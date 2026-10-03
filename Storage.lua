local _, A = ...
local backpack={0,1,2,3,4,5}

function A:BankType(storage)
    if not Enum.BankType then return end
    return storage and storage:match("^account") and Enum.BankType.Account or Enum.BankType.Character
end
function A:GetBankContainers(bankType)
    if not self.atBank or not C_Bank or not C_Bank.CanViewBank(bankType) then return {} end
    if C_Bank.FetchPurchasedBankTabIDs then return C_Bank.FetchPurchasedBankTabIDs(bankType) or {} end
    local ids={}
    local prefix=bankType==Enum.BankType.Account and "AccountBankTab_" or "CharacterBankTab_"
    for n=1,20 do
        local id=Enum.BagIndex[prefix..n]
        if not id then break end
        if C_Container.GetContainerNumSlots(id)>0 then ids[#ids+1]=id end
    end
    return ids
end
function A:GetScannedBags()
    local storage=self.storage or "bags"
    if storage=="bags" then return backpack end
    if not self.atBank then return {} end
    if storage=="character" or storage=="account" then return self:GetBankContainers(self:BankType(storage)) end
    local id=tonumber(storage:match("^account_(%d+)$"))
    for _,available in ipairs(self:GetBankContainers(self:BankType(storage))) do if available==id then return {id} end end
    return {}
end
function A:StorageChoices()
    local choices={{id="bags",name=self:BackpackTitle()}}
    if not self.atBank or not Enum.BankType then return choices end
    if self.isBankWindow then choices={} end
    choices[#choices+1]={id="character",name=A.L["Banco do personagem"]}
    choices[#choices+1]={id="account",name=A.L["Banco da tropa"]}
    local names={}
    if C_Bank.FetchPurchasedBankTabData and C_Bank.CanViewBank(Enum.BankType.Account) then
        for _,tab in ipairs(C_Bank.FetchPurchasedBankTabData(Enum.BankType.Account) or {}) do names[tab.ID]=tab.name end
    end
    for index,id in ipairs(self:GetBankContainers(Enum.BankType.Account)) do
        choices[#choices+1]={id="account_"..id,name=A.L["Tropa: "]..(names[id] or A.L["Aba "]..index)}
    end
    return choices
end
function A:SetStorage(storage)
    if self.draft or InCombatLockdown() then self:Print(A.L["Salve ou cancele a edição antes de trocar de armazenamento."]); return false end
    local found=false; for _,choice in ipairs(self:StorageChoices()) do if choice.id==storage then found=true end end
    if not found then return false end
    self:CancelBulkAction()
    if self.physicalBagView then self:SetPhysicalBagView(false) end
    self:CancelInteractions(); self.storage=storage
    if self.isBankWindow then self:BeginBankLoad() end
    self:ActivateBankScope(storage)
    if storage~="bags" then
        self.bankDepositTarget=storage
        if self.inventoryController then self.inventoryController.bankDepositTarget=storage end
    end
    if self.isBankWindow then self:SyncBankContext() end
    self.lastCategories=nil; self.pendingPlacements=nil
    self.searchResultIndex=0; self.focusedSearchIdentity=nil
    self:ScanInventory(); self:Reconcile(); self:ResizeCanvas(); self:Render()
    if self.RefreshSettings then self:RefreshSettings() end
    return true
end
function A:PaintStorageSelector()
    if not self.storageSelector then
        local b=CreateFrame("DropdownButton",nil,self.window,"WowStyle2DropdownTemplate")
        self.storageSelector=b; b:SetSize(146,24)
        b:SetPoint("RIGHT",self.seenButton,"LEFT",-28,0)
        b:SetFrameLevel(self.window:GetFrameLevel()+20)
        b:SetupMenu(function(_,root)
            for _,choice in ipairs(self:StorageChoices()) do
                root:CreateRadio(choice.name,function() return (self.storage or "bags")==choice.id end,function() self:SetStorage(choice.id) end)
            end
        end)
    end
    self.storageSelector:SetShown(self.isBankWindow==true and self.atBank==true and not self.draft)
    local name=self.isBankWindow and (self:BankType(self.storage)==Enum.BankType.Account and A.L["Banco da tropa"] or A.L["Banco do personagem"]) or self:BackpackTitle()
    for _,choice in ipairs(self:StorageChoices()) do if choice.id==(self.storage or "bags") then name=choice.name end end
    self.storageSelector:OverrideText(name)
    self.windowTitle:SetText(name)
    if self.isBankWindow then
        local state=self:BankState()
        self.bankAccessState=state
        self.storageSelector:SetEnabled(not self.draft and not InCombatLockdown())
    end
end

-- Bank integration adapted from BetterBags (MIT).
-- Initialize BankPanel during BANKFRAME_OPENED.
function A:BankOpened()
    if self.integrationBlocked then return end
    self.atBank=true
    if InCombatLockdown() then self.pendingBankOpen=true; return end
    self.openingBank=true
    self.pendingBankOpen=nil
    if not self.hiddenBags then self.hiddenBags=CreateFrame("Frame"); self.hiddenBags:Hide() end
    if BankFrame then
        BankFrame:SetParent(self.hiddenBags)
        BankFrame:SetScript("OnShow",nil); BankFrame:SetScript("OnHide",nil); BankFrame:SetScript("OnEvent",nil)
    end
    if BankPanel then
        BankPanel:SetAlpha(0); BankPanel:EnableMouse(false); BankPanel:EnableKeyboard(false)
        for _,key in ipairs({"MoneyFrame","AutoDepositFrame","Header"}) do if BankPanel[key] then BankPanel[key]:Hide() end end
        if BankPanel.MoneyDisplay then BankPanel.MoneyDisplay:UnregisterEvent("PLAYER_MONEY") end
        BankPanel:Show()
        if BankPanel.SetBankType then
            local kind=C_Bank.CanViewBank(Enum.BankType.Character) and Enum.BankType.Character or Enum.BankType.Account
            BankPanel:SetBankType(kind)
        end
    end
    self.window:Show()
    local bank=self:EnsureBankWindow()
    bank.atBank=true
    local choices=bank:StorageChoices()
    local selected=bank.storage
    local available=false
    for _,choice in ipairs(choices) do if choice.id==selected then available=true end end
    selected=available and selected or (choices[1] and choices[1].id)
    if selected then
        bank.window:Show()
        bank:SetStorage(selected)
        self.bankDepositTarget=selected
    end
    self:QueueRefresh()
    self.openingBank=nil
end

function A:PurchaseBankTab(bankType)
    if InCombatLockdown() or not self.atBank or not C_Bank.CanPurchaseBankTab or not C_Bank.CanPurchaseBankTab(bankType) then return end
    local data=C_Bank.FetchNextPurchasableBankTabData(bankType)
    if not data or not data.canAfford then self:Print(A.L["Não há uma aba disponível para compra ou gold suficiente."]); return end
    local ok,costText=pcall(GetCoinTextureString,data.tabCost)
    if not ok or type(costText)~="string" then self:Print(A.L["Não foi possível obter o preço desta aba."]); return end
    StaticPopupDialogs.BLOCKBAGS_PURCHASE_BANK_TAB=StaticPopupDialogs.BLOCKBAGS_PURCHASE_BANK_TAB or {
        text="%s",button1=ACCEPT or A.L["Comprar"],button2=CANCEL,timeout=0,whileDead=true,hideOnEscape=true,
        OnAccept=function(_,info)
            if not (info.owner or A).atBank or InCombatLockdown() or not C_Bank.CanPurchaseBankTab(info.bankType) then return end
            local current=C_Bank.FetchNextPurchasableBankTabData(info.bankType)
            if not current or not current.canAfford then return end
            local ok,cost=pcall(GetCoinTextureString,current.tabCost)
            if not ok or cost~=info.costText then (info.owner or A):PurchaseBankTab(info.bankType); return end
            C_Bank.PurchaseBankTab(info.bankType)
        end}
    local message=(data.purchasePromptTitle or A.L["Comprar aba do banco"])..A.L["\nCusto: "]..costText..A.L["\nConfirmar a compra?"]
    StaticPopup_Show("BLOCKBAGS_PURCHASE_BANK_TAB",message,nil,{bankType=bankType,costText=costText,owner=self})
end
function A:BankClosed()
    self.atBank=false; self.pendingBankOpen=nil
    if self.bankController then self.bankController:CloseBankWindow() end
    self:CancelBulkAction()
    if BankPanel and not self.integrationBlocked then
        BankPanel:Hide()
        if BankPanel.MoneyDisplay then BankPanel.MoneyDisplay:UnregisterEvent("PLAYER_MONEY") end
    end
    if InCombatLockdown() then self.pendingStorageReset=true; return end
    if self.draft then self:FinishEdit(false) end
    if (self.storage or "bags")~="bags" then self:SetStorage("bags") else self:QueueRefresh() end
end
