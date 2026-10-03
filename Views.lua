local _, A = ...
local defaultTabs={{id="default",name=A.L["Principal"]}}

function A:GetTabs() return self.profile.tabs or defaultTabs end
function A:ViewKey() return (self.storage or "bags")..":"..(self.activeTab or "default") end
function A:GetBaseLayout()
    if self:ViewKey()=="bags:default" then return self.profile.layout end
    self.profile.extraLayouts=self.profile.extraLayouts or {}
    local key=self:ViewKey()
    local layout=self.profile.extraLayouts[key]
    if not layout then layout=self:Copy(self.profile.layout); self.profile.extraLayouts[key]=layout end
    for _,cat in ipairs(self.categories) do
        if not layout[cat.id] then layout[cat.id]=self:Copy(self.profile.layout[cat.id]) end
    end
    return layout
end
function A:SetBaseLayout(layout)
    if self:ViewKey()=="bags:default" then self.profile.layout=layout
    else self.profile.extraLayouts=self.profile.extraLayouts or {}; self.profile.extraLayouts[self:ViewKey()]=layout end
end
function A:GetPositions()
    if self:ViewKey()=="bags:default" then return self.profile.placements end
    local all=self:GetDatabase().inventoryPositions[self.characterKey][self.profileKey]
    all.views=all.views or {}; all.views[self:ViewKey()]=all.views[self:ViewKey()] or {}
    return all.views[self:ViewKey()]
end
function A:GetStackCategories()
    local all=self:GetDatabase().inventoryPositions[self.characterKey][self.profileKey]
    all.stackCategories=all.stackCategories or {}
    local storage=self.storage or "bags"
    all.stackCategories[storage]=all.stackCategories[storage] or {}
    return all.stackCategories[storage]
end

function A:GetDropSlots()
    local positions=self:GetPositions()
    positions.dropSlots=positions.dropSlots or {}
    return positions.dropSlots
end

function A:IsCategoryOnTab(id)
    return ((self.profile.categoryTabs or {})[id] or "default")== (self.activeTab or "default")
end
function A:CategoryDisplayed(id)
    return self:GetLayout()[id] and not self:GetLayout()[id].hidden and self:IsCategoryOnTab(id)
