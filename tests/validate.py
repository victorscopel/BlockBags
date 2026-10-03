"""Offline Lua 5.1 syntax and core behaviour checks. Requires lupa (outside addon)."""
from pathlib import Path
import sys
from lupa.lua51 import LuaRuntime

root = Path(__file__).resolve().parents[1]
lua = LuaRuntime(unpack_returned_tuples=True)
lua.globals().TEST_LOCALE = sys.argv[1] if len(sys.argv)>1 else "ptBR"
compile_lua = lua.eval("function(source, name) local f,e = loadstring(source,name); assert(f,e); return f end")
sources = {}
for path in sorted(root.glob("*.lua")):
    sources[path.name] = compile_lua(path.read_text(encoding="utf-8"), str(path))
    print("Syntax OK:", path.name)

lua.execute('''
Enum = { BagIndex = { ReagentBag = 5 }, ItemQuality = { Poor = 0 },
    ItemClass = { Weapon = 2, Armor = 4, Tradegoods = 7, Consumable = 0 } }
CreateFrame = function() return { RegisterEvent = function() end, SetScript = function() end } end
SlashCmdList = {}
C_Timer = { After = function(_, fn) pending = fn end }
InCombatLockdown = function() return false end
CursorHasItem = function() return false end
UnitName = function() return "Tester" end
GetRealmName = function() return "Realm" end
GetLocale = function() return TEST_LOCALE end
A = {}
''')
addon = lua.globals().A
for name in ["Locale.lua", "Core.lua", "Query.lua", "Views.lua", "Storage.lua", "ItemFeatures.lua", "BulkActions.lua", "Inventory.lua", "Placement.lua", "Features.lua", "Profiles.lua", "Interaction.lua", "BankAccess.lua", "BankTools.lua", "BankWindow.lua", "Integration.lua", "BagTools.lua", "FeatureSettings.lua"]:
    sources[name]("BlockBags", addon)
lua.execute('''
A:InitializeDatabase()
A.canvasWidth, A.canvasHeight = 880, 600
local function item(id, name, cat)
    return { identity=id, name=name, category=cat or "equipment", slotKey=id,
        pending=false, info={itemID=1} }
end
local one, two, three = item("1", "Alpha"), item("2", "Beta"), item("3", "Gamma")
A.items = { one, two, three }; A:Reconcile()
assert(A.profile.placements.equipment["2"] == 2)
A.items = { two, three }; A:Reconcile()
assert(A.groups.equipment.positions[1] == nil)
assert(A.profile.placements.equipment["2"] == 2)
local four = item("4", "Delta")
A.items = { two, three, four }; A:Reconcile()
assert(A.profile.placements.equipment["4"] == 1)
-- Physical bag/slot changes do not change an instance's visual position.
two.slotKey = "5:8"; A:Reconcile()
assert(A.profile.placements.equipment["2"] == 2)
A.items = { two, three }; A.organizeCategory = "equipment"; A:Reconcile()
assert(A.profile.placements.equipment["2"] == 1)
assert(not A.profile.layout.equipment.compact)
A.profile.layout.equipment.compact = true
A.items = { four, three }; A:Reconcile()
assert(A.profile.placements.equipment["4"] == 1)
assert(A.profile.placements.equipment["3"] == 2)
-- A compact category never compacts a fixed neighbour.
local quest = item("q", "Quest", "quest")
A.profile.placements.quest = { q=8 }
A.items = { four, quest }; A:Reconcile()
assert(A.profile.placements.quest.q == 8)
-- Empty panels retain their configured geometry.
local original = A:Copy(A.profile.layout.misc)
A.items = {}; A:Reconcile()
assert(A.profile.layout.misc.rows == original.rows)
assert(A.groups.misc.max == 0)
-- All default panels fit and do not overlap.
for id, layout in pairs(A.profile.layout) do assert(A:CanPlace(id, layout), id) end
local candidate = A:Copy(A.profile.layout.equipment)
candidate.x = A.profile.layout.consumables.x
assert(not A:CanPlace("equipment", candidate))
candidate.x = 50
assert(not A:CanPlace("equipment", candidate))
candidate.x = -1
assert(not A:CanPlace("equipment", candidate))
-- Category precedence, including reagent bag and quest overrides.
assert(A:Classify({quest={isQuestItem=true},bag=5,classID=4,info={quality=0}}) == "reagentbag")
assert(A:Classify({bag=5,classID=7,info={quality=1}}) == "reagentbag")
assert(A:Classify({bag=0,classID=7,info={quality=1}}) == "materials")
assert(A:Classify({bag=0,classID=0,info={quality=1}}) == "consumables")
assert(A:Classify({bag=0,classID=15,info={quality=0}}) == "junk")
-- Editor draft does not mutate the saved layout until accepted.
A.draft = A:Copy(A.profile.layout)
A.draft.equipment.cols = 3
assert(A.profile.layout.equipment.cols == 8)
A.draft = nil
-- Nested native hooks coalesce to one toggle.
A.ready = true
local shown = false
A.window = { IsShown=function() return shown end, SetShown=function(_,v) shown=v end,
    Show=function() shown=true end, Hide=function() shown=false end }
A:RequestWindow("open"); A:RequestWindow("toggle"); pending()
assert(shown)
A:RequestWindow("close"); A:RequestWindow("toggle"); pending()
assert(not shown)
print("Behaviour OK: fixed positions, hole reuse, compact/manual sort, category isolation, geometry, classification, draft and hooks")
''')

toc = (root / "BlockBags.toc").read_text(encoding="utf-8")
for line in toc.splitlines():
    if line and not line.startswith("#"):
        assert (root / line).is_file(), line
print("TOC references OK")

