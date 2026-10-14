local oldCombat,oldAddons=InCombatLockdown,C_AddOns
local combat=true
InCombatLockdown=function() return combat end
C_AddOns={IsAddOnLoaded=function() return false end}
local T=setmetatable({ready=true,integrationInstalled=false,window=CreateFrame("Frame"),L=A.L},{__index=A})
local bindings,visibility,printed=0,0
T.RefreshCombatBindings=function() assert(not combat); bindings=bindings+1 end
T.ApplyBlizzardBagBarVisibility=function() assert(not combat); visibility=visibility+1 end
T.Print=function(_,message) printed=message end
T:InstallIntegration()
assert(not T.integrationInstalled and T.integrationPending,"combat login must record deferred integration")
assert(bindings==0 and visibility==0 and not rawget(T,"hiddenBags"))
T:Toggle(); assert(printed==A.L["Aguarde o fim do combate."],"do not promise an unprepared combat key")
combat=false
T:InstallIntegration()
assert(T.integrationInstalled and not T.integrationPending and bindings==1 and visibility==1)
local frames=createdFrames
T:InstallIntegration()
assert(bindings==1 and visibility==1 and createdFrames==frames,"resume must be idempotent")
InCombatLockdown,C_AddOns=oldCombat,oldAddons
print("Combat reload OK: integration deferred without protected setup, honest toggle guidance, safe completion and repeated resume without allocation")
