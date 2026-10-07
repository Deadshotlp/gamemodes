--[[
    Naval - Navigationscomputer (Client).

    Links Systemsuche, rechts 2D-Galaxiekarte (Draufsicht, x/y in Parsec) mit
    Hyperraumrouten. Ziehen = verschieben, Mausrad = zoomen, Klick = Ziel.

    Umschalter oben rechts: Systemkarte (Draufsicht auf das aktuelle System,
    Meter). Dort Himmelskoerper, Schiffe oder einen freien Punkt waehlen und
    den Autopiloten starten (sv_naval_autopilot.lua): Anflug mit Umweg um
    Planeten, Halten oder Orbit, Sprungpunkt ausserhalb des Massenschattens.
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

local function SendAuto(args)
    net.Start("PD.Naval.Nav")
    net.WriteString("auto")
    net.WriteString(util.TableToJSON(args) or "{}")
    net.SendToServer()
end

-- Geplanter Sprungweg (vom Server, passend zu status.pathKey)
net.Receive("PD.Naval.Path", function()
    local key = net.ReadString()
    local data = util.JSONToTable(net.ReadString()) or {}
    C.path = {key = key, points = data.points or {}, routes = data.routes or {}}
end)

local pathRequested
timer.Create("PD.Naval.PathSync", 1, 0, function()
    local key = C.status and C.status.pathKey
    if not key or (C.path and C.path.key == key) or pathRequested == key then return end

    pathRequested = key
    net.Start("PD.Naval.Path")
    net.WriteString(key)
    net.SendToServer()
    timer.Simple(3, function() if pathRequested == key then pathRequested = nil end end)
end)

-- Position auf dem Weg beim Zeitanteil f
local function PathAt(points, f)
    for i = 2, #points do
        local a, b = points[i - 1], points[i]
        if f <= b[3] then
            local t = b[3] > a[3] and (f - a[3]) / (b[3] - a[3]) or 1
            return a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
        end
    end
    local last = points[#points]
    return last[1], last[2]
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

        -- Kurs: geplanter Weg (Routen blau, abseits gelb), sonst Luftlinie
        local cur = current and static.systemsById[current]
        local target = s.Selected and static.systemsById[s.Selected]
        local st = C.status or {}
        local path = C.path and st.pathKey == C.path.key and C.path.points

        if path and #path > 1 then
            for i = 2, #path do
                local x1, y1 = ToScreen(s, path[i - 1][1], path[i - 1][2])
                local x2, y2 = ToScreen(s, path[i][1], path[i][2])
                local col = path[i - 1][4] and Color(120, 200, 255) or COL.warn
                surface.SetDrawColor(col)
                surface.DrawLine(x1, y1, x2, y2)
                surface.DrawLine(x1 + 1, y1, x2 + 1, y2)
            end

            -- Im Hyperraum: wo das Schiff gerade ist
            local hy = st.hyper
            if st.state == "hyperspace" and hy and hy.tTunnel and hy.tExit then
                local f = math.Clamp((Naval.Now() - hy.tTunnel) / math.max(hy.tExit - hy.tTunnel, 1), 0, 1)
                local x, y = ToScreen(s, PathAt(path, f))
                draw.RoundedBox(4, x - 5, y - 5, 10, 10, COL.ok)
            end

            if not target and st.nav then target = static.systemsById[st.nav.target] end
            if not target and hy and hy.to then target = static.systemsById[hy.to] end
        elseif cur and target then
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

--------------------------------------------------------------------------------
-- Systemkarte (Draufsicht x/y, Meter, logarithmischer Zoom)
--------------------------------------------------------------------------------

local BODY_COLOR = {star = Color(255, 220, 120), planet = Color(120, 200, 180), moon = Color(170, 175, 185)}

local function DrawCircle(x, y, r, col)
    if r < 1 or r > 40000 then return end
    surface.SetDrawColor(col)
    local segments = math.Clamp(math.floor(r / 2), 16, 72)
    local lx, ly
    for i = 0, segments do
        local a = i / segments * math.pi * 2
        local px, py = x + math.cos(a) * r, y + math.sin(a) * r
        if lx then surface.DrawLine(lx, ly, px, py) end
        lx, ly = px, py
    end
end

local function CreateSystemMap(parent, onSelect)
    local UI = Naval.UI
    local COL = UI.COL

    local map = vgui.Create("DPanel", parent)
    map.PxPerM = 1 / 20000       -- Pixel je Meter
    map.ViewCenter = nil        -- nil = eigenes Schiff (nicht "Center": das ist eine Panel-Methode)
    map.Selected = nil          -- {kind, id, pos, name}

    local function Origin(s)
        if s.ViewCenter then return s.ViewCenter end
        local view = C.View and C.View()
        return view and view.pos or {x = 0, y = 0, z = 0}
    end

    local function ToScreen(s, p)
        local o = Origin(s)
        return s:GetWide() / 2 + (p.x - o.x) * s.PxPerM, s:GetTall() / 2 - (p.y - o.y) * s.PxPerM
    end

    local function ToWorld(s, sx, sy)
        local o = Origin(s)
        return {x = o.x + (sx - s:GetWide() / 2) / s.PxPerM, y = o.y - (sy - s:GetTall() / 2) / s.PxPerM, z = o.z}
    end

    map.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(6, 9, 14))
        local view = C.View and C.View()
        local system = C.system
        if not view or not system or not system.bodiesById then
            draw.SimpleText("Keine Systemdaten", "MLIB.18", w / 2, h / 2, COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            return
        end

        -- Beim Oeffnen so zoomen, dass der naechste Himmelskoerper zu sehen ist
        if not s.Fitted then
            s.Fitted = true
            local nearest
            for _, body in pairs(system.bodiesById) do
                local d = Naval.V3.Dist(Naval.BodyPos(body, system.bodiesById), view.pos)
                if not nearest or d < nearest then nearest = d end
            end
            if nearest then s.PxPerM = math.min(w, h) * 0.4 / math.max(nearest * 1.3, 50000) end
        end

        local px, py = s:LocalToScreen(0, 0)
        render.SetScissorRect(px, py, px + w, py + h, true)

        local settings = (C.static and C.static.settings) or {}
        local shadow = settings.mass_shadow_factor or 4
        local clearF, clearM = settings.autopilot_clearance or 1.6, settings.autopilot_margin or 5000
        local mx, my = s:CursorPos()
        local hover, hoverD = nil, 14
        local now = Naval.Now()

        -- Himmelskoerper
        for _, body in pairs(system.bodiesById) do
            local pos = Naval.BodyPos(body, system.bodiesById, now)
            local x, y = ToScreen(s, pos)
            local r = math.max((body.radius or 0) * s.PxPerM, 3)
            local col = BODY_COLOR[body.type] or Color(150, 160, 170)

            if x + r * shadow > 0 and x - r * shadow < w and y + r * shadow > 0 and y - r * shadow < h then
                -- Massenschatten und Sicherheitsabstand
                if body.type == "star" or body.type == "planet" or body.type == "moon" then
                    DrawCircle(x, y, (body.radius or 0) * shadow * s.PxPerM, Color(240, 190, 70, 40))
                end
                DrawCircle(x, y, ((body.radius or 0) * clearF + clearM) * s.PxPerM, Color(240, 90, 80, 50))

                draw.NoTexture()
                surface.SetDrawColor(col.r, col.g, col.b, 60)
                if r > 4 and r < 4000 then
                    local poly = {}
                    for i = 0, 31 do
                        local a = i / 32 * math.pi * 2
                        poly[#poly + 1] = {x = x + math.cos(a) * r, y = y + math.sin(a) * r}
                    end
                    surface.DrawPoly(poly)
                end
                DrawCircle(x, y, r, col)

                if body.type ~= "moon" or s.PxPerM * (body.radius or 0) > 1 then
                    draw.SimpleText(body.name, "MLIB.14", x + r + 4, y - 8, col)
                end

                local d = math.sqrt((mx - x) ^ 2 + (my - y) ^ 2)
                if d < math.max(r, 10) and d < hoverD + r then
                    hover, hoverD = {kind = "body", id = body.id, name = body.name, pos = pos}, d - r
                end
            end
        end

        -- Schiffe
        local myFaction = Naval.MapShipFaction and Naval.MapShipFaction()
        local REL = Naval.RelationColors or {}
        for id, sh in pairs(view.ships or {}) do
            local info = C.info[id]
            if info and sh.state ~= "destroyed" then
                local x, y = ToScreen(s, sh.pos)
                if x > -10 and x < w + 10 and y > -10 and y < h + 10 then
                    local col = REL[Naval.ClientRelation(myFaction, info.factionId)] or COL.text
                    draw.RoundedBox(0, x - 3, y - 3, 6, 6, col)
                    draw.SimpleText(info.name, "MLIB.12", x + 6, y - 6, col)

                    local d = math.sqrt((mx - x) ^ 2 + (my - y) ^ 2)
                    if d < hoverD then hover, hoverD = {kind = "ship", id = id, name = info.name, pos = sh.pos}, d end
                end
            end
        end

        -- Geplanter Weg des Autopiloten
        local auto = C.status and C.status.auto
        if auto and auto.path and #auto.path > 1 then
            surface.SetDrawColor(COL.ok)
            for i = 2, #auto.path do
                local a, b = auto.path[i - 1], auto.path[i]
                local x1, y1 = ToScreen(s, {x = a[1], y = a[2]})
                local x2, y2 = ToScreen(s, {x = b[1], y = b[2]})
                surface.DrawLine(x1, y1, x2, y2)
                surface.DrawLine(x1 + 1, y1, x2 + 1, y2)
                draw.RoundedBox(0, x2 - 2, y2 - 2, 5, 5, COL.ok)
            end
        end

        -- Eigenes Schiff mit Bugrichtung
        local x, y = ToScreen(s, view.pos)
        local fwd = Naval.Q.Forward(view.rot)
        local fl = math.sqrt(fwd.x * fwd.x + fwd.y * fwd.y)
        local fx, fy = fl > 0.01 and fwd.x / fl or 1, fl > 0.01 and fwd.y / fl or 0
        surface.SetDrawColor(COL.ok)
        surface.DrawLine(x, y, x + fx * 18, y - fy * 18)
        draw.RoundedBox(4, x - 4, y - 4, 8, 8, COL.ok)

        -- Auswahl
        local sel = s.Selected
        if sel then
            local p = sel.kind == "ship" and view.ships[sel.id] and view.ships[sel.id].pos
                or (sel.kind == "body" and system.bodiesById[sel.id] and Naval.BodyPos(system.bodiesById[sel.id], system.bodiesById, now))
                or sel.pos
            if p then
                local sx, sy = ToScreen(s, p)
                surface.SetDrawColor(COL.warn)
                surface.DrawOutlinedRect(sx - 8, sy - 8, 17, 17, 2)
                if sel.kind == "point" then draw.SimpleText("Wegpunkt", "MLIB.14", sx + 10, sy - 8, COL.warn) end
            end
        end

        s.Hover = hover
        if hover then
            local hx, hy = ToScreen(s, hover.pos)
            surface.SetDrawColor(COL.accent)
            surface.DrawOutlinedRect(hx - 7, hy - 7, 15, 15, 1)
        end

        render.SetScissorRect(0, 0, 0, 0, false)

        local per100 = 100 / s.PxPerM
        draw.SimpleText("100 px = " .. (Naval.FormatDist and Naval.FormatDist(per100) or math.Round(per100 / 1000) .. " km"), "MLIB.14", 8, h - 22, COL.dim)
        draw.SimpleText(s.ViewCenter and "Rechtsklick: zurück zum Schiff" or "Mitte: eigenes Schiff", "MLIB.12", w - 8, h - 20, COL.dim, TEXT_ALIGN_RIGHT)
        draw.SimpleText("gelb = Massenschatten, rot = Sicherheitsabstand", "MLIB.12", w - 8, 8, COL.dim, TEXT_ALIGN_RIGHT)
    end

    map.OnMousePressed = function(s, code)
        if code == MOUSE_RIGHT then
            s.ViewCenter = nil
            return
        end
        if code ~= MOUSE_LEFT then return end
        s.DragStart = {s:CursorPos()}
        s.DragCenter = Origin(s)
        s.Moved = false
        s:MouseCapture(true)
    end

    map.OnMouseReleased = function(s, code)
        if code ~= MOUSE_LEFT then return end
        s:MouseCapture(false)
        s.DragStart = nil
        if s.Moved then return end

        if s.Hover then
            s.Selected = s.Hover
        else
            local mx, my = s:CursorPos()
            s.Selected = {kind = "point", pos = ToWorld(s, mx, my), name = "Wegpunkt"}
        end
        if onSelect then onSelect(s.Selected) end
    end

    map.Think = function(s)
        if not s.DragStart then return end
        local mx, my = s:CursorPos()
        local dx, dy = mx - s.DragStart[1], my - s.DragStart[2]
        if math.abs(dx) + math.abs(dy) > 4 then s.Moved = true end
        if s.Moved then
            s.ViewCenter = {x = s.DragCenter.x - dx / s.PxPerM, y = s.DragCenter.y + dy / s.PxPerM, z = s.DragCenter.z}
        end
    end

    map.OnMouseWheeled = function(s, delta)
        local mx, my = s:CursorPos()
        local before = ToWorld(s, mx, my)
        s.PxPerM = math.Clamp(s.PxPerM * (delta > 0 and 1.3 or 1 / 1.3), 1e-11, 0.05)
        local after = ToWorld(s, mx, my)
        local o = Origin(s)
        s.ViewCenter = {x = o.x + before.x - after.x, y = o.y + before.y - after.y, z = o.z}
        return true
    end

    return map
end

local function CreateSystemSide(parent, map)
    local UI = Naval.UI
    local COL = UI.COL

    local side = vgui.Create("DPanel", parent)
    side.Paint = nil
    local state = {mode = "stop", speed = 1, alt = nil}

    local info = vgui.Create("DPanel", side)
    info:Dock(TOP)
    info:SetTall(250)
    info.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL.panel)
        local y = 8
        local function Line(text, col)
            if #text > 44 then text = string.sub(text, 1, 42) .. "..." end
            draw.SimpleText(text, "MLIB.16", 10, y, col or COL.text)
            y = y + 22
        end

        local sel = map.Selected
        local view = C.View and C.View()
        Line("System: " .. Naval.SystemName(C.status and C.status.system), COL.dim)
        if sel and view then
            Line("Ziel: " .. (sel.name or "?"), COL.accent)
            local p = sel.pos
            if sel.kind == "ship" and view.ships[sel.id] then p = view.ships[sel.id].pos end
            if p then Line("Entfernung: " .. (Naval.FormatDist and Naval.FormatDist(Naval.V3.Dist({x = p.x, y = p.y, z = p.z or view.pos.z}, view.pos)) or "?")) end
            if sel.kind == "body" then
                local body = C.system and C.system.bodiesById[sel.id]
                if body then Line(("Radius %s"):format(Naval.FormatDist and Naval.FormatDist(body.radius or 0) or "?"), COL.dim) end
            end
        else
            Line("Ziel auf der Karte wählen:", COL.dim)
            Line("Planet, Mond, Stern, Schiff", COL.dim)
            Line("oder freier Punkt", COL.dim)
        end

        y = y + 8
        local auto = C.status and C.status.auto
        if auto then
            Line("Autopilot: " .. (auto.label or "?"), COL.ok)
            if auto.arrived then
                Line(auto.mode == "orbit" and "Im Orbit" or "Ziel erreicht", COL.ok)
            else
                Line(("Rest %s - ca. %s"):format(Naval.FormatDist and Naval.FormatDist(auto.remaining or 0) or "?", UI.Fmt(auto.eta)), COL.text)
                if auto.path and #auto.path > 2 then Line("Umweg um Himmelskörper", COL.warn) end
            end
        else
            Line("Autopilot aus", COL.dim)
        end
    end

    local function Row(height)
        local p = vgui.Create("DPanel", side)
        p:Dock(TOP)
        p:DockMargin(0, 6, 0, 0)
        p:SetTall(height)
        p.Paint = nil
        return p
    end

    -- Ankunft: halten oder Orbit
    local modeRow = Row(34)
    local stopBtn = UI.Button(modeRow, "Anfliegen + halten", function() state.mode = "stop" end,
        function() return state.mode == "stop" and COL.ok or COL.dim end)
    local orbitBtn = UI.Button(modeRow, "Orbit", function() state.mode = "orbit" end,
        function() return state.mode == "orbit" and COL.ok or COL.dim end)
    modeRow.PerformLayout = function(s, w, h)
        stopBtn:SetPos(0, 0) stopBtn:SetSize(w * 0.6 - 3, h)
        orbitBtn:SetPos(w * 0.6 + 3, 0) orbitBtn:SetSize(w * 0.4 - 3, h)
    end

    -- Geschwindigkeit
    local speedRow = Row(34)
    local speeds = {{"25 %", 0.25}, {"50 %", 0.5}, {"75 %", 0.75}, {"Voll", 1}}
    local speedBtns = {}
    for i, sp in ipairs(speeds) do
        speedBtns[i] = UI.Button(speedRow, sp[1], function() state.speed = sp[2] end,
            function() return state.speed == sp[2] and COL.ok or COL.dim end)
    end
    speedRow.PerformLayout = function(s, w, h)
        local bw = (w - 18) / 4
        for i, b in ipairs(speedBtns) do b:SetPos((i - 1) * (bw + 6), 0) b:SetSize(bw, h) end
    end

    -- Abstand
    local altRow = Row(34)
    altRow.Paint = function(s, w, h)
        draw.SimpleText("Abstand (km, leer = automatisch)", "MLIB.14", 0, h / 2, COL.dim, nil, TEXT_ALIGN_CENTER)
    end
    local altEntry = vgui.Create("DTextEntry", altRow)
    altEntry:Dock(RIGHT)
    altEntry:SetWide(90)
    altEntry:SetFont("MLIB.16")
    altEntry:SetNumeric(true)

    local goRow = Row(42)
    local goBtn = UI.Button(goRow, "AUTOPILOT STARTEN", function()
        local sel = map.Selected
        if not sel then return end
        local km = tonumber(altEntry:GetValue())
        local args = {kind = sel.kind, mode = state.mode, speed = state.speed, alt = km and km * 1000 or nil}
        if sel.kind == "point" then
            args.pos = {x = sel.pos.x, y = sel.pos.y, z = sel.pos.z}
        else
            args.id = sel.id
        end
        SendAuto(args)
    end, function() return COL.ok end)
    goBtn:Dock(FILL)

    local jumpRow = Row(38)
    local jumpBtn = UI.Button(jumpRow, "Zum Sprungpunkt (aus dem Massenschatten)", function()
        SendAuto({kind = "jumppoint", speed = state.speed})
    end)
    jumpBtn:Dock(FILL)

    local offRow = Row(38)
    local offBtn = UI.Button(offRow, "Autopilot aus", function() SendNav("auto_off") end, function() return COL.bad end)
    offBtn:Dock(FILL)

    local hintRow = Row(60)
    hintRow.Paint = function(s, w, h)
        draw.SimpleText("Ziehen = verschieben, Mausrad = zoomen,", "MLIB.12", 0, 4, COL.dim)
        draw.SimpleText("Rechtsklick = Ansicht aufs Schiff.", "MLIB.12", 0, 20, COL.dim)
        draw.SimpleText("Steuern an der Steuerkonsole schaltet ab.", "MLIB.12", 0, 36, COL.dim)
    end

    side.Think = function()
        local st = C.status or {}
        local sel = map.Selected
        goBtn.Disabled = not sel or st.state ~= "normal"
        orbitBtn.Disabled = not sel or sel.kind ~= "body"
        if orbitBtn.Disabled and state.mode == "orbit" then state.mode = "stop" end
        jumpBtn.Disabled = not (st.nav and st.nav.ready and st.nav.valid) or st.state ~= "normal"
        offBtn.Disabled = st.auto == nil
    end

    return side
end

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
    detail:SetTall(290)

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
            if filter == "" or string.find(sys.search or string.lower(sys.name), filter, 1, true) or string.find(string.lower(sys.region or ""), filter, 1, true) then
                rows[#rows + 1] = {sys = sys, d = cur and Dist2D(cur, sys) or 0}
            end
        end

        table.sort(rows, function(a, b) return a.d < b.d end)

        for i = 1, math.min(#rows, 300) do
            local r = rows[i]
            local label = r.sys.name
            if r.sys.planets and r.sys.planets ~= "" then label = label .. " (" .. r.sys.planets .. ")" end
            local line = list:AddLine(label, r.sys.region or "", math.Round(r.d))
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
            if #text > 42 then text = string.sub(text, 1, 40) .. "..." end
            draw.SimpleText(text, "MLIB.16", 10, y, col or COL.text)
            y = y + 22
        end

        if selected then
            Line("Ziel: " .. selected.name, COL.accent)
            if cur then Line(("Entfernung: %.0f pc"):format(Dist2D(cur, selected)), COL.text) end
            if selected.planets and selected.planets ~= "" then Line("Planeten: " .. selected.planets, COL.dim) end
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
                Line(nav.routes and #nav.routes > 0 and ("Über " .. table.concat(nav.routes, " -> ")) or "Direkt, abseits der Routen", COL.dim)
            end
        end
    end

    -- Systemkarte (Autopilot im System)
    local sysMap = CreateSystemMap(frame)
    sysMap:SetPos(360, 55)
    sysMap:SetSize(frame:GetWide() - 380, frame:GetTall() - 75)

    local sysSide = CreateSystemSide(frame, sysMap)
    sysSide:SetPos(20, 55)
    sysSide:SetSize(330, frame:GetTall() - 75)

    local mode = "galaxy"
    local function SetMode(m)
        mode = m
        side:SetVisible(m == "galaxy")
        map:SetVisible(m == "galaxy")
        sysSide:SetVisible(m == "system")
        sysMap:SetVisible(m == "system")
    end

    local toggle = UI.Button(frame, "", function() SetMode(mode == "galaxy" and "system" or "galaxy") end)
    toggle:SetPos(frame:GetWide() - 330, 10)
    toggle:SetSize(270, 32)

    -- Mit laufendem Autopiloten direkt die Systemkarte zeigen
    SetMode(C.status and C.status.auto and "system" or "galaxy")

    frame.Think = function(s)
        if IsValid(s.Console) and LocalPlayer():GetPos():Distance(s.Console:GetPos()) > (Naval.StationUseRange or 160) * 1.5 then
            s:Close()
            return
        end

        toggle.Label = mode == "galaxy" and "Wechseln: Systemkarte" or "Wechseln: Galaxiekarte"

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
