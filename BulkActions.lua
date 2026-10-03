local _, A = ...

function A:CancelBulkAction()
    if self.bulkAction then
        self.bulkAction.cancelled=true
        self.bulkAction=nil
    end
end
function A:BulkContextValid(action)
    if InCombatLockdown() or self.draft or CursorHasItem() or not self.window:IsShown() then return false end
    if action.viewKey and action.viewKey~=self:ViewKey() then return false end
    if action.kind=="sell" then return MerchantFrame and MerchantFrame:IsShown() and (self.storage or "bags")=="bags" end
    return self.atBank and C_Bank and C_Bank.CanUseBank(action.bankType)
end
function A:RequestCategoryAction(category,kind,targetStorage)
    if self.bulkAction then self:Print(A.L["Uma operação já está em andamento."]); return false end
    local group=self.groups[category]
    if not group then return false end
    local action={kind=kind,bankType=self:BankType(targetStorage or self.storage),entries={},index=1,done=0,skipped=0,viewKey=self:ViewKey(),owner=self}
    if not self:BulkContextValid(action) then self:Print(A.L["Abra o banco ou vendedor correspondente antes desta ação."]); return false end
    if kind=="sell" and self.atBank then self:Print(A.L["Feche o banco antes de vender itens."]); return false end
    for _,item in ipairs(group.items) do
        if not self.profile.favorites[item.info.itemID] and (item.equipmentSet or "")=="" then
            action.entries[#action.entries+1]={bag=item.bag,slot=item.slot,id=item.info.itemID,identity=item.identity,
                link=item.info.hyperlink,count=item.info.stackCount,location=self.slotLocations[item.slotKey]}
        end
    end
    if #action.entries==0 then self:Print(A.L["Não há itens elegíveis: favoritos e conjuntos são protegidos."]); return false end
    -- Confirm the item count and destination before starting.
    self.pendingBulkAction=action
    if not StaticPopupDialogs.BLOCKBAGS_CATEGORY_ACTION then
        StaticPopupDialogs.BLOCKBAGS_CATEGORY_ACTION={text="%s",button1=ACCEPT or "Confirmar",button2=CANCEL,timeout=0,whileDead=true,hideOnEscape=true,
            OnAccept=function(_,data) (data.owner or A):StartBulkAction(data) end,
            OnCancel=function(_,data) (data and data.owner or A).pendingBulkAction=nil end}
    end
    local verb=kind=="sell" and A.L["Vender"] or kind=="withdraw" and A.L["Retirar"] or A.L["Depositar"]
    local destination=kind=="sell" and A.L["no vendedor"] or kind=="withdraw" and A.L["para o inventário"] or (action.bankType==Enum.BankType.Account and A.L["no banco da tropa"] or A.L["no banco do personagem"])
    StaticPopup_Show("BLOCKBAGS_CATEGORY_ACTION",verb.." "..#action.entries..A.L[" pilhas de "]..self:CategoryName(category).." "..destination..A.L["? Favoritos e conjuntos não serão movidos."],nil,action)
    return true
end
function A:StartBulkAction(action)
    self.pendingBulkAction=nil
    if self.bulkAction or not self:BulkContextValid(action) then return false end
    self.bulkAction=action
    local function step()
        if self.bulkAction~=action or action.cancelled then return end
        if not self:BulkContextValid(action) then self:CancelBulkAction(); self:Print(A.L["Operação interrompida."]); return end
        local entry=action.entries[action.index]
        if not entry then
            self.bulkAction=nil
            self:Print(A.L["Operação concluída: "]..action.done..A.L[" pilhas processadas; "]..action.skipped..A.L[" ignoradas."])
            self:QueueRefresh(); return
        end
        local info=C_Container.GetContainerItemInfo(entry.bag,entry.slot)
        local guid=entry.location and C_Item.GetItemGUID(entry.location)
        local same=info and info.itemID==entry.id and info.stackCount==entry.count and info.hyperlink==entry.link
            and (not guid or "guid:"..guid==entry.identity)
        local member=self.equipmentMembership and self.equipmentMembership[entry.bag..":"..entry.slot]
        if not same or info.isLocked or self.profile.favorites[entry.id] or member then
            action.skipped=action.skipped+1; action.index=action.index+1; C_Timer.After(0.12,step); return
        end
        if action.kind=="sell" then
            local price=select(11,C_Item.GetItemInfo(entry.link or entry.id))
            if info.hasNoValue or not price or price<=0 then
                action.skipped=action.skipped+1; action.index=action.index+1; C_Timer.After(0.12,step); return
            end
        elseif action.kind=="deposit" and C_Bank.IsItemAllowedInBankType and not C_Bank.IsItemAllowedInBankType(action.bankType,entry.location) then
            action.skipped=action.skipped+1; action.index=action.index+1; C_Timer.After(0.12,step); return
        end
        -- Wait for the source slot to change before processing the next item.
        C_Container.UseContainerItem(entry.bag,entry.slot,nil,action.kind~="sell" and action.bankType or nil)
        C_Timer.After(0.3,function()
            if self.bulkAction~=action then return end
            local after=C_Container.GetContainerItemInfo(entry.bag,entry.slot)
            if after and after.itemID==entry.id and after.stackCount==entry.count and after.hyperlink==entry.link then
                self:CancelBulkAction(); self:Print(A.L["Operação interrompida: o servidor não confirmou a transferência. Verifique espaço e restrições."]); self:QueueRefresh(); return
            end
            action.done=action.done+1; action.index=action.index+1; step()
        end)
    end
    step()
    return true
end
function A:AddCategoryActions(root,id)
    if self.draft then return end
    local tabs=root:CreateButton(A.L["Mover categoria para aba"])
    if tabs then for _,tab in ipairs(self:GetTabs()) do tabs:CreateButton(self:TabName(tab),function() self:AssignCategoryTab(id,tab.id) end) end end
    if self.atBank then
        if (self.storage or "bags")=="bags" then
            if C_Bank.CanUseBank(Enum.BankType.Character) then root:CreateButton(A.L["Depositar categoria no banco"],function() self:RequestCategoryAction(id,"deposit","character") end) end
            if C_Bank.CanUseBank(Enum.BankType.Account) then root:CreateButton(A.L["Depositar categoria no banco da tropa"],function() self:RequestCategoryAction(id,"deposit","account") end) end
        else root:CreateButton(A.L["Retirar categoria para o inventário"],function() self:RequestCategoryAction(id,"withdraw",self.storage) end) end
    elseif MerchantFrame and MerchantFrame:IsShown() then
        root:CreateButton(A.L["Vender itens desta categoria…"],function() self:RequestCategoryAction(id,"sell") end)
    end
    if self.bulkAction then root:CreateButton(A.L["Interromper operação"],function() self:CancelBulkAction() end) end
end
