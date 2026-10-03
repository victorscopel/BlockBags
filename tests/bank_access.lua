-- Bank routing, access and event tests use a physical cursor/slot model.
local bank=A.bankController
A.atBank=true; A.storage="bags"; A.window:Show()
bank.atBank=true; bank.window:Show()
local data={[0]={[1]={id=95001,count=3,guid="source-one"},[2]={id=95002,count=1,guid="restricted"}},
    [8]={[1]={id=95003,count=1,guid="bank-one"}},[9]={},[14]={},[15]={}}
local sizes={[0]=4,[1]=0,[2]=0,[3]=0,[4]=0,[5]=0,[8]=3,[9]=3,[14]=3,[15]=3}
local ids={[0]={8,9},[2]={14,15}}
local visible,usable=true,true
local reads,pickups,held={},0,nil
local jobs={}
C_Timer.After=function(delay,callback) jobs[#jobs+1]={delay=delay,callback=callback} end
local function drain()
    local calls=0
    while #jobs>0 do
        local batch=jobs; jobs={}
        for _,job in ipairs(batch) do calls=calls+1; assert(calls<150,"unbounded bank timers"); job.callback() end
    end
    return calls
end
C_Bank.CanViewBank=function() return visible end
C_Bank.CanUseBank=function() return usable end
C_Bank.FetchPurchasedBankTabIDs=function(kind) return ids[kind] end
C_Bank.FetchPurchasedBankTabData=function() return {{ID=14,name="One"},{ID=15,name="Two"}} end
C_Bank.IsItemAllowedInBankType=function(kind,location)
    local value=location.cursor and held or data[location.bag] and data[location.bag][location.slot]
    return kind~=Enum.BankType.Account or not value or value.id~=95002
end
C_Container.GetContainerNumSlots=function(bag) return sizes[bag] or 0 end
C_Container.GetContainerNumFreeSlots=function(bag)
    local occupied=0; for _ in pairs(data[bag] or {}) do occupied=occupied+1 end
    return (sizes[bag] or 0)-occupied,0
end
C_Container.GetContainerItemInfo=function(bag,slot)
    reads[bag]=(reads[bag] or 0)+1
    local value=data[bag] and data[bag][slot]
    if value then return {itemID=value.id,stackCount=value.count,quality=1,hyperlink="item:"..value.id,iconFileID=value.id} end
end
C_Container.GetContainerItemQuestInfo=function() return {} end
C_Item.GetItemInfo=function(id)
    if type(id)=="string" then id=tonumber(id:match("item:(%d+)")) end
    return "Item "..id,"item:"..id,1,1,1,nil,nil,20,"",id,0,0,0,0,0,nil,false
end
C_Item.GetItemGUID=function(location)
    local value=location.cursor and held or data[location.bag] and data[location.bag][location.slot]
    return value and value.guid
end
C_Item.CanBeRefunded=function() return false end
CursorHasItem=function() return held~=nil end
GetCursorInfo=function() if held then return "item",held.id end end
C_Cursor={GetCursorItem=function() if held then return {cursor=true} end end}
C_Container.PickupContainerItem=function(bag,slot)
    pickups=pickups+1
    data[bag]=data[bag] or {}
    local existing=data[bag][slot]
    if held and existing and held.id==existing.id and held.count+existing.count<=20 then existing.count=existing.count+held.count; held=nil
    else held,data[bag][slot]=existing,held end
end
C_Container.UseContainerItem=function() error("bank transfers must not call protected UseContainerItem") end
local nativeType,selectedTab,contextEvents
BankPanel.SetBankType=function(_,kind) nativeType=kind end
BankPanel.SelectTab=function(_,id) selectedTab=id end
ItemButtonUtil={Event={ItemContextChanged=1},TriggerEvent=function() contextEvents=(contextEvents or 0)+1 end}
-- Both native bank context and exact target change on tab selection.
assert(bank:SetStorage("account_15")); drain()
assert(nativeType==Enum.BankType.Account and selectedTab==15 and contextEvents>0 and A.bankDepositTarget=="account_15")
A:ScanInventory(); A:Reconcile(); A:Render()
assert(A.buttons["0:2"].bankBlocked and A.buttons["0:2"].bankRestriction:IsShown())
assert(not A.buttons["0:1"].bankBlocked)
assert(not A:TransferBankItem(A.slotModels["0:2"]) and pickups==0)
assert(A:TransferBankItem(A.slotModels["0:1"])); drain()
assert(not data[0][1] and data[15][1].guid=="source-one" and not next(data[14]))
-- A full selected tab must never fall back to another tab with free space.
for slot=1,3 do data[15][slot]={id=96000+slot,count=20,guid="full"..slot} end
data[0][1]={id=95001,count=3,guid="source-two"}; A:ScanInventory(); A:Reconcile(); A:Render()
local before=pickups
assert(not A:TransferBankItem(A.slotModels["0:1"]) and pickups==before and not next(data[14]))
data[15]={}
-- Character bank right-click withdraws via the native bank template, no item-use call.
local originalCreateFrame=CreateFrame
local modifiedClicks=0
CreateFrame=function(kind,name,parent,template)
    local frame=originalCreateFrame(kind,name,parent,template)
    if template=="BankItemButtonTemplate" then frame:SetScript("OnClick",function() modifiedClicks=modifiedClicks+1 end) end
    return frame
end
assert(bank:SetStorage("character")); drain()
CreateFrame=originalCreateFrame
assert(nativeType==Enum.BankType.Character and bank.buttons["8:1"].template=="BankItemButtonTemplate")
IsModifiedClick=function() return true end
bank.buttons["8:1"].scripts.OnClick(bank.buttons["8:1"],"LeftButton")
assert(modifiedClicks==1)
IsModifiedClick=function() return false end
IsAltKeyDown=function() return false end
bank.buttons["8:1"].scripts.OnClick(bank.buttons["8:1"],"RightButton"); drain()
assert(not data[8][1] and data[0][3].guid=="bank-one")
-- All write paths are blocked in read-only, unavailable or unpurchased banks.
data[8][1]={id=95003,count=1,guid="bank-readonly"}
bank:ScanInventory(); bank:Reconcile(); bank:Render()
usable=false; assert(bank:BankState()=="readonly")
before=pickups
bank.buttons["8:1"].scripts.OnClick(bank.buttons["8:1"],"RightButton")
bank.buttons["8:1"].scripts.OnDragStart(bank.buttons["8:1"])
assert(not bank:RequestCategoryAction(bank.items[1].category,"withdraw","character"))
assert(pickups==before)
visible=false; assert(bank:BankState()=="unavailable")
visible=true; usable=true; ids[0]={}; assert(bank:BankState()=="empty")
ids[0]={8,9}; ids[2]={14}; assert(bank:BankState("account_15")=="unavailable"); ids[2]={14,15}
-- The focused window owns the whole layer; favorite actions are backpack-only.
A:FocusWindow(); assert(A.window.level>bank.window.level)
bank:FocusWindow(); assert(bank.window.level>A.window.level)
bank.titleDrag.scripts.OnMouseDown(); assert(bank.window.level>A.window.level)
A.titleDrag.scripts.OnMouseDown(); assert(A.window.level>bank.window.level)
bank:OpenItemActions(bank.items[1]); assert(not rawget(bank.itemActions,"favorite"))
bank:OpenFavorites(); assert(not bank.favoriteDialog)
bank:ToggleFavorite(bank.items[1]); assert(not next(bank.profile.favorites))
-- Bank options describe this storage and omit backpack-only controls.
bank:BuildSettingsControls(); bank:RefreshSettings()
assert(not bank.settingsControls.currencyPicker and not bank.settingsControls.currencyNames)
assert(bank.settingsControls.info:GetText():find(A.L["Banco do personagem"],1,true))
bank:SetCategoryOption("reagentbag","hidden",false); assert(bank:GetLayout().reagentbag.hidden)
bank:PaintCurrencyBar(); assert(not bank.currencyBar or not bank.currencyBar:IsShown())
local labels={}
MenuUtil.CreateContextMenu=function(_,builder)
    local root={CreateCheckbox=function(_,label) labels[label]=true end,CreateDivider=function() end,CreateButton=function() end}
    builder(nil,root)
end
bank.bagMenuButton.scripts.OnClick(bank.bagMenuButton,"LeftButton")
assert(labels[A.L["Visualização por aba física"]] and not labels[A.L["Mostrar barra de bolsas do WoW"]])
-- Profiles and custom categories belong to their bank scope, including import/export.
local characterProfile=bank.profile
local custom=bank:CreateCategory("Character vault"); assert(custom)
assert(bank:CreateProfile("Character audit",true))
local code=bank:ExportProfile(); local decoded,err=bank:DecodeProfile(code); assert(decoded,err)
assert(decoded.layout[custom])
assert(bank:SetStorage("account_14")); drain()
assert(bank.profile~=characterProfile and not bank:GetLayout()[custom] and not bank:GetDatabase().profiles["Character audit"])
assert(not bank.profile.favorites[95003])
local warProfile=bank.profile
assert(bank:SetStorage("character")); drain()
assert(bank.profileKey=="Character audit" and bank:GetLayout()[custom] and bank.profile~=warProfile)
-- One dirty tab is scanned; unrelated backpack updates and delayed flush add no reads.
reads={}
bank:HandleBankWindowEvent("BAG_UPDATE",0); bank:HandleBankWindowEvent("BAG_UPDATE_DELAYED"); drain()
assert(not next(reads))
reads={}
bank:HandleBankWindowEvent("BAG_UPDATE",8); bank:HandleBankWindowEvent("BAG_UPDATE",8)
bank:HandleBankWindowEvent("BAG_UPDATE_DELAYED"); drain()
assert(reads[8]==sizes[8] and not reads[9])
reads={}; bank:HandleBankWindowEvent("PLAYER_ACCOUNT_BANK_TAB_SLOTS_CHANGED",14); drain(); assert(not next(reads))
-- Missing data preserves saved assignments and reappears on a bounded retry.
local scanCount=0; local scan=bank.ScanInventory
bank.ScanInventory=function(controller,dirty) scanCount=scanCount+1; return scan(controller,dirty) end
sizes[8]=0; sizes[9]=0; bank:BeginBankLoad()
bank:GetStackCategories()["guid:bank-readonly"]="consumables"
bank:ScanInventory(); bank:Reconcile(); bank:Render()
assert(bank.bankLoading and bank:GetStackCategories()["guid:bank-readonly"]=="consumables")
sizes[8]=3; sizes[9]=3; drain()
assert(not bank.bankLoading and bank.items[1].identity=="guid:bank-readonly" and bank.items[1].category=="consumables")
data[8]={}; bank:BeginBankLoad(); bank:ScanInventory(); drain()
assert(bank.bankLoadRetryCount==6 and not bank.bankLoading and #jobs==0)
bank:BeginBankLoad(); bank:ScanInventory()
before=scanCount; bank:CloseBankWindow(); drain()
assert(scanCount==before and not bank.bankLoadRetryQueued)
bank.ScanInventory=scan
-- Refundable deposits use Blizzard's native confirmation with an exact target.
bank.atBank=true; bank.window:Show(); assert(bank:SetStorage("account_15")); drain()
data[0][1]={id=95001,count=1,guid="refundable"}; data[15]={}; A:ScanInventory(); A:Reconcile(); A:Render()
C_Item.CanBeRefunded=function() return true end
Item={CreateFromItemGUID=function(_,guid) return {guid=guid} end}
StaticPopupDialogs.ACCOUNT_BANK_DEPOSIT_NO_REFUND_CONFIRM={}
local popupName,popupData
StaticPopup_Show=function(name,_,_,value) popupName,popupData=name,value end
assert(not A:TransferBankItem(A.slotModels["0:1"]))
assert(held and popupName=="ACCOUNT_BANK_DEPOSIT_NO_REFUND_CONFIRM" and popupData.itemToDeposit.guid=="refundable")
assert(popupData.targetItemLocation.bag==15 and popupData.targetItemLocation.slot==1 and nativeType==Enum.BankType.Account)
C_Container.PickupContainerItem(15,1)
assert(not held and data[15][1].guid=="refundable")
C_Item.CanBeRefunded=function() return false end
A:BankClosed(); drain()
print("Bank access OK: exact selected-tab routing/full-tab refusal, native context/template/modified clicks/refund popup, incompatible item markers, read-only guards, separate scoped profiles/categories, bank-only settings, selective/coalesced reads, late-data recovery and bounded/cancelled retries")
