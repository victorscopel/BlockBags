local _, A = ...

local function text(parent,value,x,y,width)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    f:SetPoint("TOPLEFT",x,y); f:SetWidth(width or 580); f:SetJustifyH("LEFT"); f:SetText(value)
    return f
end
local function button(parent,value,x,y,width,callback)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT",x,y); b:SetSize(width or 180,26); b:SetText(value); b:SetScript("OnClick",callback)
    return b
end
local function input(parent,x,y,width)
    local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
    e:SetPoint("TOPLEFT",x,y); e:SetSize(width or 280,24); e:SetAutoFocus(false); e:SetMaxLetters(60)
    e:SetScript("OnEscapePressed",function(f) f:ClearFocus() end)
    return e
end
local function page(name,height)
    local panel=CreateFrame("Frame")
    panel.name=name
    local scroll=CreateFrame("ScrollFrame",nil,panel,"UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",8,-8); scroll:SetPoint("BOTTOMRIGHT",-32,8)
    local content=CreateFrame("Frame",nil,scroll)
    content:SetSize(640,height); scroll:SetScrollChild(content)
    panel.content=content; panel:Hide()
    text(content,name,16,-12)
    return panel,content
end

function A:SettingsChanged()
    if InCombatLockdown() then return end
    self:ResizeCanvas(); self:Reconcile(); self:Render()
end

function A:SetCategoryOption(id,key,value)
    if InCombatLockdown() then self:Print(A.L["Aguarde o fim do combate."]); return end
    local data=self:GetLayout()[id]
    if not data then return end
    if key=="rule" then
        if id=="reagentbag" then self:Print(A.L["A bolsa de reagentes acompanha a bolsa física."]); return end
        local valid,err=self:ValidateCategoryRule(value)
        if not valid then self:Print(err); return end
    end
    if key=="width" or key=="height" then
        if not self.draft then self:Print(A.L["Entre no modo Editar layout para alterar dimensões."]); self:RefreshSettings(); return end
        local candidate=self:Copy(data); candidate[key]=value
        if not self:CanPlace(id,candidate) then self:Print(A.L["Esse tamanho não cabe: verifique o mínimo, os outros painéis e a janela."]); self:RefreshSettings(); return end
    end
    if key=="hidden" and value then
        local visible=0
        for _,d in pairs(self:GetLayout()) do if not d.hidden then visible=visible+1 end end
        if visible<=1 then self:Print(A.L["Mantenha pelo menos uma categoria visível."]); return end
    end
    if key=="hidden" and not value then
        -- A hidden panel may have been overlapped during layout editing.
        local candidate=self:Copy(data); candidate.hidden=false
        if not self:CanPlace(id,candidate) then
            local bottom=0
            for other,d in pairs(self:GetLayout()) do if other~=id and not d.hidden then local _,y,_,h=self:PanelRect(d); bottom=math.max(bottom,(y+h+(self:GetSettings().categorySpacing or 0))/self.cell) end end
            if self.draft then self:PushUndo() end
            data.y=bottom
        end
    end
    if self.draft then self:PushUndo() end
    data[key]=value
    -- Reclassify existing items when visibility changes; preserve manual rules.
    if key=="hidden" or key=="rule" then
        self.visibilityChanged=true
        for _,item in ipairs(self.items or {}) do item.category=self:Classify(item) end
    end
    self:SettingsChanged(); self:RefreshSettings()
end

function A:ChooseCategoryColor(id)
    if InCombatLockdown() then return end
    if not ColorPickerFrame and C_AddOns then C_AddOns.LoadAddOn("Blizzard_ColorPicker") end
    if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then self:Print(A.L["Seletor de cores do WoW indisponível."]); return end
    local layout=self:GetLayout()
    local before=self:Copy(layout[id].tint)
    local c=before or {r=0.4,g=0.65,b=1}
    if self.draft then self:PushUndo() end
    local function apply(color)
        if self:GetLayout()~=layout or InCombatLockdown() then return end
        layout[id].tint=color
        self:ApplyLayout(); self:RefreshSettings()
    end
    ColorPickerFrame:SetupColorPickerAndShow({r=c.r,g=c.g,b=c.b,hasOpacity=false,
        swatchFunc=function() local r,g,b=ColorPickerFrame:GetColorRGB(); apply({r=r,g=g,b=b}) end,
        cancelFunc=function() apply(before) end})
