local _, A = ...

A.ruleFields={{"type","Tipo"},{"quality","Qualidade"},{"ilvl","Nível do item"},{"name","Nome"},{"id","ID do item"},
    {"count","Quantidade"},{"expansion","Expansão"},{"binding","Vínculo"},{"slot","Slot de equipamento"},
    {"set","Conjunto"},{"subtype","Subtipo"},{"profession","Família de profissão"},{"craftquality","Qualidade de reagente"},
    {"reagent","Reagente"},{"tooltip","Descrição"},{"upgrade","Melhoria"},{"uncollected","Aparência não coletada"}}
local numeric={quality=true,ilvl=true,id=true,count=true,expansion=true,craftquality=true}
local choices={
    type={{"equipment","Equipamentos"},{"weapon","Armas"},{"armor","Armaduras"},{"consumable","Consumíveis"},{"tradegoods","Materiais"}},
    quality={{"0","Lixo"},{"1","Comum"},{"2","Incomum"},{"3","Raro"},{"4","Épico"},{"5","Lendário"}},
    expansion={{"0","Classic"},{"1","The Burning Crusade"},{"2","Wrath of the Lich King"},{"3","Cataclysm"},{"4","Mists of Pandaria"},
        {"5","Warlords of Draenor"},{"6","Legion"},{"7","Battle for Azeroth"},{"8","Shadowlands"},{"9","Dragonflight"},{"10","The War Within"},{"11","Midnight"}},
    binding={{"soulbound","Vinculado"},{"boe","Vincula ao equipar"},{"warbound","Vinculado à tropa"},{"wue","Vincula à tropa ao equipar"},{"nonbinding","Sem vínculo"}},
    slot={{"head","Cabeça"},{"neck","Pescoço"},{"shoulder","Ombros"},{"chest","Peito"},{"waist","Cintura"},{"legs","Pernas"},
        {"feet","Pés"},{"hands","Mãos"},{"wrist","Pulsos"},{"ring","Anel"},{"trinket","Berloque"},{"cloak","Capa"},{"weapon","Arma"}},
    profession={{"alchemy","Alquimia"},{"blacksmithing","Ferraria"},{"cooking","Culinária"},{"enchanting","Encantamento"},
        {"engineering","Engenharia"},{"herbalism","Herborismo"},{"inscription","Inscrição"},{"jewelcrafting","Joalheria"},
        {"leatherworking","Couraria"},{"mining","Mineração"},{"skinning","Esfolamento"},{"tailoring","Alfaiataria"}},
    craftquality={{"1","1"},{"2","2"},{"3","3"}},
}
for _,field in ipairs({"reagent","upgrade","uncollected"}) do choices[field]={{"true","Sim"},{"false","Não"}} end

local function label(parent,value,x,y,width)
    local f=parent:CreateFontString(nil,"OVERLAY","GameFontHighlight"); f:SetPoint("TOPLEFT",x,y); f:SetWidth(width or 570); f:SetJustifyH("LEFT"); f:SetText(value); return f
end
local function button(parent,value,x,y,width,fn)
    local b=CreateFrame("Button",nil,parent,"UIPanelButtonTemplate"); b:SetPoint("TOPLEFT",x,y); b:SetSize(width,26); b:SetText(value); b:SetScript("OnClick",fn); return b
end
local function dropdown(parent,x,y,width,fn)
    local d=CreateFrame("DropdownButton",nil,parent,"WowStyle2DropdownTemplate"); d:SetPoint("TOPLEFT",x,y); d:SetSize(width,26); d:SetupMenu(fn); return d
end

