local _, A = ...
local backdrop = {
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 32, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function box(frame, r, g, b)
    frame:SetBackdrop(backdrop)
    frame:SetBackdropColor(r or 1, g or 1, b or 1, 0.98)
    frame:SetBackdropBorderColor(0.65, 0.57, 0.42, 1)
end

local function label(parent, text, size)
    local font = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if size then font:SetFont(STANDARD_TEXT_FONT, size) end
    font:SetText(text)
    font:SetTextColor(0.85, 0.9, 0.94)
    return font
end

local function button(parent, text, width, action)
    local b = CreateFrame("Button", nil, parent, "BackdropTemplate")
    b:SetSize(width, 24)
    A:StyleCommand(b,text)
    b:SetScript("OnClick", action)
    b:SetScript("OnMouseDown",function() if parent.blockOwner then parent.blockOwner:FocusWindow() end end)
    return b
end

local function iconButton(parent, texture, title, description, action)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(18, 18)
    b:SetNormalTexture(texture)
    b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    b:SetAlpha(0.7)
    b:SetScript("OnClick", action)
    b:SetScript("OnMouseDown",function() if parent.blockOwner then parent.blockOwner:FocusWindow() end end)
    b:SetScript("OnEnter", function()
        b:SetAlpha(1)
        GameTooltip:SetOwner(b, "ANCHOR_TOP")
        GameTooltip:SetText(title)
        GameTooltip:AddLine(description, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() b:SetAlpha(0.7); GameTooltip:Hide() end)
    return b
end

function A:FocusWindow()
    if InCombatLockdown() or not self.window then return end
    local inventory=self.inventoryController or self
    local other=self.isBankWindow and inventory or inventory.bankController
    if other and other.window then other.window:SetFrameLevel(100); other:UpdateHeaderLayers() end
    self.window:SetFrameLevel(1200)
    self:UpdateHeaderLayers()
end

function A:BuildUI()
    self:InstallInteractionHooks()
    self.canvasWidth, self.canvasHeight = 880, 600
    self.panels, self.buttons = {}, {}
    self.windowName=self.windowName or "BlockBagsWindow"
    local w = CreateFrame("Frame", self.windowName, UIParent, self.isBankWindow and "BackdropTemplate" or "BackdropTemplate,SecureHandlerBaseTemplate")
    self.window = w
    w.blockOwner=self
    w:SetSize(self.profile.window.width or 912, self.profile.window.height or 716)
    w:SetFrameStrata("HIGH")
    w:SetToplevel(true)
    w:SetFrameLevel(100)
    w:HookScript("OnMouseDown",function() self:FocusWindow() end)
    box(w)
    w:SetBackdrop({ bgFile = backdrop.bgFile, edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 11, top = 11, bottom = 11 } })
    w:SetBackdropColor(1, 1, 1, 1)
    w:SetBackdropBorderColor(1, 1, 1, 1)
    self:DecorateInventory()
    w:SetClampedToScreen(true)
    w:SetMovable(true)
    w:SetResizable(false)
    w:SetResizeBounds(560, 400, 2000, 1600)
    w:SetScale(self.profile.window.scale)
    w:SetPoint("CENTER", UIParent, "CENTER", self.profile.window.x, self.profile.window.y)
    w:Hide()
    UISpecialFrames[#UISpecialFrames + 1] = self.windowName
    self:CreateBagMenuButton()
    local move = CreateFrame("Frame", nil, w)
    self.titleDrag=move
    move:SetPoint("TOPLEFT", 10, 0)
    move:SetPoint("TOPRIGHT", -32, 0)
    move:SetHeight(38)
    move:EnableMouse(true)
    move:SetScript("OnMouseDown",function() self:FocusWindow() end)
    move:RegisterForDrag("LeftButton")
    move:SetScript("OnDragStart", function() if not InCombatLockdown() then w:StartMoving() end end)
    move:SetScript("OnDragStop", function()
        if InCombatLockdown() then self.pendingRefresh=true; return end
        w:StopMovingOrSizing()
        local x, y = w:GetCenter()
        local scale = w:GetEffectiveScale() / UIParent:GetEffectiveScale()
        self.profile.window.x = x * scale - UIParent:GetWidth() / 2
        self.profile.window.y = y * scale - UIParent:GetHeight() / 2
        w:ClearAllPoints()
        w:SetPoint("CENTER", UIParent, "CENTER", self.profile.window.x / scale, self.profile.window.y / scale)
        -- Store offsets in the window's own coordinate space.
        self.profile.window.x, self.profile.window.y = self.profile.window.x / scale, self.profile.window.y / scale
    end)
    local close = CreateFrame("Button", nil, w, self.isBankWindow and "UIPanelCloseButton" or "UIPanelCloseButton,SecureHandlerBaseTemplate")
    self.closeButton=close
    close:SetFrameStrata("HIGH")
    close:SetFrameLevel(w:GetFrameLevel()+150)
    close:SetSize(24,24)
    close:SetPoint("TOPRIGHT", -4, -2)
    close:SetScript("OnClick",function() if not InCombatLockdown() then w:Hide() end end)
    close:Show()

    self.search = CreateFrame("EditBox", nil, w, "InputBoxTemplate")
    self.search:SetSize(400, 24)
    self.search:SetPoint("TOPLEFT", 24, -48)
    self.search:SetAutoFocus(false)
    self.search:HookScript("OnMouseDown",function() self:FocusWindow() end)
    self.search:SetMaxLetters(256)
    self.search:SetScript("OnEscapePressed", function(edit) edit:SetText(""); edit:ClearFocus() end)
    self.search:SetScript("OnEnterPressed", function(edit) edit:ClearFocus() end)
    self.search:SetScript("OnTextChanged", function() if self.ready then self:Render() end end)
    self.searchHint = label(self.search, A.L["Buscar itens…"], 12)
    self.searchHint:SetPoint("LEFT", 5, 0)
    self.search:SetTextInsets(5, 25, 0, 0)
    self.searchClear = CreateFrame("Button", nil, self.search, "UIPanelCloseButton")
    self.searchClear:SetSize(20, 20)
    self.searchClear:SetPoint("RIGHT", -2, 0)
    self.searchClear:SetScript("OnClick", function() self.search:SetText(""); self.search:ClearFocus() end)
    self.editButton = button(w, A.L["Editar layout"], 112, function() self:StartEdit() end)
    self.editButton:SetPoint("TOPRIGHT", -24, -48)
    self.saveButton = button(w, A.L["Salvar"], 75, function() self:FinishEdit(true) end)
    self.saveButton:SetPoint("TOPRIGHT", -24, -48)
    self.cancelButton = button(w, A.L["Cancelar"], 85, function() self:FinishEdit(false) end)
    self.cancelButton:SetPoint("RIGHT", self.saveButton, "LEFT", -6, 0)
    self.generalButton = button(w, A.L["Configurações"], 110, function() self:OpenGeneralSettings() end)
    self.generalButton:SetPoint("RIGHT", self.cancelButton, "LEFT", -6, 0)
    self.undoButton = iconButton(w, "Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up", A.L["Desfazer"], A.L["Desfaz o último ajuste do editor (até 50 etapas)."], function() self:UndoEdit() end)
    self.undoButton:SetPoint("RIGHT", self.generalButton, "LEFT", -5, 0)
    for _,control in ipairs({self.generalButton,self.cancelButton,self.saveButton,self.editButton,self.undoButton}) do
        control:SetFrameLevel(w:GetFrameLevel()+20)
    end
    self.searchNavigation=label(w,"",11)
    self.searchNavigation:SetWidth(42)
    self.searchNext=button(w,">",24,function() self:NavigateSearch(1) end)
    self.searchPrevious=button(w,"<",24,function() self:NavigateSearch(-1) end)
    self.searchPrevious:SetPoint("LEFT",self.search,"RIGHT",6,0)
    self.searchNext:SetPoint("LEFT",self.searchPrevious,"RIGHT",3,0)
    self.searchNavigation:SetPoint("LEFT",self.searchNext,"RIGHT",4,0)
    self.search:SetScript("OnEnterPressed",function(edit) edit:ClearFocus(); self:NavigateSearch(1) end)
    self.search:SetScript("OnTextChanged",function()
        self.searchResultIndex=0; self.focusedSearchIdentity=nil
        if self.ready then self:Render() end
    end)
    self.seenButton = iconButton(w, "Interface\\Buttons\\UI-CheckBox-Check", A.L["Marcar todos como vistos"], A.L["Remove o destaque de novos itens sem reorganizar as categorias."], function()
        for _, item in ipairs(self.items or {}) do C_NewItems.RemoveNewItem(item.bag, item.slot) end
        self:Render()
    end)
    self.seenButton:SetFrameLevel(w:GetFrameLevel()+20)
    self.lockButton=iconButton(w,"Interface\\Buttons\\LockButton-Locked-Up",A.L["Bloquear layout"],
        A.L["Permite ou bloqueia arrastar categorias pelo cabeçalho. Clique direito no cabeçalho abre suas opções."],function() self:ToggleLayoutLock() end)
    self.lockButton:SetFrameLevel(w:GetFrameLevel()+20)
    self.lockButton:SetPoint("RIGHT",self.seenButton,"LEFT",-5,0)

    self.viewport = CreateFrame("ScrollFrame", nil, w)
    self.viewport:SetPoint("TOPLEFT", 16, -78)
    self.viewport:SetPoint("BOTTOMRIGHT", -24, 46)
    self.canvas = CreateFrame("Frame", nil, self.viewport)
    self.canvas:SetSize(self.canvasWidth, self.canvasHeight)
    if self.UpdateEditorGrid then self:UpdateEditorGrid() end
    self.viewport:SetScrollChild(self.canvas)
    self.windowScrollY = self:CreateWindowScrollBar(true)
    self.windowScrollX = self:CreateWindowScrollBar(false)
    self.viewport:EnableMouseWheel(true)
    self.viewport:SetScript("OnMouseWheel", function(_, delta)
        if InCombatLockdown() then return end
        local bar = IsShiftKeyDown() and self.windowScrollX or self.windowScrollY
        local lo, hi = bar:GetMinMaxValues()
        bar:SetValue(math.max(lo, math.min(hi, bar:GetValue() - delta * self.cell)))
    end)
    for _, cat in ipairs(self.categories) do self:CreatePanel(cat) end
    self.status = label(w, "", 13)
    self.status:SetPoint("BOTTOMLEFT", 16, 15)
    self.status:SetWidth(580)
    self.status:SetJustifyH("LEFT")
    self.money = label(w, "", 13)
    self.money:SetPoint("BOTTOMRIGHT", -38, 15)
    self.money:SetJustifyH("RIGHT")
    local resize = CreateFrame("Button", nil, w)
    self.windowResize = resize
    resize:SetSize(24, 24)
    resize:SetPoint("BOTTOMRIGHT", -7, 7)
    resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resize:SetScript("OnMouseDown", function(_, key)
        if key == "LeftButton" and self.draft and not InCombatLockdown() then self:PushUndo(); w:StartSizing("BOTTOMRIGHT") end
    end)
    resize:SetScript("OnMouseUp", function()
        if InCombatLockdown() then self.pendingRefresh=true; return end
        w:StopMovingOrSizing()
        self:ResizeCanvas()
    end)
    w:SetScript("OnSizeChanged", function()
        if self.windowScrollY and not InCombatLockdown() then self:ResizeCanvas() end
    end)
    self.combatOverlay = CreateFrame("Frame", nil, w, "BackdropTemplate")
    self.combatOverlay:SetPoint("TOPLEFT", 1, -38)
    self.combatOverlay:SetPoint("BOTTOMRIGHT", -1, 1)
    self.combatOverlay:SetFrameLevel(w:GetFrameLevel() + 100)
    self.combatOverlay:EnableMouse(true)
    self.combatOverlay:EnableMouseWheel(true)
    box(self.combatOverlay)
    self.combatOverlay:SetBackdropColor(0.04, 0.05, 0.06, 0.85)
    label(self.combatOverlay, A.L["Inventário pausado durante o combate.\nAs atualizações serão aplicadas ao sair de combate."], 14):SetPoint("CENTER")
    self.combatOverlay:Hide()
    w:SetScript("OnShow", function()
        self:FocusWindow(); self:PlayBackpackSound(true)
        if InCombatLockdown() then self:PaintCombatInventory(); return end
        self.forceItemPaint=true; self:QueueRefresh()
    end)
    w:SetScript("OnHide", function()
        if self.openingSettings and not InCombatLockdown() then w:Show(); return end
        self:PlayBackpackSound(false)
        self:CancelBulkAction()
        if self.physicalBagView and not InCombatLockdown() then self:SetPhysicalBagView(false) end
        if self.bagSlots and not InCombatLockdown() then self.bagSlots:Hide() end
        if self.isBankWindow and self.atBank and not self.closingBank and C_Bank and C_Bank.CloseBankFrame then
            self.closingBank=true; C_Bank.CloseBankFrame(); self.closingBank=nil
        end
        self:CancelInteractions()
        if self.draft then self:FinishEdit(false) end
        for _,panel in pairs(self.panels) do panel:SetScript("OnUpdate",nil); panel.drag=nil end
    end)
    self:ResizeCanvas()
    self:ApplyLayout()
    self:UpdateHeaderLayers()
    self:BuildCombatControls()
end

function A:CreateWindowScrollBar(vertical)
    local bar = CreateFrame("Slider", nil, self.window, "OptionsSliderTemplate")
    bar:SetFrameLevel(self.window:GetFrameLevel() + 30)
    bar:SetOrientation(vertical and "VERTICAL" or "HORIZONTAL")
    if vertical then
        bar:SetWidth(12)
        bar:SetPoint("TOPRIGHT", -9, -82)
        bar:SetPoint("BOTTOMRIGHT", -9, 48)
    else
        bar:SetHeight(12)
        bar:SetPoint("BOTTOMLEFT", 20, 31)
        bar:SetPoint("BOTTOMRIGHT", -26, 31)
    end
    if bar.Low then bar.Low:Hide() end
    if bar.High then bar.High:Hide() end
    if bar.Text then bar.Text:Hide() end
    bar:SetMinMaxValues(0, 0)
    bar:SetValueStep(1)
    bar:SetValue(0)
    bar:SetScript("OnValueChanged", function(_, value)
        if InCombatLockdown() then return end
        if vertical then self.viewport:SetVerticalScroll(value)
        else self.viewport:SetHorizontalScroll(value) end
    end)
    return bar
end

function A:ResizeCanvas()
    if self.resizingCanvas then return end
    self.resizingCanvas=true
    local neededWidth, neededHeight = 0, 0
    for id, data in pairs(self:GetLayout()) do
        if self:CategoryDisplayed(id) then
            local x, y, w, h = self:PanelRect(data)
            neededWidth, neededHeight = math.max(neededWidth, x + w), math.max(neededHeight, y + h)
        end
    end
    if self.physicalBagView then neededWidth, neededHeight = 0, self:PhysicalBagGeometry() end
    local toolbar=self:BankToolbarExtra()
    self.viewport:SetPoint("TOPLEFT",16,-78-toolbar)
    local extra=self.physicalBagView and 0 or self:FooterExtra()
    local minWidth,minHeight=math.max(650,math.ceil(neededWidth+40)),math.max(400,math.ceil(neededHeight+124+extra+toolbar))
    if self.isBankWindow then minWidth=math.max(minWidth,#self:GetBankContainers(self:BankType(self.storage))*28+144) end
    self.window:SetResizeBounds(minWidth,minHeight,math.max(2000,minWidth),math.max(1600,minHeight))
    if self.window:GetWidth()<minWidth or self.window:GetHeight()<minHeight then
        self.window:SetSize(math.max(minWidth,self.window:GetWidth()),math.max(minHeight,self.window:GetHeight()))
    end
    self.canvasWidth,self.canvasHeight=self.window:GetWidth()-40,self.window:GetHeight()-124-extra-toolbar
    self.viewport:SetPoint("BOTTOMRIGHT",-24,46+extra)
    self.canvas:SetSize(self.canvasWidth, self.canvasHeight)
    for _,bar in ipairs({self.windowScrollX,self.windowScrollY}) do
        bar:SetMinMaxValues(0,0); bar:SetValue(0); bar:Hide()
    end
    self.status:SetWidth(math.max(260, self.window:GetWidth() - 250))
    self:LayoutToolbar()
    self.searchHint:SetShown((self.search:GetText() or "") == "")
    self.resizingCanvas=false
end

function A:LayoutToolbar()
    if not self.generalButton then return end
    self.generalButton:Hide(); self.editButton:Hide()
    self.undoButton:ClearAllPoints(); self.undoButton:SetPoint("RIGHT",self.cancelButton,"LEFT",-6,0)
    self.seenButton:ClearAllPoints(); self.seenButton:SetPoint("TOPRIGHT",self.window,"TOPRIGHT",-26,-50)
    local toolbarWidth=self.draft and 200 or 50
    if self.storageSelector then self.storageSelector:SetShown(self.isBankWindow==true and self.atBank==true and not self.draft); if self.isBankWindow and self.atBank then toolbarWidth=toolbarWidth+150 end end
    self.search:SetWidth(math.max(150,self.window:GetWidth()-toolbarWidth-140))
end

function A:CreatePanel(category)
    local reused=self.panelPool and table.remove(self.panelPool)
    if reused then
        reused.id,reused.offset=category.id,0
        reused.blockCategory=category.id
        self.panels[category.id]=reused
        return reused
    end
    local panel = CreateFrame("Frame", nil, self.canvas, "BackdropTemplate")
    panel.id = category.id
    panel.blockCategory=category.id
    panel.offset = 0
    panel.blockOwner=self
    panel.cells, panel.bagParents = {}, {}
    box(panel, 0.8, 0.8, 0.8)
    panel.tintBackground=panel:CreateTexture(nil,"BACKGROUND",nil,1)
    panel.tintBackground:SetPoint("TOPLEFT",5,-5)
    panel.tintBackground:SetPoint("BOTTOMRIGHT",-5,5)
    panel.tintBackground:Hide()
    panel.favoriteGhosts={}
    panel.dropSlot=false
    panel.dropGlow=CreateFrame("Frame",nil,panel,"BackdropTemplate")
    panel.dropGlow:SetAllPoints(panel)
    panel.dropGlow:SetFrameLevel(panel:GetFrameLevel()+10)
    panel.dropGlow:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=2})
    panel.dropGlow:EnableMouse(false); panel.dropGlow:Hide()
    self.panels[category.id] = panel
    panel.title = label(panel, category.name, 12)
    panel.title:SetPoint("TOPLEFT", 8, -8)
    panel.title:SetJustifyH("LEFT")
    panel.count = label(panel, "", 11)
    panel.count:SetPoint("TOPRIGHT", -8, -9)
    panel.organize = iconButton(panel, "Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up", A.L["Organizar esta categoria"], A.L["Ordena por nome e fecha os espaços uma vez. Não muda o modo de organização nem combina pilhas."], function()
        if InCombatLockdown() then self:Print(A.L["Aguarde o fim do combate."]); return end
        self.organizeCategory = panel.id
        self:Reconcile()
        self:Render()
    end)
    panel.organize:SetPoint("TOPLEFT", 8, -24)
    panel.mode = iconButton(panel, "Interface\\Buttons\\UI-CheckBox-Up", A.L["Posições fixas ou automáticas"], A.L[self.isBankWindow and "F: mantém posições fixas. A: ordena por nome e fecha espaços automaticamente nesta categoria. Itens soltos manualmente mantêm o slot até organizar ou alternar novamente." or "F: mantém posições fixas. A: ordena por nome e fecha espaços automaticamente nesta categoria. Favoritos ficam reservados nos dois modos. Itens soltos manualmente mantêm o slot até organizar ou alternar novamente."], function()
        self:SetCategoryOption(panel.id,"compact",not self:GetLayout()[panel.id].compact)
    end)
    panel.mode:SetPoint("LEFT", panel.organize, "RIGHT", 4, 0)
    panel.mode:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    panel.mode.stateLabel=label(panel.mode,"F",11)
    panel.mode.stateLabel:SetPoint("CENTER")
    panel.customize = iconButton(panel, "Interface\\Icons\\Trade_Engineering", A.L["Personalizar categoria"], A.L["Ajuste o tamanho e o espaçamento dos itens. As alterações só são persistidas ao salvar o layout."], function() self:OpenCustomization(panel.id) end)
    panel.customize:SetPoint("LEFT", panel.mode, "RIGHT", 4, 0)

    panel.scroll = CreateFrame("ScrollFrame", nil, panel)
    panel.scroll:SetPoint("TOPLEFT", 8, -(self.header + self.padding))
    panel.content = CreateFrame("Frame", nil, panel.scroll)
    panel.scroll:SetScrollChild(panel.content)
    -- Place the scrollbar in the 8px border to preserve the item grid width.
    panel.bar = CreateFrame("Slider", nil, panel, "BackdropTemplate")
    panel.bar:SetOrientation("VERTICAL")
    panel.bar:SetWidth(8)
    panel.bar:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
    panel.bar:SetBackdropColor(0.05,0.05,0.05,0.65)
    panel.bar:SetThumbTexture("Interface\\Buttons\\WHITE8X8")
    local thumb=panel.bar:GetThumbTexture()
    if thumb then thumb:SetSize(8,24); thumb:SetVertexColor(0.75,0.65,0.4,0.9) end
    panel.bar:SetFrameLevel(panel:GetFrameLevel() + 30)
    panel.bar:SetPoint("TOPRIGHT", 0, -(self.header + self.padding))
    panel.bar:SetPoint("BOTTOMRIGHT", 0, 8)
    panel.bar:SetValueStep(1)
    if panel.bar.Low then panel.bar.Low:Hide() end
    if panel.bar.High then panel.bar.High:Hide() end
    if panel.bar.Text then panel.bar.Text:Hide() end
    panel.bar:SetScript("OnValueChanged", function(_, value)
        if InCombatLockdown() then return end
        panel.offset = value
        panel.scroll:SetVerticalScroll(value)
    end)
    panel.wheel = function(_, delta)
        if InCombatLockdown() then return end
        local _, maximum = panel.bar:GetMinMaxValues()
        local metrics = panel.currentMetrics or self:ItemMetrics(self:GetLayout()[panel.id])
        panel.bar:SetValue(math.max(0, math.min(maximum, panel.offset - delta * metrics.step)))
    end
    panel.scroll:EnableMouseWheel(true)
    panel.scroll:SetScript("OnMouseWheel", panel.wheel)

    panel.move = CreateFrame("Frame", nil, panel)
    panel.move:SetScript("OnMouseDown",function() self:FocusWindow() end)
    panel.move:SetPoint("TOPLEFT")
    panel.move:SetPoint("TOPRIGHT")
    panel.move:SetHeight(22)
    panel.move:EnableMouse(true)
    panel.move:RegisterForDrag("LeftButton")
    panel.move:SetScript("OnDragStart", function() self:BeginQuickMove(panel) end)
    panel.move:SetScript("OnDragStop", function() self:EndQuickMove(panel) end)
    local receive=function() self:DropIntoCategory(panel.id) end
    local click=function(_,button) if button=="LeftButton" and CursorHasItem() then receive() end end
    -- Receive drops on unused category space, below item buttons and controls.
    -- Container frames pass clicks through to this button.
    panel.dropTarget=CreateFrame("Button",nil,panel)
    panel.dropTarget:SetAllPoints(panel)
    panel.dropTarget:SetFrameLevel(panel:GetFrameLevel())
    panel.dropTarget:RegisterForClicks("LeftButtonUp")
    panel.dropTarget:RegisterForDrag("LeftButton")
    panel.dropTarget:SetScript("OnReceiveDrag",receive)
    panel.dropTarget:SetScript("OnClick",click)
    panel.dropTarget:SetScript("OnEnter",function() self:ShowCategoryDropHint(panel.id) end)
    panel.dropTarget:SetScript("OnLeave",function() self:HideCategoryDropHint() end)
    panel.dropTarget:EnableMouse(true)
    panel:EnableMouse(false)
    panel.content:EnableMouse(false)
    panel.scroll:SetMouseClickEnabled(false)
    panel.move:SetScript("OnReceiveDrag",receive)
    panel.move:SetScript("OnEnter",function() self:ShowCategoryDropHint(panel.id) end)
    panel.move:SetScript("OnLeave",function() self:HideCategoryDropHint() end)
    panel.move:SetScript("OnMouseUp",function(frame,key)
        if key=="RightButton" and not CursorHasItem() then self:OpenCategoryMenu(panel)
        else click(frame,key) end
    end)
    panel.resize = CreateFrame("Button", nil, panel)
    panel.resize:SetSize(24, 24)
    panel.resize:SetPoint("BOTTOMRIGHT",-1,1)
    panel.resize:SetFrameLevel(panel:GetFrameLevel() + 20)
    panel.resize:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    panel.resize:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    panel.resize:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    panel.resize:SetScript("OnEnter",function()
        GameTooltip:SetOwner(panel.resize,"ANCHOR_TOP")
        GameTooltip:SetText(A.L["Redimensionar categoria"])
        GameTooltip:AddLine(A.L["Arraste para encaixar o tamanho nos slots. Segure Shift para ajustar livremente."],1,1,1,true)
        GameTooltip:Show()
    end)
    panel.resize:SetScript("OnLeave",function() GameTooltip:Hide() end)
    panel.resize:RegisterForDrag("LeftButton")
    panel.resize:SetScript("OnDragStart", function() self:BeginPanelDrag(panel, true) end)
    panel.resize:SetScript("OnDragStop", function() self:EndPanelDrag(panel) end)
end

function A:ApplyLayout()
    self:ApplyWindowTheme()
    local layout = self:GetLayout()
    for _, cat in ipairs(self.categories) do
        local panel, data = self.panels[cat.id], layout[cat.id]
        panel:SetShown(self:CategoryDisplayed(cat.id) and not self.physicalBagView)
        panel.title:SetText(self:CategoryName(cat.id))
        local x, y, width, height = self:PanelRect(data)
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", x, -y)
        panel:SetSize(width, height)
        panel.title:SetWidth(width - 66)
        local metrics = self:ItemMetrics(data)
        panel.scroll:SetSize(metrics.width, metrics.height)
        panel.content:SetWidth(metrics.width)
        panel.move:EnableMouse(true)
        panel.resize:SetShown(self.draft ~= nil)
        panel.organize:SetEnabled(not self.draft)
        panel.mode.stateLabel:SetText(data.compact and "A" or "F")
        panel.customize:Show()
        panel:SetBackdropBorderColor(self.draft and 0.34 or 0.65, self.draft and 0.75 or 0.57, self.draft and 0.72 or 0.42, 1)
        self:StyleCategory(panel,data)
    end
    self.saveButton:SetShown(self.draft ~= nil)
    self.cancelButton:SetShown(self.draft ~= nil)
    self.generalButton:Hide()
    self:LayoutToolbar()
    self.undoButton:SetShown(self.draft ~= nil)
    self.seenButton:SetShown(self.draft == nil)
    self.editButton:Hide()
    self.windowResize:SetShown(self.draft ~= nil)
    self.window:SetResizable(self.draft ~= nil)
    self.lockButton:SetShown(self.draft==nil and not self.physicalBagView)
    self.lockButton:SetAlpha(self:GetSettings().layoutLocked and 1 or 0.45)
    self.lockButton:SetNormalTexture(self:GetSettings().layoutLocked and "Interface\\Buttons\\LockButton-Locked-Up" or "Interface\\Buttons\\LockButton-Unlocked-Up")
    self:UpdateEditorGrid()
end

function A:StartEdit()
    if InCombatLockdown() then self:Print(A.L["O editor fica disponível fora de combate."]); return end
    if self.draft then return end
    if self.physicalBagView then self:SetPhysicalBagView(false) end
    self:CancelInteractions()
    self.draft = self:Copy(self:GetBaseLayout())
    self.undoStack={}
    self.draftSettings = self:Copy(self:GetSettings())
    self.windowDraft = { width = self.window:GetWidth(), height = self.window:GetHeight() }
    self:ApplyLayout()
    self:Render()
    self:Print(A.L["Arraste o cabeçalho e redimensione pelo canto. Verde: válido; vermelho: ocupado. Salve para confirmar."])
end

function A:CreateEditorDialog(title, height)
    for _,key in ipairs({"customization","generalSettings","profileChooser","favoriteDialog","itemActions"}) do
        if self[key] then self[key]:Hide() end
    end
    local f = CreateFrame("Frame", nil, self.window, "BackdropTemplate")
    f:SetSize(340, height)
    f:SetPoint("CENTER", self.window, "CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(self.window:GetFrameLevel() + 60)
    f:EnableMouse(true)
    box(f)
    f.title = label(f, title, 14)
    f.title:SetWidth(280)
    f.title:SetWordWrap(false)
    f.title:SetPoint("TOPLEFT", 14, -14)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -1, -1)
    close:SetScript("OnClick", function() f:Hide() end)
    return f
end

function A:CreateSettingSlider(parent, y, minimum, maximum, step, onChange)
    -- Keep the slider value API for existing settings controls.
    local slider = CreateFrame("Frame", nil, parent)
    slider:SetPoint("TOPLEFT", 20, y)
    slider:SetSize(290, 18)
    slider.input=CreateFrame("EditBox",nil,slider,"InputBoxTemplate")
    slider.input:SetSize(110,24); slider.input:SetPoint("LEFT",40,0)
    slider.input:SetAutoFocus(false); slider.input:SetNumeric(true)
    slider.number=minimum
    slider.GetValue=function(control) return control.number end
    slider.SetValue=function(control,value)
        value=tonumber(value) or control.number
        value=math.max(minimum,math.min(maximum,minimum+math.floor((value-minimum)/step+0.5)*step))
        local changed=control.number~=value
        control.number=value; control.input:SetText(tostring(value))
        if changed and not parent.initializing and not self.settingsInitializing then onChange(value) end
    end
    slider.minus=button(slider,"−",28,function() slider:SetValue(slider.number-step) end)
    slider.minus:SetPoint("LEFT",0,0)
    slider.plus=button(slider,"+",28,function() slider:SetValue(slider.number+step) end)
    slider.plus:SetPoint("LEFT",slider.input,"RIGHT",8,0)
    slider.SetAvailable=function(control,enabled)
        control.minus:SetEnabled(enabled); control.plus:SetEnabled(enabled)
        control.input:EnableMouse(enabled)
        if not enabled then control.input:ClearFocus() end
        control.caption:SetTextColor(enabled and 0.85 or 0.5,enabled and 0.9 or 0.5,enabled and 0.94 or 0.5)
    end
    slider.input:SetScript("OnEnterPressed",function(edit) slider:SetValue(edit:GetText()); edit:ClearFocus() end)
    slider.input:SetScript("OnEditFocusLost",function(edit) slider:SetValue(edit:GetText()) end)
    slider.input:SetScript("OnEscapePressed",function(edit) edit:SetText(tostring(slider.number)); edit:ClearFocus() end)
    slider.caption = label(parent, "", 12)
    slider.caption:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 8)
    return slider