lua.execute('''
-- Minimal frame model exercises our UI paths, not Blizzard's native handlers.
local methods = {}
local mt = { __index = function(_, key) return methods[key] or function() end end }
createdFrames=0
function CreateFrame(kind, name, parent, template)
    createdFrames=createdFrames+1
    return setmetatable({ kind=kind, name=name, parent=parent, template=template, shown=true, text="", value=0,
        minimum=0, maximum=0, scripts={}, children={}, Low=false, High=false, Text=false, IconQuestTexture=false }, mt)
end
UIParent = CreateFrame("Frame")
UISpecialFrames = {}
STANDARD_TEXT_FONT = "font"
function methods:CreateFontString() return CreateFrame("FontString",nil,self) end
function methods:CreateTexture() return CreateFrame("Texture",nil,self) end
function methods:SetScript(key, fn) self.scripts[key]=fn end
function methods:HookScript(key, fn) self.scripts[key]=fn end
function methods:GetScript(key) return self.scripts[key] end
function methods:Init(kind,bag,slot) self.bankType=kind; self.bankTabID=bag; self.containerSlotID=slot end
function methods:GetBankTabID() return self.bankTabID end
function methods:GetContainerSlotID() return self.containerSlotID end
function methods:SetAttribute(key,value)
    self.attributes=rawget(self,"attributes") or {}; self.attributes[key]=value
end
function methods:GetAttribute(key) local attributes=rawget(self,"attributes"); return attributes and attributes[key] end
function methods:GetParent() return rawget(self,"parent") end
function methods:SetText(text) self.text=text end
function methods:GetText() return self.text end
function methods:SetChecked(value) self.checked=not not value end
function methods:GetChecked() return rawget(self,"checked") or false end
function methods:SetEnabled(value) self.enabled=not not value end
function methods:IsEnabled() return rawget(self,"enabled")~=false end
function methods:SetShown(shown) self.shown=shown end
function methods:Show() self.shown=true end
function methods:Hide() self.shown=false end
function methods:IsShown() return self.shown end
function methods:SetParent(parent) self.parent=parent end
function methods:SetSize(w,h) self.width=w; self.height=h end
function methods:SetWidth(w) self.width=w end
function methods:SetHeight(h) self.height=h end
function methods:GetFrameLevel() return rawget(self,"level") or 1 end
function methods:SetFrameLevel(value) self.level=value end
function methods:SetFrameStrata(value) self.strata=value end
function methods:GetFrameStrata() return rawget(self,"strata") or "MEDIUM" end
function methods:SetResizable(value) self.resizable=value end
function methods:GetWidth() return self.width or 912 end
function methods:GetHeight() return self.height or 716 end
function methods:GetValue() return self.value end
function methods:GetEffectiveScale() return 1 end
function methods:SetMinMaxValues(a,b) self.minimum=a; self.maximum=b end
function methods:GetMinMaxValues() return self.minimum,self.maximum end
function methods:SetValue(value)
    self.value=value
    if self.scripts.OnValueChanged then self.scripts.OnValueChanged(self,value) end
end
function methods:Initialize(bag,slot) self.bag=bag; self.slot=slot; self:Show() end
function methods:EnableMouse(enabled) self.mouse=enabled end
function methods:SetMouseClickEnabled(enabled) self.mouseClick=enabled end
C_NewItems = { IsNewItem=function() return false end, RemoveNewItem=function() end }
C_Container = { GetContainerNumFreeSlots=function() return 2,0 end }
SetItemButtonTexture=function() end
SetItemButtonCount=function() end
SetItemButtonQuality=function() end
SetItemButtonDesaturated=function() end
GetCoinTextureString=function() return "money" end
GetMoney=function() return 0 end
''')
sources["Theme.lua"]("BlockBags", addon)
sources["UI.lua"]("BlockBags", addon)
sources["Editor.lua"]("BlockBags", addon)
lua.execute('''
Settings = { RegisterCanvasLayoutCategory=function() return {GetID=function() return 1 end} end,
    RegisterCanvasLayoutSubcategory=function() return {GetID=function() return 2 end} end,
    RegisterAddOnCategory=function() end, OpenToCategory=function(id) openedSettings=id end }
SettingsPanel=CreateFrame("Frame")
GameMenuFrame=CreateFrame("Frame"); GameMenuFrame:Hide()
HideUIPanel=function(frame) frame:Hide() end
SettingsPanel.TransitionBackOpeningPanel=function(panel)
    panel:Hide()
    if panel.scripts.OnHide then panel.scripts.OnHide() end
    GameMenuFrame:Show()
end
hooksecurefunc=function(object,method,callback)
    local original=object[method]
    object[method]=function(...)
        original(...)
        callback(...)
    end
end
StaticPopupDialogs={}; YES="Yes"; CANCEL="Cancel"
ColorPickerFrame={SetupColorPickerAndShow=function(_,info) pickerInfo=info end,
    GetColorRGB=function() return 85/255,170/255,1 end}
''')
sources["Settings.lua"]("BlockBags", addon)
lua.execute('''
A:BuildUI(); A.window:Show()
A.items = {{identity="ui", name="Poção", category="consumables", slotKey="0:1",bag=0,slot=1,
    info={itemID=1,quality=1,stackCount=3,iconFileID=1},quest={}}}
A.emptySlots = {{bag=0,slot=2,slotKey="0:2",family=0},{bag=5,slot=1,slotKey="5:1",family=0}}
A.capacity = {free=2,total=32,reagentFree=1,reagentTotal=36}
A:Reconcile(); A:Render()
assert(A.buttons["0:1"]:IsShown())
assert(A.buttons["0:2"]:IsShown() and A.buttons["5:1"]:IsShown())
assert(A.buttons["0:2"].emptyAnchor and A.buttons["5:1"].emptyAnchor)
assert(not A.window.resizable and not A.windowResize:IsShown())
A.search:SetText("inexistente"); A:Render()
assert(A.panels.consumables.count:GetText() == "0/1")
A:StartEdit()
assert(A.window.resizable and A.windowResize:IsShown())
assert(not A.buttons["0:2"].mouse and not A.buttons["5:1"].mouse)
assert(not A.buttons["0:1"].mouse)
A.draft.consumables.compact = true
A:FinishEdit(false)
assert(not A.profile.layout.consumables.compact)
assert(A.buttons["0:2"].mouse)
A:StartEdit(); A.draft.consumables.compact=true; A:FinishEdit(true)
assert(A.profile.layout.consumables.compact)
A:StartEdit()
A:OpenCustomization("consumables")
A.settingsControls.size:SetValue(48)
A.settingsControls.spacing:SetValue(8)
assert(A.draft.consumables.itemSize == 48 and A.draft.consumables.itemSpacing == 8)
assert(A.buttons["0:1"].width == 48)
assert(A.profile.layout.consumables.itemSize == 36)
A:ChooseCategoryColor("consumables"); pickerInfo.swatchFunc()
assert(math.abs(A.draft.consumables.tint.r - 85/255) < 0.001)
A:OpenGeneralSettings()
A.settingsControls.generalSpacing:SetValue(12)
assert(A.draftSettings.categorySpacing == 12 and A.profile.settings.categorySpacing == 0)
A.window:SetSize(1000,800)
A:FinishEdit(false)
assert(A.window:GetWidth()>=912 and A.window:GetHeight()==716)
assert(A.profile.layout.consumables.itemSize==36 and not A.profile.layout.consumables.tint)
assert(A:GetSettings().categorySpacing==0)
A:StartEdit(); A:OpenCustomization("consumables"); A.settingsControls.size:SetValue(44)
A.settingsControls.spacing:SetValue(2)
A:OpenGeneralSettings(); A.settingsControls.generalSpacing:SetValue(8)
A.window:SetSize(1000,800)
A:FinishEdit(true)
assert(A.profile.window.width==1000 and A.profile.window.height==800)
assert(A.profile.layout.consumables.itemSize==44 and A.profile.layout.consumables.itemSpacing==2)
assert(A:GetSettings().categorySpacing==8)
assert(not A.window.resizable and not A.windowResize:IsShown())
-- Exact geometry stays disjoint: items never enter the scrollbar gutter.
for size=24,56,2 do
    for spacing=0,12 do
        local data=A:Copy(A.profile.layout.consumables)
        data.itemSize,data.itemSpacing=size,spacing
        local m=A:ItemMetrics(data)
        local _,_,width=A:PanelRect(data)
        assert((m.cols-1)*m.step+m.size<=m.width)
        assert(A.padding+m.width <= width-A.padding)
        assert(A.panels.consumables.bar.width<=A.padding)
    end
end
-- Reagent occupancy is occupied/total and full capacity is visually red.
A.capacity.reagentTotal,A.capacity.reagentFree=38,38
A:Render(); assert(A.panels.reagentbag.count:GetText()=="0/38")
A.capacity.reagentFree=0
A:Render(); assert(A.panels.reagentbag.count:GetText()=="38/38")
print("Customization OK: size, spacing, native tint, general gap, editor-only resize, atomic save/cancel, gutter, reagent occupancy")
A.window:SetSize(560,400); A:ResizeCanvas()
assert(not A.windowScrollX:IsShown() and not A.windowScrollY:IsShown())
local maxX,maxY=0,0
for _,data in pairs(A:GetLayout()) do local x,y,w,h=A:PanelRect(data); maxX=math.max(maxX,x+w); maxY=math.max(maxY,y+h) end
assert(A.window:GetWidth()>=maxX+40 and A.window:GetHeight()>=maxY+124)
assert(A.profile.layout.equipment.x == 0 and A.profile.layout.equipment.cols == 8)
-- Every free physical slot occurs exactly once, including overflow and specialty bags.
A.emptySlots = {}
for n=1,220 do A.emptySlots[#A.emptySlots+1]={bag=0,slot=n,slotKey="empty:"..n,family=0} end
for n=1,40 do A.emptySlots[#A.emptySlots+1]={bag=5,slot=n,slotKey="reagent:"..n,family=0} end
A.emptySlots[#A.emptySlots+1]={bag=4,slot=1,slotKey="special",family=32}
A:AssignEmptySlots()
local counted,seen=0,{}
for category,entries in pairs(A.emptyPositions) do
    for _,slot in pairs(entries) do
        assert(not seen[slot.slotKey]); seen[slot.slotKey]=true; counted=counted+1
        if slot.bag==5 then assert(category=="reagentbag") end
    end
end
assert(counted==261)
assert(A.displayMax.misc > A.profile.layout.misc.cols*A.profile.layout.misc.rows)
-- Native empty-slot drops keep the target index when classification agrees.
A.profile.layout.consumables.compact=false
A.pendingPlacements={["0:1"]={category="consumables",index=7}}
A:Reconcile()
assert(A.profile.placements.consumables.ui==7)
print("UI smoke OK: native empty slots, no duplicates, reagent isolation, overflow, drop placement, resize, search, editor")
-- Favorites reserve their slot even when absent and survive automatic sorting.
local potion=A.items[1]
potion.classID=Enum.ItemClass.Consumable
A:ToggleFavorite(potion)
local pinned=A.profile.favorites[1].index
local other={identity="other",name="Potion",category="consumables",slotKey="0:3",bag=0,slot=3,classID=0,
    info={itemID=2,quality=1,stackCount=1,iconFileID=2},quest={}}
A.items={potion,other}; A.profile.layout.consumables.compact=true; A:Reconcile()
assert(A.profile.placements.consumables[potion.identity]==pinned)
A.items={other}; A:Reconcile(); A:AssignEmptySlots()
assert(A.groups.consumables.reserved[pinned]==1)
assert(not A.emptyPositions.consumables[pinned])
A.items={potion,other}; A:Reconcile()
assert(A.profile.placements.consumables[potion.identity]==pinned)
A:SetManualCategory(potion,"misc")
assert(potion.category=="misc" and A:GetStackCategories()[potion.identity]=="misc")
assert(A.profile.favorites[1].category=="misc")
A:RemoveFavorite(1); A:SetManualCategory(potion,nil)
assert(potion.category=="consumables" and not A:GetStackCategories()[potion.identity])
-- Numeric settings and undo preserve the editor draft.
A:StartEdit()
local before=A:GetSettings().categorySpacing
A:OpenGeneralSettings(); A.settingsControls.generalSpacing:SetValue(4)
A:UndoEdit(); assert(A:GetSettings().categorySpacing==before)
A:FinishEdit(false)
-- Search navigation reaches hidden matches inside a category without moving panels.
A.profile.layout.consumables.compact=false
A.profile.placements.consumables[potion.identity]=70
A:Reconcile(); A.search:SetText("po"); A.searchResultIndex=0; A:Render()
assert(#A:CollectSearchResults("po")==2)
A:NavigateSearch(1); A:NavigateSearch(1)
assert(A.panels.consumables.offset>0 and A.focusedSearchIdentity==potion.identity)
assert(A.generalButton.level>A.panels.consumables:GetFrameLevel())
assert(not A.windowScrollX:IsShown() and not A.windowScrollY:IsShown())
print("Features OK: absent favorites, pinned sorting, manual categories, undo, search navigation")
-- Regression: hide ALL six standard frames, not only the five equipped bags.
C_AddOns = {IsAddOnLoaded=function() return false end}
NUM_TOTAL_BAG_FRAMES=5; NUM_CONTAINER_FRAMES=6
ContainerFrameCombinedBags=CreateFrame("Frame")
for n=1,6 do _G["ContainerFrame"..n]=CreateFrame("Frame") end
A:InstallIntegration()
for n=1,6 do assert(_G["ContainerFrame"..n].parent==A.hiddenBags) end
assert(ContainerFrameCombinedBags.parent==A.hiddenBags)
print("Integration OK: backpack + four bags + reagent bag hidden")
-- Rename migration copies once, leaves legacy data intact and never overwrites new data.
local currentDB=BlockBagsDB
BlockBagsDB=nil
AnchorBagsDB={profiles={["Tester-Realm"]={layout=A:DefaultLayout(),settings={categorySpacing=5},window={scale=0.85}}}}
local legacy=AnchorBagsDB
A:InitializeDatabase()
assert(BlockBagsDB~=legacy and BlockBagsDB.migratedFromAnchorBags)
assert(A:GetSettings().categorySpacing==5)
A.profile.settings.categorySpacing=7
assert(legacy.profiles["Tester-Realm"].settings.categorySpacing==5)
A:InitializeDatabase(); assert(A:GetSettings().categorySpacing==7)
print("Migration OK: legacy data preserved, deep copy once, existing new DB retained")
''')

