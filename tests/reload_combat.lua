local oldCombat=InCombatLockdown
InCombatLockdown=function() return true end
local order={}
local S=setmetatable({ready=true},{__index=A})
S.ScanInventory=function() order[#order+1]="scan" end
S.Reconcile=function() order[#order+1]="reconcile" end
S.Render=function(self) assert(self.renderPreparing and self.preparingCombatInventory); order[#order+1]="render" end
assert(S:PrepareStartupInventory())
assert(table.concat(order,",")=="scan,reconcile,render")
assert(S.initialInventoryPrepared and not S.preparingCombatInventory)
InCombatLockdown=oldCombat
print("Combat reload OK: ordinary inventory initializes even after lockdown, without a protected binding setup")
