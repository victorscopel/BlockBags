local T={}
for key,value in pairs(A) do if type(value)=="function" then T[key]=value end end
T.L,T.locale=A.L,A.locale
T.cell,T.padding,T.header,T.scrollGutter=40,8,36,0
T.categories=A:Copy(A.baseCategories); T.baseCategories=A:Copy(A.baseCategories)
T.database={}; T.itemCache,T.itemRequests,T.loading={},{},{}
T.windowName="BlockBagsRoadmapTest"; T.itemButtonPrefix="RoadmapItem"
T:InitializeDatabase(); T:BuildUI(); T:RegisterSettings(); T.ready=true; T.window:Show()
T.capacity={total=30,free=26,reagentTotal=0,reagentFree=0}; T.emptySlots={}; T.slotModels={}
local function item(id,index,level,quality,count,class)
    return {identity="test:"..index,bag=0,slot=index,slotKey="0:"..index,category="consumables",name="Potion "..id,
        sortName="potion "..id,classID=class or 0,itemLevel=level,expansionID=10,binding="boe",quest={},
        info={itemID=id,stackCount=count,quality=quality,hyperlink="item:"..id,iconFileID=135882}}
end
local a,b,c=item(98001,1,30,1,3),item(98002,2,50,3,8),item(98001,3,30,1,5)
local d=item(98003,4,45,2,2)
T.items={a,b,c,d}
for _,entry in ipairs(T.items) do T.slotModels[entry.slotKey]=entry end
T:Reconcile(); T:Render(); T:BuildSettingsControls(); T:RefreshSettings()
-- Boolean precedence, grouping, negation and quoted operators are data-only.
assert(T:MatchesQuery(b,"type:consumable (quality:rare | quality:epic) ilvl:>=40"))
assert(not T:MatchesQuery(a,"type:consumable (quality:rare | quality:epic)"))
assert(T:MatchesQuery(a,"!(quality:rare | quality:epic) count:>=3"))
assert(T:MatchesQuery(b,"quality:common OR quality:rare AND ilvl:>40"))
assert(not T:MatchesQuery(b,"(quality:common OR quality:rare) AND ilvl:>60"))
assert(T:CompileQuery('name:"foo OR bar (baz)"'))
for _,query in ipairs({"(type:consumable","type:consumable OR", "()", "type:consumable AND AND quality:rare", "type:consumable )", "quality:banana"}) do assert(not T:CompileQuery(query),query) end
assert(not T:ValidateCategoryRule("type:consumable OR (new:true)"))
assert(not T:CompileQuery(string.rep("(",10).."id:1"..string.rep(")",10)))
local herb=item(1,5,0,1,1,7); herb.subclassID=9; herb.craftQuality=3
assert(T:MatchesQuery(herb,"profession:alchemy craftquality:>=2"))
assert(T:MatchesQuery(herb,"profissao:herborismo"))
assert(not T:MatchesQuery(herb,"profession:enchanting"))
local rows={{group=1,field="type",value="consumable",operator="="},{group=1,field="quality",value="3",operator=">="},
    {group=2,field="name",value="Potion 98001",operator="=",invert=false}}