lua.execute('''
-- Real profile management, native Settings integration, export validation and drops.
C_Container.GetContainerNumSlots=function(bag) return bag==0 and 1 or 0 end
C_Container.GetContainerNumFreeSlots=function() return 0,0 end
C_Container.GetContainerItemInfo=function(bag,slot)
    if bag==0 and slot==1 then return {itemID=101,quality=2,stackCount=1,iconFileID=1} end
end
C_Container.GetContainerItemQuestInfo=function() return {} end
C_Item={GetItemGUID=function() return "sword" end}
ItemLocation={CreateFromBagAndSlot=function() return {} end}
A.itemCache[101]={name="Sword",classID=Enum.ItemClass.Weapon}
A:ScanInventory(); A:Reconcile(); A:Render()
local original=A.profileKey
assert(A:CreateProfile("Shared",true))
assert(BlockBagsDB.characterProfiles[A.characterKey]=="Shared")
assert(A.profile~=BlockBagsDB.profiles[original])
A.profile.settings.categorySpacing=2
assert(BlockBagsDB.profiles[original].settings.categorySpacing==7)
A:RenameProfile("Shared renamed")
assert(A.profileKey=="Shared renamed" and not BlockBagsDB.profiles.Shared)
assert(not A:DeleteProfile("Shared renamed"))
local cat=A:CreateCategory("Tools")
assert(cat and A.groups[cat] and A.panels[cat])
local sword=A.items[1]
assert(sword.category=="equipment")
A:SetManualCategory(sword,cat)
assert(sword.category==cat)
A:SetCategoryOption(cat,"hidden",true)
assert(sword.category=="misc" and not A.panels[cat]:IsShown())
A:SetCategoryOption(cat,"hidden",false)
assert(sword.category==cat and A.panels[cat]:IsShown())
A:StartEdit(); A:SetCategoryOption(cat,"hidden",true)
A:UndoEdit(); assert(not A:GetLayout()[cat].hidden and sword.category==cat)
A:SetCategoryOption(cat,"hidden",true); A:FinishEdit(false)
assert(not A:GetLayout()[cat].hidden and sword.category==cat)
A:SetCategoryOption(cat,"name","Personal tools")
assert(A:CategoryName(cat)=="Personal tools")
A:ToggleFavorite(sword)
local export=A:ExportProfile()
local decoded,err=A:DecodeProfile(export)
assert(decoded,err)
assert(decoded.layout[cat].name=="Personal tools" and not decoded.favorites[101].identity)
assert(decoded.manualCategories[101]==nil and next(decoded.placements)==nil)
assert(not A:DecodeProfile(export:sub(1,-7)))
assert(not A:DecodeProfile("BB1:0000"))
local overlapping=A:Copy(A.profile.layout[cat])
A.profile.layout[cat].x,A.profile.layout[cat].y=0,0
local bad=A:ExportProfile()
A.profile.layout[cat]=overlapping
assert(not A:DecodeProfile(bad))
assert(not A:ImportProfile("Shared renamed",export))
assert(A:ImportProfile("Imported",export))
assert(A.profile.layout[cat].name=="Personal tools" and A.items[1].category==cat)
assert(A:DeleteProfile("Shared renamed"))
-- Drops keep a manual rule only when the scanned physical destination contains the source ID.
A:RemoveFavorite(101); A:SetManualCategory(A.items[1],nil)
GetCursorInfo=function() return "item",101 end
A:RememberDrop({anchorCategory="misc",anchorIndex=5,anchorSlotKey="0:1"})
A:ScanInventory(); A:Reconcile(); A:Render()
assert(A:GetStackCategories()[A.items[1].identity]=="misc" and A.items[1].category=="misc")
assert(A.profile.placements.misc[A.items[1].identity]==5)
A:RememberDrop({anchorCategory=cat,anchorIndex=3,anchorSlotKey="0:1"})
A.pendingPlacements["0:1"].itemID=999 -- rejected/incompatible physical drop
A:ScanInventory(); A:Reconcile()
assert(A.items[1].category=="misc")
-- Color picker cancellation restores the previous tint. No popup settings dialogs exist.
A:OpenCustomization(cat)
assert(openedSettings==A.settingsIDs.categories and not A.customization)
local previous=A:Copy(A:GetLayout()[cat].tint)
A:ChooseCategoryColor(cat); pickerInfo.swatchFunc()
assert(A:GetLayout()[cat].tint.b==1)
pickerInfo.cancelFunc(); assert(A:GetLayout()[cat].tint==nil and previous==nil)
-- No permanent gutter; showing the border scrollbar never changes columns.
A:GetDropSlots()[A.items[1].identity]=nil
A.profile.placements.misc[A.items[1].identity]=500
A:Reconcile(); A:Render()
local beforeCols=A.panels.misc.currentMetrics.cols
assert(A.panels.misc.bar:IsShown())
A.profile.placements.misc[A.items[1].identity]=1
A:Reconcile(); A:Render()
assert(A.panels.misc.currentMetrics.cols==beforeCols)
-- No permanent scrollbar gutter in a category that fits all items.
A:Render()
local panel=A.panels.equipment
assert(not panel.bar:IsShown())
assert(panel.currentMetrics.width==A.profile.layout.equipment.cols*A.cell)
-- Profiles cannot change under an unsaved editor draft.
A:StartEdit(); assert(not A:SelectProfile(original)); A:FinishEdit(false)
assert(A:SelectProfile(original))
assert(A.profileKey==original)
-- Shared appearance never shares instance placements between characters.
local character=A.characterKey
local firstPositions=A.profile.placements
BlockBagsDB.characterProfiles["Other-Realm"]=original
UnitName=function() return "Other" end
A:InitializeDatabase()
assert(A.profileKey==original and A.profile.placements~=firstPositions)
A.profile.placements.misc={other=9}
UnitName=function() return "Tester" end
A:InitializeDatabase()
assert(A.profile.placements==firstPositions and A.characterKey==character)
print("Settings/profiles OK: shared selection, clone/rename/delete, legacy profiles, safe code roundtrip, overlap/corruption rejection, custom/hide/rename categories, undo/cancel, persistent drops, native color cancel, border scrollbar without grid reflow")
''')

