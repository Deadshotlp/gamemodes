-- Paar Funktionen BLiBlaBluB

PD.UI = {}
PD.UI.Colors = {}
PD.UI.Colors["Text"] = Color(255, 255, 255)
PD.UI.Colors["Button"] = Color(120, 133, 150)
PD.UI.Colors["ButtonHover"] = Color(255, 255, 255)
-- PD.UI.Colors["ButtonSelect"] = Color()
PD.UI.Colors["Grey1"] = Color(41, 59, 75)
PD.UI.Colors["Grey2"] = Color(1, 1, 3)
PD.UI.Colors["Grey3"] = Color(65, 90, 122)
PD.UI.Colors["Background"] = Color(3, 16, 16)
PD.UI.Colors["Green"] = Color(0, 162, 100)
PD.UI.Colors["SithRed"] = Color(255, 38, 6)
PD.UI.Colors["JediBlue"] = Color(1, 35, 162)
PD.UI.Colors["Black"] = Color(0, 0, 0)
-- PD.UI.Colors[""] = Color()
-- PD.UI.Colors[""] = Color()

local w = 1920
local h = 1080

function PD.W(sw)
    return ScrW() * ((sw or 0) / w)
end

function PD.H(sh)
    return ScrH() * ((sh or 0) / h)
end

local blur = Material("pp/blurscreen")
function PD.DrawBlur(panel, amount, ax, ay, w, h)
    local x, y = 20, 0

    if panel then
        x, y = panel:LocalToScreen(0, 0)
    end

    local scrW, scrH = ScrW(), ScrH()

    if ax and ay then
        x = ax
        y = ay
    end

    if w and h then
        scrW = w
        scrH = h
    end

    surface.SetDrawColor(255, 255, 255)
    surface.SetMaterial(blur)

    for i = 1, 3 do
        blur:SetFloat("$blur", (i / 3) * (amount or 6))
        blur:Recompute()
        render.UpdateScreenEffectTexture()

        render.SetScissorRect( x, y, x + scrW, y + scrH, true )
			surface.DrawTexturedRect( 0, 0, scrW, scrH )
		render.SetScissorRect( 0, 0, 0, 0, false )
    end
end

function PD.Tab(base)
    local tabs = {}

    local bar = base:Add("DPanel")
    bar:Dock(TOP)
    bar:DockMargin(0, 0, 0, 0)
    bar:SetTall(PD.H(50))
    bar.Paint = function(self, w, h)
        draw.RoundedBox(3, 0, 0, w, h, CONFIG:GetConfig("primarycolor"))
    end

    local scrl = PD.ScrollHorizontal(bar)

    function PD.AddTabItem(id, name, func)
        local btn = PD.Button(name, scrl, function(self)
            -- for k, v in pairs(tabs) do
            --     if v ~= self then
            --         v:Deactivate()
            --     end
            -- end

            --func()

            -- self:Activate()
            PD.SelectTabItem(id)

        end, function(self, w, h)
            if self:GetToggle() then
                self.status = math.Clamp(self.status + (50 / 5) * FrameTime(), 0, 1)
                draw.RoundedBox(5, w / 2 - w / 2 * self.status, h - 3, w * self.status, 3, CONFIG:GetConfig("colorred"))
            end

            if self:IsHovered() and not self:GetToggle() then
                self.status = math.Clamp(self.status + (self.speed / 5) * FrameTime(), 0, 1)
                draw.RoundedBox(5, w / 2 - w / 2 * self.status, h - 3, w * self.status, 5, CONFIG:GetConfig("colorred"))
            elseif not self:IsHovered() and not self:GetToggle() then
                self.status = math.Clamp(self.status - (self.speed / 5) * FrameTime(), 0, 1)
                draw.RoundedBox(5, w / 2 - w / 2 * self.status, h - 3, w * self.status, 5, CONFIG:GetConfig("colorred"))
            end
        end)
        btn:Dock(LEFT)
        btn:SetWide(PD.W(200))

        btn.func = func
        btn.status = 0
        btn.speed = 2

        tabs[id] = btn

        return btn
    end

    function PD.SelectTabItem(id)
        local item = tabs[id]
        if not item then return end

        for k, v in pairs(tabs) do
            v:Deactivate()
        end

        item.func()
        item:Activate()
    end
end