end

function A:FinishEdit(save)
    if InCombatLockdown() then
        self.pendingEditCancel=self.windowDraft or {}
        self.draft,self.draftSettings,self.windowDraft=nil,nil,nil
        self.undoStack={}
        for _,panel in pairs(self.panels) do panel:SetScript("OnUpdate",nil); panel.drag=nil end
        self.pendingRefresh=true
        return
    end
    self:HideEditorVisuals()
    if self.editorGrid then self.editorGrid:Hide() end
    for _, panel in pairs(self.panels) do panel:SetScript("OnUpdate", nil); panel.drag = nil end
    self.window:StopMovingOrSizing()
    if save and self.draft then
        local previous=self:GetBaseLayout()
        for id,data in pairs(self.draft) do
            if data.compact and previous[id] and not previous[id].compact then
                self:ReleaseCategoryDropSlots(id)
            end
        end
        self:SetBaseLayout(self.draft)
        self.profile.settings = self.draftSettings
        self.profile.window.width, self.profile.window.height = self.window:GetWidth(), self.window:GetHeight()
    elseif self.windowDraft then
        self.window:SetSize(self.windowDraft.width, self.windowDraft.height)
    end
    self.windowDraft = nil
    if self.customization then self.customization:Hide() end
    if self.generalSettings then self.generalSettings:Hide() end
    self.draft = nil
    self.draftSettings = nil
    self.undoStack={}
    if self.visibilityChanged then
        for _,item in ipairs(self.items or {}) do item.category=self:Classify(item) end
        self.visibilityChanged=nil
    end
    if self.profileChooser then self.profileChooser:Hide() end
    if InCombatLockdown() then self.pendingRefresh = true; return end
    self:ResizeCanvas()
    self:ApplyLayout()
    self:Reconcile()
    self:Render()