lua.execute('''
-- Stress checks: repeated UI use cannot keep creating frames or timer chains.
A.window:Show(); A.search:SetText("")
A.itemCache[101]={name="Sword",classID=Enum.ItemClass.Weapon}
A:ScanInventory(); A:Reconcile(); A:Render()
local sword=A.items[1]
A:OpenItemActions(sword); A:OpenFavorites(); A:OpenSettings()
local frames=createdFrames
collectgarbage("collect")
local baseline=collectgarbage("count")
for n=1,150 do
    A:OpenItemActions(sword)
    A.itemActions:Hide(); A.itemActions.scripts.OnHide()
    assert(rawget(A.itemActions,"item")==nil)
    A:OpenFavorites()
    A.favoriteDialog:Hide(); A.favoriteDialog.scripts.OnHide()
    assert(rawget(A.favoriteDialog,"entries")==nil)
    A:OpenCustomization("equipment")
    A:Render()
end
collectgarbage("collect")
assert(createdFrames==frames,"Repeated use created permanent frames")
assert(collectgarbage("count")-baseline<128,"Retained Lua data grows with repeated use")
-- Explicit events coalesce; closed inventory schedules no work.
local jobs={}
C_Timer.After=function(_,fn) jobs[#jobs+1]=fn end
A.refreshQueued=false; A.window:Hide()
for n=1,100 do A:QueueRefresh() end
assert(#jobs==0 and A.inventoryDirty)
A.window:Show()
for n=1,100 do A:QueueRefresh() end
assert(#jobs==1)
jobs[1](); assert(not A.refreshQueued and not A.inventoryDirty and #jobs==1)
-- Native Settings closing special windows cannot discard the layout editor.
Settings.OpenToCategory=function()
    for _,name in ipairs(UISpecialFrames) do if name=="BlockBagsWindow" then A.window:Hide() end end
    A:RequestWindow("close")
end
A:StartEdit()
for n=1,30 do A:OpenCustomization("equipment"); assert(A.window:IsShown() and A.draft) end
SettingsPanel:Hide(); SettingsPanel.scripts.OnHide()
for i=2,#jobs do jobs[i]() end
A:FinishEdit(false)
local registrations=0
for _,name in ipairs(UISpecialFrames) do if name=="BlockBagsWindow" then registrations=registrations+1 end end
assert(registrations==1)
-- Spacing means actual adjacent borders, not shrinking item panels.
for gap=0,16 do
    local layout={a={x=0,y=0,cols=3,rows=4},b={x=5,y=0,cols=4,rows=3},c={x=0,y=8,cols=3,rows=2}}
    A:PackLayout(layout,gap)
    local ax,ay,aw,ah=A:PanelRect(layout.a)
    local bx,by=A:PanelRect(layout.b)
    local cx,cy=A:PanelRect(layout.c)
    assert(math.abs(bx-ax-aw-gap)<0.00001)
    assert(math.abs(cy-ay-ah-gap)<0.00001)
    local copy=A:Copy(layout); A:PackLayout(layout,gap)
    assert(layout.a.x==copy.a.x and layout.c.y==copy.c.y)
end
print("Stress OK: 150 repeated dialog/options/render cycles create zero new frames; retained Lua growth <128KB; 100 updates coalesce; hidden inventory schedules no timer; Settings preserves editor; real spacing 0-16 verified")
''')

lua.execute('''
-- Failed item loads must not create callbacks or an endless refresh/request loop.
local requests=0
local getInfo=C_Item.GetItemInfo
C_Item.GetItemInfo=function() return nil end
C_Item.RequestLoadItemDataByID=function() requests=requests+1 end
for n=1,50 do assert(A:LoadMetadata(999)==nil) end
assert(requests==1 and A.loading[999])
A:ItemDataResult(999,false)
for n=1,50 do A:LoadMetadata(999) end
assert(requests==1 and not A.loading[999])
C_Item.GetItemInfo=getInfo
A:ScanInventory()
assert(not A.itemRequests[999])
-- Panel frames are reused even across profiles with different category IDs.
local key=A.profileKey
local source=A:Copy(A.profile)
source.categories[#source.categories+1]={id="otherCustom",name="Other custom",x=0,y=30,cols=4,rows=2}
source.layout.otherCustom={x=0,y=30,cols=4,rows=2,itemSize=36,itemSpacing=4}
source.spacingLayoutVersion=1
BlockBagsDB.profiles["Stress profile"]=source
for n=1,20 do A:SelectProfile("Stress profile"); A:SelectProfile(key) end
local frames=createdFrames
for n=1,50 do A:SelectProfile("Stress profile"); A:SelectProfile(key) end
assert(createdFrames==frames,"Profile changes leaked panel frames")
print("Load/pool OK: 100 failed metadata queries issue one request; changing profiles 100 times creates zero new frames after warmup")
''')

lua.execute('''
-- Pixel dimensions allow leftover space and survive geometry/export validation.
A.window:Show(); A:StartEdit()
local d=A.draft.equipment
local _,_,w,h=A:PanelRect(d)
d.width,d.height=w+7,h+13
local m=A:ItemMetrics(d)
assert(m.width==w+7-2*A.padding and m.height==h+13-A.header-2*A.padding)
assert((m.cols-1)*m.step+m.size<=m.width)
A:FinishEdit(true)
local decoded,err=A:DecodeProfile(A:ExportProfile())
-- Test in isolation because expanding adjacent panels can overlap.
A.profile.layout.equipment.width=w-7
A.profile.layout.equipment.height=h-13
local decoded,err=A:DecodeProfile(A:ExportProfile()); assert(decoded,err)
assert(decoded.layout.equipment.width==w-7 and decoded.layout.equipment.height==h-13)
-- Snap is proximity-based, not a hard boundary. Continuing past it releases it.
A:StartEdit()
local save=A.draft
A.draft={a={x=0,y=0,cols=3,rows=3,width=136,height=172},b={x=5,y=0,cols=3,rows=3,width=136,height=172}}
A.draftSettings.categorySpacing=5
local candidate={x=59/40,y=0,cols=3,rows=3,width=136,height=172}
A:SnapPanel("a",candidate)
assert(candidate.x==59/40) -- 5px gap before panel b
candidate.x=40/40; A:SnapPanel("a",candidate)
assert(candidate.x==1) -- outside the magnetic range: remains free
local resize={x=0,y=0,cols=3,rows=3,width=190,height=172}
A:SnapResize("a",resize); assert(resize.width==195)
resize.width=240; A:SnapResize("a",resize); assert(resize.width==240)
-- Actual resize updates in single pixels; Shift bypasses proximity snapping.
local cx,cy=0,0
GetCursorPosition=function() return cx,cy end
IsShiftKeyDown=function() return true end
local panel=A.panels.equipment
panel.id="a"
A:BeginPanelDrag(panel,true); cx=7; cy=-11; panel.scripts.OnUpdate()
assert(panel.drag.candidate.width==143 and panel.drag.candidate.height==183)
panel:SetScript("OnUpdate",nil); panel.drag=nil; panel.id="equipment"
A.draft=save; A:FinishEdit(false)
print("Free sizing OK: pixel dimensions, unused inner space, code roundtrip, proximity snap releases beyond threshold, Shift bypass, resize responds to 1px increments")
''')

