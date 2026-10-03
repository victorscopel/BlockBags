local _, A = ...

function A:BankState(storage)
    storage=storage or self.storage or "character"
    local kind=self:BankType(storage)
    if not self.atBank or not C_Bank or not C_Bank.CanViewBank(kind) then return "unavailable" end
    local reason=C_Bank.FetchBankLockedReason and C_Bank.FetchBankLockedReason(kind)
    if reason~=nil and reason~=(Enum.BankLockedReason and Enum.BankLockedReason.None or 0) then return "readonly" end
    local bags=self:GetBankContainers(kind)
    if #bags==0 then return "empty" end
    if not C_Bank.CanUseBank(kind) then return "readonly" end
    local selected=tonumber(storage:match("^account_(%d+)$"))
    if selected then
        local found=false
        for _,bag in ipairs(bags) do if bag==selected then found=true; break end end
        if not found then return "unavailable" end
    end
    return "ready"
end

function A:BankStateText(state,storage)
    local kind=self:BankType(storage or self.storage)
    local reason=C_Bank and C_Bank.FetchBankLockedReason and C_Bank.FetchBankLockedReason(kind)
    local enum=Enum.BankLockedReason or {}
    if reason~=nil then
        if enum.NoAccountInventoryLock~=nil and reason==enum.NoAccountInventoryLock then return BANK_LOCKED_REASON_NO_ACCOUNT_INVENTORY_LOCK or self.L["O banco da tropa está em uso em outra sessão."] end
        if enum.BankDisabled~=nil and reason==enum.BankDisabled then return BANK_LOCKED_REASON_BANK_DISABLED or self.L["Este banco está temporariamente desativado."] end
        if enum.BankConversionFailed~=nil and reason==enum.BankConversionFailed then return BANK_LOCKED_REASON_BANK_CONVERSION_FAILED or self.L["Não foi possível converter os dados deste banco."] end
    end
    return self.L[state=="readonly" and "Banco somente para consulta." or state=="empty" and "Nenhuma aba comprada. Compre uma aba pelo menu da bolsa." or "Banco indisponível."]
end

function A:CanMutateBank(storage,quiet)
    local state=self:BankState(storage)
    local allowed=state=="ready" and not self.draft and not InCombatLockdown()
    if not allowed and not quiet then self:Print(InCombatLockdown() and self.L["Aguarde o fim do combate."] or self.draft and self.L["Salve ou cancele a edição antes de trocar de armazenamento."] or self:BankStateText(state,storage)) end
    return allowed
end

function A:SyncBankContext(storage)
    if not self.atBank or InCombatLockdown() then return end
    storage=storage or (self.isBankWindow and self.storage or self.bankDepositTarget or "character")
    local kind=self:BankType(storage)
    if BankPanel and BankPanel.SetBankType then BankPanel:SetBankType(kind) end
    local id=tonumber(storage:match("^account_(%d+)$"))
    if id and BankPanel and BankPanel.SelectTab then BankPanel:SelectTab(id) end
    if ItemButtonUtil and ItemButtonUtil.TriggerEvent and ItemButtonUtil.Event then
        ItemButtonUtil.TriggerEvent(ItemButtonUtil.Event.ItemContextChanged)
    end
    local inventory=self.inventoryController or self
    inventory.forceItemPaint=true
    if inventory.window:IsShown() then inventory:Render() end
end

function A:BankItemAllowed(item,storage)
    if not item or not item.info then return false end
    local location=self.slotLocations and self.slotLocations[item.slotKey]
    if not location then location=ItemLocation:CreateFromBagAndSlot(item.bag,item.slot) end
    return not C_Bank.IsItemAllowedInBankType or C_Bank.IsItemAllowedInBankType(self:BankType(storage),location)
end

