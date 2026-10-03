-- Focused offline tests for the 0.5 feature set. Blizzard behavior is mocked;
-- native secure operations still require the in-game checklist in TESTING.md.
A.window:Show()
Settings.OpenToCategory=function() SettingsPanel:Show() end
assert(A:CreateProfile("Expanded features",false))
A.storage="bags"; A.activeTab="default"; A.atBank=false
Enum.BankType={Character=0,Account=2}
Enum.BagIndex.CharacterBankTab_1=6; Enum.BagIndex.CharacterBankTab_2=7
Enum.BagIndex.AccountBankTab_1=12; Enum.BagIndex.AccountBankTab_2=13
local data={ [0]={[1]=101,[2]=102,[3]=103},[1]={[1]=104},[5]={},
    [6]={[1]=101},[7]={[1]=102},[12]={[1]=102},[13]={[1]=101} }
local counts={[0]=5,[1]=3,[2]=0,[3]=0,[4]=0,[5]=2,[6]=4,[7]=4,[12]=3,[13]=3}
local catalog={
    [101]={name="Ring",class=4,subclass=0,equip="INVTYPE_FINGER",level=120,bind=2,expansion=10},
    [102]={name="Sword",class=2,subclass=7,equip="INVTYPE_WEAPONMAINHAND",level=150,bind=2,expansion=11},
    [103]={name="Cloth",class=4,subclass=1,equip="INVTYPE_CHEST",level=300,bind=1,expansion=10},
    [104]={name="Reagent",class=0,subclass=0,level=1,bind=0,expansion=10,reagent=true},
}
C_Container.GetContainerNumSlots=function(bag) return counts[bag] or 0 end
C_Container.GetContainerNumFreeSlots=function(bag)
    local filled=0; for _ in pairs(data[bag] or {}) do filled=filled+1 end
    return (counts[bag] or 0)-filled,0
end
C_Container.GetBagName=function(bag) return "Container "..bag end
C_Container.GetContainerItemInfo=function(bag,slot)
    local id=data[bag] and data[bag][slot]
    if id then return {itemID=id,quality=3,stackCount=1,iconFileID=id,hyperlink="item:"..id} end
end
C_Container.GetContainerItemQuestInfo=function() return nil end
C_Item.GetItemInfo=function(id)
    if type(id)=="string" then id=tonumber(id:match("item:(%d+)")) end
    local c=catalog[id]; if not c then return end
    return c.name,"item:"..id,3,c.level,1,"Equipment","Subtype",1,c.equip,id,10,c.class,c.subclass,c.bind,c.expansion,nil,c.reagent
end
ItemLocation.CreateFromBagAndSlot=function(_,bag,slot) return {bag=bag,slot=slot} end
C_Item.GetItemGUID=function(location)
    local id=data[location.bag] and data[location.bag][location.slot]
    if id then return "expanded-"..location.bag..":"..location.slot..":"..id end
end
C_Item.GetCurrentItemLevel=function(location)
    local id=data[location.bag] and data[location.bag][location.slot]
    return id and catalog[id].level
end
C_Item.GetDetailedItemLevelInfo=function(link) return link=="equipped" and 100 or 120 end
GetInventoryItemLink=function() return "equipped" end
UnitClass=function() return "Warrior","WARRIOR" end
C_PlayerInfo={CanUseItem=function(id) return id~=103 end}
C_Item.IsBound=function(location) return location.bag==12 end
C_Item.IsBoundToAccountUntilEquip=function() return false end
C_EquipmentSet={GetEquipmentSetIDs=function() return {1} end,
    GetEquipmentSetInfo=function() return "Raid DPS" end,
    GetItemLocations=function() return {[16]=77} end}
EquipmentManager_GetLocationData=function() return {isBags=true,bag=0,slot=2} end
C_TransmogCollection={GetItemInfo=function() return 1,2 end,PlayerHasTransmog=function(id) return id~=102 end}
local usable=true
C_Bank={CanViewBank=function() return usable end,CanUseBank=function() return usable end,
    FetchPurchasedBankTabIDs=function(kind) return kind==0 and {6,7} or {12,13} end,
    FetchPurchasedBankTabData=function() return {{ID=12,name="Materials"},{ID=13,name="Gear"}} end,
    IsItemAllowedInBankType=function(kind,location) return kind~=2 or (data[location.bag] and data[location.bag][location.slot]~=103) end}
