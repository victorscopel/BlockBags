local _, A = ...

function A:UpdateEditorGrid()
    if not self.draft then
        if self.editorGrid then self.editorGrid:Hide() end
        return
    end
    local f=self.editorGrid
    if not f then
        f=CreateFrame("Frame",nil,self.canvas)
        f:SetAllPoints(self.canvas); f:SetFrameLevel(self.canvas:GetFrameLevel())
        f:EnableMouse(false); f:SetClipsChildren(true); f.lines={}; self.editorGrid=f
    end
    f:Show()
    if f.drawWidth==self.canvasWidth and f.drawHeight==self.canvasHeight then return end
    f.drawWidth,f.drawHeight=self.canvasWidth,self.canvasHeight
    for _,line in ipairs(f.lines) do line:Hide() end
    local step=20
    while math.max(self.canvasWidth,self.canvasHeight)/step>128 do step=step*2 end
    local count=0
    local function draw(vertical,index)
        count=count+1
        local line=f.lines[count]
        if not line then line=f:CreateTexture(nil,"BACKGROUND"); f.lines[count]=line end
        line:SetColorTexture(0.4,0.8,0.8,index%5==0 and 0.2 or 0.09)
        line:ClearAllPoints(); line:SetPoint("TOPLEFT",f,"TOPLEFT",vertical and index*step or 0,vertical and 0 or -index*step)
        line:SetSize(vertical and 1 or self.canvasWidth,vertical and self.canvasHeight or 1); line:Show()
    end
    for i=0,math.floor(self.canvasWidth/step) do draw(true,i) end
    for i=0,math.floor(self.canvasHeight/step) do draw(false,i) end
end

function A:BuildEditorVisuals()
    if self.editorVisuals then return end
    local f=CreateFrame("Frame",nil,self.canvas)
    f:SetAllPoints(self.canvas); f:SetFrameLevel(self.window:GetFrameLevel()+50); f:EnableMouse(false)
    f.guides={}
    for i=1,8 do local line=f:CreateTexture(nil,"OVERLAY"); line:SetColorTexture(0.25,0.95,0.9,0.65); line:Hide(); f.guides[i]=line end
    local preview=CreateFrame("Frame",nil,f,"BackdropTemplate")
    preview:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8"})
    preview:SetBackdropColor(0.04,0.06,0.08,0.92)
    preview:EnableMouse(false); preview:SetClipsChildren(true); preview.lines={}; preview.slots={}
    preview.caption=f:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    preview.caption:SetPoint("BOTTOMLEFT",preview,"TOPLEFT",0,8)
    f.preview=preview; f:Hide(); self.editorVisuals=f
end

function A:HideEditorVisuals()
    if self.editorVisuals then self.editorVisuals:Hide() end
end

function A:UpdateEditorVisuals(id,candidate,resize,valid,free)
    self:BuildEditorVisuals()
    local f=self.editorVisuals
    f:Show()
    for _,line in ipairs(f.guides) do line:Hide() end
    local x,y,w,h=self:PanelRect(candidate)
    local used=0
    local function guide(vertical,coordinate)
        if used>=#f.guides then return end
        used=used+1
        local line=f.guides[used]; line:ClearAllPoints()
        line:SetPoint("TOPLEFT",f,"TOPLEFT",vertical and coordinate or 0,vertical and 0 or -coordinate)
        line:SetSize(vertical and 1 or self.canvasWidth,vertical and self.canvasHeight or 1); line:Show()
    end
    local gap=self:GetSettings().categorySpacing or 0
    if not free then
        for other,d in pairs(self:GetLayout()) do
            if other~=id and not d.hidden then
                local ox,oy,ow,oh=self:PanelRect(d)
                if math.abs(x-ox)<0.5 then guide(true,x) end
                if math.abs(x+w-ox-ow)<0.5 then guide(true,x+w) end
                if math.abs(x+w+gap-ox)<0.5 then guide(true,x+w); if gap>0 then guide(true,ox) end end
                if math.abs(x-ox-ow-gap)<0.5 then guide(true,x); if gap>0 then guide(true,ox+ow) end end
                if math.abs(y-oy)<0.5 then guide(false,y) end
                if math.abs(y+h-oy-oh)<0.5 then guide(false,y+h) end
                if math.abs(y+h+gap-oy)<0.5 then guide(false,y+h); if gap>0 then guide(false,oy) end end
                if math.abs(y-oy-oh-gap)<0.5 then guide(false,y); if gap>0 then guide(false,oy+oh) end end
            end
        end
    end
    local p=f.preview
    p:SetShown(resize); p.caption:SetShown(resize)
    if not resize then return end
    local m=self:ItemMetrics(candidate)
    p:ClearAllPoints(); p:SetPoint("TOPLEFT",f,"TOPLEFT",x+self.padding,-y-self.header-self.padding)
    p:SetSize(m.width,m.height)
    for _,line in ipairs(p.lines) do line:Hide() end
    for _,slot in ipairs(p.slots) do slot:Hide() end
    for index=1,math.min(m.cols*m.rows,4096) do
        local slot=p.slots[index]
        if not slot then
            slot=p:CreateTexture(nil,"ARTWORK")
            slot:SetTexture("Interface\\Buttons\\UI-EmptySlot")
            p.slots[index]=slot
        end
        local column,row=(index-1)%m.cols,math.floor((index-1)/m.cols)
        slot:ClearAllPoints(); slot:SetPoint("TOPLEFT",p,"TOPLEFT",column*m.step,-row*m.step)
        slot:SetSize(m.size,m.size)
        slot:SetVertexColor(valid and 0.85 or 1,valid and 0.95 or 0.35,valid and 1 or 0.35,0.95)
        slot:Show()
    end
    local n=0
    local function grid(vertical,index,closing)
        n=n+1
        local line=p.lines[n]
        if not line then line=p:CreateTexture(nil,"BACKGROUND"); p.lines[n]=line end
        line:SetColorTexture(valid and 0.3 or 1,valid and 0.8 or 0.25,0.65,0.45)
        local coordinate=closing and (index-1)*m.step+m.size or index*m.step
        line:ClearAllPoints(); line:SetPoint("TOPLEFT",p,"TOPLEFT",vertical and coordinate or 0,vertical and 0 or -coordinate)
        line:SetSize(vertical and 1 or (m.cols-1)*m.step+m.size,vertical and (m.rows-1)*m.step+m.size or 1); line:Show()
    end
    for i=0,math.min(m.cols,64)-1 do grid(true,i) end
    for i=0,math.min(m.rows,64)-1 do grid(false,i) end
    -- Draw the closing edges around the last full slot; leftover pixels stay shaded.
    grid(true,math.min(m.cols,64),true); grid(false,math.min(m.rows,64),true)
    p.caption:SetText(string.format(A.L["%d × %d px\n%d colunas × %d linhas · %d slots%s"],w,h,m.cols,m.rows,m.cols*m.rows,valid and "" or A.L["\nÁrea ocupada"]))
    p.caption:SetTextColor(valid and 0.8 or 1,valid and 1 or 0.35,0.8)
end
