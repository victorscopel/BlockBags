local _, A = ...

function A:UpdateItemInteraction(button)
    local receiver=button.interactionLayer
    if not receiver then return end
    local enabled=not self.draft and not InCombatLockdown()
    if receiver.interactionEnabled~=enabled then
        receiver.interactionEnabled=enabled
        receiver:EnableMouse(enabled)
    end
    if not enabled then return end
    local intercept=IsAltKeyDown() or self.atBank==true
    if receiver.interceptsRight~=intercept then
        receiver.interceptsRight=intercept
        if intercept then receiver:SetPassThroughButtons() else receiver:SetPassThroughButtons("RightButton") end
    end
end

function A:UpdateInteractionLayers()
    for _,button in pairs(self.buttons or {}) do self:UpdateItemInteraction(button) end
end

function A:PrepareStartupInventory()
    if not self.ready or self.isBankWindow or self.preparingCombatInventory then return false end
    self:ScanInventory()
    self:Reconcile()
    self.renderPreparing=true
    self.preparingCombatInventory=InCombatLockdown()
    self:Render()
    self.preparingCombatInventory=nil
    self.renderPreparing=nil
    self.initialInventoryPrepared=true
    if InCombatLockdown() and self.window and self.window:IsShown() then self:PaintCombatInventory() end
    return true
end

function A:PaintCombatInventory()
    if self.isBankWindow or not self.buttons or not self.window:IsShown() then return end
    if not self.initialInventoryPrepared then self:PrepareStartupInventory(); return end
    self:UpdateInteractionLayers()
    local search=(self.search:GetText() or ""):lower()
    for _,button in pairs(self.buttons) do
        if button.combatReveal then button:Show() end
        if button:IsShown() then
            local info=C_Container.GetContainerItemInfo(button.bagID or button:GetBagID(),button:GetID())
            button:SetHasItem(info~=nil)
            button:SetReadable(info and info.isReadable or false)
            SetItemButtonTexture(button,info and info.iconFileID)
            SetItemButtonCount(button,info and info.stackCount or 0)
            SetItemButtonDesaturated(button,info and info.isLocked or false)
            if button.stackBadge then button.stackBadge:Hide() end
            if button.UpdateCooldown then button:UpdateCooldown(info~=nil) end
            local model=self.slotModels and self.slotModels[button.anchorSlotKey]
            if model then
                model.info=info
                if info then
                    local data=self.itemCache[info.itemID]
                    model.name=data and data.name or (C_Item.GetItemInfo(info.itemID)) or self.L["Carregando…"]
                    model.sortName=model.name:lower()
                    button.currentItem=model
                else button.currentItem=nil end
            end
            local match=search=="" or (model and info and self:MatchesQuery(model,search))
            button:SetAlpha(match and 1 or 0.22)
        end
    end
    self.searchHint:SetShown(search==""); self.searchClear:SetShown(search~="")
    self.status:SetText(self.L["Combate: as posições serão atualizadas ao sair do combate."])
end
