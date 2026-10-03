local _, A = ...
BlockBags = A
AnchorBags = A -- Compatibility for existing bindings/scripts.
A.version = "0.7.1"
A.cell, A.padding, A.header, A.scrollGutter = 40, 8, 36, 0
A.categories = {
    { id = "equipment", name = A.L["Equipamentos"], x = 0, y = 0, cols = 8, rows = 4 },
    { id = "consumables", name = A.L["Consumíveis"], x = 9, y = 0, cols = 5, rows = 3 },
    { id = "reagentbag", name = A.L["Bolsa de reagentes"], x = 15, y = 0, cols = 6, rows = 5 },
    { id = "materials", name = A.L["Materiais"], x = 0, y = 6, cols = 8, rows = 3 },
    { id = "quest", name = A.L["Missões"], x = 9, y = 5, cols = 5, rows = 3 },
    { id = "misc", name = A.L["Diversos"], x = 15, y = 7, cols = 6, rows = 3 },
    { id = "junk", name = A.L["Lixo"], x = 0, y = 11, cols = 8, rows = 2 },
}

function A:Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for k, v in pairs(value) do result[k] = self:Copy(v) end
    return result
end

function A:ClearTable(value)
    for key in pairs(value) do value[key]=nil end
    return value
end

function A:Print(message)
    print("|cff57d6ceBlockBags|r: " .. message)
end

function A:DefaultLayout()
    local result = {}
    for _, category in ipairs(self.categories) do
        result[category.id] = {
            x = category.x, y = category.y, cols = category.cols, rows = category.rows,
            compact = false, itemSize = 36, itemSpacing = 4,
        }
    end
    return result
end

function A:GetLayout()
    return self.draft or self:GetBaseLayout()
end

function A:GetSettings()
    return self.draftSettings or self.profile.settings or { categorySpacing = 0 }
end

function A:CategoryName(id)
    local data = self:GetLayout()[id]
    if data and data.name then return data.name end
    for _, cat in ipairs(self.categories) do if cat.id == id then return self:DefaultCategoryName(cat.id,cat.name) end end
    return id
end

function A:VisibleCategory(id)
    local layout = self:GetLayout()
    if layout[id] and not layout[id].hidden then return id end
    if layout.misc and not layout.misc.hidden then return "misc" end
    for _, cat in ipairs(self.categories) do if not layout[cat.id].hidden then return cat.id end end
    return "misc"
end

function A:GetDatabase() return self.database or BlockBagsDB end

function A:InitializeDatabase()
    if not BlockBagsDB and type(AnchorBagsDB)=="table" then
        BlockBagsDB = self:Copy(AnchorBagsDB)
        BlockBagsDB.migratedFromAnchorBags = true
    end
    BlockBagsDB = BlockBagsDB or {}
    local db = self:GetDatabase()
    db.schema = 2
    db.profiles = db.profiles or {}
    local character = UnitName("player") .. "-" .. GetRealmName()
    db.characterProfiles = db.characterProfiles or {}
    local key = db.characterProfiles[character] or character
    db.characterProfiles[character] = key
    self.characterKey = character
    db.profiles[key] = db.profiles[key] or {}
    self.profile = db.profiles[key]
    self.profileKey = key
    self.profile.layout = self.profile.layout or self:DefaultLayout()
    self.profile.placements = self.profile.placements or {}
    db.inventoryPositions = db.inventoryPositions or {}
    db.inventoryPositions[character] = db.inventoryPositions[character] or {}
    local positions = db.inventoryPositions[character]
    positions[key] = positions[key] or (key == character and self.profile.placements or {})
    self.profile.placements = positions[key]
    self.profile.window = self.profile.window or { x = 0, y = 0, scale = 0.85 }
    self.profile.settings = self.profile.settings or { categorySpacing = 0 }
    self.profile.favorites = self.profile.favorites or {}
    self.profile.manualCategories = self.profile.manualCategories or {}
    self.profile.categories = self.profile.categories or self:Copy(self.baseCategories or self.categories)
    self.baseCategories = self.baseCategories or self:Copy(self.categories)
    self.categories = self.profile.categories
    for _, cat in ipairs(self.categories) do
        if not self.profile.layout[cat.id] then
            self.profile.layout[cat.id] = self:DefaultLayout()[cat.id]
        end
        local layout = self.profile.layout[cat.id]
        layout.itemSize = layout.itemSize or 36
        layout.itemSpacing = layout.itemSpacing or 4
    end
    if not self.profile.spacingLayoutVersion then
        self:PackLayout(self.profile.layout,self.profile.settings.categorySpacing or 0)
        self.profile.spacingLayoutVersion=1
    end
