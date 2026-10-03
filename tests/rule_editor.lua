local T=RoadmapFixture
local c=T.ruleControls
local savedData,savedUnsupported=c.data,c.unsupported
local row=c.rows[1]

-- Native dropdowns populate and query their selections during SetupMenu.
c.data={}; c.unsupported=false
T:RefreshRuleEditorRows(); T:PreviewRuleEditor()
for _,controls in ipairs(c.rows) do
    for _,name in ipairs({"group","field","operator","choice"}) do
        controls[name]:GenerateMenu()
        assert(#controls[name].menuEntries==0)
    end
end

c.data={{group=1,field="type",value="consumable",operator="="}}
T:RefreshRuleEditorRows(); T:PreviewRuleEditor()
for _,name in ipairs({"group","field","operator","choice"}) do row[name]:GenerateMenu() end
assert(#row.group.menuEntries==4 and row.group.menuEntries[1].isSelected)
assert(#row.field.menuEntries==#A.ruleFields and row.field.menuEntries[1].isSelected)
assert(#row.operator.menuEntries==5 and row.operator.menuEntries[1].isSelected)
assert(#row.choice.menuEntries==5 and row.choice.menuEntries[4].isSelected)

local typeChoice=row.choice.menuEntries[4]
row.field.menuEntries[2].responder()
assert(c.data[1].field=="quality" and c.data[1].value=="0")
assert(not typeChoice.selected())
typeChoice.responder()
assert(c.data[1].field=="quality" and c.data[1].value=="0")
row.choice:GenerateMenu()
assert(#row.choice.menuEntries==6 and row.choice.menuEntries[1].isSelected)
row.choice.menuEntries[4].responder()
row.operator:GenerateMenu(); row.operator.menuEntries[3].responder()
row.group:GenerateMenu(); row.group.menuEntries[2].responder()
assert(c.data[1].value=="3" and c.data[1].operator==">=" and c.data[1].group==2)
local query,err=T:QueryFromRuleRows(c.data)
assert(query,err)
assert(query=="(quality:>=3)")
assert(T:MatchesQuery(T.items[2],query) and not T:MatchesQuery(T.items[1],query))

local stale={}
for _,name in ipairs({"group","field","operator","choice"}) do
    row[name]:GenerateMenu()
    stale[#stale+1]=row[name].menuEntries[1]
end
row.remove.scripts.OnClick()
assert(#c.data==0)
for _,name in ipairs({"group","field","operator","choice"}) do row[name]:SignalUpdate() end
for _,entry in ipairs(stale) do assert(not entry.selected()); entry.responder() end
row.invert.scripts.OnClick(); row.remove.scripts.OnClick()
assert(#c.data==0)

-- Replacing a category's rows invalidates callbacks even for the same field.
c.data={{group=1,field="quality",value="2",operator="="}}
row.choice:GenerateMenu()
local previous=row.choice.menuEntries[4]
c.data={{group=1,field="quality",value="1",operator="="}}
previous.responder(); assert(c.data[1].value=="1" and not previous.selected())
row.operator:GenerateMenu()
local previousOperator=row.operator.menuEntries[3]
c.data[1].field="name"; c.data[1].value="Potion"
previousOperator.responder(); assert(c.data[1].operator=="=" and not previousOperator.selected())

c.data={{group=1,field="type",value="consumable",operator="="}}
T:RefreshRuleEditorRows(); T:PreviewRuleEditor()
local frames=createdFrames
for n=1,100 do
    for _,name in ipairs({"group","field","operator","choice"}) do row[name]:OpenMenu() end
    row.choice.menuEntries[4].responder()
end
assert(createdFrames==frames)
c.data,c.unsupported=savedData,savedUnsupported
T:RefreshRuleEditorRows(); T:PreviewRuleEditor()
print("Rule editor menus OK: immediate initialization, missing rows, dynamic choices, removed/replaced rows and stale field callbacks, 100 reopenings reuse controls")