end

local function section(parent,title,y,height)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    f.initializing=false
    f:SetPoint("TOPLEFT",16,y); f:SetSize(600,height)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(0.08,0.08,0.09,0.75); f:SetBackdropBorderColor(0.28,0.25,0.2,1)
    local heading=text(f,title,16,-14,560); heading:SetFontObject("GameFontNormalLarge")
    return f
end
local function dropdown(parent,x,y,width,generator)
    local d=CreateFrame("DropdownButton",nil,parent,"WowStyle2DropdownTemplate")
    d:SetPoint("TOPLEFT",x,y); d:SetSize(width,26); d:SetupMenu(generator)
    return d
end

function A:RegisterSettings()
    if self.settingsPages or not Settings or not Settings.RegisterCanvasLayoutCategory then return end
    local general=page("BlockBags",780)
    local category=Settings.RegisterCanvasLayoutCategory(general,"BlockBags")
    Settings.RegisterAddOnCategory(category)
    local categories=page(A.L["Categorias"],1480)
    local categoryPage=Settings.RegisterCanvasLayoutSubcategory(category,categories,A.L["Categorias"])
    local profiles=page(A.L["Perfis"],840)
    local profilePage=Settings.RegisterCanvasLayoutSubcategory(category,profiles,A.L["Perfis"])
    local features=page(A.L["Moedas, indicadores e abas"],1080)
    local featurePage=Settings.RegisterCanvasLayoutSubcategory(category,features,A.L["Recursos"])
    self.settingsPages={general=general,categories=categories,profiles=profiles,features=features}
    self.settingsIDs={general=category:GetID(),categories=categoryPage:GetID(),profiles=profilePage:GetID(),features=featurePage:GetID()}
    for _,panel in pairs(self.settingsPages) do panel:SetScript("OnShow",function() self:BuildSettingsControls(); self:RefreshSettings() end) end
end