end

function A:QueueRefresh(changedBags)
    if changedBags then
        self.scanDirtyBags=self.scanDirtyBags or {}
        for bag in pairs(changedBags) do self.scanDirtyBags[bag]=true end
    else self.fullInventoryScan=true end
    if not self.ready or self.refreshQueued then return end
    if self.window and not self.window:IsShown() then self.inventoryDirty=true; return end
    self.refreshQueued = true
    C_Timer.After(0.05, function()
        self.refreshQueued = false
        if not self.ready then return end
        if not self.window:IsShown() then self.inventoryDirty=true; return end
        if InCombatLockdown() then self.pendingRefresh = true; return end
        self.pendingRefresh = nil
        self.inventoryDirty = nil
        local changed=not self.fullInventoryScan and self.scanDirtyBags or nil
        self.fullInventoryScan=nil; self.scanDirtyBags=nil
        self:ScanInventory(changed)
        self:Reconcile()
        self:Render()
    end)
end

local events = CreateFrame("Frame")
A.events = events
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, arg, success)
    if A.bankController and A.bankController.ready then A.bankController:HandleBankWindowEvent(event,arg,success) end
    if event == "ADDON_LOADED" then
        if arg ~= "BlockBags" then
            if A.ready and arg=="Pawn" then A:QueueRefresh() end
            if A.ready and arg=="Blizzard_MainMenuBarBagButtons" then A:ApplyBlizzardBagBarVisibility() end
            return
        end
        A:InitializeDatabase()
        A:BuildUI()
        A:RegisterSettings()
        A.ready = true
        for _, name in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "BAG_UPDATE_DELAYED", "ITEM_LOCK_CHANGED",
            "BAG_UPDATE_COOLDOWN", "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT", "PLAYER_MONEY", "PLAYER_REGEN_ENABLED",
            "PLAYER_REGEN_DISABLED", "MERCHANT_SHOW", "MERCHANT_CLOSED", "CURSOR_CHANGED",
            "PLAYER_EQUIPMENT_CHANGED", "EQUIPMENT_SETS_CHANGED", "TRANSMOG_COLLECTION_UPDATED", "CURRENCY_DISPLAY_UPDATE",
            "BANKFRAME_OPENED", "BANKFRAME_CLOSED", "BAG_UPDATE", "PLAYERBANKSLOTS_CHANGED", "PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED",
            "BANK_TABS_CHANGED", "BANK_TAB_SETTINGS_UPDATED" }) do events:RegisterEvent(name) end
        A:QueueRefresh()
    elseif event == "PLAYER_LOGIN" then
        A:InstallIntegration()
        A:QueueRefresh()
    elseif event == "PLAYER_REGEN_DISABLED" then
        A:CancelBulkAction()
        A:CancelInteractions()
        if A.bagSlots then A.bagSlots:Hide() end
        if A.draft then A:FinishEdit(false) end
        A.combatOverlay:Show()
    elseif event == "PLAYER_REGEN_ENABLED" then
        A.forceItemPaint=true
        A:ApplyBlizzardBagBarVisibility()
        A.combatOverlay:Hide()
        if A.pendingStorageReset then A.pendingStorageReset=nil; A:SetStorage("bags") end
        if A.pendingBankOpen and A.atBank then A:BankOpened() end
        if A.physicalBagView then
            if A.window:IsShown() then A.bagSlots:SetShown((A.storage or "bags")=="bags")
            else A:SetPhysicalBagView(false) end
        end
        A:QueueRefresh()
    elseif event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
        A:ItemDataResult(arg,success)
    elseif event == "PLAYER_MONEY" then
        if A.window:IsShown() then A.money:SetText(A:FormatMoney(GetMoney())) end
    elseif event == "BANKFRAME_OPENED" then
        A:BankOpened()
    elseif event == "BANKFRAME_CLOSED" then
        A:BankClosed()
    elseif event == "CURRENCY_DISPLAY_UPDATE" then
        if A.window:IsShown() then A:PaintCurrencyBar() end
    elseif event == "CURSOR_CHANGED" then
        if not CursorHasItem() then A.itemDrag=nil; A:HideCategoryDropHint() end
    elseif event == "BAG_UPDATE" then
        A.bagUpdateBatch=true
        if type(arg)=="number" and arg>=0 and arg<=Enum.BagIndex.ReagentBag then A:QueueRefresh({[arg]=true}) end
    elseif event == "BAG_UPDATE_COOLDOWN" then
        if not InCombatLockdown() and A.window:IsShown() then
            for _,button in pairs(A.buttons) do if button.currentItem and button:IsShown() then button:UpdateCooldown(true) end end
        end
    elseif event == "BAG_UPDATE_DELAYED" then
        if not A.bagUpdateBatch then A:QueueRefresh() end
        A.bagUpdateBatch=nil
    elseif event=="PLAYERBANKSLOTS_CHANGED" or event=="PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" or event=="BANK_TABS_CHANGED" then
        -- Bank slot events are handled by the bank controller.
    else
        if event=="MERCHANT_CLOSED" then A:CancelBulkAction() end
        if event=="PLAYER_EQUIPMENT_CHANGED" or event=="EQUIPMENT_SETS_CHANGED" or event=="TRANSMOG_COLLECTION_UPDATED" then A.invalidateTooltips=true end
        if event=="MERCHANT_SHOW" or event=="MERCHANT_CLOSED" or event=="PLAYER_ENTERING_WORLD" then A.forceItemPaint=true end
        A:QueueRefresh()
    end
