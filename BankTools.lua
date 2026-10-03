local _, A = ...

function A:BankToolbarExtra() return self.isBankWindow and 64 or 0 end

function A:PaintMoney()
    if self.draft then self.money:SetText(""); return end
    if self.isBankWindow and self:BankType(self.storage)==Enum.BankType.Account then
        local amount=C_Bank.FetchDepositedMoney and C_Bank.CanViewBank(Enum.BankType.Account) and C_Bank.FetchDepositedMoney(Enum.BankType.Account)
        self.money:SetText(self.L["Tropa: "]..(amount and self:FormatMoney(amount) or "—"))
    else self.money:SetText(self:FormatMoney(GetMoney())) end
end

function A:OpenBankMoneyDialog(withdraw)
    if not self:CanMutateBank() then return false end
    local kind=self:BankType(self.storage)
    local allowed=withdraw and C_Bank.CanWithdrawMoney or C_Bank.CanDepositMoney
    if not C_Bank.DoesBankTypeSupportMoneyTransfer or not C_Bank.DoesBankTypeSupportMoneyTransfer(kind) or not allowed or not allowed(kind) then return false end
    self:SyncBankContext()
    local name=withdraw and "BANK_MONEY_WITHDRAW" or "BANK_MONEY_DEPOSIT"
    if StaticPopup_Hide then StaticPopup_Hide(withdraw and "BANK_MONEY_DEPOSIT" or "BANK_MONEY_WITHDRAW") end
    StaticPopup_Show(name,nil,nil,{bankType=kind})
    return true
end

function A:AutoDepositBankItems()
    if not self:CanMutateBank() or CursorHasItem() or self.bulkAction or (self.inventoryController and self.inventoryController.bulkAction) then return false end
    local kind=self:BankType(self.storage)
    if not C_Bank.DoesBankTypeSupportAutoDeposit or not C_Bank.DoesBankTypeSupportAutoDeposit(kind) then return false end
    self:SyncBankContext()
    local native=BankPanel and BankPanel.AutoDepositFrame and BankPanel.AutoDepositFrame.DepositButton
    if native and native.AutoDepositItems then
        native:AutoDepositItems()
    else
        -- Preserve Blizzard's refund confirmation even if its deposit button is unavailable.
        local refundable=kind==Enum.BankType.Account and ItemUtil and ItemUtil.IteratePlayerInventory and ItemUtil.IteratePlayerInventory(function(location)
            return C_Bank.IsItemAllowedInBankType(kind,location) and C_Item.CanBeRefunded(location)
        end)
        if refundable then StaticPopup_Show("ACCOUNT_BANK_DEPOSIT_ALL_NO_REFUND_CONFIRM",nil,nil,{bankType=kind})
        elseif C_Bank.AutoDepositItemsIntoBank then C_Bank.AutoDepositItemsIntoBank(kind)
        else return false end
    end
    return true
end

function A:CloseBankTransactions()
    if StaticPopup_Hide then
        for _,name in ipairs({"BANK_MONEY_DEPOSIT","BANK_MONEY_WITHDRAW","ACCOUNT_BANK_DEPOSIT_ALL_NO_REFUND_CONFIRM","ACCOUNT_BANK_DEPOSIT_NO_REFUND_CONFIRM","CONFIRM_BUY_BANK_TAB","BLOCKBAGS_PURCHASE_BANK_TAB"}) do StaticPopup_Hide(name) end
    end
end

function A:CloseBankTabSettings()
    local menu=self.nativeBankTabSettings
    if menu then menu:Hide(); self.nativeBankTabSettings=nil end
end