local tooltipCalls=0
C_TooltipInfo={GetBagItem=function() tooltipCalls=tooltipCalls+1; return {lines={{leftText="Increase movement speed"},{rightText="Soulbound"}}} end}
A.itemCache={}; A.slotLocations={}; A.invalidateTooltips=true
A:ScanInventory(); A:Reconcile(); A:Render()
local ring,sword,cloth,reagent=A.slotModels["0:1"],A.slotModels["0:2"],A.slotModels["0:3"],A.slotModels["1:1"]
assert(ring.upgrade and sword.upgrade and not cloth.upgrade)
assert(sword.equipmentSet=="Raid DPS" and sword.uncollected)
assert(reagent.reagent and reagent.category=="materials")
assert(ring.binding=="boe" and ring.expansionID==10)
assert(A.buttons["0:2"].upgradeMarker:IsShown() and A.buttons["0:2"].setMarker:IsShown() and A.buttons["0:2"].transmogMarker:IsShown())
assert(A:MatchesQuery(ring,"expansao:tww vinculo:boe slot:anel melhoria:sim"))
assert(A:MatchesQuery(sword,'conjunto:"Raid DPS" descricao:"movement speed" transmog:sim'))
for n=1,100 do assert(A:MatchesQuery(sword,'descricao:"movement speed"')) end
assert(tooltipCalls==1)
A:ScanInventory(); assert(A:MatchesQuery(sword,'descricao:"movement speed"') and tooltipCalls==1)
A.invalidateTooltips=true; A:ScanInventory(); A:MatchesQuery(sword,'descricao:"movement speed"'); assert(tooltipCalls==2)
assert(not A:CompileQuery('conjunto:"incomplete'))
assert(A:ValidateCategoryRule('conjunto:"Raid DPS"'))
PawnShouldItemLinkHaveUpgradeArrowUnbudgeted=function() return false end
A.profile.settings.upgradeProvider="pawn"; A:ScanInventory(); assert(not sword.upgrade)
PawnShouldItemLinkHaveUpgradeArrowUnbudgeted=nil; A:ScanInventory(); assert(sword.upgrade)
A.profile.settings.showUpgrade=false; A.profile.settings.showTransmog=false; A:Render()
assert(not A.buttons["0:2"].upgradeMarker:IsShown() and not A.buttons["0:2"].transmogMarker:IsShown())
A.profile.settings.showUpgrade=true; A.profile.settings.showTransmog=true
print("Equipment/search OK: ilvl/Pawn fallback, unusable gear, physical equipment sets, uncollected transmog, correct reagent metadata, quoted filters, on-demand tooltip indexing/invalidation")

C_CurrencyInfo={GetCurrencyInfo=function(id) return {name="Currency "..id,quantity=id,maxQuantity=1000,iconFileID=1} end,
    GetCurrencyListSize=function() return 2 end,
    GetCurrencyListInfo=function(index) return {currencyID=index,name="Currency "..index} end}
