local _, A = ...

function A:FormatMoney(amount)
    local value=GetCoinTextureString(amount)
    local gold=math.floor(amount/10000)
    if gold<1000 then return value end
    return (value:gsub("^(%d+)",function(number)
        if tonumber(number)~=gold then return number end
        return number:reverse():gsub("(%d%d%d)","%1."):reverse():gsub("^%.","")
    end))
end

local equipmentSlots={INVTYPE_HEAD={1},INVTYPE_NECK={2},INVTYPE_SHOULDER={3},INVTYPE_BODY={4},INVTYPE_CHEST={5},
    INVTYPE_ROBE={5},INVTYPE_WAIST={6},INVTYPE_LEGS={7},INVTYPE_FEET={8},INVTYPE_WRIST={9},INVTYPE_HAND={10},
    INVTYPE_FINGER={11,12},INVTYPE_TRINKET={13,14},INVTYPE_CLOAK={15},INVTYPE_WEAPON={16,17},
    INVTYPE_2HWEAPON={16},INVTYPE_WEAPONMAINHAND={16},INVTYPE_WEAPONOFFHAND={17},INVTYPE_SHIELD={17},
    INVTYPE_HOLDABLE={17},INVTYPE_RANGED={16},INVTYPE_RANGEDRIGHT={16},INVTYPE_TABARD={19}}
local expansionAliases={classic=0,tbc=1,bc=1,wotlk=2,cata=3,mop=4,wod=5,legion=6,bfa=7,sl=8,df=9,tww=10,mid=11,midnight=11}
A.expansionAliases=expansionAliases
local bindings={[0]="nonbinding",[1]="bop",[2]="boe",[3]="bou",[4]="quest",[7]="account",[8]="warbound",[9]="wue"}
local preferredArmor={WARRIOR=4,PALADIN=4,DEATHKNIGHT=4,HUNTER=3,SHAMAN=3,EVOKER=3,ROGUE=2,DRUID=2,MONK=2,DEMONHUNTER=2,MAGE=1,PRIEST=1,WARLOCK=1}

function A:RefreshEquipmentData()
    self.equippedLevels=self:ClearTable(self.equippedLevels or {})
    for slot=1,19 do
        local link=GetInventoryItemLink and GetInventoryItemLink("player",slot)
        self.equippedLevels[slot]=link and C_Item.GetDetailedItemLevelInfo and C_Item.GetDetailedItemLevelInfo(link) or 0
    end
    self.equipmentMembership=self:ClearTable(self.equipmentMembership or {})
    if not C_EquipmentSet or not C_EquipmentSet.GetEquipmentSetIDs then return end
    for _,setID in ipairs(C_EquipmentSet.GetEquipmentSetIDs() or {}) do
        local name=C_EquipmentSet.GetEquipmentSetInfo(setID)
        for _,location in pairs(C_EquipmentSet.GetItemLocations(setID) or {}) do
            local data
            if EquipmentManager_GetLocationData then data=EquipmentManager_GetLocationData(location)
            elseif EquipmentManager_UnpackLocation then
                local _,bank,bags,_,slot,bag=EquipmentManager_UnpackLocation(location)
                data={isBank=bank,isBags=bags,slot=slot,bag=bag}
            end
            if name and data and (data.isBank or data.isBags) and data.slot and data.bag then
                local key=data.bag..":"..data.slot
                self.equipmentMembership[key]=(self.equipmentMembership[key] and self.equipmentMembership[key].."; " or "")..name
            end
        end
    end
end

function A:IsUpgrade(item)
    if not item.equipLoc or not equipmentSlots[item.equipLoc] or not item.itemLevel then return false end
    if C_PlayerInfo and C_PlayerInfo.CanUseItem and not C_PlayerInfo.CanUseItem(item.info.itemID) then return false end
    if item.classID==4 and item.equipLoc~="INVTYPE_CLOAK" and type(item.subclassID)=="number" and item.subclassID>=1 and item.subclassID<=4 and UnitClass then
        local _,class=UnitClass("player")
        local preferred=preferredArmor[class]
        if preferred and preferred~=item.subclassID then return false end
    end
    if self:GetSettings().upgradeProvider=="pawn" and PawnShouldItemLinkHaveUpgradeArrowUnbudgeted and item.info.hyperlink then
        local ok,result=pcall(PawnShouldItemLinkHaveUpgradeArrowUnbudgeted,item.info.hyperlink,true)
        if ok then return not not result end
    end
    if item.equipLoc=="INVTYPE_WEAPONOFFHAND" or item.equipLoc=="INVTYPE_SHIELD" or item.equipLoc=="INVTYPE_HOLDABLE" then
        local link=GetInventoryItemLink and GetInventoryItemLink("player",16)
        if link then
            local equippedType=select(9,C_Item.GetItemInfo(link))
            if equippedType=="INVTYPE_2HWEAPON" then return false end
        end
    end
    -- Compare rings and trinkets against both equipped slots.
    for _,slot in ipairs(equipmentSlots[item.equipLoc]) do
        local level=self.equippedLevels and self.equippedLevels[slot]
        if type(level)=="number" and item.itemLevel>level then return true end
    end
    return false
end

