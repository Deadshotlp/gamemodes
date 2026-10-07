--[[
    Naval - Admin-Tab "Raumflotte" (Client): reine Konfiguration.

      Simulation     Pause, Flottenkommando oeffnen
      Einstellungen  Tempo und Regeln (dieselben Werte wie im Web-Panel)
      Kalibrierung   Map-Schiff vermessen (Bug/Heck, Mitte, Massstab)
      Konsolen       aufstellen, sperren, entfernen

    Schiffe und Befehle: Flottenkommando (cl_naval_fleet.lua). Server:
    sv_naval_admintool.lua.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C

net.Receive("PD.Naval.AdminData", function()
    local size = net.ReadUInt(16)
    local json = util.Decompress(net.ReadData(size))
    C.admin = json and util.JSONToTable(json) or C.admin
    hook.Run("PD.Naval.AdminData")
end)

net.Receive("PD.Naval.AdminSettings", function()
    C.adminSettings = util.JSONToTable(net.ReadString()) or {}
    hook.Run("PD.Naval.AdminSettings")
end)

function Naval.AdminSend(action, args)
    net.Start("PD.Naval.Admin")
    net.WriteString(action)
    net.WriteString(util.TableToJSON(args or {}) or "{}")
    net.SendToServer()
end

local Send = Naval.AdminSend

--------------------------------------------------------------------------------
-- Bausteine fuer Seitenleisten (auch vom Flottenkommando benutzt)
--------------------------------------------------------------------------------

function Naval.UIBuilder(scroll)
    local UI = Naval.UI
    local COL = UI.COL
    local B = {}

    function B.Header(text)
        local p = scroll:Add("DPanel")
        p:Dock(TOP)
        p:DockMargin(0, 12, 0, 4)
        p:SetTall(26)
        p.Paint = function(s, w, h)
            surface.SetDrawColor(COL.accent)
            surface.DrawRect(0, h - 2, w, 2)
            draw.SimpleText(text, "MLIB.18", 2, 2, COL.text)
        end
    end

    function B.Text(text, height)
        local p = scroll:Add("DLabel")
        p:Dock(TOP)
        p:DockMargin(0, 0, 0, 4)
        p:SetFont("MLIB.14")
        p:SetTextColor(COL.dim)
        p:SetWrap(true)
        p:SetAutoStretchVertical(true)
        p:SetText(text)
        if height then p:SetTall(height) end
        return p
    end

    function B.Row(height)
        local p = scroll:Add("DPanel")
        p:Dock(TOP)
        p:DockMargin(0, 0, 0, 4)
        p:SetTall(height or 32)
        p.Paint = nil
        return p
    end

    function B.Buttons(defs)
        local row = B.Row(32)
        local buttons = {}
        for i, d in ipairs(defs) do
            buttons[i] = UI.Button(row, d[1], d[2], d[3] and function() return d[3] end)
        end
        row.PerformLayout = function(s, w, h)
            local bw = (w - (#buttons - 1) * 4) / #buttons
            for i, b in ipairs(buttons) do
                b:SetPos((i - 1) * (bw + 4), 0)
                b:SetSize(bw, h)
            end
        end
        return buttons
    end

    function B.Entry(placeholder, value)
        local e = vgui.Create("DTextEntry", B.Row(30))
        e:Dock(FILL)
        e:SetFont("MLIB.16")
        e:SetPlaceholderText(placeholder)
        if value then e:SetValue(value) end
        return e
    end

    function B.Combo(entries, default)
        local c = vgui.Create("DComboBox", B.Row(30))
        c:Dock(FILL)
        c:SetFont("MLIB.16")
        for _, e in ipairs(entries) do c:AddChoice(e[2], e[1], e[1] == default) end
        return c
    end

    function B.Info(height, paint)
        local p = B.Row(height)
        p.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, COL.panel)
            paint(s, w, h)
        end
        return p
    end

    function B.ComboValue(c)
        local _, data = c:GetSelected()
        return data
    end

    return B
end

--------------------------------------------------------------------------------
-- Einstellungen: Beschriftung (wie im Web-Panel)
--------------------------------------------------------------------------------

Naval.SettingInfo = {
    {"Sprünge", {
        {"hyper_base_time", "Kürzester Sprung", "s"},
        {"hyper_time_per_gu", "Sprungzeit pro Parsec", "s"},
        {"hyper_max_time", "Längster Sprung", "s"},
        {"route_speed_factor", "Faktor auf Hauptrouten", "0,5 = doppelt so schnell"},
        {"route_minor_factor", "Faktor auf Nebenrouten", ""},
        {"route_junction_dist", "Umstieg zwischen Routen bis", "pc"},
        {"spool_time", "Hochfahren des Hyperantriebs", "s"},
        {"jump_anim_time", "Eintritt in den Hyperraum", "s"},
        {"exit_anim_time", "Austritt aus dem Hyperraum", "s"},
        {"jump_align_tolerance", "Erlaubte Abweichung beim Sprung", "Grad"},
        {"mass_shadow_factor", "Massenschatten", "× Radius"},
        {"arrival_scatter", "Streuung beim Austritt", "m"},
    }},
    {"Navigationscomputer", {
        {"nav_calc_base", "Kursberechnung mindestens", "s"},
        {"nav_calc_per_gu", "Kursberechnung pro Parsec", "s"},
        {"nav_calc_max", "Kursberechnung höchstens", "s"},
        {"nav_valid_seconds", "Kurslösung gültig für", "s"},
        {"nav_max_drift", "Lösung ungültig nach Flug von", "m"},
    }},
    {"Gefecht", {
        {"combat_damage_mult", "Faktor auf allen Waffenschaden", "0,5 = doppelt so lang"},
        {"combat_shield_regen_mult", "Nachladen der Schilde", "Faktor"},
        {"combat_wreck_time", "Wrack sichtbar für", "s"},
    }},
    {"Schadenskontrolle", {
        {"dc_max_incidents", "Gleichzeitige Schäden an Bord", "Anzahl"},
        {"dc_incident_chance", "Chance auf Schaden je Treffer", "0..1"},
        {"dc_repair_time", "Reparatur je Schweregrad", "s"},
        {"dc_repair_sub", "Subsystem-Reparatur je Schaden", "Anteil"},
        {"dc_team_count", "Reparaturtrupps", "Anzahl"},
        {"dc_team_rate", "Trupp-Reparatur je Sekunde", "Anteil"},
        {"dc_fire_damage", "Feuer: Schaden an Spielern", "pro s"},
        {"dc_fire_spread", "Feuer greift über nach", "s"},
    }},
    {"Alarmstufen", {
        {"alert_auto_yellow", "Bei Beschuss automatisch Gelb", "1 = an"},
        {"alert_defcon_normal", "DEFCON bei Normal", "0 = nicht ändern"},
        {"alert_defcon_yellow", "DEFCON bei Gelb", "0 = nicht ändern"},
        {"alert_defcon_red", "DEFCON bei Rot", "0 = nicht ändern"},
        {"alert_alarm_seconds", "Alarmton bei Rot", "s"},
        {"alert_red_light", "Rotlicht bei Rot", "1 Map dunkel+rot, 2 nur rot, 0 aus"},
        {"alert_red_lightstyle", "Map-Helligkeit bei Rot", "a dunkel .. m normal"},
    }},
    {"Sensoren und Schildmodulation", {
        {"sensor_ident_range", "Automatisch erkannt bis", "m"},
        {"sensor_scan_time", "Dauer eines Scans", "s"},
        {"shield_mod_bonus", "Modulation: weniger Schildverbrauch", "Anteil"},
        {"shield_mod_duration", "Modulation hält", "s"},
        {"shield_mod_cooldown", "Sperre nach Fehlversuch", "s"},
    }},
    {"Flotten, Moral und Funk", {
        {"fleet_spacing", "Formationsabstand", "× Schiffslänge"},
        {"morale_enabled", "KI-Moral (Flucht, Kapitulation)", "1 = an"},
        {"morale_flee", "Flucht unter Moral", "0..100"},
        {"morale_surrender", "Kapitulation unter Moral", "0..100"},
        {"comms_auto_reply", "KI beantwortet Funkrufe", "1 = an"},
        {"comms_distress_range", "Notruf erreicht Schiffe bis", "pc"},
        {"comms_distress_ships", "Notruf: höchstens Schiffe", "Anzahl"},
        {"comms_distress_cooldown", "Notruf-Sperre", "s"},
        {"interdict_range", "Abfangfeld-Reichweite", "m"},
    }},
    {"Autopilot", {
        {"autopilot_clearance", "Sicherheitsabstand", "× Radius"},
        {"autopilot_margin", "Sicherheitsabstand zusätzlich", "m"},
        {"ship_inertia", "Trägheit beim Fliegen", "1 = an, 0 = aus"},
    }},
    {"Sensoren und Darstellung", {
        {"sensor_default", "Sensorreichweite (Standard)", "m"},
        {"near_ship_range", "Schiffe als Modell bis", "m"},
        {"render_scale", "Darstellungsmaßstab", "m pro Einheit"},
        {"render_far", "Fernbereich der Darstellung", "Einheiten"},
    }},
    {"Taktik-Hologramm", {
        {"holo_radius", "Größe (Radius)", "Einheiten"},
        {"holo_height", "Höhe über dem Projektor", "Einheiten"},
    }},
    {"Sonstiges", {
        {"start_system", "Startsystem (ID, leer = Coruscant)", ""},
        {"autosave_interval", "Automatisch speichern alle", "s"},
    }},
}

--------------------------------------------------------------------------------
-- Tab
--------------------------------------------------------------------------------

function Naval.AdminMenu(base)
    local UI = Naval.UI
    local COL = UI.COL

    if not Naval.IsNavalMap() or not C.static then
        local label = vgui.Create("DLabel", base)
        label:Dock(TOP)
        label:SetTall(40)
        label:SetFont("MLIB.18")
        label:SetText("Das Naval-System ist auf dieser Map nicht aktiv (pd_naval_active 1 und Map-Neustart).")
        return
    end

    -- Zwei Spalten: links Einstellungen, rechts Simulation/Kalibrierung/Konsolen
    local holder = vgui.Create("DPanel", base)
    holder:Dock(FILL)
    holder.Paint = nil

    local right = vgui.Create("DScrollPanel", holder)
    right:Dock(RIGHT)
    right:SetWide(math.max(360, base:GetWide() * 0.45))
    right:DockMargin(12, 0, 0, 0)

    local left = vgui.Create("DScrollPanel", holder)
    left:Dock(FILL)

    holder.PerformLayout = function(_, w) right:SetWide(math.max(360, w * 0.45)) end

    local L = Naval.UIBuilder(left)
    local R = Naval.UIBuilder(right)

    ----------------------------------------------------------------------------
    -- Simulation
    ----------------------------------------------------------------------------

    R.Header("Simulation")
    R.Info(46, function(s, w, h)
        local a = C.admin or {}
        draw.SimpleText("Map-Schiff in: " .. Naval.SystemName(C.status and C.status.system), "MLIB.16", 8, 4, COL.text)
        draw.SimpleText(a.paused and "PAUSIERT" or "läuft", "MLIB.14", 8, 24, a.paused and COL.warn or COL.ok)
    end)
    R.Buttons({
        {"Pause an/aus", function() Send("pause") end, COL.warn},
        {"Flottenkommando öffnen", function() Naval.OpenFleetCommand() end, COL.ok},
        {"Geschützstellungen", function() if Naval.OpenHardpointEditor then Naval.OpenHardpointEditor() end end},
    })
    Send("watch", {on = true})
    holder.OnRemove = function() Send("watch", {on = false}) end

    ----------------------------------------------------------------------------
    -- Kalibrierung
    ----------------------------------------------------------------------------

    R.Header("Map-Schiff vermessen")
    R.Text("1. Ganz vorne am Schiff hinstellen und \"Hier ist vorne\" drücken.\n"
        .. "2. Ganz hinten hinstellen und \"Hier ist hinten\" drücken.\n"
        .. "Daraus folgen Länge, Maßstab, Schiffsmitte und Bugrichtung. Alternativ einzeln:"
        .. " auf der Brücke durch die Frontfenster schauen -> \"Blick = Bug\".")
    R.Buttons({
        {"Hier ist vorne", function() RunConsoleCommand("pd_naval_calibrate", "vorne") end},
        {"Hier ist hinten", function() RunConsoleCommand("pd_naval_calibrate", "hinten") end},
    })
    R.Buttons({
        {"Blick = Bug", function() RunConsoleCommand("pd_naval_calibrate", "bug") end},
        {"Hier = Mitte", function() RunConsoleCommand("pd_naval_calibrate", "mitte") end},
        {"Zurücksetzen", function()
            Derma_Query("Kalibrierung auf die Profilwerte zurücksetzen?", "Raumflotte", "Zurücksetzen", function()
                RunConsoleCommand("pd_naval_calibrate", "reset")
            end, "Abbrechen")
        end, COL.bad},
    })
    R.Info(66, function(s, w, h)
        local p = Naval.GetProfile()
        if not p then return end
        local o = p.shipOriginMap or Vector()
        draw.SimpleText(("Bug zeigt nach Yaw %.1f°"):format(p.mapToBody and p.mapToBody.y or 0), "MLIB.14", 8, 4, COL.text)
        draw.SimpleText(("Schiffsmitte %d %d %d"):format(o.x, o.y, o.z), "MLIB.14", 8, 24, COL.text)
        draw.SimpleText(p.metersPerUnit and ("Maßstab %.4f m pro Einheit"):format(p.metersPerUnit) or "Maßstab: nicht vermessen",
            "MLIB.14", 8, 44, p.metersPerUnit and COL.text or COL.warn)
    end)

    ----------------------------------------------------------------------------
    -- Konsolen
    ----------------------------------------------------------------------------

    ----------------------------------------------------------------------------
    -- Alarmstufen und Map-Knoepfe
    ----------------------------------------------------------------------------

    R.Header("Alarmstufen und Map-Knöpfe")
    R.Text("Map-Knöpfe (z. B. Venator-Sirene, rote Lichtpaneele) einer Alarmstufe zuordnen: Knopf anschauen und "
        .. "\"Angeschauter Knopf\" drücken. Gelb-Knöpfe laufen auch bei Rot weiter. Beim Erreichen der Stufe wird er eingeschaltet, mit \"Beim Verlassen wieder "
        .. "drücken\" auch beim Zurückschalten (Schalter, die an/aus umschalten).")
    R.Buttons({
        {"Normal", function() Send("alert_set", {level = 0}) end, Color(90, 210, 130)},
        {"Gelb", function() Send("alert_set", {level = 1}) end, Color(240, 200, 60)},
        {"Rot", function() Send("alert_set", {level = 2}) end, Color(240, 70, 60)},
    })

    local leave = true
    local leaveBtn = R.Buttons({{"", function() leave = not leave end}})[1]
    leaveBtn.Think = function(s) s.Label = leave and "Beim Verlassen wieder drücken: AN" or "Beim Verlassen wieder drücken: AUS" end

    R.Buttons({
        {"Angeschauter Knopf -> Gelb", function() Send("alertbtn_add", {level = 1, leave = leave}) end, Color(240, 200, 60)},
        {"Angeschauter Knopf -> Rot", function() Send("alertbtn_add", {level = 2, leave = leave}) end, Color(240, 70, 60)},
    })

    local buttonList = R.Row(10)
    buttonList.Paint = nil

    local function FillButtons()
        if not IsValid(buttonList) then return end
        buttonList:Clear()
        local list = (C.adminSettings or {})._alertButtons or {}
        buttonList:SetTall(math.max(#list * 36, 10))

        for i, entry in ipairs(list) do
            local row = vgui.Create("DPanel", buttonList)
            row:Dock(TOP)
            row:DockMargin(0, 0, 0, 4)
            row:SetTall(32)
            row.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, COL.panel)
                local col = tonumber(entry.level) == 1 and Color(240, 200, 60) or Color(240, 70, 60)
                surface.SetDrawColor(col)
                surface.DrawRect(0, 0, 4, h)
                draw.SimpleText((entry.ok and "" or "FEHLT: ") .. tostring(entry.name or "?"), "MLIB.14", 10, h / 2,
                    entry.ok and COL.text or COL.bad, nil, TEXT_ALIGN_CENTER)
            end

            local del = UI.Button(row, "Entfernen", function() Send("alertbtn_remove", {idx = i}) end, function() return COL.bad end)
            del:Dock(RIGHT) del:SetWide(80)
            local test = UI.Button(row, "Testen", function() Send("alertbtn_test", {idx = i}) end)
            test:Dock(RIGHT) test:DockMargin(0, 0, 4, 0) test:SetWide(64)
            local lvl = UI.Button(row, tonumber(entry.level) == 1 and "ab Gelb" or "bei Rot", function() Send("alertbtn_level", {idx = i}) end,
                function() return tonumber(entry.level) == 1 and Color(240, 200, 60) or Color(240, 70, 60) end)
            lvl:Dock(RIGHT) lvl:DockMargin(0, 0, 4, 0) lvl:SetWide(64)
            local lv = UI.Button(row, entry.leave and "zurück: ja" or "zurück: nein", function() Send("alertbtn_leave", {idx = i}) end)
            lv:Dock(RIGHT) lv:DockMargin(0, 0, 4, 0) lv:SetWide(90)
        end
    end
    hook.Add("PD.Naval.AdminSettings", buttonList, FillButtons)

    R.Header("Konsolen")
    R.Text("Neue Konsole: auf die Stelle schauen, an der sie stehen soll, Station wählen, \"Aufstellen\". "
        .. "Ausrichten: mit dem Physgun greifen und drehen (nur Admins) oder mit Links/Rechts/Kippen (je 15°), "
        .. "danach \"Speichern\". \"Hierher\" setzt eine Konsole an deinen Blickpunkt (auch den unsichtbaren "
        .. "Hologramm-Projektor). Taktik-Hologramm: Projektor auf den Holotisch, dazu Ein/Aus, näher, weiter. "
        .. "Schadenspunkte: unsichtbare Orte für Funken, Rauch und Feuer - je Punkt Subsystem und Ortsname festlegen. "
        .. "Unsichtbare Punkte siehst du, solange du Physgun oder Toolgun hältst.")

    local stations = {}
    for id, def in SortedPairs(Naval.Stations or {}) do stations[#stations + 1] = {id, def.name} end
    local cStation = R.Combo(stations, "helm")
    R.Buttons({{"Aufstellen (Blickpunkt)", function()
        local id = R.ComboValue(cStation)
        if id then RunConsoleCommand("pd_naval_console_add", id) end
    end, COL.ok}})

    local consoleList = R.Row(10)
    consoleList.Paint = nil

    local function FillConsoles()
        if not IsValid(consoleList) then return end
        consoleList:Clear()

        local list = ents.FindByClass("pd_naval_console")
        table.sort(list, function(a, b) return a:GetConsoleId() < b:GetConsoleId() end)
        local total = 0
        for _, ent in ipairs(list) do total = total + (ent:GetStation() == "damage_point" and 104 or 70) end
        consoleList:SetTall(math.max(total, 10))

        for _, ent in ipairs(list) do
            local def = ent:StationDef()
            local id = ent:EntIndex()
            local isPoint = ent:GetStation() == "damage_point"

            local card = vgui.Create("DPanel", consoleList)
            card:Dock(TOP)
            card:DockMargin(0, 0, 0, 6)
            card:SetTall(isPoint and 98 or 64)
            card.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, COL.panel)
                if not IsValid(ent) then return end
                local dist = math.Round(LocalPlayer():GetPos():Distance(ent:GetPos()) / 52.5)
                draw.SimpleText(((def and def.name) or ent:GetStation()) .. " #" .. ent:GetConsoleId(), "MLIB.16", 8, 15, COL.text, nil, TEXT_ALIGN_CENTER)
                draw.SimpleText(dist .. " m", "MLIB.12", 8, isPoint and h - 24 or 30, COL.dim)
            end

            -- Zeile 1: Sperre, Entfernen
            local top = vgui.Create("DPanel", card)
            top:Dock(TOP)
            top:SetTall(30)
            top.Paint = nil

            local remove = UI.Button(top, "Entfernen", function()
                Derma_Query("Konsole entfernen?", "Raumflotte", "Entfernen", function()
                    Send("console_remove", {ent = id})
                    timer.Simple(1.5, FillConsoles)
                end, "Abbrechen")
            end, function() return COL.bad end)
            remove:Dock(RIGHT)
            remove:SetWide(80)

            local lock = UI.Button(top, "", function() Send("console_lock", {ent = id}) end)
            lock:Dock(RIGHT)
            lock:DockMargin(0, 0, 4, 0)
            lock:SetWide(80)
            lock.Think = function(s)
                if IsValid(ent) then s.Label = ent:GetLocked() and "Gesperrt" or "Frei" end
            end

            -- Schadenspunkt: Subsystem und Ortsname
            if isPoint then
                local mid = vgui.Create("DPanel", card)
                mid:Dock(TOP)
                mid:DockMargin(0, 2, 0, 0)
                mid:SetTall(30)
                mid.Paint = nil

                local subCombo = vgui.Create("DComboBox", mid)
                subCombo:Dock(LEFT)
                subCombo:SetWide(170)
                subCombo:SetFont("MLIB.14")
                local current = ent:GetNWString("PD_NavalSub", "")
                subCombo:AddChoice("Kein Subsystem", "", current == "")
                subCombo:AddChoice("Hülle", "hull", current == "hull")
                for subId, name in SortedPairsByValue(Naval.SubsystemNames) do
                    subCombo:AddChoice(name, subId, current == subId)
                end

                local labelEntry = vgui.Create("DTextEntry", mid)
                labelEntry:Dock(FILL)
                labelEntry:DockMargin(4, 0, 4, 0)
                labelEntry:SetFont("MLIB.14")
                labelEntry:SetPlaceholderText("Ortsname, z. B. Hangar 2")
                labelEntry:SetValue(ent:GetNWString("PD_NavalLabel", ""))

                local apply = UI.Button(mid, "Übernehmen", function()
                    Send("console_data", {ent = id, sub = R.ComboValue(subCombo) or "", label = labelEntry:GetValue()})
                end, function() return COL.ok end)
                apply:Dock(RIGHT)
                apply:SetWide(90)
            end

            -- Zeile 2: Ausrichtung
            local bottom = vgui.Create("DPanel", card)
            bottom:Dock(BOTTOM)
            bottom:SetTall(30)
            bottom.Paint = nil

            local defs = {
                {"Speichern", function() Send("console_save", {ent = id}) end, COL.ok, 80},
                {"Hierher", function() Send("console_here", {ent = id}) end, nil, 70},
                {"Rechts", function() Send("console_rotate", {ent = id, axis = "y", deg = -15}) end, nil, 56},
                {"Links", function() Send("console_rotate", {ent = id, axis = "y", deg = 15}) end, nil, 56},
                {"Kippen", function() Send("console_rotate", {ent = id, axis = "p", deg = 15}) end, nil, 60},
            }
            for _, d in ipairs(defs) do
                local b = UI.Button(bottom, d[1], d[2], d[3] and function() return d[3] end)
                b:Dock(RIGHT)
                b:DockMargin(4, 0, 0, 0)
                b:SetWide(d[4])
            end
        end
    end

    FillConsoles()
    R.Buttons({
        {"Liste aktualisieren", FillConsoles},
        {"Alle speichern", function() Send("console_save", {all = true}) end, COL.ok},
    })

    ----------------------------------------------------------------------------
    -- Einstellungen
    ----------------------------------------------------------------------------

    L.Header("Einstellungen")
    L.Text("Tempo und Regeln der Raumflotte. Gilt nach dem Speichern sofort, ohne Neustart. Dieselben Werte stehen im Web-Panel unter Raumflotte.")

    local entries = {}

    for _, group in ipairs(Naval.SettingInfo) do
        L.Header(group[1])

        for _, info in ipairs(group[2]) do
            local key, label, unit = info[1], info[2], info[3]
            local row = L.Row(30)

            local entry = vgui.Create("DTextEntry", row)
            entry:Dock(RIGHT)
            entry:SetWide(130)
            entry:SetFont("MLIB.16")

            row.Paint = function(s, w, h)
                draw.SimpleText(label, "MLIB.16", 0, h / 2 - 1, COL.text, nil, TEXT_ALIGN_CENTER)
                if unit ~= "" then
                    draw.SimpleText(unit, "MLIB.12", w - 136, h / 2, COL.dim, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                end
            end

            entries[key] = entry
        end
    end

    local function FillSettings()
        for key, entry in pairs(entries) do
            if IsValid(entry) then
                local value = (C.adminSettings or {})[key]
                entry:SetValue(value == nil and "" or tostring(value))
                entry.Original = entry:GetValue()
            end
        end
    end

    hook.Add("PD.Naval.AdminSettings", holder, FillSettings)
    Send("settings_get")

    L.Buttons({{"Einstellungen speichern", function()
        local values = {}
        for key, entry in pairs(entries) do
            if IsValid(entry) and entry:GetValue() ~= entry.Original then
                local text = entry:GetValue()
                values[key] = tonumber(text) or text
            end
        end
        Send("settings_save", {values = values})
    end, COL.ok}})
end

if PD.Admin and PD.Admin.AddTab then
    PD.Admin:AddTab("naval", "Raumflotte", function(base)
        Naval.AdminMenu(base)
    end, nil, 60)
end
