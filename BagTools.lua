local _, A = ...

-- Blizzard artwork and bag equipment APIs, following BetterBags' MIT bag controls.
function A:CreateBagMenuButton()
    local b = CreateFrame("Button", nil, self.window)
    self.bagMenuButton = b
    b:SetSize(40, 40)
    b:SetPoint("TOPLEFT", self.window, "TOPLEFT", -4, 7)
    -- Keep the bag button above the NineSlice border.
    b:SetFrameStrata("DIALOG")
    b:SetFrameLevel(self.window:GetFrameLevel() + 150)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local portrait = b:CreateTexture(nil, "OVERLAY")
    portrait:SetTexture("Interface\\Containerframe\\Bagslots2x")
    portrait:SetTexCoord(0, 0.2, 0, 1)
    portrait:SetSize(48, 60)
    portrait:SetPoint("CENTER")
    local highlight = b:CreateTexture(nil, "OVERLAY")
    highlight:SetTexture("Interface\\Containerframe\\Bagslots2x")
    highlight:SetTexCoord(0.2, 0.3992, 0, 1)
    highlight:SetSize(48, 60)
    highlight:SetPoint("CENTER", 2, 0)
    highlight:Hide()
    b:SetScript("OnEnter", function()
        highlight:Show()
        GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
        GameTooltip:SetText(A.L["Bolsas"])
        GameTooltip:AddLine(A.L["Clique: menu. Clique direito: alternar visualização por bolsa."], 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() highlight:Hide(); GameTooltip:Hide() end)
    b:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then self:ToggleBagSlots(); return end
        MenuUtil.CreateContextMenu(b, function(_, root)
            root:CreateCheckbox(A.L["Mostrar bolsas equipadas"], function()
                return self.physicalBagView == true
            end, function() self:ToggleBagSlots() end)
            root:CreateCheckbox(A.L["Mostrar nível dos equipamentos"], function()
                return self:GetSettings().showItemLevel ~= false
            end, function()
                local settings = self:GetSettings()
                settings.showItemLevel = settings.showItemLevel == false
                self:Render()
            end)
            root:CreateDivider()
            root:CreateButton(A.L["Configurações"], function() self:OpenGeneralSettings() end)
            root:CreateButton(A.L["Editar layout"], function() self:StartEdit() end)
            root:CreateButton(A.L["Moedas, indicadores e abas"], function() self:OpenSettings("features") end)
            if self.atBank and C_Bank and C_Bank.CanPurchaseBankTab then
                for _,kind in ipairs({Enum.BankType.Character,Enum.BankType.Account}) do
                    if C_Bank.CanPurchaseBankTab(kind) then
                        root:CreateButton(kind==Enum.BankType.Account and A.L["Comprar aba da tropa…"] or A.L["Comprar aba do banco…"],function() self:PurchaseBankTab(kind) end)
                    end
                end
            end
            if self.bulkAction then root:CreateButton(A.L["Interromper operação em lote"],function() self:CancelBulkAction() end) end
        end)
    end)
end