lua.execute('''
-- Numeric dimensions remain draft-only and reject overlap without damaging the profile.
local d=A.profile.layout.equipment
local _,_,width,height=A:PanelRect(d)
A:StartEdit(); A:OpenCustomization("equipment")
A.settingsControls.width:SetValue(width-5)
A.settingsControls.height:SetValue(height-5)
assert(A.draft.equipment.width==width-5 and A.draft.equipment.height==height-5)
assert(A.profile.layout.equipment.width==width)
A.settingsControls.width:SetValue(12000)
assert(A.draft.equipment.width==width-5)
A:UndoEdit(); assert(A.draft.equipment.height==height)
A:FinishEdit(false)
-- Visuals are bounded and reused across mouse updates.
local candidate=A:Copy(A.profile.layout.equipment)
A:UpdateEditorVisuals("equipment",candidate,true,true,false)
assert(A.editorVisuals:IsShown() and A.editorVisuals.preview:IsShown())
assert(A.editorVisuals.preview.caption:GetText():find("slots"))
local count=createdFrames
for n=1,100 do A:UpdateEditorVisuals("equipment",candidate,true,true,false) end
assert(createdFrames==count and #A.editorVisuals.preview.lines<=130)
A:HideEditorVisuals(); assert(not A.editorVisuals:IsShown())
-- Only user-created categories may be deleted. Cleanup preserves the items/favorites.
assert(not A:DeleteCategory("equipment"))
A.window:Show()
local id=A:CreateCategory("Delete test")
local sword=A.items[1]
A:SetManualCategory(sword,id); A:ToggleFavorite(sword)
assert(A.profile.favorites[101].category==id)
assert(A:DeleteCategory(id))
assert(not A.profile.layout[id] and not A.profile.manualCategories[101])
assert(A.profile.favorites[101] and A.profile.favorites[101].category~=id)
assert(A.items[1].category~=id)
local parsed,err=A:DecodeProfile(A:ExportProfile()); assert(parsed,err)
print("Editor enhancements OK: numeric draft dimensions, overlap rejection, undo/cancel, bounded reusable guide/grid visuals, built-in category protection, custom deletion with rule/favorite cleanup and valid export")
''')

lua.execute('''
-- Wider, stable, collision-aware magnetic snapping and edit-only background grid.
A.window:Show(); A:StartEdit()
local saved=A.draft
A.draft={a={x=0,y=0,cols=3,rows=3,width=136,height=172},b={x=5,y=0,cols=3,rows=3,width=136,height=172}}
A.draftSettings.categorySpacing=5
local state={}
local candidate={x=72/40,y=0,cols=3,rows=3,width=136,height=172}
A:SnapPanel("a",candidate,state)
assert(math.abs(candidate.x*40-59)<0.00001 and A:CanPlace("a",candidate))
-- Move 25px off the original captured edge: it stays held inside release band.
candidate.x=84/40; A:SnapPanel("a",candidate,state)
assert(candidate.x==59/40)
-- Move out of the capture/release bands toward open space: follows cursor again.
candidate.x=25/40; A:SnapPanel("a",candidate,state)
assert(candidate.x==25/40)
-- Distant categories cannot attract either coordinate just by sharing an axis.
A.draft.b.y=20
candidate.x=59/40; candidate.y=2
A:SnapPanel("a",candidate,{})
assert(candidate.x==59/40 and candidate.y==2)
A.draft=saved
A:UpdateEditorGrid()
assert(A.editorGrid:IsShown() and #A.editorGrid.lines<=258)
local frames=createdFrames
for n=1,100 do A:UpdateEditorGrid() end
assert(createdFrames==frames)
A:FinishEdit(false); assert(not A.editorGrid:IsShown())
print("Magnet/grid OK: 18px capture, 30px release, valid collision-free target, nearby panels only, reusable bounded grid visible only while editing")
''')

lua.execute('''
-- Category transfers must reuse physical models/buttons and avoid native repaint
-- of unchanged items. Real physical swaps still invalidate the relevant fields.
A.window:Show(); A.search:SetText("")
A.profile.favorites={}; A.profile.manualCategories={}
A.slotLocations={}
local slots={101,102}
local locations=0
ItemLocation.CreateFromBagAndSlot=function(_,bag,slot)
    locations=locations+1; return {bag=bag,slot=slot}
end
C_Item.GetItemGUID=function(location) return "movement-"..slots[location.slot] end
C_Container.GetContainerNumSlots=function(bag) return bag==0 and 2 or 0 end
C_Container.GetContainerNumFreeSlots=function() return 0,0 end
C_Container.GetContainerItemInfo=function(bag,slot)
    if bag==0 and slots[slot] then
        return {itemID=slots[slot],quality=2,stackCount=1,iconFileID=slots[slot]}
    end
end
A.itemCache[101]={name="Sword",classID=Enum.ItemClass.Weapon}
A.itemCache[102]={name="Second sword",classID=Enum.ItemClass.Weapon}
A:ScanInventory(); A:Reconcile(); A:Render()
local items,empties,capacity=A.items,A.emptySlots,A.capacity
local model=A.items[1]
local groups,positions=A.groups,A.groups.equipment.positions
local textures,shows,hides=0,0,0
local originalTexture=SetItemButtonTexture
SetItemButtonTexture=function(...) textures=textures+1; originalTexture(...) end
for _,key in ipairs({"0:1","0:2"}) do
    local b=A.buttons[key]
    local show,hide=b.Show,b.Hide
    b.Show=function(...) shows=shows+1; show(...) end
    b.Hide=function(...) hides=hides+1; hide(...) end
end
-- Warm up each category's bag parent once, then count only steady-state work.
A:SetManualCategory(model,"misc"); A:SetManualCategory(model,"equipment")
textures,shows,hides=0,0,0
collectgarbage("collect")
local baseline,frames=collectgarbage("count"),createdFrames
for n=1,400 do
    A:SetManualCategory(model,n%2==0 and "equipment" or "misc")
    A:ScanInventory(); A:Reconcile(); A:Render()
end
collectgarbage("collect")
local growth=collectgarbage("count")-baseline
assert(growth<128,"Retained movement growth: "..growth.." KB")
assert(createdFrames==frames and textures==0 and shows==0 and hides==0)
assert(locations==2 and A.items==items and A.emptySlots==empties and A.capacity==capacity)
assert(A.items[1]==model and A.groups==groups and A.groups.equipment.positions==positions)
-- A dialog's selected item remains stable if its physical slot changes contents.
A:OpenItemActions(model)
local selected=A.itemActions.item
slots[1],slots[2]=102,101
A:ScanInventory(); A:Reconcile(); A:Render()
assert(textures==2 and A.buttons["0:1"].currentItem.info.itemID==102)
assert(selected.info.itemID==101 and selected.identity=="guid:movement-101")
A.itemActions:Hide()
-- Occupied -> empty clears native state, and the next identical render is free.
slots[1]=nil
C_Container.GetContainerNumFreeSlots=function(bag) return bag==0 and 1 or 0,0 end
A:ScanInventory(); A:Reconcile(); A:Render()
assert(A.buttons["0:1"].paintState.kind=="empty")
local painted=textures
A:Render(); assert(textures==painted)
SetItemButtonTexture=originalTexture
print("Movement stress OK: 400 category transfers/scans reuse models, groups, locations and frames; unchanged item textures and Show/Hide calls = 0; retained growth <128KB; physical swaps/removal repaint correctly")
''')