function PD.SideTab(base, rightPanel)
    local tabs = {}
    local check = {}

    local pnl = PD.Panel("", base)
    pnl:Dock(LEFT)
    pnl:SetWide(PD.W(200))

    local scrl = PD.Scroll(pnl)

    function PD.AddSideItem(name, func)
        tabs[name] = {
            name = name,
            func = func,
            level = 0
        }

        PD.ShowItem()
    end

    function PD.AddSubItem(parentName, name, func)
        -- Prüfen, ob der Parent existiert und dessen Level erben
        local parentTab = tabs[parentName]
        local parentLevel = parentTab and parentTab.level or 0

        tabs[parentName .. "_" .. name] = {
            name = name,
            func = func,
            parent = parentName,  -- Referenz auf den Parent-Button
            level = parentLevel + 1  -- Level des Parent + 1
        }

        PD.ShowItem()
    end

    local function deactive()
        for k, v in pairs(check) do
            v:Deactivate()
        end
    end

    function PD.ShowItem()
        for k, v in SortedPairs(tabs) do
            if check[k] then continue end

            local btn = PD.Button(v.name, scrl, function(self)
                rightPanel:Clear()

                deactive()

                self:Activate()

                v.func(rightPanel)
            end)
            btn:Dock(TOP)
            btn.func = v.func

            if v.level > 0 then
                local indent = PD.H(30) * v.level
                btn:DockMargin(indent, PD.H(5), PD.W(5), PD.H(5))
            end

            check[k] = btn
        end
    end

    function PD.SelectItem(name)
        local item = tabs[name]
        if not item then return end

        item.func(rightPanel)

        if not check[name] then return end

        check[name]:Activate()
    end

    function PD.Print()
        PrintTable(tabs)
        print("------------------------------------------------------")
        local scrl = scrl:GetChildren()
        PrintTable(scrl)
    end

    return pnl
end

function PD.Frame(title, w, h, close, paint, test)
    local Mbase = vgui.Create("DFrame")
    Mbase:SetSize(w,h)
    if not test then
        Mbase:Center()
        Mbase:MakePopup()
    end
    Mbase:SetTitle("")  
    Mbase:ShowCloseButton(false) 
    Mbase:SetDraggable(false)
    Mbase:SetMinWidth(PD.W(600))
    Mbase:SetMinHeight(PD.H(300))
    Mbase:SetSizable(false)
    Mbase:DockPadding(0, 0, 0, 0)
    Mbase.backcol = PD.UI.Colors["Background"]
    Mbase.Blur = false

    Mbase.Paint = function(self,sw,sh)
        if self.Blur then
            PD.DrawBlur(self, 6)
        else
            draw.RoundedBoxEx(PD.H(5), 0, 0, w, h, self.backcol, false, false, true, true)
        end

        if paint then
            paint(self,w,h)
        end
    end

    Mbase.tobbarcol = PD.UI.Colors["Grey2"]
    Mbase.algn = "left"

    local topPanel = vgui.Create("DPanel", Mbase)
    topPanel:SetSize(Mbase:GetWide(), PD.H(30))
    topPanel:Dock(TOP)
    topPanel.Paint = function(self, w, h)
        draw.RoundedBoxEx(PD.H(5), 0, 0, w, h, Mbase.tobbarcol, true, true, false, false)
        
        if self:IsDraggable() and self:IsHovered() then
            self:SetCursor("sizeall")
        end

        local tit = title or "Kein Title"

        if Mbase.algn == "left" then
            draw.DrawText(tit,"MLIB.25",PD.W(10),h/2-PD.H(12.5), PD.UI.Colors["Text"],TEXT_ALIGN_LEFT)
        elseif Mbase.algn == "center" then
            draw.DrawText(tit,"MLIB.25",w/2,h/2-PD.H(12.5),PD.UI.Colors["Text"],TEXT_ALIGN_CENTER)
        elseif Mbase.algn == "right" then
            draw.DrawText(tit,"MLIB.25",w-PD.W(10),h/2-PD.H(12.5),PD.UI.Colors["Text"],TEXT_ALIGN_RIGHT)
        end
    end
    
    topPanel.Think = function()
        if Mbase:IsDraggable() then
            if topPanel:IsHovered() and input.IsButtonDown(MOUSE_LEFT) then
                Mbase:SetPos(gui.MouseX() - Mbase:GetWide()/2, gui.MouseY() - 10)
            end
        end
    end

    if close then
        local close = vgui.Create("DButton",topPanel)
        close:SetSize(PD.H(30),PD.H(30))
        close:SetPos(Mbase:GetWide() - PD.W(30),0)
        close:SetText("")
        close.Paint = function(self,w,h)
            if self:IsHovered() then
                draw.RoundedBox(5,0,0,w,h,Color(255,0,0))
            end

            draw.DrawText("X","MLIB.25",w/2,h/2-PD.H(12.5),PD.UI.Colors["Text"],TEXT_ALIGN_CENTER)
        end
        close.DoClick = function()
            if isfunction(Mbase.OnClose) then
                Mbase:OnClose()
            end
            Mbase:Remove()
        end

        Mbase.PerformLayout = function(self)
            close:SetPos(self:GetWide() - PD.H(30) , 0)
        end
    end

    Mbase.SetBarColor = function(self,col)
        self.tobbarcol = col
    end

    Mbase.SetBlur = function(self, bool)
        self.Blur = bool
    end

    Mbase.SetBackColor = function(self,col)
        self.backcol = col
    end

    Mbase.SetTitleAlign = function(self,algn)
        self.algn = algn
    end

    return Mbase
end

function SmoothLerp(current, target, speed, deltaTime)
    return Lerp(math.Clamp(speed * deltaTime, 0, 1), current, target)
end