local query,err=T:QueryFromRuleRows(rows); assert(query,err)
assert(T:MatchesQuery(a,query) and T:MatchesQuery(b,query))
local back=T:RuleRowsFromQuery(query); assert(#back==3 and back[3].group==2)
assert(not T:RuleRowsFromQuery("!(type:equipment quality:rare)"))
assert(not T:QueryFromRuleRows({{group=5,field="name",value="foo",operator="="}}))
T.settingsCategory="consumables"; T:RefreshSettings()
T.ruleControls.data=rows; T:RefreshRuleEditorRows(); T:PreviewRuleEditor()
assert(T.ruleControls.preview:GetText():find("3",1,true))
T:SetCategoryOption("consumables","rule",query)
assert(T:GetLayout().consumables.rule==query)
local geometry=T:Copy(T:GetLayout())
T:MoveCategoryRulePriority("consumables",-1)
for id,layout in pairs(geometry) do assert(T:GetLayout()[id].x==layout.x and T:GetLayout()[id].y==layout.y) end
-- Sorting never rearranges fixed positions unless explicitly requested.
local originalIndex=T:GetPositions().consumables[b.identity]
T:SetCategoryOption("consumables","sortBy","quality")
assert(T:GetPositions().consumables[b.identity]==originalIndex)
T.organizeCategory="consumables"; T:Reconcile(); assert(T.groups.consumables.positions[1]==b)
T:SetCategoryOption("consumables","sortBy","count")
T.organizeCategory="consumables"; T:Reconcile(); assert(T.groups.consumables.positions[1]==b and T.groups.consumables.positions[2]==c)
T:ToggleFavorite(b)
local reserved=T.profile.favorites[b.info.itemID].index
T:SetCategoryOption("consumables","sortBy","ilvl"); T:SetCategoryOption("consumables","sortDescending",false)
T.organizeCategory="consumables"; T:Reconcile(); assert(T:GetPositions().consumables[b.identity]==reserved)
local placements=T:Copy(T:GetPositions().consumables)
for _,preset in ipairs(A.layoutPresets) do
    assert(T:ApplyLayoutPreset(preset.id))
    for id,layout in pairs(T:GetLayout()) do assert(T:CanPlace(id,layout),id) end
    for identity,index in pairs(placements) do assert(T:GetPositions().consumables[identity]==index) end
    assert(T:DecodeProfile(T:ExportProfile()))
end
T:StartEdit(); local savedSize=T.profile.layout.consumables.itemSize
T:ResetCategory("consumables"); assert(T.draft.consumables.itemSize==36 and T.profile.layout.consumables.itemSize==savedSize)
for id,layout in pairs(T:GetLayout()) do assert(T:CanPlace(id,layout),id) end
T:FinishEdit(false)
T:CopyCategoryAppearance("consumables","misc")
assert(T:GetLayout().misc.itemSize==T:GetLayout().consumables.itemSize)
assert(T:GetLayout().misc.width~=nil)
local favoriteIndex=T.profile.favorites[b.info.itemID].index
-- Virtual groups preserve every physical identity and only sum identical links.
local originalCountSetter=SetItemButtonCount
SetItemButtonCount=function(button,value) button.testDisplayedCount=value end
for _,button in pairs(T.buttons) do button.testDisplayedCount=button.paintState and button.paintState.count end
T:SetCategoryOption("consumables","stackGrouping",true)
T:Reconcile(); T:Render()
local group=T.groups.consumables
local index=T:GetPositions().consumables[a.identity]
local stack=group.virtualAt[index]
assert(stack and stack.total==8 and #stack.members==2)
assert(not group.virtualAt[reserved] or #group.virtualAt[reserved].members==1)
assert(T.buttons[a.slotKey].currentItem==a and T.buttons[a.slotKey].stackBadge:IsShown())
assert(not T.buttons[c.slotKey]:IsShown())
assert(T.buttons[a.slotKey].testDisplayedCount==8)
T:ToggleVirtualStack(stack); assert(T.buttons[a.slotKey]:IsShown() and T.buttons[c.slotKey]:IsShown())
assert(T.buttons[a.slotKey].testDisplayedCount==3 and T.buttons[c.slotKey].testDisplayedCount==5)
T:ToggleVirtualStack(stack)
assert(T.buttons[a.slotKey].testDisplayedCount==8)
T.physicalBagView=true; T:PaintItem(T.buttons[a.slotKey],a,""); assert(T.buttons[a.slotKey].testDisplayedCount==3)
T.physicalBagView=false; T:Render(); assert(T.buttons[a.slotKey].testDisplayedCount==8)
local frames=createdFrames; collectgarbage("collect"); local baseline=collectgarbage("count")
for n=1,200 do T:Reconcile(); T:Render() end
collectgarbage("collect"); assert(createdFrames==frames and collectgarbage("count")-baseline<128)
assert(T.profile.favorites[b.info.itemID].index==favoriteIndex)
T:GetDropSlots()[c.identity]={category="consumables",index=10}; T:Reconcile(); T:Render()
assert(T.buttons[c.slotKey]:IsShown() and not group.virtualAt[10])
local imported=T:DecodeProfile(T:ExportProfile()); assert(imported and imported.layout.consumables.stackGrouping)
local bad=T:Copy(imported); bad.layout.consumables.sortBy="unknown"; assert(not pcall(function() T:ValidateProfile(bad) end))
bad=T:Copy(imported); bad.settings.theme="unknown"; assert(not pcall(function() T:ValidateProfile(bad) end))
local titleFont,categoryFont
T.windowTitle.SetFont=function(_,font) titleFont=font end
T.panels.consumables.title.SetFont=function(_,font) categoryFont=font end
T:SetFeatureOption("theme","dark"); assert(not T.decoration:IsShown())
local oldElvUI=ElvUI
ElvUI={{media={backdropcolor={0.1,0.2,0.3},bordercolor={0.3,0.4,0.5},normFont="custom-font"}}}
T:SetFeatureOption("theme","elvui"); local theme,bg,border,font=T:ThemeColors(); assert(theme=="elvui" and bg[2]==0.2 and font=="custom-font")
assert(titleFont=="custom-font" and categoryFont=="custom-font")
ElvUI=oldElvUI; T:SetFeatureOption("theme","blizzard"); assert(T.decoration:IsShown())
assert(titleFont==STANDARD_TEXT_FONT and categoryFont==STANDARD_TEXT_FONT)

T.itemDrag={category="consumables",identity=a.identity,bag=0,itemID=a.info.itemID}
local oldCursor,oldInfo=CursorHasItem,GetCursorInfo
CursorHasItem=function() return true end; GetCursorInfo=function() return "item",a.info.itemID end
assert(not T:DropPreview("consumables"))
assert(T:DropPreview("consumables",T:GetPositions().consumables[d.identity]))
T.groups.consumables.reserved[100]=99999
assert(not T:DropPreview("consumables",100))
T:ShowCategoryDropHint("consumables",100); T:HideCategoryDropHint()
frames=createdFrames
for n=1,100 do T:ShowCategoryDropHint("consumables",100); T:HideCategoryDropHint() end
assert(createdFrames==frames)
CursorHasItem,GetCursorInfo=oldCursor,oldInfo
T:CancelInteractions()
SetItemButtonCount=originalCountSetter
RoadmapFixture=T
print("Roadmap OK: bounded Boolean parser, visual rules/preview/priority, profession families, stable per-category sorting, favorite reservations, three presets, reset/copy, themes, virtual stacks/physical expansion and pinned exclusions, 200 renders retain <128KB and no frames; exact drop preview reuses frames")
