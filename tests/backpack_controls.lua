local nativeName=TEST_LOCALE=="ptBR" and "Mochila nativa" or "Native backpack"
BAG_NAME_BACKPACK=nativeName
A.storage="bags"; A.window:Show(); A:PaintStorageSelector()
assert(A.windowTitle:GetText()==nativeName and A:BackpackTitle()==nativeName)
BAG_NAME_BACKPACK=nil
assert(A:BackpackTitle()==A.L["Mochila"])
A:PaintStorageSelector(); assert(A.windowTitle:GetText()==A.L["Mochila"])
-- The Blizzard bar setting is independent of the temporary physical-bag view.
BagsBar=CreateFrame("Frame")
local registrations,removals=0,0
RegisterStateDriver=function(frame,state,condition)
    assert(frame==BagsBar and state=="visibility" and condition=="hide")
    registrations=registrations+1; frame:Hide()
end
UnregisterStateDriver=function(frame,state)
    assert(frame==BagsBar and state=="visibility")
    removals=removals+1
end
A.integrationInstalled=true; A.integrationBlocked=false
A.profile.settings.showBlizzardBagBar=nil; A.bagBarVisibilityManaged=nil
A:ApplyBlizzardBagBarVisibility()
assert(not BagsBar:IsShown() and registrations==1)
A:ApplyBlizzardBagBarVisibility(); assert(registrations==1)
local physical=A.physicalBagView
local entries={}
MenuUtil.CreateContextMenu=function(_,generator)
    local root={CreateDivider=function() end,CreateButton=function() end}
    function root:CreateCheckbox(title,checked,callback) entries[title]={checked=checked,click=callback} end
    generator(nil,root)
end
A.bagMenuButton.scripts.OnClick(A.bagMenuButton,"LeftButton")
local setting=entries[A.L["Mostrar barra de bolsas do WoW"]]
assert(setting and not setting.checked() and entries[A.L["Visualização por bolsa"]])
setting.click()
assert(setting.checked() and BagsBar:IsShown() and removals==1 and A.physicalBagView==physical)
local decoded=A:DecodeProfile(A:ExportProfile())
assert(decoded.settings.showBlizzardBagBar==true)
A.profile.settings.showBlizzardBagBar=false
InCombatLockdown=function() return true end
A:ApplyBlizzardBagBarVisibility()
assert(A.pendingBagBarVisibility and BagsBar:IsShown() and registrations==1)
InCombatLockdown=function() return false end
A:ApplyBlizzardBagBarVisibility()
assert(not A.pendingBagBarVisibility and not BagsBar:IsShown() and registrations==2)
-- Window scripts play native sounds only for backpack transitions.
local played={}
SOUNDKIT={IG_BACKPACK_OPEN=862,IG_BACKPACK_CLOSE=863}
PlaySound=function(sound) played[#played+1]=sound end
A.openingSettings=nil; A.settingsInventorySession=nil
A.window:Show(); A.window.scripts.OnShow()
A.window:Hide(); A.window.scripts.OnHide()
assert(#played==2 and played[1]==862 and played[2]==863)
A.openingSettings=true
A.window.scripts.OnShow(); A.window.scripts.OnHide()
assert(#played==2)
A.openingSettings=nil; A.settingsInventorySession={}
A:PlayBackpackSound(true); A:PlayBackpackSound(false)
assert(#played==2)
A.settingsInventorySession=nil
A.bankController:PlayBackpackSound(true)
assert(#played==2)
print("Backpack controls OK: native localized title, Blizzard bar hidden by default, menu setting persists independently of physical view, secure visibility deferred in combat, native open/close sounds and quiet settings/bank")
