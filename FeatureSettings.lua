local _, A = ...
local function text(parent,value,x,y,width)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    f:SetPoint("TOPLEFT",x,y); f:SetWidth(width or 550); f:SetJustifyH("LEFT"); f:SetText(value)
    return f
end
local function section(parent,title,y,height)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    f:SetPoint("TOPLEFT",16,y); f:SetSize(600,height)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(0.08,0.08,0.09,0.75); f:SetBackdropBorderColor(0.28,0.25,0.2,1)
    text(f,title,16,-14):SetFontObject("GameFontNormalLarge")
    return f
end
local function button(parent,title,x,y,width,callback)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate")
    b:SetPoint("TOPLEFT",x,y); b:SetSize(width,26); b:SetText(title); b:SetScript("OnClick",callback)
    return b
end
local function input(parent,x,y,width)
    local e=CreateFrame("EditBox",nil,parent,"InputBoxTemplate")
    e:SetPoint("TOPLEFT",x,y); e:SetSize(width,26); e:SetAutoFocus(false); e:SetMaxLetters(100)
    e:SetScript("OnEscapePressed",function() e:ClearFocus() end)
    return e
end
local function dropdown(parent,x,y,width,generator)
    local d=CreateFrame("DropdownButton",nil,parent,"WowStyle2DropdownTemplate")
    d:SetPoint("TOPLEFT",x,y); d:SetSize(width,26); d:SetupMenu(generator)
    return d
end

function A:SetFeatureOption(key,value)
    if InCombatLockdown() then return false end
    if self.draft then self:PushUndo() end
    self:GetSettings()[key]=value
    self.invalidateTooltips=true
    self:ResizeCanvas(); self:Render(); self:QueueRefresh(); self:RefreshSettings()
    return true