function A:BuildBagSlots()
    if self.bagSlots then return end
    local panel = CreateFrame("Frame", nil, self.window, "BackdropTemplate")
    self.bagSlots = panel
    panel:SetSize(230, 72)
    panel:SetPoint("BOTTOMLEFT", self.window, "TOPLEFT", 0, 10)
    panel:SetClampedToScreen(true)
    panel:SetFrameLevel(self.window:GetFrameLevel() + 30)
    panel:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Buttons\\WHITE8X8", edgeSize=1})
    panel:SetBackdropColor(0.08, 0.08, 0.08, 0.98)
    panel:SetBackdropBorderColor(0.4, 0.36, 0.28, 1)
    panel.buttons = {}
    local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    title:SetPoint("TOP", 0, -5)
    title:SetText(A.L["Bolsas equipadas"])
    for bag = 1, Enum.BagIndex.ReagentBag do
        local b = CreateFrame("ItemButton", nil, panel)
        panel.buttons[bag] = b
        b:SetSize(37, 37)
        b:SetPoint("TOPLEFT", 12 + (bag - 1) * 42, -20)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:RegisterForDrag("LeftButton")
        local bg = b:CreateTexture(nil, "BACKGROUND", "ItemSlotBackgroundCombinedBagsTemplate")
        bg:SetAllPoints(b)
        b.emptyBackground = bg
        local count = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        count:SetPoint("TOP", b, "BOTTOM", 0, -4)
        b.capacityLabel = count
        local function put()
            if not InCombatLockdown() then self.itemDrag = nil; PutItemInBag(b.inventoryID) end
        end
        local function pickup()
            if not InCombatLockdown() then self.itemDrag = nil; PickupBagFromSlot(b.inventoryID) end
        end
        b:SetScript("OnClick", function()
            if IsModifiedClick("PICKUPITEM") then pickup() else put() end
        end)
        b:SetScript("OnDragStart", pickup)
        b:SetScript("OnReceiveDrag", put)
        b:SetScript("OnEnter", function()
            GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
            if b.empty then
                GameTooltip:SetText(bag == Enum.BagIndex.ReagentBag and A.L["Slot da bolsa de reagentes"] or A.L["Slot de bolsa vazio"])
            else GameTooltip:SetInventoryItem("player", b.inventoryID) end
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
    panel:Hide()
end

function A:RefreshBagSlots()
    if not self.bagSlots or not self.bagSlots:IsShown() then return end
    for bag, b in ipairs(self.bagSlots.buttons) do
        b.inventoryID = C_Container.ContainerIDToInventoryID(bag)
        local texture = GetInventoryItemTexture("player", b.inventoryID)
        b.empty = not texture
        SetItemButtonTexture(b, texture)
        SetItemButtonQuality(b, GetInventoryItemQuality("player", b.inventoryID))
        b.emptyBackground:SetShown(b.empty)
        local total = C_Container.GetContainerNumSlots(bag)
        local free = C_Container.GetContainerNumFreeSlots(bag) or 0
        b.capacityLabel:SetText((total - free) .. "/" .. total)
        b.capacityLabel:SetTextColor(total > 0 and free == 0 and 1 or 0.85, free == 0 and total > 0 and 0.2 or 0.9, free == 0 and total > 0 and 0.2 or 0.94)
    end
end

function A:ToggleBagSlots()
    if InCombatLockdown() then return end
    if self.draft then self:Print(A.L["Salve ou cancele o layout antes de mostrar as bolsas."]); return end
    self:SetPhysicalBagView(not self.physicalBagView)
end

-- Physical-bag view leaves the saved category layout untouched.
function A:PhysicalBagGeometry()
    local width = math.max(280, (self.window:GetWidth() - 60) / 2)
    local cols = math.max(1, math.floor(width / 34))
    local heights = {0, 0}
    local bags=self:GetScannedBags()
    for index,bag in ipairs(bags) do
        local column = index<=math.ceil(#bags/2) and 1 or 2
        local slots = C_Container.GetContainerNumSlots(bag)
        if slots > 0 then heights[column] = heights[column] + 24 + math.ceil(slots / cols) * 34 + 12 end
    end
    return math.max(heights[1], heights[2]), width, cols
end

function A:SetPhysicalBagView(enabled)
    if InCombatLockdown() then return end
    enabled = enabled == true
    if enabled == (self.physicalBagView == true) then return end
    self:CancelInteractions()
    if enabled then
        self.categoryWindowSize = {width=self.window:GetWidth(), height=self.window:GetHeight()}
        self.physicalBagView = true
        self:BuildBagSlots()
        self.bagSlots:SetShown((self.storage or "bags")=="bags")
        self.window:SetSize(self.window:GetWidth(), math.max(400, self:PhysicalBagGeometry() + 124))
    else
        self.physicalBagView = false
        if self.bagSlots then self.bagSlots:Hide() end
        local size = self.categoryWindowSize
        self.categoryWindowSize = nil
        if size then self.window:SetSize(size.width, size.height) end
    end
    self:ResizeCanvas()
    self:Render()
    self:QueueRefresh()
end

function A:RenderPhysicalBags()
    self.physicalSections = self.physicalSections or {}
    local height, width, cols = self:PhysicalBagGeometry()
    if self.canvasHeight < height then self:ResizeCanvas() end
    local offsets = {0, 0}
    local search = (self.search:GetText() or ""):lower()
    if self.currencyBar then self.currencyBar:Hide() end
    self.searchHint:SetShown(search == "")
    self.searchClear:SetShown(search ~= "")
    self.searchPrevious:Hide(); self.searchNext:Hide(); self.searchNavigation:SetText("")
    self.renderSerial = (self.renderSerial or 0) + 1
    local bags=self:GetScannedBags()
    local drawn={}
    for bagIndex,bag in ipairs(bags) do
        drawn[bag]=true
        local panel = self.physicalSections[bag]
        if not panel then
            panel = CreateFrame("Frame", nil, self.canvas)
            panel.content = CreateFrame("Frame", nil, panel)
            panel.content:SetPoint("TOPLEFT", 0, -24)
            panel.bagParents = {}
            panel.wheel = function() end
            panel.title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            panel.title:SetPoint("TOPLEFT", 0, -3)
            self.physicalSections[bag] = panel
        end
        local count = C_Container.GetContainerNumSlots(bag)
        local column = bagIndex<=math.ceil(#bags/2) and 1 or 2
        local sectionHeight = 24 + math.ceil(count / cols) * 34 + 12
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", (column - 1) * (width + 20), -offsets[column])
        panel:SetSize(width, sectionHeight)
        panel.content:SetSize(width, math.max(1, sectionHeight - 24))
        local name = C_Container.GetBagName and C_Container.GetBagName(bag) or nil
        panel.title:SetText("#" .. bagIndex .. ": " .. (name or (bag == 0 and A.L["Mochila"] or bag == Enum.BagIndex.ReagentBag and A.L["Bolsa de reagentes"] or A.L["Bolsa"])))
        panel:SetShown(count > 0)
        if count > 0 then offsets[column] = offsets[column] + sectionHeight end
        for slot = 1, count do
            local model = self.slotModels and self.slotModels[bag .. ":" .. slot]
            if model then
                local b = self:GetItemButton(model, panel)
                local x, y = ((slot - 1) % cols) * 34, math.floor((slot - 1) / cols) * 34
                b.anchorCategory, b.anchorIndex, b.anchorSlotKey = nil, nil, model.slotKey
                b.renderSerial = self.renderSerial
                if b.renderSize ~= 32 then b:SetSize(32,32); b.renderSize=32 end
                if b.renderPanel ~= panel or b.renderX ~= x or b.renderY ~= y then
                    b:ClearAllPoints(); b:SetPoint("TOPLEFT",panel.content,"TOPLEFT",x,-y)
                    b.renderPanel,b.renderX,b.renderY=panel,x,y
                end
                if model.info then self:PaintItem(b,model,search)
                else self:PaintEmpty(b,model,panel,slot) end
                b.anchorCategory, b.anchorIndex = nil, nil
                b:Show()
            end
        end
    end
    for bag,panel in pairs(self.physicalSections) do if not drawn[bag] then panel:Hide() end end
    for _,b in pairs(self.buttons) do if b.renderSerial ~= self.renderSerial then b:Hide(); b.currentItem=nil end end
    self.forceItemPaint=nil
    local c=self.capacity
    if c then self.status:SetText(string.format(A.L["Livres: %d/%d  |  Reagentes livres: %d/%d"],c.free,c.total,c.reagentFree,c.reagentTotal)) end
    self.money:SetText(GetCoinTextureString(GetMoney()))
end
