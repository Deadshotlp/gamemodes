--[[
    Naval - Navigationscomputer (Client).

    Links Systemsuche, rechts 2D-Galaxiekarte (Draufsicht, x/y in Parsec) mit
    Hyperraumrouten. Ziehen = verschieben, Mausrad = zoomen, Klick = Ziel.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C

local function SendNav(action, systemId)
    net.Start("PD.Naval.Nav")
    net.WriteString(action)
    if systemId then net.WriteString(systemId) end
    net.SendToServer()
end

local function Dist2D(a, b)
    return math.sqrt((a.g.x - b.g.x) ^ 2 + (a.g.y - b.g.y) ^ 2 + (a.g.z - b.g.z) ^ 2)
end

local function CreateMap(parent, onSelect)
    local UI = Naval.UI
    local COL = UI.COL

    local map = vgui.Create("DPanel", parent)
    map.Zoom = 0.03            -- Pixel je Parsec
    map.Center = {x = 0, y = 0}
    map.Selected = nil

    local function ToScreen(s, gx, gy)
        return s:GetWide() / 2 + (gx - s.Center.x) * s.Zoom, s:GetTall() / 2 - (gy - s.Center.y) * s.Zoom
    end

    local function ToGalaxy(s, sx, sy)
        return s.Center.x + (sx - s:GetWide() / 2) / s.Zoom, s.Center.y - (sy - s:GetTall() / 2) / s.Zoom
    end

    function map:FocusSystem(sys, zoom)
        if not sys then return end
        self.Center = {x = sys.g.x, y = sys.g.y}
        if zoom then self.Zoom = zoom end
    end

    map.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(6, 9, 14))
        local static = C.static
        if not static then
            draw.SimpleText("Keine Galaxiedaten", "MLIB.18", w / 2, h / 2, COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end

        local px, py = s:LocalToScreen(0, 0)
        render.SetScissorRect(px, py, px + w, py + h, true)

        -- Routen
        for _, route in pairs(static.routes or {}) do
            surface.SetDrawColor(route.major and Color(90, 140, 220, 160) or Color(70, 90, 130, 90))
            for _, line in ipairs(route.lines or {}) do
                for i = 2, #line do
                    local x1, y1 = ToScreen(s, line[i - 1][1], line[i - 1][2])
                    local x2, y2 = ToScreen(s, line[i][1], line[i][2])
                    if math.max(x1, x2) >= 0 and math.min(x1, x2) <= w and math.max(y1, y2) >= 0 and math.min(y1, y2) <= h then
                        surface.DrawLine(x1, y1, x2, y2)
                    end
                end
            end
        end

        -- Systeme
        local current = C.status and C.status.system
        local showNames = s.Zoom > 0.6
        local hover, hoverD = nil, 12
        local mx, my = s:CursorPos()

        for _, sys in ipairs(static.systemList) do
            local x, y = ToScreen(s, sys.g.x, sys.g.y)
            if x >= -5 and x <= w + 5 and y >= -5 and y <= h + 5 then
                local onRoute = sys.routes and #sys.routes > 0
                surface.SetDrawColor(onRoute and Color(200, 215, 240) or Color(120, 130, 150))
                surface.DrawRect(x - 1, y - 1, onRoute and 3 or 2, onRoute and 3 or 2)

                if showNames then
                    draw.SimpleText(sys.name, "MLIB.12", x + 4, y - 6, Color(150, 160, 180))
                end

                local d = math.sqrt((mx - x) ^ 2 + (my - y) ^ 2)
                if d < hoverD then hover, hoverD = sys, d end
            end
        end
        s.Hover = hover

        -- Kurslinie
        local cur = current and static.systemsById[current]
        local target = s.Selected and static.systemsById[s.Selected]
        if cur and target then
            local x1, y1 = ToScreen(s, cur.g.x, cur.g.y)
            local x2, y2 = ToScreen(s, target.g.x, target.g.y)
            surface.SetDrawColor(COL.warn)
            surface.DrawLine(x1, y1, x2, y2)
        end

        local function Mark(sys, col, label)
            if not sys then return end
            local x, y = ToScreen(s, sys.g.x, sys.g.y)
            surface.SetDrawColor(col)
            surface.DrawOutlinedRect(x - 6, y - 6, 13, 13, 2)
            draw.SimpleText(label or sys.name, "MLIB.16", x + 10, y - 9, col)
        end

        Mark(cur, COL.ok, cur and ("Hier: " .. cur.name))
        Mark(target, COL.warn)
        if hover and hover ~= target and hover ~= cur then Mark(hover, COL.accent) end

        render.SetScissorRect(0, 0, 0, 0, false)

        draw.SimpleText(("%.0f pc / 100 px"):format(100 / s.Zoom), "MLIB.14", 8, h - 22, COL.dim)
    end

    map.OnMousePressed = function(s, code)
        if code == MOUSE_LEFT then
            s.DragStart = {s:CursorPos()}
            s.DragCenter = {x = s.Center.x, y = s.Center.y}
            s.Moved = false
            s:MouseCapture(true)
        end
    end

    map.OnMouseReleased = function(s, code)
        if code ~= MOUSE_LEFT then return end
        s:MouseCapture(false)
        if not s.Moved and s.Hover then
            s.Selected = s.Hover.id
            if onSelect then onSelect(s.Hover) end
        end
        s.DragStart = nil
    end

    map.Think = function(s)
        if not s.DragStart then return end
        local mx, my = s:CursorPos()
        local dx, dy = mx - s.DragStart[1], my - s.DragStart[2]
        if math.abs(dx) + math.abs(dy) > 4 then s.Moved = true end
        s.Center = {x = s.DragCenter.x - dx / s.Zoom, y = s.DragCenter.y + dy / s.Zoom}
    end

    map.OnMouseWheeled = function(s, delta)
        local mx, my = s:CursorPos()
        local gx, gy = ToGalaxy(s, mx, my)
        s.Zoom = math.Clamp(s.Zoom * (delta > 0 and 1.25 or 0.8), 0.005, 40)
        -- Punkt unter der Maus bleibt stehen
        local nx, ny = ToGalaxy(s, mx, my)
        s.Center = {x = s.Center.x + gx - nx, y = s.Center.y + gy - ny}
        return true
    end

    return map
end

Naval.CreateGalaxyMap = CreateMap

local function OpenNavcomputer(console)
    local UI = Naval.UI
    local COL = UI.COL

    local frame = UI.Frame("NAVIGATIONSCOMPUTER", 1280, 780)
    frame.Console = console

    local static = C.static
    local current = C.status and C.status.system
    local selected

    local side = vgui.Create("DPanel", frame)
    side:SetPos(20, 55)
    side:SetSize(330, frame:GetTall() - 75)
    side.Paint = nil

    local search = vgui.Create("DTextEntry", side)
    search:Dock(TOP)
    search:SetTall(34)
    search:SetFont("MLIB.16")
    search:SetPlaceholderText("System oder Planet suchen ...")

    local list = vgui.Create("DListView", side)
    list:Dock(FILL)
    list:DockMargin(0, 6, 0, 6)
    list:SetMultiSelect(false)
    list:AddColumn("System")
    list:AddColumn("Region")
    list:AddColumn("pc"):SetFixedWidth(55)

    local detail = vgui.Create("DPanel", side)
    detail:Dock(BOTTOM)
    detail:SetTall(220)

    local map = CreateMap(frame, function(sys)
        selected = sys
        search:SetValue(sys.name)
    end)
    map:SetPos(360, 55)
    map:SetSize(frame:GetWide() - 380, frame:GetTall() - 75)

    local function Select(sys)
        selected = sys
        map.Selected = sys and sys.id
        if sys then map:FocusSystem(sys, math.max(map.Zoom, 0.8)) end
    end

    local function Fill(filter)
        list:Clear()
        if not static then return end

        filter = string.lower(string.Trim(filter or ""))
        local cur = current and static.systemsById[current]
        local rows = {}

        for _, sys in ipairs(static.systemList) do
            if filter == "" or string.find(string.lower(sys.name), filter, 1, true) or string.find(string.lower(sys.region or ""), filter, 1, true) then
                rows[#rows + 1] = {sys = sys, d = cur and Dist2D(cur, sys) or 0}
            end
        end

        table.sort(rows, function(a, b) return a.d < b.d end)

        for i = 1, math.min(#rows, 300) do
            local r = rows[i]
            local line = list:AddLine(r.sys.name, r.sys.region or "", math.Round(r.d))
            line.System = r.sys
        end
    end

    search.OnChange = function(s) Fill(s:GetValue()) end
    list.OnRowSelected = function(_, _, line) Select(line.System) end

    local calc = UI.Button(detail, "Kurs berechnen", function()
        if selected then SendNav("calc", selected.id) end
    end, function() return COL.ok end)

    local clear = UI.Button(detail, "Kurs verwerfen", function() SendNav("clear") end, function() return COL.bad end)

    detail.PerformLayout = function(s, w, h)
        calc:SetPos(0, h - 84) calc:SetSize(w, 38)
        clear:SetPos(0, h - 40) clear:SetSize(w, 38)
    end

    detail.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h - 90, COL.panel)
        local st = C.status or {}
        local cur = static and st.system and static.systemsById[st.system]
        local y = 8

        local function Line(text, col)
            draw.SimpleText(text, "MLIB.16", 10, y, col or COL.text)
            y = y + 22
        end

        if selected then
            Line("Ziel: " .. selected.name, COL.accent)
            if cur then Line(("Entfernung: %.0f pc"):format(Dist2D(cur, selected)), COL.text) end
            if selected.routes and #selected.routes > 0 then Line("An einer Hyperraumroute", COL.ok) end
        else
            Line("Kein Ziel gewählt", COL.dim)
        end

        local nav = st.nav
        if nav then
            y = y + 6
            if not nav.ready then
                Line("Berechnung " .. Naval.SystemName(nav.target) .. ": " .. UI.Fmt(nav.finish - Naval.Now()), COL.warn)
                UI.Bar(10, y, w - 20, 8, (Naval.Now() - nav.start) / math.max(nav.finish - nav.start, 1), COL.warn)
            else
                Line("Lösung " .. Naval.SystemName(nav.target) .. ": " .. UI.Fmt(nav.duration) .. " Sprung", nav.valid and COL.ok or COL.bad)
                if not nav.valid and nav.reason then Line(nav.reason, COL.bad) end
            end
        end
    end

    frame.Think = function(s)
        if IsValid(s.Console) and LocalPlayer():GetPos():Distance(s.Console:GetPos()) > (Naval.StationUseRange or 160) * 1.5 then
            s:Close()
            return
        end

        local st = C.status or {}
        calc.Disabled = not selected or st.state ~= "normal" or (st.system == (selected and selected.id))
        clear.Disabled = st.nav == nil
    end

    Fill("")
    if static and current then
        map:FocusSystem(static.systemsById[current], 0.15)
    end
    if C.status and C.status.nav then
        Select(static and static.systemsById[C.status.nav.target])
    end
end

Naval.StationUI = Naval.StationUI or {}
Naval.StationUI.navcomputer = OpenNavcomputer
