local _, A = ...

-- Data-only filters. No loadstring, arbitrary Lua or eager tooltip scans.
local aliases={nome="name",tipo="type",qualidade="quality",nivel="ilvl",categoria="category",
    favorito="favorite",novo="new",reagente="reagent",expansao="expansion",vinculo="binding",slot="slot",
    conjunto="set",equipmentset="set",descricao="tooltip",subtipo="subtype",melhoria="upgrade",transmog="uncollected"}
local qualities={lixo=0,poor=0,comum=1,common=1,incomum=2,uncommon=2,raro=3,rare=3,
    epico=4,epic=4,lendario=5,legendary=5}
local types={arma=2,weapon=2,armadura=4,armor=4,consumivel=0,consumable=0,material=7,tradegoods=7,
    equipamento=-1,equipment=-1}
local fields={name=true,type=true,quality=true,ilvl=true,id=true,category=true,favorite=true,new=true,reagent=true,
    expansion=true,binding=true,slot=true,set=true,tooltip=true,subtype=true,upgrade=true,uncollected=true}
local slotAliases={cabeca="INVTYPE_HEAD",head="INVTYPE_HEAD",pescoco="INVTYPE_NECK",neck="INVTYPE_NECK",
    ombro="INVTYPE_SHOULDER",shoulder="INVTYPE_SHOULDER",peito="INVTYPE_CHEST",chest="INVTYPE_CHEST",
    mao="INVTYPE_HAND",hands="INVTYPE_HAND",pernas="INVTYPE_LEGS",legs="INVTYPE_LEGS",pes="INVTYPE_FEET",feet="INVTYPE_FEET",
    anel="INVTYPE_FINGER",finger="INVTYPE_FINGER",ring="INVTYPE_FINGER",berloque="INVTYPE_TRINKET",trinket="INVTYPE_TRINKET",
    capa="INVTYPE_CLOAK",cloak="INVTYPE_CLOAK",escudo="INVTYPE_SHIELD",shield="INVTYPE_SHIELD",
    arma="INVTYPE_WEAPON",weapon="INVTYPE_WEAPON",duasmaos="INVTYPE_2HWEAPON",twohand="INVTYPE_2HWEAPON",
    cintura="INVTYPE_WAIST",waist="INVTYPE_WAIST",pulso="INVTYPE_WRIST",wrist="INVTYPE_WRIST"}

function A:CompileQuery(query)
    query=(query or ""):lower():match("^%s*(.-)%s*$")
    if #query>256 then return nil,"Use no máximo 256 caracteres." end
    local compiled={}
    if query=="" then return compiled end
    -- Plain text retains phrase search. Attribute queries combine terms with AND.
    if not query:find(":",1,true) then return {{field="name",value=query}} end
    -- Quoted field values support set/tooltip names containing spaces.
    local tokens,at={},1
    while at<=#query do
        local start=at
        if query:sub(at,at):match("%s") then at=at+1
        else
            local quoted=false
            while at<=#query do
                local c=query:sub(at,at)
                if c=='"' then quoted=not quoted
                elseif c:match("%s") and not quoted then break end
                at=at+1
            end
            if quoted then return nil,"Aspas incompletas." end
            tokens[#tokens+1]=query:sub(start,at-1):gsub('"',"")
        end
    end
    for _,token in ipairs(tokens) do
        local invert=token:sub(1,1)=="!"
        if invert then token=token:sub(2) end
        local key,value=token:match("^([%a]+):(.*)$")
        if not key then key,value="name",token end
        key=aliases[key] or key
        if not fields[key] or value=="" then return nil,"Filtro inválido: "..token end
        local term={field=key,value=value,invert=invert}
        if key=="id" or key=="ilvl" or key=="quality" then
            if key=="quality" then value=tostring(qualities[value] or value) end
            local operator,number=value:match("^([<>]=?)(%d+)$")
            term.number=tonumber(number or value); term.operator=operator or "="
            if not term.number then return nil,"Valor numérico inválido: "..token end
        elseif key=="type" then
            term.number=types[value] or tonumber(value)
            if not term.number then return nil,"Tipo desconhecido: "..value end
        elseif key=="expansion" then
            term.number=(self.expansionAliases or {})[value] or tonumber(value)
            if not term.number then return nil,"Expansão desconhecida: "..value end
        elseif key=="slot" then term.value=slotAliases[value] or value:upper()
        elseif key=="favorite" or key=="new" or key=="reagent" or key=="upgrade" or key=="uncollected" then
            if value~="sim" and value~="nao" and value~="true" and value~="false" and value~="1" and value~="0" then return nil,"Use sim ou nao: "..token end
            term.boolean=value=="sim" or value=="true" or value=="1"
        end
        compiled[#compiled+1]=term
    end
    return compiled
end

function A:ValidateCategoryRule(rule)
    local terms,err=self:CompileQuery(rule)
    if not terms then return false,err end
    for _,term in ipairs(terms) do
        if term.field=="category" or term.field=="favorite" or term.field=="new" then
            return false,"Regras não podem depender de categoria, favorito ou item novo."
        end
    end
    return true
end

local function compare(value,term)
    if type(value)~="number" then return false end
    if term.operator==">" then return value>term.number end
    if term.operator==">=" then return value>=term.number end
    if term.operator=="<" then return value<term.number end
    if term.operator=="<=" then return value<=term.number end
    return value==term.number
end

function A:MatchesQuery(item,query)
    self.queryCache=self.queryCache or {}; self.queryCacheSize=self.queryCacheSize or 0
    local terms=self.queryCache[query]
    if terms==nil then
        if self.queryCacheSize>=64 then self:ClearTable(self.queryCache); self.queryCacheSize=0 end
        terms=self:CompileQuery(query) or false
        self.queryCache[query]=terms; self.queryCacheSize=self.queryCacheSize+1
    end
    if not terms then return false end
    for _,term in ipairs(terms) do
        local field,match=term.field,false
        if field=="name" then match=(item.sortName or item.name:lower()):find(term.value,1,true)~=nil
        elseif field=="type" then match=item.classID==term.number or (term.number==-1 and (item.classID==2 or item.classID==4))
        elseif field=="id" then match=compare(item.info.itemID,term)
        elseif field=="quality" then match=compare(item.info.quality,term)
        elseif field=="ilvl" then match=compare(item.itemLevel,term)
        elseif field=="category" then match=item.category==term.value or self:CategoryName(item.category or ""):lower():find(term.value,1,true)~=nil
        elseif field=="favorite" then match=(self.profile.favorites[item.info.itemID]~=nil)==term.boolean
        elseif field=="new" then match=(not not C_NewItems.IsNewItem(item.bag,item.slot))==term.boolean
        elseif field=="reagent" then match=(not not item.reagent)==term.boolean
        elseif field=="expansion" then match=item.expansionID==term.number
        elseif field=="binding" then match=(item.binding or "")==term.value
        elseif field=="slot" then match=item.equipLoc==term.value or (term.value=="INVTYPE_CHEST" and item.equipLoc=="INVTYPE_ROBE")
        elseif field=="set" then match=(item.equipmentSet or ""):lower():find(term.value,1,true)~=nil
        elseif field=="tooltip" then match=self:GetSearchTooltip(item):find(term.value,1,true)~=nil
        elseif field=="subtype" then match=(item.subtype or ""):lower():find(term.value,1,true)~=nil
        elseif field=="upgrade" then match=(not not item.upgrade)==term.boolean
        elseif field=="uncollected" then match=(not not item.uncollected)==term.boolean end
        if term.invert then match=not match end
        if not match then return false end
    end
    return true
end
