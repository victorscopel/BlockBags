local T=RoadmapFixture
local oldTime,oldDate=GetServerTime,date
local clock=10000000
GetServerTime=function() return clock end; date=function(_,value) return tostring(value) end
local cache=T:GetOfflineCache(); assert(not cache.enabled and cache.maxItems==6000 and cache.maxCharacters==5 and cache.retentionDays==30)
assert(not T:CaptureOfflineSnapshot())
cache.enabled=true
assert(T:CaptureOfflineSnapshot())
local key=T.characterKey..":bags"
local snapshot=cache.snapshots[key]; assert(snapshot and #snapshot.items==4 and snapshot.items[1].offline)
local fields=snapshot.items[1]; assert(not fields.identity and not fields.tooltipText)
clock=clock+100; assert(T:CaptureOfflineSnapshot() and cache.snapshots[key]==snapshot and snapshot.at==clock)
local originalCount=fields.info.stackCount
T.items[1].info.stackCount=99; assert(fields.info.stackCount==originalCount)
assert(T:CaptureOfflineSnapshot() and cache.snapshots[key]~=snapshot)
local updated=cache.snapshots[key]
T.items[1].itemLevel=777; T.items[1].equipmentSet="Test set"; T.items[1].upgrade=true
assert(T:CaptureOfflineSnapshot() and cache.snapshots[key]~=updated)
assert(cache.snapshots[key].items[1].itemLevel==777 and cache.snapshots[key].items[1].equipmentSet=="Test set" and cache.snapshots[key].items[1].upgrade)
local export=T:ExportProfile(); assert(not export:find("snapshots",1,true))
-- The viewer uses at most one viewport of generic, read-only buttons.
local source=cache.snapshots[key].items[1]
for n=1,600 do local entry=T:Copy(source); entry.name="Cached "..n; cache.snapshots[key].items[n]=entry end
T:OpenOfflineInventory()
local f=T.offlineWindow; assert(#f.filtered==600)
local controls=0
for _,b in pairs(f.buttons) do controls=controls+1; assert(not b.scripts.OnClick and not b.scripts.OnDragStart and not rawget(b,"attributes")) end
assert(controls==108)
local frames=createdFrames
for n=1,100 do f.scroll.GetVerticalScroll=function() return (n%20)*44 end; T:DrawOfflineItems(); T:RefreshOfflineWindow() end
assert(createdFrames==frames)
f.scripts.OnHide(); assert(#f.filtered==0)
for _,button in pairs(f.buttons) do assert(not rawget(button,"item")) end
T:RefreshOfflineWindow()
f.search:SetText("Cached 600"); T:RefreshOfflineWindow(); assert(#f.filtered==1)
-- Snapshot limits discard whole oldest records rather than silently truncating them.
cache.maxCharacters=2; cache.snapshots={}
for n=1,5 do cache.snapshots["Char"..n]={character="Char"..n,storage="bags",at=clock+n,items={T:Copy(source)}} end
T:PruneOfflineCache(); local count=0; for _ in pairs(cache.snapshots) do count=count+1 end
assert(count==2 and cache.snapshots.Char5 and cache.snapshots.Char4)
cache.snapshots.account={character="Char5",storage="account",at=clock+10,items={T:Copy(source)}}
T:PruneOfflineCache(); assert(cache.snapshots.account and cache.itemCount==3)
cache.maxItems=500
for n=1,501 do cache.snapshots.account.items[n]=T:Copy(source) end
T:PruneOfflineCache(); assert(not cache.snapshots.account and cache.itemCount<=500)
cache.snapshots.expired={character="Expired",storage="character",at=clock-91*86400,items={}}
T:PruneOfflineCache(); assert(not cache.snapshots.expired)
-- Invalid settings are clamped; an active cursor never overwrites a snapshot.
T:SetOfflineOption("maxItems",1); assert(cache.maxItems==500)
T:SetOfflineOption("retentionDays",999); assert(cache.retentionDays==90)
local oldCursor=CursorHasItem; CursorHasItem=function() return true end
assert(not T:CaptureOfflineSnapshot())
CursorHasItem=oldCursor
T:ClearOfflineCache(); assert(not next(cache.snapshots) and cache.itemCount==0)
GetServerTime,date=oldTime,oldDate
print("Offline OK: opt-in, immutable physical snapshots, unchanged visits reuse records, exports omit history, read-only viewport capped at108 buttons, 100 scrolls/reopens reuse frames, character/item/age bounds and shared Warband snapshot, oversized/expired records discarded, cursor guards and explicit clearing")
