-- Independent stack assignments, split destinations and searchable currencies.
A.storage="bags"; A.activeTab="default"; A.atBank=false; A.draft=nil
A.profile.manualCategories={}; A.profile.favorites={}
A:ClearTable(A:GetStackCategories()); A:ClearTable(A:GetDropSlots())
A.profile.layout.consumables.compact=true
local slots={[1]={id=91001,count=20,guid="potion-original"}}
local cursor
C_Container.GetContainerNumSlots=function(bag) return bag==0 and 8 or 0 end
C_Container.GetContainerNumFreeSlots=function() return 6,0 end
C_Container.GetContainerItemInfo=function(bag,slot)
    local value=bag==0 and slots[slot]
    if value then return {itemID=value.id,stackCount=value.count,quality=1,iconFileID=value.id} end
end
C_Container.GetContainerItemQuestInfo=function() return {} end
C_Item.GetItemGUID=function(location) return slots[location.slot] and slots[location.slot].guid end
A.itemCache[91001]={name="Potion",classID=Enum.ItemClass.Consumable}
GetCursorInfo=function() return cursor and "item",cursor end
CursorHasItem=function() return cursor~=nil end
ClearCursor=function() cursor=nil end
A:ScanInventory(); A:Reconcile(); A:Render()
local original=A.slotModels["0:1"]
A:ToggleFavorite(original)
assert(A.profile.favorites[91001].index==1)
-- Background drops and dropping onto the source slot preserve its position.
for _,index in ipairs({false,1}) do
    A:CaptureItemSource(A.buttons["0:1"]); cursor=91001
    assert(A:TryVirtualDrop("consumables",index or nil))
    assert(not cursor and not A.itemDrag and not A.pendingPlacements)
    assert(A:GetPositions().consumables[original.identity]==1)
    assert(A.profile.favorites[91001].index==1 and not A:GetStackCategories()[original.identity])
end
-- Explicit slots remain movable even with automatic positions and favorites.
for _,index in ipairs({7,1}) do
    A:CaptureItemSource(A.buttons["0:1"]); cursor=91001
    assert(A:TryVirtualDrop("consumables",index))
    assert(not cursor and not A.itemDrag)
    A:ScanInventory(); A:Reconcile(); A:Render()
    assert(A:GetPositions().consumables[original.identity]==index)
    assert(A.profile.favorites[91001].index==index)
    assert(not A:GetStackCategories()[original.identity] and slots[1].count==20)
end
-- Occupied slots swap visually; physical inventory and stack amounts stay intact.
slots[3]={id=91002,count=1,guid="second-consumable"}
A.itemCache[91002]={name="Second",classID=Enum.ItemClass.Consumable}
A:ScanInventory(); A:Reconcile(); A:Render()
local other=A.slotModels["0:3"]
local otherIndex=A:GetPositions().consumables[other.identity]
A:ToggleFavorite(other)
A:CaptureItemSource(A.buttons["0:1"]); cursor=91001
assert(A:TryVirtualDrop("consumables",otherIndex))
assert(A:GetPositions().consumables[original.identity]==otherIndex)
assert(A:GetPositions().consumables[other.identity]==1)
assert(A.profile.favorites[91001].index==otherIndex and A.profile.favorites[91002].index==1)
assert(slots[1].id==91001 and slots[3].id==91002 and slots[1].count==20)
A:CaptureItemSource(A.buttons["0:1"]); cursor=91001
assert(A:TryVirtualDrop("consumables",1))
A:RemoveFavorite(91002); slots[3]=nil
A:ScanInventory(); A:Reconcile(); A:Render()
-- An absent favorite's reservation cannot be displaced by another item.
A.profile.favorites[91003]={category="consumables",index=7,iconFileID=91003}
A:Reconcile(); A:Render()
A:CaptureItemSource(A.buttons["0:1"]); cursor=91001
assert(A:TryVirtualDrop("consumables",7))
assert(not cursor and A:GetPositions().consumables[original.identity]==1)
assert(A.profile.favorites[91003].index==7)
A:RemoveFavorite(91003)
-- Native splitting creates a new GUID in the chosen physical empty slot.
slots[1].count=5; slots[2]={id=91001,count=15,guid="potion-split"}
cursor=91001
A:RememberDrop({anchorCategory="consumables",anchorIndex=6,anchorSlotKey="0:2"})
cursor=nil
A:ScanInventory(); A:Reconcile(); A:Render()
local split=A.slotModels["0:2"]
assert(original.category=="consumables" and split.category=="consumables")
assert(A:GetPositions().consumables[split.identity]==6)
assert(A:GetPositions().consumables[original.identity]==1)
-- A separate matching stack still goes to the native merge handler.
A:CaptureItemSource(A.buttons["0:2"]); cursor=91001
assert(not A:TryVirtualDrop("consumables",1) and cursor==91001 and not A.itemDrag)
cursor=nil
A:Reconcile(); assert(A:GetPositions().consumables[split.identity]==6)
-- Only the dragged stack changes category; the favorite remains in its slot.
A:CaptureItemSource(A.buttons["0:2"]); cursor=91001
assert(A:TryVirtualDrop("misc",5))
A:ScanInventory(); A:Reconcile(); A:Render()
assert(split.category=="misc" and original.category=="consumables")
assert(A.profile.favorites[91001].category=="consumables" and A.profile.favorites[91001].index==1)
assert(A:GetPositions().misc[split.identity]==5 and not A.profile.manualCategories[91001])
A:SetManualCategory(original,"equipment",3)
A:ScanInventory(); A:Reconcile()
assert(A.profile.favorites[91001].category=="equipment")
assert(original.category=="equipment" and split.category=="misc")
local fresh={identity="third-stack",bag=0,info={itemID=91001,quality=1},classID=Enum.ItemClass.Consumable}
assert(A:Classify(fresh)=="consumables")
A:RemoveFavorite(91001)
A:SetManualCategory(original,"equipment",3)
A:ScanInventory(); A:Reconcile()
assert(original.category=="equipment" and split.category=="misc")
assert(original.info.stackCount+split.info.stackCount==20)
local saved=A:GetStackCategories()[split.identity]
A.storage="character"; assert(not A:GetStackCategories()[split.identity])
A.storage="bags"; assert(A:GetStackCategories()[split.identity]==saved)
-- Explicit positions persist, but deliberate sorting releases them.
A:SetManualCategory(split,"consumables")
A.pendingPlacements={["0:2"]={itemID=91001,category="consumables",index=8}}
A:Reconcile(); A:Reconcile()
assert(A:GetPositions().consumables[split.identity]==8)
A.organizeCategory="consumables"; A:Reconcile()
assert(A:GetPositions().consumables[split.identity]==1 and not A:GetDropSlots()[split.identity])
slots[2]=nil; A:ScanInventory(); A:Reconcile()
assert(not A:GetStackCategories()["guid:potion-split"])
print("Stacks OK: per-GUID moves preserve other stacks and favorite; native split slot persists with compact mode; manual sort releases position; consumed assignments pruned; storage isolation")

