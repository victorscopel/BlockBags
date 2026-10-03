local _, A = ...

function A:BuildVirtualStacks()
    self.virtualStackPools=self.virtualStackPools or {}
    self.expandedVirtualStacks=self.expandedVirtualStacks or {}
    self.liveVirtualStacks=self:ClearTable(self.liveVirtualStacks or {})
    for id,pool in pairs(self.virtualStackPools) do
        if not self:GetLayout()[id] then self.virtualStackPools[id]=nil end
    end
    for _,cat in ipairs(self.categories) do
        local group=self.groups[cat.id]
        group.virtualAt=self:ClearTable(group.virtualAt or {})
        group.virtualHidden=self:ClearTable(group.virtualHidden or {})
        local pool=self.virtualStackPools[cat.id] or {}; self.virtualStackPools[cat.id]=pool
        for _,stack in pairs(pool) do stack.live=false; self:ClearTable(stack.members); self:ClearTable(stack.indices); stack.total=0 end
        if self:GetLayout()[cat.id].stackGrouping and not self.draft then
            for index=1,group.max do
                local item=group.positions[index]
                if item and item.classID~=2 and item.classID~=4 and not self.profile.favorites[item.info.itemID]
                    and not self:GetDropSlots()[item.identity] and (not self.itemCache[item.info.itemID] or self.itemCache[item.info.itemID].maxStack~=1) then
                    local signature=(item.info.hyperlink or tostring(item.info.itemID))..":"..(item.binding or "")
                    local stack=pool[signature]
                    if not stack then stack={members={},indices={},total=0}; pool[signature]=stack end
                    if not stack.live then
                        stack.first=index; stack.key=self:ViewKey()..":"..cat.id..":"..signature
                        stack.live=true
                    end
                    stack.members[#stack.members+1]=item; stack.indices[#stack.indices+1]=index; stack.total=stack.total+(item.info.stackCount or 1)
                    group.virtualAt[index]=stack
                end
            end
        end
        for signature,stack in pairs(pool) do
            if not stack.live then pool[signature]=nil
            elseif #stack.members>1 then
                self.liveVirtualStacks[stack.key]=true
                stack.expanded=self.expandedVirtualStacks[stack.key]==true
                if not stack.expanded then
                    for _,index in ipairs(stack.indices) do if index~=stack.first then group.virtualHidden[index]=true end end
                end
            end
        end
    end
    for key in pairs(self.expandedVirtualStacks) do if not self.liveVirtualStacks[key] then self.expandedVirtualStacks[key]=nil end end
end

function A:ToggleVirtualStack(stack)
    if InCombatLockdown() or self.draft or not stack or #stack.members<2 then return end
    self.expandedVirtualStacks[stack.key]=not self.expandedVirtualStacks[stack.key] or nil
    self:Render()
end

function A:DisplayStackCount(button,item)
    local group=self.groups and self.groups[item.category]
    local stack=not self.physicalBagView and group and group.virtualAt and group.virtualAt[button.anchorIndex]
    if stack and #stack.members>1 and not stack.expanded and button.anchorIndex==stack.first then return stack.total end
    return item.info.stackCount
end

function A:PaintVirtualStack(button,item)
    local group=self.groups[item.category]
    local stack=group.virtualAt and group.virtualAt[button.anchorIndex]
    local active=stack and #stack.members>1 and button.anchorIndex==stack.first
    if active and not button.stackBadge then
        local badge=CreateFrame("Button",nil,button)
        button.stackBadge=badge
        badge:SetSize(14,14); badge:SetPoint("TOPLEFT",-2,2)
        badge:SetFrameLevel(button:GetFrameLevel()+6)
        local font=badge:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); font:SetPoint("CENTER"); badge.label=font
        badge:SetScript("OnClick",function() self:ToggleVirtualStack(badge.stack) end)
        badge:SetScript("OnEnter",function()
            GameTooltip:SetOwner(badge,"ANCHOR_RIGHT")
            GameTooltip:SetText(self.L["Pilhas agrupadas"])
            GameTooltip:AddLine(string.format(self.L["%d itens em %d slots físicos."],badge.stack.total,#badge.stack.members),1,1,1)
            GameTooltip:AddLine(self.L["Clique em + para acessar cada pilha. Usar ou arrastar o ícone atua apenas na pilha desse slot."],1,0.82,0,true)
            GameTooltip:Show()
        end)
        badge:SetScript("OnLeave",function() GameTooltip:Hide() end)
    end
    if button.stackBadge then
        button.stackBadge:SetShown(not not active)
        button.stackBadge.stack=active and stack or nil
        if active then button.stackBadge.label:SetText(stack.expanded and "−" or "+") end
    end
    if self.combatController then
        local reveal=group.virtualHidden[button.anchorIndex]==true and self:CategoryDisplayed(item.category)
        if button:GetAttribute("combat-reveal")~=reveal then button:SetAttribute("combat-reveal",reveal) end
    end
end
