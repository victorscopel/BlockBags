local _, A = ...

local toggleSnippet=[[
    local window=self:GetFrameRef("window")
    if button=="Close" then window:Hide()
    elseif button=="Open" then window:Show()
    elseif window:IsShown() then window:Hide() else window:Show() end
]]
local stateSnippet=[[
    self:ClearBindings()
    if newstate=="combat" and self:GetAttribute("integrated") then
        for i=1,self:GetAttribute("key-count") or 0 do
            self:SetBindingClick(true,self:GetAttribute("key-"..i),self:GetName(),self:GetAttribute("action-"..i))
        end
        if self:GetFrameRef("window"):IsShown() then self:SetBindingClick(true,"ESCAPE",self:GetName(),"Close") end
        for i=1,self:GetAttribute("slot-count") or 0 do
            local slot=self:GetFrameRef("slot-"..i)
            slot:EnableMouse(true)
            slot:SetAttribute("type2","item")
            if slot:GetAttribute("combat-reveal") then slot:Show() end
        end
        local bags=self:GetFrameRef("bag-slots")
        if bags then bags:Hide() end
        self:GetFrameRef("save"):Hide()
        self:GetFrameRef("cancel"):Hide()
        self:GetFrameRef("undo"):Hide()
    end
]]

function A:BuildCombatControls()
    if self.isBankWindow or not SecureHandlerWrapScript or not RegisterStateDriver then return end
    local control=CreateFrame("Button","BlockBagsSecureToggle",UIParent,"SecureHandlerClickTemplate,SecureHandlerStateTemplate")
    self.combatController=control
    control:RegisterForClicks("AnyUp")
    control:SetFrameRef("window",self.window)
    -- Restricted combat handlers require explicitly protected target frames.
    for _,key in ipairs({"save","cancel","undo"}) do control:SetFrameRef(key,self[key.."Button"]) end
    control:SetAttribute("_onclick",toggleSnippet)
    control:SetAttribute("_onstate-combat",stateSnippet)
    control:SetAttribute("key-count",0); control:SetAttribute("slot-count",0)
    RegisterStateDriver(control,"combat","[combat] combat; peace")
    SecureHandlerWrapScript(self.closeButton,"OnClick",control,[[control:GetFrameRef("window"):Hide(); return false]])
    SecureHandlerWrapScript(self.window,"OnShow",control,[[
        if control:GetAttribute("state-combat")=="combat" and control:GetAttribute("integrated") then
            control:SetBindingClick(true,"ESCAPE",control:GetName(),"Close")
        end
    ]])
    SecureHandlerWrapScript(self.window,"OnHide",control,[[control:ClearBinding("ESCAPE")]])
end

function A:PrepareCombatButton(button)
    local control=self.combatController
    if not control then return end
    self.combatButtonCount=(self.combatButtonCount or 0)+1
    control:SetFrameRef("slot-"..self.combatButtonCount,button)
    control:SetAttribute("slot-count",self.combatButtonCount)
    SecureHandlerWrapScript(button,"PreClick",control,[[
        if control:GetAttribute("state-combat")=="combat" then self:SetAttribute("type2","item") end
    ]])
end

function A:RefreshCombatBindings()
    local control=self.combatController
    if not control or InCombatLockdown() then return end
    control:SetAttribute("integrated",self.integrationInstalled==true and not self.integrationBlocked)
    local count,seen=0,{}
    if GetBindingKey then
        for _,entry in ipairs({{"TOGGLEBACKPACK","LeftButton"},{"TOGGLEBAGS","LeftButton"},{"OPENALLBAGS","Open"},
            {"CLOSEALLBAGS","Close"},{"TOGGLEBAG1","LeftButton"},{"TOGGLEBAG2","LeftButton"},
            {"TOGGLEBAG3","LeftButton"},{"TOGGLEBAG4","LeftButton"},{"TOGGLEBAG5","LeftButton"},{"TOGGLEREAGENTBAG","LeftButton"},{"BLOCKBAGS_TOGGLE","LeftButton"},{"ANCHORBAGS_TOGGLE","LeftButton"}}) do
            for _,key in ipairs({GetBindingKey(entry[1])}) do
                if not seen[key] and count<32 then
                    count=count+1; seen[key]=true
                    control:SetAttribute("key-"..count,key); control:SetAttribute("action-"..count,entry[2])
                end
            end
        end
    end
    control:SetAttribute("key-count",count)
    local native=MainMenuBarBackpackButton
    if native and self.integrationInstalled and not self.integrationBlocked and not self.combatBackpackProxy then
        local proxy=CreateFrame("Button","BlockBagsSecureBackpack",native,"SecureHandlerClickTemplate")
        self.combatBackpackProxy=proxy
        proxy:SetAllPoints(native); proxy:SetFrameLevel(native:GetFrameLevel()+5)
        proxy:RegisterForClicks("LeftButtonUp","RightButtonUp")
        proxy:SetFrameRef("window",self.window); proxy:SetAttribute("_onclick",toggleSnippet)
        proxy:SetScript("OnEnter",function()
            local enter=native:GetScript("OnEnter")
            if enter then enter(native) else GameTooltip:SetOwner(proxy,"ANCHOR_RIGHT"); GameTooltip:SetText(self:BackpackTitle()); GameTooltip:Show() end
        end)
        proxy:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
end

function A:PaintCombatInventory()
    if self.isBankWindow or not self.buttons or not self.window:IsShown() then return end
    local search=(self.search:GetText() or ""):lower()
    for _,button in pairs(self.buttons) do
        if button:IsShown() then
            local info=C_Container.GetContainerItemInfo(button.bagID or button:GetBagID(),button:GetID())
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
