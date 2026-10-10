local T=RoadmapFixture
local button=T.buttons["0:1"]
local oldInfo=C_Container.GetContainerItemInfo
local oldDirect=T.CanUseItemDirectly
local info={itemID=9001,hyperlink="item:9001",stackCount=1}
local allow=true
C_Container.GetContainerItemInfo=function(bag,slot)
    assert(bag==0 and slot==1,"use must check the clicked physical slot")
    return info
end
T.CanUseItemDirectly=function() return allow end
local calls=0
local function click()
    button.scripts.PreClick(button,"RightButton")
    if button:GetAttribute("type2")=="item" then
        assert(info and info.hyperlink,"C_Item.IsEquippableItem received nil from empty slot")
        calls=calls+1
    end
end
click(); assert(calls==1)
-- The displayed model can be stale after consumption, before the next render.
info=nil
click(); assert(calls==1 and button:GetAttribute("type2")=="")
info={itemID=9002}
click(); assert(calls==1 and button:GetAttribute("type2")=="")
info={itemID=9002,hyperlink="item:9002",stackCount=1}
click(); assert(calls==2 and button:GetAttribute("type2")=="item")
allow=false
click(); assert(calls==2 and button:GetAttribute("type2")=="")
allow=true; click(); assert(calls==3)
C_Container.GetContainerItemInfo=oldInfo; T.CanUseItemDirectly=oldDirect
print("Secure item use OK: live empty slot, stale model, replenished slot and interaction-context guard")
