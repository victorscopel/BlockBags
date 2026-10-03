-- The header button, settings and saved editor changes use the same mode switch.
A.storage="bags"; A.activeTab="default"; A.draft=nil
A.profile.manualCategories={}; A.profile.favorites={}; A.pendingPlacements=nil
A:ClearTable(A:GetDropSlots()); A:ClearTable(A:GetStackCategories())
A.profile.layout.consumables.compact=false
local function item(id,name,slot)
    return {identity="mode-"..id,name=name,sortName=name:lower(),category="consumables",classID=0,
        bag=0,slot=slot,slotKey="0:"..slot,info={itemID=id,quality=1,stackCount=1,iconFileID=id},quest={}}
end
local zulu=item(93001,"Zulu",1)
local alpha=item(93002,"Alpha",2)
local favorite=item(93003,"Favorite",3)
A.items={zulu,alpha,favorite}
A:GetPositions().consumables={[zulu.identity]=8,[alpha.identity]=6,[favorite.identity]=3}
A:GetDropSlots()[zulu.identity]={category="consumables",index=8}
A.profile.favorites[93003]={category="consumables",index=3,identity=favorite.identity}
A:Reconcile(); A:Render()
local button=A.panels.consumables.mode
button.scripts.OnClick(button)
assert(A:GetLayout().consumables.compact)
assert(A:GetPositions().consumables[alpha.identity]==1 and A:GetPositions().consumables[zulu.identity]==2)
assert(A:GetPositions().consumables[favorite.identity]==3 and not A:GetDropSlots()[zulu.identity])
button.scripts.OnClick(button)
assert(not A:GetLayout().consumables.compact)
A.items={zulu,favorite}; A:Reconcile()
assert(A:GetPositions().consumables[zulu.identity]==2 and not A.groups.consumables.positions[1])
-- Settings can activate automatic mode too, preserving favorite reservations.
A:SetCategoryOption("consumables","compact",true)
assert(A:GetPositions().consumables[zulu.identity]==1 and A:GetPositions().consumables[favorite.identity]==3)
-- A freshly dropped stack stays in the user's chosen slot until sorting or toggling.
A.items={zulu,alpha,favorite}
A.pendingPlacements={[alpha.slotKey]={itemID=93002,category="consumables",index=7}}
A:Reconcile(); A:Reconcile()
assert(A:GetPositions().consumables[alpha.identity]==7)
A:SetCategoryOption("consumables","compact",true)
assert(A:GetPositions().consumables[alpha.identity]==7)
button.scripts.OnClick(button); button.scripts.OnClick(button)
assert(A:GetPositions().consumables[alpha.identity]==1 and A:GetPositions().consumables[zulu.identity]==2)
-- Draft changes do not discard chosen positions when cancelled.
A:SetCategoryOption("consumables","compact",false)
A:GetDropSlots()[alpha.identity]={category="consumables",index=9}
A:Reconcile()
A:StartEdit(); button.scripts.OnClick(button)
assert(A.draft.consumables.compact and A:GetDropSlots()[alpha.identity].index==9)
assert(A:GetPositions().consumables[alpha.identity]==9)
A:FinishEdit(false)
assert(not A:GetLayout().consumables.compact and A:GetPositions().consumables[alpha.identity]==9)
A:StartEdit(); button.scripts.OnClick(button); A:FinishEdit(true)
assert(A:GetLayout().consumables.compact and A:GetPositions().consumables[alpha.identity]==1)
assert(A:GetPositions().consumables[favorite.identity]==3 and not A:GetDropSlots()[alpha.identity])
print("Position modes OK: header/settings/editor agree, automatic activation releases drop pins and sorts, fixed mode preserves holes, explicit split/drop positions and favorite slots respected, cancelled edits retain pins")