for id=1,7 do assert(A:ToggleCurrency(id)) end
assert(not A:ToggleCurrency(8) and #A.profile.settings.currencies==7)
assert(A:ToggleCurrency(1) and A:ToggleCurrency(8))
A:PaintCurrencyBar(); assert(A.currencyBar:IsShown())
local frames=createdFrames
for n=1,100 do A:PaintCurrencyBar() end
assert(createdFrames==frames)
local originalLayout=A:Copy(A.profile.layout)
local tab=A:CreateTab("Profession"); assert(tab)
assert(A:AssignCategoryTab("materials",tab))
assert(not A.panels.materials:IsShown())
assert(A:SelectTab(tab) and A.panels.materials:IsShown() and not A.panels.equipment:IsShown())
local alternate=A:GetBaseLayout()
alternate.materials.x=0; alternate.materials.y=0
A:StartEdit(); A.draft.materials.width=280; A:FinishEdit(true)
assert(A.profile.layout.materials.width==originalLayout.materials.width)
assert(A:SelectTab("default") and A:GetBaseLayout()==A.profile.layout)
assert(A:SelectTab(tab) and A:GetBaseLayout().materials.width==280)
local profile,error=A:DecodeProfile(A:ExportProfile()); assert(profile,error)
assert(profile.tabs[2].name=="Profession" and profile.extraLayouts["bags:"..tab].materials.width==280)
assert(profile.settings.currencies[7]==8 and profile.categoryTabs.materials==tab)
local bad=A:Copy(profile); bad.categoryTabs.materials="unknown"; assert(not pcall(function() A:ValidateProfile(bad) end))
bad=A:Copy(profile); bad.settings.currencies={1,1}; assert(not pcall(function() A:ValidateProfile(bad) end))
bad=A:Copy(profile); bad.extraLayouts["evil:default"]=A:Copy(bad.layout); assert(not pcall(function() A:ValidateProfile(bad) end))
frames=createdFrames
for n=1,100 do A:SelectTab("default"); A:SelectTab(tab) end
assert(createdFrames==frames)
assert(A:DeleteTab(tab) and not A.profile.categoryTabs.materials and A.activeTab=="default")
assert(A.panels.materials:IsShown() and not A:DeleteTab("default"))
assert(not A.profile.extraLayouts["bags:"..tab])
print("Currencies/tabs OK: seven-currency limit, pooled widgets, independent saved dimensions, quote-safe profile roundtrip, invalid imports rejected, 100 tab switches allocate no frames, deleting tabs preserves categories")

-- Banking respects purchased IDs rather than hardcoded capacities. The same
-- physical slots can be regrouped without touching the inventory layout/maps.
A.atBank=true
assert(#A:StorageChoices()==4)
local bagPositions=A.profile.placements
assert(A:SetStorage("character") and #A:GetScannedBags()==2)
assert(#A.items==2 and A.capacity.total==8 and A.windowTitle:GetText()==A.L["Banco do personagem"])
local bankLayout=A:GetBaseLayout(); bankLayout.equipment.x=0; bankLayout.equipment.width=300
A:Reconcile(); A:Render()
assert(A:GetPositions()~=bagPositions and A.profile.layout.equipment.width~=300)
assert(A:SetStorage("account_12") and #A.items==1 and A.items[1].bag==12)
assert(A.items[1].binding=="warbound")
assert(A.windowTitle:GetText()==A.L["Tropa: "].."Materials")
A:ToggleBagSlots(); assert(A.physicalBagView and not A.bagSlots:IsShown() and A.physicalSections[12]:IsShown())
A:ToggleBagSlots(); assert(not A.physicalBagView)
assert(A:SetStorage("character") and A:GetBaseLayout().equipment.width==300)
assert(A:SetStorage("bags") and A.profile.placements==bagPositions and #A.items==4)
-- Warm all parents/models once, then prove the views don't allocate indefinitely.
for _,storage in ipairs({"bags","character","account_12","account_13"}) do A:SetStorage(storage) end
frames=createdFrames
for n=1,60 do
    for _,storage in ipairs({"bags","character","account_12","account_13"}) do A:SetStorage(storage) end
end
assert(createdFrames==frames)
A:SetStorage("bags")
profile,error=A:DecodeProfile(A:ExportProfile()); assert(profile,error)
assert(profile.extraLayouts["character:default"].equipment.width==300)
usable=false; assert(not A:SetStorage("account_12")); usable=true
A:BankClosed(); assert(not A.atBank and (A.storage or "bags")=="bags")
assert(#A:StorageChoices()==1)
print("Storage OK: purchased bank tabs, isolated inventory/bank layouts and positions, account-bank binding, native physical-bank view, 240 storage switches reuse frames, bank close restores inventory")

local jobs={}
C_Timer.After=function(_,fn) jobs[#jobs+1]=fn end
local function drain()
    local count=0
    while #jobs>0 do
        local batch=jobs; jobs={}
        for _,fn in ipairs(batch) do count=count+1; assert(count<100); fn() end
    end
end
local popup
StaticPopup_Show=function(_,_,_,value) popup=value end
MerchantFrame=CreateFrame("Frame"); MerchantFrame:Show()
local operations={}
C_Container.UseContainerItem=function(bag,slot,_,bankType)
    operations[#operations+1]={bag=bag,slot=slot,bankType=bankType}
    data[bag][slot]=nil
end
A.profile.favorites[101]={category="equipment",index=1}
A:ScanInventory(); A:Reconcile(); A:Render()
assert(A:RequestCategoryAction("equipment","sell"))
-- Ring favorite and sword equipment-set member are excluded. Cloth is the only
-- eligible entry; confirmation itself must issue no server operation.
assert(#popup.entries==1 and popup.entries[1].id==103 and #operations==0)
assert(A:StartBulkAction(popup)); drain()
assert(#operations==1 and operations[1].bag==0 and not A.bulkAction)
data[0][3]=103; A:ScanInventory(); A:Reconcile(); A:Render()
assert(A:RequestCategoryAction("equipment","sell"))
-- Changing the source between confirmation and execution must never sell its replacement.
data[0][3]=104
assert(A:StartBulkAction(popup)); drain(); assert(#operations==1)
data[0][3]=103; A:ScanInventory(); A:Reconcile(); A:Render()
assert(A:RequestCategoryAction("equipment","sell"))
assert(A:StartBulkAction(popup)); A:CancelBulkAction(); local done=#operations; drain(); assert(#operations==done)
MerchantFrame:Hide(); data[0][3]=103; A:ScanInventory(); A:Reconcile(); A:Render()
assert(not A:RequestCategoryAction("equipment","sell"))
A.atBank=true
assert(A:RequestCategoryAction("materials","deposit","account"))
assert(A:StartBulkAction(popup)); drain()
assert(operations[#operations].bankType==Enum.BankType.Account)
-- Rejected native transfer has one attempt and no endless retry chain.
data[1][1]=104; A:ScanInventory(); A:Reconcile(); A:Render()
C_Container.UseContainerItem=function() operations[#operations+1]={rejected=true} end
assert(A:RequestCategoryAction("materials","deposit","character"))
done=#operations; assert(A:StartBulkAction(popup)); drain()
assert(#operations==done+1 and not A.bulkAction and #jobs==0)
assert(A:SetStorage("character"))
A.profile.favorites={}; C_EquipmentSet.GetEquipmentSetIDs=function() return {} end
A:ScanInventory(); A:Reconcile(); A:Render()
C_Container.UseContainerItem=function(bag,slot,_,kind) operations[#operations+1]={bankType=kind}; data[bag][slot]=nil end
assert(A:RequestCategoryAction("equipment","withdraw","character"))
assert(A:StartBulkAction(popup)); drain()
assert(not A.bulkAction and operations[#operations].bankType==Enum.BankType.Character)
A:BankClosed(); A:Render()
print("Bulk actions OK: concrete native confirmation, favorites/sets protected, changed sources skipped, cancellation/context checks, explicit account/character bank type, rejected transfer attempts once, withdrawals complete")
