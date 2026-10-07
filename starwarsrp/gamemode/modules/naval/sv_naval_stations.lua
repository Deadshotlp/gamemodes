--[[
    Naval - Bedienung der Stationen (Server).

    Jede Aktion wird geprueft: der Spieler muss an einer passenden, nicht
    gesperrten Konsole stehen (Admins duerfen gesperrte), Zahlen werden
    begrenzt, Eingaben sind rate-limitiert.

      PD.Naval.Station.Open   Server -> Client: Station oeffnen
      PD.Naval.Helm           Schub, Drehraten, Duesen
      PD.Naval.Nav            Kurs berechnen / verwerfen
      PD.Naval.Hyper          ausrichten / springen / abbrechen
      PD.Naval.ShipLog        Logbuch lesen / schreiben
      PD.Naval.Status         2 Hz an alle: Kurs, Ausrichtung, Massenschatten,
                              Hyperraum-Zeiten (fuer Konsolen und Anzeigen)
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3 = Naval.V3
local esc = function(value) return PD.SQL.EscapeString(tostring(value == nil and "" or value)) end

util.AddNetworkString("PD.Naval.Station.Open")
util.AddNetworkString("PD.Naval.Helm")
util.AddNetworkString("PD.Naval.Nav")
util.AddNetworkString("PD.Naval.Hyper")
util.AddNetworkString("PD.Naval.ShipLog")
util.AddNetworkString("PD.Naval.Status")
util.AddNetworkString("PD.Naval.Feedback")

-- Rueckmeldung an den Bediener einer Konsole: erscheint im geoeffneten
-- Konsolenfenster (keine Bildschirm-Meldungen, cl_naval_stations.lua)
function Naval.Feedback(ply, text, ok)
    if not IsValid(ply) then return end
    net.Start("PD.Naval.Feedback")
    net.WriteString(tostring(text or ""))
    net.WriteBool(ok == true)
    net.Send(ply)
end

local function Notify(ply, text, ok)
    Naval.Feedback(ply, text, ok)
end

local function Who(ply)
    return IsValid(ply) and ply:Nick() or "?"
end

--------------------------------------------------------------------------------
-- Zugriff
--------------------------------------------------------------------------------

function Naval.OpenStation(ply, ent)
    local def = ent:StationDef()
    if not def or def.noUse then return end

    if ent:GetLocked() and not ply:IsAdmin() then
        Notify(ply, "Diese Konsole ist gesperrt.")
        return
    end

    if not def.offline and (not Naval.SimRunning or not Naval.GetMapShip()) then
        Notify(ply, "Das Schiffssystem ist nicht aktiv.")
        return
    end

    if def.action then
        if (ply.PD_NavalActionNext or 0) > CurTime() then return end
        ply.PD_NavalActionNext = CurTime() + 0.4

        local fn = Naval.StationActions[def.action]
        if fn then fn(ply, ent) end
        return
    end

    ply.PD_NavalStation = ent

    net.Start("PD.Naval.Station.Open")
    net.WriteString(ent:GetStation())
    net.WriteEntity(ent)
    net.Send(ply)
end

-- Steht der Spieler (noch) an einer passenden Konsole?
local function AtStation(ply, station)
    local ent = ply.PD_NavalStation
    if not IsValid(ent) or ent:GetStation() ~= station then return false end
    if ent:GetLocked() and not ply:IsAdmin() then return false end

    return ply:GetPos():Distance(ent:GetPos()) <= Naval.StationUseRange * 1.5
end

Naval.AtStation = AtStation

local function RateLimit(ply, key, per)
    local now = CurTime()
    ply.PD_NavalRate = ply.PD_NavalRate or {}
    if (ply.PD_NavalRate[key] or 0) > now then return false end
    ply.PD_NavalRate[key] = now + per
    return true
end

--------------------------------------------------------------------------------
-- Taktik-Hologramm (Schalter)
--------------------------------------------------------------------------------

Naval.StationActions = Naval.StationActions or {}

local function HoloZoom(delta)
    -- Galaxie-Ansicht: eigener Zoom (Parsec)
    if GetGlobalInt("PD.Naval.HoloMode", 0) == 1 then
        local zoom = math.Clamp(GetGlobalInt("PD.Naval.HoloGalaxyZoom", Naval.HoloGalaxyDefaultZoom) + delta, 1, #Naval.HoloGalaxyRanges)
        SetGlobalInt("PD.Naval.HoloGalaxyZoom", zoom)
        return Naval.HoloGalaxyRanges[zoom]
    end

    local zoom = math.Clamp(GetGlobalInt("PD.Naval.HoloZoom", Naval.HoloDefaultZoom) + delta, 1, #Naval.HoloRanges)
    SetGlobalInt("PD.Naval.HoloZoom", zoom)
    return Naval.HoloRanges[zoom]
end

-- Hologramm-Steuerung (Konsole holo_control, Befehle ueber PD.Naval.CombatCmd)
Naval.CombatCommands = Naval.CombatCommands or {}
local HC = {}
Naval.CombatCommands.holo_control = HC

HC.power = function(ply, ship, args)
    SetGlobalBool("PD.Naval.HoloOn", args.on == true)
end

HC.mode = function(ply, ship, args)
    SetGlobalInt("PD.Naval.HoloMode", args.id == "galaxy" and 1 or 0)
end

HC.zoom = function(ply, ship, args)
    HoloZoom(math.Clamp(math.floor(tonumber(args.delta) or 0), -3, 3))
end

-- Drehen um die Achsen des Projektors in 45-Grad-Schritten
HC.rotate = function(ply, ship, args)
    local key = ({p = "PD.Naval.HoloRotP", y = "PD.Naval.HoloRotY", r = "PD.Naval.HoloRotR"})[args.axis or ""]
    if not key then return end
    local step = (tonumber(args.delta) or 0) >= 0 and 45 or -45
    SetGlobalInt(key, (GetGlobalInt(key, 0) + step) % 360)
end

-- Dauerrotation: Achse, Tempo (Grad/s, Vorzeichen = Richtung) und Startzeit;
-- die Clients rechnen den Winkel selbst. Beim Stoppen rastet der Winkel auf
-- den naechsten 45-Grad-Schritt ein.
local ROT_KEY = {p = "PD.Naval.HoloRotP", y = "PD.Naval.HoloRotY", r = "PD.Naval.HoloRotR"}

local function StopSpin()
    local axis = GetGlobalString("PD.Naval.HoloSpinAxis", "")
    if not ROT_KEY[axis] then return end
    local angle = GetGlobalInt(ROT_KEY[axis], 0)
        + GetGlobalFloat("PD.Naval.HoloSpinSpeed", 0) * (CurTime() - GetGlobalFloat("PD.Naval.HoloSpinStart", CurTime()))
    SetGlobalInt(ROT_KEY[axis], (math.Round(angle / 45) * 45) % 360)
    SetGlobalString("PD.Naval.HoloSpinAxis", "")
end

HC.spin = function(ply, ship, args)
    StopSpin()
    if not ROT_KEY[args.axis or ""] then return end
    SetGlobalFloat("PD.Naval.HoloSpinSpeed", math.Clamp(tonumber(args.speed) or 20, -90, 90))
    SetGlobalFloat("PD.Naval.HoloSpinStart", CurTime())
    SetGlobalString("PD.Naval.HoloSpinAxis", args.axis)
end

HC.reset = function()
    StopSpin()
    SetGlobalInt("PD.Naval.HoloRotP", 0)
    SetGlobalInt("PD.Naval.HoloRotY", 0)
    SetGlobalInt("PD.Naval.HoloRotR", 0)
end

HC.layer = function(ply, ship, args)
    for _, l in ipairs(Naval.HoloLayers) do
        if l.id == args.id then
            local mask = GetGlobalInt("PD.Naval.HoloLayers", Naval.HoloLayersDefault)
            mask = args.on and bit.bor(mask, l.bit) or bit.band(mask, bit.bnot(l.bit))
            SetGlobalInt("PD.Naval.HoloLayers", mask)
        end
    end
end

HC.focus = function()
    SetGlobalString("PD.Naval.HoloFocus", "")
end

--------------------------------------------------------------------------------
-- Steuer
--------------------------------------------------------------------------------

net.Receive("PD.Naval.Helm", function(_, ply)
    if not RateLimit(ply, "helm", 0.04) or not AtStation(ply, "helm") then return end

    local ship = Naval.GetMapShip()
    if not ship then return end

    local throttle = math.Clamp(net.ReadFloat(), -0.25, 1)
    local p, y, r = math.Clamp(net.ReadFloat(), -1, 1), math.Clamp(net.ReadFloat(), -1, 1), math.Clamp(net.ReadFloat(), -1, 1)
    local ty, tz = math.Clamp(net.ReadFloat(), -1, 1), math.Clamp(net.ReadFloat(), -1, 1)
    local align = net.ReadBool()
    local cancelAuto = net.ReadBool()
    local manualThrottle = net.ReadBool()

    -- Waehrend eines Sprungs fuehrt der Hyperantrieb
    if ship.state ~= Naval.State.NORMAL then return end

    -- System-Autopilot (Navigationscomputer): jede Handsteuerung schaltet ihn ab
    if ship.auto then
        if manualThrottle or align or cancelAuto or p ~= 0 or y ~= 0 or r ~= 0 or ty ~= 0 or tz ~= 0 then
            Naval.StopAutopilot(ship, "von Hand übernommen")
        else
            ship.ctrl.thrust = {x = 0, y = 0, z = 0}
            return
        end
    end

    ship.ctrl.throttle = throttle
    ship.ctrl.rate = {p = p, y = y, r = r}
    ship.ctrl.thrust = {x = 0, y = ty, z = tz}

    -- Handsteuerung uebernimmt vom Autopiloten; "align" setzt ihn auf den
    -- Sprungvektor (auch die Hyperantrieb-Konsole kann das).
    if align and ship.nav and ship.nav.target then
        local from, to = Naval.Systems[ship.systemId], Naval.Systems[ship.nav.target]
        if from and to then ship.ctrl.autopilot = {dir = Naval.JumpVector(from, to)} end
    elseif p ~= 0 or y ~= 0 or r ~= 0 or cancelAuto then
        ship.ctrl.autopilot = nil
    end

    ship.dirty = true
end)

--------------------------------------------------------------------------------
-- Navigationscomputer
--------------------------------------------------------------------------------

-- Gilt die Kursloesung noch?
function Naval.NavValid(ship)
    local nav = ship.nav
    if not nav or not nav.ready then return false, "Keine Kursloesung" end
    if nav.system ~= ship.systemId then return false, "Kursloesung aus einem anderen System" end
    if Naval.Now() > (nav.validUntil or 0) then return false, "Kursloesung veraltet - neu berechnen" end

    local drift = V3.Dist(ship.pos, nav.origin)
    if drift > (Naval.Settings.nav_max_drift or 50000) then
        return false, ("Seit der Berechnung %.0f km geflogen - neu berechnen"):format(drift / 1000)
    end

    return true
end

local function NavCalcTime(from, to)
    local s = Naval.Settings
    local t = (s.nav_calc_base or 30) + Naval.SystemDistance(from, to) * (s.nav_calc_per_gu or 0.002)
    return math.Clamp(t, s.nav_calc_base or 30, s.nav_calc_max or 90)
end

net.Receive("PD.Naval.Nav", function(_, ply)
    if not RateLimit(ply, "nav", 0.5) or not AtStation(ply, "navcomputer") then return end

    local ship = Naval.GetMapShip()
    if not ship then return end

    local action = net.ReadString()

    if action == "clear" then
        ship.nav = nil
        Notify(ply, "Kursloesung verworfen.", true)
        return
    end

    -- Galaxie-Hologramm auf ein System ausrichten ("" = Map-Schiff)
    if action == "holo_focus" then
        local id = net.ReadString() or ""
        if id ~= "" and not Naval.Systems[id] then return end
        SetGlobalString("PD.Naval.HoloFocus", id)
        SetGlobalInt("PD.Naval.HoloMode", 1)
        Notify(ply, id ~= "" and ("Hologramm zeigt " .. Naval.Systems[id].name) or "Hologramm zeigt unsere Position", true)
        return
    end

    -- Autopilot im System (Systemkarte)
    if action == "auto" then
        local args = util.JSONToTable(net.ReadString() or "") or {}
        if not Naval.StartAutopilot then return end
        local ok, reason = Naval.StartAutopilot(ship, args, Who(ply))
        Notify(ply, ok and "Autopilot aktiv" or reason, ok)
        return
    elseif action == "plan" then
        -- Geplanter Kurs der Systemkarte (bleibt fuer alle an der Konsole stehen)
        local args = util.JSONToTable(net.ReadString() or "") or {}
        if Naval.SetNavPlan then Naval.SetNavPlan(ship, args) end
        return
    elseif action == "auto_off" then
        if ship.auto and Naval.StopAutopilot then
            Naval.StopAutopilot(ship, "abgeschaltet von " .. Who(ply))
            ship.ctrl.throttle = 0
        end
        return
    end

    if action ~= "calc" then return end

    local to = Naval.Systems[net.ReadString()]
    local from = Naval.Systems[ship.systemId]
    if not to or not from then Notify(ply, "Unbekanntes Ziel.") return end
    if to.id == from.id then Notify(ply, "Wir sind bereits in diesem System.") return end
    if not to.jumpable then Notify(ply, "Dieses Ziel ist gesperrt.") return end
    if ship.state ~= Naval.State.NORMAL then Notify(ply, "Waehrend eines Sprungs nicht moeglich.") return end

    local now = Naval.Now()
    local calc = NavCalcTime(from, to)

    ship.nav = {
        target = to.id,
        system = from.id,
        origin = V3.Copy(ship.pos),
        start = now,
        finish = now + calc,
        ready = false,
        duration = Naval.JumpDuration(from, to, ship:Stat("hyperRating")),
        routes = (Naval.PlanJump(from, to) or {}).routes,
        by = Who(ply),
    }

    ship:Log("nav", Who(ply), ("Kursberechnung nach %s gestartet (%.0f s)"):format(to.name, calc))
    Notify(ply, ("Berechne Kurs nach %s ... (%.0f s)"):format(to.name, calc), true)
end)

-- Fertige Berechnungen freischalten
timer.Create("PD.Naval.NavCalc", 0.5, 0, function()
    local ship = Naval.GetMapShip()
    local nav = ship and ship.nav

    if nav and not nav.ready and Naval.Now() >= nav.finish then
        nav.ready = true
        nav.validUntil = Naval.Now() + (Naval.Settings.nav_valid_seconds or 600)

        local to = Naval.Systems[nav.target]
        ship:Log("nav", nav.by or "", "Kursloesung nach " .. (to and to.name or "?") .. " bereit")
    end
end)

--------------------------------------------------------------------------------
-- Hyperantrieb
--------------------------------------------------------------------------------

net.Receive("PD.Naval.Hyper", function(_, ply)
    if not RateLimit(ply, "hyper", 0.5) or not AtStation(ply, "hyperdrive") then return end

    local ship = Naval.GetMapShip()
    if not ship then return end

    local action = net.ReadString()

    if action == "abort" then
        local ok, reason = Naval.AbortJump(ship, Who(ply))
        Notify(ply, ok and "Sprung abgebrochen." or reason, ok)
        return
    end

    local valid, reason = Naval.NavValid(ship)
    if not valid then Notify(ply, reason) return end

    if action == "align" then
        if ship.auto and Naval.StopAutopilot then Naval.StopAutopilot(ship) end
        local from, to = Naval.Systems[ship.systemId], Naval.Systems[ship.nav.target]
        ship.ctrl.autopilot = {dir = Naval.JumpVector(from, to)}
        Notify(ply, "Richte auf den Sprungvektor aus.", true)
    elseif action == "jump" then
        local ok, result = Naval.StartJump(ship, ship.nav.target, Who(ply))

        if ok then
            local to = Naval.Systems[ship.nav.target]
            if PD.LOGS and PD.LOGS.Add then
                PD.LOGS.Add("Naval", Who(ply) .. " springt nach " .. (to and to.name or "?"), Color(120, 170, 255))
            end
        else
            Notify(ply, result)
        end
    end
end)

--------------------------------------------------------------------------------
-- Logbuch
--------------------------------------------------------------------------------

net.Receive("PD.Naval.ShipLog", function(_, ply)
    if not RateLimit(ply, "log", 1) or not AtStation(ply, "shiplog") then return end

    local ship = Naval.GetMapShip()
    if not ship then return end

    local action = net.ReadString()

    if action == "add" then
        local text = string.sub(string.Trim(net.ReadString() or ""), 1, 400)
        if text == "" then return end
        ship:Log("manual", Who(ply), text)
    end

    -- Liste (auch nach dem Schreiben) zurueckschicken
    timer.Simple(0.2, function()
        PD.SQL.FetchAll("SELECT `ts`, `kind`, `author`, `text` FROM `pd_naval_log` WHERE `server_key` = " .. esc(Naval.DB.ServerKey())
            .. " AND `ship_id` = " .. ship.id .. " ORDER BY `id` DESC LIMIT 60", function(rows)
            if not IsValid(ply) then return end

            net.Start("PD.Naval.ShipLog")
            net.WriteString(util.TableToJSON(rows or {}) or "[]")
            net.Send(ply)
        end)
    end)
end)

--------------------------------------------------------------------------------
-- Status an alle (2 Hz)
--------------------------------------------------------------------------------

timer.Create("PD.Naval.Status", 0.5, 0, function()
    if not Naval.SimRunning then return end

    local ship = Naval.GetMapShip()
    if not ship then return end

    local status = {
        system = ship.systemId,
        speed = math.Round(ship:Speed()),
        maxSpeed = math.Round(ship:Stat("maxSpeed")),
        throttle = ship.ctrl.throttle,
        autopilot = ship.ctrl.autopilot ~= nil,
        state = ship.state,
        hyper = ship.hyper,
        now = Naval.Now(),
    }

    local nav = ship.nav
    if nav then
        local valid, reason = Naval.NavValid(ship)
        status.nav = {target = nav.target, start = nav.start, finish = nav.finish, ready = nav.ready,
            duration = nav.duration, routes = nav.routes, valid = valid, reason = reason}

        if nav.target and Naval.Systems[nav.target] then
            status.align = Naval.AlignmentError(ship, nav.target)
        end
    end

    status.pathKey = Naval.PathKey and Naval.PathKey(ship)
    status.combat = Naval.CombatStatus and Naval.CombatStatus(ship)

    -- Schadenskontrolle, Sensoren, Alarm, Autopilot haengen sich hier an
    for key, fn in pairs(Naval.StatusExtras or {}) do
        local ok, value = pcall(fn, ship)
        if ok then status[key] = value end
    end

    local body, dist, limit = Naval.MassShadow(ship)
    if body then status.shadow = {name = body.name, dist = dist, limit = limit} end

    local recipients = {}
    for _, ply in ipairs(player.GetHumans()) do
        if ply.PD_NavalReady then recipients[#recipients + 1] = ply end
    end
    if #recipients == 0 then return end

    -- Komprimiert: der Status ist mit Kampf, Sensoren, Funk usw. gross, und er
    -- geht 2x pro Sekunde zuverlaessig an alle
    local data = util.Compress(util.TableToJSON(status) or "{}") or ""
    if #data > 60000 then return end

    net.Start("PD.Naval.Status")
    net.WriteUInt(#data, 16)
    net.WriteData(data, #data)
    net.Send(recipients)
end)