function SmoothColorLerp(colA, colB, speed, deltaTime)
    local t = math.Clamp(speed * deltaTime, 0, 1)
    return Color(
        Lerp(t, colA.r, colB.r),
        Lerp(t, colA.g, colB.g),
        Lerp(t, colA.b, colB.b),
        Lerp(t, colA.a or 255, colB.a or 255)
    )
end

function PD.Button(name, wo, doclick, paint)
    local btn = wo:Add("DButton")
    btn:SetText("")

    surface.SetFont("MLIB.25")
    local tw, th = surface.GetTextSize(name)
    btn:SetTall(th + PD.H(10))
    btn:SetWide(tw + PD.W(20))
    btn:DockMargin(PD.H(5),PD.H(5),PD.H(5),PD.H(5))
    btn.bgcol = PD.UI.Colors["Button"]
    btn.bghcol = PD.UI.Colors["ButtonHover"]
    btn.textcol = PD.UI.Colors["Text"]
    btn.OutlineColor = PD.UI.Colors["Button"]
    btn.disabled = false
    btn.Active = false
    btn.visible = true
    btn.Animation = true
    btn.Font = 25
    btn.radius = PD.H(50)
    btn.disabledBackground = false
    btn.TextAlign = TEXT_ALIGN_CENTER
    local posX = PD.W(10)
    local tc = btn.OutlineColor

    local middle = Color(0,0,0,255)
    local mainW, mainH = 0, 0
    local moveW, moveH = PD.W(4), PD.H(4)
    -- local font = btn.Font * 0.7
    btn.Paint = function(self, w, h)
        mainW, mainH = w, h
        local time, moveTime = 1.5, 5 * FrameTime()

        if self.visible and !self.disabledBackground then
            -- draw.RoundedBox(self.radius + 2, 0, 0, w, h, self.OutlineColor)
            -- draw.RoundedBox(self.radius, PD.W(2), PD.H(2), w - PD.W(4), h - PD.H(4), middle)

            draw.RoundedBox(self.radius, PD.W(0) + moveW, PD.H(0) + moveH, w - moveW * 2, h - moveH * 2, tc)
            draw.RoundedBox(self.radius - 4, PD.W(2) + moveW, PD.H(2) + moveH, w - PD.W(4) - moveW * 2, h - PD.H(4) - moveH * 2, middle)
        end

        if self.disabled then 
            self:SetCursor("no")
        else
            self:SetCursor("hand")
            if self:IsHovered() or self.Active then
                -- tc = PD.UI.Colors["Background"]

                -- draw.RoundedBox(self.radius - 4, PD.W(5), PD.H(5), w - PD.W(10), h - PD.H(10), self.bghcol)

                if self.Animation then
                    -- font = SmoothLerp(font, self.Font, time, moveTime)

                    tc = SmoothColorLerp(tc, self.bghcol, 5, FrameTime())
                    moveW = SmoothLerp(moveW, 0, time, moveTime)
                    moveH = SmoothLerp(moveW, 0, time, moveTime)
                end
               
            else
                self.bgcol = PD.UI.Colors["Button"]
                tc = self.textcol
                middle = Color(0,0,0,255)
                
                if self.Animation then
                    -- font = SmoothLerp(font, self.Font * 0.7, time, moveTime)
                    tc = SmoothColorLerp(tc, self.OutlineColor, 5, FrameTime())
                    moveW = SmoothLerp(moveW, PD.W(4), time, moveTime)
                    moveH = SmoothLerp(moveW, PD.H(4), time, moveTime)
                end
            end
        end

        if paint then
            paint(self, w, h)
        end

        if self.TextAlign == TEXT_ALIGN_LEFT then
            posX = PD.W(10)
        elseif self.TextAlign == TEXT_ALIGN_CENTER then
            posX = w / 2
        elseif self.TextAlign == TEXT_ALIGN_RIGHT then
            posX = w - PD.W(10)
        end

        self.name = name
        draw.DrawText(name, "MLIB." .. math.Round(self.Font), posX, h / 2 - PD.H(math.Round(self.Font) / 2), tc, self.TextAlign)
    end

    btn.SetRadius = function(self, rad)
        self.radius = rad
    end

    btn.SetTextAlign = function(self, align)
        if align == "left" then
            self.TextAlign = TEXT_ALIGN_LEFT
        elseif align == "center" then
            self.TextAlign = TEXT_ALIGN_CENTER
        elseif align == "right" then
            self.TextAlign = TEXT_ALIGN_RIGHT
        end
    end 

    btn.SetBackgroundDisabled = function(self, bool)
        self.disabledBackground = bool
    end

    btn.SetVisible = function(self, bool)
        self.visible = bool
    end

    btn.SetDisabled = function(self, bool)
        self.disabled = bool

        if bool then
            self.bgcol = Color(33,33,33)
        else
            self.bgcol = CONFIG:GetConfig("hovercolor")
        end
    end

    btn.SetOutlineColor = function(self, col)
        self.OutlineColor = col
    end

    btn.GetOutlineColor = function(self)
        return self.OutlineColor
    end

    btn.SetTextColor = function(self,col)
        self.textcol = col
    end

    btn.GetTextColor = function(self)
        return self.textcol
    end

    btn.SetHoverColor = function(self,col)
        self.bghcol = col
    end

    btn.GetHoverColor = function(self)
        return self.bghcol
    end

    btn.SetBackColor = function(self,col)
        self.bgcol = col
    end

    btn.GetBackColor = function(self)
        return self.bgcol
    end

    btn.OnCursorEntered = function(self)
        if not self.disabled then
            surface.PlaySound("mario/lk_click.mp3")
        end
    end

    btn.DoClickInternal = function(self)
        if not self.disabled then
            surface.PlaySound("mario/lk_click.mp3")
        end
    end

    btn.Activate = function(self)
        self.Active = true
    end

    btn.Deactivate = function(self)
        self.Active = false
    end

    btn.DeactivateAnimation = function(self)
        self.Animation = false
    end

    btn.Toggle = function(self)
        if self.Active then
            self.Active = false
        else
            self.Active = true
        end
    end

    btn.GetToggle = function(self)
        return self.Active
    end

    btn.DoClick = function()
        if btn.disabled then return end
        if doclick then
            doclick(btn)
        end
    end

    btn.GetText = function()
        return name
    end

    btn.SetText = function(self, text)
        name = text
    end

    return btn