lua.execute('''
-- One ordinary empty per eligible category, before surplus distribution.
for _,cat in ipairs(A.categories) do A.profile.layout[cat.id].hidden=false end
local physical={[1]=101}
C_Container.GetContainerNumSlots=function(bag) return bag==0 and 9 or bag==5 and 1 or 0 end
C_Container.GetContainerNumFreeSlots=function(bag) return bag==0 and 8 or bag==5 and 1 or 0,0 end
C_Container.GetContainerItemInfo=function(bag,slot)
    if bag==0 and physical[slot] then return {itemID=physical[slot],quality=2,stackCount=1,iconFileID=physical[slot]} end
end
C_Item.GetItemGUID=function(location) return "category-drop" end
A.profile.manualCategories={}; A.profile.favorites={}
A:ScanInventory(); A:Reconcile(); A:Render()
local assigned={}
for _,cat in ipairs(A.categories) do
    local found=false
    local metrics=A:ItemMetrics(A:GetLayout()[cat.id])
    for index,slot in pairs(A.emptyPositions[cat.id]) do
        assert(not assigned[slot.slotKey]); assigned[slot.slotKey]=true
        if index<=metrics.cols*metrics.rows then found=true end
        assert((slot.bag==5)==(cat.id=="reagentbag"))
    end
    assert(found,"No drop destination for "..cat.id)
end
local cursor=101
GetCursorInfo=function() return cursor and "item",cursor end
CursorHasItem=function() return cursor~=nil end
local pickups=0
C_Container.PickupContainerItem=function(bag,slot)
    pickups=pickups+1
    if bag==0 and not physical[slot] then physical[1]=nil; physical[slot]=cursor; cursor=nil end
end
-- Exercise the actual background button, not just a direct function call.
local panel=A.panels.misc
assert(panel.dropTarget.mouse and panel.scroll.mouseClick==false and panel.content.mouse==false)
assert(panel.dropTarget.scripts.OnClick and panel.move.scripts.OnReceiveDrag)
for _,parent in pairs(panel.bagParents) do assert(parent.mouse==false) end
panel.dropTarget.scripts.OnReceiveDrag()
assert(cursor==nil and pickups==1)
A:ScanInventory(); A:Reconcile(); A:Render()
assert(A.items[1].category=="misc" and A:GetStackCategories()[A.items[1].identity]=="misc")
-- A native rejection (ordinary item into reagent bag) preserves the cursor and
-- leaves no pending category override. No transfer is attempted while editing.
cursor=101
assert(not A:DropIntoCategory("reagentbag") and cursor==101)
assert(not next(A.pendingPlacements))
A.draft=A:Copy(A.profile.layout)
local previous=pickups
assert(not A:DropIntoCategory("misc") and pickups==previous)
A.draft=nil
-- No ordinary slots: reagent free space must not be reused for ordinary panels.
A.emptySlots={{bag=5,slot=1,slotKey="5:1",family=0}}
A:AssignEmptySlots()
assert(not A:DropIntoCategory("consumables") and pickups==previous)
cursor=nil; assert(not A:DropIntoCategory("misc"))
print("Category drops OK: one real empty slot per eligible panel, unique slots and reagent isolation; dedicated background receives drops with transparent frames passing clicks; rejected transfers preserve cursor and clear pending rules; editor/full bags protected")
''')

lua.execute('''
-- Rebuild: MyBags-style source tracking makes category assignment independent
-- from available physical slots; focus ancestry catches release over children.
A.window:Show(); A.search:SetText("")
A.profile.manualCategories={}; A.profile.favorites={}
local physical={101,102}; local cursor
C_Container.GetContainerNumSlots=function(bag) return bag==0 and 2 or 0 end
C_Container.GetContainerNumFreeSlots=function() return 0,0 end
C_Container.GetContainerItemInfo=function(bag,slot)
    if bag==0 and physical[slot] then return {itemID=physical[slot],quality=2,stackCount=1,iconFileID=physical[slot]} end
end
C_Item.GetItemGUID=function(location) return "virtual-"..physical[location.slot] end
A.itemCache[101]={name="Sword",classID=Enum.ItemClass.Weapon}
A.itemCache[102]={name="Shield",classID=Enum.ItemClass.Armor}
GetCursorInfo=function() return cursor and "item",cursor end
CursorHasItem=function() return cursor~=nil end
local clears,pickups=0,0
ClearCursor=function() clears=clears+1; cursor=nil end
C_Container.PickupContainerItem=function() pickups=pickups+1 end
A:ScanInventory(); A:Reconcile(); A:Render()
local source=A.buttons["0:1"]
assert(#A.emptySlots==0)
A:CaptureItemSource(source); cursor=101
GetMouseFoci=function() return {A.panels.misc.title} end
-- Font -> panel ancestry, then the source's actual OnDragStop handler.
source.scripts.OnDragStop(source)
assert(cursor==nil and clears==1 and pickups==0)
assert(A.items[1].category=="misc" and physical[1]==101 and physical[2]==102)
assert(A:GetStackCategories()[A.items[1].identity]=="misc")
-- The item is usable in a native slot after reclassification, and a favorite
-- follows the same explicit destination index without making a physical swap.
A:ToggleFavorite(A.items[1])
A:CaptureItemSource(source); cursor=101
assert(A:TryVirtualDrop("consumables",7))
assert(A.profile.favorites[101].category=="consumables" and A.profile.favorites[101].index==7)
assert(A.profile.placements.consumables[A.items[1].identity]==7 and pickups==0)
-- Dropping onto the same item must reach the native stack handler, with or
-- without a favorite. A remaining cursor stack must not be reclassified on stop.
local target={info={itemID=101,stackCount=5},identity="second-stack",bag=0,slot=2}
local savedPosition=A.groups.consumables.positions[9]
local savedFavorite=A.profile.favorites[101]
A.groups.consumables.positions[9]=target
local focus={anchorCategory="consumables",anchorIndex=9}
for _,favorite in ipairs({true,false}) do
    if not favorite then A:RemoveFavorite(101) end
    A.groups.consumables.positions[9]=target
    cursor=nil; A:CaptureItemSource(source); cursor=101
    local beforeClears=clears
    local beforeRule=A.profile.manualCategories[101]
    local beforeFavorite=A.profile.favorites[101]
    assert(not A:TryVirtualDrop("consumables",9))
    assert(cursor==101 and clears==beforeClears and not A.itemDrag)
    assert(A.profile.manualCategories[101]==beforeRule and A.profile.favorites[101]==beforeFavorite)
    -- A full or partially filled target may leave items on the cursor.
    GetMouseFoci=function() return {focus} end
    source.scripts.OnDragStop(source)
    assert(cursor==101 and clears==beforeClears and A.profile.manualCategories[101]==beforeRule)
    A.groups.consumables.positions[9]=target
end
A.groups.consumables.positions[9]=savedPosition
A.profile.favorites[101]=savedFavorite
cursor=nil
print("Stack drops OK: identical items reach native handling with and without favorites; remaining cursor stacks are not virtually moved")
-- An unrelated cursor item, split stack or reagent transfer is never consumed.
A:CaptureItemSource(source); cursor=102
local old=A.profile.manualCategories[101]
assert(not A:TryVirtualDrop("quest") and cursor==102 and A.profile.manualCategories[101]==old)
cursor=nil; A:CaptureItemSource(source); cursor=101
assert(not A:TryVirtualDrop("reagentbag") and cursor==101)
cursor=nil; A.itemDrag=nil

-- Quick category movement persists independently of the editor, while resizing
-- still needs explicit edit mode. Swaps validate both rectangle footprints.
local savedLayout=A.profile.layout
local template={cols=3,rows=2,width=136,height=132,itemSize=36,itemSpacing=4,compact=false}
local first=A:Copy(template); first.x,first.y=0,0
local second=A:Copy(template); second.x,second.y=5,0
A.profile.layout={equipment=first,consumables=second}
for _,cat in ipairs(A.categories) do
    if not A.profile.layout[cat.id] then local hidden=A:Copy(savedLayout[cat.id]); hidden.hidden=true; A.profile.layout[cat.id]=hidden end
end
local cx,cy=0,0
GetCursorPosition=function() return cx,cy end
IsShiftKeyDown=function() return true end
A.profile.settings.layoutLocked=false
local panel=A.panels.equipment
A:BeginQuickMove(panel); assert(type(panel.quickDrag)=="table" and not A.draft)
cx=200; panel.scripts.OnUpdate()
assert(panel.quickDrag.valid and panel.quickDrag.swap.id=="consumables")
A:EndQuickMove(panel)
assert(A.profile.layout.equipment.x==5 and A.profile.layout.consumables.x==0 and not panel.scripts.OnUpdate)
local before=A:Copy(A.profile.layout.equipment)
A:BeginQuickMove(panel); cx=500; panel.scripts.OnUpdate(); A:EndQuickMove(panel,true)
assert(A.profile.layout.equipment.x==before.x)
A:ToggleLayoutLock(); A:BeginQuickMove(panel); assert(type(panel.quickDrag)~="table")
A:ToggleLayoutLock()
-- Repeated direct moves reuse guides/decorations, with no idle update scripts.
local frames=createdFrames
for n=1,100 do A:BeginQuickMove(panel); cx=cx+1; panel.scripts.OnUpdate(); A:EndQuickMove(panel,true) end
assert(createdFrames==frames and not panel.scripts.OnUpdate)
A.profile.layout=savedLayout
A:ApplyLayout(); A:Render()
local result,err=A:DecodeProfile(A:ExportProfile()); assert(result,err)
assert(result.settings.layoutLocked==false)
assert(A.decoration and A.panels.misc.blockStyled and A.lockButton:IsShown())
print("Rebuild OK: full physical bags accept virtual category transfers; focus ancestry/source release works; favorites keep destination; foreign/reagent cursor protected; direct movement, safe swaps, cancel and lock; 100 moves create no frames; old profile code roundtrip intact")
''')

