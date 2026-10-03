local _, A = ...

local aliases={nome="name",tipo="type",qualidade="quality",nivel="ilvl",categoria="category",favorito="favorite",
    novo="new",reagente="reagent",expansao="expansion",vinculo="binding",slot="slot",conjunto="set",equipmentset="set",
    descricao="tooltip",subtipo="subtype",melhoria="upgrade",transmog="uncollected",profissao="profession",
    quantidade="count",reagentquality="craftquality",qualidadereagente="craftquality"}
local qualities={lixo=0,poor=0,comum=1,common=1,incomum=2,uncommon=2,raro=3,rare=3,epico=4,epic=4,lendario=5,legendary=5}
local types={arma=2,weapon=2,armadura=4,armor=4,consumivel=0,consumable=0,material=7,tradegoods=7,equipamento=-1,equipment=-1}
local fields={name=true,type=true,quality=true,ilvl=true,id=true,category=true,favorite=true,new=true,reagent=true,
    expansion=true,binding=true,slot=true,set=true,tooltip=true,subtype=true,upgrade=true,uncollected=true,
    profession=true,count=true,craftquality=true}
local slotAliases={cabeca="INVTYPE_HEAD",head="INVTYPE_HEAD",pescoco="INVTYPE_NECK",neck="INVTYPE_NECK",
    ombro="INVTYPE_SHOULDER",shoulder="INVTYPE_SHOULDER",peito="INVTYPE_CHEST",chest="INVTYPE_CHEST",
    mao="INVTYPE_HAND",hands="INVTYPE_HAND",pernas="INVTYPE_LEGS",legs="INVTYPE_LEGS",pes="INVTYPE_FEET",feet="INVTYPE_FEET",
    anel="INVTYPE_FINGER",finger="INVTYPE_FINGER",ring="INVTYPE_FINGER",berloque="INVTYPE_TRINKET",trinket="INVTYPE_TRINKET",
    capa="INVTYPE_CLOAK",cloak="INVTYPE_CLOAK",escudo="INVTYPE_SHIELD",shield="INVTYPE_SHIELD",arma="INVTYPE_WEAPON",
    weapon="INVTYPE_WEAPON",duasmaos="INVTYPE_2HWEAPON",twohand="INVTYPE_2HWEAPON",cintura="INVTYPE_WAIST",
    waist="INVTYPE_WAIST",pulso="INVTYPE_WRIST",wrist="INVTYPE_WRIST"}
local numeric={id=true,ilvl=true,quality=true,expansion=true,count=true,craftquality=true}
local booleans={favorite=true,new=true,reagent=true,upgrade=true,uncollected=true}

local function term(token)
    local key,value=token:match("^([%a]+):(.*)$")
    if not key then key,value="name",token end
    key=aliases[key] or key
    assert(fields[key] and value~="",A.L["Filtro inválido: "]..token)
    local t={field=key,value=value}
    if numeric[key] then
        if key=="quality" then value=tostring(qualities[value] or value) end
        if key=="expansion" then value=tostring((A.expansionAliases or {})[value] or value) end
        local operator,number=value:match("^([<>]=?)(%d+)$")
        t.number=tonumber(number or value); t.operator=operator or "="
        assert(t.number and t.number>=0 and t.number<=10000000,A.L["Valor numérico inválido: "]..token)
    elseif key=="type" then
        t.number=types[value] or tonumber(value)
        assert(t.number,A.L["Tipo desconhecido: "]..value)
    elseif key=="slot" then t.value=slotAliases[value] or value:upper()
    elseif booleans[key] then
        assert(value=="sim" or value=="nao" or value=="true" or value=="false" or value=="1" or value=="0",A.L["Use sim ou nao: "]..token)
        t.boolean=value=="sim" or value=="true" or value=="1"
    end
    return t
end

