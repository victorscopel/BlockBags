-- Banking controls delegate confirmations/settings to Blizzard and reuse their frames.
local bank=A.bankController
SettingsPanel:Hide()
A.atBank=true; A.window:Show(); bank.atBank=true; bank.window:Show()
local money=7654321
local tabs={{ID=14,name="Materials",icon=100,depositFlags=0},{ID=15,name="Gear",icon=101,depositFlags=0}}
local usable,maximum,affordable=true,false,true
C_Bank.CanViewBank=function() return true end
C_Bank.CanUseBank=function() return usable end
C_Bank.FetchBankLockedReason=function() end
C_Bank.FetchPurchasedBankTabIDs=function(kind) if kind==Enum.BankType.Account then local ids={}; for _,tab in ipairs(tabs) do ids[#ids+1]=tab.ID end; return ids end; return {8,9} end
C_Bank.FetchPurchasedBankTabData=function() return tabs end
C_Bank.FetchNumPurchasedBankTabs=function(kind) return kind==Enum.BankType.Account and #tabs or 2 end
C_Bank.FetchDepositedMoney=function(kind) assert(kind==Enum.BankType.Account); return money end
C_Bank.DoesBankTypeSupportMoneyTransfer=function(kind) return kind==Enum.BankType.Account end
C_Bank.CanDepositMoney=function() return usable end
C_Bank.CanWithdrawMoney=function() return usable end
C_Bank.DoesBankTypeSupportAutoDeposit=function() return true end
C_Bank.HasMaxBankTabs=function() return maximum end
C_Bank.CanPurchaseBankTab=function() return usable and not maximum end
C_Bank.FetchNextPurchasableBankTabData=function() if not maximum then return {canAfford=affordable,tabCost=1000000,purchasePromptConfirmation="Confirm new tab"} end end
local kind
BankPanel.SetBankType=function(_,value) kind=value end
local jobs={}
C_Timer.After=function(_,callback) jobs[#jobs+1]=callback end
local function drain()
    local iterations=0
    while #jobs>0 do local batch=jobs; jobs={}; for _,callback in ipairs(batch) do iterations=iterations+1; assert(iterations<200); callback() end end
end
assert(bank:SetStorage("account")); drain()
local c=bank.bankControls
assert(c and c.row:IsShown() and c.count:GetText()==string.format(A.L["Abas: %d"],2))
assert(c.tabButtons[1].number:GetText()==1 and c.tabButtons[2].number:GetText()==2 and c.purchase:IsShown())
assert(bank.money:GetText()==A.L["Tropa: "]..bank:FormatMoney(money))
assert(c.deposit:IsShown() and c.withdraw:IsShown())
local reads=0; local scan=bank.ScanInventory
bank.ScanInventory=function(controller,dirty) reads=reads+1; return scan(controller,dirty) end
money=money+100; bank:HandleBankWindowEvent("ACCOUNT_MONEY")
assert(reads==0 and bank.money:GetText()==A.L["Tropa: "]..bank:FormatMoney(money))
local popup,payload
StaticPopup_Show=function(name,_,_,value) popup,payload=name,value; return {text={SetText=function(_,text) assert(text=="Confirm new tab") end}} end
local hidden={}
StaticPopup_Hide=function(name) hidden[name]=true end
assert(bank:OpenBankMoneyDialog(false) and popup=="BANK_MONEY_DEPOSIT" and payload.bankType==Enum.BankType.Account)
assert(bank:OpenBankMoneyDialog(true) and popup=="BANK_MONEY_WITHDRAW" and hidden.BANK_MONEY_DEPOSIT)
StaticPopupDialogs.CONFIRM_BUY_BANK_TAB={}
c.purchase.scripts.OnClick()
assert(popup=="CONFIRM_BUY_BANK_TAB" and payload.bankType==Enum.BankType.Account)
maximum=true; bank:RefreshBankControls(); assert(not c.purchase:IsShown())
maximum=false; affordable=false; bank:RefreshBankControls(); assert(c.purchase:IsShown() and not c.purchase:IsEnabled())
affordable=true
local purchased=tabs; tabs={}; usable=false
local canPurchase=C_Bank.CanPurchaseBankTab
C_Bank.CanPurchaseBankTab=function() return true end
bank:RefreshBankControls()
assert(bank:BankState()=="empty" and c.purchase:IsEnabled() and c.count:GetText()==string.format(A.L["Abas: %d"],0))
c.purchase.scripts.OnClick(); assert(popup=="CONFIRM_BUY_BANK_TAB")
tabs=purchased; usable=true; C_Bank.CanPurchaseBankTab=canPurchase
bank:RefreshBankControls()
-- Only the native automatic deposit action is invoked; it owns refund confirmation.
local deposits=0
C_Bank.AutoDepositItemsIntoBank=function(value) assert(value==kind); deposits=deposits+1 end
local refundable=false
BankPanel.AutoDepositFrame={DepositButton={AutoDepositItems=function()
    if refundable then StaticPopup_Show("ACCOUNT_BANK_DEPOSIT_ALL_NO_REFUND_CONFIRM",nil,nil,{bankType=kind})
    else C_Bank.AutoDepositItemsIntoBank(kind) end
end}}
assert(bank:AutoDepositBankItems() and deposits==1)
refundable=true; assert(bank:AutoDepositBankItems() and popup=="ACCOUNT_BANK_DEPOSIT_ALL_NO_REFUND_CONFIRM" and deposits==1)
refundable=false
local include=false
C_CVar={GetCVarBool=function(name) assert(name=="bankAutoDepositReagents"); return include end,
    SetCVar=function(name,value) assert(name=="bankAutoDepositReagents"); include=value=="1" end}
c.reagents:SetChecked(true); c.reagents.scripts.OnClick(c.reagents)
assert(include)
c.reagents:SetChecked(false); bank:HandleBankWindowEvent("CVAR_UPDATE","bankAutoDepositReagents")
assert(c.reagents:GetChecked() and reads==0)
-- Native tab settings have a visible parent and do not select a physical item view.
local nativeMenu=CreateFrame("Frame",nil,BankPanel)
local edited
nativeMenu.OnOpenTabSettingsRequested=function(menu,id) edited=id; menu:Show() end
BankPanel.TabSettingsMenu=nativeMenu
c.tabButtons[2].scripts.OnClick(c.tabButtons[2])
assert(edited==15 and nativeMenu:IsShown() and nativeMenu:GetParent()==bank.window and bank.storage=="account")
assert(bank:SetStorage("character")); drain()
assert(not nativeMenu:IsShown() and not c.deposit:IsShown() and not c.withdraw:IsShown() and not c.reagents:IsShown())
assert(bank.money:GetText()==bank:FormatMoney(GetMoney()))
assert(not bank:OpenBankMoneyDialog(true))
assert(bank:SetStorage("account")); drain()
-- Ownership/access guards apply to money, native settings, deposits and purchases.
usable=false
local before=deposits; popup=nil
bank:RefreshBankControls(); assert(not c.deposit:IsEnabled() and not c.withdraw:IsEnabled() and not c.depositItems:IsEnabled() and not c.purchase:IsEnabled())
assert(not bank:AutoDepositBankItems() and deposits==before)
assert(not bank:OpenBankMoneyDialog(false) and not popup)
assert(not bank:OpenBankTabSettings(14))
bank:PurchaseBankTab(Enum.BankType.Account); assert(not popup)
Enum.BankLockedReason={NoAccountInventoryLock=1,BankDisabled=2,BankConversionFailed=3}
C_Bank.FetchBankLockedReason=function() return 1 end
assert(bank:BankStateText("readonly")==A.L["O banco da tropa está em uso em outra sessão."])
usable=true; C_Bank.FetchBankLockedReason=function() end
-- New purchase events update the visible tab count/icons and preserve unified storage.
tabs[3]={ID=16,name="New",icon=102,depositFlags=0}
bank:HandleBankWindowEvent("BANK_TABS_CHANGED",Enum.BankType.Account); drain()
assert(c.count:GetText()==string.format(A.L["Abas: %d"],3) and c.tabButtons[3]:IsShown() and bank.storage=="account")
local frames=createdFrames
for n=1,100 do bank:RefreshBankControls(); bank:PaintMoney() end
assert(createdFrames==frames)
bank:OpenBankTabSettings(14); bank:CloseBankWindow()
assert(not nativeMenu:IsShown() and hidden.BANK_MONEY_DEPOSIT and hidden.BANK_MONEY_WITHDRAW and hidden.ACCOUNT_BANK_DEPOSIT_ALL_NO_REFUND_CONFIRM)
bank.ScanInventory=scan
print("Bank tools OK: persistent tab count/icons/purchase, native money/refund confirmations, event-only balance updates, reagent CVar, visible native tab settings with unified storage, access guards and 100 refreshes reuse frames")
