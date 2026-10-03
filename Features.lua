local _, A = ...

function A:SnapshotEditor()
    return {layout=self:Copy(self.draft), settings=self:Copy(self.draftSettings),
        width=self.window:GetWidth(), height=self.window:GetHeight()}
end

function A:PushUndo()
    if not self.draft then return end
    self.undoStack = self.undoStack or {}
    self.undoStack[#self.undoStack+1] = self:SnapshotEditor()
    if #self.undoStack > 50 then table.remove(self.undoStack,1) end
end

function A:UndoEdit()
    if not self.draft or InCombatLockdown() then return end
    local snapshot = table.remove(self.undoStack or {})
    if not snapshot then self:Print(A.L["Nada para desfazer."]); return end
    self.draft, self.draftSettings = snapshot.layout, snapshot.settings
    if self.visibilityChanged then
        for _,item in ipairs(self.items or {}) do item.category=self:Classify(item) end
    end
    self.window:SetSize(snapshot.width, snapshot.height)
    if self.customization then self.customization:Hide() end
    if self.generalSettings then self.generalSettings:Hide() end
    self:ResizeCanvas(); self:Render()
end

function A:SetManualCategory(item, category, index)
    if InCombatLockdown() or self.draft then return end
    if category == "reagentbag" or item.bag == Enum.BagIndex.ReagentBag then
        self:Print(A.L["A categoria da bolsa de reagentes acompanha a bolsa física."]); return
    end
    local id = item.info.itemID
    self:GetStackCategories()[item.identity] = category
    if not category then
        self.profile.manualCategories[id]=nil
        self:GetDropSlots()[item.identity]=nil
    end
    local favorite = self.profile.favorites[id]
    if favorite and favorite.identity==item.identity then
        self.profile.favorites[id] = nil
        favorite.category = self:VisibleCategory(category or self:AutomaticCategory(item))
        local destination=index
        if not destination then
            local group=self.groups[favorite.category]
            destination=1
            while group and ((group.positions[destination] and group.positions[destination].identity~=item.identity)
                or (group.reserved[destination] and group.reserved[destination]~=id)) do
                destination=destination+1
            end
        end
        favorite.index = destination
        self.profile.favorites[id] = favorite
    end
    for _, current in ipairs(self.items) do
        if current.identity==item.identity then current.category=self:Classify(current) end
    end
    self:Reconcile(); self:Render()
end

function A:ToggleFavorite(item)
    if InCombatLockdown() or self.draft then return end
    local id = item.info.itemID
    if self.profile.favorites[id] then self.profile.favorites[id]=nil
    else
        self.profile.favorites[id] = { category=item.category,
            index=self:GetPositions()[item.category][item.identity] or 1,
            identity=item.identity, name=item.name }
    end
    self:Reconcile(); self:Render()
end

function A:RemoveFavorite(id)
    if InCombatLockdown() then return end
    self.profile.favorites[id]=nil
    self:Reconcile(); self:Render()
end

function A:OpenItemActions(item)
    if self.draft or InCombatLockdown() then return end
    local f=self.itemActions
    if not f then
        f=self:CreateEditorDialog("",340); self.itemActions=f
        f.rows={}; f.page=1
        local function action(value,y,callback)
            local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
            b:SetSize(300,24); b:SetPoint("TOPLEFT",20,y); b:SetText(value); b:SetScript("OnClick",callback)
            return b
        end
        f.favorite=action("",-42,function() if f.item then self:ToggleFavorite(f.item) end; f:Hide() end)
        action(A.L["Restaurar categoria automática"],-72,function() if f.item then self:SetManualCategory(f.item,nil) end; f:Hide() end)
        for i=1,6 do
            local b=action("",-110-(i-1)*29,function()
                local cat=f.choices and f.choices[(f.page-1)*6+i]
                if f.item and cat then self:SetManualCategory(f.item,cat.id) end
                f:Hide()
            end)
            f.rows[i]=b
        end
        f.Draw=function()
            for i,b in ipairs(f.rows) do
                local cat=f.choices[(f.page-1)*6+i]
                b:SetShown(cat~=nil)
                if cat then b:SetText(A.L["Mover para "]..self:CategoryName(cat.id)) end
            end
        end
        f.next=action(A.L["Mais categorias"],-298,function() f.page=f.page%math.max(1,math.ceil(#f.choices/6))+1; f.Draw() end)
        f:SetScript("OnHide",function() f.item=nil; f.choices=nil end)
    end
    if self.favoriteDialog then self.favoriteDialog:Hide() end
    f.item=self:Copy(item); f.page=1; f.choices={}
    for _,cat in ipairs(self.categories) do if cat.id~="reagentbag" and not self:GetLayout()[cat.id].hidden then f.choices[#f.choices+1]=cat end end
    f.title:SetText(item.name)
    f.favorite:SetText(self.profile.favorites[item.info.itemID] and A.L["Remover favorito"] or A.L["Favoritar e fixar neste slot"])
    f.next:SetShown(#f.choices>6); f.Draw(); f:Show()
end

function A:OpenFavorites()
    if InCombatLockdown() then return end
    local f=self.favoriteDialog
    if not f then
        f=self:CreateEditorDialog(A.L["Favoritos"],340); self.favoriteDialog=f
        f.page=1; f.rows={}
        for row=1,7 do
            local b=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
            b:SetSize(300,26); b:SetPoint("TOPLEFT",20,-40-(row-1)*34)
            b:SetScript("OnClick",function()
                local entry=f.entries and f.entries[(f.page-1)*7+row]
                if entry then self:RemoveFavorite(entry.id); self:OpenFavorites() end
            end)
            f.rows[row]=b
        end
        f.Draw=function()
            f.title:SetText(#f.entries==0 and A.L["Você ainda não tem favoritos"] or A.L["Favoritos — página "]..f.page)
            for row,b in ipairs(f.rows) do
                local entry=f.entries[(f.page-1)*7+row]
                b:SetShown(entry~=nil)
                if entry then b:SetText(A.L["Remover: "]..(entry.name or tostring(entry.id))) end
            end
        end
        local nextPage=CreateFrame("Button",nil,f,"UIPanelButtonTemplate")
        nextPage:SetSize(135,24); nextPage:SetPoint("BOTTOMRIGHT",-20,17); nextPage:SetText(A.L["Próxima página"])
        nextPage:SetScript("OnClick",function() f.page=f.page%math.max(1,math.ceil(#f.entries/7))+1; f.Draw() end)
        f:SetScript("OnHide",function() f.entries=nil end)
    end
    if self.itemActions then self.itemActions:Hide() end
    f.entries={}; f.page=1
    for id,favorite in pairs(self.profile.favorites) do f.entries[#f.entries+1]={id=id,name=favorite.name} end
    table.sort(f.entries,function(a,b) return (a.name or "")<(b.name or "") end)
    f.Draw(); f:Show()
end

function A:ReportMemory(collect)
    local api=C_AddOns or {}
    local update=api.UpdateAddOnMemoryUsage or UpdateAddOnMemoryUsage
    local memory=api.GetAddOnMemoryUsage or GetAddOnMemoryUsage
    if update then update() end
    local kb=memory and memory("BlockBags") or 0
    if collect then
        if InCombatLockdown() then self:Print(A.L["Faça este diagnóstico fora de combate."]); return end
        local ok,err=pcall(collectgarbage,"collect")
        if not ok then self:Print(A.L["O cliente não permitiu a coleta: "]..tostring(err)); return end
        if update then update() end
        local after=memory and memory("BlockBags") or 0
        self:Print(string.format(A.L["Coleta manual: %.2f MB antes → %.2f MB depois; %.2f MB liberados."],kb/1024,after/1024,(kb-after)/1024))
        kb=after
    end
    local buttons,panels,cache,loading=0,0,0,0
    for _ in pairs(self.buttons or {}) do buttons=buttons+1 end
    for _ in pairs(self.panels or {}) do panels=panels+1 end
    for _ in pairs(self.itemCache or {}) do cache=cache+1 end
    for _ in pairs(self.loading or {}) do loading=loading+1 end
    self:Print(string.format(A.L["Memória atribuída: %.2f MB; botões: %d; painéis: %d; metadados: %d; cargas pendentes: %d; histórico: %d."],kb/1024,buttons,panels,cache,loading,#(self.undoStack or {})))
    if self.lastMemoryKB then self:Print(string.format(A.L["Diferença desde a medição anterior: %+.2f MB."],(kb-self.lastMemoryKB)/1024)) end
    self.lastMemoryKB=kb
    if not collect then self:Print(A.L["/bb memory gc compara antes/depois de uma coleta manual. Use fora de combate; pode causar uma pausa breve."]) end
end

function A:CollectSearchResults(query)
    local result={}
    if query=="" then return result end
    for _,cat in ipairs(self.categories) do
        local group=self.groups[cat.id]
        for index=1,group.max do
            local item=group.positions[index]
            if item and self:CategoryDisplayed(cat.id) and self:MatchesQuery(item,query) then
                result[#result+1]={item=item,category=cat.id,index=index}
            end
        end
    end
    return result
end

function A:NavigateSearch(direction)
    if InCombatLockdown() or self.draft then return end
    local results=self:CollectSearchResults((self.search:GetText() or ""):lower())
    if #results==0 then return end
    self.searchResultIndex=((self.searchResultIndex or 0)+(direction or 1)-1)%#results+1
    local hit=results[self.searchResultIndex]
    local panel=self.panels[hit.category]
    local metrics=panel.currentMetrics or self:ItemMetrics(self:GetLayout()[hit.category])
    local y=math.floor((hit.index-1)/metrics.cols)*metrics.step
    local _,max=panel.bar:GetMinMaxValues()
    panel.bar:SetValue(math.max(0,math.min(max,y)))
    self.focusedSearchIdentity=hit.item.identity
    self:Render()
end