end

function A:BeginPanelDrag(panel, resize)
    if not self.draft or InCombatLockdown() then return end
    local x, y = GetCursorPosition()
    local original=self:Copy(self.draft[panel.id])
    local _,_,width,height=self:PanelRect(original)
    panel.drag = { x = x, y = y, original = original, width=width,height=height,resize = resize,snap={} }
    panel:SetScript("OnUpdate", function()
        local drag = panel.drag
        if not drag then return end
        local cx, cy = GetCursorPosition()
        local scale = self.canvas:GetEffectiveScale()
        local dx = math.floor((cx - drag.x) / scale + 0.5)
        local dy = math.floor((drag.y - cy) / scale + 0.5)
        local free=IsShiftKeyDown()
        if drag.lastDX==dx and drag.lastDY==dy and drag.free==free then return end
        drag.lastDX,drag.lastDY,drag.free=dx,dy,free
        if free then drag.snap.x,drag.snap.y=nil,nil end
        local candidate = self:Copy(drag.original)
        if drag.resize then
            local minW,minH=self:MinimumPanelSize(candidate)
            candidate.width = math.max(minW, drag.width + dx)
            candidate.height = math.max(minH, drag.height + dy)
            if not free then
                self:SnapResize(panel.id,candidate,drag.snap)
                self:SnapResizeToSlots(panel.id,candidate)
            end
        else
            candidate.x = math.max(0, drag.original.x + dx/self.cell)
            candidate.y = math.max(0, drag.original.y + dy/self.cell)
            if not free then self:SnapPanel(panel.id,candidate,drag.snap) end
        end
        drag.candidate, drag.valid = candidate, self:CanPlace(panel.id, candidate)
        local px, py, width, height = self:PanelRect(candidate)
        panel:ClearAllPoints()
        panel:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", px, -py)
        panel:SetSize(width, height)
        panel:SetBackdropBorderColor(drag.valid and 0.2 or 1, drag.valid and 0.9 or 0.2, 0.3, 1)
        self:UpdateEditorVisuals(panel.id,candidate,resize,drag.valid,free)
    end)
