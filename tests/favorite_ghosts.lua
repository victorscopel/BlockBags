-- Absent favorites use pooled, inert icons and keep their reserved positions.
A.storage="bags"; A.activeTab="default"; A.atBank=false; A.draft=nil
A.window:Show(); A.search:SetText("")
A.profile.favorites={}; A.profile.manualCategories={}
A:ClearTable(A:GetStackCategories()); A:ClearTable(A:GetDropSlots())
A.profile.layout.consumables.compact=false
local stock={[1]={id=96001,guid="ghost-original"}}
C_Container.GetContainerNumSlots=function(bag) return bag==0 and 8 or 0 end
C_Container.GetContainerNumFreeSlots=function() return 7,0 end
C_Container.GetContainerItemInfo=function(bag,slot)
    local item=bag==0 and stock[slot]
    if item then return {itemID=item.id,stackCount=1,quality=1,iconFileID=135882,
        hyperlink="item:"..item.id} end
end
C_Container.GetContainerItemQuestInfo=function() return {} end
C_Item.GetItemGUID=function(location) return stock[location.slot] and stock[location.slot].guid end
A.itemCache[96001]={name="Saved potion",classID=Enum.ItemClass.Consumable}
CursorHasItem=function() return false end
GetCursorInfo=function() end
A:ScanInventory(); A:Reconcile(); A:Render()
local item=A.slotModels["0:1"]
A:GetDropSlots()[item.identity]={category="consumables",index=6}
A:Reconcile(); A:Render(); A:ToggleFavorite(item)
local favorite=A.profile.favorites[96001]
assert(favorite.index==6 and favorite.iconFileID==135882 and favorite.hyperlink=="item:96001")
stock[1]=nil; A:ScanInventory(); A:Reconcile(); A:Render()
local panel=A.panels.consumables
local ghost=panel.favoriteGhosts[1]
assert(ghost:IsShown() and ghost.favoriteID==96001 and ghost.anchorIndex==6 and ghost.iconFileID==135882)
assert(not A.emptyPositions.consumables[6] and A.groups.consumables.reserved[6]==96001)
assert(not rawget(ghost,"currentItem") and not ghost.scripts.OnDragStart and not rawget(ghost,"attributes"))
-- Repainting, including a size change, reuses the same frame and textures.
local frames=createdFrames
for n=1,100 do A:Render() end
assert(createdFrames==frames and panel.favoriteGhosts[1]==ghost)
local previousSize=A:GetLayout().consumables.itemSize
A:GetLayout().consumables.itemSize=52; A:Render(); assert(ghost.width==52 and ghost.height==52)
A:GetLayout().consumables.itemSize=previousSize
local oldTooltip=GameTooltip
local lines={}
GameTooltip={SetOwner=function() end,SetHyperlink=function(_,link) assert(link=="item:96001") end,
    AddLine=function(_,line) lines[#lines+1]=line end,Show=function() end,Hide=function() end}
ghost.scripts.OnEnter()
assert(lines[1]==A.L["Favorito ausente da mochila."] and lines[2]==A.L["Este slot permanece reservado para este item."])
GameTooltip=oldTooltip
-- Reacquiring the favorite replaces the ghost and updates its preferred stack.
stock[2]={id=96001,guid="ghost-returned"}
A.itemCache[96001]={name="Saved potion",classID=Enum.ItemClass.Consumable}
A:ScanInventory(); A:Reconcile(); A:Render()
local returned=A.slotModels["0:2"]
assert(not ghost:IsShown() and A:GetPositions().consumables[returned.identity]==6)
assert(favorite.identity==returned.identity and A.buttons["0:2"].favoriteMarker:IsShown())
-- Old profiles without icon metadata recover it once from the item API.
stock[2]=nil; favorite.iconFileID=nil; favorite.hyperlink=nil
local calls=0
local iconAPI=C_Item.GetItemIconByID
C_Item.GetItemIconByID=function(id) calls=calls+1; assert(id==96001); return 135882 end
A:ScanInventory(); A:Reconcile(); A:Render(); A:Render()
assert(calls==1 and favorite.iconFileID==135882 and ghost:IsShown())
local profile=A:DecodeProfile(A:ExportProfile())
assert(profile and profile.favorites[96001].iconFileID==135882 and not profile.favorites[96001].identity)
C_Item.GetItemIconByID=iconAPI
A:RemoveFavorite(96001)
assert(not ghost:IsShown() and not A.groups.consumables.reserved[6])
print("Favorite ghosts OK: saved icons, exact reserved slots, tooltip localization, inert frames, size changes, 100 renders without allocation, reacquisition, old-profile metadata recovery and export")
