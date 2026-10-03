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

function A:MigrateUnifiedWarband(database)
    local function keysWithTabs(source)
        local keys={}
        for key in pairs(source or {}) do if key:match("^account_%d+") then keys[#keys+1]=key end end
        table.sort(keys)
        return keys
    end
    for _,profile in pairs(database.profiles or {}) do
        local layouts=profile.extraLayouts or {}
        for _,key in ipairs(keysWithTabs(layouts)) do
            local tab=key:match("^account_%d+:(.+)$")
            if tab then
                local destination="account:"..tab
                if not layouts[destination] then layouts[destination]=self:Copy(layouts[key]) end
                layouts[key]=nil
            end
        end
    end
    local function merge(target,source)
        for key,value in pairs(source) do
            if target[key]==nil then target[key]=type(value)=="table" and self:Copy(value) or value
            elseif type(target[key])=="table" and type(value)=="table" then merge(target[key],value) end
        end
    end
    for _,profiles in pairs(database.inventoryPositions or {}) do
        for _,positions in pairs(profiles) do
            local views=positions.views or {}
            for _,key in ipairs(keysWithTabs(views)) do
                local tab=key:match("^account_%d+:(.+)$")
                if tab then
                    local destination="account:"..tab
                    views[destination]=views[destination] or {}
                    merge(views[destination],views[key]); views[key]=nil
                end
            end
            local rules=positions.stackCategories or {}
            for _,key in ipairs(keysWithTabs(rules)) do
                rules.account=rules.account or {}; merge(rules.account,rules[key]); rules[key]=nil
            end
        end
    end
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
    bank.bankRoot=migrateBankDatabase(self)
    bank.bankRoot.scopes=bank.bankRoot.scopes or {}
    for _,scope in ipairs({"character","account"}) do
        if not bank.bankRoot.scopes[scope] then
            bank.bankRoot.scopes[scope]={profiles=self:Copy(bank.bankRoot.profiles or {}),
                characterProfiles=self:Copy(bank.bankRoot.characterProfiles or {}),
                inventoryPositions=self:Copy(bank.bankRoot.inventoryPositions or {})}
        end
    end
    bank.bankRoot.profiles=nil; bank.bankRoot.characterProfiles=nil; bank.bankRoot.inventoryPositions=nil
    for _,database in pairs(bank.bankRoot.scopes) do
        for _,profile in pairs(database.profiles) do profile.favorites={} end
    end
    bank:MigrateUnifiedWarband(bank.bankRoot.scopes.account)
    bank.database=bank.bankRoot.scopes.character
    bank.bankScope="character"
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
    self:CloseBankTabSettings()
    self:CloseBankTransactions()
    self.atBank=false; self.bankLoadGeneration=(self.bankLoadGeneration or 0)+1; self.bankLoadRetryQueued=nil; self.bankLoading=nil
    self:CancelBulkAction(); self:CancelInteractions()
    if InCombatLockdown() then self.pendingBankWindowClose=true; return end
    if self.draft then self:FinishEdit(false) end
    self.closingBank=true; self.window:Hide(); self.closingBank=nil
end

function A:HandleBankWindowEvent(event,arg,success)
    if event=="PLAYER_REGEN_DISABLED" then
        self:CloseBankTabSettings(); self:CloseBankTransactions()
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
    elseif event=="PLAYER_MONEY" or event=="ACCOUNT_MONEY" or event=="CVAR_UPDATE" then
        if event=="CVAR_UPDATE" and (type(arg)~="string" or arg:lower()~="bankautodepositreagents") then return end
        if self.window:IsShown() then self:PaintMoney(); if not InCombatLockdown() then self:RefreshBankControls() end end
    elseif event=="CURRENCY_DISPLAY_UPDATE" then
        -- Character currencies are displayed only in the backpack.
    elseif self.atBank and event=="BAG_UPDATE" then
        self.bagUpdateBatch=true
        for _,bag in ipairs(self:GetScannedBags()) do
            if bag==arg then self:QueueRefresh({[bag]=true}); break end
        end
    elseif self.atBank and event=="BAG_UPDATE_DELAYED" then
        if not self.bagUpdateBatch then self:QueueRefresh() end
        self.bagUpdateBatch=nil
    elseif self.atBank and event=="BAG_UPDATE_COOLDOWN" then
        if not InCombatLockdown() and self.window:IsShown() then
            for _,button in pairs(self.buttons) do if button.currentItem and button:IsShown() then button:UpdateCooldown() end end
        end
    elseif self.atBank and (event=="PLAYERBANKSLOTS_CHANGED" or event=="PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED") then
        local kind=self:BankType(self.storage)
        if (event=="PLAYERBANKSLOTS_CHANGED" and kind==Enum.BankType.Character)
            or (event=="PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED" and kind==Enum.BankType.Account) then
            local changed={}
            for _,bag in ipairs(self:GetScannedBags()) do changed[bag]=true end
            if next(changed) then self:QueueRefresh(changed) end
        end
    elseif self.atBank and (event=="PLAYER_EQUIPMENT_CHANGED" or event=="EQUIPMENT_SETS_CHANGED" or event=="TRANSMOG_COLLECTION_UPDATED" or event=="BANK_TABS_CHANGED" or event=="BANK_TAB_SETTINGS_UPDATED" or event=="PLAYER_ENTERING_WORLD") then
        if event=="PLAYER_EQUIPMENT_CHANGED" or event=="EQUIPMENT_SETS_CHANGED" or event=="TRANSMOG_COLLECTION_UPDATED" then self.invalidateTooltips=true end
        self:QueueRefresh()
    end
end

function A:ActivateBankScope(storage)
    if not self.isBankWindow then return end
    local scope=storage:match("^account") and "account" or "character"
    if self.bankScope==scope then return end
    self.database=self.bankRoot.scopes[scope]
    self.bankScope=scope
    self:InitializeDatabase()
    self.lastCategories=nil
    self:RefreshProfile()
end

function A:BeginBankLoad()
    self.bankLoadGeneration=(self.bankLoadGeneration or 0)+1
    self.bankLoadRetryCount=0; self.bankLoadRetryQueued=nil; self.bankLoading=nil
end

function A:ScheduleBankLoadRetry()
    if not self.atBank then return end
    local ids=self:GetBankContainers(self:BankType(self.storage))
    local missing=#ids>0 and ((self.capacity.total or 0)==0 or #self.items==0)
    for _,bag in ipairs(self:GetScannedBags()) do if C_Container.GetContainerNumSlots(bag)==0 then missing=true; break end end
    for _,item in ipairs(self.items or {}) do if item.pending then missing=true; break end end
    self.bankLoading=missing and (self.bankLoadRetryCount or 0)<6 or false
    if not self.bankLoading or self.bankLoadRetryQueued then return end
    local generation=self.bankLoadGeneration
    self.bankLoadRetryQueued=true
    self.bankLoadRetryCount=(self.bankLoadRetryCount or 0)+1
    C_Timer.After(0.2*self.bankLoadRetryCount,function()
        if generation~=self.bankLoadGeneration or not self.atBank then return end
        self.bankLoadRetryQueued=nil
        if not self.window:IsShown() then return end
        for id,state in pairs(self.itemRequests) do
            if state=="failed" then self.itemRequests[id]=nil; self.loading[id]=nil end
        end
        self:QueueRefresh()
    end)
end