function A:OpenBankTabSettings(id)
    if not self.isBankWindow or not self:CanMutateBank() then return false end
    local found=false
    for _,tab in ipairs(self:GetBankContainers(self:BankType(self.storage))) do if tab==id then found=true; break end end
    if not found then return false end
    local menu=BankPanel and BankPanel.TabSettingsMenu
    if not menu or not menu.OnOpenTabSettingsRequested then return false end
    self:CloseBankTabSettings(); menu:Hide()
    self:SyncBankContext()
    menu:SetParent(self.window); menu:SetAlpha(1); menu:SetFrameStrata("DIALOG")
    menu:SetFrameLevel(self.window:GetFrameLevel()+60)
    menu:ClearAllPoints(); menu:SetPoint("TOPLEFT",self.window,"TOPRIGHT",8,-36); menu:SetClampedToScreen(true)
    self.nativeBankTabSettings=menu
    menu:OnOpenTabSettingsRequested(id)
    return true
end

function A:BuildBankControls()
    if not self.isBankWindow or self.bankControls then return end
    local row=CreateFrame("Frame",nil,self.window)
    row:SetPoint("TOPLEFT",16,-76); row:SetPoint("TOPRIGHT",-24,-76); row:SetHeight(60)
    local c={row=row,tabButtons={}}; self.bankControls=c
    c.count=row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    c.count:SetPoint("TOPLEFT",0,-8); c.count:SetWidth(70); c.count:SetJustifyH("LEFT")
    local function button(title,width,action)
        local b=CreateFrame("Button",nil,row,"UIPanelButtonTemplate")
        b:SetSize(width,24); b:SetText(title); b:SetScript("OnClick",action)
        b:SetScript("OnMouseDown",function() self:FocusWindow() end)
        return b
    end
    c.purchase=button("+",24,function() self:PurchaseBankTab(self:BankType(self.storage)) end)
    c.purchase:SetScript("OnEnter",function(b)
        GameTooltip:SetOwner(b,"ANCHOR_RIGHT"); GameTooltip:SetText(self.L["Comprar aba do banco"])
        local nextTab=C_Bank.FetchNextPurchasableBankTabData and C_Bank.FetchNextPurchasableBankTabData(self:BankType(self.storage))
        if nextTab then GameTooltip:AddLine(self.L["Custo: "]..self:FormatMoney(nextTab.tabCost),1,1,1,true) end
        if not self:CanMutateBank(nil,true) then GameTooltip:AddLine(self:BankStateText(self:BankState()),1,0.4,0.4,true) end
        GameTooltip:Show()
    end)
    c.purchase:SetScript("OnLeave",function() GameTooltip:Hide() end)
    c.depositItems=button(self.L["Depositar itens"],152,function() self:AutoDepositBankItems() end)
    c.depositItems:SetPoint("TOPLEFT",0,-32)
    c.depositItems:SetScript("OnEnter",function(b)
        GameTooltip:SetOwner(b,"ANCHOR_RIGHT"); GameTooltip:SetText(b:GetText())
        GameTooltip:AddLine(self.L["Usa o depósito automático do WoW e os filtros configurados nas abas físicas."],1,1,1,true); GameTooltip:Show()
    end)
    c.depositItems:SetScript("OnLeave",function() GameTooltip:Hide() end)
    c.reagents=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
    c.reagents:SetSize(24,24); c.reagents:SetPoint("LEFT",c.depositItems,"RIGHT",8,0)
    c.reagentsText=c.reagents:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    c.reagentsText:SetPoint("LEFT",c.reagents,"RIGHT",2,0); c.reagentsText:SetText(self.L["Incluir reagentes"])
    c.reagents:SetScript("OnClick",function(b)
        if not self:CanMutateBank(nil,true) then self:RefreshBankControls(); return end
        if C_CVar and C_CVar.SetCVar then C_CVar.SetCVar("bankAutoDepositReagents",b:GetChecked() and "1" or "0")
        elseif SetCVar then SetCVar("bankAutoDepositReagents",b:GetChecked() and "1" or "0") end
    end)
    c.withdraw=button(self.L["Retirar ouro"],108,function() self:OpenBankMoneyDialog(true) end)
    c.withdraw:SetPoint("TOPRIGHT",0,-32)
    c.deposit=button(self.L["Depositar ouro"],108,function() self:OpenBankMoneyDialog(false) end)
    c.deposit:SetPoint("RIGHT",c.withdraw,"LEFT",-6,0)
end

