local _, A = ...

function A:RememberDrop(frame)
    if self.draft or InCombatLockdown() or not frame.anchorCategory then return end
    local kind, id
    if GetCursorInfo then kind, id = GetCursorInfo() end
    if kind and kind ~= "item" then return end
    self.pendingPlacements = self.pendingPlacements or {}
    local key = frame.currentItem and frame.currentItem.slotKey or frame.anchorSlotKey
    if key then self.pendingPlacements[key] = {category=frame.anchorCategory, index=frame.anchorIndex, itemID=id} end
end

function A:DropIntoCategory(category)
    if self.draft or InCombatLockdown() then return false end
    if self.TryVirtualDrop and self:TryVirtualDrop(category) then return true end
    local layout=self:GetLayout()[category]
    local kind,id=GetCursorInfo()
    if not layout or layout.hidden or kind~="item" then return false end
    local group=self.groups[category]
    if not group then return false end
    local chosen,index
    local function available(slot)
        local reagent=slot.bag==Enum.BagIndex.ReagentBag
        if category=="reagentbag" then
            if not reagent then return false end
        elseif reagent or (slot.family or 0)~=0 then return false end
        local info=C_Container.GetContainerItemInfo(slot.bag,slot.slot)
        return not info or not info.itemID
    end
    -- Recheck the empty slot: picking up an item may have made the scan stale.
    for position,slot in pairs(self.emptyPositions[category] or {}) do
        if (not index or position<index) and available(slot) then chosen,index=slot,position end
    end
    if not chosen then
        for _,slot in ipairs(self.emptySlots or {}) do
            if available(slot) then chosen=slot; break end
        end
        index=1
        while group.positions[index] or group.reserved[index] or (self.emptyPositions[category] or {})[index] do index=index+1 end
    end
    if not chosen then self:Print(A.L["Não há um slot físico livre compatível para receber este item."]); return false end
    self:RememberDrop({anchorCategory=category,anchorIndex=index,anchorSlotKey=chosen.slotKey})
    C_Container.PickupContainerItem(chosen.bag,chosen.slot)
    -- Clear the pending category assignment when a transfer fails.
    if CursorHasItem() then
        if self.pendingPlacements then self.pendingPlacements[chosen.slotKey]=nil end
        return false
    end
    self:QueueRefresh()
    return true
end

function A:CanChangeProfile()
    if InCombatLockdown() then self:Print(A.L["Aguarde o fim do combate."]); return false end
    if self.draft then self:Print(A.L["Salve ou cancele a edição do layout antes de trocar perfis ou criar categorias."]); return false end
    return true
end

