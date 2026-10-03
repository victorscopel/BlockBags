-- Slot dimensions include the actual item size, spacing and panel borders.
A.window:Show(); A:StartEdit()
for id,data in pairs(A.draft) do data.hidden=id~="equipment" end
local data=A.draft.equipment
data.x,data.y=0,0
for size=24,56,4 do
    for spacing=0,12,3 do
        local candidate=A:Copy(data)
        candidate.itemSize,candidate.itemSpacing=size,spacing
        candidate.width,candidate.height=351,243
        A:SnapResizeToSlots("equipment",candidate)
        local m=A:ItemMetrics(candidate)
        assert(m.width==(m.cols-1)*m.step+m.size)
        assert(m.height==(m.rows-1)*m.step+m.size)
        local minW,minH=A:MinimumPanelSize(candidate)
        assert(candidate.width>=minW and candidate.height>=minH)
    end
end
-- Rounding toward a neighbor can fall back to the smaller complete-slot size.
A.draft.neighbor={x=5,y=0,cols=3,rows=6,width=132,height=300}
local near=A:Copy(data)
near.itemSize,near.itemSpacing=36,4
near.width,near.height=195,100
A:SnapResizeToSlots("equipment",near)
assert(near.width==172 and A:CanPlace("equipment",near))
A.draft.neighbor=nil
-- Preview cells are individual slot textures and reuse their pool on mouse updates.
local candidate=A:Copy(data)
candidate.itemSize,candidate.itemSpacing=36,4
candidate.width,candidate.height=351,243
A:SnapResizeToSlots("equipment",candidate)
A:UpdateEditorVisuals("equipment",candidate,true,true,false)
local m=A:ItemMetrics(candidate)
local preview=A.editorVisuals.preview
local shown=0
for _,slot in ipairs(preview.slots) do if slot:IsShown() then shown=shown+1; assert(slot.width==m.size and slot.height==m.size) end end
assert(shown==m.cols*m.rows)
local frames=createdFrames
for n=1,100 do A:UpdateEditorVisuals("equipment",candidate,true,true,false) end
assert(createdFrames==frames)
candidate.width,candidate.height=132,88
A:UpdateEditorVisuals("equipment",candidate,true,true,true)
shown=0; for _,slot in ipairs(preview.slots) do if slot:IsShown() then shown=shown+1 end end
assert(shown==3)
A:UpdateEditorVisuals("equipment",candidate,false,true,false)
assert(not preview:IsShown() and not preview.caption:IsShown())
-- Shift bypasses both edge and slot snapping, including toggling without moving.
data.width,data.height=332,252
local cx,cy=0,0
GetCursorPosition=function() return cx,cy end
local free=false
IsShiftKeyDown=function() return free end
local panel=A.panels.equipment
A:BeginPanelDrag(panel,true)
cx,cy=7,-11; panel.scripts.OnUpdate()
local snapped=A:Copy(panel.drag.candidate)
m=A:ItemMetrics(snapped)
assert(m.width==(m.cols-1)*m.step+m.size and m.height==(m.rows-1)*m.step+m.size)
free=true; panel.scripts.OnUpdate()
assert(panel.drag.candidate.width==339 and panel.drag.candidate.height==263)
free=false; panel.scripts.OnUpdate()
assert(panel.drag.candidate.width==snapped.width and panel.drag.candidate.height==snapped.height)
A:EndPanelDrag(panel); A:FinishEdit(false)
print("Resize slots OK: exact fit for item sizes/spacings, individual visible slots, bounded reusable texture pool, preview shrink/hide, Shift pixel sizing and modifier changes without mouse movement")
