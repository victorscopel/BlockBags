local _, A = ...

local function compare(a, b)
    if a.pending ~= b.pending then return not a.pending end
    local an, bn = a.sortName or a.name:lower(), b.sortName or b.name:lower()
    if an ~= bn then return an < bn end
    if a.info.itemID ~= b.info.itemID then return a.info.itemID < b.info.itemID end
    return a.slotKey < b.slotKey
end

function A:Reconcile()
    local stored=self:GetPositions()
    self.groups = self.groups or {}
    for id in pairs(self.groups) do if not self:GetLayout()[id] then self.groups[id]=nil end end
    for id in pairs(self.emptyPositions or {}) do if not self:GetLayout()[id] then self.emptyPositions[id]=nil end end
    for _,cat in ipairs(self.categories) do
        local group=self.groups[cat.id]
        if not group then group={items={},positions={},reserved={},favoriteIDs={}}; self.groups[cat.id]=group end
        self:ClearTable(group.items); self:ClearTable(group.positions); self:ClearTable(group.reserved)
        group.max=0
    end
    for _, item in ipairs(self.items or {}) do
        item.category = self:VisibleCategory(item.category)
        local group = self.groups[item.category]
        group.items[#group.items + 1] = item
    end
    for _, cat in ipairs(self.categories) do
        local group = self.groups[cat.id]
        local previous = stored[cat.id] or {}
        local nextPositions, claimed = {}, group.positions
        table.sort(group.items, compare)
        local favoriteIDs=self:ClearTable(group.favoriteIDs)
        for id,favorite in pairs(self.profile.favorites or {}) do
            if self:VisibleCategory(favorite.category)==cat.id then favoriteIDs[#favoriteIDs+1]=id end
        end
        table.sort(favoriteIDs)
        for _,id in ipairs(favoriteIDs) do
            local favorite=self.profile.favorites[id]
            local index=math.max(1,math.floor(tonumber(favorite.index) or 1))
            while group.reserved[index] do index=index+1 end
            favorite.index=index
            group.reserved[index]=id
            group.max=math.max(group.max,index)
            local chosen
            for _,item in ipairs(group.items) do
                if item.info.itemID==id then
                    chosen=chosen or item
                    if item.identity==favorite.identity then chosen=item; break end
                end
            end
            if chosen then nextPositions[chosen.identity],claimed[index]=index,chosen end
        end
        local compact = self:GetLayout()[cat.id].compact or self.organizeCategory == cat.id
        if not compact then
            for _, item in ipairs(group.items) do
                local target = self.pendingPlacements and self.pendingPlacements[item.slotKey]
                if target and (not target.itemID or target.itemID==item.info.itemID) and target.category == cat.id and not nextPositions[item.identity] and not claimed[target.index] and not group.reserved[target.index] then
                    nextPositions[item.identity], claimed[target.index] = target.index, item
                end
            end
        end
        -- Preserve occupied positions when items are removed.
        if not compact then
            for _, item in ipairs(group.items) do
                local index = previous[item.identity]
                if not nextPositions[item.identity] and type(index) == "number" and index >= 1 and index % 1 == 0 and not claimed[index] and not group.reserved[index] then
                    nextPositions[item.identity], claimed[index] = index, item
                end
            end
        end
        local firstFree = 1
        for _, item in ipairs(group.items) do
            local index = nextPositions[item.identity]
            if not index then
                while claimed[firstFree] or group.reserved[firstFree] do firstFree = firstFree + 1 end
                index = firstFree
                nextPositions[item.identity], claimed[index] = index, item
            end
            group.max = math.max(group.max, index)
        end
        group.positions = claimed
        stored[cat.id] = nextPositions
    end
    self.organizeCategory = nil
    self.pendingPlacements = nil
end

function A:AssignEmptySlots()
    -- Assign each physical free slot once. Keep reagent slots in their panel;
    -- distribute ordinary slots across categories and put the surplus in Diversos.
    self.emptyPools=self.emptyPools or {common={},reagents={},specialty={}}
    local pools=self.emptyPools
    for _,pool in pairs(pools) do self:ClearTable(pool) end
    self.emptyPositions,self.displayMax=self.emptyPositions or {},self.displayMax or {}
    for _, cat in ipairs(self.categories) do
        self.emptyPositions[cat.id] = self:ClearTable(self.emptyPositions[cat.id] or {})
        self.displayMax[cat.id] = self.groups[cat.id].max
    end
    for _, slot in ipairs(self.emptySlots or {}) do
        local pool = slot.bag == Enum.BagIndex.ReagentBag and pools.reagents
            or ((slot.family or 0) == 0 and pools.common or pools.specialty)
        pool[#pool + 1] = slot
    end
    local function assign(id, index, slot)
        self.emptyPositions[id][index] = slot
        self.displayMax[id] = math.max(self.displayMax[id], index)
    end
    local function vacant(id, start)
        local index = start or 1
        while self.groups[id].positions[index] or (self.groups[id].reserved and self.groups[id].reserved[index]) or self.emptyPositions[id][index] do index = index + 1 end
        return index
    end
    local index = 1
    for _, slot in ipairs(pools.reagents) do
        index = vacant("reagentbag", index)
        local target = self:VisibleCategory("reagentbag")
        index = vacant(target, index)
        assign(target, index, slot)
    end
    local commonIndex = 1
    -- Reserve one free slot per visible category before distributing the rest.
    for _, cat in ipairs(self.categories) do
        local data = self:GetLayout()[cat.id]
        if cat.id ~= "reagentbag" and self:CategoryDisplayed(cat.id) and pools.common[commonIndex] then
            local metrics = self:ItemMetrics(data)
            local position = vacant(cat.id)
            if position <= metrics.cols * metrics.rows then
                assign(cat.id, position, pools.common[commonIndex])
                commonIndex = commonIndex + 1
            end
        end
    end
    for _, cat in ipairs(self.categories) do
        if cat.id ~= "reagentbag" and self:CategoryDisplayed(cat.id) then
            local data = self:GetLayout()[cat.id]
            local metrics = self:ItemMetrics(data)
            for position = 1, math.max(metrics.cols * metrics.rows, self.groups[cat.id].max) do
                if not self.groups[cat.id].positions[position] and not (self.groups[cat.id].reserved and self.groups[cat.id].reserved[position]) and not self.emptyPositions[cat.id][position] and pools.common[commonIndex] then
                    assign(cat.id, position, pools.common[commonIndex])
                    commonIndex = commonIndex + 1
                end
            end
        end
    end
    index = 1
    for i = commonIndex, #pools.common do
        local target = self:VisibleCategory("misc")
        index = vacant(target, index)
        assign(target, index, pools.common[i])
    end
    for _, slot in ipairs(pools.specialty) do
        local target = self:VisibleCategory("materials")
        index = vacant(target, 1)
        assign(target, index, slot)
    end
end

function A:PanelRect(layout)
    return layout.x * self.cell, layout.y * self.cell,
        layout.width or (layout.cols * self.cell + self.padding * 2),
        layout.height or (layout.rows * self.cell + self.header + self.padding * 2)
end

function A:MinimumPanelSize(layout)
    local size=layout.itemSize or 36
    return math.max(96,size+self.padding*2),self.header+self.padding*2+size
end

-- Snap to nearby edges without overlaps. A wider release threshold prevents jitter.
function A:MagneticSnap(id,candidate,resize,state)
    local capture,release=18,30
    local gap=self:GetSettings().categorySpacing or 0
    local x,y,w,h=self:PanelRect(candidate)
    local rawX,rawY=resize and w or x,resize and h or y
    local minW,minH=self:MinimumPanelSize(candidate)
    local xs,ys={},{}
    local function add(options,value,raw,minimum)
        local distance=math.abs(value-raw)
        if value>=minimum and distance<=capture then options[#options+1]={value=value,distance=distance} end
    end
    local function near(a,length,b,otherLength)
        return a<=b+otherLength+capture and a+length>=b-capture
    end
    for other,data in pairs(self:GetLayout()) do
        if other~=id and self:CategoryDisplayed(other) then
            local ox,oy,ow,oh=self:PanelRect(data)
            if near(y,h,oy,oh) then
                if resize then
                    add(xs,ox-gap-x,w,minW); add(xs,ox+ow-x,w,minW)
                else
                    add(xs,ox,x,0); add(xs,ox+ow-w,x,0)
                    add(xs,ox+ow+gap,x,0); add(xs,ox-w-gap,x,0)
                end
            end
            if near(x,w,ox,ow) then
                if resize then
                    add(ys,oy-gap-y,h,minH); add(ys,oy+oh-y,h,minH)
                else
                    add(ys,oy,y,0); add(ys,oy+oh-h,y,0)
                    add(ys,oy+oh+gap,y,0); add(ys,oy-h-gap,y,0)
                end
            end
        end
    end
    add(xs,resize and self.canvasWidth-x or 0,rawX,resize and minW or 0)
    add(ys,resize and self.canvasHeight-y or 0,rawY,resize and minH or 0)
    if not resize then
        add(xs,self.canvasWidth-w,rawX,0); add(ys,self.canvasHeight-h,rawY,0)
    end
    local function prepare(options,raw,lock)
        if lock and math.abs(lock-raw)<=release then options[#options+1]={value=lock,distance=math.abs(lock-raw),locked=true} end
        table.sort(options,function(a,b)
            if a.locked~=b.locked then return a.locked==true end
            if a.distance~=b.distance then return a.distance<b.distance end
            return a.value<b.value
        end)
        local selected,seen={},{}
        for _,option in ipairs(options) do
            if not seen[option.value] and #selected<6 then selected[#selected+1]=option; seen[option.value]=true end
        end
        selected[#selected+1]={value=raw,distance=0,free=true}
        return selected
    end
    xs=prepare(xs,rawX,state and state.x); ys=prepare(ys,rawY,state and state.y)
    local best,bestX,bestY
    for _,horizontal in ipairs(xs) do
        for _,vertical in ipairs(ys) do
            if resize then candidate.width,candidate.height=horizontal.value,vertical.value
            else candidate.x,candidate.y=horizontal.value/self.cell,vertical.value/self.cell end
            if self:CanPlace(id,candidate) then
                local score=horizontal.distance+vertical.distance
                    -(horizontal.free and 0 or 40)-(vertical.free and 0 or 40)
                    -(horizontal.locked and 40 or 0)-(vertical.locked and 40 or 0)
                if not best or score<best then best,bestX,bestY=score,horizontal,vertical end
            end
        end
    end
    if resize then candidate.width,candidate.height=bestX and bestX.value or rawX,bestY and bestY.value or rawY
    else candidate.x,candidate.y=(bestX and bestX.value or rawX)/self.cell,(bestY and bestY.value or rawY)/self.cell end
    if state then
        state.x=bestX and not bestX.free and bestX.value or nil
        state.y=bestY and not bestY.free and bestY.value or nil
    end
    return candidate
end

function A:SnapResize(id,candidate,state)
    return self:MagneticSnap(id,candidate,true,state)
end

-- Repack on spacing changes or migration, preserving category order.
function A:PackLayout(layout, gap)
    local entries={}
    for id,data in pairs(layout) do if not data.hidden and self:IsCategoryOnTab(id) then entries[#entries+1]={id=id,data=data} end end
    table.sort(entries,function(a,b) return a.data.x==b.data.x and (a.data.y==b.data.y and a.id<b.id or a.data.y<b.data.y) or a.data.x<b.data.x end)
    for i,entry in ipairs(entries) do
        local _,y,_,h=self:PanelRect(entry.data)
        local x=0
        for j=1,i-1 do
            local ox,oy,ow,oh=self:PanelRect(entries[j].data)
            if y<oy+oh and y+h>oy then x=math.max(x,ox+ow+gap) end
        end
        entry.data.x=x/self.cell
    end
    table.sort(entries,function(a,b) return a.data.y==b.data.y and (a.data.x==b.data.x and a.id<b.id or a.data.x<b.data.x) or a.data.y<b.data.y end)
    for i,entry in ipairs(entries) do
        local x,_,w=self:PanelRect(entry.data)
        local y=0
        for j=1,i-1 do
            local ox,oy,ow,oh=self:PanelRect(entries[j].data)
            if x<ox+ow and x+w>ox then y=math.max(y,oy+oh+gap) end
        end
        entry.data.y=y/self.cell
    end
end

function A:SnapPanel(id,candidate,state)
    return self:MagneticSnap(id,candidate,false,state)
end

function A:ItemMetrics(layout)
    local size = math.max(24, math.min(56, layout.itemSize or 36))
    local spacing = math.max(0, math.min(12, layout.itemSpacing or 4))
    local step = size + spacing
    local _,_,panelWidth,panelHeight=self:PanelRect(layout)
    local width, height = panelWidth-self.padding*2, panelHeight-self.header-self.padding*2
    return { size = size, spacing = spacing, step = step,
        cols = math.max(1, math.floor((width + spacing) / step)),
        rows = math.max(1, math.floor((height + spacing) / step)),
        width = width, height = height }
end

function A:CanPlace(id, candidate)
    local epsilon=0.001 -- Fractional saved anchors can round slightly past an edge.
    if candidate.x < 0 or candidate.y < 0 or candidate.cols < 2 or candidate.rows < 1 then return false end
    local x, y, w, h = self:PanelRect(candidate)
    local minW,minH=self:MinimumPanelSize(candidate)
    if w<minW or h<minH then return false end
    if x + w > self.canvasWidth+epsilon or y + h > self.canvasHeight+epsilon then return false end
    for otherID, layout in pairs(self:GetLayout()) do
        if otherID ~= id and self:CategoryDisplayed(otherID) then
            local ox, oy, ow, oh = self:PanelRect(layout)
            if x < ox + ow-epsilon and x + w > ox+epsilon and y < oy + oh-epsilon and y + h > oy+epsilon then return false end
        end
    end
    return true
end