local nativeCoins=GetCoinTextureString
GetCoinTextureString=function(amount)
    return math.floor(amount/10000).."|Tgold|t "..(math.floor(amount/100)%100).."|Tsilver|t "..(amount%100).."|Tcopper|t"
end
assert(A:FormatMoney(4045798402)=="404.579|Tgold|t 84|Tsilver|t 2|Tcopper|t")
assert(A:FormatMoney(10000000000)=="1.000.000|Tgold|t 0|Tsilver|t 0|Tcopper|t")
assert(A:FormatMoney(9999901)=="999|Tgold|t 99|Tsilver|t 1|Tcopper|t")
assert(A:FormatMoney(0)=="0|Tgold|t 0|Tsilver|t 0|Tcopper|t")
GetCoinTextureString=nativeCoins

A.profile.settings.currencies={301,2}
C_CurrencyInfo={
    GetCurrencyInfo=function(id) return {name=id==301 and "Selected outside list" or "Currency "..id} end,
    GetCurrencyListSize=function() return 300 end,
    GetCurrencyListInfo=function(index) return {currencyID=index,name="Currency "..index} end}
local choices=A:CurrencyChoices("")
assert(#choices==301 and choices[1].selected and choices[2].selected)
assert(#A:CurrencyChoices("outside")==1 and A:CurrencyChoices("outside")[1].id==301)
assert(#A:CurrencyChoices("not a currency")==0)
assert(A:CurrencyChoices("250")[1].id==250)
A.settingsControls.currencySearch:SetText("")
A.settingsControls.currencyPage=999; A:RefreshCurrencyPicker()
assert(A.settingsControls.currencyPage==38)
A.settingsControls.currencySearch:SetText("outside")
A:RefreshCurrencyPicker(); assert(A.settingsControls.currencyPage==1)
print("Currency/gold OK: search by name/ID, selected first without duplicates, bounded pages with 300 currencies, missing selected currencies retained; dot thousands and unchanged silver/copper")

-- Ordinary right-click use must receive the physical bag and slot, not a category.
A:Render()
local usedBag,usedSlot,uses
uses=0
C_Container.UseContainerItem=function(bag,slot) usedBag,usedSlot=bag,slot; uses=uses+1 end
local modified=false
IsAltKeyDown=function() return false end
IsModifiedClick=function() return modified end
for _,name in ipairs({"MerchantFrame","GuildBankFrame","MailFrame","AuctionHouseFrame","AuctionFrame",
    "TradeFrame","ItemUpgradeFrame","ObliterumForgeFrame","ChallengesKeystoneFrame","AzeriteRespecFrame","RuneforgeFrame"}) do
    if _G[name] then _G[name]:Hide() end
end
local itemButton=A.buttons["0:1"]
itemButton.scripts.OnClick(itemButton,"RightButton")
itemButton.scripts.PreClick(itemButton)
assert(uses==0 and itemButton:GetAttribute("type2")=="item")
assert(itemButton:GetAttribute("item2")=="0 1" and itemButton:GetAttribute("useOnKeyDown")==false)
assert(itemButton:GetAttribute("alt-type2")=="" and itemButton:GetAttribute("shift-type2")=="")
modified=true; itemButton.scripts.OnClick(itemButton,"RightButton"); assert(uses==0)
modified=false
MerchantFrame:Show(); assert(not A:CanUseItemDirectly())
itemButton.scripts.PreClick(itemButton); assert(itemButton:GetAttribute("type2")=="")
MerchantFrame:Hide(); itemButton.scripts.PreClick(itemButton); assert(itemButton:GetAttribute("type2")=="item")
A.atBank=true; assert(not A:CanUseItemDirectly()); A.atBank=false
cursor=91001; assert(not A:CanUseItemDirectly()); cursor=nil
print("Item use OK: right-click is configured as a secure item action for the physical slot and does not call protected use in addon Lua; modified clicks and vendor/bank/cursor contexts retain native handling")