end

function PD.Panel(title, wo, paint)
    local pnl = wo:Add("DPanel")
    pnl:Dock(TOP)
    pnl:DockMargin(PD.W(5),PD.H(5),PD.W(5),PD.H(5))
    pnl:SetSize(wo:GetWide(),PD.H(50))
    pnl:SetText("")
    pnl.bgcol = PD.UI.Colors["Grey1"]
    pnl.title = title
    pnl.radius = 5

    pnl.Paint = function(self,w,h)
        draw.RoundedBox(self.radius,0,0,w,h,self.bgcol)

        if paint then
            paint(self,w,h)
        end
    end

    pnl.SetRadius = function(self, rad)
        self.radius = rad
    end

    pnl.SetTitle = function(self,titl)
        self.title = titl
        -- print("dadad")
    end

    if #pnl.title > 0 then
        local tit = PD.Label(pnl.title,pnl)
    end

    pnl.SetBackColor = function(self,col)
        self.bgcol = col
    end

    pnl.GetBackColor = function(self,col)
        return self.bgcol.r, self.bgcol.g, self.bgcol.b, self.bgcol.a
    end

    return pnl
end

function PD.PanelButtonDesign(title, wo, paint)
    local pnl = wo:Add("DPanel")
    pnl:Dock(TOP)
    pnl:DockMargin(PD.H(5),PD.H(5),PD.H(5),PD.H(5))
    pnl:SetSize(wo:GetWide(),PD.H(50))
    pnl:SetText("")
    pnl.bgcol = PD.UI.Colors["Grey1"]
    pnl.OutlineColor = PD.UI.Colors["Button"]
    local middle = PD.UI.Colors["Black"]
    pnl.title = title
    pnl.noPaint = false
    pnl.radius = 100

    pnl.Paint = function(self,w,h)
        if self.noPaint then return end

        draw.RoundedBox(self.radius, 0, 0, w, h, self.OutlineColor)
        draw.RoundedBox(self.radius, PD.W(2), PD.H(2), w - PD.W(4), h - PD.H(4), middle)

        if paint then
            paint(self,w,h)
        end
    end

    pnl.SetRadius = function(self, rad)
        self.radius = rad
    end

    pnl.SetTitle = function(self,titl)
        self.title = titl
        -- print("dadad")
    end

    if #pnl.title > 0 then
        local tit = PD.Label(pnl.title,pnl)
    end

    pnl.SetBackColor = function(self,col)
        self.bgcol = col
    end

    pnl.SetNoPaint = function(self)
        self.noPaint = true
    end

    return pnl
end

function PD.Scroll(wo)
    ScrollPanel = wo:Add("DScrollPanel")
    ScrollPanel:SetSize(wo:GetWide(), wo:GetTall())
    ScrollPanel:Dock(FILL)
    local sbar = ScrollPanel:GetVBar()
    sbar:SetWide(10)
    sbar:SetHideButtons(true)

    function sbar:Paint(w, h)
        draw.RoundedBox(100, 0, 0, w, h, PD.UI.Colors["Grey1"])
    end

    function sbar.btnGrip:Paint(w, h)
        draw.RoundedBox(100, 0, 0, w, h, PD.UI.Colors["Button"])
    end
    
    return ScrollPanel
end

function PD.ScrollHorizontal(wo)
    local DHorizontalScroller = wo:Add("DHorizontalScroller")
    DHorizontalScroller:Dock(FILL)
    DHorizontalScroller:SetOverlap(-4)

    -- function DHorizontalScroller.btnLeft:Paint(w, h)
    --     draw.RoundedBoxEx(5, 0, 0, w, h, CONFIG:GetConfig("scrollup"), true, false, true, false)
    -- end
    -- function DHorizontalScroller.btnRight:Paint(w, h)
    --     draw.RoundedBoxEx(5, 0, 0, w, h, CONFIG:GetConfig("scrolldown"), false, true, false, true)
    -- end
    
    
    return DHorizontalScroller
