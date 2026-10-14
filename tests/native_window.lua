local T=RoadmapFixture
assert(not (T.window.template or ""):find("Secure"),"backpack window must be ordinary")
for _,button in pairs(T.buttons) do
    assert(button.template=="ContainerFrameItemButtonTemplate","native item buttons must not inherit a secure action")
    assert(button.interactionLayer,"category clicks require a separate interaction layer")
end
print("Native window templates OK")

local oldAlt=IsAltKeyDown
local b=T.buttons["0:1"]
IsAltKeyDown=function() return true end
T:UpdateItemInteraction(b); assert(b.interactionLayer.interceptsRight and #b.interactionLayer.passThrough==0)
IsAltKeyDown=function() return false end
local oldBank=T.atBank; T.atBank=true
T:UpdateItemInteraction(b); assert(b.interactionLayer.interceptsRight)
T.atBank=false; T:UpdateItemInteraction(b)
assert(not b.interactionLayer.interceptsRight and b.interactionLayer.passThrough[1]=="RightButton")
T.atBank=oldBank; IsAltKeyDown=oldAlt
print("Native routing OK: Alt menus and bank transfer intercept right-click only outside combat")
