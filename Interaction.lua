local _, A = ...

function A:InstallInteractionHooks()
    if self.interactionHooksInstalled or not C_Container.SplitContainerItem then return end
    self.interactionHooksInstalled=true
    hooksecurefunc(C_Container,"SplitContainerItem",function() self.itemDrag=nil end)
end

-- Source tracking, focused-frame ancestry and virtual reassignment adapted from
-- MyBags/dragndrop.lua. Copyright (c) 2026 MyGamesDevelopmentAcc. MIT.
-- Item use, equipment, stack splitting and bag transfers use native slots.
function A:CaptureItemSource(button)
    self.itemDrag=nil
    if self.draft or self.physicalBagView or InCombatLockdown() then return end
    if IsModifiedClick and IsModifiedClick("SPLITSTACK") then return end
    local kind=GetCursorInfo()
    if kind then return end
    local item=button.currentItem
    if not item then self.itemDrag=nil; return end
    self.itemDrag={bag=item.bag,slot=item.slot,itemID=item.info.itemID,
        identity=item.identity,category=item.category,slotKey=item.slotKey}
end

function A:ResolveDropTarget()
    -- Walk parent frames to resolve drops over item overlays.
    for _,focus in ipairs(GetMouseFoci and GetMouseFoci() or {}) do
        local frame=focus
        for _=1,16 do
            if not frame then break end
            local id=frame.blockCategory or frame.anchorCategory
            if type(id)=="string" and self.panels[id] and self.panels[id]:IsShown() then
                return id,type(frame.anchorIndex)=="number" and frame.anchorIndex or nil
            end
            frame=frame.GetParent and frame:GetParent() or nil
        end
    end
end

function A:TryVirtualDrop(category,index)
    local source=self.itemDrag
    if not source or self.draft or self.physicalBagView or InCombatLockdown() then return false end
    local kind,id=GetCursorInfo()
    local layout=self:GetLayout()[category]
    if kind~="item" or id~=source.itemID or not layout or layout.hidden then return false end
    -- Reagent-bag transfers must move the physical item.
    if source.bag==Enum.BagIndex.ReagentBag or category=="reagentbag" then return false end
    local info=C_Container.GetContainerItemInfo(source.bag,source.slot)
    if not info or info.itemID~=source.itemID then self.itemDrag=nil; return false end
    local model=self.slotModels and self.slotModels[source.slotKey]
    if not model or model.identity~=source.identity then self.itemDrag=nil; return false end
    local targetIndex=index
    local group=self.groups[category]
    if not targetIndex or group.positions[targetIndex] or group.reserved[targetIndex] then
        targetIndex=1
        while group.positions[targetIndex] or group.reserved[targetIndex] do targetIndex=targetIndex+1 end
    end
    -- Return the item to its physical slot, then change its category.
    self.itemDrag=nil
    ClearCursor()
    if CursorHasItem() then return false end
    self.pendingPlacements=self.pendingPlacements or {}
    self.pendingPlacements[source.slotKey]={category=category,index=targetIndex,itemID=id}
    self:SetManualCategory(model,category,targetIndex)
    return true
end

function A:CompleteItemDrag()
    local category,index=self:ResolveDropTarget()
    if category then return self:TryVirtualDrop(category,index) end
    return false
end

function A:ToggleLayoutLock()
    if self.draft or InCombatLockdown() then return end
    self.profile.settings.layoutLocked=not self.profile.settings.layoutLocked
    self:CancelInteractions()
    self:ApplyLayout()
    if self.RefreshSettings then self:RefreshSettings() end
end