function A:CompileQuery(query)
    if type(query)~="string" and query~=nil then return nil,self.L["Regra inválida."] end
    query=(query or ""):lower():match("^%s*(.-)%s*$")
    if #query>256 then return nil,self.L["Use no máximo 256 caracteres."] end
    if query=="" then return {terms={}} end
    if not query:find(":",1,true) and not query:find("[()|]") then
        local t={field="name",value=query}; return {terms={t},tree={kind="term",term=t}}
    end
    local tokens,at={},1
    while at<=#query do
        local c=query:sub(at,at)
        if c:match("%s") then at=at+1
        elseif c=="(" or c==")" or c=="|" or c=="!" then tokens[#tokens+1]=c; at=at+1
        else
            local start,quoted=at,false
            while at<=#query do
                c=query:sub(at,at)
                if c=='"' then quoted=not quoted
                elseif not quoted and (c:match("%s") or c=="(" or c==")" or c=="|") then break end
                at=at+1
            end
            if quoted then return nil,self.L["Aspas incompletas."] end
            tokens[#tokens+1]=query:sub(start,at-1):gsub('"',"")
        end
        if #tokens>96 then return nil,self.L["Regra muito complexa."] end
    end
    local position,terms=1,{}
    local parseOr,parseAnd,parseAtom
    local function isOr(t) return t=="|" or t=="or" or t=="ou" end
    local function isAnd(t) return t=="and" or t=="e" end
    parseAtom=function(depth)
        assert(depth<=8,self.L["Regra muito complexa."])
        local token=tokens[position]; position=position+1
        assert(token and token~=")" and not isOr(token) and not isAnd(token),self.L["Regra incompleta."])
        if token=="!" then return {kind="not",child=parseAtom(depth+1)} end
        if token=="(" then
            local node=parseOr(depth+1)
            assert(tokens[position]==")",self.L["Parênteses incompletos."]); position=position+1
            return node
        end
        local t=term(token); terms[#terms+1]=t
        return {kind="term",term=t}
    end
    parseAnd=function(depth)
        local node=parseAtom(depth)
        while tokens[position] and tokens[position]~=")" and not isOr(tokens[position]) do
            if isAnd(tokens[position]) then position=position+1 end
            node={kind="all",left=node,right=parseAtom(depth)}
        end
        return node
    end
    parseOr=function(depth)
        local node=parseAnd(depth)
        while isOr(tokens[position]) do position=position+1; node={kind="any",left=node,right=parseAnd(depth)} end
        return node
    end
    local ok,tree=pcall(function() local node=parseOr(1); assert(position>#tokens,self.L["Regra incompleta."]); return node end)
    if not ok then return nil,tostring(tree):gsub("^.-:%d+: ","") end
    return {tree=tree,terms=terms}
end

function A:ValidateCategoryRule(rule)
    local compiled,err=self:CompileQuery(rule)
    if not compiled then return false,err end
    for _,t in ipairs(compiled.terms) do
        if t.field=="category" or t.field=="favorite" or t.field=="new" then
            return false,self.L["Regras não podem depender de categoria, favorito ou item novo."]
        end
    end
    return true
end

local function compare(value,t)
    if type(value)~="number" then return false end
    if t.operator==">" then return value>t.number end
    if t.operator==">=" then return value>=t.number end
    if t.operator=="<" then return value<t.number end
    if t.operator=="<=" then return value<=t.number end
    return value==t.number
end

function A:MatchQueryTerm(item,t)
    local field=t.field
    if field=="name" then return (item.sortName or (item.name or ""):lower()):find(t.value,1,true)~=nil
    elseif field=="type" then return item.classID==t.number or (t.number==-1 and (item.classID==2 or item.classID==4))
    elseif field=="id" then return compare(item.info.itemID,t)
    elseif field=="quality" then return compare(item.info.quality,t)
    elseif field=="ilvl" then return compare(item.itemLevel,t)
    elseif field=="count" then return compare(item.info.stackCount or 1,t)
    elseif field=="craftquality" then return compare(item.craftQuality,t)
    elseif field=="category" then return item.category==t.value or self:CategoryName(item.category or ""):lower():find(t.value,1,true)~=nil
    elseif field=="favorite" then return (self.profile.favorites[item.info.itemID]~=nil)==t.boolean
    elseif field=="new" then return (not item.offline and not not C_NewItems.IsNewItem(item.bag,item.slot))==t.boolean
    elseif field=="reagent" then return (not not item.reagent)==t.boolean
    elseif field=="expansion" then return compare(item.expansionID,t)
    elseif field=="binding" then return (item.binding or "")==t.value
    elseif field=="slot" then return item.equipLoc==t.value or (t.value=="INVTYPE_CHEST" and item.equipLoc=="INVTYPE_ROBE")
    elseif field=="set" then return (item.equipmentSet or ""):lower():find(t.value,1,true)~=nil
    elseif field=="tooltip" then return self:GetSearchTooltip(item):find(t.value,1,true)~=nil
    elseif field=="subtype" then return (item.subtype or ""):lower():find(t.value,1,true)~=nil
    elseif field=="profession" then return self:MatchesProfessionFamily(item,t.value)
    elseif field=="upgrade" then return (not not item.upgrade)==t.boolean
    elseif field=="uncollected" then return (not not item.uncollected)==t.boolean end
    return false
end

local function matchTree(owner,item,node)
    if not node then return true end
    if node.kind=="term" then return owner:MatchQueryTerm(item,node.term) end
    if node.kind=="not" then return not matchTree(owner,item,node.child) end
    if node.kind=="all" then return matchTree(owner,item,node.left) and matchTree(owner,item,node.right) end
    return matchTree(owner,item,node.left) or matchTree(owner,item,node.right)
end

function A:MatchesQuery(item,query)
    self.queryCache=self.queryCache or {}; self.queryCacheSize=self.queryCacheSize or 0
    local compiled=self.queryCache[query]
    if compiled==nil then
        if self.queryCacheSize>=64 then self:ClearTable(self.queryCache); self.queryCacheSize=0 end
        compiled=self:CompileQuery(query) or false
        self.queryCache[query]=compiled; self.queryCacheSize=self.queryCacheSize+1
    end
    if not compiled then return false end
    return matchTree(self,item,compiled.tree)
end