end

function PD.SimpleCheck(wo, text, val, change)
    local value = val
    local txt = markup.Parse("<font=MLIB.20>\n<colour=255,255,255>"..text,wo:GetWide() - PD.W(20))
    local posX = PD.W(5)


    local panel = PD.Panel("", wo, function(self, w, h)
        local c = CONFIG:GetConfig("textcolor")
        txt:Draw(PD.W(70),h/2-PD.H(10),TEXT_ALIGN_LEFT)
    end)
    panel:SetTall(txt:GetHeight() + PD.H(20))
    panel:SetBackColor(Color(0, 0, 0, 0))

    local color = PD.UI.Colors["SithRed"]
    local targetX = value and PD.W(35) or PD.W(5)
    local check = PD.Button("", panel, function(self)
        value = not value

        targetX = value and PD.W(35) or PD.W(5)

        change(value)
    end, function(self, w, h)
            posX = SmoothLerp(posX, targetX, 5, FrameTime())

        if value then
            color = SmoothColorLerp(color, PD.UI.Colors["Green"], 5, FrameTime())
        else
            color = SmoothColorLerp(color, PD.UI.Colors["SithRed"], 5, FrameTime())
        end

        draw.RoundedBox(PD.H(100), PD.W(2), PD.H(2), w - PD.W(4), h - PD.H(4), color)
        draw.RoundedBox(PD.H(100), posX, h / 2 - PD.H(10), PD.H(20), PD.H(20), PD.UI.Colors["Text"])
    end)
    check:Dock(LEFT)
    check:SetWide(PD.H(60))
    check:SetHoverColor(Color(0, 0, 0, 0))
    check:SetOutlineColor(PD.UI.Colors["Text"])
    check:DeactivateAnimation()
    check:SetBackgroundDisabled(true)

    check.GetChecked = function()
        return value
    end

    check.GetValue = function()
        return value
    end

    return panel, check
end

function PD.TextEntry(pleaceholder, wo, val)
    if not pleaceholder then pleaceholder = "" end

    local Entry = wo:Add("DTextEntry")
    Entry:Dock(TOP)
    Entry:DockMargin(PD.H(5),PD.H(5),PD.H(5),PD.H(5))
    Entry:SetTall(PD.H(50))
    Entry:SetFont("MLIB.20")
    Entry:SetEditable(true)

    if val then
        Entry:SetValue(val)
    end

    Entry.Paint = function(self, w, h)
        draw.RoundedBox(20, 0, 0, w, h, PD.UI.Colors["Button"])
        draw.RoundedBox(20, PD.W(2), PD.H(2), w - PD.W(4), h - PD.H(4), PD.UI.Colors["Grey1"])

        if self:GetValue() == "" then
            draw.DrawText(pleaceholder, "MLIB.20", PD.W(10), h / 2 - PD.H(10), CONFIG:GetConfig("textcolor"), TEXT_ALIGN_LEFT)
        end 

        self:DrawTextEntryText(PD.UI.Colors["Text"], PD.UI.Colors["Button"], PD.UI.Colors["Text"])
    end

    return Entry
end

function PD.TextEntryLabel(text, wo, pleaceholder, val)

    panel = PD.Panel(text,wo)
    panel:SetTall(PD.H(120))
    entry = PD.TextEntry(pleaceholder,panel,val)
    entry:Dock(FILL)

    return panel,entry
end

function PD.ComboBox(value, wo, func)
    local tbl = {}
    local out = nil
    local search = false
    local box, menu, scrl

    local function UpdateList(filter)
        scrl:Clear()
        for k, v in pairs(tbl) do
            if not filter or string.find(string.lower(v), string.lower(filter), 1, true) then
                local btn = PD.Button(v, scrl, function(s)
                    box:SetText(v)
                    if menu then
                        menu:Remove()
                        menu = nil
                    end
                    out = v
                    func(v)
                end)
                btn:Dock(TOP)
                btn:SetTall(PD.H(30))
            end
        end
    end

    box = PD.Button(value, wo, function(self)
        if not menu then
            menu = PD.Panel("", wo)
            menu:Dock(NODOCK)
            menu:SetPos(self:GetX(), self:GetY() + PD.H(50))
            menu:SetSize(self:GetWide(), PD.H(200))
            menu:SetBackColor(Color(30,30,30))
            
            if search then
                local searchBar = PD.TextEntry("Suche...", menu)
                searchBar:Dock(TOP)
                searchBar:SetTall(PD.H(40))

                searchBar.OnChange = function(self)
                    UpdateList(self:GetValue())
                end
            end

            scrl = PD.Scroll(menu)
            UpdateList()
        else
            menu:Remove()
            menu = nil
        end
    end)
    box:Dock(TOP)
    box:SetTall(PD.H(50))

    box.AddChoice = function(self, txt)
        if table.HasValue(tbl, txt) then return end
        table.insert(tbl, txt)
    end

    box.GetChoice = function(self)
        return out or value
    end

    box.SetSearch = function(self, bool)
        search = bool
    end

    return box, box
end