function A:BuildSettingsControls()
    if self.settingsControls then return end
    self.settingsInitializing=true
    self.settingsControls={}
    local controls=self.settingsControls
    local g,c,p=self.settingsPages.general.content,self.settingsPages.categories.content,self.settingsPages.profiles.content
    local status=section(g,A.L["Perfil e edição"],-42,106)
    controls.info=text(status,"",16,-44,560)
    text(status,A.L["As opções são salvas no perfil ativo. No editor, use Salvar ou Cancelar."],16,-72,560)
    local layout=section(g,A.L["Layout do inventário"],-160,188)
    controls.generalSpacing=self:CreateSettingSlider(layout,-91,0,16,1,function(value)
        if InCombatLockdown() then self:RefreshSettings(); return end
        if self.draft then self:PushUndo() end
        self:GetSettings().categorySpacing=value
        self:PackLayout(self:GetLayout(),value)
        self:SettingsChanged(); self:RefreshSettings()
    end)
    text(layout,A.L["Define a distância real entre painéis. Alterar este valor aproxima as categorias mantendo sua ordem. Itens entrando ou saindo nunca movem os painéis."],16,-122,560)
    local actions=section(g,A.L["Acesso rápido"],-360,94)
    button(actions,A.L["Editar layout"],16,-48,180,function() SettingsPanel:Hide(); self.window:Show(); self:StartEdit() end)
    button(actions,A.L["Gerenciar favoritos"],212,-48,190,function() SettingsPanel:Hide(); self.window:Show(); self:OpenFavorites() end)
    local help=section(g,A.L["Organização dos itens"],-466,146)
    text(help,A.L["Arraste entre categorias ou use Alt + clique direito para atribuir um item. Missões reúne itens que o WoW associa a uma missão. A bolsa física de reagentes mantém suas restrições."],16,-44,560)
    button(help,A.L["Diagnóstico de memória"],16,-105,210,function() self:ReportMemory() end)
    local direct=section(g,A.L["Movimento direto das categorias"],-624,110)
    controls.layoutLock=button(direct,"",16,-40,255,function() self:ToggleLayoutLock() end)
    text(direct,A.L["Arraste o cabeçalho sem abrir o editor. Shift ignora o encaixe. Clique direito no cabeçalho abre as opções da categoria."],16,-77,560)

    local choose=section(c,A.L["Categoria selecionada"],-42,92)
    controls.categorySelect=dropdown(choose,16,-47,350,function(_,root)
        for _,cat in ipairs(self.categories) do
            root:CreateRadio(self:CategoryName(cat.id),function(id) return self.settingsCategory==id end,
                function(id) self.settingsCategory=id; self:RefreshSettings() end,cat.id)
        end
    end)
    controls.categoryTitle=text(choose,"",385,-52,200)
    local identity=section(c,A.L["Nome e comportamento"],-146,199)
    controls.categoryName=input(identity,20,-50,340)
    button(identity,A.L["Renomear"],380,-50,160,function()
        local name=(controls.categoryName:GetText() or ""):match("^%s*(.-)%s*$")
        if #name>0 and #name<=60 then self:SetCategoryOption(self.settingsCategory,"name",name) end
    end)
    controls.visibility=button(identity,"",20,-89,210,function()
        local d=self:GetLayout()[self.settingsCategory]; self:SetCategoryOption(self.settingsCategory,"hidden",not d.hidden)
    end)
    controls.positions=button(identity,"",248,-89,292,function()
        local d=self:GetLayout()[self.settingsCategory]; self:SetCategoryOption(self.settingsCategory,"compact",not d.compact)
    end)
    text(identity,A.L["Ocultar mantém os itens acessíveis em outra categoria visível."],20,-127,550)
    controls.deleteCategory=button(identity,A.L["Excluir categoria criada"],20,-158,245,function()
        if self:CanChangeProfile() and self:IsCustomCategory(self.settingsCategory) then
            StaticPopup_Show("BLOCKBAGS_DELETE_CATEGORY",self:CategoryName(self.settingsCategory),nil,{id=self.settingsCategory})
        end
    end)
    local dimensions=section(c,A.L["Dimensões do painel"],-357,212)
    controls.width=self:CreateSettingSlider(dimensions,-85,96,12000,1,function(value) self:SetCategoryOption(self.settingsCategory,"width",value) end)
    controls.height=self:CreateSettingSlider(dimensions,-148,76,12000,1,function(value) self:SetCategoryOption(self.settingsCategory,"height",value) end)
    text(dimensions,A.L["Disponíveis no modo Editar layout. Valores em pixels; espaço sobrando é permitido."],20,-178,550)
    local appearance=section(c,A.L["Aparência desta categoria"],-581,251)
    controls.size=self:CreateSettingSlider(appearance,-91,24,56,2,function(value) self:SetCategoryOption(self.settingsCategory,"itemSize",value) end)
    controls.spacing=self:CreateSettingSlider(appearance,-154,0,12,1,function(value) self:SetCategoryOption(self.settingsCategory,"itemSpacing",value) end)
    controls.color=button(appearance,A.L["Escolher cor…"],20,-198,210,function() self:ChooseCategoryColor(self.settingsCategory) end)
    controls.swatch=controls.color:CreateTexture(nil,"OVERLAY")
    controls.swatch:SetSize(18,18); controls.swatch:SetPoint("RIGHT",-8,0)
    button(appearance,A.L["Remover cor"],248,-198,160,function() self:SetCategoryOption(self.settingsCategory,"tint",nil) end)
    local create=section(c,A.L["Criar categoria"],-844,149)
    controls.newCategory=input(create,20,-50,340)
    button(create,A.L["Criar"],380,-50,160,function()
        local id=self:CreateCategory(controls.newCategory:GetText())
        if id then self.settingsCategory=id; controls.newCategory:SetText(""); self:RefreshSettings() end
    end)
    text(create,A.L["Atribua itens por arraste ou escolha manual. Depois, posicione e redimensione o painel no editor. Encerre a edição antes de criar uma categoria."],20,-90,550)
    local automatic=section(c,A.L["Regra automática desta categoria"],-1005,260)
    controls.rule=input(automatic,20,-51,540); controls.rule:SetMaxLetters(256)
    controls.applyRule=button(automatic,A.L["Aplicar regra"],20,-86,220,function()
        self:SetCategoryOption(self.settingsCategory,"rule",controls.rule:GetText())
    end)
    text(automatic,A.L["Exemplos: tipo:consumivel   qualidade:epico   nivel:>=80\nCombine filtros com espaços: tipo:equipamento !qualidade:lixo\nTexto simples procura pelo nome. Regra vazia remove a classificação automática desta categoria. A primeira regra compatível na lista vence; atribuições manuais e favoritos têm prioridade."],20,-130,560)

    local active=section(p,A.L["Selecionar perfil"],-42,154)
    controls.profileTitle=text(active,"",20,-43,550)
    controls.profileSelect=dropdown(active,20,-77,330,function(_,root)
        local keys={}; for key in pairs(BlockBagsDB.profiles) do keys[#keys+1]=key end; table.sort(keys)
        for _,key in ipairs(keys) do root:CreateRadio(key,function(name) return self.settingsProfile==name end,
            function(name) self.settingsProfile=name; self:RefreshSettings() end,key) end
    end)
    button(active,A.L["Ativar"],365,-77,90,function() self:SelectProfile(self.settingsProfile) end)
    button(active,A.L["Excluir"],470,-77,90,function()
        if self:CanChangeProfile() then StaticPopup_Show("BLOCKBAGS_DELETE_PROFILE",self.settingsProfile,nil,{name=self.settingsProfile}) end
    end)
    controls.profileChoice=text(active,"",20,-119,550)
    local manage=section(p,A.L["Criar ou renomear"],-208,167)
    text(manage,A.L["Nome do perfil"],20,-43,550)
    controls.profileName=input(manage,20,-69,540)
    button(manage,A.L["Criar vazio"],20,-111,160,function() self:CreateProfile(controls.profileName:GetText(),false) end)
    button(manage,A.L["Duplicar ativo"],198,-111,172,function() self:CreateProfile(controls.profileName:GetText(),true) end)
    button(manage,A.L["Renomear ativo"],388,-111,172,function() self:RenameProfile(controls.profileName:GetText()) end)
    local transfer=section(p,A.L["Importar e exportar"],-387,368)
    text(transfer,A.L["Digite um nome acima para importar. Cole o código abaixo; a importação cria um perfil novo e não substitui os existentes."],20,-43,550)
    local codeBox=CreateFrame("Frame",nil,transfer,"BackdropTemplate")
    codeBox:SetPoint("TOPLEFT",20,-96); codeBox:SetSize(540,172)
    codeBox:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    codeBox:SetBackdropColor(0,0,0,0.6); codeBox:SetBackdropBorderColor(0.4,0.4,0.4,1)
    local codeScroll=CreateFrame("ScrollFrame",nil,codeBox,"UIPanelScrollFrameTemplate")
    codeScroll:SetPoint("TOPLEFT",8,-8); codeScroll:SetPoint("BOTTOMRIGHT",-28,8)
    controls.code=CreateFrame("EditBox",nil,codeScroll)
    controls.code:SetMultiLine(true); controls.code:SetFontObject("ChatFontNormal"); controls.code:SetAutoFocus(false)
    controls.code:SetSize(495,155); controls.code:SetMaxLetters(1048576); codeScroll:SetScrollChild(controls.code)
    controls.code:SetScript("OnEscapePressed",function(f) f:ClearFocus() end)
    controls.code:SetScript("OnTextChanged",function(f)
        local height=f:GetStringHeight(); if type(height)=="number" then f:SetHeight(math.max(155,height+24)) end
    end)
    button(transfer,A.L["Exportar ativo"],20,-285,210,function()
        controls.code:SetText(self:ExportProfile()); controls.code:SetFocus(); controls.code:HighlightText()
    end)
    button(transfer,A.L["Importar como novo"],248,-285,230,function() self:ImportProfile(controls.profileName:GetText(),controls.code:GetText()) end)
    text(transfer,A.L["Ctrl+C para copiar · Ctrl+V para colar. O código não contém itens físicos."],20,-331,550)
    text(p,A.L["Perfis podem ser compartilhados entre personagens. Salve ou cancele a edição antes de gerenciá-los."],32,-776,580)
    StaticPopupDialogs.BLOCKBAGS_DELETE_PROFILE={text=A.L["Excluir o perfil %s?"],button1=YES,button2=CANCEL,timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
        OnAccept=function(_,data) A:DeleteProfile(data.name) end}
    StaticPopupDialogs.BLOCKBAGS_DELETE_CATEGORY={text=A.L["Excluir a categoria %s? Os itens continuarão acessíveis. As regras desta categoria serão removidas."],button1=YES,button2=CANCEL,timeout=0,whileDead=true,hideOnEscape=true,preferredIndex=3,
        OnAccept=function(_,data) A:DeleteCategory(data.id) end}
    self:BuildFeatureSettings()
    self.settingsInitializing=false
end

function A:CycleSettingsCategory(direction)
    local index=1
    for i,cat in ipairs(self.categories) do if cat.id==self.settingsCategory then index=i end end
    self.settingsCategory=self.categories[(index-1+direction)%#self.categories+1].id
    self:RefreshSettings()
end
function A:CycleSettingsProfile(direction)
    local keys={}; for key in pairs(BlockBagsDB.profiles) do keys[#keys+1]=key end; table.sort(keys)
    local index=1; for i,key in ipairs(keys) do if key==self.settingsProfile then index=i end end
    self.settingsProfile=keys[(index-1+direction)%#keys+1]; self:RefreshSettings()
end

function A:RefreshSettings()
    local c=self.settingsControls
    if not c then return end
    self.settingsCategory=self:GetLayout()[self.settingsCategory or ""] and self.settingsCategory or self.categories[1].id
    self.settingsProfile=BlockBagsDB.profiles[self.settingsProfile or ""] and self.settingsProfile or self.profileKey
    local d=self:GetLayout()[self.settingsCategory]
    self.settingsInitializing=true
    c.info:SetText(A.L["Perfil ativo: "]..self.profileKey..(self.draft and A.L[" — prévia de edição"] or ""))
    c.categoryTitle:SetText(d.hidden and A.L["Oculta"] or A.L["Visível"])
    c.categorySelect:OverrideText(self:CategoryName(self.settingsCategory))
    c.profileSelect:OverrideText(self.settingsProfile)
    c.categoryName:SetText(self:CategoryName(self.settingsCategory))
    c.rule:SetText(d.rule or ""); c.applyRule:SetEnabled(self.settingsCategory~="reagentbag")
    c.visibility:SetText(d.hidden and A.L["Mostrar categoria"] or A.L["Ocultar categoria"])
    c.positions:SetText(d.compact and A.L["Posições: automáticas"] or A.L["Posições: fixas"])
    c.deleteCategory:SetEnabled(self:IsCustomCategory(self.settingsCategory) and not self.draft)
    c.profileTitle:SetText(A.L["Perfil ativo: "]..self.profileKey)
    c.profileChoice:SetText(A.L["Selecionado: "]..self.settingsProfile)
    for _,pageFrame in pairs(self.settingsPages) do pageFrame.content.initializing=true end
    c.generalSpacing:SetValue(self:GetSettings().categorySpacing or 0)
    c.layoutLock:SetText(self:GetSettings().layoutLocked and A.L["Desbloquear movimento"] or A.L["Bloquear movimento"])
    c.layoutLock:SetEnabled(not self.draft)
    c.size:SetValue(d.itemSize or 36); c.spacing:SetValue(d.itemSpacing or 4)
    local _,_,width,height=self:PanelRect(d)
    c.width:SetValue(width); c.height:SetValue(height)
    c.width:SetAvailable(self.draft~=nil); c.height:SetAvailable(self.draft~=nil)
    c.width.caption:SetText(A.L["Largura do painel: "]..width.." px")
    c.height.caption:SetText(A.L["Altura do painel: "]..height.." px")
    c.generalSpacing.caption:SetText(A.L["Espaçamento das categorias: "]..(self:GetSettings().categorySpacing or 0).." px")
    c.size.caption:SetText(A.L["Tamanho dos itens: "]..(d.itemSize or 36).." px")
    c.spacing.caption:SetText(A.L["Espaçamento dos itens: "]..(d.itemSpacing or 4).." px")
    local color=d.tint or {r=0.4,g=0.4,b=0.4}; c.swatch:SetColorTexture(color.r,color.g,color.b,1)
    for _,pageFrame in pairs(self.settingsPages) do pageFrame.content.initializing=false end
    self:RefreshFeatureSettings()
    self.settingsInitializing=false
end

function A:RestoreInventoryEscape()
    local index=self.settingsSpecialIndex
    self.settingsSpecialIndex=nil
    if not index then return end
    for _,name in ipairs(UISpecialFrames) do if name=="BlockBagsWindow" then return end end
    table.insert(UISpecialFrames,math.min(index,#UISpecialFrames+1),"BlockBagsWindow")
end

function A:ProtectInventoryDuringSettings(protectInventory)
    self.settingsMenuSession={}
    if protectInventory and not self.settingsInventorySession then
        self.settingsInventorySession={}
        for i=#UISpecialFrames,1,-1 do
            if UISpecialFrames[i]=="BlockBagsWindow" then
                self.settingsSpecialIndex=i
                table.remove(UISpecialFrames,i)
                break
            end
        end
    end
    if not self.settingsCloseHookInstalled then
        self.settingsCloseHookInstalled=true
        -- Suppress Blizzard's return to GameMenu for settings opened by BlockBags.
        hooksecurefunc(SettingsPanel,"TransitionBackOpeningPanel",function()
            if self.settingsMenuSession and GameMenuFrame and GameMenuFrame:IsShown() then
                HideUIPanel(GameMenuFrame)
            end
        end)
        SettingsPanel:HookScript("OnHide",function()
            local session=self.settingsInventorySession
            local menuSession=self.settingsMenuSession
            -- Keep the close guard until Escape's remaining handlers have run.
            C_Timer.After(0,function()
                if SettingsPanel:IsShown() then return end
                if self.settingsMenuSession==menuSession then self.settingsMenuSession=nil end
                if not session or self.settingsInventorySession~=session then return end
                self.settingsInventorySession=nil
                self:RestoreInventoryEscape()
            end)
        end)
    end
end

function A:OpenSettings(section,id)
    if InCombatLockdown() then self:Print(A.L["Aguarde o fim do combate."]); return end
    self:RegisterSettings()
    if not self.settingsIDs then self:Print(A.L["A página de opções do WoW está indisponível."]); return end
    if id then self.settingsCategory=id end
    for _,key in ipairs({"customization","generalSettings","profileChooser","favoriteDialog","itemActions"}) do
        if self[key] then self[key]:Hide() end
    end
    self:BuildSettingsControls()
    self:RefreshSettings()
    local shown=self.window:IsShown()
    self.openingSettings=true
    self:ProtectInventoryDuringSettings(shown)
    local ok,err=pcall(Settings.OpenToCategory,self.settingsIDs[section or "general"])
    if shown then self.window:Show() end
    self.openingSettings=nil
    if not ok then
        self.settingsMenuSession=nil
        self.settingsInventorySession=nil
        self:RestoreInventoryEscape()
        self:Print(A.L["Não foi possível abrir as opções: "]..tostring(err))
    end
end
function A:OpenCustomization(id) self:OpenSettings("categories",id) end
function A:OpenGeneralSettings() self:OpenSettings("general") end