function A:RuleRowsFromQuery(query)
    local compiled=self:CompileQuery(query)
    if not compiled then return nil end
    if not compiled.tree then return {} end
    local groups={}
    local function splitOr(node)
        if node.kind=="any" then return splitOr(node.left) and splitOr(node.right) end
        groups[#groups+1]=node; return #groups<=4
    end
    if not splitOr(compiled.tree) then return nil end
    local rows={}
    for group,node in ipairs(groups) do
        local function splitAnd(n)
            if n.kind=="all" then return splitAnd(n.left) and splitAnd(n.right) end
            local invert=n.kind=="not"
            if invert then n=n.child end
            if n.kind~="term" then return false end
            local t=n.term
            rows[#rows+1]={group=group,field=t.field,value=t.number and tostring(t.number) or t.value,operator=t.operator or "=",invert=invert}
            return #rows<=8
        end
        if not splitAnd(node) then return nil end
    end
    return rows
end

function A:QueryFromRuleRows(rows)
    local groups={}
    if type(rows)~="table" or #rows>8 then return nil,self.L["Regra muito complexa."] end
    for _,row in ipairs(rows) do
        local value=(row.value or ""):match("^%s*(.-)%s*$")
        if value~="" then
            if value:find('["()]') or value:find("|",1,true) then return nil,self.L["Use o editor avançado para este valor."] end
            if row.group<1 or row.group>4 then return nil,self.L["Regra inválida."] end
            if value:find("%s") then value='"'..value..'"' end
            local term=(row.invert and "!" or "")..row.field..":"..(numeric[row.field] and row.operator~="=" and row.operator or "")..value
            groups[row.group]=groups[row.group] or {}; groups[row.group][#groups[row.group]+1]=term
        end
    end
    local result={}
    for group=1,4 do
        if groups[group] then result[#result+1]="("..table.concat(groups[group]," ")..")" end
    end
    local query=table.concat(result," | ")
    local valid,err=self:ValidateCategoryRule(query)
    return valid and query or nil,err
end

function A:MoveCategoryRulePriority(id,direction)
    if not self:CanChangeProfile() then return false end
    for index,cat in ipairs(self.categories) do
        if cat.id==id then
            local target=math.max(1,math.min(#self.categories,index+direction))
            self.categories[index],self.categories[target]=self.categories[target],self.categories[index]
            for _,item in ipairs(self.items or {}) do item.category=self:Classify(item) end
            self:Reconcile(); self:Render(); self:RefreshSettings()
            return true
        end
    end
    return false
end

function A:BuildRuleEditor()
    if self.ruleControls then return end
    local parent=self.settingsPages.rules.content
    local c={rows={}}; self.ruleControls=c
    label(parent,self.L["Categoria e prioridade"],20,-50)
    c.category=dropdown(parent,20,-80,360,function(_,root)
        for _,cat in ipairs(self.categories) do if cat.id~="reagentbag" then
            root:CreateRadio(self:CategoryName(cat.id),function() return self.settingsCategory==cat.id end,
                function() self.settingsCategory=cat.id; self:RefreshSettings() end)
        end end
    end)
    button(parent,"↑",392,-80,70,function() self:MoveCategoryRulePriority(self.settingsCategory,-1) end)
    button(parent,"↓",474,-80,70,function() self:MoveCategoryRulePriority(self.settingsCategory,1) end)
    c.priority=label(parent,"",20,-119)
    label(parent,self.L["Condições do mesmo grupo usam E. Grupos diferentes usam OU."],20,-154)
    label(parent,self.L["Grupo"],20,-185,65); label(parent,self.L["Filtro"],98,-185,140); label(parent,self.L["Valor"],320,-185,190)
    for index=1,8 do
        local y=-210-(index-1)*40
        local row={}; c.rows[index]=row
        local function changed() self:RefreshRuleEditorRows(); self:PreviewRuleEditor() end
        row.group=dropdown(parent,20,y,70,function(_,root)
            for n=1,4 do root:CreateRadio(tostring(n),function() return c.data[index] and c.data[index].group==n end,
                function() c.data[index].group=n; changed() end) end
        end)
        row.field=dropdown(parent,98,y,146,function(_,root)
            for _,entry in ipairs(A.ruleFields) do
                root:CreateRadio(self.L[entry[2]],function() return c.data[index] and c.data[index].field==entry[1] end,function()
                    local data=c.data[index]; data.field=entry[1]; data.operator="="; data.value=choices[entry[1]] and choices[entry[1]][1][1] or ""
                    changed()
                end)
            end
        end)
        row.operator=dropdown(parent,252,y,64,function(_,root)
            for _,op in ipairs({"=",">",">=","<","<="}) do root:CreateRadio(op,function() return c.data[index] and c.data[index].operator==op end,
                function() c.data[index].operator=op; changed() end) end
        end)
        row.value=CreateFrame("EditBox",nil,parent,"InputBoxTemplate"); row.value:SetPoint("TOPLEFT",324,y); row.value:SetSize(177,26); row.value:SetAutoFocus(false); row.value:SetMaxLetters(100)
        row.value:SetScript("OnEscapePressed",function(e) e:ClearFocus() end)
        row.value:SetScript("OnTextChanged",function(e)
            if not c.initializing and c.data and c.data[index] then c.data[index].value=e:GetText(); self:PreviewRuleEditor() end
        end)
        row.choice=dropdown(parent,320,y,185,function(_,root)
            local data=c.data[index]
            for _,entry in ipairs(data and choices[data.field] or {}) do
                root:CreateRadio(self.L[entry[2]],function() return data.value==entry[1] end,function() data.value=entry[1]; changed() end)
            end
        end)
        row.invert=CreateFrame("CheckButton",nil,parent,"UICheckButtonTemplate"); row.invert:SetPoint("TOPLEFT",511,y); row.invert:SetSize(26,26)
        row.invert:SetScript("OnClick",function() c.data[index].invert=not c.data[index].invert; changed() end)
        row.invert:SetScript("OnEnter",function() GameTooltip:SetOwner(row.invert,"ANCHOR_RIGHT"); GameTooltip:SetText(self.L["Excluir correspondências"]); GameTooltip:Show() end)
        row.invert:SetScript("OnLeave",function() GameTooltip:Hide() end)
        row.remove=button(parent,"−",548,y,36,function() table.remove(c.data,index); changed() end)
    end
    c.add=button(parent,self.L["Adicionar condição"],20,-548,205,function()
        if #c.data<8 then c.data[#c.data+1]={field="type",value="consumable",operator="=",group=1}; self:RefreshRuleEditorRows(); self:PreviewRuleEditor() end
    end)
    c.apply=button(parent,self.L["Aplicar regra visual"],242,-548,220,function()
        local query,err=self:QueryFromRuleRows(c.data)
        if query then self:SetCategoryOption(self.settingsCategory,"rule",query) else self:Print(err) end
    end)
    button(parent,self.L["Nova regra visual"],20,-588,205,function() c.data={}; c.unsupported=false; self:RefreshRuleEditorRows(); self:PreviewRuleEditor() end)
    c.preview=label(parent,"",20,-633); c.preview:SetHeight(72)
    c.query=label(parent,"",20,-719); c.query:SetHeight(78)
    label(parent,self.L["Editor avançado"],20,-820)
    c.advanced=CreateFrame("EditBox",nil,parent,"InputBoxTemplate"); c.advanced:SetPoint("TOPLEFT",24,-855); c.advanced:SetSize(540,26); c.advanced:SetAutoFocus(false); c.advanced:SetMaxLetters(256)
    c.advanced:SetScript("OnEscapePressed",function(e) e:ClearFocus() end)
    button(parent,self.L["Aplicar regra avançada"],20,-896,230,function() self:SetCategoryOption(self.settingsCategory,"rule",c.advanced:GetText()) end)
    label(parent,self.L["A primeira categoria compatível vence. Atribuições manuais têm prioridade. Famílias de profissão classificam tipos de materiais, não todos os reagentes de cada receita."],20,-946):SetHeight(100)
end

function A:RefreshRuleEditorRows()
    local c=self.ruleControls
    if not c then return end
    c.initializing=true
    for index,row in ipairs(c.rows) do
        local data=c.data[index]
        for _,control in pairs(row) do control:SetShown(data~=nil) end
        if data then
            row.group:OverrideText(tostring(data.group))
            for _,entry in ipairs(A.ruleFields) do if entry[1]==data.field then row.field:OverrideText(self.L[entry[2]]) end end
            row.operator:OverrideText(data.operator); row.operator:SetShown(numeric[data.field]==true)
            row.value:SetText(data.value); row.value:SetShown(not choices[data.field]); row.choice:SetShown(choices[data.field]~=nil)
            if choices[data.field] then
                local title=data.value
                for _,entry in ipairs(choices[data.field]) do if entry[1]==data.value then title=self.L[entry[2]] end end
                row.choice:OverrideText(title)
            end
            row.invert:SetChecked(data.invert==true)
        end
    end
    c.add:SetEnabled(not c.unsupported and #c.data<8 and self.settingsCategory~="reagentbag")
    c.apply:SetEnabled(not c.unsupported and self.settingsCategory~="reagentbag")
    c.initializing=false
end

function A:PreviewRuleEditor()
    local c=self.ruleControls
    if not c then return end
    if c.unsupported then c.preview:SetText(self.L["Esta regra usa uma estrutura avançada. Edite o texto ou crie uma nova regra visual."]); c.query:SetText(""); return end
    local query,err=self:QueryFromRuleRows(c.data)
    c.apply:SetEnabled(query~=nil and self.settingsCategory~="reagentbag")
    c.query:SetText(query or err)
    local count,names=0,{}
    if query and query~="" then for _,item in ipairs(self.items or {}) do
        if self:MatchesQuery(item,query) then count=count+1; if #names<5 then names[#names+1]=item.name end end
    end end
    c.preview:SetText(string.format(self.L["Prévia: %d pilhas correspondem à regra."],count)..(#names>0 and "\n"..table.concat(names," · ") or ""))
end

function A:RefreshRuleEditor()
    local c=self.ruleControls
    if not c then return end
    local rule=self:GetLayout()[self.settingsCategory].rule or ""
    if c.categoryID~=self.settingsCategory or c.profile~=self.profile or c.savedRule~=rule then
        c.categoryID,c.profile,c.savedRule=self.settingsCategory,self.profile,rule
        c.data=self:RuleRowsFromQuery(rule); c.unsupported=c.data==nil; c.data=c.data or {}
        c.advanced:SetText(rule)
    end
    c.category:OverrideText(self:CategoryName(self.settingsCategory))
    for index,cat in ipairs(self.categories) do if cat.id==self.settingsCategory then c.priority:SetText(string.format(self.L["Prioridade: %d/%d"],index,#self.categories)) end end
    self:RefreshRuleEditorRows(); self:PreviewRuleEditor()
end