lua.execute('''
-- Attribute search and automatic rules share the same data-only evaluator.
local sword=A.items[1]
sword.itemLevel=100
assert(A:MatchesQuery(sword,"tipo:equipamento nivel:>=80 !qualidade:lixo"))
assert(A:MatchesQuery(sword,"id:101 favorito:sim"))
assert(not A:MatchesQuery(sword,"tipo:consumivel"))
assert(not A:MatchesQuery(sword,"id:102"))
assert(A:MatchesQuery(sword,"Sword"))
assert(not A:CompileQuery("qualidade:banana"))
assert(not A:ValidateCategoryRule("categoria:misc"))
assert(not A:ValidateCategoryRule("novo:sim"))
assert(not A:ValidateCategoryRule(string.rep("x",257)))
assert(A:ValidateCategoryRule("tipo:equipamento !qualidade:lixo"))
A:RemoveFavorite(101); A:SetManualCategory(sword,nil)
A:SetCategoryOption("misc","rule","tipo:equipamento nivel:>=80")
assert(sword.category=="misc")
A:SetManualCategory(sword,"quest"); assert(sword.category=="quest")
A:SetManualCategory(sword,nil); assert(sword.category=="misc")
A:SetCategoryOption("misc","rule",""); assert(sword.category=="equipment")
A:SetCategoryOption("misc","rule","tipo:equipamento")
local p,err=A:DecodeProfile(A:ExportProfile()); assert(p,err)
assert(p.layout.misc.rule=="tipo:equipamento")
local invalid=A:Copy(p); invalid.layout.misc.rule="novo:sim"
assert(not pcall(function() A:ValidateProfile(invalid) end))
-- Compiled filters have a hard cache bound even while typing many searches.
for n=1,200 do A:MatchesQuery(sword,"name"..n) end
local size=0; for _ in pairs(A.queryCache) do size=size+1 end
assert(size<=64)
A:SetCategoryOption("misc","rule","")

-- Split-stack gestures do not become category-only transfers of the whole stack.
GetCursorInfo=function() return nil end
IsModifiedClick=function(key) return key=="SPLITSTACK" end
A:CaptureItemSource(A.buttons["0:1"]); assert(not A.itemDrag)
IsModifiedClick=function() return false end
-- Native modern menu exposes category actions without creating a dialog per click.
local entries={}
MenuUtil={CreateContextMenu=function(_,generator)
    local root={}
    function root:CreateTitle() end
    function root:CreateButton(title,callback) entries[title]=callback end
    function root:CreateCheckbox(title,checked,callback) entries[title]=callback end
    generator(nil,root)
end}
A:OpenCategoryMenu(A.panels.misc)
assert(entries[A.L["Personalizar categoria"]] and entries[A.L["Redimensionar no editor"]])
entries[A.L["Bloquear movimento das categorias"]]()
assert(A:GetSettings().layoutLocked)
entries[A.L["Bloquear movimento das categorias"]]()
assert(not A:GetSettings().layoutLocked)
-- Drop feedback reuses its frame rather than allocating a highlight per hover.
CursorHasItem=function() return true end
GetCursorInfo=function() return "item",101 end
A.itemDrag={bag=0}
local frames=createdFrames
for n=1,100 do A:ShowCategoryDropHint("misc"); assert(A.panels.misc.dropGlow:IsShown()); A:HideCategoryDropHint() end
assert(createdFrames==frames and not A.panels.misc.dropGlow:IsShown())
A.itemDrag=nil
-- Split API hooks are installed once and remove the virtual source state.
local hooks=0
C_Container.SplitContainerItem=function() end
hooksecurefunc=function(_,method,fn) assert(method=="SplitContainerItem"); hooks=hooks+1; splitHook=fn end
A:InstallInteractionHooks(); A:InstallInteractionHooks(); assert(hooks==1)
A.itemDrag={bag=0}; splitHook(); assert(not A.itemDrag)
print("Queries/menu OK: numeric/negative attribute filters, manual precedence, rule removal and profile roundtrip; unsafe/oversize rules rejected; cache <=64; split gesture source excluded; native context menu actions")
''')

lua.execute('''
CursorHasItem=function() return false end
GetCursorInfo=function() return nil end
IsModifiedClick=function() return false end
A.profile.manualCategories={}; A.profile.favorites={}
A.profile.settings.showItemLevel=nil
A.slotLocations={}
local filled=true
C_Container.GetContainerNumSlots=function(bag) return bag==0 and 2 or 0 end
C_Container.GetContainerNumFreeSlots=function() return 0,0 end
C_Container.GetContainerItemInfo=function(bag,slot)
    if bag==0 and filled then return {itemID=101,quality=3,stackCount=1,iconFileID=101} end
end
C_Item.GetItemGUID=function(location) return "level-"..location.slot end
C_Item.GetCurrentItemLevel=function(location) return location.slot==1 and 120 or 144 end
A.itemCache[101]={name="Sword",classID=Enum.ItemClass.Weapon,itemLevel=80}
A:ScanInventory(); A:Reconcile(); A:Render()
assert(A.items[1].itemLevel==120 and A.items[2].itemLevel==144)
assert(A.buttons["0:1"].levelLabel:GetText()=="120")
assert(A.buttons["0:2"].levelLabel:GetText()=="144")
assert(A.buttons["0:1"].levelLabel:IsShown())
local entries={}
MenuUtil.CreateContextMenu=function(_,generator)
    local root={}
    function root:CreateDivider() end
    function root:CreateButton(title,callback) entries[title]=callback end
    function root:CreateCheckbox(title,checked,callback) entries[title]=callback end
    generator(nil,root)
end
A.bagMenuButton.scripts.OnClick(A.bagMenuButton,"LeftButton")
entries[A.L["Mostrar nível dos equipamentos"]]()
assert(A.profile.settings.showItemLevel==false and not A.buttons["0:1"].levelLabel:IsShown())
local decoded,err=A:DecodeProfile(A:ExportProfile()); assert(decoded,err)
assert(decoded.settings.showItemLevel==false)
entries[A.L["Mostrar nível dos equipamentos"]]()
assert(A.buttons["0:1"].levelLabel:IsShown())
filled=false; A:ScanInventory(); A:Reconcile(); A:Render()
assert(not A.buttons["0:1"].levelLabel:IsShown())
-- The temporary equipped-bag panel uses equipment APIs, not inventory-slot moves.
C_Container.ContainerIDToInventoryID=function(bag) return bag+19 end
GetInventoryItemTexture=function(_,id) if id~=24 then return 101 end end
GetInventoryItemQuality=function() return 2 end
local put,pickup
PutItemInBag=function(id) put=id end
PickupBagFromSlot=function(id) pickup=id end
C_Container.GetContainerNumSlots=function(bag) return bag==5 and 40 or 32 end
C_Container.GetContainerNumFreeSlots=function(bag) return bag==5 and 40 or 12 end
local layout=A:ExportProfile()
entries[A.L["Visualização por bolsa"]]()
assert(A.bagSlots:IsShown() and #A.bagSlots.buttons==5)
assert(A.bagSlots.buttons[1].capacityLabel:GetText()=="20/32")
assert(A.bagSlots.buttons[5].capacityLabel:GetText()=="0/40")
assert(A.bagSlots.buttons[5].empty and A.bagSlots.buttons[5].emptyBackground:IsShown())
A.bagSlots.buttons[2].scripts.OnReceiveDrag(); assert(put==21)
A.bagSlots.buttons[3].scripts.OnDragStart(); assert(pickup==22)
local frames=createdFrames
for n=1,100 do A:ToggleBagSlots(); A:ToggleBagSlots() end
assert(createdFrames==frames and A:ExportProfile()==layout)
InCombatLockdown=function() return true end
put=nil; A.bagSlots.buttons[2].scripts.OnReceiveDrag(); assert(not put)
InCombatLockdown=function() return false end
A.window.scripts.OnHide(); assert(not A.bagSlots:IsShown())
print("Bag tools OK: actual per-instance ilvl, menu toggle/profile roundtrip, empty-slot cleanup; five native equipped-bag controls, combat protection, 100 toggles create no frames or layout changes, close hides temporary panel")
''')