end)

SLASH_BLOCKBAGS1 = "/bb"
SLASH_BLOCKBAGS2 = "/blockbags"
SLASH_BLOCKBAGS3 = "/blocks"
SlashCmdList.BLOCKBAGS = function(message)
    if not A.ready then return end
    local command = (message or ""):lower():match("^%s*(.-)%s*$")
    if command == "memory gc" then
        A:ReportMemory(true)
    elseif command == "memory" then
        A:ReportMemory()
    elseif command == "config" then
        A:OpenSettings()
    elseif command == "edit" then
        A.window:Show()
        A:StartEdit()
    elseif command == "reset" then
        if InCombatLockdown() then A:Print(A.L["Aguarde o fim do combate."]); return end
        if A.draft then A:FinishEdit(false) end
        A:SetBaseLayout(A:DefaultLayout())
        A:PackLayout(A:GetBaseLayout(),A:GetSettings().categorySpacing or 0)
        A:ResizeCanvas()
        A:ApplyLayout()
        A:QueueRefresh()
        A:Print(A.L["Layout restaurado. As posições dos itens foram mantidas."])
    elseif command:match("^scale ") then
        local scale = tonumber(command:match("^scale (.+)$"))
        if InCombatLockdown() then A:Print(A.L["Aguarde o fim do combate."]); return end
        if scale and scale >= 0.5 and scale <= 1.25 then
            A.profile.window.scale = scale
            A.window:SetScale(scale)
        else A:Print(A.L["Use /bb scale 0.85 (intervalo: 0.5 a 1.25)."]) end
    elseif command == "help" then
        A:Print(A.L["/bb — abrir; /bb edit — editar; /bb config — opções; /bb memory — diagnóstico; /bb reset — restaurar layout; /bb scale 0.85."])
    else A:Toggle() end
end
