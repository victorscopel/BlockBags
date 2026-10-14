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

local oldCombat=InCombatLockdown
local blocked=false
InCombatLockdown=function() return blocked end
local order={}
local S=setmetatable({ready=true},{__index=A})
S.ScanInventory=function() order[#order+1]="scan" end
S.Reconcile=function() order[#order+1]="reconcile" end
S.Render=function(self) assert(self.renderPreparing); order[#order+1]="render" end
S.InstallIntegration=function() order[#order+1]="integration" end
S.RefreshCombatBindings=function() order[#order+1]="bindings" end
assert(S:PrepareStartupInventory())
assert(table.concat(order,",")=="scan,reconcile,render","early loading must not install integration before competing addons load")
assert(not S.renderPreparing)
blocked=true
assert(not S:PrepareStartupInventory() and #order==3,"late lockdown must never force startup writes")
InCombatLockdown=oldCombat
print("Startup preparation OK: slots render before integration/bindings, late lockdown is deferred")
