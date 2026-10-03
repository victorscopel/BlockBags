local _, A = ...

A.layoutPresets={
    {id="compact",name="Compacto",size=28,spacing=2,cols=6,rows=3,width=680},
    {id="balanced",name="Equilibrado",size=36,spacing=4,cols=6,rows=4,width=880},
    {id="spacious",name="Espaçoso",size=44,spacing=4,cols=6,rows=4,width=960},
}

function A:ApplyLayoutPreset(id)
    if InCombatLockdown() then return false end
    local preset
    for _,candidate in ipairs(A.layoutPresets) do if candidate.id==id then preset=candidate end end
    if not preset then return false end
    if self.draft then self:PushUndo() end
    local layout=self:GetLayout()
    local x,y,rowHeight,gap=0,0,0,self:GetSettings().categorySpacing or 0
    for _,cat in ipairs(self.categories) do
        local data=layout[cat.id]
        if self:CategoryDisplayed(cat.id) then
            data.itemSize,data.itemSpacing=preset.size,preset.spacing
            data.cols,data.rows=preset.cols,preset.rows
            data.width=preset.cols*(preset.size+preset.spacing)-preset.spacing+self.padding*2
            data.height=preset.rows*(preset.size+preset.spacing)-preset.spacing+self.padding*2+self.header
            if x>0 and x+data.width>preset.width then x=0; y=y+rowHeight+gap; rowHeight=0 end
            data.x,data.y=x/self.cell,y/self.cell
            x=x+data.width+gap; rowHeight=math.max(rowHeight,data.height)
        end
    end
    self:SettingsChanged(); self:RefreshSettings()
    return true
end

function A:RequestLayoutPreset(id)
    if InCombatLockdown() then return end
    StaticPopupDialogs.BLOCKBAGS_PRESET=StaticPopupDialogs.BLOCKBAGS_PRESET or {
        text=A.L["Aplicar este layout? As posições dos itens e as regras serão mantidas."],
        button1=ACCEPT,button2=CANCEL,timeout=0,whileDead=true,hideOnEscape=true,
        OnAccept=function(_,data) data.owner:ApplyLayoutPreset(data.id) end}
    StaticPopup_Show("BLOCKBAGS_PRESET",nil,nil,{owner=self,id=id})
end

function A:CopyCategoryAppearance(source,target)
    if InCombatLockdown() or source==target then return false end
    local layout=self:GetLayout()
    if not layout[source] or not layout[target] then return false end
    if self.draft then self:PushUndo() end
    local from,to=layout[source],layout[target]
    local candidate=self:Copy(to); candidate.itemSize=from.itemSize
    local _,_,w,h=self:PanelRect(candidate); local minW,minH=self:MinimumPanelSize(candidate)
    if w<minW or h<minH then self:Print(self.L["Esse tamanho não cabe: verifique o mínimo, os outros painéis e a janela."]); return false end
    to.itemSize,to.itemSpacing,to.tint=from.itemSize,from.itemSpacing,self:Copy(from.tint)
    self:SettingsChanged(); self:RefreshSettings()
    return true
end

function A:ResetCategory(id)
    if InCombatLockdown() or not self:GetLayout()[id] then return false end
    if self.draft then self:PushUndo() end
    local d=self:GetLayout()[id]
    d.itemSize,d.itemSpacing,d.tint=36,4,nil
    d.cols,d.rows,d.width,d.height=6,3,nil,nil
    local x,y,w,h=self:PanelRect(d)
    local collision,bottom=false,0
    for other,data in pairs(self:GetLayout()) do
        if other~=id and self:CategoryDisplayed(other) then
            local ox,oy,ow,oh=self:PanelRect(data)
            bottom=math.max(bottom,oy+oh+(self:GetSettings().categorySpacing or 0))
            if x<ox+ow and x+w>ox and y<oy+oh and y+h>oy then collision=true end
        end
    end
    if collision then d.x,d.y=0,bottom/self.cell end
    self:SettingsChanged(); self:RefreshSettings()
    return true
end

function A:ItemComparator(id)
    local data=(self.draft and self:GetBaseLayout() or self:GetLayout())[id]
    local key,descending=data.sortBy or "name",data.sortDescending
    if descending==nil then descending=key~="name" end
    return function(a,b)
        if a.pending~=b.pending then return not a.pending end
        local av,bv
        if key=="quality" then av,bv=a.info.quality or -1,b.info.quality or -1
        elseif key=="ilvl" then av,bv=a.itemLevel or 0,b.itemLevel or 0
        elseif key=="count" then av,bv=a.info.stackCount or 1,b.info.stackCount or 1
        elseif key=="expansion" then av,bv=a.expansionID or -1,b.expansionID or -1
        else av,bv=a.sortName or (a.name or ""):lower(),b.sortName or (b.name or ""):lower() end
        if av~=bv then if descending then return av>bv else return av<bv end end
        local an,bn=a.sortName or (a.name or ""):lower(),b.sortName or (b.name or ""):lower()
        if an~=bn then return an<bn end
        if a.info.itemID~=b.info.itemID then return a.info.itemID<b.info.itemID end
        return a.slotKey<b.slotKey
    end
end