end
function A:FooterExtra()
    return (#self:GetTabs()>1 and 28 or 0)+(#(self:GetSettings().currencies or {})>0 and 22 or 0)
end

function A:SelectTab(id)
    if self.draft or InCombatLockdown() then self:Print(A.L["Salve ou cancele o layout antes de trocar de aba."]); return false end
    local found=false; for _,tab in ipairs(self:GetTabs()) do if tab.id==id then found=true end end
    if not found then return false end
    if self.physicalBagView then self:SetPhysicalBagView(false) end
    self:CancelBulkAction()
    self:CancelInteractions(); self.activeTab=id
    self:ResizeCanvas(); self:Reconcile(); self:Render()
    if self.RefreshSettings then self:RefreshSettings() end
    return true
end
function A:CreateTab(name)
    if not self:CanChangeProfile() then return false end
    name=(name or ""):match("^%s*(.-)%s*$")
    if #name==0 or #name>40 or #self:GetTabs()>=8 then self:Print(A.L["Use um nome de até 40 caracteres; limite de 8 abas."]); return false end
    self.profile.tabs=self.profile.tabs or self:Copy(defaultTabs)
    local used={}; for _,tab in ipairs(self.profile.tabs) do used[tab.id]=true end
    local n=1; while used["tab"..n] do n=n+1 end
    local id="tab"..n; self.profile.tabs[#self.profile.tabs+1]={id=id,name=name}
    self:ResizeCanvas(); self:Render(); self:RefreshSettings()
    return id
end
function A:RenameTab(id,name)
    if not self:CanChangeProfile() then return false end
    name=(name or ""):match("^%s*(.-)%s*$")
    if #name==0 or #name>40 then return false end
    self.profile.tabs=self.profile.tabs or self:Copy(defaultTabs)
    for _,tab in ipairs(self.profile.tabs) do if tab.id==id then tab.name=name; self:Render(); self:RefreshSettings(); return true end end
    return false
end
function A:AssignCategoryTab(id,tabID)
    if not self:CanChangeProfile() or not self.profile.layout[id] then return false end
    local found=false; for _,tab in ipairs(self:GetTabs()) do if tab.id==tabID then found=true end end
    if not found then return false end
    self.profile.categoryTabs=self.profile.categoryTabs or {}; self.profile.categoryTabs[id]=tabID
    self:RepairTabPlacement(id,tabID)
    self:ResizeCanvas(); self:Render(); self:RefreshSettings()
    return true
end
function A:RepairTabPlacement(id,tabID)
    local function repair(layout)
        local d=layout[id]; if not d then return end
        local x,y,w,h=self:PanelRect(d)
        local collision,bottom=false,0
        for other,data in pairs(layout) do
            if other~=id and not data.hidden and ((self.profile.categoryTabs or {})[other] or "default")==tabID then
                local ox,oy,ow,oh=self:PanelRect(data)
                bottom=math.max(bottom,oy+oh+(self:GetSettings().categorySpacing or 0))
                if x<ox+ow and x+w>ox and y<oy+oh and y+h>oy then collision=true end
            end
        end
        if collision then d.x=0; d.y=bottom/self.cell end
    end
    if tabID=="default" then repair(self.profile.layout) end
    for key,layout in pairs(self.profile.extraLayouts or {}) do if key:match(":"..tabID.."$") then repair(layout) end end
end
function A:DeleteTab(id)
    if id=="default" or not self:CanChangeProfile() then return false end
    for index,tab in ipairs(self:GetTabs()) do
        if tab.id==id then
            for cat,value in pairs(self.profile.categoryTabs or {}) do
                if value==id then self.profile.categoryTabs[cat]=nil; self:RepairTabPlacement(cat,"default") end
            end
            table.remove(self.profile.tabs,index)
            for key in pairs(self.profile.extraLayouts or {}) do if key:match(":"..id.."$") then self.profile.extraLayouts[key]=nil end end
            local views=self:GetDatabase().inventoryPositions[self.characterKey][self.profileKey].views or {}
            for key in pairs(views) do if key:match(":"..id.."$") then views[key]=nil end end
            if self.activeTab==id then self.activeTab="default" end
            self:ResizeCanvas(); self:Reconcile(); self:Render(); self:RefreshSettings()
            return true
        end
    end
    return false
end

function A:PaintTabs()
    if not self.tabBar then
        self.tabBar=CreateFrame("Frame",nil,self.window); self.tabBar.buttons={}
        self.tabBar:SetHeight(24)
    end
    local bar=self.tabBar
    bar:ClearAllPoints(); bar:SetPoint("BOTTOMLEFT",16,35+(#(self:GetSettings().currencies or {})>0 and 22 or 0))
    bar:SetWidth(self.window:GetWidth()-40)
    for index=1,8 do
        local tab=self:GetTabs()[index]; local b=bar.buttons[index]
        if not b then
            b=CreateFrame("Button",nil,bar,"UIPanelButtonTemplate"); bar.buttons[index]=b
            b:SetSize(96,22); b:SetPoint("LEFT",(index-1)*99,0)
            b:SetScript("OnClick",function() if b.tabID then self:SelectTab(b.tabID) end end)
        end
        b.tabID=tab and tab.id
        b:SetShown(tab~=nil)
        if tab then
            local width=math.min(96,math.floor((self.window:GetWidth()-40)/#self:GetTabs())-3)
            b:ClearAllPoints(); b:SetPoint("LEFT",(index-1)*(width+3),0); b:SetWidth(width)
            b:SetText(self:TabName(tab)); b:SetEnabled(not self.draft and tab.id~=(self.activeTab or "default"))
        end
    end
    bar:SetShown(#self:GetTabs()>1 and not self.physicalBagView)
end