function A:EnrichItem(item,data,location)
    item.equipLoc=data and data.equipLoc
    item.expansionID=data and data.expansionID
    item.subtype=data and data.subtype
    item.subclassID=data and data.subclassID
    item.binding=bindings[data and data.bindType or 0] or "unknown"
    if C_Item.IsBound and C_Item.IsBound(location) then item.binding="soulbound" end
    if C_Item.IsBoundToAccountUntilEquip and C_Item.IsBoundToAccountUntilEquip(location) then item.binding="wue"
    elseif C_Item.IsBoundToAccount and C_Item.IsBoundToAccount(location) then item.binding="warbound" end
    if item.binding=="soulbound" and C_Bank and C_Bank.IsItemAllowedInBankType and Enum.BankType
        and C_Bank.IsItemAllowedInBankType(Enum.BankType.Account,location) then item.binding="warbound" end
    if data and data.bindType==4 then item.binding="quest" end
    item.equipmentSet=self.equipmentMembership and self.equipmentMembership[item.slotKey] or ""
    item.upgrade=self:IsUpgrade(item)
    item.uncollected=false
    if (item.classID==2 or item.classID==4) and C_TransmogCollection and C_TransmogCollection.GetItemInfo then
        local appearance,modified=C_TransmogCollection.GetItemInfo(item.info.hyperlink or item.info.itemID)
        if appearance and appearance>0 and modified and modified>0 and C_TransmogCollection.PlayerHasTransmog then
            item.uncollected=not C_TransmogCollection.PlayerHasTransmog(item.info.itemID,modified)
        end
    end
    -- Invalidate cached tooltip text when the item or collection data changes.
    local signature=item.identity..":"..(item.info.hyperlink or "")..":"..(item.info.stackCount or 1)
    if item.tooltipSignature~=signature or self.invalidateTooltips then item.tooltipText=nil; item.tooltipSignature=signature end
end

function A:GetSearchTooltip(item)
    if item.tooltipText then return item.tooltipText end
    if not C_TooltipInfo or not C_TooltipInfo.GetBagItem then return "" end
    local tooltip=C_TooltipInfo.GetBagItem(item.bag,item.slot)
    if not tooltip then return "" end
    local lines={}
    for _,line in ipairs(tooltip.lines or {}) do
        if type(line.leftText)=="string" then lines[#lines+1]=line.leftText end
        if type(line.rightText)=="string" then lines[#lines+1]=line.rightText end
    end
    item.tooltipText=table.concat(lines," "):lower()
    return item.tooltipText
end

function A:BuildItemIndicators(b)
    b.upgradeMarker=b:CreateTexture(nil,"OVERLAY")
    b.upgradeMarker:SetTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
    b.upgradeMarker:SetRotation(math.pi/2)
    b.upgradeMarker:SetVertexColor(0.2,1,0.25)
    b.upgradeMarker:SetSize(13,13); b.upgradeMarker:SetPoint("TOPLEFT",1,-12); b.upgradeMarker:Hide()
    b.setMarker=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    b.setMarker:SetText("C"); b.setMarker:SetPoint("TOPRIGHT",-2,-13); b.setMarker:SetTextColor(0.4,0.8,1); b.setMarker:Hide()
    b.transmogMarker=b:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    b.transmogMarker:SetText("T"); b.transmogMarker:SetPoint("BOTTOMLEFT",2,13); b.transmogMarker:SetTextColor(1,0.4,0.85); b.transmogMarker:Hide()
end

function A:PaintItemIndicators(b,item)
    local settings=self:GetSettings()
    b.upgradeMarker:SetShown(settings.showUpgrade~=false and item.upgrade==true)
    b.setMarker:SetShown(settings.showEquipmentSets~=false and (item.equipmentSet or "")~="")
    b.transmogMarker:SetShown(settings.showTransmog~=false and item.uncollected==true)
end

function A:PaintCurrencyBar()
    if not self.currencyBar then
        self.currencyBar=CreateFrame("Frame",nil,self.window)
        self.currencyBar:SetPoint("BOTTOMLEFT",16,35); self.currencyBar:SetHeight(20)
        self.currencyBar.buttons={}
    end
    local bar=self.currencyBar
    local ids=self:GetSettings().currencies or {}
    local x=0
    for index=1,7 do
        local b=bar.buttons[index]
        if not b then
            b=CreateFrame("Button",nil,bar); bar.buttons[index]=b; b:SetHeight(20)
            b.text=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); b.text:SetPoint("LEFT")
            b:SetScript("OnEnter",function()
                if b.currencyID then GameTooltip:SetOwner(b,"ANCHOR_TOP"); GameTooltip:SetCurrencyByID(b.currencyID); GameTooltip:Show() end
            end)
            b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        end
        local info=ids[index] and C_CurrencyInfo and C_CurrencyInfo.GetCurrencyInfo(ids[index])
        b.currencyID=ids[index]
        b:SetShown(info~=nil)
        if info then
            local value="|T"..(info.iconFileID or 0)..":14|t "..(info.quantity or 0)
            if info.maxQuantity and info.maxQuantity>0 then value=value.."/"..info.maxQuantity end
            b.text:SetText(value)
            local textWidth=b.text:GetStringWidth()
            local width=type(textWidth)=="number" and textWidth+18 or 100
            width=math.min(width,math.max(60,(self.window:GetWidth()-40)/math.max(1,#ids)))
            b.text:SetWidth(width-8); b.text:SetWordWrap(false)
            b:ClearAllPoints(); b:SetPoint("LEFT",bar,"LEFT",x,0); b:SetWidth(width); x=x+width
        end
    end
    bar:SetWidth(math.max(1,x)); bar:SetShown(#ids>0 and not self.draft)
end
