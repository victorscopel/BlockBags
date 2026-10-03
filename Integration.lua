local _, A = ...

function A:Toggle()
    if not self.ready then return end
    if InCombatLockdown() then
        self:Print(A.L["Em combate, use sua tecla de mochila para abrir ou fechar."])
        return
    end
    self.window:SetShown(not self.window:IsShown())
end

function A:RequestWindow(action)
    if not self.ready or self.integrationBlocked then return end
    local bank=self.bankController
    if action=="close" and bank and (bank.openingSettings or bank.settingsInventorySession) then return end
    if action=="close" and (self.openingSettings or self.settingsInventorySession or self.openingBank) then return end
    -- Combine nested bag calls into one window action.
    if action == "toggle" or self.windowIntent ~= "toggle" then self.windowIntent = action end
    if self.intentQueued then return end
    self.intentQueued = true
    C_Timer.After(0, function()
        self.intentQueued = false
        local intent = self.windowIntent
        self.windowIntent = nil
        if InCombatLockdown() then return end
        if intent == "toggle" then self:Toggle()
        elseif intent == "open" then self.window:Show()
        elseif intent == "close" and not self.openingSettings and not self.settingsInventorySession and not self.openingBank
            and not (self.bankController and (self.bankController.openingSettings or self.bankController.settingsInventorySession)) then self.window:Hide() end
    end)
end

function A:InstallIntegration()
    if self.integrationInstalled then return end
    -- Skip integration when another bag replacement is active.
    for _, name in ipairs({ "BetterBags", "MyBags", "ArkInventory", "Baganator", "Bagnon" }) do
        if C_AddOns.IsAddOnLoaded(name) then
            self.integrationBlocked = true
            self:Print(name .. A.L[" está ativo. Use /bb para testar; desative os outros addons de bolsas e dê /reload para substituir a interface padrão."])
            return
        end
    end
    local engine = ElvUI and ElvUI[1]
    if C_AddOns.IsAddOnLoaded("ElvUI") and (not engine or not engine.private or engine.private.bags.enable) then
        self.integrationBlocked = true
        self:Print(A.L["O módulo de bolsas do ElvUI está ativo. Desative-o e dê /reload. O BlockBags continua acessível por /bb."])
        return
    end
    if InCombatLockdown() then return end
    self.integrationInstalled=true
    self:RefreshCombatBindings()
    self:ApplyBlizzardBagBarVisibility()
    self.hiddenBags = CreateFrame("Frame")
    self.hiddenBags:Hide()
    if ContainerFrameCombinedBags then ContainerFrameCombinedBags:SetParent(self.hiddenBags) end
    -- Include the backpack frame, which NUM_TOTAL_BAG_FRAMES omits.
    for i = 1, NUM_CONTAINER_FRAMES or ((NUM_TOTAL_BAG_FRAMES or 5) + 1) do
        local frame = _G["ContainerFrame" .. i]
        if frame then frame:SetParent(self.hiddenBags) end
    end
    for _, name in ipairs({ "ToggleAllBags", "ToggleBackpack", "ToggleBag" }) do
        if type(_G[name]) == "function" then hooksecurefunc(name, function() self:RequestWindow("toggle") end) end
    end
    for _, name in ipairs({ "OpenAllBags", "OpenBackpack", "OpenBag" }) do
        if type(_G[name]) == "function" then hooksecurefunc(name, function() self:RequestWindow("open") end) end
    end
    for _, name in ipairs({ "CloseAllBags", "CloseBackpack", "CloseBag", "CloseSpecialWindows" }) do
        if type(_G[name]) == "function" then hooksecurefunc(name, function() self:RequestWindow("close") end) end
    end
end

BINDING_HEADER_BLOCKBAGS = "BlockBags"
BINDING_NAME_BLOCKBAGS_TOGGLE = A.L["Abrir/fechar BlockBags"]
BINDING_NAME_ANCHORBAGS_TOGGLE = A.L["Abrir/fechar BlockBags (atalho legado)"]