function A:RefreshProfile()
    self:ApplyBlizzardBagBarVisibility()
    self.activeTab="default"
    self:CancelBulkAction()
    self.physicalBagView=false
    self.categoryWindowSize=nil
    if self.bagSlots then self.bagSlots:Hide() end
    if self.physicalSections then for _,panel in pairs(self.physicalSections) do panel:Hide() end end
    if self.CancelInteractions then self:CancelInteractions() end
    self.categories = self.profile.categories
    self.panelPool=self.panelPool or {}
    for _, panel in pairs(self.panels) do panel:Hide(); self.panelPool[#self.panelPool+1]=panel end
    self.panels={}
    for _, cat in ipairs(self.categories) do self:CreatePanel(cat) end
    self.lastCategories = nil
    self.window:SetScale(self.profile.window.scale or 0.85)
    self.window:SetSize(self.profile.window.width or 912, self.profile.window.height or 716)
    self.window:ClearAllPoints()
    self.window:SetPoint("CENTER", UIParent, "CENTER", self.profile.window.x or 0, self.profile.window.y or 0)
    self:ResizeCanvas()
    self:ScanInventory(); self:Reconcile(); self:Render()
    if self.RefreshSettings then self:RefreshSettings() end
end

function A:SelectProfile(name)
    if not self:CanChangeProfile() or not self:GetDatabase().profiles[name] then return false end
    self.profileKey, self.profile = name, self:GetDatabase().profiles[name]
    local p=self.profile
    p.categories=p.categories or self:Copy(self.baseCategories)
    p.placements=p.placements or {}; p.favorites=p.favorites or {}; p.manualCategories=p.manualCategories or {}
    local positions=self:GetDatabase().inventoryPositions[self.characterKey]
    positions[name]=positions[name] or {}
    p.placements=positions[name]
    p.settings=p.settings or {categorySpacing=0}; p.window=p.window or {x=0,y=0,scale=0.85}
    if not p.spacingLayoutVersion then self:PackLayout(p.layout,p.settings.categorySpacing or 0); p.spacingLayoutVersion=1 end
    self:GetDatabase().characterProfiles[self.characterKey] = name
    self:RefreshProfile()
    return true
end

function A:CreateProfile(name, duplicate)
    if not self:CanChangeProfile() then return false end
    name = (name or ""):match("^%s*(.-)%s*$")
    if #name == 0 or #name > 60 or self:GetDatabase().profiles[name] then self:Print(A.L["Use um nome novo com até 60 caracteres."]); return false end
    local profile
    if duplicate then profile = self:Copy(self.profile); profile.placements = {}
    else
        local categories = self.categories
        self.categories = self.baseCategories
        profile = {categories=self:Copy(self.baseCategories),layout=self:DefaultLayout(),settings={categorySpacing=0},
            window={x=0,y=0,scale=0.85},placements={},favorites={},manualCategories={}}
        self.categories = categories
    end
    self:GetDatabase().profiles[name] = profile
    return self:SelectProfile(name)
end

function A:RenameProfile(name)
    if not self:CanChangeProfile() then return end
    name=(name or ""):match("^%s*(.-)%s*$")
    if #name==0 or #name>60 or self:GetDatabase().profiles[name] then self:Print(A.L["Nome inválido ou já utilizado."]); return end
    local old=self.profileKey
    self:GetDatabase().profiles[name], self:GetDatabase().profiles[old] = self.profile, nil
    for _,positions in pairs(self:GetDatabase().inventoryPositions) do
        positions[name],positions[old]=positions[old],nil
    end
    for character,key in pairs(self:GetDatabase().characterProfiles) do if key==old then self:GetDatabase().characterProfiles[character]=name end end
    self.profileKey=name
    self:RefreshSettings()
end

function A:DeleteProfile(name)
    if not self:CanChangeProfile() then return false end
    for _, key in pairs(self:GetDatabase().characterProfiles) do
        if key==name then self:Print(A.L["Este perfil está em uso por um personagem. Troque o perfil antes de excluir."]); return false end
    end
    self:GetDatabase().profiles[name]=nil
    for _,positions in pairs(self:GetDatabase().inventoryPositions) do positions[name]=nil end
    self:RefreshSettings()
    return true
end

function A:CreateCategory(name)
    if not self:CanChangeProfile() then return end
    name=(name or ""):match("^%s*(.-)%s*$")
    if #name==0 or #name>60 or #self.categories>=32 then self:Print(A.L["Nome obrigatório (até 60 caracteres); limite de 32 categorias."]); return end
    local n=1
    while self.profile.layout["custom"..n] do n=n+1 end
    local id="custom"..n
    local bottom=0
    for _,data in pairs(self.profile.layout) do local _,y,_,h=self:PanelRect(data); bottom=math.max(bottom,(y+h+(self:GetSettings().categorySpacing or 0))/self.cell) end
    local cat={id=id,name=name,x=0,y=bottom,cols=6,rows=3,custom=true}
    self.categories[#self.categories+1]=cat
    self.profile.layout[id]={x=0,y=bottom,cols=6,rows=3,itemSize=36,itemSpacing=4,compact=false,name=name}
    for _,layout in pairs(self.profile.extraLayouts or {}) do
        local bottom=0
        for _,d in pairs(layout) do local _,y,_,h=self:PanelRect(d); bottom=math.max(bottom,(y+h+16)/self.cell) end
        layout[id]=self:Copy(self.profile.layout[id]); layout[id].y=bottom
    end
    if (self.activeTab or "default")~="default" then
        self.profile.categoryTabs=self.profile.categoryTabs or {}; self.profile.categoryTabs[id]=self.activeTab
    end
    self:CreatePanel(cat)
    self:ResizeCanvas(); self:Reconcile(); self:Render()
    self:RefreshSettings()
    return id
end

function A:IsCustomCategory(id)
    if not self.profile.layout[id] then return false end
    for _,cat in ipairs(self.baseCategories) do if cat.id==id then return false end end
    return true
end

function A:DeleteCategory(id)
    if not self:CanChangeProfile() then return false end
    if not self:IsCustomCategory(id) then self:Print(A.L["Categorias padrão não podem ser excluídas."]); return false end
    local visible=0
    for other,data in pairs(self.profile.layout) do if other~=id and not data.hidden then visible=visible+1 end end
    if visible==0 then self:Print(A.L["Mostre outra categoria antes de excluir esta."]); return false end
    for index,cat in ipairs(self.categories) do if cat.id==id then table.remove(self.categories,index); break end end
    self.profile.layout[id]=nil
    if self.profile.categoryTabs then self.profile.categoryTabs[id]=nil end
    for _,layout in pairs(self.profile.extraLayouts or {}) do layout[id]=nil end
    for itemID,category in pairs(self.profile.manualCategories) do if category==id then self.profile.manualCategories[itemID]=nil end end
    for _,favorite in pairs(self.profile.favorites) do
        if favorite.category==id then favorite.category=self:VisibleCategory("misc"); favorite.index=1 end
    end
    for _,characters in pairs(self:GetDatabase().inventoryPositions) do
        if characters[self.profileKey] then
            characters[self.profileKey][id]=nil
            for identity,target in pairs(characters[self.profileKey].dropSlots or {}) do
                if target.category==id then characters[self.profileKey].dropSlots[identity]=nil end
            end
            for _,assignments in pairs(characters[self.profileKey].stackCategories or {}) do
                for identity,category in pairs(assignments) do if category==id then assignments[identity]=nil end end
            end
            for _,view in pairs(characters[self.profileKey].views or {}) do
                view[id]=nil
                for identity,target in pairs(view.dropSlots or {}) do
                    if target.category==id then view.dropSlots[identity]=nil end
                end
            end
        end
    end
    self.settingsCategory=nil
    self:RefreshProfile()
    return true
end

-- Parse length-prefixed profile data with size and depth limits.
local function encode(value)
    local t=type(value)
    if t=="string" then return "s"..#value..":"..value end
    if t=="number" then return "n"..tostring(value)..";" end
    if t=="boolean" then return value and "b1" or "b0" end
    if t=="table" then
        local keys={}; for key in pairs(value) do keys[#keys+1]=key end
        table.sort(keys,function(a,b) return tostring(a)<tostring(b) end)
        local out={"t"..#keys..":"}
        for _,key in ipairs(keys) do out[#out+1]=encode(key); out[#out+1]=encode(value[key]) end
        return table.concat(out)
    end
    error(A.L["Tipo inválido"])
end

function A:ExportProfile()
    local p=self.profile
    local raw=encode({version=1,categories=p.categories,layout=p.layout,settings=p.settings,window=p.window,
        manualCategories=p.manualCategories,favorites=p.favorites,tabs=p.tabs,categoryTabs=p.categoryTabs,extraLayouts=p.extraLayouts})
    return "BB1:"..raw:gsub(".",function(c) return string.format("%02X",string.byte(c)) end)
end

function A:DecodeProfile(code)
    if type(code)~="string" or #code>1048576 then return nil,A.L["Código muito grande."] end
    code=code:gsub("%s","")
    if code:sub(1,4)~="BB1:" then return nil,A.L["Formato esperado: BB1."] end
    local hex=code:sub(5)
    if #hex%2~=0 or hex:find("[^%x]") then return nil,A.L["Código incompleto ou inválido."] end
    local raw=hex:gsub("%x%x",function(pair) return string.char(tonumber(pair,16)) end)
    local at,nodes=1,0
    local function read(depth)
        nodes=nodes+1; assert(depth<16 and nodes<100000,A.L["Limite de dados excedido"])
        local tag=raw:sub(at,at); at=at+1
        if tag=="b" then local b=raw:sub(at,at); at=at+1; assert(b=="0" or b=="1"); return b=="1" end
        local delimiter=tag=="n" and ";" or ":"
        local stop=raw:find(delimiter,at,true); assert(stop and stop-at<24)
        local length=tonumber(raw:sub(at,stop-1)); assert(length and length==length and math.abs(length)<10000000)
        at=stop+1
        if tag=="n" then return length end
        assert(length>=0 and length%1==0)
        if tag=="s" then assert(length<=4096 and at+length-1<=#raw); local value=raw:sub(at,at+length-1); at=at+length; return value end
        assert(tag=="t" and length<=4000)
        local value={}
        for _=1,length do local key=read(depth+1); assert(type(key)=="string" or type(key)=="number"); assert(value[key]==nil); value[key]=read(depth+1) end
        return value
    end
    local ok,p=pcall(function() local value=read(0); assert(at==#raw+1); return value end)
    if not ok then return nil,A.L["Código inválido ou incompleto."] end
    local valid,err=pcall(function() self:ValidateProfile(p) end)
    if not valid then return nil,A.L["Configuração inválida: "]..tostring(err) end
    p.placements={}
    return p
end

function A:ValidateProfile(p)
    local function number(v,lo,hi) assert(type(v)=="number" and v==v and v>=lo and v<=hi,A.L["número fora do intervalo"]) end
    assert(type(p)=="table" and p.version==1 and type(p.categories)=="table" and #p.categories>=1 and #p.categories<=32,A.L["categorias"])
    assert(type(p.layout)=="table" and type(p.settings)=="table" and type(p.window)=="table","layout")
    local ids,visible={},0
    for _,cat in ipairs(p.categories) do
        assert(type(cat.id)=="string" and cat.id:match("^[%w_]+$") and #cat.id<=40 and not ids[cat.id],A.L["identificador"])
        assert(type(cat.name)=="string" and #cat.name>0 and #cat.name<=60,A.L["nome"])
        ids[cat.id]=true
        local d=p.layout[cat.id]; assert(type(d)=="table",A.L["categoria sem layout"])
        number(d.x,0,1000); number(d.y,0,1000); number(d.cols,2,30); number(d.rows,1,30)
        for _,key in ipairs({"cols","rows"}) do assert(d[key]%1==0,A.L["grade inteira"]) end
        number(d.itemSize,24,56); number(d.itemSpacing,0,12)
        if d.width then number(d.width,96,12000) end
        if d.height then number(d.height,76,12000) end
        local _,_,w,h=self:PanelRect(d)
        local minW,minH=self:MinimumPanelSize(d)
        assert(w>=minW and h>=minH,A.L["categoria menor que um item"])
        cat.x,cat.y,cat.cols,cat.rows=d.x,d.y,d.cols,d.rows
        assert(d.hidden==nil or type(d.hidden)=="boolean"); assert(d.compact==nil or type(d.compact)=="boolean")
        if d.name then assert(type(d.name)=="string" and #d.name>0 and #d.name<=60) end
        if d.rule then
            assert(type(d.rule)=="string" and #d.rule<=256,A.L["regra inválida"])
            local valid,err=self:ValidateCategoryRule(d.rule); assert(valid,err)
            assert(cat.id~="reagentbag" or d.rule=="",A.L["bolsa física de reagentes"])
        end
        if d.tint then for _,key in ipairs({"r","g","b"}) do number(d.tint[key],0,1) end end
        if not d.hidden then visible=visible+1 end
    end
    assert(visible>0,A.L["todas as categorias ocultas"])
    for _,cat in ipairs(self.baseCategories) do assert(ids[cat.id],A.L["categoria padrão ausente"]) end
    for id in pairs(p.layout) do assert(ids[id],A.L["layout desconhecido"]) end
    number(p.settings.categorySpacing,0,16)
    assert(p.settings.layoutLocked==nil or type(p.settings.layoutLocked)=="boolean",A.L["bloqueio de layout"])
    assert(p.settings.showBlizzardBagBar==nil or type(p.settings.showBlizzardBagBar)=="boolean",A.L["Bolsas"])
    assert(p.settings.showItemLevel==nil or type(p.settings.showItemLevel)=="boolean",A.L["nível dos equipamentos"])
    for _,key in ipairs({"showUpgrade","showEquipmentSets","showTransmog"}) do assert(p.settings[key]==nil or type(p.settings[key])=="boolean",A.L["indicador"]) end
    assert(p.settings.upgradeProvider==nil or p.settings.upgradeProvider=="ilvl" or p.settings.upgradeProvider=="pawn",A.L["avaliação de equipamento"])
    if p.settings.currencies then
        assert(type(p.settings.currencies)=="table" and #p.settings.currencies<=7,A.L["moedas"])
        local seen={}
        for index,id in pairs(p.settings.currencies) do
            number(index,1,#p.settings.currencies); number(id,1,10000000)
            assert(index%1==0 and id%1==0 and not seen[id],A.L["moeda duplicada/inválida"]); seen[id]=true
        end
    end
    local tabIDs={default=true}
    if p.tabs then
        assert(type(p.tabs)=="table" and #p.tabs>=1 and #p.tabs<=8 and p.tabs[1].id=="default",A.L["abas"])
        tabIDs={}
        for _,tab in ipairs(p.tabs) do
            assert(type(tab.id)=="string" and (tab.id=="default" or tab.id:match("^tab%d+$")) and not tabIDs[tab.id],A.L["aba inválida"])
            assert(type(tab.name)=="string" and #tab.name>0 and #tab.name<=40,A.L["nome de aba"])
            tabIDs[tab.id]=true
        end
    end
    assert(p.categoryTabs==nil or type(p.categoryTabs)=="table",A.L["categorias das abas"])
    for id,tab in pairs(p.categoryTabs or {}) do assert(ids[id] and tabIDs[tab],A.L["atribuição de aba"]) end
    number(p.window.scale or 0.85,0.5,1.25)
    if p.window.width then number(p.window.width,400,50000) end
    if p.window.height then number(p.window.height,300,50000) end
    number(p.window.x or 0,-50000,50000); number(p.window.y or 0,-50000,50000)
    p.manualCategories=p.manualCategories or {}; p.favorites=p.favorites or {}
    for id,cat in pairs(p.manualCategories) do number(id,1,10000000); assert(id%1==0 and ids[cat],A.L["regra inválida"]) end
    assert(type(p.manualCategories)=="table" and type(p.favorites)=="table",A.L["regras"])
    for id,f in pairs(p.favorites) do
        number(id,1,10000000); assert(id%1==0 and type(f)=="table" and ids[f.category],A.L["favorito inválido"])
        number(f.index,1,4096); assert(f.index%1==0)
        assert(f.name==nil or (type(f.name)=="string" and #f.name<=512),A.L["nome de favorito"])
        f.identity=nil -- GUIDs and physical inventory positions are never shared.
    end
    for id,a in pairs(p.layout) do
        for other,b in pairs(p.layout) do
            if id<other and not a.hidden and not b.hidden and ((p.categoryTabs or {})[id] or "default")==((p.categoryTabs or {})[other] or "default") then
                local function rect(d) return self:PanelRect(d) end
                local ax,ay,aw,ah=rect(a); local bx,by,bw,bh=rect(b)
                assert(not (ax<bx+bw and ax+aw>bx and ay<by+bh and ay+ah>by),A.L["categorias sobrepostas"])
            end
        end
    end
    if p.extraLayouts then
        assert(type(p.extraLayouts)=="table",A.L["layouts adicionais"])
        local count=0
        for key,layout in pairs(p.extraLayouts) do
            count=count+1; assert(count<=64 and type(key)=="string" and #key<=60,A.L["limite de layouts"])
            local storage,tab=key:match("^([%w_]+):([%w_]+)$")
            assert((storage=="bags" or storage=="character" or storage and storage:match("^account_%d+$")) and tabIDs[tab],A.L["área/aba desconhecida"])
            self:ValidateProfile({version=1,categories=self:Copy(p.categories),layout=layout,settings=p.settings,window=p.window,
                tabs=p.tabs,categoryTabs=p.categoryTabs,manualCategories={},favorites={}})
        end
    end
end

function A:ImportProfile(name,code)
    if not self:CanChangeProfile() then return false end
    name=(name or ""):match("^%s*(.-)%s*$")
    if #name==0 or #name>60 or self:GetDatabase().profiles[name] then self:Print(A.L["Escolha um nome novo para importar sem substituir perfis."]); return false end
    local p,err=self:DecodeProfile(code)
    if not p then self:Print(err); return false end
    p.version=nil
    p.spacingLayoutVersion=1
    self:GetDatabase().profiles[name]=p
    return self:SelectProfile(name)
end
