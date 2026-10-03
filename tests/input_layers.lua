local oldCreate,oldMixin=CreateFrame,ContainerFrameItemButtonMixin
local oldCursor,oldInfo,oldModified=CursorHasItem,GetCursorInfo,IsModifiedClick
local nativeClicks=0
ContainerFrameItemButtonMixin={OnClick=function() nativeClicks=nativeClicks+1 end}
CursorHasItem=function() return false end; GetCursorInfo=function() end; IsModifiedClick=function() return false end
local frames={}
CreateFrame=function(kind,name,parent,template)
    local f=oldCreate(kind,name,parent,template)
    frames[#frames+1]=f
    f.RegisterForDrag=function(frame,key) frame.dragKey=key end
    local setLevel=f.SetFrameLevel
    setLevel(f,parent and parent:GetFrameLevel()+1 or 1)
    -- Native templates may specify a level independently of the addon hierarchy.
    if template and template:find("ContainerFrameItemButtonTemplate",1,true) then setLevel(f,10) end
    local function shift(frame,delta)
        setLevel(frame,frame:GetFrameLevel()+delta)
        for _,child in ipairs(frames) do if child:GetParent()==frame then shift(child,delta) end end
    end
    f.SetFrameLevel=function(frame,level) shift(frame,level-frame:GetFrameLevel()) end
    return f
end
local T={}
for key,value in pairs(A) do if type(value)=="function" then T[key]=value end end
T.L,T.locale=A.L,A.locale; T.cell,T.padding,T.header,T.scrollGutter=40,8,36,0
T.categories=A:Copy(A.baseCategories); T.baseCategories=A:Copy(A.baseCategories)
T.database={}; T.itemCache,T.itemRequests,T.loading={},{},{}
T.windowName="BlockBagsInputTest"; T.itemButtonPrefix="InputItem"
T:InitializeDatabase(); T:BuildUI(); T.ready=true; T.window:Show()
T.items=T:Copy(RoadmapFixture.items); T.slotModels={}; T.emptySlots={}
T.capacity={total=30,free=26,reagentTotal=0,reagentFree=0}
for _,item in ipairs(T.items) do T.slotModels[item.slotKey]=item end
T:Reconcile(); T:Render()
local item=T.items[1]; local b=T.buttons[item.slotKey]; local panel=T.panels[item.category]
local function top(...)
    local winner
    for _,frame in ipairs({...}) do
        local clickable=frame.kind=="Button" or frame.mouse==true
        if clickable and frame.mouse~=false and frame.mouseClick~=false and frame:IsShown() then
            if not winner or frame:GetFrameLevel()>=winner:GetFrameLevel() then winner=frame end
        end
    end
    return winner
end
local function itemTarget()
    return top(b,panel.dropTarget,panel,panel.scroll,panel.content,b:GetParent(),b.focusBorder)
end
assert(b.dragKey=="LeftButton")
assert(itemTarget()==b,"first render: category background intercepts item clicks")
assert(top(panel.organize,panel.dropTarget)==panel.organize,"category background intercepts organize button")
assert(top(panel.mode,panel.dropTarget)==panel.mode,"category background intercepts position mode")
assert(top(panel.customize,panel.dropTarget)==panel.customize,"category background intercepts customization")
itemTarget().scripts.OnClick(b,"LeftButton"); assert(nativeClicks==1)
T:FocusWindow(); assert(itemTarget()==b)
T:Render(); itemTarget().scripts.OnClick(b,"LeftButton"); assert(nativeClicks==2)
T:StartEdit(); assert(not b.mouse)
T:FinishEdit(false); assert(itemTarget()==b and b.mouse)
local before=createdFrames
for n=1,100 do T:Render() end
assert(createdFrames==before and itemTarget()==b)
CreateFrame,ContainerFrameItemButtonMixin=oldCreate,oldMixin
CursorHasItem,GetCursorInfo,IsModifiedClick=oldCursor,oldInfo,oldModified
T.window:Hide()
print("Input layers OK: first-render item clicks reach native handling; category buttons stay above drop receiver; focus/edit transitions and 100 renders reuse frames")