end

function A:EndPanelDrag(panel)
    self:HideEditorVisuals()
    local drag = panel.drag
    panel:SetScript("OnUpdate", nil)
    panel.drag = nil
    if not drag or not self.draft then return end
    if drag.valid then self:PushUndo(); self.draft[panel.id] = drag.candidate end
    self:ResizeCanvas()
    self:ApplyLayout()
    self:Render()
end

local itemFrameOverlays={"IconBorder","IconOverlay","IconOverlay2"}

function A:SizeItemButton(button,size)
    if button.renderSize==size then return end
    button:SetSize(size,size)
    button.renderSize=size
    -- The native button is 37px; its quickslot artwork includes transparent padding.
    local scale=size/37
    local normal=button:GetNormalTexture()
    if normal then
        normal:ClearAllPoints()
        normal:SetPoint("CENTER",button,"CENTER",0,-scale)
        normal:SetSize(64*scale,64*scale)
    end
    for _,key in ipairs(itemFrameOverlays) do
        local overlay=button[key]
        if type(overlay)=="table" or type(overlay)=="userdata" then
            overlay:ClearAllPoints()
            overlay:SetAllPoints(button)
        end
    end
    local quest=button.IconQuestTexture
    if type(quest)=="table" or type(quest)=="userdata" then
        quest:ClearAllPoints()
        quest:SetPoint("TOP",button,"TOP",0,0)
        quest:SetSize(size,38*scale)
    end