function A:BeginQuickMove(panel)
    if self.draft then self:BeginPanelDrag(panel,false); return end
    if InCombatLockdown() or self:GetSettings().layoutLocked or CursorHasItem() then return end
    local x,y=GetCursorPosition()
    panel.quickDrag={x=x,y=y,original=self:Copy(self:GetBaseLayout()[panel.id]),snap={}}
    panel:SetScript("OnUpdate",function()
        local drag=panel.quickDrag
        if not drag then return end
        local cx,cy=GetCursorPosition()
        local scale=self.canvas:GetEffectiveScale()
        local dx,dy=math.floor((cx-drag.x)/scale+0.5),math.floor((drag.y-cy)/scale+0.5)
        local free=IsShiftKeyDown()
        if dx==drag.dx and dy==drag.dy and free==drag.free then return end
        drag.dx,drag.dy,drag.free=dx,dy,free
        local candidate=self:Copy(drag.original)
        candidate.x=math.max(0,candidate.x+dx/self.cell)
        candidate.y=math.max(0,candidate.y+dy/self.cell)
        if free then drag.snap.x,drag.snap.y=nil,nil else self:SnapPanel(panel.id,candidate,drag.snap) end
        drag.candidate,drag.valid=candidate,self:CanPlace(panel.id,candidate)
        -- Try a swap on collision; validate both resulting rectangles.
        drag.swap=nil
        if not drag.valid then
            for _,cat in ipairs(self.categories) do
                local other=self:GetBaseLayout()[cat.id]
                if cat.id~=panel.id and self:CategoryDisplayed(cat.id) then
                    local ox,oy,ow,oh=self:PanelRect(other)
                    local mx,my=candidate.x*self.cell,candidate.y*self.cell
                    if mx>=ox and mx<ox+ow and my>=oy and my<oy+oh then
                        local first=self:Copy(drag.original); first.x,first.y=other.x,other.y
                        local second=self:Copy(other); second.x,second.y=drag.original.x,drag.original.y
                        local layout=self:GetBaseLayout()
                        layout[cat.id]=second
                        local valid=self:CanPlace(panel.id,first)
                        layout[panel.id]=first
                        valid=valid and self:CanPlace(cat.id,second)
                        layout[panel.id],layout[cat.id]=drag.original,other
                        if valid then drag.candidate,drag.swap,drag.valid=first,{id=cat.id,data=second},true end
                        break
                    end
                end
            end
        end
        local px,py,w,h=self:PanelRect(drag.candidate)
        panel:ClearAllPoints(); panel:SetPoint("TOPLEFT",self.canvas,"TOPLEFT",px,-py); panel:SetSize(w,h)
        panel:SetBackdropBorderColor(drag.valid and 0.2 or 1,drag.valid and 0.9 or 0.2,0.5,1)
        self:UpdateEditorVisuals(panel.id,drag.candidate,false,drag.valid,free)
    end)
end

function A:EndQuickMove(panel,cancel)
    if self.draft and type(panel.quickDrag)~="table" then self:EndPanelDrag(panel); return end
    local drag=panel.quickDrag
    if type(drag)~="table" then return end
    panel:SetScript("OnUpdate",nil); panel.quickDrag=nil
    self:HideEditorVisuals()
    if InCombatLockdown() then self.pendingRefresh=true; return end
    if drag and drag.valid and not cancel and not InCombatLockdown() and not self:GetSettings().layoutLocked then
        self:GetBaseLayout()[panel.id]=drag.candidate
        if drag.swap then self:GetBaseLayout()[drag.swap.id]=drag.swap.data end
    end
    self:ApplyLayout(); self:Render()
end

function A:CancelInteractions()
    self.itemDrag=nil
    self:HideCategoryDropHint()
    for _,panel in pairs(self.panels or {}) do
        if type(panel.quickDrag)=="table" then self:EndQuickMove(panel,true) end
    end
end

function A:ShowCategoryDropHint(id)
    self:HideCategoryDropHint()
    if self.draft or InCombatLockdown() or not CursorHasItem() then return end
    local panel=self.panels[id]
    if not panel then return end
    local canDrop=self.itemDrag and self.itemDrag.bag~=Enum.BagIndex.ReagentBag and id~="reagentbag"
    if not canDrop then
        local _,itemID=GetCursorInfo()
        local data=self.itemCache[itemID]
        for _,slot in ipairs(self.emptySlots or {}) do
            if (id=="reagentbag" and slot.bag==Enum.BagIndex.ReagentBag and data and data.reagent) or
                (id~="reagentbag" and slot.bag~=Enum.BagIndex.ReagentBag and (slot.family or 0)==0) then canDrop=true; break end
        end
    end
    panel.dropGlow:SetShown(true)
    panel.dropGlow:SetBackdropBorderColor(canDrop and 0.25 or 1,canDrop and 0.9 or 0.25,0.4,0.95)
    self.dropHintPanel=panel
end

function A:HideCategoryDropHint()
    if self.dropHintPanel then self.dropHintPanel.dropGlow:Hide(); self.dropHintPanel=nil end
end

function A:OpenCategoryMenu(panel)
    if InCombatLockdown() then return end
    MenuUtil.CreateContextMenu(panel.move,function(_,root)
        root:CreateTitle(self:CategoryName(panel.id))
        root:CreateButton("Organizar itens",function() self.organizeCategory=panel.id; self:Reconcile(); self:Render() end)
        root:CreateCheckbox("Compactar automaticamente",function() return self:GetLayout()[panel.id].compact end,
            function() self:SetCategoryOption(panel.id,"compact",not self:GetLayout()[panel.id].compact) end)
        root:CreateButton("Personalizar categoria",function() self:OpenCustomization(panel.id) end)
        self:AddCategoryActions(root,panel.id)
        root:CreateButton("Redimensionar no editor",function() self.window:Show(); self:StartEdit() end)
        root:CreateCheckbox("Bloquear movimento das categorias",function() return self:GetSettings().layoutLocked end,
            function() self:ToggleLayoutLock() end)
    end)
end