function PD.Label(text, wo, col)
    MLabel = wo:Add("DLabel")
    MLabel:SetText(text)
    MLabel:SetFont("MLIB.20")
    MLabel:SetTextColor(col or PD.UI.Colors["Text"])
    MLabel:SizeToContents()
    MLabel:Dock(TOP)
    MLabel:DockMargin(PD.H(5),PD.H(5),PD.H(5),PD.H(5))

    return MLabel
end

function PD.NumSlider(text, wo, min, max, value, func)
    local minValue, maxValue = min, max
    local currentValue = value
    local isDragging = false
    local trackStartX = PD.W(5)

    local pnl = PD.Panel(text, wo, function(self, w, h)
        draw.DrawText("Value: " .. currentValue, "MLIB.15", w - PD.W(5), PD.H(5), PD.UI.Colors["Text"], TEXT_ALIGN_RIGHT)
    
        draw.RoundedBox(100, PD.W(5), h / 2, w - PD.W(10), PD.H(20), PD.UI.Colors["Grey3"])

        for i = 0, 10 do
            local x = Lerp(i / 10, PD.W(5), w - PD.W(5))
            -- draw.RoundedBox(100, x, h / 2 + PD.H(25), PD.W(2), PD.H(5), PD.UI.Colors["Text"])
            
            -- Draw Zahlen die erste ist ling und die letzte rechts

            if i == 0 then
                draw.DrawText(minValue, "MLIB.15", x, h / 2 + PD.H(20), PD.UI.Colors["Text"], TEXT_ALIGN_LEFT)
            elseif i == 10 then
                draw.DrawText(maxValue, "MLIB.15", x, h / 2 + PD.H(20), PD.UI.Colors["Text"], TEXT_ALIGN_RIGHT)
            else
                draw.DrawText(tostring(minValue + (maxValue - minValue) / 10 * i), "MLIB.15", x, h / 2 + PD.H(20), PD.UI.Colors["Text"], TEXT_ALIGN_CENTER)
            end
        end
    end)
    pnl:SetTall(PD.H(100))
    
    local slider = pnl:Add("DButton")
    slider:SetSize(PD.W(20), PD.H(20)) -- Breite und Höhe des Sliders
    slider:SetText("")
    slider.col = PD.UI.Colors["Text"]

    slider.Paint = function(self, w, h)
        draw.RoundedBox(100, 0, 0, w, h, self.col)
    end
    
    -- Das Ende der Strecke wird so angepasst, dass der Slider innerhalb bleibt
    local trackEndX = pnl:GetWide() - PD.W(15) - slider:GetWide()

    -- Funktion zur Berechnung des Wertes basierend auf der Slider-Position
    local function CalculateValue(sliderX)
        local percentage = (sliderX - trackStartX) / (trackEndX - trackStartX)
        return math.Round(minValue + (maxValue - minValue) * percentage)
    end
    
    -- Funktion zur Berechnung der Slider-Position basierend auf einem Wert
    local function CalculatePosition(value)
        local percentage = (value - minValue) / (maxValue - minValue)
        return math.Clamp(trackStartX + percentage * (trackEndX - trackStartX), trackStartX, trackEndX)
    end

    -- Initiale Position des Sliders basierend auf dem Startwert
    local initialX = CalculatePosition(currentValue)
    slider:SetPos(initialX, PD.H(50))
    
    slider.OnMousePressed = function(self)
        isDragging = true
        self.col = PD.UI.Colors["Green"]
        self:MouseCapture(true)
    end
    
    slider.OnMouseReleased = function(self)
        isDragging = false
        self.col = PD.UI.Colors["Text"]
        self:MouseCapture(false)

        if func then
            func(math.Round(currentValue))
        end
    end
    
    slider.Think = function(self)
        if isDragging then
            local mouseX = pnl:ScreenToLocal(gui.MouseX())
            mouseX = mouseX - slider:GetWide() / 2 -- Den Mittelpunkt des Sliders berechnen
            local newX = math.Clamp(mouseX, trackStartX, trackEndX) -- Begrenzen der Position
            self:SetPos(newX, self.y)
            
            currentValue = CalculateValue(newX)
        end
    end
    
    return pnl, slider
end

function PD.ColorPicker(wo,title,col,func)
    local panel = PD.Panel(title,wo)
    panel:SetTall(PD.H(150))

    local picker = panel:Add("DColorMixer")
    picker:Dock(FILL)
    picker:SetColor(col)
    picker:SetAlphaBar(true)
    picker:SetWangs(true)

    picker.Think = function(s)
		--if input.IsMouseDown( MOUSE_LEFT ) then return end

		local CR = s:GetColor()
		CR = Color(CR.r, CR.g, CR.b, CR.a)

		func(CR)
	end
    

    return panel,picker
end

function PD.SelectMulti(wo, title, value, tbl, func)
    local label = PD.Label(title,wo)

    local panel = PD.Panel("",wo)
    panel:SetTall(PD.H(300))

    local scrl = PD.Scroll(panel)

    for k, v in pairs(value) do
        local switch = PD.SimpleCheck(scrl, v, tbl[v] or false, function(val)
            tbl[v] = val
            func(tbl)
        end)
    end

    return panel
