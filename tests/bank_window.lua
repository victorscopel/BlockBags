-- Inventory and bank use independent controllers, profiles and frame pools.
A.storage="bags"; A.activeTab="default"; A.atBank=false; A.draft=nil; A.ready=true
A.integrationBlocked=false
local contents={[0]={[1]=94001,[2]=94002},[6]={[1]=94001},[12]={[1]=94002}}
local function count(bag) return contents[bag] and 4 or 0 end
C_Container.GetContainerNumSlots=count
C_Container.GetContainerNumFreeSlots=function(bag)
    local occupied=0; for _ in pairs(contents[bag] or {}) do occupied=occupied+1 end
    return count(bag)-occupied,0
end
C_Container.GetContainerItemInfo=function(bag,slot)
    local id=contents[bag] and contents[bag][slot]
    if id then return {itemID=id,stackCount=1,quality=1,iconFileID=id} end
end
C_Container.GetContainerItemQuestInfo=function() return {} end
C_Item.GetItemInfo=function(id) return "Potion "..id,nil,1,1,1,nil,nil,1,"",id,1,0,0,0,0,nil,false end
C_Item.GetItemGUID=function(location)
    if contents[location.bag] and contents[location.bag][location.slot] then return "separate-"..location.bag..":"..location.slot end
end
C_Bank={CanViewBank=function() return true end,CanUseBank=function() return true end,
    FetchPurchasedBankTabIDs=function(kind) return kind==Enum.BankType.Character and {6} or {12} end,
    FetchPurchasedBankTabData=function() return {{ID=12,name="Shared"}} end}
