local T=RoadmapFixture
local oldWrap,oldDriver,oldKeys,oldCombat=SecureHandlerWrapScript,RegisterStateDriver,GetBindingKey,InCombatLockdown
local combat,secure=false,false
InCombatLockdown=function() return combat end
local function run(header,source,frame,button,newstate)
    local fn=assert(loadstring(source))
    setfenv(fn,setmetatable({self=frame or header,control=header,button=button,newstate=newstate},{__index=_G}))
    local before=secure; secure=true; local ok,err=pcall(fn); secure=before; assert(ok,err)
end
SecureHandlerWrapScript=function(frame,script,header,source)
    frame.secureWrappers=rawget(frame,"secureWrappers") or {}; frame.secureWrappers[script]={header=header,source=source}
end
RegisterStateDriver=function(frame,state,condition) assert(state=="combat" and condition=="[combat] combat; peace"); frame.driver=condition end
GetBindingKey=function(command)
    if command=="TOGGLEBAGS" then return "B","SHIFT-B" end
    if command=="BLOCKBAGS_TOGGLE" then return "CTRL-B" end
end
T:BuildCombatControls(); T.integrationInstalled=true; T:RefreshCombatBindings()
T:BuildBagSlots()
local header=T.combatController
header.GetName=function() return "BlockBagsSecureToggle" end
header.refs={window=T.window,save=T.saveButton,cancel=T.cancelButton,undo=T.undoButton,["bag-slots"]=T.bagSlots}
header.SetFrameRef=function(_,name,frame) header.refs[name]=frame end
local function frameHandle(frame)
    if not frame then return nil end
    return setmetatable({}, {__index=function(_,method)
        return function(_, ...)
            assert(not combat or (frame.template or ""):find("Secure"), "Invalid frame handle: "..tostring(frame.name or frame.kind))
            return frame[method](frame, ...)
        end
    end})
end
header.GetFrameRef=function(_,name) return frameHandle(header.refs[name]) end
header.bindings={}
header.SetBindingClick=function(_,priority,key,name,button) assert(secure); header.bindings[key]={name=name,button=button} end
header.ClearBindings=function() assert(secure); header.bindings={} end
header.ClearBinding=function(_,key) assert(secure); header.bindings[key]=nil end
local originalShow,originalHide=T.window.Show,T.window.Hide
T.window.Show=function(w)
    assert(not combat or secure,"insecure Show during combat")
    originalShow(w)
    local wrap=w.secureWrappers.OnShow; if wrap then run(wrap.header,wrap.source,w) end
end
T.window.Hide=function(w)
    assert(not combat or secure,"insecure Hide during combat")
    originalHide(w)
    local wrap=w.secureWrappers.OnHide; if wrap then run(wrap.header,wrap.source,w) end
end
for _,b in pairs(T.buttons) do T:PrepareCombatButton(b) end
assert(header:GetAttribute("key-count")==3 and header:GetAttribute("slot-count")>0)
-- An ordinary child of a protected window still has an invalid restricted handle.
local plain=CreateFrame("Frame",nil,T.window)
header.refs.unprotected=plain
combat=true
assert(not pcall(function() header:GetFrameRef("unprotected"):Hide() end))
combat=false
header.refs.unprotected=nil
for _,name in ipairs({"window","save","cancel","undo","bag-slots"}) do
    assert((header.refs[name].template or ""):find("Secure"),name.." must be explicitly protected")
end
local button=T.buttons["0:1"]
button:SetAttribute("combat-reveal",true)
local originalItems=T.items
T.items={originalItems[2],originalItems[3],originalItems[4]}; T:Reconcile(); T:Render()
assert(not button:GetAttribute("combat-reveal") and not button:IsShown())
T.items=originalItems; T:Reconcile(); T:Render()
local originalAttribute=button.SetAttribute
button.SetAttribute=function(b,name,value) assert(not combat or secure,"insecure attribute update"); originalAttribute(b,name,value) end
button:SetAttribute("type2","")
button:SetAttribute("combat-reveal",true); button:Hide()
T.window:Hide(); combat=true; header:SetAttribute("state-combat","combat")
run(header,header:GetAttribute("_onstate-combat"),nil,nil,"combat")
assert(header.bindings.B and header.bindings["SHIFT-B"] and header.bindings["CTRL-B"] and not header.bindings.ESCAPE)
assert(button:GetAttribute("type2")=="item" and button:IsShown() and not T.bagSlots:IsShown())
local beforeScroll=T.panels.consumables.offset
local originalScroll=T.panels.consumables.scroll.SetVerticalScroll
T.panels.consumables.scroll.SetVerticalScroll=function() error("insecure scroll during combat") end
T.panels.consumables.wheel(nil,-1)
T.panels.consumables.bar.scripts.OnValueChanged(nil,100)
assert(T.panels.consumables.offset==beforeScroll)
T.panels.consumables.scroll.SetVerticalScroll=originalScroll
run(header,header:GetAttribute("_onclick"),nil,"LeftButton")
assert(T.window:IsShown() and header.bindings.ESCAPE and header.bindings.ESCAPE.button=="Close")
T:Toggle(); assert(T.window:IsShown()) -- Slash commands never simulate secure clicks.
local beforeLayout=T:Copy(T:GetLayout())
T:Render(); assert(T.pendingRefresh and T.window:IsShown())
for id,data in pairs(beforeLayout) do assert(T:GetLayout()[id].x==data.x and T:GetLayout()[id].width==data.width) end
local wrap=T.closeButton.secureWrappers.OnClick; run(wrap.header,wrap.source,T.closeButton,"LeftButton")
assert(not T.window:IsShown() and not header.bindings.ESCAPE and header.bindings.B)
run(header,header:GetAttribute("_onclick"),nil,"Open"); assert(T.window:IsShown())
run(header,header:GetAttribute("_onclick"),nil,"Close"); assert(not T.window:IsShown())
run(header,header:GetAttribute("_onstate-combat"),nil,nil,"peace"); assert(not next(header.bindings))
combat=false
button.SetAttribute=originalAttribute; T.window.Show,T.window.Hide=originalShow,originalHide
SecureHandlerWrapScript,RegisterStateDriver,GetBindingKey,InCombatLockdown=oldWrap,oldDriver,oldKeys,oldCombat
T.combatController=nil; T.combatButtonCount=nil; T.pendingRefresh=nil
-- Timing counters hold aggregates rather than one record per update.
local oldTimer=debugprofilestop; local ticks=0
DebugTime=function() ticks=ticks+2; return ticks end; debugprofilestop=DebugTime
for n=1,1000 do local started=T:BeginRefreshMeasurement(); T:FinishRefreshMeasurement(started) end
assert(T.refreshMetrics.count==1000 and T.refreshMetrics.maximum==2 and T.refreshMetrics.total==2000)
T:ResetPerformanceMeasurements(); assert(not T.refreshMetrics)
debugprofilestop=oldTimer
print("Combat setup OK: protected window/close wrappers, prepared physical slots, combat-only binding overrides, secure open/toggle/close, scoped Escape binding, native type2 item action, collapsed-stack reveal, no insecure show/attribute writes, frozen geometry, return-to-peace cleanup and constant-size refresh metrics; actual taint requires Retail")
