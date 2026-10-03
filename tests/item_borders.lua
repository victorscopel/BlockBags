-- Native textures with fixed dimensions must follow category icon sizing.
A.window:Show()
local button=A.buttons["0:1"]
local normal=CreateFrame("Texture",nil,button)
button.GetNormalTexture=function() return normal end
local keys={"IconBorder","IconOverlay","IconOverlay2","IconQuestTexture"}
for _,key in ipairs(keys) do
    local region=CreateFrame("Texture",nil,button)
    region:SetSize(37,key=="IconQuestTexture" and 38 or 37)
    region.SetAllPoints=function(texture,target) texture.allPoints=target end
    button[key]=region
end
local click=button:GetScript("OnClick")
local parent=button:GetParent()
local frames=createdFrames
button.renderSize=nil
for _,size in ipairs({24,36,48,56,32,36}) do
    A:SizeItemButton(button,size)
    assert(button:GetWidth()==size and button:GetHeight()==size)
    assert(math.abs(normal:GetWidth()-64*size/37)<0.001)
    for _,key in ipairs({"IconBorder","IconOverlay","IconOverlay2"}) do assert(button[key].allPoints==button) end
    assert(button.IconQuestTexture:GetWidth()==size)
    assert(math.abs(button.IconQuestTexture:GetHeight()-38*size/37)<0.001)
end
local writes=0
local setSize=button.SetSize
button.SetSize=function(...) writes=writes+1; return setSize(...) end
for n=1,100 do A:SizeItemButton(button,36) end
assert(writes==0 and createdFrames==frames and button:GetScript("OnClick")==click and button:GetParent()==parent)
button.SetSize=setSize
-- Both category and physical render paths use the same sizing routine.
local calls={}
local resize=A.SizeItemButton
A.SizeItemButton=function(controller,b,size) calls[size]=true; return resize(controller,b,size) end
local category=button.currentItem.category
local original=A:GetLayout()[category].itemSize
A:GetLayout()[category].itemSize=48
A:Render(); assert(calls[48] and button.renderSize==48)
A:SetPhysicalBagView(true); assert(calls[32] and button.renderSize==32)
A:SetPhysicalBagView(false); assert(button.renderSize==48)
A:GetLayout()[category].itemSize=original
A:Render()
A.SizeItemButton=resize
print("Item borders OK: quality/special overlays cover resized icons, native quickslot and quest proportions, 24–56px sizing and physical-view restore, no new frames/redundant writes or click changes")
