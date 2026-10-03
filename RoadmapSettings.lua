local _, A = ...

local function text(parent,value,x,y,width)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight"); f:SetPoint("TOPLEFT",x,y); f:SetWidth(width or 550); f:SetJustifyH("LEFT"); f:SetText(value); return f
end
local function section(parent,title,y,height)
    local f=CreateFrame("Frame",nil,parent,"BackdropTemplate"); f:SetPoint("TOPLEFT",16,y); f:SetSize(600,height)
    f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    f:SetBackdropColor(0.08,0.08,0.09,0.75); f:SetBackdropBorderColor(0.28,0.25,0.2,1)
    text(f,title,16,-14):SetFontObject("GameFontNormalLarge"); return f
end
local function button(parent,title,x,y,width,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate"); b:SetPoint("TOPLEFT",x,y); b:SetSize(width,26); b:SetText(title); b:SetScript("OnClick",fn); return b
end
local function dropdown(parent,x,y,width,fn)
    local d=CreateFrame("DropdownButton",nil,parent,"WowStyle2DropdownTemplate"); d:SetPoint("TOPLEFT",x,y); d:SetSize(width,26); d:SetupMenu(fn); return d
end
A.sortChoices={{"name","Nome"},{"quality","Qualidade"},{"ilvl","Nível do item"},{"count","Quantidade"},{"expansion","Expansão"}}

function A:BuildRoadmapSettings()
    if self.roadmapControls then return end
    local c={}; self.roadmapControls=c
    local p=self.settingsPages.tools.content
    local presets=section(p,self.L["Layouts iniciais"],-42,133)
    c.preset=dropdown(presets,20,-45,320,function(_,root)
        for _,preset in ipairs(A.layoutPresets) do
            root:CreateRadio(self.L[preset.name],function() return (self.settingsPreset or "balanced")==preset.id end,
                function() self.settingsPreset=preset.id; self:RefreshSettings() end)
        end
    end)
    button(presets,self.L["Aplicar layout…"],360,-45,210,function() self:RequestLayoutPreset(self.settingsPreset or "balanced") end)
    text(presets,self.L[self.isBankWindow and "Altera apenas as categorias deste banco. Os painéis continuam fixos após aplicar o layout." or "Altera apenas as categorias da aba atual. Os painéis continuam fixos após aplicar o layout."],20,-90)
    local themes=section(p,self.L["Tema"],-187,132)
    c.theme=dropdown(themes,20,-45,380,function(_,root)
        for _,entry in ipairs({{"blizzard","Blizzard"},{"dark","Escuro"},{"elvui","ElvUI"}}) do
            root:CreateRadio(self.L[entry[2]],function() return (self:GetSettings().theme or "blizzard")==entry[1] end,
                function() self:SetFeatureOption("theme",entry[1]) end)
        end
    end)
    text(themes,self.L["ElvUI usa as fontes e cores desse addon quando instalado; caso contrário, usa o tema escuro. Desative o módulo de bolsas do ElvUI para usar BlockBags."],20,-90)
    local category=section(p,self.L["Categoria selecionada"],-331,95)
    c.category=dropdown(category,20,-45,510,function(_,root)
        for _,cat in ipairs(self.categories) do if not self.isBankWindow or cat.id~="reagentbag" then
            root:CreateRadio(self:CategoryName(cat.id),function() return self.settingsCategory==cat.id end,
                function() self.settingsCategory=cat.id; self:RefreshSettings() end)
        end end
    end)
    local appearance=section(p,self.L["Copiar aparência e restaurar"],-438,163)
    c.copyTarget=dropdown(appearance,20,-45,315,function(_,root)
        for _,cat in ipairs(self.categories) do if cat.id~=self.settingsCategory and (not self.isBankWindow or cat.id~="reagentbag") then
            root:CreateRadio(self:CategoryName(cat.id),function() return self.settingsCopyTarget==cat.id end,
                function() self.settingsCopyTarget=cat.id; self:RefreshSettings() end)
        end end
    end)
    button(appearance,self.L["Copiar aparência"],360,-45,210,function() self:CopyCategoryAppearance(self.settingsCategory,self.settingsCopyTarget) end)
    button(appearance,self.L["Restaurar esta categoria…"],20,-89,290,function()
        StaticPopupDialogs.BLOCKBAGS_RESET_CATEGORY=StaticPopupDialogs.BLOCKBAGS_RESET_CATEGORY or {
            text=self.L["Restaurar tamanho e aparência desta categoria? O nome e as regras serão mantidos."],
            button1=ACCEPT,button2=CANCEL,timeout=0,whileDead=true,hideOnEscape=true,
            OnAccept=function(_,data) data.owner:ResetCategory(data.id) end}
        StaticPopup_Show("BLOCKBAGS_RESET_CATEGORY",nil,nil,{owner=self,id=self.settingsCategory})
    end)
    text(appearance,self.L["Copia tamanho dos ícones, espaçamento e cor; não altera regras, posições ou dimensões do painel."],20,-128)
    local sort=section(p,self.L["Ordenação desta categoria"],-613,165)
    c.sort=dropdown(sort,20,-45,315,function(_,root)
        for _,entry in ipairs(A.sortChoices) do
            root:CreateRadio(self.L[entry[2]],function() return (self:GetLayout()[self.settingsCategory].sortBy or "name")==entry[1] end,
                function() self:SetCategoryOption(self.settingsCategory,"sortBy",entry[1]) end)
        end
    end)
    c.direction=button(sort,"",360,-45,210,function()
        local d=self:GetLayout()[self.settingsCategory]
        local descending=d.sortDescending
        if descending==nil then descending=(d.sortBy or "name")~="name" end
        self:SetCategoryOption(self.settingsCategory,"sortDescending",not descending)
    end)
    button(sort,self.L["Organizar agora"],20,-86,250,function() if not InCombatLockdown() and not self.draft then self.organizeCategory=self.settingsCategory; self:Reconcile(); self:Render() end end)
    text(sort,self.L["A ordem só muda ao organizar ou no modo automático. Posições reservadas são preservadas."],20,-125)
    local stacks=section(p,self.L["Pilhas agrupadas"],-790,153)
    c.stacks=CreateFrame("CheckButton",nil,stacks,"UICheckButtonTemplate"); c.stacks:SetPoint("TOPLEFT",16,-42); c.stacks:SetSize(26,26)
    text(stacks,self.L["Agrupar pilhas iguais nesta categoria"],50,-47,510)
    c.stacks:SetScript("OnClick",function() local d=self:GetLayout()[self.settingsCategory]; self:SetCategoryOption(self.settingsCategory,"stackGrouping",not d.stackGrouping) end)
    text(stacks,self.L["Agrupamento apenas visual e opcional. O + mostra os slots reais. Favoritos, equipamentos e slots posicionados manualmente não são agrupados."],20,-85)
    local diagnostics=section(p,self.L["Desempenho"],-955,142)
    button(diagnostics,self.L["Medir CPU e memória"],20,-44,260,function() self:ReportPerformance() end)
    button(diagnostics,self.L["Reiniciar medições"],300,-44,260,function() self:ResetPerformanceMeasurements() end)
    text(diagnostics,self.L["As medições acompanham atualizações por evento. Não há varredura contínua nem coleta de lixo automática."],20,-89)
    if not self.isBankWindow then
        local offline=self.settingsPages.offline.content
        local history=section(offline,self.L["Inventário offline"],-42,182)
        c.cacheEnabled=CreateFrame("CheckButton",nil,history,"UICheckButtonTemplate"); c.cacheEnabled:SetPoint("TOPLEFT",16,-43); c.cacheEnabled:SetSize(26,26)
        text(history,self.L["Salvar mochila e bancos visitados para consulta"],50,-48,510)
        c.cacheEnabled:SetScript("OnClick",function() self:SetOfflineOption("enabled",not self:GetOfflineCache().enabled) end)
        button(history,self.L["Abrir inventário offline"],20,-90,250,function() self:OpenOfflineInventory() end)
        button(history,self.L["Limpar inventário offline…"],300,-90,250,function()
            StaticPopupDialogs.BLOCKBAGS_CLEAR_OFFLINE=StaticPopupDialogs.BLOCKBAGS_CLEAR_OFFLINE or {
                text=self.L["Apagar todos os registros offline? Os itens e perfis não serão alterados."],button1=ACCEPT,button2=CANCEL,
                timeout=0,whileDead=true,hideOnEscape=true,OnAccept=function() self:ClearOfflineCache() end}
            StaticPopup_Show("BLOCKBAGS_CLEAR_OFFLINE")
        end)
        text(history,self.L["Desativado por padrão. Mostra apenas dados da última visita, sem permitir usar ou mover itens. Desativar a coleta mantém os registros até limpar ou expirar."],20,-132)
        local limits=section(offline,self.L["Limites do inventário offline"],-236,268)
        c.characters=self:CreateSettingSlider(limits,-83,1,20,1,function(value) self:SetOfflineOption("maxCharacters",value) end)
        c.items=self:CreateSettingSlider(limits,-146,500,12000,500,function(value) self:SetOfflineOption("maxItems",value) end)
        c.days=self:CreateSettingSlider(limits,-209,1,90,1,function(value) self:SetOfflineOption("retentionDays",value) end)
        local state=section(offline,self.L["Registros salvos"],-516,124)
        c.cacheInfo=text(state,"",20,-45)
        text(state,self.L["O banco da tropa tem um único registro compartilhado. Os registros mais antigos são descartados primeiro quando um limite é atingido."],20,-79)
    end
end

function A:RefreshRoadmapSettings()
    local c=self.roadmapControls
    if not c then return end
    local d=self:GetLayout()[self.settingsCategory]
    local theme=self:GetSettings().theme or "blizzard"
    c.theme:OverrideText(theme=="blizzard" and "Blizzard" or theme=="elvui" and "ElvUI" or self.L["Escuro"])
    for _,preset in ipairs(A.layoutPresets) do if preset.id==(self.settingsPreset or "balanced") then c.preset:OverrideText(self.L[preset.name]) end end
    c.category:OverrideText(self:CategoryName(self.settingsCategory))
    if not self:GetLayout()[self.settingsCopyTarget or ""] or self.settingsCopyTarget==self.settingsCategory then
        self.settingsCopyTarget=nil
        for _,cat in ipairs(self.categories) do if cat.id~=self.settingsCategory and (not self.isBankWindow or cat.id~="reagentbag") then self.settingsCopyTarget=cat.id; break end end
    end
    c.copyTarget:OverrideText(self.settingsCopyTarget and self:CategoryName(self.settingsCopyTarget) or "—")
    for _,entry in ipairs(A.sortChoices) do if entry[1]==(d.sortBy or "name") then c.sort:OverrideText(self.L[entry[2]]) end end
    local descending=d.sortDescending
    if descending==nil then descending=(d.sortBy or "name")~="name" end
    c.direction:SetText(descending and self.L["Decrescente"] or self.L["Crescente"])
    c.stacks:SetChecked(d.stackGrouping==true)
    if c.cacheEnabled then
        local cache=self:GetOfflineCache()
        c.cacheEnabled:SetChecked(cache.enabled==true)
        c.characters:SetValue(cache.maxCharacters); c.characters.caption:SetText(self.L["Personagens: "]..cache.maxCharacters)
        c.items:SetValue(cache.maxItems); c.items.caption:SetText(self.L["Limite total de itens: "]..cache.maxItems)
        c.days:SetValue(cache.retentionDays); c.days.caption:SetText(self.L["Retenção em dias: "]..cache.retentionDays)
        local count=0; for _ in pairs(cache.snapshots) do count=count+1 end
        c.cacheInfo:SetText(string.format(self.L["%d registros · %d itens armazenados"],count,cache.itemCount or 0))
    end
end