end

function A:GetItemButton(item, panel)
    local b = self.buttons[item.slotKey]
    if not panel.bagParents[item.bag] then
        local parent = CreateFrame("Frame", nil, panel.content)
        parent:SetAllPoints(panel.content)
        parent:EnableMouse(false)
        parent:SetID(item.bag)
        parent.IsCombinedBagContainer = function() return true end
        panel.bagParents[item.bag] = parent
    end
    local parent = panel.bagParents[item.bag]
    if not b then
        local bankButton=self.isBankWindow==true
        local template=bankButton and "BankItemButtonTemplate" or "ContainerFrameItemButtonTemplate,SecureActionButtonTemplate"
        b = CreateFrame("ItemButton", (self.itemButtonPrefix or "BlockBagsItem") .. item.bag .. "_" .. item.slot, parent, template)
        self.buttons[item.slotKey] = b
        b.stackBadge=false
        if bankButton then
            b:Init(self:BankType(self.storage),item.bag,item.slot)
            b.GetBagID=function(frame) return frame:GetBankTabID() end
            b.GetID=function(frame) return frame:GetContainerSlotID() end
            b.SetHasItem=function() end
            b.SetReadable=function() end
            b.UpdateNewItem=function() end
            b.UpdateJunkItem=function() end
            b.UpdateQuestItem=function(frame,isQuestItem,questID,isActive)
                frame:RefreshQuestItemInfo()
                if frame.IconQuestTexture then
                    if questID and not isActive then frame.IconQuestTexture:SetTexture(TEXTURE_ITEM_QUEST_BANG)
                    else frame.IconQuestTexture:SetTexture(TEXTURE_ITEM_QUEST_BORDER) end
                    frame.IconQuestTexture:SetShown(questID or isQuestItem)
                end
            end
        else b:Initialize(item.bag, item.slot) end
        b:HookScript("OnMouseDown",function() self:FocusWindow() end)
        b:RegisterForClicks("LeftButtonUp","RightButtonUp")
        b:SetAttribute("useOnKeyDown",false)
        b:SetAttribute("item2",item.bag.." "..item.slot)
        b:SetAttribute("type2","item")
        for _,prefix in ipairs({"alt-","ctrl-","shift-","alt-ctrl-","alt-shift-","ctrl-shift-","alt-ctrl-shift-"}) do
            b:SetAttribute(prefix.."type2","")
        end
        b:HookScript("PreClick",function(frame)
            if InCombatLockdown() then return end
            local action=self:CanUseItemDirectly() and "item" or ""
            if frame:GetAttribute("type2")~=action then frame:SetAttribute("type2",action) end
        end)
        b.bagID=item.bag
        self:PrepareCombatButton(b)
        self:SizeItemButton(b,36)
        b:EnableMouseWheel(true)
        b:HookScript("OnEnter", function(frame)
            if frame.newMarker then frame.newMarker:Hide() end
            if frame.bankBlocked then GameTooltip:AddLine(self.L["Este item não pode ser depositado nesse banco."],1,0.3,0.3,true); GameTooltip:Show() end
            self:ShowCategoryDropHint(frame.anchorCategory,frame.anchorIndex)
        end)
        b:HookScript("OnLeave",function() self:HideCategoryDropHint() end)
        local nativeDrag=b:GetScript("OnDragStart")
        b:SetScript("OnDragStart",function(frame,...)
            if InCombatLockdown() then return end
            if bankButton and not self:CanMutateBank(nil,true) then return end
            self:CaptureItemSource(frame)
            if nativeDrag then nativeDrag(frame,...) end
        end)
        local nativeStop=b:GetScript("OnDragStop")
        b:SetScript("OnDragStop",function(frame,...)
            if InCombatLockdown() then return end
            self:CompleteItemDrag()
            if nativeStop then nativeStop(frame,...) end
        end)
        local nativeClick=bankButton and b:GetScript("OnClick") or (ContainerFrameItemButtonMixin and ContainerFrameItemButtonMixin.OnClick or ContainerFrameItemButton_OnClick)
        -- Keep the secure template's OnClick untouched; observe it afterward.
        local function click(frame,mouseButton,...)
            if InCombatLockdown() then return end
            if bankButton and not self:CanMutateBank(nil,true) then return end
            if mouseButton=="LeftButton" then
                if CursorHasItem() and self:TryVirtualDrop(frame.anchorCategory,frame.anchorIndex) then return end
                if not CursorHasItem() then self:CaptureItemSource(frame) end
            end
            if CursorHasItem() then self:RememberDrop(frame) end
            if mouseButton=="RightButton" and IsAltKeyDown() and frame.currentItem then
                self:OpenItemActions(frame.currentItem)
            elseif mouseButton=="RightButton" and self.atBank and frame.currentItem and not IsModifiedClick() then
                self:TransferBankItem(frame.currentItem)
            elseif mouseButton=="RightButton" and not IsModifiedClick() and frame:GetAttribute("type2")=="item" then
                return
            elseif nativeClick then nativeClick(frame,mouseButton,...) end
        end
        if bankButton then b:SetScript("OnClick",click) else b:HookScript("OnClick",click) end
        for _, event in ipairs({"OnReceiveDrag", "OnMouseDown"}) do
            local native=b:GetScript(event)
            b:SetScript(event,function(frame,...)
                if InCombatLockdown() then return end
                if event=="OnMouseDown" then self:FocusWindow() end
                if bankButton and not self:CanMutateBank(nil,true) then return end
                if event=="OnReceiveDrag" and self:TryVirtualDrop(frame.anchorCategory,frame.anchorIndex) then return end
                if CursorHasItem() then self:RememberDrop(frame) end
                if native then native(frame,...) end
            end)
        end
        b.newMarker = label(b, "N", 11)
        b.newMarker:SetPoint("TOPLEFT", 2, -2)
        b.newMarker:SetTextColor(0.2, 1, 0.9)
        b.levelLabel = label(b, "", 10)
        b.levelLabel:SetFont(STANDARD_TEXT_FONT, 10, "OUTLINE")
        b.levelLabel:SetPoint("BOTTOMLEFT", 2, 2)
        b.levelLabel:SetTextColor(1, 0.9, 0.55)
        b.levelLabel:Hide()
        self:BuildItemIndicators(b)
        b.favoriteMarker=label(b,"*",16)
        b.favoriteMarker:SetTextColor(1,0.82,0)
        b.favoriteMarker:SetPoint("TOPRIGHT",-1,-1)
        b.focusBorder=CreateFrame("Frame",nil,b,"BackdropTemplate")
        b.focusBorder:SetAllPoints(b)
        b.focusBorder:SetFrameLevel(b:GetFrameLevel()+5)
        b.focusBorder:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=2})
        b.focusBorder:SetBackdropBorderColor(1,0.82,0,1)
        b.focusBorder:Hide()
    end
    b.anchorOwner=self
    if b.anchorParent~=parent then b:SetParent(parent); b.anchorParent=parent end
    if b.anchorWheel~=panel.wheel then b:SetScript("OnMouseWheel",panel.wheel); b.anchorWheel=panel.wheel end
    return b