lua.execute('''
-- Real bag grouping must render every physical slot once, keep native drops,
-- and leave the category layout/window size intact after returning.
A.window:Show(); A:ApplyLayout()
assert(not A.generalButton:IsShown() and not A.editButton:IsShown())
A.slotLocations={}
local counts={[0]=3,[1]=2,[2]=0,[3]=4,[4]=1,[5]=2}
C_Container.GetContainerNumSlots=function(bag) return counts[bag] end
C_Container.GetContainerNumFreeSlots=function(bag) return counts[bag]-(bag==0 and 1 or 0),0 end
C_Container.GetContainerItemInfo=function(bag,slot)
    if bag==0 and slot==1 then return {itemID=101,quality=3,stackCount=1,iconFileID=101} end
end
C_Container.GetBagName=function(bag) return "Physical bag "..bag end
A.itemCache[101]={name="Sword",classID=Enum.ItemClass.Weapon,itemLevel=120}
A:ScanInventory(); A:Reconcile(); A:Render()
local saved=A:ExportProfile()
local width,height=A.window:GetWidth(),A.window:GetHeight()
A:ToggleBagSlots()
assert(A.physicalBagView and A.bagSlots:IsShown())
assert(not A.panels.equipment:IsShown() and not A.lockButton:IsShown())
assert(not A.physicalSections[2]:IsShown())
assert(A.physicalSections[0].title:GetText()=="#1: Physical bag 0")
local visible=0
for bag=0,5 do
    for slot=1,counts[bag] do
        local b=A.buttons[bag..":"..slot]
        assert(b:IsShown() and b.renderPanel==A.physicalSections[bag])
        assert(rawget(b,"anchorCategory")==nil and b.anchorSlotKey==bag..":"..slot)
        visible=visible+1
    end
end
assert(visible==12)
A:CaptureItemSource(A.buttons["0:1"]); assert(not A.itemDrag)
A.itemDrag={bag=0}; assert(not A:TryVirtualDrop("misc",1)); A.itemDrag=nil
local frames=createdFrames
for n=1,100 do A:ToggleBagSlots(); A:ToggleBagSlots() end
assert(createdFrames==frames and A:ExportProfile()==saved)
A:ToggleBagSlots()
assert(not A.physicalBagView and not A.bagSlots:IsShown())
assert(A.window:GetWidth()==width and A.window:GetHeight()==height)
assert(A.panels.equipment:IsShown() and A.buttons["0:1"].anchorCategory=="equipment")
A:ToggleBagSlots(); A:StartEdit()
assert(A.draft and not A.physicalBagView)
assert(not A.generalButton:IsShown() and not A.editButton:IsShown() and A.saveButton:IsShown())
A:FinishEdit(false)
A:ToggleBagSlots(); A.window.scripts.OnHide()
assert(not A.physicalBagView and not A.bagSlots:IsShown())
print("Physical view OK: all native slots grouped by bag, no virtual category drops, 100 toggles allocate no frames or change exported layout, original dimensions restored, editor/close return to categories; redundant toolbar buttons stay hidden")
''')

lua.execute('''
-- Settings close (including Escape's global bag-close hooks) must preserve the
-- inventory, then restore ordinary Escape handling exactly once.
assert(A.windowTitle:GetText()==A:BackpackTitle())
local jobs={}
C_Timer.After=function(_,fn) jobs[#jobs+1]=fn end
local function flush()
    local pending=jobs; jobs={}
    for _,fn in ipairs(pending) do fn() end
end
Settings.OpenToCategory=function()
    SettingsPanel:Show()
    A:RequestWindow("close")
    for _,name in ipairs(UISpecialFrames) do if name=="BlockBagsWindow" then A.window:Hide() end end
end
A.window:Show(); A.windowIntent=nil; A.intentQueued=false; A.refreshQueued=false
-- A bag-close already queued before opening Settings must also be ignored.
A:RequestWindow("close"); A:OpenGeneralSettings(); flush()
assert(A.window:IsShown() and A.settingsInventorySession)
for _,name in ipairs(UISpecialFrames) do assert(name~="BlockBagsWindow") end
SettingsPanel:TransitionBackOpeningPanel()
assert(not GameMenuFrame:IsShown())
A:RequestWindow("close")
for _,name in ipairs(UISpecialFrames) do if name=="BlockBagsWindow" then A.window:Hide() end end
assert(A.window:IsShown()); flush()
assert(not A.settingsInventorySession and A.window:IsShown())
local count=0; for _,name in ipairs(UISpecialFrames) do if name=="BlockBagsWindow" then count=count+1 end end
assert(count==1)
A:RequestWindow("close"); flush(); assert(not A.window:IsShown())
-- Reopening before the deferred cleanup preserves protection until the next close.
A.window:Show(); A:OpenGeneralSettings()
SettingsPanel:Hide(); SettingsPanel.scripts.OnHide()
A:OpenGeneralSettings(); flush(); assert(A.settingsInventorySession)
SettingsPanel:Hide(); SettingsPanel.scripts.OnHide(); flush()
assert(not A.settingsInventorySession and A.window:IsShown())
-- Opening options alone does not open a previously hidden inventory.
A.window:Hide(); A:OpenGeneralSettings(); flush()
assert(not A.window:IsShown() and not A.settingsInventorySession)
SettingsPanel:TransitionBackOpeningPanel(); assert(not GameMenuFrame:IsShown()); flush()
-- Settings opened outside BlockBags retain Blizzard's return to GameMenu.
SettingsPanel:Show(); SettingsPanel:TransitionBackOpeningPanel()
assert(GameMenuFrame:IsShown()); GameMenuFrame:Hide(); flush()
-- A failed Settings open cannot leave the inventory outside Escape handling.
A.window:Show(); Settings.OpenToCategory=function() error("test failure") end
A:OpenGeneralSettings()
assert(not A.settingsInventorySession and not A.settingsSpecialIndex)
assert(not A.settingsMenuSession)
count=0; for _,name in ipairs(UISpecialFrames) do if name=="BlockBagsWindow" then count=count+1 end end
assert(count==1)
print("Settings close OK: Escape/global bag close and queued closes preserve inventory, normal close resumes, rapid reopening and failed opens restore one Escape registration, hidden inventory stays hidden; window title uses the native backpack label")
''')

lua.execute((root / "tests" / "expanded.lua").read_text(encoding="utf-8"))

lua.execute((root / "tests" / "localization.lua").read_text(encoding="utf-8"))

lua.execute((root / "tests" / "stack_layout.lua").read_text(encoding="utf-8"))

# Bindings.xml is loaded automatically by WoW, not as an ordinary TOC XML file.
import xml.etree.ElementTree as ET
binding_root = ET.fromstring((root / "Bindings.xml").read_text(encoding="utf-8"))
assert binding_root.tag == "Bindings"
assert sum("header" in binding.attrib for binding in binding_root) == 1
assert len({binding.attrib["name"] for binding in binding_root}) == len(binding_root)
assert "Bindings.xml" not in (root / "BlockBags.toc").read_text(encoding="utf-8").splitlines()
item_button_source = (root / "UI.lua").read_text(encoding="utf-8").split("function A:GetItemButton",1)[1].split("function A:PaintItem",1)[0]
assert "ContainerFrameItemButtonTemplate,SecureActionButtonTemplate" in item_button_source
assert 'if bankButton then b:SetScript("OnClick",click) else b:HookScript("OnClick",click) end' in item_button_source
print("Bindings/security setup OK: automatic XML load, one header, preserved secure click handler")

lua.execute((root / "tests" / "favorite_restore.lua").read_text(encoding="utf-8"))

lua.execute((root / "tests" / "position_modes.lua").read_text(encoding="utf-8"))

lua.execute((root / "tests" / "resize_slots.lua").read_text(encoding="utf-8"))

lua.execute('''
-- EditBox has no GetStringHeight; profile text is measured with a FontString.
local code=A.settingsControls.code
local measure=A.settingsControls.codeMeasure
code.GetStringHeight=function() error("EditBox cannot measure string height") end
local height=1000
measure.GetStringHeight=function() return height end
code:SetText("BB1:profile-code")
code.scripts.OnTextChanged(code)
assert(code.height==1024 and measure:GetText()==code:GetText())
height=0; code:SetText(""); code.scripts.OnTextChanged(code)
assert(code.height==155 and measure:GetText()=="")
local frames=createdFrames
for n=1,100 do code.scripts.OnTextChanged(code) end
assert(createdFrames==frames and not measure:IsShown())
print("Profile text OK: hidden FontString measures height, empty text preserves minimum, repeated edits reuse one measure")
''')

lua.execute((root / "tests" / "bank_window.lua").read_text(encoding="utf-8"))

lua.execute((root / "tests" / "backpack_controls.lua").read_text(encoding="utf-8"))

lua.execute((root / "tests" / "item_borders.lua").read_text(encoding="utf-8"))

lua.execute((root / "tests" / "bank_access.lua").read_text(encoding="utf-8"))

lua.execute((root / "tests" / "bank_tools.lua").read_text(encoding="utf-8"))
