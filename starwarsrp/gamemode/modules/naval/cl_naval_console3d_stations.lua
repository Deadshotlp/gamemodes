--[[
    Naval - 3D2D-Oberflaechen aller Konsolen ausser der Steuer (Client).

    Rahmen, Rollen und Bedienung: cl_naval_console3d.lua. Die alten Menues
    bleiben im Code (Naval.StationUI), werden aber nicht mehr geoeffnet,
    solange die Station ui3d = true hat. Ausnahmen, die ein Fenster brauchen:
    Texteingabe (Logbuch, Funkspruch) und die Galaxiekarte des
    Navigationscomputers ("Karte öffnen").
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C
local V3 = Naval.V3

local Lib = Naval.Console3DLib or {}
local COL = Lib.COL or {}
local State = Naval.Console3DState

local function Cmd(station, action, args)
    if Naval.CombatCmd then Naval.CombatCmd(station, action, args) end
end

local function Dist(m)
    return Naval.FormatDist and Naval.FormatDist(m or 0) or (math.Round((m or 0) / 1000) .. " km")
end

local function Time(s)
    s = math.max(0, math.floor(tonumber(s) or 0))
    return s >= 60 and ("%d:%02d"):format(math.floor(s / 60), s % 60) or (s .. " s")
end

local function Frac(f)
    return f > 0.5 and COL.ok or (f > 0.25 and COL.warn or COL.bad)
end

-- maxW: Schrift so weit verkleinern, dass der Text hineinpasst
local function Text(text, font, x, y, col, ax, ay, maxW)
    font = font or "PD.N3D.Small"
    if maxW and Naval.Console3DFit then font = Naval.Console3DFit(text, font, maxW) end
    draw.SimpleText(text, font, x, y, col or COL.text, ax, ay)
end

-- Tastenfeld-Raster: Zelle (c, r) mit Breite span
local function Grid(w, h, cols, rows)
    local pad = 12
    local bw = (w - pad * (cols + 1)) / cols
    local bh = (h - pad * (rows + 1)) / rows
    return function(c, r, span, rspan)
        span, rspan = span or 1, rspan or 1
        return pad + (c - 1) * (bw + pad), pad + (r - 1) * (bh + pad), bw * span + pad * (span - 1), bh * rspan + pad * (rspan - 1)
    end
end

local function Near(ent, dist)
    return IsValid(ent) and LocalPlayer():GetPos():DistToSqr(ent:GetPos()) < (dist or 200) ^ 2
end

local function Scroll(st, delta, count, rows)
    st.scroll = math.Clamp((st.scroll or 0) + delta * math.max(1, (rows or 4) - 1), 0, math.max(0, (count or 0) - 1))
end

-- Kontakte aus der Sicht des Map-Schiffs
local function Contacts(hostileFirst)
    local view = C.View and C.View()
    local list = {}
    if not view then return list end
    local my = Naval.MapShipFaction and Naval.MapShipFaction()
    local sens = C.status and C.status.sensors and C.status.sensors.contacts or {}
    for id, s in pairs(view.ships or {}) do
        local info = C.info[id]
        if info and s.state ~= "destroyed" then
            local c = sens[tostring(id)] or {}
            list[#list + 1] = {id = id, name = info.name, classId = info.classId, factionId = info.factionId, level = info.ident or 2,
                dist = V3.Dist(s.pos, view.pos), hull = s.hull or 100, state = s.state, surrendered = c.surrendered,
                relation = Naval.ClientRelation and Naval.ClientRelation(my, info.factionId) or "neutral"}
        end
    end
    table.sort(list, function(a, b)
        if hostileFirst and (a.relation == "hostile") ~= (b.relation == "hostile") then return a.relation == "hostile" end
        return a.dist < b.dist
    end)
    return list
end

local function ContactRow(c, x, y, w, h)
    local rel = Naval.RelationColors and Naval.RelationColors[c.relation] or COL.text
    surface.SetDrawColor(rel)
    surface.DrawRect(x, y, 6, h)
    Text(c.name, "PD.N3D.Small", x + 16, y + 6, COL.text, nil, nil, w * 0.62)
    local sub = c.surrendered and "kapituliert" or (c.level == 0 and "unbekannt" or "")
    Text(sub, "PD.N3D.Small", x + 16, y + h - 6, c.surrendered and COL.warn or COL.dim, nil, TEXT_ALIGN_BOTTOM)
    Text(Dist(c.dist), "PD.N3D.Small", x + w - 10, y + 6, COL.text, TEXT_ALIGN_RIGHT)
end

local function Feedback(ui, w, h)
    if Naval.Console3DFeedback then Naval.Console3DFeedback(ui, w, h - 44) end
end

local function Small(ui, w, h, title, value, col, sub)
    ui:Frame(w, h, title)
    Text(value or "-", "PD.N3D.Big", w / 2, h / 2 + 6, col or COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, w - 28)
    if sub then Text(sub, "PD.N3D.Small", w / 2, h - 16, COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_BOTTOM, w - 28) end
end

local function Register(station, fn)
    Naval.Console3D[station] = {draw = function(role, w, h, ui, ent) fn(role, w, h, ui, ent, State(ent)) end}
end

--------------------------------------------------------------------------------
-- Hyperantrieb
--------------------------------------------------------------------------------

local function SendHyper(action)
    net.Start("PD.Naval.Hyper")
    net.WriteString(action)
    net.SendToServer()
end

local function Tolerance()
    return (C.static and C.static.settings and C.static.settings.jump_align_tolerance) or 2
end

Register("hyperdrive", function(role, w, h, ui)
    local st = C.status or {}
    local now = Naval.Now()
    local hy = st.hyper or {}
    local nav = st.nav
    local ready = st.state == "normal" and nav and nav.ready and nav.valid and not st.shadow and not st.interdict and (st.align or 99) <= Tolerance()

    if role == "main" then
        ui:Frame(w, h, "HYPERANTRIEB")
        local y = 52
        local function Line(text, col, font)
            Text(text, font or "PD.N3D.Small", 22, y, col)
            y = y + (font == "PD.N3D.Med" and 46 or 36)
        end
        if not nav then
            Line("Keine Kurslösung", COL.dim, "PD.N3D.Med")
            Line("Am Navigationscomputer berechnen.", COL.dim)
        elseif not nav.ready then
            Line("Berechne Kurs nach", COL.warn)
            Line(Naval.SystemName(nav.target), COL.warn, "PD.N3D.Med")
            ui:Bar(22, y, w - 44, 14, (now - nav.start) / math.max(nav.finish - nav.start, 1), COL.warn)
            y = y + 30
        else
            Line(Naval.SystemName(nav.target), nav.valid and COL.ok or COL.bad, "PD.N3D.Med")
            Line("Sprungdauer " .. Time(nav.duration), COL.text)
            if not nav.valid then Line(nav.reason or "Ungültig", COL.bad) end
        end
        if st.shadow then Line(("Massenschatten %s: %.0f km"):format(st.shadow.name, (st.shadow.limit - st.shadow.dist) / 1000), COL.bad)
        elseif st.interdict then Line("Abfangfeld aktiv", COL.bad) end
        if st.state == "spooling" and hy.tJump then
            Line("Antrieb fährt hoch: " .. Time(hy.tJump - now), COL.warn)
            ui:Bar(22, y, w - 44, 14, (now - hy.tSpool) / math.max(hy.tJump - hy.tSpool, 1), COL.warn)
        elseif st.state == "hyperspace" and hy.tExit then
            Line("Ankunft in " .. Time(hy.tExit - now), COL.accent)
            ui:Bar(22, y, w - 44, 14, (now - hy.tTunnel) / math.max(hy.tExit - hy.tTunnel, 1), COL.accent)
        end
        Feedback(ui, w, h)
    elseif role == "s1" then
        local text, col = "NICHT BEREIT", COL.dim
        if ready then text, col = "BEREIT", COL.ok end
        if st.state == "spooling" and hy.tJump then text, col = Time(hy.tJump - now), COL.warn end
        if st.state == "hyperspace" and hy.tExit then text, col = Time(hy.tExit - now), COL.accent end
        Small(ui, w, h, "SPRUNG", text, col)
    elseif role == "s2" then
        Small(ui, w, h, "AUSRICHTUNG", st.align and ("%.1f°"):format(st.align) or "-",
            st.align and (st.align <= Tolerance() and COL.ok or COL.warn) or COL.dim)
    elseif role == "keys" then
        ui:Keypad(w, h)
        local cell = Grid(w, h, 3, 1)
        local x, y, bw, bh = cell(1, 1)
        if ui:Button(x, y, bw, bh, "AUSRICHTEN", {font = "PD.N3D.Big", disabled = not (st.state == "normal" and nav and nav.ready and nav.valid)}) then SendHyper("align") end
        x, y, bw, bh = cell(2, 1)
        if ui:Button(x, y, bw, bh, "SPRINGEN", {col = COL.ok, disabled = not ready, font = "PD.N3D.Big"}) then SendHyper("jump") end
        x, y, bw, bh = cell(3, 1)
        if ui:Button(x, y, bw, bh, "ABBRECHEN", {col = COL.bad, font = "PD.N3D.Big", disabled = st.state ~= "spooling"}) then SendHyper("abort") end
    end
end)

--------------------------------------------------------------------------------
-- Logbuch
--------------------------------------------------------------------------------

local KIND_LABEL = {nav = "Navigation", manual = "Eintrag", admin = "Kommando", contact = "Kontakt", damage = "Schaden",
    combat = "Gefecht", comms = "Funk", supply = "Logistik", event = "Ereignis"}

Register("shiplog", function(role, w, h, ui, ent, st)
    local rows = Naval.ShipLogRows or {}
    if role == "main" then
        if Near(ent, 220) and CurTime() > (st.nextList or 0) then
            st.nextList = CurTime() + 8
            net.Start("PD.Naval.ShipLog") net.WriteString("list") net.SendToServer()
        end
        ui:Frame(w, h, "LOGBUCH")
        local sel = st.sel and rows[st.sel]
        if sel then
            Text(os.date("%d.%m. %H:%M", tonumber(sel.ts) or 0) .. "  " .. (KIND_LABEL[sel.kind] or sel.kind or ""), "PD.N3D.Small", 22, 52, COL.dim)
            if sel.author and sel.author ~= "" then Text(sel.author, "PD.N3D.Small", 22, 86, COL.accent) end
            for i, line in ipairs(ui.Wrap(sel.text, 28)) do
                if 120 + i * 34 > h - 20 then break end
                Text(line, "PD.N3D.Small", 22, 90 + i * 34, COL.text)
            end
            return
        end
        local items = {}
        for i, r in ipairs(rows) do items[i] = {id = i, row = r} end
        local clicked, n = ui:List(14, 50, w - 28, h - 64, items, {rowH = 74, scroll = st.scroll, draw = function(it, x, y, iw, ih)
            local r = it.row
            Text(os.date("%d.%m. %H:%M", tonumber(r.ts) or 0) .. "  " .. (KIND_LABEL[r.kind] or r.kind or ""), "PD.N3D.Small", x + 10, y + 4, COL.dim)
            Text(string.sub(r.text or "", 1, 30), "PD.N3D.Small", x + 10, y + ih - 4, COL.text, nil, TEXT_ALIGN_BOTTOM)
        end})
        st.rows = n
        if clicked then st.sel = clicked.id end
    elseif role == "s1" then
        Small(ui, w, h, "EINTRÄGE", tostring(#rows))
    elseif role == "s2" then
        Small(ui, w, h, "BORDZEIT", os.date("%H:%M"))
    elseif role == "keys" then
        ui:Keypad(w, h)
        local cell = Grid(w, h, 3, 2)
        local x, y, bw, bh = cell(1, 1)
        if ui:Button(x, y, bw, bh, "▲") then st.sel = nil Scroll(st, -1, #rows, st.rows) end
        x, y, bw, bh = cell(1, 2)
        if ui:Button(x, y, bw, bh, "▼") then st.sel = nil Scroll(st, 1, #rows, st.rows) end
        x, y, bw, bh = cell(2, 1)
        if ui:Button(x, y, bw, bh, st.sel and "Zurück zur Liste" or "Neueste", {active = st.sel ~= nil}) then st.sel = nil st.scroll = 0 end
        x, y, bw, bh = cell(2, 2)
        if ui:Button(x, y, bw, bh, "Aktualisieren") then st.nextList = 0 end
        x, y, bw, bh = cell(3, 1, 1, 2)
        if ui:Button(x, y, bw, bh, "Eintrag schreiben", {col = COL.ok}) then
            Derma_StringRequest("Logbuch", "Neuer Eintrag:", "", function(text)
                if string.Trim(text) == "" then return end
                net.Start("PD.Naval.ShipLog") net.WriteString("add") net.WriteString(text) net.SendToServer()
                st.nextList = CurTime() + 0.5
            end)
        end
    end
end)

--------------------------------------------------------------------------------
-- Schildkontrolle (mit Modulations-Minispiel auf dem Hauptbildschirm)
--------------------------------------------------------------------------------

-- Kreuz: Bug oben, Heck unten, Backbord links, Steuerbord rechts; Oben/Unten rechts
local ZONES = {
    {"front", "Bug", 2, 1}, {"left", "Backbord", 1, 2}, {"right", "Steuerbord", 3, 2}, {"back", "Heck", 2, 3},
    {"top", "Oben", 3, 1}, {"bottom", "Unten", 3, 3},
}

local function Combat() return C.status and C.status.combat end

local function SendDist(zone, delta)
    local cs = Combat()
    if not cs then return end
    local dist = {}
    for _, z in ipairs(Naval.Zones) do dist[z] = cs.zones[z].w end
    dist[zone] = math.Clamp(dist[zone] + delta, 0.25, 3)
    Cmd("shields", "dist", {dist = dist})
end

local function DrawWave(x0, y0, w, h, freq, phase, col, noise)
    local last
    local t = CurTime()
    surface.SetDrawColor(col)
    for x = 0, w, 6 do
        local a = x / w * math.pi * freq + math.rad(phase)
        local y = y0 + h / 2 - math.sin(a) * h * 0.35 + (noise and math.sin(x * 0.7 + t * 9) * 5 or 0)
        if last then surface.DrawLine(x0 + last[1], last[2], x0 + x, y) surface.DrawLine(x0 + last[1], last[2] + 1, x0 + x, y + 1) end
        last = {x, y}
    end
end

Register("shields", function(role, w, h, ui, ent, st)
    local cs = Combat()
    local game = Naval.ModGame
    if game and CurTime() - game.start > 30 then Naval.ModGame, game = nil, nil end
    st.zone = st.zone or "front"

    if role == "main" then
        if game then
            ui:Frame(w, h, "SCHILDMODULATION")
            DrawWave(14, 50, w - 28, h - 130, game.tf, game.tp, Color(255, 110, 90), true)
            DrawWave(14, 50, w - 28, h - 130, game.f, game.p, Color(110, 200, 255), false)
            Text(("Frequenz %.1f   Phase %d°"):format(game.f, game.p), "PD.N3D.Small", 22, h - 72, Color(110, 200, 255))
            Text(("noch %d s"):format(math.max(0, 30 - (CurTime() - game.start))), "PD.N3D.Small", w - 22, h - 72, COL.text, TEXT_ALIGN_RIGHT)
            return
        end
        ui:Frame(w, h, "SCHILDZONEN")
        if not cs then return end
        local bw, bh = (w - 40) / 3, 84
        local gap = ((h - 100) - bh * 3) / 2
        for _, z in ipairs(ZONES) do
            local zone = cs.zones[z[1]]
            local x, y = 14 + (z[3] - 1) * (bw + 6), 50 + (z[4] - 1) * (bh + gap)
            local total = (zone.e + zone.m) / math.max(zone.ce + zone.cm, 1)
            local hover = ui.active and ui:Hover(x, y, bw, bh)
            draw.RoundedBox(6, x, y, bw, bh, hover and Color(24, 36, 52) or Color(12, 16, 22))
            surface.SetDrawColor(st.zone == z[1] and Color(255, 230, 90) or (total > 0.5 and COL.accent or (total > 0.2 and COL.warn or COL.bad)))
            surface.DrawOutlinedRect(x, y, bw, bh, st.zone == z[1] and 4 or 2)
            Text(z[2], "PD.N3D.Small", x + bw / 2, y + 4, COL.text, TEXT_ALIGN_CENTER, nil, bw - 12)
            Text(("%d%%"):format(zone.w / 6 * 100), "PD.N3D.Tiny", x + 8, y + bh - 22, COL.dim, nil, TEXT_ALIGN_CENTER)
            ui:Bar(x + 64, y + bh - 34, bw - 72, 8, zone.e / math.max(zone.ce, 1), Color(110, 180, 255))
            ui:Bar(x + 64, y + bh - 20, bw - 72, 8, zone.m / math.max(zone.cm, 1), Color(255, 190, 90))
            if hover and Lib.Input.pressed then st.zone = z[1] surface.PlaySound("buttons/button15.wav") end
        end
        Text(("Strahlen %d %%  /  Partikel %d %%"):format(math.Round(cs.ratio * 100), math.Round((1 - cs.ratio) * 100)), "PD.N3D.Small", 22, h - 40, COL.text)
    elseif role == "s1" then
        Small(ui, w, h, "SCHILDE", cs and (cs.up and "OBEN" or "UNTEN") or "-", cs and (cs.up and COL.ok or COL.bad) or COL.dim)
    elseif role == "s2" then
        local text, col = "STANDARD", COL.dim
        if cs and cs.modLeft then text, col = Time(cs.modLeft), COL.ok
        elseif cs and cs.modBlocked then text, col = Time(cs.modBlocked), COL.warn end
        Small(ui, w, h, "MODULATION", text, col)
    elseif role == "keys" then
        ui:Keypad(w, h)
        local cell = Grid(w, h, 6, 3)
        for i, z in ipairs({"front", "back", "left", "right", "top", "bottom"}) do
            local x, y, bw, bh = cell(i, 1)
            if ui:Button(x, y, bw, bh, Naval.ZoneNames[z] or z, {active = st.zone == z, font = "PD.N3D.Small"}) then st.zone = z end
        end
        local row2 = {
            {"Anteil −", function() SendDist(st.zone, -0.25) end}, {"Anteil +", function() SendDist(st.zone, 0.25) end},
            {"Gleichmäßig", function()
                local dist = {}
                for _, z in ipairs(Naval.Zones) do dist[z] = 1 end
                Cmd("shields", "dist", {dist = dist})
            end},
            {"Strahlen +", function() if cs then Cmd("shields", "ratio", {value = math.Clamp(cs.ratio + 0.1, 0, 1)}) end end},
            {"Ausgewogen", function() Cmd("shields", "ratio", {value = 0.7}) end},
            {"Partikel +", function() if cs then Cmd("shields", "ratio", {value = math.Clamp(cs.ratio - 0.1, 0, 1)}) end end},
        }
        for i, b in ipairs(row2) do
            local x, y, bw, bh = cell(i, 2)
            if ui:Button(x, y, bw, bh, b[1], {font = "PD.N3D.Small", disabled = not cs}) then b[2]() end
        end
        if game then
            local mod = {{"Freq. −", function() game.f = math.Clamp(game.f - 0.2, 1, 9) end}, {"Freq. +", function() game.f = math.Clamp(game.f + 0.2, 1, 9) end},
                {"Phase −", function() game.p = (game.p - 10) % 360 end}, {"Phase +", function() game.p = (game.p + 10) % 360 end}}
            for i, b in ipairs(mod) do
                local x, y, bw, bh = cell(i, 3)
                if ui:Button(x, y, bw, bh, b[1], {col = Color(110, 200, 255)}) then b[2]() end
            end
            local x, y, bw, bh = cell(5, 3, 2)
            if ui:Button(x, y, bw, bh, "ÜBERNEHMEN", {col = COL.ok}) then
                Cmd("shields", "mod_submit", {f = game.f, p = game.p})
                Naval.ModGame = nil
            end
        else
            local x, y, bw, bh = cell(1, 3, 3)
            if ui:Button(x, y, bw, bh, cs and cs.up and "SCHILDE SENKEN" or "SCHILDE HEBEN", {col = cs and cs.up and COL.warn or COL.ok, disabled = not cs}) then
                Cmd("shields", "up", {on = not cs.up})
            end
            x, y, bw, bh = cell(4, 3, 3)
            if ui:Button(x, y, bw, bh, "Modulation anpassen", {disabled = not cs or cs.modBlocked ~= nil}) then Cmd("shields", "mod_start", {}) end
        end
    end
end)

--------------------------------------------------------------------------------
-- Hologramm-Steuerung
--------------------------------------------------------------------------------

local function HoloCmd(action, args) Cmd("holo_control", action, args or {}) end
local function Galaxy() return GetGlobalInt("PD.Naval.HoloMode", 0) == 1 end
local function ZoomText()
    if Galaxy() then
        return (Naval.HoloGalaxyRanges[GetGlobalInt("PD.Naval.HoloGalaxyZoom", Naval.HoloGalaxyDefaultZoom)] or 0) .. " pc"
    end
    return Dist(Naval.HoloRanges[GetGlobalInt("PD.Naval.HoloZoom", Naval.HoloDefaultZoom)] or 0)
end
local SPEEDS = {10, 20, 45}

Register("holo_control", function(role, w, h, ui, ent, st)
    local on = GetGlobalBool("PD.Naval.HoloOn", false)
    local spinAxis = GetGlobalString("PD.Naval.HoloSpinAxis", "")
    st.spin = st.spin or (spinAxis ~= "" and math.Round(GetGlobalFloat("PD.Naval.HoloSpinSpeed", 20)) or 20)

    if role == "main" then
        ui:Frame(w, h, "HOLOGRAMM")
        Text(on and "AN" or "AUS", "PD.N3D.Med", 22, 46, on and COL.ok or COL.bad)
        local focus = GetGlobalString("PD.Naval.HoloFocus", "")
        Text("Mitte: " .. (focus ~= "" and Naval.SystemName(focus) or "unsere Position"), "PD.N3D.Small", w - 22, 54, COL.text, TEXT_ALIGN_RIGHT)
        Text(("Drehung  K %d°  D %d°  R %d°"):format(GetGlobalInt("PD.Naval.HoloRotP", 0), GetGlobalInt("PD.Naval.HoloRotY", 0), GetGlobalInt("PD.Naval.HoloRotR", 0)),
            "PD.N3D.Small", 22, 96, COL.dim)
        Text("Dauerrotation: " .. (spinAxis == "" and "aus" or (({y = "Drehen", p = "Kippen", r = "Rollen"})[spinAxis] or spinAxis)), "PD.N3D.Small", 22, 130, COL.dim)
        Text("EBENEN (antippen)", "PD.N3D.Small", 22, 172, COL.dim)
        local cols = 2
        local lw = (w - 44 - 10) / cols
        for i, l in ipairs(Naval.HoloLayers) do
            local x = 22 + ((i - 1) % cols) * (lw + 10)
            local y = 206 + math.floor((i - 1) / cols) * 54
            local active = Naval.HoloLayer(l.id)
            if ui:Button(x, y, lw, 46, l.name, {active = active, col = active and COL.ok or COL.dim, font = "PD.N3D.Small"}) then
                HoloCmd("layer", {id = l.id, on = not active})
            end
        end
    elseif role == "s1" then
        Small(ui, w, h, "ZOOM", ZoomText(), COL.accent)
    elseif role == "s2" then
        Small(ui, w, h, "ANSICHT", Galaxy() and "GALAXIE" or "TAKTIK", COL.accent)
    elseif role == "keys" then
        ui:Keypad(w, h)
        local cell = Grid(w, h, 6, 3)
        local spinName = {[10] = "langsam", [20] = "mittel", [45] = "schnell"}
        local buttons = {
            {1, 1, on and "AUS" or "AN", function() HoloCmd("power", {on = not on}) end, {col = on and COL.bad or COL.ok}},
            {2, 1, "Taktik", function() HoloCmd("mode", {id = "tactical"}) end, {active = not Galaxy()}},
            {3, 1, "Galaxie", function() HoloCmd("mode", {id = "galaxy"}) end, {active = Galaxy()}},
            {4, 1, "Zoom −", function() HoloCmd("zoom", {delta = 1}) end},
            {5, 1, "Zoom +", function() HoloCmd("zoom", {delta = -1}) end},
            {6, 1, "Unsere Pos.", function() HoloCmd("focus", {}) end},
            {1, 2, "Kippen −", function() HoloCmd("rotate", {axis = "p", delta = -1}) end},
            {2, 2, "Kippen +", function() HoloCmd("rotate", {axis = "p", delta = 1}) end},
            {3, 2, "Drehen −", function() HoloCmd("rotate", {axis = "y", delta = -1}) end},
            {4, 2, "Drehen +", function() HoloCmd("rotate", {axis = "y", delta = 1}) end},
            {5, 2, "Rollen −", function() HoloCmd("rotate", {axis = "r", delta = -1}) end},
            {6, 2, "Rollen +", function() HoloCmd("rotate", {axis = "r", delta = 1}) end},
            {1, 3, "Rot. aus", function() HoloCmd("spin", {axis = "", speed = st.spin}) end, {active = spinAxis == ""}},
            {2, 3, "Rot. Drehen", function() HoloCmd("spin", {axis = "y", speed = st.spin}) end, {active = spinAxis == "y"}},
            {3, 3, "Rot. Kippen", function() HoloCmd("spin", {axis = "p", speed = st.spin}) end, {active = spinAxis == "p"}},
            {4, 3, "Tempo: " .. (spinName[math.abs(st.spin)] or "?"), function()
                local idx = 1
                for i, s in ipairs(SPEEDS) do if s == math.abs(st.spin) then idx = i end end
                st.spin = SPEEDS[idx % #SPEEDS + 1]
                if spinAxis ~= "" then HoloCmd("spin", {axis = spinAxis, speed = st.spin}) end
            end},
            {5, 3, "Zurücksetzen", function() HoloCmd("reset") end, {col = COL.warn}},
            {6, 3, "Als Wand", function()
                HoloCmd("reset")
                timer.Simple(0.2, function() HoloCmd("rotate", {axis = "p", delta = 1}) end)
                timer.Simple(0.4, function() HoloCmd("rotate", {axis = "p", delta = 1}) end)
            end},
        }
        for _, b in ipairs(buttons) do
            local x, y, bw, bh = cell(b[1], b[2])
            local opts = b[5] or {}
            opts.font = "PD.N3D.Small"
            if ui:Button(x, y, bw, bh, b[3], opts) then b[4]() end
        end
    end
end)

--------------------------------------------------------------------------------
-- Sensoren
--------------------------------------------------------------------------------

local LEVEL_TEXT = {[0] = "UNBEKANNT", [1] = "IDENTIFIZIERT", [2] = "GESCANNT"}

local function SensorDetail(ui, w, h, id)
    local info = C.info[id]
    local view = C.View and C.View()
    local ship = view and view.ships[id]
    if not info or not ship then Text("Kontakt verloren", "PD.N3D.Med", 22, 52, COL.dim) return end
    local level = info.ident or 2
    local class = C.static and C.static.classes[info.classId]
    local y = 50
    local function Line(text, col, font)
        Text(text, font or "PD.N3D.Small", 22, y, col)
        y = y + (font == "PD.N3D.Med" and 44 or 34)
    end
    Line(info.name, COL.text, "PD.N3D.Med")
    Line("Entfernung " .. Dist(V3.Dist(ship.pos, view.pos)))
    if level == 0 then
        Line("Größe ca. " .. math.Round((class and class.lengthM or 0) / 50) * 50 .. " m", COL.dim)
        Line("Unbekannt - scannen.", COL.warn)
        return
    end
    local faction = C.static.factions[info.factionId]
    Line(class and class.name or info.classId)
    Line(faction and faction.name or info.factionId, Naval.RelationColors and Naval.RelationColors[Naval.ClientRelation(Naval.MapShipFaction(), info.factionId)] or COL.text)
    Line(("Hülle %d %%"):format(ship.hull or 100), Frac((ship.hull or 100) / 100))
    local c = C.status and C.status.sensors and C.status.sensors.contacts and C.status.sensors.contacts[tostring(id)]
    if level < 2 or not c then Line("Genauer Scan nötig", COL.dim) return end
    Line(("Schilde %d %% (%s)"):format(c.shield or 0, c.up and "oben" or "unten"), c.up and COL.accent or COL.warn)
    if c.morale then Line(("Moral %d %%"):format(c.morale), Frac(c.morale / 100)) end
    if c.surrendered then Line("Hat kapituliert", COL.warn) end
    for _, sub in ipairs(c.subs or {}) do
        if y > h - 30 then break end
        Text(Naval.SubsystemNames[sub.id] or sub.id, "PD.N3D.Small", 22, y, COL.text)
        ui:Bar(w * 0.62, y + 10, w * 0.32, 10, sub.pct / 100, Frac(sub.pct / 100))
        y = y + 30
    end
end

Register("sensors", function(role, w, h, ui, ent, st)
    local sens = C.status and C.status.sensors
    local scan = sens and sens.scan
    local list = Contacts(false)
    if role == "main" then
        if st.detail and st.sel then
            ui:Frame(w, h, "KONTAKT")
            SensorDetail(ui, w, h, st.sel)
            return
        end
        ui:Frame(w, h, "KONTAKTE  -  Reichweite " .. Dist(sens and sens.range or 0))
        local clicked, n = ui:List(14, 50, w - 28, h - 64, list, {rowH = 74, scroll = st.scroll, selected = st.sel, draw = function(c, x, y, iw, ih)
            ContactRow(c, x, y, iw, ih)
            if scan and scan.id == c.id then ui:Bar(x + iw - 130, y + ih - 18, 120, 8, (Naval.Now() - scan.start) / math.max(scan.finish - scan.start, 1), COL.accent) end
        end})
        st.rows = n
        if clicked then st.sel = clicked.id st.detail = true end
    elseif role == "s1" then
        local info = st.sel and C.info[st.sel]
        Small(ui, w, h, "KONTAKT", info and LEVEL_TEXT[info.ident or 2] or "-", info and ((info.ident or 2) == 0 and COL.warn or COL.ok) or COL.dim,
            info and string.sub(info.name, 1, 14))
    elseif role == "s2" then
        local text = "-"
        if scan then text = math.Round(math.Clamp((Naval.Now() - scan.start) / math.max(scan.finish - scan.start, 1), 0, 1) * 100) .. " %" end
        Small(ui, w, h, "SCAN", text, scan and COL.accent or COL.dim)
    elseif role == "keys" then
        ui:Keypad(w, h)
        local cell = Grid(w, h, 4, 2)
        local info = st.sel and C.info[st.sel]
        local x, y, bw, bh = cell(1, 1)
        if ui:Button(x, y, bw, bh, "▲") then st.detail = false Scroll(st, -1, #list, st.rows) end
        x, y, bw, bh = cell(2, 1)
        if ui:Button(x, y, bw, bh, "▼") then st.detail = false Scroll(st, 1, #list, st.rows) end
        x, y, bw, bh = cell(3, 1)
        if ui:Button(x, y, bw, bh, st.detail and "Liste" or "Details", {disabled = not st.sel}) then st.detail = not st.detail end
        x, y, bw, bh = cell(4, 1)
        if ui:Button(x, y, bw, bh, "Scan abbrechen", {col = COL.bad, disabled = scan == nil, font = "PD.N3D.Small"}) then Cmd("sensors", "cancel", {}) end
        x, y, bw, bh = cell(1, 2, 4)
        local label = info and (info.ident or 2) == 0 and "IDENTIFIZIEREN" or "GENAU SCANNEN"
        if ui:Button(x, y, bw, bh, label, {col = COL.ok, disabled = not info or (info.ident or 2) >= 2 or scan ~= nil}) then
            Cmd("sensors", "scan", {id = st.sel})
        end
    end
end)

--------------------------------------------------------------------------------
-- Alarmstufe
--------------------------------------------------------------------------------

Register("alert", function(role, w, h, ui)
    local level = GetGlobalInt("PD.Naval.Alert", 0)
    local colors = Naval.AlertColors or {[0] = COL.ok, [1] = COL.warn, [2] = COL.bad}
    if role == "main" then
        ui:Frame(w, h, "ALARMSTUFE")
        Text(string.upper(Naval.AlertNames[level] or ""), "PD.N3D.Big", w / 2, h / 2 - 20, colors[level], TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        Text(level == 2 and "Schilde automatisch oben" or (level == 1 and "Gefechtsbereitschaft" or "Normalbetrieb"), "PD.N3D.Small", w / 2, h / 2 + 40, COL.dim, TEXT_ALIGN_CENTER)
        Feedback(ui, w, h)
    elseif role == "s1" then
        Small(ui, w, h, "STUFE", tostring(level), colors[level])
    elseif role == "s2" then
        local since = GetGlobalFloat("PD.Naval.AlertSince", 0)
        Small(ui, w, h, "SEIT", since > 0 and Time(CurTime() - since) or "-", COL.text)
    elseif role == "keys" then
        ui:Keypad(w, h)
        local cell = Grid(w, h, 3, 1)
        for l = 0, 2 do
            local x, y, bw, bh = cell(l + 1, 1)
            if ui:Button(x, y, bw, bh, ({[0] = "NORMAL", "GELB", "ROT"})[l], {col = colors[l], active = level == l, font = "PD.N3D.Big"}) then
                Cmd("alert", "set", {level = l})
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- Kommunikation
--------------------------------------------------------------------------------

Register("comms", function(role, w, h, ui, ent, st)
    local comms = C.status and C.status.comms or {}
    local list = Contacts(false)
    local sel
    for _, c in ipairs(list) do if c.id == st.sel then sel = c end end
    if st.sel and not sel then st.sel = nil end
    st.view = st.view or "log"

    if role == "main" then
        if st.view == "list" then
            ui:Frame(w, h, "KONTAKTE (antippen = wählen)")
            local clicked, n = ui:List(14, 50, w - 28, h - 64, list, {rowH = 74, scroll = st.scroll, selected = st.sel, draw = ContactRow})
            st.rows = n
            if clicked then st.sel = st.sel ~= clicked.id and clicked.id or nil end
            return
        end
        ui:Frame(w, h, "FUNKPROTOKOLL")
        local log = comms.log or {}
        local y = h - 16
        for i = #log, 1, -1 do
            local e = log[i]
            local col = e.own and COL.accent or (e.kind == "distress" and COL.bad or (e.kind == "surrender" and COL.warn or COL.text))
            local lines = ui.Wrap(e.text, 30)
            y = y - (#lines * 30 + 30)
            if y < 46 then break end
            Text(os.date("%H:%M", e.t or 0) .. "  " .. (e.from or "?"), "PD.N3D.Small", 22, y, COL.dim)
            for k, l in ipairs(lines) do Text(l, "PD.N3D.Small", 22, y + k * 30, col) end
        end
    elseif role == "s1" then
        Small(ui, w, h, "AN", sel and string.sub(sel.name, 1, 12) or "ALLE", sel and COL.accent or COL.dim)
    elseif role == "s2" then
        local wait = comms.distressIn or 0
        Small(ui, w, h, "NOTRUF", wait > 0 and Time(wait) or "BEREIT", wait > 0 and COL.warn or COL.ok)
    elseif role == "keys" then
        ui:Keypad(w, h)
        local cell = Grid(w, h, 6, 3)
        local x, y, bw, bh = cell(1, 1)
        if ui:Button(x, y, bw, bh, "▲") then Scroll(st, -1, #list, st.rows) end
        x, y, bw, bh = cell(2, 1)
        if ui:Button(x, y, bw, bh, "▼") then Scroll(st, 1, #list, st.rows) end
        x, y, bw, bh = cell(3, 1, 2)
        if ui:Button(x, y, bw, bh, st.view == "list" and "Funkprotokoll" or "Kontakte", {active = st.view == "list"}) then
            st.view = st.view == "list" and "log" or "list"
        end
        x, y, bw, bh = cell(5, 1, 2)
        if ui:Button(x, y, bw, bh, "Nachricht", {col = COL.ok}) then
            local to = st.sel
            Derma_StringRequest("Kommunikation", to and ("Nachricht an " .. (sel and sel.name or "?") .. ":") or "Nachricht an alle:", "", function(text)
                if string.Trim(text) ~= "" then Cmd("comms", "say", {id = to or 0, text = text}) end
            end)
        end
        x, y, bw, bh = cell(1, 2, 2)
        if ui:Button(x, y, bw, bh, "Rufen", {disabled = not sel}) then Cmd("comms", "hail", {id = sel.id}) end
        x, y, bw, bh = cell(3, 2, 2)
        if ui:Button(x, y, bw, bh, "Kapitulation fordern", {col = COL.warn, disabled = not sel or sel.surrendered, font = "PD.N3D.Small"}) then
            Cmd("comms", "demand", {id = sel.id})
        end
        x, y, bw, bh = cell(5, 2, 2)
        if ui:Button(x, y, bw, bh, "Kapitulation annehmen", {col = COL.ok, disabled = not sel or not sel.surrendered, font = "PD.N3D.Small"}) then
            Cmd("comms", "accept", {id = sel.id})
        end
        x, y, bw, bh = cell(1, 3, 3)
        if ui:Confirm(st, "distress", x, y, bw, bh, "NOTRUF", {col = COL.bad, disabled = (comms.distressIn or 0) > 0}) then Cmd("comms", "distress", {}) end
        x, y, bw, bh = cell(4, 3, 3)
        if ui:Confirm(st, "offer", x, y, bw, bh, "Eigene Kapitulation anbieten", {col = COL.warn, font = "PD.N3D.Small"}) then Cmd("comms", "offer", {}) end
    end
end)

--------------------------------------------------------------------------------
-- Logistik
--------------------------------------------------------------------------------

Register("logistics", function(role, w, h, ui, ent, st)
    local l = C.status and C.status.logistics
    st.order = st.order or {}
    local total = 0
    for _, n in pairs(st.order) do total = total + n end

    if role == "main" then
        ui:Frame(w, h, "LOGISTIK")
        if not l then return end
        local y = 50
        if not l.enabled then Text("Nachschub-System AUS", "PD.N3D.Small", 22, y, COL.warn) y = y + 36 end
        for _, kind in ipairs(Naval.SupplyOrder) do
            local def = Naval.SupplyKinds[kind]
            local a = l.ammo[kind]
            if a then
                Text(("%s %d / %d"):format(def.unit or def.name, a.cur, a.max), "PD.N3D.Small", 22, y, COL.text)
                ui:Bar(22, y + 34, w - 44, 10, a.max > 0 and a.cur / a.max or 0, def.color)
                y = y + 58
            end
        end
        Text(("Hülle %d / %d"):format(l.hull, l.hullMax), "PD.N3D.Small", 22, y, COL.text)
        ui:Bar(22, y + 34, w - 44, 10, l.hull / math.max(l.hullMax, 1), COL.ok)
        y = y + 64
        local status = l.delivery and ("Lieferung kommt in " .. Time(l.delivery.eta)) or (l.available and ("Verfügbar: " .. (l.reason or "")) or (l.reason or ""))
        for _, line in ipairs(ui.Wrap(status, 30)) do
            Text(line, "PD.N3D.Small", 22, y, (l.available or l.delivery) and COL.ok or COL.warn)
            y = y + 32
        end
        if l.drops == 0 or l.intakes == 0 then Text("Anlieferung/Annahme fehlen!", "PD.N3D.Small", 22, h - 40, COL.bad) end
    elseif role == "s1" then
        Small(ui, w, h, "LIEFERUNG", l and l.delivery and Time(l.delivery.eta) or "-", l and l.delivery and COL.accent or COL.dim)
    elseif role == "s2" then
        local on = 0
        for _, n in pairs(l and l.onBoard or {}) do on = on + n end
        Small(ui, w, h, "KISTEN AN BORD", tostring(on), COL.text, l and l.cooldown > 0 and ("Sperre " .. Time(l.cooldown)) or nil)
    elseif role == "keys" then
        ui:Keypad(w, h)
        local cell = Grid(w, h, 6, 3)
        for r, kind in ipairs(Naval.SupplyOrder) do
            local def = Naval.SupplyKinds[kind]
            local x, y, bw, bh = cell(1, r, 2)
            draw.RoundedBox(6, x, y, bw, bh, Color(30, 33, 38))
            Text(def.name, "PD.N3D.Small", x + bw / 2, y + bh / 2, def.color, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            x, y, bw, bh = cell(3, r)
            if ui:Button(x, y, bw, bh, "−") then st.order[kind] = math.max(0, (st.order[kind] or 0) - 1) end
            x, y, bw, bh = cell(4, r)
            Text(tostring(st.order[kind] or 0), "PD.N3D.Big", x + bw / 2, y + bh / 2, COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            x, y, bw, bh = cell(5, r)
            if ui:Button(x, y, bw, bh, "+", {disabled = not l or total >= (l.maxCrates or 8)}) then st.order[kind] = (st.order[kind] or 0) + 1 end
        end
        local x, y, bw, bh = cell(6, 1)
        if ui:Button(x, y, bw, bh, "ANFORDERN", {col = COL.ok, disabled = not (l and l.available) or total == 0, font = "PD.N3D.Small"}) then
            Cmd("logistics", "order", {crates = st.order})
            st.order = {}
        end
        if LocalPlayer():IsAdmin() then
            x, y, bw, bh = cell(6, 2)
            if ui:Button(x, y, bw, bh, "Admin: sofort", {col = COL.warn, font = "PD.N3D.Small"}) then
                Cmd("logistics", "adminDeliver", {crates = st.order})
                st.order = {}
            end
            x, y, bw, bh = cell(6, 3)
            if ui:Button(x, y, bw, bh, l and l.enabled and "System: AN" or "System: AUS", {col = l and l.enabled and COL.ok or COL.bad, font = "PD.N3D.Small"}) then
                Cmd("logistics", "adminToggle", {})
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- Umstationierung (auch auf Planeten-Maps, ohne laufende Simulation)
--------------------------------------------------------------------------------

Register("relocation", function(role, w, h, ui, ent, st)
    local rs = Naval.RelocateGetState and Naval.RelocateGetState() or {}
    if role == "main" then
        if Near(ent, 250) and CurTime() > (st.nextPoll or 0) then
            st.nextPoll = CurTime() + 1
            net.Start("PD.Naval.RelocateState")
            net.SendToServer()
        end
        ui:Frame(w, h, "UMSTATIONIERUNG")
        if rs.mode == "planet" and rs.back then
            Text("Auf " .. (rs.back.body or "dem Planeten"), "PD.N3D.Med", 22, 52, COL.accent)
            for i, line in ipairs(ui.Wrap("Rückflug freigeben, dann mit einem Fahrzeug an den Rand der Map fliegen.", 30)) do
                Text(line, "PD.N3D.Small", 22, 100 + (i - 1) * 32, COL.text)
            end
            return
        end
        if not rs.body then
            for i, line in ipairs(ui.Wrap(rs.reason or "Lade ...", 30)) do Text(line, "PD.N3D.Small", 22, 52 + (i - 1) * 32, COL.dim) end
            return
        end
        Text("Orbit: " .. rs.body, "PD.N3D.Med", 22, 48, COL.accent)
        local items = {}
        for _, m in ipairs(rs.maps or {}) do items[#items + 1] = m end
        local clicked, n = ui:List(14, 100, w - 28, h - 114, items, {rowH = 80, scroll = st.scroll, selected = st.selMap, draw = function(m, x, y, iw, ih)
            Text(m.name, "PD.N3D.Small", x + 12, y + 6, m.exists and COL.text or COL.dim)
            Text(m.exists and string.sub(m.description ~= "" and m.description or m.map, 1, 32) or "Map fehlt auf dem Server", "PD.N3D.Small", x + 12, y + ih - 6,
                m.exists and COL.dim or COL.bad, nil, TEXT_ALIGN_BOTTOM)
        end})
        st.rows = n
        if clicked and clicked.exists then st.selMap = clicked.id end
    elseif role == "s1" then
        local a = rs.armed
        local text, col = "-", COL.dim
        if a then
            if a.countdown then text, col = a.countdown .. " s", COL.warn
            else text, col = Time(a.remaining), COL.ok end
        end
        Small(ui, w, h, a and a.countdown and "MAPWECHSEL" or "FREIGABE", text, col)
    elseif role == "s2" then
        Small(ui, w, h, "ZIEL", rs.armed and string.sub(rs.armed.name or "", 1, 12) or "-", rs.armed and COL.accent or COL.dim)
    elseif role == "keys" then
        ui:Keypad(w, h)
        local cell = Grid(w, h, 4, 2)
        local x, y, bw, bh = cell(1, 1)
        if ui:Button(x, y, bw, bh, "▲") then Scroll(st, -1, #(rs.maps or {}), st.rows) end
        x, y, bw, bh = cell(1, 2)
        if ui:Button(x, y, bw, bh, "▼") then Scroll(st, 1, #(rs.maps or {}), st.rows) end
        x, y, bw, bh = cell(2, 1, 2)
        if rs.mode == "planet" then
            if ui:Confirm(st, "back", x, y, bw, bh, "Rückflug freigeben", {col = COL.ok, disabled = rs.armed ~= nil}) and Naval.RelocateSend then Naval.RelocateSend("arm") end
        elseif ui:Confirm(st, "arm", x, y, bw, bh, "Umstationieren", {col = COL.ok, disabled = rs.armed ~= nil or not st.selMap}) and Naval.RelocateSend then
            Naval.RelocateSend("arm", st.selMap)
        end
        x, y, bw, bh = cell(2, 2, 2)
        Text("Beim Mapwechsel gehen alle mit.", "PD.N3D.Small", x + bw / 2, y + bh / 2, COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        x, y, bw, bh = cell(4, 1, 1, 2)
        if ui:Button(x, y, bw, bh, "Abbrechen", {col = COL.bad, disabled = not rs.armed or rs.armed.countdown ~= nil}) and Naval.RelocateSend then
            Naval.RelocateSend("cancel")
        end
    end
end)

--------------------------------------------------------------------------------
-- Navigationscomputer (grosse Konsole)
--------------------------------------------------------------------------------

local function SendNav(action, arg)
    net.Start("PD.Naval.Nav")
    net.WriteString(action)
    if arg then net.WriteString(arg) end
    net.SendToServer()
end

local function Bodies()
    local view = C.View and C.View()
    local sys = C.system
    local list = {}
    if not view or not sys or sys.systemId ~= view.systemId or not sys.bodiesById then return list end
    local now = Naval.Now()
    for id, b in pairs(sys.bodiesById) do
        list[#list + 1] = {id = id, name = b.name, type = b.type, dist = V3.Dist(Naval.BodyPos(b, sys.bodiesById, now), view.pos)}
    end
    table.sort(list, function(a, b) return a.dist < b.dist end)
    return list
end

local BODY_TYPE = {star = "Stern", planet = "Planet", moon = "Mond", station = "Station"}
local NAV_SPEEDS = {1, 0.75, 0.5, 0.25}

Register("navcomputer", function(role, w, h, ui, ent, st)
    local s = C.status or {}
    local nav = s.nav
    local bodies = Bodies()
    st.speed = st.speed or 1

    -- Auswahl: standardmaessig das erste Ziel der Liste, Pfeile bewegen sie
    local selIndex
    for i, b in ipairs(bodies) do if b.id == st.selBody then selIndex = i end end
    if not selIndex and bodies[1] then st.selBody, selIndex = bodies[1].id, 1 end
    local function MoveSel(d)
        if #bodies == 0 then return end
        selIndex = math.Clamp((selIndex or 1) + d, 1, #bodies)
        st.selBody = bodies[selIndex].id
        local rows = st.rows or 5
        if selIndex <= (st.scroll or 0) then st.scroll = selIndex - 1
        elseif selIndex > (st.scroll or 0) + rows then st.scroll = selIndex - rows end
    end

    if role == "main" then
        ui:Frame(w, h, "HYPERRAUM-KURS")
        local y = 50
        local function Line(text, col, font)
            Text(text, font or "PD.N3D.Small", 22, y, col)
            y = y + (font == "PD.N3D.Med" and 44 or 34)
        end
        Line("Hier: " .. Naval.SystemName(s.system), COL.text, "PD.N3D.Med")
        if not nav then
            Line("Kein Sprungziel", COL.dim)
            Line("Ziel: Karte öffnen", COL.dim)
        elseif not nav.ready then
            Line("Berechne Kurs nach", COL.warn)
            Line(Naval.SystemName(nav.target), COL.warn, "PD.N3D.Med")
            ui:Bar(22, y, w - 44, 14, (Naval.Now() - nav.start) / math.max(nav.finish - nav.start, 1), COL.warn)
            y = y + 30
        else
            Line("Ziel: " .. Naval.SystemName(nav.target), nav.valid and COL.ok or COL.bad, "PD.N3D.Med")
            Line("Sprungdauer " .. Time(nav.duration))
            for _, line in ipairs(ui.Wrap(nav.routes and #nav.routes > 0 and ("Über " .. table.concat(nav.routes, ", ")) or "Direktsprung", 30)) do
                if y > h - 60 then break end
                Line(line, COL.dim)
            end
            if not nav.valid then Line(nav.reason or "Ungültig", COL.bad) end
        end
        Feedback(ui, w, h)
    elseif role == "main2" then
        ui:Frame(w, h, "SYSTEM - Ziel antippen")
        local clicked, n = ui:List(14, 50, w - 28, h - 64, bodies, {rowH = 64, scroll = st.scroll, selected = st.selBody, draw = function(b, x, y, iw, ih)
            Text(b.name, "PD.N3D.Small", x + 12, y + ih / 2, COL.text, nil, TEXT_ALIGN_CENTER)
            Text((BODY_TYPE[b.type] or b.type) .. "  " .. Dist(b.dist), "PD.N3D.Small", x + iw - 10, y + ih / 2, COL.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end})
        st.rows = n
        if clicked then st.selBody = clicked.id end
    elseif role == "s1" then
        local text, col = "AUS", COL.dim
        if s.auto then text, col = s.auto.arrived and "DA" or Time(s.auto.eta), COL.ok end
        Small(ui, w, h, "AUTOPILOT", text, col, s.auto and string.sub(s.auto.label or "", 1, 14) or nil)
    elseif role == "s2" then
        local text, col = "-", COL.dim
        if nav and not nav.ready then text, col = math.Round(math.Clamp((Naval.Now() - nav.start) / math.max(nav.finish - nav.start, 1), 0, 1) * 100) .. " %", COL.warn
        elseif nav and nav.ready then text, col = nav.valid and "BEREIT" or "UNGÜLTIG", nav.valid and COL.ok or COL.bad end
        Small(ui, w, h, "KURSLÖSUNG", text, col)
    elseif role == "keys" then
        ui:Keypad(w, h)
        local cell = Grid(w, h, 4, 3)
        local normal = s.state == "normal"
        local function Go(mode)
            SendNav("auto", util.TableToJSON({legs = {{kind = "body", id = st.selBody, mode = mode}}, speed = st.speed}))
        end
        -- "auto" erwartet die Argumente als JSON-Zeichenkette
        local x, y, bw, bh = cell(1, 1)
        if ui:Button(x, y, bw, bh, "Anfliegen", {disabled = not st.selBody or not normal}) then Go("stop") end
        x, y, bw, bh = cell(2, 1)
        if ui:Button(x, y, bw, bh, "Orbit", {disabled = not st.selBody or not normal}) then Go("orbit") end
        x, y, bw, bh = cell(3, 1)
        if ui:Button(x, y, bw, bh, ("Tempo %d %%"):format(st.speed * 100), {font = "PD.N3D.Small"}) then
            local idx = 1
            for i, v in ipairs(NAV_SPEEDS) do if v == st.speed then idx = i end end
            st.speed = NAV_SPEEDS[idx % #NAV_SPEEDS + 1]
        end
        x, y, bw, bh = cell(4, 1)
        if ui:Button(x, y, bw, bh, "Autopilot aus", {col = COL.bad, disabled = s.auto == nil, font = "PD.N3D.Small"}) then SendNav("auto_off") end
        x, y, bw, bh = cell(1, 2, 2)
        if ui:Button(x, y, bw, bh, "▲") then MoveSel(-1) end
        x, y, bw, bh = cell(3, 2, 2)
        if ui:Confirm(st, "clear", x, y, bw, bh, "Kurs verwerfen", {col = COL.warn, disabled = not nav}) then SendNav("clear") end
        x, y, bw, bh = cell(1, 3, 2)
        if ui:Button(x, y, bw, bh, "▼") then MoveSel(1) end
        x, y, bw, bh = cell(3, 3, 2)
        if ui:Button(x, y, bw, bh, "Zum Sprungpunkt", {disabled = not (nav and nav.ready and nav.valid) or not normal}) then
            SendNav("auto", util.TableToJSON({kind = "jumppoint", speed = st.speed}))
        end
    elseif role == "b1" then
        ui:Keypad(w, h)
        if ui:Button(10, 10, w - 20, h - 20, "KARTE", {col = COL.ok}) and Naval.StationUI.navcomputer then
            Naval.StationUI.navcomputer(ent)
        end
    elseif role == "b2" then
        ui:Keypad(w, h)
        if ui:Button(10, 10, w - 20, h - 20, "Ziel im\nHolo-\ngramm", {disabled = not nav}) then SendNav("holo_focus", nav.target) end
    elseif role == "b3" then
        ui:Keypad(w, h)
        if ui:Button(10, 10, w - 20, h - 20, "Holo-\ngramm:\nunsere\nPosition") then SendNav("holo_focus", "") end
    end
end)

--------------------------------------------------------------------------------
-- Waffenleitstand (grosse Konsole)
--------------------------------------------------------------------------------

Register("weapons", function(role, w, h, ui, ent, st)
    local cs = Combat()
    local list = Contacts(true)
    local t = cs and cs.target

    if role == "main" then
        ui:Frame(w, h, "KONTAKTE - antippen = Ziel")
        local clicked, n = ui:List(14, 50, w - 28, h - 64, list, {rowH = 74, scroll = st.scroll, selected = t and t.id, draw = function(c, x, y, iw, ih, sel)
            ContactRow(c, x, y, iw, ih)
            if sel then Text("ZIEL", "PD.N3D.Small", x + iw - 10, y + ih - 6, COL.bad, TEXT_ALIGN_RIGHT, TEXT_ALIGN_BOTTOM) end
        end})
        st.rows = n
        if clicked then Cmd("weapons", "target", {id = clicked.id}) end
    elseif role == "main2" then
        ui:Frame(w, h, "BATTERIEN - antippen = an/aus")
        if not cs then return end
        if t then
            Text(("%s  %s"):format(string.sub(t.name, 1, 16), Dist(t.dist)), "PD.N3D.Small", 22, 48, COL.bad)
        end
        local items = {}
        for i, b in ipairs(cs.batteries or {}) do items[#items + 1] = {id = i, b = b} end
        local clicked = ui:List(14, 86, w - 28, h - 100, items, {rowH = 62, draw = function(it, x, y, iw, ih)
            local b = it.b
            Text(("%s ×%d"):format(string.sub(b.name, 1, 16), b.count), "PD.N3D.Small", x + 10, y + 4, b.on and COL.text or COL.dim)
            local state = b.on and "AN" or "AUS"
            if b.on and t then state = not b.inArc and "nicht im Bogen" or (not b.inRange and "zu weit" or ("bereit " .. math.Round((b.chance or 0) * 100) .. "%")) end
            Text(state, "PD.N3D.Small", x + iw - 10, y + 4, b.on and ((b.inArc and b.inRange) and COL.ok or COL.warn) or COL.dim, TEXT_ALIGN_RIGHT)
            if b.ammo then Text(("Munition %d/%d"):format(b.ammo, b.maxAmmo), "PD.N3D.Small", x + 10, y + ih - 2, b.ammo > 0 and COL.dim or COL.bad, nil, TEXT_ALIGN_BOTTOM) end
        end})
        if clicked then Cmd("weapons", "battery", {idx = clicked.id, on = not clicked.b.on}) end
    elseif role == "s1" then
        Small(ui, w, h, "ZIEL", t and Dist(t.dist) or "-", t and COL.bad or COL.dim, t and string.sub(t.name, 1, 14) or nil)
    elseif role == "s2" then
        Small(ui, w, h, "FEUER", cs and cs.fire and "FREI" or "HALT", cs and cs.fire and COL.bad or COL.dim)
    elseif role == "keys" then
        ui:Keypad(w, h)
        local cell = Grid(w, h, 6, 3)
        local x, y, bw, bh = cell(1, 1, 4)
        if ui:Button(x, y, bw, bh, cs and cs.fire and "FEUER EINSTELLEN" or "FEUER FREI", {col = cs and cs.fire and COL.bad or COL.ok, disabled = not cs, font = "PD.N3D.Big"}) then
            Cmd("weapons", "fire", {on = not cs.fire})
        end
        x, y, bw, bh = cell(5, 1)
        if ui:Button(x, y, bw, bh, "▲") then Scroll(st, -1, #list, st.rows) end
        x, y, bw, bh = cell(6, 1)
        if ui:Button(x, y, bw, bh, "▼") then Scroll(st, 1, #list, st.rows) end
        -- Subsystem-Ziel (nach genauem Scan)
        local scanned = t and Naval.ContactLevel and Naval.ContactLevel(t.id) >= 2
        local sens = C.status and C.status.sensors
        local contact = scanned and sens and sens.contacts and sens.contacts[tostring(t.id)]
        local subs = {{id = "", name = "Ganzes Schiff"}}
        for _, sub in ipairs(contact and contact.subs or {}) do
            subs[#subs + 1] = {id = sub.id, name = ("%s %d%%"):format(Naval.SubsystemNames[sub.id] or sub.id, sub.pct)}
        end
        for i = 1, 12 do
            local sub = subs[i]
            if not sub then break end
            x, y, bw, bh = cell((i - 1) % 6 + 1, 2 + math.floor((i - 1) / 6))
            local current = (cs and cs.targetSub) or ""
            if ui:Button(x, y, bw, bh, string.sub(sub.name, 1, 16), {active = current == sub.id, disabled = not scanned, font = "PD.N3D.Small"}) then
                Cmd("weapons", "subtarget", {sub = sub.id})
            end
        end
        if not scanned then
            x, y, bw, bh = cell(2, 2, 5)
            Text("Subsysteme: Ziel erst an den Sensoren genau scannen", "PD.N3D.Small", x + bw / 2, y + bh / 2, COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end
    elseif role == "b1" or role == "b3" then
        ui:Keypad(w, h)
        local on = role == "b1"
        if ui:Button(10, 10, w - 20, h - 20, on and "ALLE AN" or "ALLE AUS", {col = on and COL.ok or COL.warn, font = "PD.N3D.Small", disabled = not cs}) then
            for i, b in ipairs(cs.batteries or {}) do
                if b.on ~= on then Cmd("weapons", "battery", {idx = i, on = on}) end
            end
        end
    elseif role == "b2" then
        ui:Keypad(w, h)
        if ui:Button(10, 10, w - 20, h - 20, "Nächster Feind", {col = COL.bad, font = "PD.N3D.Small"}) then
            for _, c in ipairs(list) do
                if c.relation == "hostile" then Cmd("weapons", "target", {id = c.id}) break end
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- Maschinenraum (grosse Konsole)
--------------------------------------------------------------------------------

local PRESETS = {
    {"Ausgewogen", {engines = 25, shields = 25, weapons = 25, sensors = 25}},
    {"Gefecht", {engines = 15, shields = 35, weapons = 40, sensors = 10}},
    {"Flucht", {engines = 45, shields = 35, weapons = 5, sensors = 15}},
}

Register("engineering", function(role, w, h, ui, ent, st)
    local cs = Combat()
    if not st.values then
        st.values = {}
        for _, sys in ipairs(Naval.PowerSystems) do st.values[sys.id] = cs and cs.power and cs.power[sys.id] or 25 end
    end
    local sum = 0
    for _, v in pairs(st.values) do sum = sum + v end

    if role == "main2" then
        ui:Frame(w, h, "ENERGIEVERTEILUNG")
        if not cs then return end
        local y = 50
        for _, sys in ipairs(Naval.PowerSystems) do
            local v = st.values[sys.id]
            local live = cs.power and cs.power[sys.id]
            Text(sys.name, "PD.N3D.Small", 22, y, COL.text)
            Text(v .. " %" .. (live and live ~= v and ("  (jetzt " .. live .. ")") or ""), "PD.N3D.Small", w - 22, y, live ~= v and COL.warn or COL.text, TEXT_ALIGN_RIGHT)
            ui:Bar(22, y + 34, w - 44, 12, v / 60, COL.accent)
            y = y + 70
        end
        Text(("Reaktor %d %%  -  verteilt %d %%"):format(cs.output, sum), "PD.N3D.Small", 22, y, sum > 100 and COL.bad or (sum > cs.output and COL.warn or COL.ok))
        if sum > 100 then Text("ÜBERLAST", "PD.N3D.Med", 22, y + 36, COL.bad) end
    elseif role == "main" then
        ui:Frame(w, h, "ZUSTAND")
        if not cs then return end
        Text(("Hülle %d / %d"):format(cs.hull, cs.hullMax), "PD.N3D.Small", 22, 46, COL.text)
        ui:Bar(22, 80, w - 44, 12, cs.hull / math.max(cs.hullMax, 1), Frac(cs.hull / math.max(cs.hullMax, 1)))
        local systems = cs.systems or {}
        local step = math.min(30, (h - 120) / math.max(#systems, 1))
        local y = 104
        for _, sub in ipairs(systems) do
            local f = sub.hp / math.max(sub.max, 1)
            Text(Naval.SubsystemNames[sub.id] or sub.id, "PD.N3D.Tiny", 22, y, f <= 0 and COL.bad or COL.text, nil, nil, w * 0.55)
            ui:Bar(w * 0.62, y + 8, w * 0.32, 8, f, Frac(f))
            y = y + step
        end
    elseif role == "s1" then
        Small(ui, w, h, "REAKTOR", cs and (cs.output .. " %") or "-", COL.accent)
    elseif role == "s2" then
        Small(ui, w, h, "VERTEILT", sum .. " %", sum > 100 and COL.bad or ((cs and sum > cs.output) and COL.warn or COL.ok))
    elseif role == "keys" then
        ui:Keypad(w, h)
        local cell = Grid(w, h, 6, 3)
        local i = 0
        for _, sys in ipairs(Naval.PowerSystems) do
            local c = i % 3 * 2 + 1
            local r = math.floor(i / 3) + 1
            local x, y, bw, bh = cell(c, r)
            if ui:Button(x, y, bw, bh, sys.name .. " −", {font = "PD.N3D.Small"}) then st.values[sys.id] = math.max(0, st.values[sys.id] - 5) end
            x, y, bw, bh = cell(c + 1, r)
            if ui:Button(x, y, bw, bh, sys.name .. " +", {font = "PD.N3D.Small"}) then st.values[sys.id] = math.min(60, st.values[sys.id] + 5) end
            i = i + 1
        end
        for k, p in ipairs(PRESETS) do
            local x, y, bw, bh = cell(2 + k, 2)
            if ui:Button(x, y, bw, bh, p[1], {font = "PD.N3D.Small"}) then
                for id, v in pairs(p[2]) do st.values[id] = v end
            end
        end
        local x, y, bw, bh = cell(1, 3, 3)
        if ui:Button(x, y, bw, bh, "Zurücksetzen", {col = COL.warn}) then st.values = nil end
        x, y, bw, bh = cell(4, 3, 3)
        if ui:Button(x, y, bw, bh, "ÜBERNEHMEN", {col = COL.ok, disabled = not cs}) then Cmd("engineering", "power", st.values) end
    end
end)

--------------------------------------------------------------------------------
-- Schadenskontrolle (grosse Konsole)
--------------------------------------------------------------------------------

local KIND_COLOR = {sparks = Color(255, 220, 120), smoke = Color(180, 180, 190), fire = Color(255, 120, 60)}

Register("damagecontrol", function(role, w, h, ui, ent, st)
    local cs = Combat()
    local dc = C.status and C.status.dc or {}
    st.team = math.Clamp(st.team or 1, 1, math.max(dc.teamCount or 1, 1))

    if role == "main" then
        ui:Frame(w, h, "SUBSYSTEME")
        if not cs then return end
        local y = 48
        local step = math.min(34, (h - 64) / math.max(#(cs.systems or {}), 1))
        for _, sub in ipairs(cs.systems or {}) do
            local f = sub.hp / math.max(sub.max, 1)
            local working = {}
            for i = 1, dc.teamCount or 0 do if (dc.teams or {})[i] == sub.id then working[#working + 1] = tostring(i) end end
            Text(Naval.SubsystemNames[sub.id] or sub.id, "PD.N3D.Tiny", 22, y, f <= 0 and COL.bad or COL.text, nil, nil, w * 0.42)
            if #working > 0 then Text("T" .. table.concat(working, ","), "PD.N3D.Tiny", w * 0.6, y, COL.accent, TEXT_ALIGN_RIGHT) end
            ui:Bar(w * 0.64, y + 8, w * 0.3, 8, f, Frac(f))
            y = y + step
        end
    elseif role == "main2" then
        ui:Frame(w, h, "SCHÄDEN AN BORD")
        if (dc.points or 0) == 0 then Text("Keine Schadenspunkte aufgestellt", "PD.N3D.Small", 22, 52, COL.warn) return end
        local list = dc.incidents or {}
        if #list == 0 then Text("Keine Schäden gemeldet", "PD.N3D.Med", 22, 52, COL.ok) return end
        local y = 48
        for _, inc in ipairs(list) do
            if y > h - 70 then break end
            local kind = Naval.IncidentKinds[inc.kind] or {}
            draw.RoundedBox(6, 14, y, w - 28, 62, Color(12, 16, 22))
            surface.SetDrawColor(KIND_COLOR[inc.kind] or COL.text)
            surface.DrawRect(14, y, 6, 62)
            Text((kind.name or inc.kind) .. " - " .. string.sub(inc.where or "?", 1, 18), "PD.N3D.Small", 28, y + 2, COL.text)
            Text(("seit %s"):format(Time(inc.age)), "PD.N3D.Small", 28, y + 58, COL.dim, nil, TEXT_ALIGN_BOTTOM)
            if (inc.progress or 0) > 0 then ui:Bar(w - 160, y + 40, 130, 10, inc.progress, COL.ok) end
            y = y + 68
        end
    elseif role == "s1" then
        local f = cs and cs.hull / math.max(cs.hullMax, 1) or 0
        Small(ui, w, h, "HÜLLE", cs and (math.Round(f * 100) .. " %") or "-", Frac(f))
    elseif role == "s2" then
        Small(ui, w, h, "SCHÄDEN", tostring(#(dc.incidents or {})), #(dc.incidents or {}) > 0 and COL.warn or COL.ok)
    elseif role == "keys" then
        ui:Keypad(w, h)
        local cell = Grid(w, h, 6, 3)
        local x, y, bw, bh = cell(1, 1)
        if ui:Button(x, y, bw, bh, "◄ Trupp") then st.team = st.team > 1 and st.team - 1 or (dc.teamCount or 1) end
        x, y, bw, bh = cell(6, 1)
        if ui:Button(x, y, bw, bh, "Trupp ►") then st.team = st.team % math.max(dc.teamCount or 1, 1) + 1 end
        local current = (dc.teams or {})[st.team] or ""
        local targets = {{"", "Bereitschaft"}, {"hull", "Hülle"}}
        for _, sub in ipairs(cs and cs.systems or {}) do targets[#targets + 1] = {sub.id, Naval.SubsystemNames[sub.id] or sub.id} end
        x, y, bw, bh = cell(2, 1, 4)
        draw.RoundedBox(6, x, y, bw, bh, Color(30, 33, 38))
        local curName = "Bereitschaft"
        for _, t in ipairs(targets) do if t[1] == current then curName = t[2] end end
        Text(("Trupp %d / %d:  %s"):format(st.team, dc.teamCount or 0, curName), "PD.N3D.Med", x + bw / 2, y + bh / 2, COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        for i = 1, 12 do
            local t = targets[i]
            if not t then break end
            x, y, bw, bh = cell((i - 1) % 6 + 1, 2 + math.floor((i - 1) / 6))
            if ui:Button(x, y, bw, bh, string.sub(t[2], 1, 16), {active = current == t[1], disabled = (dc.teamCount or 0) == 0, font = "PD.N3D.Small"}) then
                Cmd("damagecontrol", "assign", {team = st.team, target = t[1]})
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- Flottenfuehrung (grosse Konsole)
--------------------------------------------------------------------------------

local ROE = {{id = "hold", name = "Feuer halten"}, {id = "return", name = "Zurückschießen"}, {id = "free", name = "Feuer frei"}}

local function MemberLine(m)
    if m.surrendered then return "kapituliert" end
    if m.state ~= "normal" then return m.state == "hyperspace" and "im Hyperraum" or "springt" end
    if not m.dist then return "anderes System" end
    if m.slotDist and m.slotDist < 3000 then return "in Formation" end
    if m.slotDist then return "schließt auf" end
    return Dist(m.dist)
end

Register("fleetcmd", function(role, w, h, ui, ent, st)
    local f = C.status and C.status.fleet
    local lead = f and f.isFlagship

    local members = f and f.members or {}
    local selM
    for _, m in ipairs(members) do if m.id == st.selMember then selM = m end end
    if not selM and members[1] then selM = members[1] st.selMember = selM.id end

    if role == "main" then
        ui:Frame(w, h, "FLOTTE - Schiff antippen")
        if not f then
            for i, line in ipairs(ui.Wrap("Dieses Schiff führt keine Flotte. Begleitschiffe teilt die Spielleitung zu.", 30)) do
                Text(line, "PD.N3D.Small", 22, 52 + (i - 1) * 32, COL.dim)
            end
            return
        end
        Text(f.name, "PD.N3D.Med", 22, 46, COL.text, nil, nil, w - 44)
        Text(lead and (#members .. " Begleitschiffe") or ("Wir folgen " .. (f.flagship or "?")), "PD.N3D.Small", 22, 90, lead and COL.dim or COL.warn, nil, nil, w - 44)
        local clicked, n = ui:List(14, 128, w - 28, h - 142, members, {rowH = 70, scroll = st.scroll, selected = st.selMember, draw = function(m, x, y, iw, ih)
            local hf = (m.hull or 0) / 100
            Text(m.name, "PD.N3D.Small", x + 10, y + 4, m.surrendered and COL.warn or COL.text, nil, nil, iw * 0.55)
            Text(MemberLine(m), "PD.N3D.Small", x + iw - 10, y + 4, COL.dim, TEXT_ALIGN_RIGHT, nil, iw * 0.4)
            ui:Bar(x + 10, y + ih - 16, iw - 20, 8, hf, Frac(hf))
        end})
        st.rows = n
        if clicked then st.selMember = clicked.id end
    elseif role == "main2" then
        ui:Frame(w, h, "GEWÄHLTES SCHIFF")
        if not selM then Text("Kein Begleitschiff", "PD.N3D.Small", 22, 52, COL.dim) return end
        local class = C.static and C.static.classes[selM.classId]
        local y = 50
        Text(selM.name, "PD.N3D.Med", 22, y, COL.text, nil, nil, w - 44) y = y + 46
        Text(class and class.name or selM.classId, "PD.N3D.Small", 22, y, COL.dim, nil, nil, w - 44) y = y + 40
        Text(("Hülle %d %%"):format(selM.hull or 0), "PD.N3D.Small", 22, y, Frac((selM.hull or 0) / 100)) y = y + 36
        if selM.morale then Text(("Moral %d %%"):format(selM.morale), "PD.N3D.Small", 22, y, Frac(selM.morale / 100)) y = y + 36 end
        Text(MemberLine(selM), "PD.N3D.Small", 22, y, COL.accent, nil, nil, w - 44)
        Feedback(ui, w, h)
    elseif role == "s1" then
        local name = "-"
        for _, e in ipairs(Naval.Formations) do if f and e.id == f.formation then name = e.name end end
        Small(ui, w, h, "FORMATION", string.upper(name), COL.accent)
    elseif role == "s2" then
        local name = "-"
        for _, e in ipairs(Naval.FleetModes) do if f and e.id == f.mode then name = e.name end end
        Small(ui, w, h, "BEFEHL", string.sub(name, 1, 12), COL.accent)
    elseif role == "keys" then
        ui:Keypad(w, h)
        local cell = Grid(w, h, 6, 3)
        for i, e in ipairs(Naval.Formations) do
            local x, y, bw, bh = cell(i, 1)
            if ui:Button(x, y, bw, bh, e.name, {active = f and f.formation == e.id, disabled = not lead, font = "PD.N3D.Small"}) then Cmd("fleetcmd", "formation", {id = e.id}) end
        end
        for i, e in ipairs(Naval.FleetModes) do
            local x, y, bw, bh = cell(i, 2)
            if ui:Button(x, y, bw, bh, e.name, {active = f and f.mode == e.id, disabled = not lead, font = "PD.N3D.Small"}) then Cmd("fleetcmd", "mode", {id = e.id}) end
        end
        for i, e in ipairs(ROE) do
            local x, y, bw, bh = cell(3 + i, 2)
            if ui:Button(x, y, bw, bh, e.name, {col = COL.warn, disabled = not lead, font = "PD.N3D.Small"}) then Cmd("fleetcmd", "roe", {roe = e.id}) end
        end
        local x, y, bw, bh = cell(1, 3, 3)
        if ui:Button(x, y, bw, bh, "Enger (−25 %)", {disabled = not lead}) then Cmd("fleetcmd", "spacing", {factor = 0.75}) end
        x, y, bw, bh = cell(4, 3, 3)
        if ui:Button(x, y, bw, bh, "Weiter (+33 %)", {disabled = not lead}) then Cmd("fleetcmd", "spacing", {factor = 1.33}) end
    elseif role == "b1" then
        ui:Keypad(w, h)
        if ui:Button(10, 10, w - 20, h - 20, "Nächstes\nSchiff", {disabled = #members < 2}) then
            local idx = 1
            for i, m in ipairs(members) do if m.id == st.selMember then idx = i end end
            local ni = idx % #members + 1
            st.selMember = members[ni].id
            local rows = st.rows or 3
            if ni <= (st.scroll or 0) then st.scroll = ni - 1 elseif ni > (st.scroll or 0) + rows then st.scroll = ni - rows end
        end
    elseif role == "b2" then
        ui:Keypad(w, h)
        if ui:Button(10, 10, w - 20, h - 20, "Zu uns\nrufen", {col = COL.ok, disabled = not lead or not selM}) then
            Cmd("fleetcmd", "recall", {id = selM.id})
        end
    elseif role == "b3" then
        ui:Keypad(w, h)
        if ui:Button(10, 10, w - 20, h - 20, "In anderes\nSystem\nbeordern", {col = COL.warn, disabled = not lead or not selM}) then
            local id = selM.id
            local nav = C.status and C.status.nav
            Derma_StringRequest("Flottenführung", "System für " .. selM.name .. ":", nav and Naval.SystemName(nav.target) or "", function(text)
                if string.Trim(text) ~= "" then Cmd("fleetcmd", "send", {id = id, system = text}) end
            end)
        end
    end
end)

--------------------------------------------------------------------------------
-- Traktorstrahl und Entern (grosse Konsole)
--------------------------------------------------------------------------------

Register("tractor", function(role, w, h, ui, ent, st)
    local t = C.status and C.status.tractor
    local held = t and t.held
    local b = t and t.boarding
    local contacts = t and t.contacts or {}

    if role == "main" then
        ui:Frame(w, h, "SCHIFFE IN DER NÄHE")
        if not t then Text("Kein Traktorstrahl an Bord", "PD.N3D.Small", 22, 52, COL.dim) return end
        local clicked, n = ui:List(14, 50, w - 28, h - 64, contacts, {rowH = 74, scroll = st.scroll, selected = st.sel, draw = function(c, x, y, iw, ih)
            Text(string.sub(c.name, 1, 18), "PD.N3D.Small", x + 12, y + 4, c.ok and COL.text or COL.dim)
            Text(Dist(c.dist), "PD.N3D.Small", x + iw - 10, y + 4, COL.text, TEXT_ALIGN_RIGHT)
            Text(c.ok and (c.defenseless and "wehrlos - greifbar" or "greifbar") or string.sub(c.reason or "", 1, 30), "PD.N3D.Small", x + 12, y + ih - 4,
                c.ok and COL.ok or COL.dim, nil, TEXT_ALIGN_BOTTOM)
        end})
        st.rows = n
        if clicked then st.sel = clicked.id end
    elseif role == "main2" then
        ui:Frame(w, h, "STRAHL UND ENTERKOMMANDO")
        if not t then return end
        local y = 50
        if held then
            Text("Hält: " .. string.sub(held.name, 1, 16), "PD.N3D.Med", 22, y, COL.accent)
            y = y + 46
            Text(held.docked and "angedockt" or (held.pull and "wird herangezogen" or "gehalten"), "PD.N3D.Small", 22, y, COL.text)
            y = y + 34
            if held.shields then Text("Schilde des Ziels oben", "PD.N3D.Small", 22, y, COL.warn) y = y + 34 end
            if not held.defenseless then Text("Ziel wehrt sich", "PD.N3D.Small", 22, y, COL.warn) y = y + 34 end
        else
            Text("Strahl frei", "PD.N3D.Med", 22, y, COL.dim)
            y = y + 46
        end
        y = y + 14
        if b then
            Text("Enterkommando auf " .. string.sub(b.name, 1, 12), "PD.N3D.Small", 22, y, COL.text)
            Text(("Erfolgsaussicht %d %%"):format(b.chance), "PD.N3D.Small", 22, y + 34, COL.dim)
            ui:Bar(22, y + 74, w - 44, 14, b.progress, COL.warn)
            if b.remaining <= 0 and b.live then Text("wartet auf die Spielleitung", "PD.N3D.Small", 22, y + 100, COL.warn) end
        elseif t.cooldown > 0 then
            Text("Kommando sammelt sich: " .. Time(t.cooldown), "PD.N3D.Small", 22, y, COL.warn)
        end
        Feedback(ui, w, h)
    elseif role == "s1" then
        Small(ui, w, h, "STRAHL", held and Dist(held.dist) or "-", held and (held.docked and COL.ok or COL.accent) or COL.dim)
    elseif role == "s2" then
        Small(ui, w, h, "ENTERN", b and (math.Round(b.progress * 100) .. " %") or "-", b and COL.warn or COL.dim)
    elseif role == "keys" then
        ui:Keypad(w, h)
        local cell = Grid(w, h, 4, 2)
        local selC
        for _, c in ipairs(contacts) do if c.id == st.sel then selC = c end end
        local x, y, bw, bh = cell(1, 1)
        if ui:Button(x, y, bw, bh, "GREIFEN", {col = COL.accent, disabled = held ~= nil or not (selC and selC.ok)}) then Cmd("tractor", "lock", {id = st.sel}) end
        x, y, bw, bh = cell(2, 1)
        if ui:Button(x, y, bw, bh, "Heranziehen", {active = held and held.pull, disabled = not held}) then Cmd("tractor", "pull", {on = not held.pull}) end
        x, y, bw, bh = cell(3, 1)
        if ui:Button(x, y, bw, bh, "Lösen", {col = COL.bad, disabled = not held or b ~= nil}) then Cmd("tractor", "release") end
        x, y, bw, bh = cell(4, 1)
        if ui:Confirm(st, "board", x, y, bw, bh, "ENTERN", {col = COL.warn, disabled = not (held and held.docked) or held.shields or b ~= nil or (t and t.cooldown > 0)}) then
            Cmd("tractor", "board")
        end
        x, y, bw, bh = cell(1, 2)
        if ui:Button(x, y, bw, bh, "▲") then Scroll(st, -1, #contacts, st.rows) end
        x, y, bw, bh = cell(2, 2)
        if ui:Button(x, y, bw, bh, "▼") then Scroll(st, 1, #contacts, st.rows) end
        if LocalPlayer():IsAdmin() and b and b.live and b.remaining <= 0 then
            x, y, bw, bh = cell(3, 2)
            if ui:Button(x, y, bw, bh, "SL: Erfolg", {col = COL.ok, font = "PD.N3D.Small"}) then Cmd("tractor", "resolve", {ok = true}) end
            x, y, bw, bh = cell(4, 2)
            if ui:Button(x, y, bw, bh, "SL: abgewehrt", {col = COL.bad, font = "PD.N3D.Small"}) then Cmd("tractor", "resolve", {ok = false}) end
        end
    end
end)