end

function A:PaintItem(b,item,search)
    local info,q=item.info,item.quest or {}
    local displayCount=self:DisplayStackCount(b,item)
    local p=b.paintState
    if type(p)~="table" then p={}; b.paintState=p end
    local full=p.kind~="item" or self.forceItemPaint
    local changedIdentity=p.identity~=item.identity
    b.currentItem=item; b.emptyAnchor=nil
    if full then b:SetHasItem(true) end
    if full or p.icon~=info.iconFileID then SetItemButtonTexture(b,info.iconFileID) end
    if full or p.count~=displayCount then SetItemButtonCount(b,displayCount) end
    if full or p.quality~=(info.quality or false) or p.link~=(info.hyperlink or false) then SetItemButtonQuality(b,info.quality,info.hyperlink) end
    if full or p.locked~=(info.isLocked or false) then SetItemButtonDesaturated(b,info.isLocked) end
    if full or changedIdentity or p.locked~=(info.isLocked or false) then b:UpdateCooldown(true) end
    if full or p.readable~=(info.isReadable or false) then b:SetReadable(info.isReadable) end
    if full or p.questItem~=(q.isQuestItem or false) or p.questID~=(q.questID or false) or p.questActive~=(q.isActive or false) then
        b:UpdateQuestItem(q.isQuestItem,q.questID,q.isActive)
    end
    local isNew=C_NewItems.IsNewItem(item.bag,item.slot)
    if full or p.new~=isNew or p.quality~=(info.quality or false) then b:UpdateNewItem(info.quality) end
    if full or p.quality~=(info.quality or false) or p.noValue~=(info.hasNoValue or false) then b:UpdateJunkItem(info.quality,info.hasNoValue) end
    if b.UpdateItemContextMatching and (full or changedIdentity or p.link~=(info.hyperlink or false)) then b:UpdateItemContextMatching() end
    p.kind,p.identity,p.icon,p.count="item",item.identity,info.iconFileID,displayCount
    p.quality,p.link,p.locked,p.readable=info.quality or false,info.hyperlink or false,info.isLocked or false,info.isReadable or false
    p.questItem,p.questID,p.questActive=q.isQuestItem or false,q.questID or false,q.isActive or false
    p.new,p.noValue=isNew,info.hasNoValue or false
    b.newMarker:SetShown(isNew)
    local level = item.itemLevel
    local equipment = item.classID == Enum.ItemClass.Weapon or item.classID == Enum.ItemClass.Armor
    local showLevel = self:GetSettings().showItemLevel ~= false and equipment and type(level) == "number" and level > 0
    if p.itemLevel ~= level or full then b.levelLabel:SetText(type(level) == "number" and tostring(level) or ""); p.itemLevel = level end
    b.levelLabel:SetShown(showLevel)
    self:PaintItemIndicators(b,item)
    local group=self.groups[item.category]
    b.favoriteMarker:SetShown(not self.isBankWindow and group and group.reserved[b.anchorIndex]==info.itemID and group.positions[b.anchorIndex]==item)
    b.focusBorder:SetShown(self.focusedSearchIdentity==item.identity)
    local match=search=="" or self:MatchesQuery(item,search)
    self:UpdateBankEligibility(b,item)
    b:SetAlpha(match and 1 or 0.22); b:EnableMouse(not self.draft)
    return match