function A:UpdateBankEligibility(button,item)
    local blocked=false
    if self.atBank and not self.isBankWindow and item then
        blocked=not self:CanMutateBank(self.bankDepositTarget or "character",true)
            or not self:BankItemAllowed(item,self.bankDepositTarget or "character")
    end
    button.bankBlocked=blocked
    if type(button.bankRestriction)~="table" and type(button.bankRestriction)~="userdata" then
        button.bankRestriction=button:CreateTexture(nil,"OVERLAY",nil,6)
        button.bankRestriction:SetAllPoints(button)
        button.bankRestriction:SetColorTexture(0,0,0,0.6)
    end
    button.bankRestriction:SetShown(blocked)
end

-- Unified banks use the first compatible space; legacy explicit destinations remain supported.
function A:TransferBankItem(item,targetStorage,confirmed)
    local sourceBank=self.isBankWindow or (self.storage or "bags")~="bags"
    local storage=sourceBank and self.storage or targetStorage or self.bankDepositTarget or "character"
    if not self:CanMutateBank(storage) or CursorHasItem() then return false end
    local info=C_Container.GetContainerItemInfo(item.bag,item.slot)
    if not info or info.itemID~=item.info.itemID or info.isLocked then return false end
    if item.identity and item.identity:match("^guid:") then
        local guid=C_Item.GetItemGUID(ItemLocation:CreateFromBagAndSlot(item.bag,item.slot))
        if not guid or item.identity~="guid:"..guid then return false end
    end
    if not sourceBank and not self:BankItemAllowed(item,storage) then
        self:Print(self.L["Este item não pode ser depositado nesse banco."]); return false
    end
    local bags=sourceBank and {0,1,2,3,4,5} or self:GetBankContainers(self:BankType(storage))
    local selected=not sourceBank and tonumber(storage:match("^account_(%d+)$"))
    local targetBag,targetSlot
    local maximum=select(8,C_Item.GetItemInfo(info.hyperlink or info.itemID)) or 1
    for _,bag in ipairs(bags) do
        if not selected or bag==selected then
            local _,family=C_Container.GetContainerNumFreeSlots(bag)
            local compatible=not sourceBank or ((family or 0)==0 and bag~=Enum.BagIndex.ReagentBag)
            if compatible then
                for slot=1,C_Container.GetContainerNumSlots(bag) do
                    local existing=C_Container.GetContainerItemInfo(bag,slot)
                    if not existing and not targetBag then targetBag,targetSlot=bag,slot end
                    if existing and not existing.isLocked and existing.itemID==info.itemID
                        and existing.hyperlink==info.hyperlink and maximum-(existing.stackCount or 1)>=(info.stackCount or 1) then
                        targetBag,targetSlot=bag,slot; break
                    end
                end
            end
        end
        if targetBag then break end
    end
    if not targetBag then self:Print(self.L["Não há espaço compatível no destino selecionado."]); return false end
    local location=ItemLocation:CreateFromBagAndSlot(item.bag,item.slot)
    if not sourceBank and self:BankType(storage)==Enum.BankType.Account and C_Item.CanBeRefunded
        and C_Item.CanBeRefunded(location) and not confirmed then
        if not Item or not Item.CreateFromItemGUID or not StaticPopupDialogs.ACCOUNT_BANK_DEPOSIT_NO_REFUND_CONFIRM then return false end
        self:SyncBankContext(storage)
        local guid=C_Item.GetItemGUID(location)
        if not guid then return false end
        local refundable=Item:CreateFromItemGUID(guid)
        C_Container.PickupContainerItem(item.bag,item.slot)
        if not CursorHasItem() then return false end
        StaticPopup_Show("ACCOUNT_BANK_DEPOSIT_NO_REFUND_CONFIRM",nil,nil,
            {itemToDeposit=refundable,targetItemLocation=ItemLocation:CreateFromBagAndSlot(targetBag,targetSlot)})
        return false
    end
    C_Container.PickupContainerItem(item.bag,item.slot)
    if not CursorHasItem() then return false end
    C_Container.PickupContainerItem(targetBag,targetSlot)
    local success=not CursorHasItem()
    if not success then C_Container.PickupContainerItem(item.bag,item.slot) end
    self.itemDrag=nil
    local inventory=self.inventoryController or self
    inventory:QueueRefresh()
    if inventory.bankController then inventory.bankController:QueueRefresh() end
    return success
end
