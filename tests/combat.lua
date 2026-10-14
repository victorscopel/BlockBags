local T=RoadmapFixture
local oldCombat,oldTimer=InCombatLockdown,C_Timer.After
local combat=true
InCombatLockdown=function() return combat end
C_Timer.After=function(_,fn) fn() end
T.initialInventoryPrepared=true
local oldShow,oldHide,oldShown=T.window.Show,T.window.Hide,T.window.SetShown
T.window.SetShown=function(w,shown) if shown then w:Show() else w:Hide() end end
T.window.Show=function(w)
    local changed=not w:IsShown(); oldShow(w)
    if changed and w.scripts.OnShow then w.scripts.OnShow(w) end
end
T.window.Hide=function(w)
    local changed=w:IsShown(); oldHide(w)
    if changed and w.scripts.OnHide then w.scripts.OnHide(w) end
end
assert(not (T.window.template or ""):find("Secure") and not T.combatController)
local start,stop=0,0
local oldStart,oldStop,oldCenter=T.window.StartMoving,T.window.StopMovingOrSizing,T.window.GetCenter
T.window.StartMoving=function() start=start+1 end
T.window.StopMovingOrSizing=function() stop=stop+1 end
T.window.GetCenter=function() return 460,360 end
local hidden=next(T.buttons)
hidden=T.buttons[hidden]; hidden.combatReveal=true; hidden:Hide()
T.window:Hide(); T:RequestWindow("toggle"); assert(T.window:IsShown() and hidden:IsShown())
hidden.combatReveal=false
T:RequestWindow("toggle"); assert(not T.window:IsShown())
T:Toggle(); assert(T.window:IsShown())
T.titleDrag.scripts.OnDragStart(); assert(start==1 and T.windowMoving)
T.titleDrag.scripts.OnDragStop(); assert(stop==1 and not T.windowMoving)
assert(type(T.profile.window.x)=="number" and type(T.profile.window.y)=="number")
T.closeButton.scripts.OnClick(); assert(not T.window:IsShown())
T:Toggle(); assert(T.window:IsShown())
T:UpdateInteractionLayers()
for _,button in pairs(T.buttons) do
    assert(not button.interactionLayer.mouse and button.scripts.OnClick==button.nativeClick)
end
local layout=T:Copy(T:GetLayout())
T:Render(); assert(T.pendingRefresh)
for id,data in pairs(layout) do assert(T:GetLayout()[id].x==data.x and T:GetLayout()[id].width==data.width) end
combat=false; T:UpdateInteractionLayers()
for _,button in pairs(T.buttons) do assert(button.interactionLayer.mouse) end
local oldItems,oldEmpty=T.items,T.emptySlots
T.items={}; T.emptySlots={}; hidden.combatReveal=true
T:Reconcile(); T:Render()
assert(not hidden:IsShown() and hidden.combatReveal==false, "retired slots must not reappear in combat")
T.items,T.emptySlots=oldItems,oldEmpty
T:Reconcile(); T:Render()
T.window.StartMoving,T.window.StopMovingOrSizing,T.window.GetCenter=oldStart,oldStop,oldCenter
T.window.Show,T.window.Hide,T.window.SetShown=oldShow,oldHide,oldShown
InCombatLockdown,C_Timer.After=oldCombat,oldTimer
T.pendingRefresh=nil
print("Combat window OK: ordinary templates, repeated native bag toggles, slash toggle, drag/save, X, native item routes and frozen category geometry")
