local T=RoadmapFixture
local button=T.buttons["0:1"]
local oldInfo,oldUse,oldModified=C_Container.GetContainerItemInfo,C_Container.UseContainerItem,IsModifiedClick
local info={itemID=9001,hyperlink="item:9001",stackCount=1}
C_Container.GetContainerItemInfo=function(bag,slot) assert(bag==0 and slot==1); return info end
IsModifiedClick=function() return false end
local calls=0
C_Container.UseContainerItem=function(bag,slot) assert(bag==0 and slot==1); calls=calls+1 end
assert(button.scripts.OnClick==button.nativeClick,"native use handler must remain untouched")
button.scripts.OnClick(button,"RightButton"); assert(calls==1)
info=nil; button.scripts.OnClick(button,"RightButton"); assert(calls==1)
info={itemID=9002,hyperlink="item:9002",stackCount=1}
button.scripts.OnClick(button,"RightButton"); assert(calls==2)
assert(not button:GetAttribute("type2") and button.interactionLayer.passThrough[1]=="RightButton")
C_Container.GetContainerItemInfo,C_Container.UseContainerItem,IsModifiedClick=oldInfo,oldUse,oldModified
print("Native item use OK: untouched script, exact physical slot, empty and replenished slots, no custom secure action")
