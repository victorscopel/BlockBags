local _, A = ...
A.itemCache = {}
A.loading = {}
A.itemRequests = {}

function A:AutomaticCategory(item)
    -- Group reagent-bag slots in their own category.
    if item.bag == Enum.BagIndex.ReagentBag then return "reagentbag" end
    local id = item.info.itemID
    local favorite = self.profile and self.profile.favorites and self.profile.favorites[id]
    local manual = self.profile and self.profile.manualCategories and self.profile.manualCategories[id]
    if favorite then return favorite.category end
    if manual then return manual end
    for _,cat in ipairs(self.categories) do
        local rule=self:GetLayout()[cat.id].rule
        if rule and rule~="" and self:MatchesQuery(item,rule) then return cat.id end
    end
    local q = item.quest
    if q and (q.isQuestItem or q.questID) then return "quest" end
    if item.classID == Enum.ItemClass.Weapon or item.classID == Enum.ItemClass.Armor then return "equipment" end
    if item.reagent or item.classID == Enum.ItemClass.Tradegoods then return "materials" end
    if item.classID == Enum.ItemClass.Consumable then return "consumables" end
    if item.info.quality == Enum.ItemQuality.Poor then return "junk" end
    return "misc"
end

function A:Classify(item)
    return self:VisibleCategory(self:AutomaticCategory(item))
end

function A:LoadMetadata(id)
    if self.itemCache[id] then return self.itemCache[id] end
    if self.loading[id] or self.itemRequests[id]=="failed" then return end
    local name, _, _, itemLevel, _, _, subtype, _, equipLoc, _, _, classID, subclassID, bindType, expansionID, _, reagent = C_Item.GetItemInfo(id)
    if name then
        local data = { name = name, classID = classID, subclassID = subclassID, reagent = reagent, itemLevel=itemLevel,
            subtype=subtype,equipLoc=equipLoc,bindType=bindType,expansionID=expansionID }
        self.itemCache[id] = data
        self.loading[id],self.itemRequests[id]=nil,nil
        return data
    end
    if not self.itemRequests[id] then
        self.itemRequests[id] = true
        self.loading[id] = true
        C_Item.RequestLoadItemDataByID(id)
    end
end

function A:ItemDataResult(id,success)
    if not self.itemRequests[id] then return end
    self.loading[id]=nil
    self.itemRequests[id]=success and "ready" or "failed"
    if success then self:QueueRefresh() end
    -- Retry missing metadata on inventory events, rather than on a timer.
end

function A:ScanInventory()
    self:RefreshEquipmentData()
    self.slotModels=self.slotModels or {}
    self.slotLocations=self.slotLocations or {}
    self.items=self.items or {}; self.emptySlots=self.emptySlots or {}
    self.occurrences=self.occurrences or {}; self.presentIDs=self.presentIDs or {}
    self:ClearTable(self.items); self:ClearTable(self.emptySlots)
    local occurrences=self:ClearTable(self.occurrences)
    local present=self:ClearTable(self.presentIDs)
    local items, free, reagentFree, total, reagentTotal = self.items, 0, 0, 0, 0
    -- Scan only the selected storage; bank containers are available while at the bank.
    for _,bag in ipairs(self:GetScannedBags()) do
        local count = C_Container.GetContainerNumSlots(bag)
        local empty,family = C_Container.GetContainerNumFreeSlots(bag)
        empty=empty or 0
        if bag == Enum.BagIndex.ReagentBag then
            reagentFree, reagentTotal = empty, count
        else
            free, total = free + empty, total + count
        end
        for slot = 1, count do
            local info = C_Container.GetContainerItemInfo(bag, slot)
            local slotKey = bag .. ":" .. slot
            local model=self.slotModels[slotKey]
            if not model then model={bag=bag,slot=slot,slotKey=slotKey}; self.slotModels[slotKey]=model end
            if info and info.itemID then
                local data = self:LoadMetadata(info.itemID)
                local location = self.slotLocations[slotKey]
                if not location then location=ItemLocation:CreateFromBagAndSlot(bag,slot); self.slotLocations[slotKey]=location end
                local guid = C_Item.GetItemGUID(location)
                local signature = info.hyperlink or tostring(info.itemID)
                occurrences[signature] = (occurrences[signature] or 0) + 1
                local identity = guid and ("guid:" .. guid) or ("link:" .. signature .. ":" .. occurrences[signature])
                local item=model
                item.identity,item.info=identity,info
                item.quest=C_Container.GetContainerItemQuestInfo(bag,slot)
                item.name,item.pending=data and data.name or "Carregando…",not data
                item.sortName=item.name:lower()
                item.classID,item.reagent=data and data.classID,data and data.reagent
                item.itemLevel=data and data.itemLevel
                if item.classID == Enum.ItemClass.Weapon or item.classID == Enum.ItemClass.Armor then
                    -- Use the instance level to include upgrades and bonus lists.
                    local level = C_Item.GetCurrentItemLevel and C_Item.GetCurrentItemLevel(location)
                    if not level and info.hyperlink and C_Item.GetDetailedItemLevelInfo then
                        level = C_Item.GetDetailedItemLevelInfo(info.hyperlink)
                    end
                    if type(level) == "number" then item.itemLevel = level end
                end
                self:EnrichItem(item,data,location)
                present[info.itemID]=true
                local target = self.pendingPlacements and self.pendingPlacements[slotKey]
                if target and target.itemID == info.itemID and target.category ~= "reagentbag" and bag ~= Enum.BagIndex.ReagentBag then
                    self.profile.manualCategories[info.itemID] = target.category
                    local favorite = self.profile.favorites[info.itemID]
                    if favorite then favorite.category, favorite.index = target.category, target.index end
                end
                -- Keep the previous category while metadata is loading.
                item.category = item.pending and not target and not self.profile.manualCategories[info.itemID] and self.lastCategories and self.lastCategories[identity] or nil
                item.category = item.category or self:Classify(item)
                item.category = self:VisibleCategory(item.category)
                items[#items + 1] = item
            else
                model.info,model.quest,model.identity,model.category,model.name,model.sortName=nil,nil,nil,nil,nil,nil
                model.family=family or 0
                self.emptySlots[#self.emptySlots + 1] = model
            end
        end
    end
    self.lastCategories = self:ClearTable(self.lastCategories or {})
    for _, item in ipairs(items) do self.lastCategories[item.identity] = item.category end
    -- Remove cached metadata for items no longer in this inventory.
    for id in pairs(self.itemCache) do if not present[id] then self.itemCache[id]=nil end end
    for id in pairs(self.itemRequests) do if not present[id] then self.itemRequests[id],self.loading[id]=nil,nil end end
    self.items = items
    self.capacity=self.capacity or {}
    self.capacity.free,self.capacity.total=free,total
    self.capacity.reagentFree,self.capacity.reagentTotal=reagentFree,reagentTotal
    self.invalidateTooltips=nil
end