end

function A:PaintEmpty(b,slot,panel,index)
    b.anchorSlotKey=slot.slotKey
    b.emptyAnchor,b.anchorCategory,b.anchorIndex=true,panel.id,index
    b.currentItem=nil
    if b.stackBadge then b.stackBadge:Hide() end
    if self.combatController then b:SetAttribute("combat-reveal",false) end
    local p=b.paintState
    if type(p)~="table" then p={}; b.paintState=p end
    if p.kind~="empty" or self.forceItemPaint then
        b:SetHasItem(false)
        SetItemButtonTexture(b,nil); SetItemButtonCount(b,0); SetItemButtonQuality(b,nil)
        SetItemButtonDesaturated(b,false); b:SetReadable(false)
        b:UpdateCooldown(false); b:UpdateQuestItem(false,nil,false); b:UpdateNewItem(nil); b:UpdateJunkItem(nil,true)
        if ClearItemButtonOverlay then ClearItemButtonOverlay(b) end
        if b.UpdateItemContextMatching then b:UpdateItemContextMatching() end
        p.kind="empty"
    end
    if type(b.bankRestriction)=="table" or type(b.bankRestriction)=="userdata" then b.bankRestriction:Hide() end
    b.favoriteMarker:Hide(); b.focusBorder:Hide(); b.newMarker:Hide(); b.levelLabel:Hide()
    b.upgradeMarker:Hide(); b.setMarker:Hide(); b.transmogMarker:Hide()
    if b.IconQuestTexture then b.IconQuestTexture:Hide() end
    b:SetAlpha(1); b:EnableMouse(not self.draft)
end