BankFrame=CreateFrame("Frame")
BankPanel=CreateFrame("Frame")
BankPanel.MoneyFrame,BankPanel.AutoDepositFrame,BankPanel.Header,BankPanel.MoneyDisplay=false,false,false,false
BankPanel.SetBankType=function(panel,kind) panel.bankType=kind end
local bankCloses=0
C_Bank.CloseBankFrame=function() bankCloses=bankCloses+1 end
C_Timer.After=function(_,callback) callback() end
CursorHasItem=function() return false end
GetCursorInfo=function() end
IsModifiedClick=function() return false end
local mainProfile=A.profile
local mainLayout=A:Copy(A:GetBaseLayout())
local mainCategories=A.categories
A.window:Show(); A:ScanInventory(); A:Reconcile(); A:Render()
local inventoryButton=A.buttons["0:1"]
-- Preserve a legacy bank layout during one-time migration.
A.profile.extraLayouts=A.profile.extraLayouts or {}
A.profile.extraLayouts["character:default"]=A:Copy(A.profile.layout)
A.profile.extraLayouts["character:default"].consumables.tint={r=0.11,g=0.22,b=0.33}
A:BankOpened()
local bank=A.bankController
assert(bank and bank~=A and bank.isBankWindow and bank.window~=A.window)
assert(A.window:IsShown() and bank.window:IsShown() and A.storage=="bags" and bank.storage=="character")
assert(A.profile==mainProfile and A.categories==mainCategories and A.buttons["0:1"]==inventoryButton)
assert(#A.items==2 and #bank.items==1 and bank.items[1].bag==6)
assert(bank.profile~=A.profile and bank.categories~=A.categories and bank.itemCache~=A.itemCache)
assert(bank.panels~=A.panels and bank.buttons~=A.buttons and bank.settingsIDs~=A.settingsIDs)
assert(bank:GetBaseLayout().consumables.tint.r==0.11)
assert(not A.profile.extraLayouts["character:default"])
assert(not A.storageSelector:IsShown() and bank.storageSelector:IsShown())
assert(#bank:StorageChoices()==2)
assert(bank.windowName=="BlockBagsBankWindow" and bank:GetDatabase()==BlockBagsDB.bank.scopes.character)
-- Renaming/recoloring bank categories never changes inventory categories.
local originalName=A:CategoryName("consumables")
bank:SetCategoryOption("consumables","name","Bank potions")
bank:SetCategoryOption("consumables","tint",{r=0.9,g=0.1,b=0.2})
assert(A:CategoryName("consumables")==originalName and bank:CategoryName("consumables")=="Bank potions")
assert(A:GetLayout().consumables.tint==nil or A:GetLayout().consumables.tint.r~=0.9)
local bankItem=bank.items[1]
bank:ToggleFavorite(bankItem)
assert(not bank.profile.favorites[94001] and not A.profile.favorites[94001])
local extra=bank:CreateCategory("Bank only"); assert(extra and not A:GetLayout()[extra])
assert(bank:DeleteCategory(extra) and not A:GetLayout()[extra])
-- Warband selection leaves inventory and character-bank layouts alone.
assert(bank:SetStorage("account_12") and bank.items[1].bag==12)
assert(A.storage=="bags" and #A.items==2 and A.buttons["0:1"]==inventoryButton)
assert(A.bankDepositTarget=="account")
assert(bank.windowTitle:GetText()==A.L["Banco da tropa"])
bank:SetCategoryOption("consumables","name","Warband potions")
assert(bank:SetStorage("character") and bank:CategoryName("consumables")=="Bank potions")
-- Controller ownership prevents virtual assignments across physical storages.
GetMouseFoci=function() return {bank.buttons["6:1"]} end
assert(not A:ResolveDropTarget())
-- Native options have their own category controls and profile store.
bank:BuildSettingsControls(); bank:RefreshSettings()
assert(not bank.settingsControls.tabPicker and not bank.settingsControls.categoryTab)
assert(not bank.tabBar and #bank:GetTabs()==1)
assert(not bank:CreateTab("Unneeded") and not bank:AssignCategoryTab("quest","default"))
-- Previously hidden bank categories and their saved slots migrate to the unified view.
bank.profile.tabs={{id="default",name="Main"},{id="tab1",name="Legacy"}}
bank.profile.categoryTabs={quest="tab1"}
bank.profile.extraLayouts["character:tab1"]=bank:Copy(bank:GetBaseLayout())
bank.profile.extraLayouts["character:tab1"].quest.tint={r=0.21,g=0.32,b=0.43}
local bankPositions=bank:GetDatabase().inventoryPositions[bank.characterKey][bank.profileKey]
bankPositions.views["character:tab1"]={quest={["legacy-bank-item"]=4},dropSlots={
    ["legacy-bank-item"]={category="quest",index=4}}}
bank:CollapseBankCategoryTabs()
assert(not bank.profile.tabs and not bank.profile.categoryTabs)
assert(bank:IsCategoryOnTab("quest") and bank:CategoryDisplayed("quest"))
assert(bank:GetBaseLayout().quest.tint.r==0.21)
assert(bankPositions.views["character:default"].quest["legacy-bank-item"]==4)
assert(bankPositions.views["character:default"].dropSlots["legacy-bank-item"].index==4)
assert(not bankPositions.views["character:tab1"] and not bank.profile.extraLayouts["character:tab1"])
local migrated=bank:ExportProfile(); bank:CollapseBankCategoryTabs(); assert(bank:ExportProfile()==migrated)
for _,cat in ipairs(bank.categories) do
    if not bank:GetLayout()[cat.id].hidden then
        for _,other in ipairs(bank.categories) do
            if other.id~=cat.id and not bank:GetLayout()[other.id].hidden then
                local x,y,w,h=bank:PanelRect(bank:GetLayout()[cat.id])
                local ox,oy,ow,oh=bank:PanelRect(bank:GetLayout()[other.id])
                assert(not (x<ox+ow and x+w>ox and y<oy+oh and y+h>oy))
            end
        end
    end
end
local before=A.profileKey
assert(bank:CreateProfile("Bank profile",true))
assert(bank.profileKey=="Bank profile" and A.profileKey==before and not BlockBagsDB.profiles["Bank profile"])
assert(bank:SelectProfile(before))
-- Warm both views, then repeated opening/closing reuses all frames.
bank:SetStorage("account_12"); bank:SetStorage("character")
for n=1,10 do A:BankClosed(); A:BankOpened(); bank:SetStorage("account_12"); bank:SetStorage("character") end
local frames=createdFrames
for n=1,30 do
    A:BankClosed(); assert(A.window:IsShown() and not bank.window:IsShown())
    A:BankOpened(); bank:SetStorage("account_12"); bank:SetStorage("character")
end
assert(createdFrames==frames and A.bankController==bank,"frames: "..frames.." -> "..createdFrames)
-- Hiding inventory alone does not close the bank interaction.
A.window:Hide(); A.window.scripts.OnHide()
assert(bankCloses==0 and bank.window:IsShown())
A.window:Show()
bank.window:Hide(); bank.window.scripts.OnHide()
assert(bankCloses==1 and A.window:IsShown())
A:BankClosed(); assert(not A.atBank and not bank.atBank and not bank.window:IsShown() and A.window:IsShown())
assert(A:GetBaseLayout().consumables.width==mainLayout.consumables.width)
-- Bag updates reach both models without creating another controller or frames.
A:BankOpened()
contents[6][2]=94002
bank:HandleBankWindowEvent("BAG_UPDATE",6)
bank:HandleBankWindowEvent("BAG_UPDATE_DELAYED")
A:QueueRefresh()
assert(#bank.items==2 and #A.items==2)
A:BankClosed()
local scan=bank.ScanInventory
local hiddenScans=0
bank.ScanInventory=function(controller) hiddenScans=hiddenScans+1; return scan(controller) end
for n=1,100 do bank:HandleBankWindowEvent("BAG_UPDATE_DELAYED") end
assert(hiddenScans==0)
bank.ScanInventory=scan
-- Closing the bank in combat defers frame changes until combat ends.
A:BankOpened()
InCombatLockdown=function() return true end
A:BankClosed()
assert(bank.pendingBankWindowClose and bank.window:IsShown())
InCombatLockdown=function() return false end
bank:HandleBankWindowEvent("PLAYER_REGEN_ENABLED")
assert(not bank.pendingBankWindowClose and not bank.window:IsShown() and A.window:IsShown())
A.pendingStorageReset=nil
print("Separate bank OK: simultaneous windows, own categories/profiles/options and backpack-only favorites, legacy bank layouts migrated, Warband selector isolated, cross-window physical drops, 30 reopen cycles reuse frames, independent close behavior")