end

function PD.Binder(wo, title, value, func)
    local panel = PD.Panel(title,wo)
    panel:SetTall(PD.H(100))

    local binder = panel:Add("DBinder")
    binder:Dock(TOP)
    binder:DockMargin(PD.H(5),PD.H(5),PD.H(5),PD.H(5))
    binder:SetTall(PD.H(50))
    binder:SetValue(value)
	binder:SetFont("MLIB.20")
	binder:SetTextColor(PD.UI.Colors["Text"])
	binder.Paint = function(self,w,h)
		draw.RoundedBox(20,0,0,w,h,PD.UI.Colors["Button"])

		if self:IsHovered() then
			draw.RoundedBox(20,0,0,w,h,Color(PD.UI.Colors["ButtonHover"].r, PD.UI.Colors["ButtonHover"].g, PD.UI.Colors["ButtonHover"].b, 100))
		end
	end

    binder.OnChange = function(self,val)
        func(self,val)
    end

    return panel, binder
end

function PD.Model(wo, setmodel, x, y, w, h)
    local model = wo:Add("DModelPanel")
    model:SetPos(x, y)
    model:SetSize(w, h)
    model:DockMargin(PD.H(5),PD.H(5),PD.H(5),PD.H(5))
    model:SetModel(setmodel)
    model:SetCamPos(Vector(50,0,50))

    model.rot = 110
	model.fov = 20
	model:SetFOV( model.fov )
	model.dragging = false
	model.dragging2 = false
	model.ux = 0
	model.uy = 0
	model.spinmul = 0.4
	model.zoommul = 0.09
	model.xmod = 0
	model.ymod = 0

    function model.Entity:GetPlayerColor() return Vector (1, 0, 0) end

    local function InverseLerp( pos, p1, p2 )
        local range = 0
        range = p2-p1
        if range == 0 then return 1 end
        return ((pos - p1)/range)
    end

    function model:LayoutEntity( ent )

		local newrot = self.rot
		local newfov = self:GetFOV()

		if self.dragging == true then
			newrot = self.rot + (gui.MouseX() - self.ux)*self.spinmul
			newfov = self.fov + (self.uy - gui.MouseY()) * self.zoommul
			if newfov < 20 then newfov = 20 end
			if newfov > 75 then newfov = 75 end
		end

		local newxmod, newymod = self.xmod, self.ymod

		if self.dragging2 == true then
			newxmod = self.xmod + (self.ux - gui.MouseX())*0.02
			newymod = self.ymod + (self.uy - gui.MouseY())*0.02
		end

		newxmod = math.Clamp( newxmod, -16, 16 )
		newymod = math.Clamp( newymod, -16, 16 )

		ent:SetAngles( Angle(0,0,0) )
		self:SetFOV( newfov )

		local height = 72/2
		local frac = InverseLerp( newfov, 75, 20 )
		height = Lerp( frac, 72/2, 64 )

		local norm = (self:GetCamPos() - Vector(0,0,64))
		norm:Normalize()
		local lookAng = norm:Angle()

		self:SetLookAt( Vector(0,0,height-(2*frac) ) - Vector( 0, 0, newymod*2*(1-frac) ) - lookAng:Right()*newxmod*2*(1-frac) )
		self:SetCamPos( Vector( 64*math.sin( newrot * (math.pi/180)), 64*math.cos( newrot * (math.pi/180)), height + 4*(1-frac)) - Vector( 0, 0, newymod*2*(1-frac) ) - lookAng:Right()*newxmod*2*(1-frac) )

	end

	function model:OnMousePressed( k )
		self.ux = gui.MouseX()
		self.uy = gui.MouseY()
		self.dragging = (k == MOUSE_LEFT) or false 
		self.dragging2 = (k == MOUSE_RIGHT) or false 
	end

	function model:OnMouseReleased( k )
		if self.dragging == true then
			self.rot = self.rot + (gui.MouseX() - self.ux)*self.spinmul
			self.fov = self.fov + (self.uy - gui.MouseY()) * self.zoommul
			self.fov = math.Clamp( self.fov, 20, 75 )
		end

		if self.dragging2 == true then
			self.xmod = self.xmod + (self.ux - gui.MouseX())*0.02
			self.ymod = self.ymod + (self.uy - gui.MouseY())*0.02

			self.xmod = math.Clamp( self.xmod, -16, 16 )
			self.ymod = math.Clamp( self.ymod, -16, 16 )
		end

		self.dragging = false 
		self.dragging2 = false
	end

	function model:OnCursorExited()
		if self.dragging == true or self.dragging2 == true then
			self:OnMouseReleased()
		end
	end

    return model
end

function PD.Progress(wo, start, func)
    local progress = wo:Add("DProgress")
    progress:Dock(TOP)
    progress:DockMargin(PD.H(5),PD.H(5),PD.H(5),PD.H(5))
    progress:SetTall(PD.H(50))
    progress:SetFraction(start or 0)

    progress.OnUpdate = function(self, fraction)
        if func then
            func(fraction)
        end
    end

    progress.SetProgress = function(self, fraction)
        self:SetFraction(fraction)
        self:OnUpdate(fraction)
    end

    progress.GetProgress = function(self)
        return self:GetFraction()
    end

    return progress
