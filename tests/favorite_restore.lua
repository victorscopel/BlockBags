-- Restoring a favorite must not displace existing items or other reservations.
A.storage="bags"; A.activeTab="default"; A.draft=nil
A.profile.manualCategories={}; A.profile.favorites={}
A:ClearTable(A:GetStackCategories()); A:ClearTable(A:GetDropSlots())
A.pendingPlacements=nil
A.profile.layout.consumables.compact=false
local function potion(id,identity,category,slot)
    return {identity=identity,name="Potion "..id,sortName="potion "..id,category=category,
        classID=Enum.ItemClass.Consumable,bag=0,slot=slot,slotKey="0:"..slot,
        info={itemID=id,quality=1,stackCount=1,iconFileID=id},quest={}}
end
local first=potion(92001,"first-restore","consumables",1)
local second=potion(92002,"second-restore","consumables",2)
local favorite=potion(92003,"favorite-restore","misc",3)
A.items={first,second,favorite}
A:GetPositions().consumables={[first.identity]=1,[second.identity]=3}
A:GetPositions().misc={[favorite.identity]=7}
A:GetStackCategories()[favorite.identity]="misc"
A.profile.favorites[92004]={category="consumables",index=2,identity="absent-restore"}
A:Reconcile(); A:ToggleFavorite(favorite)
assert(A.profile.favorites[92003].index==7)
A:SetManualCategory(favorite,nil)
assert(favorite.category=="consumables")
assert(A.profile.favorites[92003].category=="consumables" and A.profile.favorites[92003].index==4)
assert(A:GetPositions().consumables[first.identity]==1 and A:GetPositions().consumables[second.identity]==3)
assert(A:GetPositions().consumables[favorite.identity]==4 and A.groups.consumables.reserved[2]==92004)
A:Reconcile(); assert(A:GetPositions().consumables[favorite.identity]==4)
-- Restoring an already automatic favorite keeps its available reserved slot.
A:SetManualCategory(favorite,nil)
assert(A:GetPositions().consumables[favorite.identity]==4)
-- Menu-based moves without an explicit drop slot also choose free space.
A.profile.layout.misc.compact=false
local occupant=potion(92005,"occupied-misc","misc",4)
A.items[#A.items+1]=occupant
A:GetPositions().misc[occupant.identity]=1
A:Reconcile(); A:SetManualCategory(favorite,"misc")
assert(A.profile.favorites[92003].index==2 and A:GetPositions().misc[occupant.identity]==1)
-- Explicit drag destinations still win when provided by the user.
A:SetManualCategory(favorite,"consumables",8)
assert(A.profile.favorites[92003].index==8)
print("Favorite restore OK: first free slot, occupied slots and absent favorites preserved, repeat restore stable, menu move chooses free space, explicit drag index retained")
