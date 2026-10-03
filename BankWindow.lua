local _, A = ...

local function migrateBankDatabase(inventory)
    local source=inventory:GetDatabase()
    if source.bank then return source.bank end
    local bank={profiles={},characterProfiles=inventory:Copy(source.characterProfiles or {}),inventoryPositions={}}
    for name,profile in pairs(source.profiles or {}) do
        local copy=inventory:Copy(profile)
        copy.placements={}; copy.extraLayouts={}
        for key,layout in pairs(profile.extraLayouts or {}) do
            if key:match("^character:") or key:match("^account_%d+:") then copy.extraLayouts[key]=inventory:Copy(layout) end
        end
        if copy.layout.reagentbag then copy.layout.reagentbag.hidden=true end
        for _,layout in pairs(copy.extraLayouts) do if layout.reagentbag then layout.reagentbag.hidden=true end end
        copy.window.x=(copy.window.x or 0)-360
        bank.profiles[name]=copy
    end
    for character,profiles in pairs(source.inventoryPositions or {}) do
        bank.inventoryPositions[character]={}
        for name,positions in pairs(profiles) do
            local copy={views={},stackCategories={}}
            for key,view in pairs(positions.views or {}) do
                if key:match("^character:") or key:match("^account_%d+:") then copy.views[key]=inventory:Copy(view) end
            end
            for key,rules in pairs(positions.stackCategories or {}) do
                if key=="character" or key:match("^account_%d+$") then copy.stackCategories[key]=inventory:Copy(rules) end
            end
            bank.inventoryPositions[character][name]=copy
        end
    end
    -- Remove migrated bank-only data from inventory profiles and positions.
    for _,profile in pairs(source.profiles or {}) do
        for key in pairs(profile.extraLayouts or {}) do
            if key:match("^character:") or key:match("^account_%d+:") then profile.extraLayouts[key]=nil end
        end
    end
    for _,profiles in pairs(source.inventoryPositions or {}) do
        for _,positions in pairs(profiles) do
            for key in pairs(positions.views or {}) do
                if key:match("^character:") or key:match("^account_%d+:") then positions.views[key]=nil end
            end
            for key in pairs(positions.stackCategories or {}) do
                if key=="character" or key:match("^account_%d+$") then positions.stackCategories[key]=nil end
            end
        end
    end
    source.bank=bank
    return bank
end

function A:EnsureBankWindow()
    if self.isBankWindow then return self end
    if self.bankController then return self.bankController end
    local bank={}
    -- Copy methods only. Runtime frames, caches and queues belong to each window.
    for key,value in pairs(A) do if type(value)=="function" then bank[key]=value end end
    bank.isBankWindow=true; bank.inventoryController=self
    bank.windowName="BlockBagsBankWindow"; bank.itemButtonPrefix="BlockBagsBankItem"
    bank.L,bank.locale,bank.version=self.L,self.locale,self.version
    bank.cell,bank.padding,bank.header,bank.scrollGutter=self.cell,self.padding,self.header,self.scrollGutter
    bank.categories=self:Copy(self.baseCategories)
    bank.itemCache,bank.loading,bank.itemRequests={},{},{}
    bank.database=migrateBankDatabase(self)
    bank.storage="character"; bank.activeTab="default"
    bank.DefaultLayout=function(controller)
        local layout=A.DefaultLayout(controller)
        layout.reagentbag.hidden=true
        return layout
    end
    bank:InitializeDatabase()
    bank:BuildUI(); bank:RegisterSettings()
    bank.ready=true
    self.bankController=bank
    return bank
end

function A:CloseBankWindow()
    self.atBank=false; self:CancelBulkAction(); self:CancelInteractions()
    if InCombatLockdown() then self.pendingBankWindowClose=true; return end
    if self.draft then self:FinishEdit(false) end
    self.closingBank=true; self.window:Hide(); self.closingBank=nil
end

function A:HandleBankWindowEvent(event,arg,success)
    if event=="PLAYER_REGEN_DISABLED" then
        self:CancelBulkAction(); self:CancelInteractions()
        if self.draft then self:FinishEdit(false) end
        self.combatOverlay:Show()
    elseif event=="PLAYER_REGEN_ENABLED" then
        self.combatOverlay:Hide(); self.forceItemPaint=true
        if self.pendingBankWindowClose then
            self.pendingBankWindowClose=nil; self:CloseBankWindow()
        elseif self.atBank then self:QueueRefresh() end
    elseif event=="GET_ITEM_INFO_RECEIVED" or event=="ITEM_DATA_LOAD_RESULT" then
        self:ItemDataResult(arg,success)
    elseif event=="CURSOR_CHANGED" then
        if not CursorHasItem() then self.itemDrag=nil; self:HideCategoryDropHint() end
    elseif event=="PLAYER_MONEY" then
        if self.window:IsShown() then self.money:SetText(self:FormatMoney(GetMoney())) end
    elseif event=="CURRENCY_DISPLAY_UPDATE" then
        if self.window:IsShown() then self:PaintCurrencyBar() end
    elseif self.atBank and event~="BANKFRAME_OPENED" and event~="BANKFRAME_CLOSED" then
        if event=="PLAYER_EQUIPMENT_CHANGED" or event=="EQUIPMENT_SETS_CHANGED" or event=="TRANSMOG_COLLECTION_UPDATED" then self.invalidateTooltips=true end
        self:QueueRefresh()
    end
end