end

local x, y = ScrW() - 10, ScrH() - 10
local ptbl = {}
function PD.Popup(text, color)
    for k, v in pairs(ptbl) do
        if v.text == text then
            return
        end
    end

    local barStatus = 0
	local speedBar = 1
    surface.SetFont("MLIB.20")
    local tw, th = surface.GetTextSize(text)
    local w = tw + PD.W(20)

    local posY = y - (#ptbl * PD.H(50))

    Popup = vgui.Create("DPanel")
    Popup:SetSize(w, PD.H(50))
    Popup:SetPos(x - w, posY - PD.H(50))
    Popup.Paint = function(self,w,h)
        draw.RoundedBox(0,0,0,w,h,PD.UI.Colors["Background"])

        draw.DrawText(text,"MLIB.20",w/2,h/2-PD.H(10),PD.UI.Colors["Text"],TEXT_ALIGN_CENTER)

        barStatus = math.Clamp(barStatus + (speedBar / 5) * FrameTime(), 0, 1)
		draw.RoundedBox(0, 0,h - PD.H(5), w * barStatus, PD.H(5), color)
    end

    table.insert(ptbl, {text = text, color = color, pnl = Popup})

    timer.Simple(5,function()
        local xp, yp = Popup:GetPos()
        Popup:MoveTo(xp + ScrW() + 100, yp, 3, 2)

        timer.Simple(6, function()
            for i, v in ipairs(ptbl) do
                v.pnl:MoveTo(x - w, y - (i - 1) * PD.H(50), 0.5, 0, 1)
            end

            timer.Simple(2, function()
                table.RemoveByValue(ptbl, Popup)
                Popup:Remove()
            end)
        end)
    end)

    return Popup
end

net.Receive("PD.Notify", function()
    local msg = net.ReadString()
    local col = net.ReadColor()

    local pop = PD.Popup(msg, col)
end)

PD.ImgurMaterials = {}
local errorMat = Material("debug/debugempty")
file.CreateDir("imgur_materials")

function GetImgurMaterial(id, callbackFunction)
    if PD.ImgurMaterials[id] then
        return callbackFunction(PD.ImgurMaterials[id])
    end

    if file.Exists("imgur_materials/" .. id .. ".png", "DATA") then
        PD.ImgurMaterials[id] = Material("../data/imgur_materials/" .. id .. ".png", "noclamp smooth mips")
        return callbackFunction(PD.ImgurMaterials[id])
    end

    http.Fetch("https://i.imgur.com/" .. id .. ".png",
        function(body, length)
            file.Write("imgur_materials/" .. id .. ".png", body)
            PD.ImgurMaterials[id] = Material("../data/imgur_materials/" .. id .. ".png", "noclamp smooth mips")

            return callbackFunction(PD.ImgurMaterials[id])
        end,
        function(error)
            return GetImgurMaterial(id, callbackFunction)
        end
    )
end

function PD.DrawImgur(x, y, w, h, id)
    if not PD.ImgurMaterials[id] then
        GetImgurMaterial(id, function(mat)
            PD.ImgurMaterials[id] = mat
        end)

        return
    end

    surface.SetDrawColor(255, 255, 255, 255)
    surface.SetMaterial(PD.ImgurMaterials[id])
    surface.DrawTexturedRect(x, y, w, h)
end

local function FrameMenu()
    if IsValid(TestBase) then return end

    TestBase = PD.Frame("Test UI", PD.W(600), PD.H(600), true)

    local scrl = PD.Scroll(TestBase)

    local Button = PD.Button("Test", scrl, function()
        PD.Notify("Test", CONFIG:GetConfig("colorred"))
    end)
    Button:Dock(TOP)
    Button:SetTall(PD.H(50))

    local switch = PD.SimpleCheck(scrl, "Test", false, function(val)
        print(val)
    end)

    local panel = PD.Panel("Test", scrl)

    local textlbl = PD.TextEntryLabel("Test", scrl, "Test", "Test")
    local text = PD.TextEntry("Test", scrl)

    local slider = PD.NumSlider("Test", scrl, 0, 250, 135, function(self, val)
        print(val)
    end)

    local multi = PD.SelectMulti(scrl, "Test", {"Test1", "Test2", "Test3"}, {["Test1"] = true, ["Test3"] = true}, function(val, v)
        print(val, v)
    end)

    local color = PD.ColorPicker(scrl, "Test", CONFIG:GetConfig("colorred"), function(col)
        print(col)
    end)

    local combo = PD.ComboBox("Test", TestBase, function(val)
        print(val)
    end)
    combo:SetSearch(true)

    combo:AddChoice("Test1")
    combo:AddChoice("Test2")
    combo:AddChoice("Test3")

    local binder = PD.Binder(scrl, "Test", KEY_F1, function(self, val)
        print(val)
    end)

end

-- if TestBase then
--     TestBase:Remove()
-- end

-- FrameMenu()
