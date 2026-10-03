local _, A = ...

local function now() return GetServerTime and GetServerTime() or time and time() or 0 end
local function clamp(value,default,minimum,maximum)
    value=tonumber(value) or default
    if value~=value then value=default end
    return math.max(minimum,math.min(maximum,math.floor(value)))
end

function A:GetOfflineCache()
    local inventory=self.inventoryController or self
    local db=inventory:GetDatabase()
    db.offline=db.offline or {enabled=false,snapshots={}}
    local cache=db.offline
    cache.snapshots=cache.snapshots or {}
    cache.maxCharacters=clamp(cache.maxCharacters,5,1,20)
    cache.maxItems=clamp(cache.maxItems,6000,500,12000)
    cache.retentionDays=clamp(cache.retentionDays,30,1,90)
    return cache
end

function A:PruneOfflineCache()
    local cache=self:GetOfflineCache()
    local entries,characters={},{}
    local cutoff=now()-cache.retentionDays*86400
    for key,snapshot in pairs(cache.snapshots) do
        if type(snapshot)~="table" or type(snapshot.at)~="number" or type(snapshot.items)~="table"
            or snapshot.at<cutoff or snapshot.at>now()+86400 or type(snapshot.character)~="string"
            or (snapshot.storage~="bags" and snapshot.storage~="character" and snapshot.storage~="account") or #snapshot.items>1600 then cache.snapshots[key]=nil
        else entries[#entries+1]={key=key,snapshot=snapshot} end
    end
    table.sort(entries,function(a,b) if a.snapshot.at~=b.snapshot.at then return a.snapshot.at>b.snapshot.at end; return a.key<b.key end)
    local total,characterCount=0,0
    for _,entry in ipairs(entries) do
        local snapshot=entry.snapshot
        local isNew=snapshot.storage~="account" and not characters[snapshot.character]
        if (isNew and characterCount>=cache.maxCharacters) or total+#snapshot.items>cache.maxItems then
            cache.snapshots[entry.key]=nil
        else
            total=total+#snapshot.items
            if isNew then characters[snapshot.character]=true; characterCount=characterCount+1 end
        end
    end
    cache.itemCount=total
end

function A:SetOfflineOption(key,value)
    if InCombatLockdown() then return false end
    local cache=self:GetOfflineCache()
    if key=="enabled" then cache.enabled=value==true
    elseif key=="maxCharacters" then cache.maxCharacters=clamp(value,5,1,20)
    elseif key=="maxItems" then cache.maxItems=clamp(value,6000,500,12000)
    elseif key=="retentionDays" then cache.retentionDays=clamp(value,30,1,90)
    else return false end
    self:PruneOfflineCache()
    if cache.enabled then
        local inventory=self.inventoryController or self
        inventory:QueueRefresh()
        if inventory.bankController and inventory.bankController.atBank then inventory.bankController:QueueRefresh() end
    end
    self:RefreshSettings()
    if self.offlineWindow and self.offlineWindow:IsShown() then self:RefreshOfflineWindow() end
    return true
end

function A:ClearOfflineCache()
    local cache=self:GetOfflineCache()
    cache.snapshots={}; cache.itemCount=0
    self:RefreshSettings()
    if self.offlineWindow then self:RefreshOfflineWindow() end
end

function A:CaptureOfflineSnapshot()
    local cache=self:GetOfflineCache()
    if not cache.enabled or InCombatLockdown() or CursorHasItem() or not self.capacity or not self.items then return false end
    if self.isBankWindow and (not self.atBank or self.bankLoading or self:BankState()~="ready") then return false end
    if #self.items>1600 or #self.items>cache.maxItems then return false end
    if #self.items~=(self.capacity.total-self.capacity.free)+(self.capacity.reagentTotal-self.capacity.reagentFree) then return false end
    local storage=self.storage or "bags"
    if storage~="bags" and storage~="character" and storage~="account" then return false end
    if self.isBankWindow and self.capacity.total==0 then return false end
    local key=storage=="account" and "account" or self.characterKey..":"..storage
    local money=storage=="bags" and GetMoney() or nil
    self.snapshotSignature=self:ClearTable(self.snapshotSignature or {})
    local signature=self.snapshotSignature
    signature[1]=tostring(self.capacity.total)..":"..tostring(self.capacity.reagentTotal)..":"..tostring(money)
    for _,item in ipairs(self.items) do
        signature[#signature+1]=item.slotKey..":"..item.info.itemID..":"..(item.info.stackCount or 1)..":"..
            (item.info.hyperlink or "")..":"..(item.name or "")..":"..(item.binding or "")..":"..
            tostring(item.info.quality)..":"..tostring(item.info.iconFileID)..":"..tostring(item.itemLevel)..":"..
            tostring(item.classID)..":"..tostring(item.subclassID)..":"..tostring(item.reagent)..":"..
            tostring(item.expansionID)..":"..(item.equipLoc or "")..":"..(item.subtype or "")..":"..
            (item.equipmentSet or "")..":"..tostring(item.craftQuality)..":"..tostring(item.upgrade)..":"..tostring(item.uncollected)
    end
    local fingerprint=table.concat(signature,"|")
    local snapshot=cache.snapshots[key]
    if snapshot and snapshot.fingerprint==fingerprint then snapshot.at=now(); return true end
    local records={}
    for _,item in ipairs(self.items) do
        records[#records+1]={name=(item.name or ""):sub(1,240),bag=item.bag,slot=item.slot,slotKey=item.slotKey,
            classID=item.classID,subclassID=item.subclassID,reagent=item.reagent,itemLevel=item.itemLevel,
            expansionID=item.expansionID,binding=item.binding,equipLoc=item.equipLoc,subtype=item.subtype,
            equipmentSet=item.equipmentSet,craftQuality=item.craftQuality,upgrade=item.upgrade,uncollected=item.uncollected,offline=true,
            info={itemID=item.info.itemID,stackCount=item.info.stackCount,quality=item.info.quality,
                iconFileID=item.info.iconFileID,hyperlink=item.info.hyperlink and item.info.hyperlink:sub(1,1024)}}
    end
    cache.snapshots[key]={character=self.characterKey,storage=storage,at=now(),items=records,
        capacity=self:Copy(self.capacity),money=money,fingerprint=fingerprint}
    self:PruneOfflineCache()
    local inventory=self.inventoryController or self
    if inventory.offlineWindow and inventory.offlineWindow:IsShown() then inventory:RefreshOfflineWindow() end
    return true
end

function A:OfflineChoices()
    self:PruneOfflineCache()
    local entries={}
    for key,snapshot in pairs(self:GetOfflineCache().snapshots) do entries[#entries+1]={key=key,snapshot=snapshot} end
    table.sort(entries,function(a,b) return a.key<b.key end)
    return entries
end

function A:OfflineStorageName(snapshot)
    local storage=self.L[snapshot.storage=="bags" and "Mochila" or snapshot.storage=="account" and "Banco da tropa" or "Banco do personagem"]
    return snapshot.storage=="account" and storage or snapshot.character.." · "..storage
end

function A:RefreshOfflineWindow()
    local f=self.offlineWindow
    if not f then return end
    local entries=self:OfflineChoices()
    local cache=self:GetOfflineCache()
    local snapshot=cache.snapshots[f.selected or ""]
    if not snapshot then f.selected=entries[1] and entries[1].key; snapshot=f.selected and cache.snapshots[f.selected] end
    f.select:OverrideText(snapshot and self:OfflineStorageName(snapshot) or self.L["Nenhum registro salvo."])
    f.filtered=self:ClearTable(f.filtered or {})
    local search=(f.search:GetText() or ""):lower()
    if snapshot then for _,item in ipairs(snapshot.items) do if search=="" or self:MatchesQuery(item,search) then f.filtered[#f.filtered+1]=item end end end
    local dateText=snapshot and date and date("%x %X",snapshot.at) or snapshot and tostring(snapshot.at) or "—"
    f.status:SetText(snapshot and string.format(self.L["Somente consulta · %d/%d itens · atualizado em %s"],#f.filtered,#snapshot.items,dateText)
        or self.L["Ative o histórico e visite a mochila ou o banco para salvar um registro."])
    f.money:SetText(snapshot and snapshot.money and self:FormatMoney(snapshot.money) or "")
    f.content:SetHeight(math.max(320,math.ceil(#f.filtered/12)*44))
    self:DrawOfflineItems()
end

function A:DrawOfflineItems()
    local f=self.offlineWindow
    local offset=f.scroll:GetVerticalScroll() or 0
    local firstRow=math.max(0,math.floor(offset/44))
    for n=1,108 do
        local index=firstRow*12+n
        local item=f.filtered[index]
        local b=f.buttons[n]
        if item and not b then
            b=CreateFrame("Button",nil,f.content,"BackdropTemplate"); f.buttons[n]=b
            b:SetSize(36,36)
            b.icon=b:CreateTexture(nil,"ARTWORK"); b.icon:SetAllPoints(b)
            b:SetBackdrop({edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
            b.count=b:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); b.count:SetPoint("BOTTOMRIGHT",-1,1)
            b:SetScript("OnEnter",function()
                GameTooltip:SetOwner(b,"ANCHOR_RIGHT")
                if b.item.info.hyperlink then GameTooltip:SetHyperlink(b.item.info.hyperlink)
                else GameTooltip:SetItemByID(b.item.info.itemID) end
                GameTooltip:AddLine(self.L["Registro offline: este item não pode ser usado ou movido."],0.7,0.7,0.7,true)
                GameTooltip:Show()
            end)
            b:SetScript("OnLeave",function() GameTooltip:Hide() end)
        end
        if b then
            b:SetShown(item~=nil); b.item=item
            if item then
                b:ClearAllPoints(); b:SetPoint("TOPLEFT",((index-1)%12)*44,-math.floor((index-1)/12)*44)
                b.icon:SetTexture(item.info.iconFileID or 134400)
                b.count:SetText((item.info.stackCount or 1)>1 and tostring(item.info.stackCount) or "")
                local color=ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[item.info.quality or 1]
                b:SetBackdropBorderColor(color and color.r or 0.6,color and color.g or 0.6,color and color.b or 0.6,1)
            end
        end
    end
end

function A:OpenOfflineInventory()
    if self.inventoryController then return self.inventoryController:OpenOfflineInventory() end
    if InCombatLockdown() then self:Print(self.L["Aguarde o fim do combate."]); return end
    local f=self.offlineWindow
    if not f then
        f=CreateFrame("Frame","BlockBagsOfflineWindow",UIParent,"BackdropTemplate")
        self.offlineWindow=f
        f:SetSize(600,548); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG"); f:SetToplevel(true)
        f:SetMovable(true); f:EnableMouse(true); f:RegisterForDrag("LeftButton"); f:SetClampedToScreen(true)
        f:SetScript("OnDragStart",function() f:StartMoving() end); f:SetScript("OnDragStop",function() f:StopMovingOrSizing() end)
        f:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Tooltips\\UI-Tooltip-Border",edgeSize=16})
        f:SetBackdropColor(0.04,0.05,0.065,0.98)
        local title=f:CreateFontString(nil,"OVERLAY","GameFontNormalLarge"); title:SetPoint("TOPLEFT",20,-16); title:SetText(self.L["Histórico offline"])
        local close=CreateFrame("Button",nil,f,"UIPanelCloseButton"); close:SetPoint("TOPRIGHT"); close:SetScript("OnClick",function() f:Hide() end)
        f.select=CreateFrame("DropdownButton",nil,f,"WowStyle2DropdownTemplate"); f.select:SetPoint("TOPLEFT",20,-52); f.select:SetSize(550,26)
        f.select:SetupMenu(function(_,root)
            for _,entry in ipairs(self:OfflineChoices()) do
                root:CreateRadio(self:OfflineStorageName(entry.snapshot),function() return f.selected==entry.key end,
                    function() f.selected=entry.key; f.scroll:SetVerticalScroll(0); self:RefreshOfflineWindow() end)
            end
        end)
        f.search=CreateFrame("EditBox",nil,f,"InputBoxTemplate"); f.search:SetPoint("TOPLEFT",24,-94); f.search:SetSize(540,24); f.search:SetAutoFocus(false)
        f.search:SetMaxLetters(256); f.search:SetScript("OnEscapePressed",function(e) e:ClearFocus() end)
        f.search:SetScript("OnTextChanged",function() if f.scroll then f.scroll:SetVerticalScroll(0); self:RefreshOfflineWindow() end end)
        local hint=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); hint:SetPoint("TOPLEFT",20,-130); hint:SetText(self.L["Busca por nome ou filtros. Os registros representam sua última visita."])
        f.scroll=CreateFrame("ScrollFrame",nil,f,"UIPanelScrollFrameTemplate"); f.scroll:SetPoint("TOPLEFT",20,-157); f.scroll:SetPoint("BOTTOMRIGHT",-44,60)
        f.content=CreateFrame("Frame",nil,f.scroll); f.content:SetSize(532,320); f.scroll:SetScrollChild(f.content)
        f.scroll:HookScript("OnVerticalScroll",function() self:DrawOfflineItems() end)
        f.buttons={}; f.filtered={}
        f.status=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); f.status:SetPoint("BOTTOMLEFT",20,32); f.status:SetWidth(554); f.status:SetJustifyH("LEFT"); f.status:SetWordWrap(true)
        f.money=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall"); f.money:SetPoint("BOTTOMRIGHT",-20,12)
        f:SetScript("OnShow",function() self:RefreshOfflineWindow() end)
        f:SetScript("OnHide",function()
            self:ClearTable(f.filtered)
            for _,b in pairs(f.buttons) do
                if GameTooltip.IsOwned and GameTooltip:IsOwned(b) then GameTooltip:Hide() end
                b.item=nil; b:Hide()
            end
        end)
        UISpecialFrames[#UISpecialFrames+1]="BlockBagsOfflineWindow"
    end
    self:RefreshOfflineWindow(); f:Show()
end
