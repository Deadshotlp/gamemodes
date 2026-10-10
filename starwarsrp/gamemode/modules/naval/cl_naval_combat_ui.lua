--[[
    Naval - Kampfkonsolen (Client): Waffenleitstand, Schildkontrolle,
    Maschinenraum. Zustand aus C.status.combat (2 Hz), Befehle ueber
    PD.Naval.CombatCmd (sv_naval_stations_combat.lua).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C

local function Cmd(station, action, args)
    net.Start("PD.Naval.CombatCmd")
    net.WriteString(station)
    net.WriteString(action)
    net.WriteString(util.TableToJSON(args or {}) or "{}")
    net.SendToServer()
end

Naval.CombatCmd = Cmd

local function Combat()
    return C.status and C.status.combat
end

-- Erkennungsstufe eines Kontakts (Sensoren): 0 unbekannt, 1, 2 genau
function Naval.ContactLevel(id)
    local info = C.info[id]
    if info and info.ident then return info.ident end
    return 2
end

local ZONE_SHORT = {front = "B", back = "H", left = "BB", right = "SB", top = "O", bottom = "U"}

local function DistText(m)
    return Naval.FormatDist and Naval.FormatDist(m) or (math.Round(m / 1000) .. " km")
end

local function HullBar(UI, x, y, w, h, frac, label)
    local col = frac > 0.5 and UI.COL.ok or (frac > 0.25 and UI.COL.warn or UI.COL.bad)
    UI.Bar(x, y, w, h, frac, col)
    if label then draw.SimpleText(label, "MLIB.14", x + w / 2, y + h / 2, UI.COL.text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER) end
end

--------------------------------------------------------------------------------
-- Waffenleitstand
--------------------------------------------------------------------------------

local function OpenWeapons(console)
    local UI = Naval.UI
    local COL = UI.COL
    local frame = UI.Frame("WAFFENLEITSTAND", 1180, 720)
    frame.Console = console

    -- Kontakte
    local contacts = vgui.Create("DScrollPanel", frame)
    contacts:SetPos(20, 55)
    contacts:SetSize(360, frame:GetTall() - 75)

    local rows = {}
    local function Contacts()
        local view = C.View and C.View()
        local list = {}
        if not view then return list end

        local myFaction = Naval.MapShipFaction and Naval.MapShipFaction()
        for id, s in pairs(view.ships or {}) do
            local info = C.info[id]
            if info and s.state ~= "destroyed" and s.det ~= false then
                local rel = Naval.V3.Sub(s.pos, view.pos)
                list[#list + 1] = {id = id, name = info.name, classId = info.classId, dist = Naval.V3.Len(rel), hull = s.hull or 100,
                    relation = Naval.ClientRelation and Naval.ClientRelation(myFaction, info.factionId) or "neutral", state = s.state}
            end
        end

        table.sort(list, function(a, b)
            if (a.relation == "hostile") ~= (b.relation == "hostile") then return a.relation == "hostile" end
            return a.dist < b.dist
        end)
        return list
    end

    local REL_COL = {hostile = COL.bad, neutral = COL.warn, ally = COL.accent, unknown = Color(175, 175, 185)}

    for i = 1, 30 do
        local row = contacts:Add("DButton")
        row:Dock(TOP)
        row:DockMargin(0, 0, 0, 3)
        row:SetTall(46)
        row:SetText("")
        row.Index = i
        row.DoClick = function(s)
            if s.Contact then
                surface.PlaySound("buttons/button15.wav")
                Cmd("weapons", "target", {id = s.Contact.id})
            end
        end
        row.Paint = function(s, w, h)
            local c = s.Contact
            if not c then return end
            local cs = Combat() or {}
            local selected = cs.target and cs.target.id == c.id
            draw.RoundedBox(0, 0, 0, w, h, selected and Color(60, 30, 30) or COL.panel)
            surface.SetDrawColor(REL_COL[c.relation] or COL.text)
            surface.DrawRect(0, 0, 4, h)
            local class = C.static and C.static.classes[c.classId]
            draw.SimpleText(c.name, "MLIB.16", 12, 4, COL.text)
            local known = Naval.ContactLevel(c.id) >= 1
            draw.SimpleText(known and (class and class.name or c.classId) or ("Größe ca. " .. math.Round((class and class.lengthM or 0) / 50) * 50 .. " m"),
                "MLIB.12", 12, 24, COL.dim)
            draw.SimpleText(DistText(c.dist), "MLIB.14", w - 8, 4, COL.text, TEXT_ALIGN_RIGHT)
            if known then HullBar(UI, w - 88, 26, 80, 10, c.hull / 100) end
            if selected then draw.SimpleText("ZIEL", "MLIB.12", w - 8, 36, COL.bad, TEXT_ALIGN_RIGHT) end
        end
        rows[i] = row
    end

    -- Ziel und Batterien
    local main = vgui.Create("DPanel", frame)
    main:SetPos(395, 55)
    main:SetSize(frame:GetWide() - 415, frame:GetTall() - 145)
    main.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL.panel)
        local cs = Combat()
        if not cs then
            draw.SimpleText("Keine Daten", "MLIB.18", w / 2, h / 2, COL.dim, TEXT_ALIGN_CENTER)
            return
        end

        local t = cs.target
        if t then
            draw.SimpleText("ZIEL: " .. t.name, "MLIB.22", 14, 10, COL.bad)
            local known = Naval.ContactLevel(t.id) >= 1
            draw.SimpleText(("%s  -  liegt %s%s"):format(DistText(t.dist), Naval.ZoneNames[t.zone] or "?", known and ("  -  Hülle " .. t.hull .. " %") or ""),
                "MLIB.16", 14, 40, COL.text)
        else
            draw.SimpleText("Kein Ziel - Kontakt links wählen", "MLIB.18", 14, 14, COL.dim)
        end

        -- Kopfzeile
        local y = 80
        draw.SimpleText("Batterie", "MLIB.14", 14, y, COL.dim)
        draw.SimpleText("Bogen", "MLIB.14", w * 0.42, y, COL.dim)
        draw.SimpleText("Reichweite", "MLIB.14", w * 0.55, y, COL.dim)
        draw.SimpleText("Lage", "MLIB.14", w * 0.70, y, COL.dim)
        draw.SimpleText("Treffer", "MLIB.14", w * 0.82, y, COL.dim)
    end

    local batteryButtons = {}
    for i = 1, 8 do
        local row = vgui.Create("DPanel", main)
        row:SetPos(8, 100 + (i - 1) * 44)
        row:SetSize(main:GetWide() - 16, 40)
        row.Paint = function(s, w, h)
            local cs = Combat()
            local b = cs and cs.batteries and cs.batteries[i]
            if not b then return end

            draw.RoundedBox(0, 0, 0, w, h, b.on and Color(30, 38, 50) or Color(24, 24, 28))
            draw.SimpleText(("%s  ×%d"):format(b.name, b.count), "MLIB.16", 8, 4, b.on and COL.text or COL.dim)
            if b.ammo then draw.SimpleText(("Munition %d / %d"):format(b.ammo, b.maxAmmo), "MLIB.12", 8, 22, b.ammo > 0 and COL.dim or COL.bad) end

            if b.stations then
                -- Geschuetzstellungen: intakt / im Bogen des Ziels
                local text = (b.alive or 0) .. " intakt"
                if cs.target then text = (b.inArcCount or 0) .. " im Bogen, " .. text end
                draw.SimpleText(text, "MLIB.14", w * 0.42 - 8, 12, (b.alive or 0) < (b.count or 0) and COL.warn or COL.dim)
            else
                local arc = {}
                for _, z in ipairs(b.arc or {}) do arc[#arc + 1] = ZONE_SHORT[z] or z end
                draw.SimpleText(table.concat(arc, " "), "MLIB.14", w * 0.42 - 8, 12, COL.dim)
            end
            draw.SimpleText(DistText(b.range or 0), "MLIB.14", w * 0.55 - 8, 12, COL.dim)

            if cs.target then
                local ok = b.inArc and b.inRange
                local text = not b.inArc and "nicht im Bogen" or (not b.inRange and "zu weit" or "bereit")
                draw.SimpleText(text, "MLIB.14", w * 0.70 - 8, 12, ok and COL.ok or COL.warn)
                if b.chance then draw.SimpleText(math.Round(b.chance * 100) .. " %", "MLIB.14", w * 0.82 - 8, 12, COL.text) end
            end
        end

        local toggle = UI.Button(row, "", function()
            local cs = Combat()
            local b = cs and cs.batteries and cs.batteries[i]
            if b then Cmd("weapons", "battery", {idx = i, on = not b.on}) end
        end)
        toggle:SetSize(70, 30)
        toggle:SetPos(row:GetWide() - 76, 5)
        toggle.Think = function(s)
            local cs = Combat()
            local b = cs and cs.batteries and cs.batteries[i]
            s:SetVisible(b ~= nil)
            if b then s.Label = b.on and "AN" or "AUS" end
        end
        batteryButtons[i] = toggle
    end

    -- Subsystem-Ziel (nach genauem Scan an den Sensoren)
    local subRow = vgui.Create("DPanel", main)
    subRow:SetPos(8, main:GetTall() - 48)
    subRow:SetSize(main:GetWide() - 16, 40)
    subRow.Paint = function(s, w, h)
        local cs = Combat()
        draw.RoundedBox(0, 0, 0, w, h, Color(30, 38, 50))
        draw.SimpleText("Subsystem-Ziel", "MLIB.16", 8, h / 2, COL.text, nil, TEXT_ALIGN_CENTER)
        if cs and cs.target and Naval.ContactLevel(cs.target.id) < 2 then
            draw.SimpleText("erst an den Sensoren genau scannen", "MLIB.14", w - 8, h / 2, COL.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
        end
    end

    local subCombo = vgui.Create("DComboBox", subRow)
    subCombo:SetPos(150, 6)
    subCombo:SetSize(300, 28)
    subCombo:SetFont("MLIB.14")
    subCombo.OnSelect = function(_, _, _, data)
        surface.PlaySound("buttons/button15.wav")
        Cmd("weapons", "subtarget", {sub = data})
    end
    local subKey
    subCombo.Think = function(s)
        local cs = Combat()
        local tid = cs and cs.target and cs.target.id
        local open = tid and Naval.ContactLevel(tid) >= 2
        s:SetVisible(open == true)
        if not open then subKey = nil return end

        local key = tostring(tid) .. ":" .. tostring(cs.targetSub)
        if key == subKey or s:IsMenuOpen() then return end
        subKey = key

        s:Clear()
        s:AddChoice("Ganzes Schiff", "", cs.targetSub == nil)
        local sens = C.status and C.status.sensors
        local contact = sens and sens.contacts and sens.contacts[tostring(tid)]
        for _, sub in ipairs(contact and contact.subs or {}) do
            s:AddChoice(("%s (%d %%)"):format(Naval.SubsystemNames[sub.id] or sub.id, sub.pct), sub.id, cs.targetSub == sub.id)
        end
    end

    local fire = UI.Button(frame, "", function()
        local cs = Combat()
        if cs then Cmd("weapons", "fire", {on = not cs.fire}) end
    end, function()
        local cs = Combat()
        return cs and cs.fire and COL.bad or COL.ok
    end)
    fire:SetPos(395, frame:GetTall() - 80)
    fire:SetSize(frame:GetWide() - 415, 60)

    local baseThink = frame.Think
    frame.Think = function(s)
        if baseThink then baseThink(s) end
        if not IsValid(s) then return end

        local list = Contacts()
        for i, row in ipairs(rows) do
            row.Contact = list[i]
            row:SetVisible(list[i] ~= nil)
        end

        local cs = Combat()
        fire.Label = cs and cs.fire and "FEUER EINSTELLEN" or "FEUER FREI"
    end
end

--------------------------------------------------------------------------------
-- Schildkontrolle
--------------------------------------------------------------------------------

local function OpenShields(console)
    local UI = Naval.UI
    local COL = UI.COL
    local frame = UI.Frame("SCHILDKONTROLLE", 1000, 700)
    frame.Console = console

    -- Zonen im Kreuz: Bug oben, Heck unten, Backbord links, Steuerbord rechts,
    -- Oben/Unten rechts daneben
    local LAYOUT = {
        front = {1, 0}, left = {0, 1}, right = {2, 1}, back = {1, 2}, top = {3.3, 0.5}, bottom = {3.3, 1.5},
    }
    local BW, BH = 170, 130

    local function SendDist(zone, delta)
        local cs = Combat()
        if not cs then return end
        local dist = {}
        for _, z in ipairs(Naval.Zones) do dist[z] = cs.zones[z].w end
        dist[zone] = math.Clamp(dist[zone] + delta, 0.25, 3)
        Cmd("shields", "dist", {dist = dist})
    end

    for zone, pos in pairs(LAYOUT) do
        local box = vgui.Create("DPanel", frame)
        box:SetPos(30 + pos[1] * (BW + 10), 60 + pos[2] * (BH + 10))
        box:SetSize(BW, BH)
        box.Paint = function(s, w, h)
            local cs = Combat()
            draw.RoundedBox(0, 0, 0, w, h, COL.panel)
            if not cs then return end
            local z = cs.zones[zone]
            local total = (z.e + z.m) / math.max(z.ce + z.cm, 1)
            surface.SetDrawColor(total > 0.5 and COL.accent or (total > 0.2 and COL.warn or COL.bad))
            surface.DrawOutlinedRect(0, 0, w, h, 2)

            draw.SimpleText(Naval.ZoneNames[zone] or zone, "MLIB.18", 10, 6, COL.text)
            draw.SimpleText(("Strahlen %d / %d"):format(z.e, z.ce), "MLIB.12", 10, 32, COL.dim)
            UI.Bar(10, 48, w - 20, 8, z.e / math.max(z.ce, 1), Color(110, 180, 255))
            draw.SimpleText(("Partikel %d / %d"):format(z.m, z.cm), "MLIB.12", 10, 60, COL.dim)
            UI.Bar(10, 76, w - 20, 8, z.m / math.max(z.cm, 1), Color(255, 190, 90))
            draw.SimpleText(("Anteil %.0f %%"):format(z.w / 6 * 100), "MLIB.14", w / 2, 100, COL.text, TEXT_ALIGN_CENTER)
        end

        local minus = UI.Button(box, "−", function() SendDist(zone, -0.25) end)
        minus:SetPos(8, BH - 32) minus:SetSize(30, 26)
        local plus = UI.Button(box, "+", function() SendDist(zone, 0.25) end)
        plus:SetPos(BW - 38, BH - 32) plus:SetSize(30, 26)
    end

    -- Mitte: Schiff
    local center = vgui.Create("DPanel", frame)
    center:SetPos(30 + BW + 10, 60 + BH + 10)
    center:SetSize(BW, BH)
    center.Paint = function(s, w, h)
        local cs = Combat()
        draw.SimpleText("SCHIFF", "MLIB.18", w / 2, h / 2 - 10, COL.dim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        if cs then
            draw.SimpleText(cs.up and "SCHILDE OBEN" or "SCHILDE UNTEN", "MLIB.14", w / 2, h - 18, cs.up and COL.ok or COL.bad, TEXT_ALIGN_CENTER)
        end
    end

    -- Strahlen/Partikel
    local info = vgui.Create("DPanel", frame)
    info:SetPos(30, 500)
    info:SetSize(frame:GetWide() - 60, 60)
    info.Paint = function(s, w, h)
        local cs = Combat()
        draw.RoundedBox(0, 0, 0, w, h, COL.panel)
        if not cs then return end
        draw.SimpleText(("Strahlenschild %d %%   /   Partikelschild %d %%"):format(math.Round(cs.ratio * 100), math.Round((1 - cs.ratio) * 100)),
            "MLIB.16", 12, 6, COL.text)
        draw.SimpleText("Strahlen gegen Laser und Turbolaser, Partikel gegen Raketen und Torpedos", "MLIB.12", 12, 30, COL.dim)
    end

    local ratioButtons = {
        {"Strahlen +", 0.1}, {"Ausgewogen", nil}, {"Partikel +", -0.1},
    }
    for i, d in ipairs(ratioButtons) do
        local b = UI.Button(frame, d[1], function()
            local cs = Combat()
            if not cs then return end
            Cmd("shields", "ratio", {value = d[2] and math.Clamp(cs.ratio + d[2], 0, 1) or 0.7})
        end)
        b:SetPos(30 + (i - 1) * 170, 570)
        b:SetSize(160, 40)
    end

    local toggle = UI.Button(frame, "", function()
        local cs = Combat()
        if cs then Cmd("shields", "up", {on = not cs.up}) end
    end, function()
        local cs = Combat()
        return cs and cs.up and COL.warn or COL.ok
    end)
    toggle:SetPos(frame:GetWide() - 330, 570)
    toggle:SetSize(300, 40)

    local even = UI.Button(frame, "Gleichmäßig verteilen", function()
        local dist = {}
        for _, z in ipairs(Naval.Zones) do dist[z] = 1 end
        Cmd("shields", "dist", {dist = dist})
    end)
    even:SetPos(frame:GetWide() - 330, 620)
    even:SetSize(300, 40)

    local mod = UI.Button(frame, "Modulation anpassen", function()
        Cmd("shields", "mod_start", {})
    end, function()
        local cs = Combat()
        return cs and cs.modLeft and COL.ok or COL.accent
    end)
    mod:SetPos(30, 620)
    mod:SetSize(330, 40)

    local modInfo = vgui.Create("DPanel", frame)
    modInfo:SetPos(370, 620)
    modInfo:SetSize(frame:GetWide() - 710, 40)
    modInfo.Paint = function(s, w, h)
        local cs = Combat()
        if not cs then return end
        if cs.modLeft then
            draw.SimpleText("Modulation aktiv: " .. Naval.UI.Fmt(cs.modLeft), "MLIB.14", 4, h / 2, COL.ok, nil, TEXT_ALIGN_CENTER)
        elseif cs.modBlocked then
            draw.SimpleText(("Modulator kühlt ab: %d s"):format(cs.modBlocked), "MLIB.14", 4, h / 2, COL.warn, nil, TEXT_ALIGN_CENTER)
        else
            draw.SimpleText("Modulation: Standard", "MLIB.14", 4, h / 2, COL.dim, nil, TEXT_ALIGN_CENTER)
        end
    end

    local baseThink = frame.Think
    frame.Think = function(s)
        if baseThink then baseThink(s) end
        local cs = Combat()
        toggle.Label = cs and cs.up and "SCHILDE SENKEN" or "SCHILDE HEBEN"
    end
end

--------------------------------------------------------------------------------
-- Schildmodulation (Minispiel): eigene Welle auf die feindliche Frequenz
-- und Phase einstellen, dann uebernehmen. 30 s Zeit.
--------------------------------------------------------------------------------

local function OpenModGame(targetF, targetP)
    local UI = Naval.UI
    local COL = UI.COL
    local frame = UI.Frame("SCHILDMODULATION", 760, 480)
    local started = CurTime()
    local f, p = 5, 180

    local wave = vgui.Create("DPanel", frame)
    wave:SetPos(20, 55)
    wave:SetSize(frame:GetWide() - 40, 230)
    wave.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, Color(6, 10, 16))
        local t = CurTime()
        local function DrawWave(freq, phase, col, noise)
            local last
            for x = 0, w, 3 do
                local a = x / w * math.pi * 2 * freq * 0.5 + math.rad(phase)
                local y = h / 2 - math.sin(a) * h * 0.35 + (noise and math.sin(x * 0.7 + t * 9) * 4 or 0)
                if last then
                    surface.SetDrawColor(col)
                    surface.DrawLine(last[1], last[2], x, y)
                end
                last = {x, y}
            end
        end
        DrawWave(targetF, targetP, Color(255, 110, 90), true)
        DrawWave(f, p, Color(110, 200, 255), false)
        draw.SimpleText("Feindliche Waffenfrequenz", "MLIB.14", 8, 6, Color(255, 110, 90))
        draw.SimpleText("Schildmodulation", "MLIB.14", 8, 24, Color(110, 200, 255))
        draw.SimpleText(("Zeit: %d s"):format(math.max(0, 30 - (CurTime() - started))), "MLIB.14", w - 8, 6, COL.text, TEXT_ALIGN_RIGHT)
    end

    local function Slider(y, label, min, max, decimals, get, set)
        local sl = vgui.Create("DNumSlider", frame)
        sl:SetPos(20, y)
        sl:SetSize(frame:GetWide() - 40, 40)
        sl:SetText(label)
        sl:SetMin(min) sl:SetMax(max) sl:SetDecimals(decimals)
        sl:SetValue(get())
        sl.Label:SetTextColor(COL.text)
        sl.Label:SetFont("MLIB.16")
        sl.OnValueChanged = function(_, v) set(v) end
        return sl
    end

    Slider(300, "Frequenz", 1, 9, 1, function() return f end, function(v) f = v end)
    Slider(345, "Phase", 0, 359, 0, function() return p end, function(v) p = v end)

    local apply = UI.Button(frame, "ÜBERNEHMEN", function()
        Cmd("shields", "mod_submit", {f = f, p = p})
        frame:Close()
    end, function() return COL.ok end)
    apply:SetPos(20, frame:GetTall() - 70)
    apply:SetSize(frame:GetWide() - 40, 50)

    frame.Think = function(s)
        if CurTime() - started > 30 then s:Close() end
    end
end

net.Receive("PD.Naval.ModGame", function()
    local f = net.ReadFloat()
    local p = net.ReadUInt(9)
    local def = Naval.Stations and Naval.Stations.shields
    if def and def.ui3d and Naval.Console3D and Naval.Console3D.shields then
        Naval.ModGame = {tf = f, tp = p, f = 5, p = 180, start = CurTime()}
        return
    end
    OpenModGame(f, p)
end)

--------------------------------------------------------------------------------
-- Maschinenraum
--------------------------------------------------------------------------------

local function OpenEngineering(console)
    local UI = Naval.UI
    local COL = UI.COL
    local frame = UI.Frame("MASCHINENRAUM", 1100, 700)
    frame.Console = console

    local values = {}
    local cs0 = Combat()
    for _, sys in ipairs(Naval.PowerSystems) do
        values[sys.id] = cs0 and cs0.power and cs0.power[sys.id] or 25
    end

    local left = vgui.Create("DPanel", frame)
    left:SetPos(20, 55)
    left:SetSize(520, frame:GetTall() - 75)
    left.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL.panel)
        local cs = Combat()
        draw.SimpleText("ENERGIEVERTEILUNG", "MLIB.18", 14, 10, COL.text)
        if not cs then return end

        local sum = 0
        for _, v in pairs(values) do sum = sum + v end
        draw.SimpleText(("Reaktor liefert %d %%   -   verteilt %d %%"):format(cs.output, sum), "MLIB.16", 14, 40,
            sum > 100 and COL.bad or (sum > cs.output and COL.warn or COL.ok))
        if sum > 100 then
            draw.SimpleText("ÜBERLAST: Reaktor nimmt Schaden", "MLIB.14", 14, 62, COL.bad)
        end
    end

    local y = 95
    for _, sys in ipairs(Naval.PowerSystems) do
        local row = vgui.Create("DPanel", left)
        row:SetPos(14, y)
        row:SetSize(492, 70)
        row.Paint = function(s, w, h)
            local cs = Combat()
            draw.SimpleText(sys.name, "MLIB.18", 0, 4, COL.text)
            draw.SimpleText(values[sys.id] .. " %", "MLIB.18", w - 100, 4, COL.text, TEXT_ALIGN_RIGHT)
            UI.Bar(0, 32, w - 100, 14, values[sys.id] / 60, COL.accent)
            if cs and cs.factors then
                draw.SimpleText(("Wirkung %d %%"):format(math.Round((cs.factors[sys.id] or 0) * 100)), "MLIB.12", 0, 50, COL.dim)
            end
        end

        local minus = UI.Button(row, "−5", function()
            values[sys.id] = math.max(0, values[sys.id] - 5)
        end)
        minus:SetPos(402, 26) minus:SetSize(42, 28)
        local plus = UI.Button(row, "+5", function()
            values[sys.id] = math.min(60, values[sys.id] + 5)
        end)
        plus:SetPos(450, 26) plus:SetSize(42, 28)

        y = y + 78
    end

    local presets = {
        {"Ausgewogen", {engines = 25, shields = 25, weapons = 25, sensors = 25}},
        {"Gefecht", {engines = 15, shields = 35, weapons = 40, sensors = 10}},
        {"Flucht", {engines = 45, shields = 35, weapons = 5, sensors = 15}},
    }
    for i, p in ipairs(presets) do
        local b = UI.Button(left, p[1], function()
            for k, v in pairs(p[2]) do values[k] = v end
        end)
        b:SetPos(14 + (i - 1) * 166, y + 6)
        b:SetSize(158, 36)
    end

    local apply = UI.Button(left, "ÜBERNEHMEN", function()
        Cmd("engineering", "power", values)
    end, function() return COL.ok end)
    apply:SetPos(14, y + 52)
    apply:SetSize(492, 44)

    -- Rechts: Huelle und Subsysteme
    local right = vgui.Create("DPanel", frame)
    right:SetPos(555, 55)
    right:SetSize(frame:GetWide() - 575, frame:GetTall() - 75)
    right.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, COL.panel)
        local cs = Combat()
        draw.SimpleText("ZUSTAND", "MLIB.18", 14, 10, COL.text)
        if not cs then return end

        draw.SimpleText(("Hülle %d / %d"):format(cs.hull, cs.hullMax), "MLIB.16", 14, 42, COL.text)
        HullBar(UI, 14, 66, w - 28, 14, cs.hull / math.max(cs.hullMax, 1))

        local yy = 100
        for _, sub in ipairs(cs.systems or {}) do
            local frac = sub.hp / math.max(sub.max, 1)
            local name = Naval.SubsystemNames[sub.id] or sub.id
            draw.SimpleText(name, "MLIB.14", 14, yy, frac <= 0 and COL.bad or COL.text)
            draw.SimpleText(frac <= 0 and "AUSGEFALLEN" or (frac < 0.5 and "beschädigt" or "in Ordnung"), "MLIB.12", w - 14, yy + 2,
                frac <= 0 and COL.bad or (frac < 0.5 and COL.warn or COL.dim), TEXT_ALIGN_RIGHT)
            HullBar(UI, 14, yy + 20, w - 28, 8, frac)
            yy = yy + 40
        end
    end
end

Naval.StationUI = Naval.StationUI or {}
Naval.StationUI.weapons = OpenWeapons
Naval.StationUI.shields = OpenShields
Naval.StationUI.engineering = OpenEngineering