function A:PaintFavoriteGhost(panel,ordinal,id,index,size,x,y)
    local favorite=self.profile.favorites[id]
    if not favorite or self.isBankWindow then return end
    local ghost=panel.favoriteGhosts[ordinal]
    if not ghost then
        ghost=CreateFrame("Button",nil,panel.content)
        panel.favoriteGhosts[ordinal]=ghost
        ghost.anchorOwner=self
        ghost.icon=ghost:CreateTexture(nil,"ARTWORK")
        ghost.icon:SetAllPoints(ghost)
        ghost.icon:SetDesaturated(true)
        ghost.icon:SetAlpha(0.35)
        ghost.border=ghost:CreateTexture(nil,"OVERLAY")
        ghost.border:SetTexture("Interface\\Buttons\\UI-Quickslot2")
        ghost.border:SetPoint("CENTER",ghost,"CENTER",0,0)
        ghost.border:SetVertexColor(0.65,0.65,0.65,0.55)
        ghost.star=label(ghost,"*",16)
        ghost.star:SetPoint("TOPRIGHT",-1,-1)
        ghost.star:SetTextColor(1,0.82,0)
        ghost:EnableMouseWheel(true)
        ghost:SetScript("OnMouseWheel",panel.wheel)
        ghost:SetScript("OnMouseDown",function() self:FocusWindow() end)
        local receive=function()
            if CursorHasItem() then self:TryVirtualDrop(ghost.anchorCategory,ghost.anchorIndex) end
        end
        ghost:SetScript("OnReceiveDrag",receive)
        ghost:RegisterForClicks("LeftButtonUp","RightButtonUp")
        ghost:SetScript("OnClick",function(_,key)
            if key=="RightButton" and not CursorHasItem() and not InCombatLockdown() then
                MenuUtil.CreateContextMenu(ghost,function(_,root)
                    local entry=self.profile.favorites[ghost.favoriteID]
                    root:CreateTitle(entry and entry.name or self.L["Favoritos"])
                    root:CreateButton(self.L["Remover favorito"],function() self:RemoveFavorite(ghost.favoriteID) end)
                end)
            else receive() end
        end)
        ghost:SetScript("OnEnter",function()
            if CursorHasItem() then return end
            GameTooltip:SetOwner(ghost,"ANCHOR_RIGHT")
            if ghost.hyperlink then GameTooltip:SetHyperlink(ghost.hyperlink)
            else GameTooltip:SetItemByID(ghost.favoriteID) end
            GameTooltip:AddLine(self.L["Favorito ausente da mochila."],0.7,0.7,0.7,true)
            GameTooltip:AddLine(self.L["Este slot permanece reservado para este item."],1,0.82,0,true)
            GameTooltip:Show()
        end)
        ghost:SetScript("OnLeave",function() GameTooltip:Hide() end)
        ghost:SetScript("OnHide",function()
            if GameTooltip.IsOwned and GameTooltip:IsOwned(ghost) then GameTooltip:Hide() end
        end)
    end
    if not favorite.iconFileID and C_Item.GetItemIconByID then favorite.iconFileID=C_Item.GetItemIconByID(id) end
    ghost.favoriteID,ghost.hyperlink=id,favorite.hyperlink
    ghost.anchorCategory,ghost.anchorIndex=panel.id,index
    local icon=favorite.iconFileID or 134400
    if ghost.iconFileID~=icon then ghost.icon:SetTexture(icon); ghost.iconFileID=icon end
    ghost:SetSize(size,size)
    ghost.border:SetSize(64*size/37,64*size/37)
    ghost:ClearAllPoints(); ghost:SetPoint("TOPLEFT",panel.content,"TOPLEFT",x,-y)
    ghost:EnableMouse(not self.draft)
    ghost:Show()
end

function A:Render()
    if InCombatLockdown() then self.pendingRefresh = true; self:PaintCombatInventory(); return end
    if self.ready and not self.window:IsShown() and not self.renderPreparing then self.inventoryDirty=true; return end
    self:ApplyLayout()
    self:RefreshBagSlots()
    self:PaintCurrencyBar(); self:PaintTabs(); self:PaintStorageSelector(); self:RefreshBankControls()
    if self.physicalBagView then self:RenderPhysicalBags(); return end
    if self.physicalSections then for _,panel in pairs(self.physicalSections) do panel:Hide() end end
    if not self.groups then return end
    self:AssignEmptySlots()
    self:BuildVirtualStacks()
    self.renderSerial=(self.renderSerial or 0)+1
    local search = (self.search:GetText() or ""):lower()
    self.searchHint:SetShown(search == "")
    self.searchClear:SetShown(search ~= "")
    local results=self:CollectSearchResults(search)
    self.searchPrevious:SetShown(search~="" and not self.draft)
    self.searchNext:SetShown(search~="" and not self.draft)
    self.searchNavigation:SetText(search~="" and ((self.searchResultIndex or 0) .. "/" .. #results) or "")
    for _, cat in ipairs(self.categories) do
        local panel, layout = self.panels[cat.id], self:GetLayout()[cat.id]
        local group = self.groups and self.groups[cat.id] or { positions = {}, max = 0, items = {} }
        local metrics = self:ItemMetrics(layout)
        panel.scroll:SetSize(metrics.width, metrics.height)
        panel.content:SetWidth(metrics.width)
        panel.currentMetrics = metrics
        local rows = math.ceil(self.displayMax[cat.id] / metrics.cols)
        local contentHeight = math.max(metrics.height, rows * metrics.step - metrics.spacing)
        panel.content:SetHeight(contentHeight)
        local maxScroll = math.max(0, contentHeight - metrics.height)
        panel.bar:SetMinMaxValues(0, maxScroll)
        panel.bar:SetValue(math.min(panel.offset, maxScroll))
        panel.bar:SetShown(maxScroll > 0)
        local slots = self.displayMax[cat.id]
        for _,ghost in pairs(panel.favoriteGhosts) do ghost:Hide() end
        for _, cell in ipairs(panel.cells) do cell:Hide() end
        local matches = 0
        local markerIndex=0
        for index = 1, slots do
            local x, y = ((index - 1) % metrics.cols) * metrics.step, math.floor((index - 1) / metrics.cols) * metrics.step
            local item = group.positions[index]
            local empty = self.emptyPositions[cat.id][index]
            if item or empty then
                local b = self:GetItemButton(item or empty, panel)
                b.anchorCategory, b.anchorIndex = cat.id, index
                b.renderSerial=self.renderSerial
                self:SizeItemButton(b,metrics.size)
                if b.renderPanel~=panel or b.renderX~=x or b.renderY~=y then
                    b:ClearAllPoints(); b:SetPoint("TOPLEFT",panel.content,"TOPLEFT",x,-y)
                    b.renderPanel,b.renderX,b.renderY=panel,x,y
                end
                if item then
                    if self:PaintItem(b, item, search) then matches = matches + 1 end
                    self:PaintVirtualStack(b,item)
                else
                    self:PaintEmpty(b, empty, panel, index)
                end
                if self:CategoryDisplayed(cat.id) and not group.virtualHidden[index] then
                    if not b:IsShown() then b:Show() end
                elseif b:IsShown() then b:Hide() end
            elseif group.reserved and group.reserved[index] then
                markerIndex=markerIndex+1
                self:PaintFavoriteGhost(panel,markerIndex,group.reserved[index],index,metrics.size,x,y)
            end
        end
        if cat.id == "reagentbag" and self.capacity then
            local total, free = self.capacity.reagentTotal, self.capacity.reagentFree
            panel.count:SetText((total - free) .. "/" .. total)
            panel.count:SetTextColor(total > 0 and free == 0 and 1 or 0.85, free == 0 and total > 0 and 0.2 or 0.9, free == 0 and total > 0 and 0.2 or 0.94)
        else
            panel.count:SetText(search ~= "" and (matches .. "/" .. #group.items) or tostring(#group.items))
            panel.count:SetTextColor(0.85, 0.9, 0.94)
        end
    end
    for _,b in pairs(self.buttons) do
        if b.renderSerial~=self.renderSerial then
            if b:IsShown() then b:Hide() end
            b.currentItem=nil
            if self.combatController and b:GetAttribute("combat-reveal") then b:SetAttribute("combat-reveal",false) end
        end
    end
    self.forceItemPaint=nil
    local c = self.capacity
    if self.draft then
        self.status:SetText(A.L["EDIÇÃO — arraste, redimensione ou use a engrenagem."])
        self.money:SetText("")
    elseif c then
        if self.isBankWindow then
            local state=self:BankState()
            self.status:SetText(self.bankLoading and A.L["Carregando dados do banco…"] or state=="ready" and string.format(A.L["Livres: %d/%d"],c.free,c.total) or self:BankStateText(state))
        else self.status:SetText(string.format(A.L["Livres: %d/%d  |  Reagentes livres: %d/%d"], c.free, c.total, c.reagentFree, c.reagentTotal)) end
        self:PaintMoney()
    end
end