function A:RefreshBankControls()
    if not self.isBankWindow then return end
    self:BuildBankControls()
    local c=self.bankControls
    c.row:SetShown(self.atBank==true)
    local kind=self:BankType(self.storage)
    local ids=self:GetBankContainers(kind)
    local viewable=C_Bank.CanViewBank(kind)
    local count=viewable and (C_Bank.FetchNumPurchasedBankTabs and C_Bank.FetchNumPurchasedBankTabs(kind) or #ids)
    c.count:SetText(count and string.format(self.L["Abas: %d"],count) or self.L["Abas: —"])
    local metadata={}
    if viewable and C_Bank.FetchPurchasedBankTabData then
        for _,tab in ipairs(C_Bank.FetchPurchasedBankTabData(kind) or {}) do metadata[tab.ID]=tab end
    end
    local enabled=self:CanMutateBank(nil,true)
    for index,id in ipairs(ids) do
        local b=c.tabButtons[index]
        if not b then
            b=CreateFrame("Button",nil,c.row); c.tabButtons[index]=b
            b:SetSize(24,24); b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
            b.number=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall"); b.number:SetPoint("BOTTOMRIGHT",0,0)
            b:SetScript("OnClick",function(frame) self:OpenBankTabSettings(frame.bankTabID) end)
            b:SetScript("OnEnter",function(frame)
                GameTooltip:SetOwner(frame,"ANCHOR_RIGHT"); GameTooltip:SetText(frame.tabName)
                GameTooltip:AddLine(self.L["Clique para editar nome, ícone e filtros de depósito. Todos os itens continuam na visão unificada."],1,1,1,true); GameTooltip:Show()
            end)
            b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        end
        b.bankTabID=id; b.tabName=metadata[id] and metadata[id].name or self.L["Aba "]..index
        b:SetNormalTexture(metadata[id] and metadata[id].icon or "Interface\\Icons\\INV_Misc_Bag_10")
        b.number:SetText(index); b:SetPoint("TOPLEFT",72+(index-1)*28,0); b:SetEnabled(enabled); b:Show()
    end
    for index=#ids+1,#c.tabButtons do c.tabButtons[index]:Hide() end
    c.purchase:ClearAllPoints(); c.purchase:SetPoint("TOPLEFT",72+#ids*28,0)
    local maximum=C_Bank.HasMaxBankTabs and C_Bank.HasMaxBankTabs(kind)
    c.purchase:SetShown(not maximum)
    local nextTab=viewable and C_Bank.FetchNextPurchasableBankTabData and C_Bank.FetchNextPurchasableBankTabData(kind)
    c.purchase:SetEnabled(not self.draft and not InCombatLockdown() and self.atBank and C_Bank.CanPurchaseBankTab and C_Bank.CanPurchaseBankTab(kind) and nextTab and nextTab.canAfford)
    local auto=enabled and C_Bank.DoesBankTypeSupportAutoDeposit and C_Bank.DoesBankTypeSupportAutoDeposit(kind)
    c.depositItems:SetText(kind==Enum.BankType.Character and self.L["Depositar reagentes"] or self.L["Depositar itens"])
    c.depositItems:SetEnabled(auto); c.reagents:SetEnabled(auto)
    c.reagents:SetShown(kind==Enum.BankType.Account)
    c.reagents:SetChecked(C_CVar and C_CVar.GetCVarBool and C_CVar.GetCVarBool("bankAutoDepositReagents") or GetCVarBool and GetCVarBool("bankAutoDepositReagents") or false)
    local transfer=C_Bank.DoesBankTypeSupportMoneyTransfer and C_Bank.DoesBankTypeSupportMoneyTransfer(kind)
    c.deposit:SetShown(transfer); c.withdraw:SetShown(transfer)
    c.deposit:SetEnabled(enabled and transfer and C_Bank.CanDepositMoney and C_Bank.CanDepositMoney(kind))
    c.withdraw:SetEnabled(enabled and transfer and C_Bank.CanWithdrawMoney and C_Bank.CanWithdrawMoney(kind))
    if not enabled then self:CloseBankTabSettings() end
end