end
function A:ToggleCurrency(id)
    if InCombatLockdown() or not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyInfo(id) then return false end
    local ids=self:Copy(self:GetSettings().currencies or {})
    for index,value in ipairs(ids) do if value==id then table.remove(ids,index); return self:SetFeatureOption("currencies",ids) end end
    if #ids>=7 then self:Print(A.L["Você pode acompanhar até 7 moedas."]); return false end
    ids[#ids+1]=id
    return self:SetFeatureOption("currencies",ids)
end
function A:BuildFeatureSettings()
    local c=self.settingsControls
    if c.featureBuilt then return end
    c.featureBuilt=true
    local p=self.settingsPages.features.content
    local indicators=section(p,A.L["Indicadores de equipamento"],-42,244)
    c.indicators={}
    local options={{"showItemLevel",A.L["Mostrar nível dos equipamentos"]},{"showUpgrade",A.L["Mostrar seta de possível melhoria"]},
        {"showEquipmentSets",A.L["Identificar peças de conjuntos (C)"]},{"showTransmog",A.L["Identificar aparência não coletada (T)"]}}
    for index,option in ipairs(options) do
        local key,title=option[1],option[2]
        local b=CreateFrame("CheckButton",nil,indicators,"UICheckButtonTemplate")
        b:SetPoint("TOPLEFT",16,-40-(index-1)*32); b:SetSize(26,26)
        text(b,title,32,-6,510)
        b:SetScript("OnClick",function() self:SetFeatureOption(key,self:GetSettings()[key]==false) end)
        c.indicators[key]=b
    end
    c.upgradeProvider=dropdown(indicators,20,-180,200,function(_,root)
        root:CreateRadio(A.L["Comparar ilvl"],function() return self:GetSettings().upgradeProvider~="pawn" end,function() self:SetFeatureOption("upgradeProvider","ilvl") end)
        root:CreateRadio(A.L["Pawn (se instalado)"],function() return self:GetSettings().upgradeProvider=="pawn" end,function() self:SetFeatureOption("upgradeProvider","pawn") end)
    end)
    text(indicators,A.L["A comparação por ilvl sinaliza candidatos; o Pawn usa sua avaliação. Sem Pawn, a comparação por ilvl continua disponível."],236,-183,345)
    local currencies=section(p,A.L["Moedas no rodapé"],-298,233)
    c.currencyPicker=dropdown(currencies,20,-43,400,function(_,root)
        if not C_CurrencyInfo or not C_CurrencyInfo.GetCurrencyListSize then root:CreateTitle(A.L["Lista de moedas indisponível"]); return end
        for index=1,C_CurrencyInfo.GetCurrencyListSize() do
            local info=C_CurrencyInfo.GetCurrencyListInfo(index)
            if info and not info.isHeader then
                local id=info.currencyID
                if not id and C_CurrencyInfo.GetCurrencyListLink then
                    local link=C_CurrencyInfo.GetCurrencyListLink(index)
                    if link then id=tonumber(link:match("currency:(%d+)")) end
                end
                if id then
                root:CreateCheckbox(info.name,function()
                    for _,value in ipairs(self:GetSettings().currencies or {}) do if value==id then return true end end
                    return false
                end,function() self:ToggleCurrency(id) end)
                end
            end
        end
    end)
    c.currencyPicker:OverrideText(A.L["Selecionar moedas descobertas"])
    c.currencyNames=text(currencies,"",20,-81,550)
    text(currencies,A.L["Ou digite o ID de uma moeda para adicionar/remover:"],20,-148,550)
    c.currencyID=input(currencies,20,-174,140)
    button(currencies,A.L["Alternar moeda"],182,-174,180,function()
        local id=tonumber(c.currencyID:GetText())
        if not id or id%1~=0 or id<1 then self:Print(A.L["Digite um ID numérico válido."]); return end
        if not self:ToggleCurrency(id) then self:Print(A.L["Moeda indisponível ou limite de 7 moedas atingido."]) end
    end)
    button(currencies,A.L["Limpar seleção"],380,-174,170,function() self:SetFeatureOption("currencies",{}) end)
    local tabs=section(p,A.L["Abas de categorias"],-543,263)
    c.tabPicker=dropdown(tabs,20,-43,330,function(_,root)
        for _,tab in ipairs(self:GetTabs()) do
            root:CreateRadio(self:TabName(tab),function() return (self.settingsTab or "default")==tab.id end,
                function() self.settingsTab=tab.id; self:RefreshSettings() end)
        end
    end)
    text(tabs,A.L["Nome da aba"],20,-84)
    c.tabName=input(tabs,20,-110,520)
    button(tabs,A.L["Criar aba"],20,-151,160,function() local id=self:CreateTab(c.tabName:GetText()); if id then self.settingsTab=id; self:RefreshSettings() end end)
    button(tabs,A.L["Renomear"],198,-151,160,function() self:RenameTab(self.settingsTab or "default",c.tabName:GetText()) end)
    c.deleteTab=button(tabs,A.L["Excluir aba"],376,-151,164,function()
        local id=self.settingsTab
        if id=="default" then return end
        StaticPopup_Show("BLOCKBAGS_DELETE_TAB",nil,nil,{id=id})
    end)
    text(tabs,A.L["Mover categorias: clique direito no cabeçalho → Mover categoria para aba, ou use a página Categorias. Cada aba salva seu próprio layout. Excluir uma aba retorna suas categorias à Principal."],20,-194,550)
    StaticPopupDialogs.BLOCKBAGS_DELETE_TAB={text=A.L["Excluir esta aba? Suas categorias retornarão à Principal."],button1=YES,button2=CANCEL,timeout=0,whileDead=true,hideOnEscape=true,
        OnAccept=function(_,data) A:DeleteTab(data.id); A.settingsTab="default"; A:RefreshSettings() end}
    local management=section(p,A.L["Banco e ações por categoria"],-818,150)
    text(management,A.L["Ao abrir um banco, use o seletor ao lado da busca para alternar entre inventário, banco do personagem e abas da tropa. Clique direito no cabeçalho para depositar/retirar uma categoria. No vendedor, você pode vender a categoria após confirmar. Favoritos e conjuntos são protegidos."],20,-43,550)
    text(p,A.L["Busca: expansao:tww · vinculo:boe · slot:anel · conjunto:\"Raid DPS\" · descricao:\"velocidade\" · melhoria:sim · transmog:sim"],32,-996,570)
    local category=section(self.settingsPages.categories.content,"Aba desta categoria",-1338,98)
    c.categoryTab=dropdown(category,20,-46,460,function(_,root)
        for _,tab in ipairs(self:GetTabs()) do
            root:CreateRadio(self:TabName(tab),function() return ((self.profile.categoryTabs or {})[self.settingsCategory] or "default")==tab.id end,
                function() self:AssignCategoryTab(self.settingsCategory,tab.id) end)
        end
    end)
end

function A:RefreshFeatureSettings()
    local c=self.settingsControls
    if not c or not c.featureBuilt then return end
    for key,b in pairs(c.indicators) do b:SetChecked(self:GetSettings()[key]~=false) end
    c.upgradeProvider:OverrideText(self:GetSettings().upgradeProvider=="pawn" and A.L["Pawn (se instalado)"] or A.L["Comparar ilvl"])
    local names={}
    for _,id in ipairs(self:GetSettings().currencies or {}) do
        local info=C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(id)
        names[#names+1]=info and info.name or tostring(id)
    end
    c.currencyNames:SetText(#names>0 and table.concat(names," · ") or A.L["Nenhuma moeda selecionada."])
    local choice="default"
    for _,tab in ipairs(self:GetTabs()) do if tab.id==self.settingsTab then choice=tab.id end end
    self.settingsTab=choice
    for _,tab in ipairs(self:GetTabs()) do
        if tab.id==choice then c.tabPicker:OverrideText(self:TabName(tab)); c.tabName:SetText(self:TabName(tab)) end
        if tab.id==((self.profile.categoryTabs or {})[self.settingsCategory] or "default") then c.categoryTab:OverrideText(self:TabName(tab)) end
    end
    c.deleteTab:SetEnabled(choice~="default" and not self.draft)
end
