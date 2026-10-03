local _, A = ...

-- DefaultPanelTemplate decoration adapted from BetterBags/themes/default.lua.
-- Copyright (c) 2023 Antonio Lobato. MIT; see THIRD_PARTY_NOTICES.md.
local darkBackground,darkBorder={0.035,0.04,0.055},{0.25,0.27,0.32}
local sectionBackdrop={bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1}

function A:DecorateInventory()
    local frame=self.window
    local decoration=CreateFrame("Frame",nil,frame,"DefaultPanelTemplate")
    decoration:SetAllPoints(frame)
    decoration:SetFrameLevel(math.max(0,frame:GetFrameLevel()-1))
    decoration:EnableMouse(false)
    for _,key in ipairs({"TitleContainer","NineSlice","PortraitContainer"}) do
        local child=decoration[key]
        if type(child)=="table" or type(child)=="userdata" then child:EnableMouse(false) end
    end
    local title=decoration.TitleContainer
    if type(title)=="table" and title.TitleText then title.TitleText:SetText("") end
    local close=decoration.CloseButton
    if type(close)=="table" then close:Hide() end
    frame:SetBackdrop(nil)
    self.decoration=decoration
    local caption=CreateFrame("Frame",nil,frame)
    caption:SetPoint("TOPLEFT",48,-4)
    caption:SetPoint("TOPRIGHT",-34,-4)
    caption:SetHeight(24)
    caption:SetFrameLevel(frame:GetFrameLevel()+5)
    caption:EnableMouse(false)
    self.titleCaptionFrame=caption
    self.windowTitle=caption:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
    self.windowTitle:SetPoint("CENTER")
    self.windowTitle:SetText(self:BackpackTitle())
end

function A:StyleCategory(panel,data)
    if panel.blockStyled~=true then
        panel:SetBackdrop(sectionBackdrop)
        panel.headerShade=panel:CreateTexture(nil,"BACKGROUND",nil,2)
        panel.headerShade:SetPoint("TOPLEFT",1,-1)
        panel.headerShade:SetPoint("TOPRIGHT",-1,-1)
        panel.headerShade:SetHeight(22)
        panel.headerShade:SetColorTexture(1,1,1,0.035)
        panel.blockStyled=true
    end
    local color=data.tint
    local theme,background,border,font=self:ThemeColors()
    if theme=="blizzard" then panel:SetBackdropColor(0.045,0.05,0.065,0.94)
    else
        panel:SetBackdropColor(background[1] or background.r,background[2] or background.g,background[3] or background.b,0.94)
    end
    panel.title:SetFont(theme=="blizzard" and STANDARD_TEXT_FONT or font,12,"")
    panel.tintBackground:SetShown(color~=nil)
    if color then panel.tintBackground:SetColorTexture(color.r,color.g,color.b,0.16) end
    panel.title:SetTextColor(1,0.82,0.4)
    if self.draft then panel:SetBackdropBorderColor(0.25,0.65,0.65,0.9)
    else panel:SetBackdropBorderColor(0.25,0.27,0.32,0.65) end
end

function A:StyleCommand(button,title)
    button:SetBackdrop(sectionBackdrop)
    button:SetBackdropColor(0.09,0.1,0.13,0.98)
    button:SetBackdropBorderColor(0.32,0.35,0.4,0.8)
    local font=button:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    font:SetPoint("CENTER")
    button:SetFontString(font)
    button:SetNormalFontObject("GameFontHighlightSmall")
    button:SetDisabledFontObject("GameFontDisableSmall")
    button:SetHighlightFontObject("GameFontNormalSmall")
    button:SetText(title)
    button:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
end

function A:UpdateHeaderLayers()
    local level=self.window:GetFrameLevel()
    if self.decoration then
        self.decoration:SetFrameLevel(math.max(0,level-1))
        for _,key in ipairs({"NineSlice","TitleContainer","PortraitContainer"}) do
            local child=self.decoration[key]
            if type(child)=="table" or type(child)=="userdata" then child:SetFrameLevel(level+10); child:EnableMouse(false) end
        end
    end
    if self.titleCaptionFrame then self.titleCaptionFrame:SetFrameLevel(level+20) end
    if self.titleDrag then self.titleDrag:SetFrameLevel(level+21) end
    if self.bagMenuButton then self.bagMenuButton:SetFrameLevel(level+30) end
    if self.closeButton then self.closeButton:SetFrameLevel(level+30) end
end

function A:ThemeColors()
    local theme=self:GetSettings().theme or "blizzard"
    local engine=theme=="elvui" and ElvUI and ElvUI[1]
    local media=engine and engine.media
    return theme,media and media.backdropcolor or darkBackground,media and media.bordercolor or darkBorder,
        media and media.normFont or STANDARD_TEXT_FONT
end

function A:ApplyWindowTheme()
    local theme,background,border,font=self:ThemeColors()
    if self.appliedTheme==theme and self.appliedThemeProfile==self.profile then return end
    self.appliedTheme,self.appliedThemeProfile=theme,self.profile
    self.windowTitle:SetFont(theme=="blizzard" and STANDARD_TEXT_FONT or font,12,"")
    self.decoration:SetShown(theme=="blizzard")
    if theme=="blizzard" then self.window:SetBackdrop(nil)
    else
        self.window:SetBackdrop(sectionBackdrop)
        self.window:SetBackdropColor(background[1] or background.r,background[2] or background.g,background[3] or background.b,0.98)
        self.window:SetBackdropBorderColor(border[1] or border.r,border[2] or border.g,border[3] or border.b,1)
    end
end
