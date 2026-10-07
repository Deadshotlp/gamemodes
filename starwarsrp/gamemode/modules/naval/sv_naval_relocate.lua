--[[
    Naval - Umstationieren auf Planeten-Maps (Server, Stufe 4f).

    Im Web-Panel (Raumflotte > Planeten-Maps) haengen an Planeten, Monden
    und Stationen Maps (Tabelle pd_naval_planet_maps). Ablauf:
      1. Map-Schiff steht im Orbit eines solchen Koerpers (Abstand bis
         Massenschatten x relocate_orbit_factor).
      2. Jeder an der Konsole "Umstationierung" waehlt eine Map und bestaetigt
         -> Abflug ist fuer relocate_window Sekunden freigegeben, Ansage an alle.
      3. Fliegt ein Fahrzeug mit Spielern darin an die Weltgrenze der Map, und
         zwar auf der Seite, hinter der der Planet gerade liegt, startet ein
         Countdown; danach wechselt der Server die Map (alle gehen mit).
    Der Naval-Zustand wird vorher gespeichert; das Map-Schiff bleibt im Orbit.
    Auf der Planeten-Map steht dieselbe Konsole fuer den Rueckflug: freigeben,
    mit einem Fahrzeug an eine beliebige Weltgrenze fliegen -> zurueck.

    Zuletzt: Naval.Settings.relocation = {from, to, bodyId, bodyName, name, at}
    Befehle: pd_naval_planetmaps_reload, pd_naval_relocate_info (Admin)
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3, Q = Naval.V3, Naval.Q
local S = Naval.State

local esc = function(value) return PD.SQL.EscapeString(tostring(value == nil and "" or value)) end

util.AddNetworkString("PD.Naval.Relocate")
util.AddNetworkString("PD.Naval.RelocateState")

Naval.PlanetMaps = Naval.PlanetMaps or {}

local function Setting(key, default)
    return tonumber(Naval.Settings and Naval.Settings[key]) or default
end

-- Keine Bildschirm-Meldungen: die Konsole Umstationierung zeigt alles an
local function NotifyAll(text)
    Naval.DebugLog("[Umstationierung] " .. text)
end

local function MapExists(map)
    return isstring(map) and map ~= "" and file.Exists("maps/" .. map .. ".bsp", "GAME")
end

--------------------------------------------------------------------------------
-- Datenbank
--------------------------------------------------------------------------------

local CREATE = [[CREATE TABLE IF NOT EXISTS `pd_naval_planet_maps` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `body_id` VARCHAR(64) NOT NULL,
    `map` VARCHAR(128) NOT NULL,
    `name` VARCHAR(128) NOT NULL DEFAULT '',
    `description` VARCHAR(255) NOT NULL DEFAULT '',
    `position` INT NOT NULL DEFAULT 0,
    `updated_at` BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `body_id` (`body_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

function Naval.LoadPlanetMaps(callback)
    PD.SQL.Query(CREATE, function()
        PD.SQL.FetchAll("SELECT * FROM `pd_naval_planet_maps` ORDER BY `body_id`, `position`, `id`", function(rows)
            local byBody = {}
            for _, row in ipairs(rows or {}) do
                local list = byBody[row.body_id] or {}
                byBody[row.body_id] = list
                list[#list + 1] = {id = tonumber(row.id), map = row.map, name = row.name ~= "" and row.name or row.map, description = row.description}
            end
            Naval.PlanetMaps = byBody
            if callback then callback(#(rows or {})) end
        end)
    end)
end

-- Rueckflug: Konsolen auch auf Maps ohne Naval-Profil aufstellen
hook.Add("PD.Naval.Ready", "PD.Naval.Relocate", function()
    Naval.LoadPlanetMaps()
    if not Naval.IsNavalMap() and Naval.SpawnConsoles then timer.Simple(3, Naval.SpawnConsoles) end
end)
if Naval.Ready then Naval.LoadPlanetMaps() end

hook.Add("PostCleanupMap", "PD.Naval.Relocate", function()
    if Naval.Ready and not Naval.IsNavalMap() and Naval.SpawnConsoles then timer.Simple(1, Naval.SpawnConsoles) end
end)

concommand.Add("pd_naval_planetmaps_reload", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    Naval.LoadPlanetMaps(function(n) print("[Naval] " .. n .. " Planeten-Maps geladen") end)
end)

--------------------------------------------------------------------------------
-- Lage
--------------------------------------------------------------------------------

-- Koerper mit Maps, in dessen Orbit das Map-Schiff steht
local function OrbitBody(ship)
    if not ship or ship.state ~= S.NORMAL then return nil end
    local factor = Setting("mass_shadow_factor", 4) * Setting("relocate_orbit_factor", 1.5)
    local best, bestD
    for _, b in ipairs(Naval.BodiesBySystem[ship.systemId] or {}) do
        if Naval.PlanetMaps[b.id] then
            local d = V3.Dist(ship.pos, Naval.BodyPos(b, Naval.Bodies))
            if d <= (b.radius or 0) * factor and (not bestD or d < bestD) then best, bestD = b, d end
        end
    end
    return best
end

-- Richtung zum Koerper in Map-Koordinaten (wie der Renderer)
local function MapDirection(ship, body)
    local profile = Naval.GetProfile()
    if not profile then return nil end
    local a = profile.mapToBody or Angle(0, 0, 0)
    local M = Q.Mul(Q.FromAngle(a.p, a.y, a.r), Q.Conj(ship.rot))
    local d = Q.RotateVec(M, V3.Sub(Naval.BodyPos(body, Naval.Bodies), ship.pos))
    local v = Vector(d.x, d.y, d.z)
    v:Normalize()
    return v
end

local function Mode()
    if Naval.IsNavalMap() and Naval.SimRunning then return "ship" end
    local last = Naval.Settings and Naval.Settings.relocation
    if istable(last) and last.to == game.GetMap() and MapExists(last.from) then return "planet" end
    return "none"
end

--------------------------------------------------------------------------------
-- Freigabe und Ausloesen
--------------------------------------------------------------------------------

local armed -- {map, name, untilT, dir, bodyId, bodyName, back, by, countdown}

local function Disarm(text)
    if not armed then return end
    armed = nil
    if text then NotifyAll(text, Color(255, 200, 80)) end
end

local function Remember(entry)
    Naval.Settings.relocation = entry
    PD.SQL.Query("REPLACE INTO `pd_naval_settings` (`config_key`, `config_value`) VALUES ('relocation', "
        .. esc(Naval.DB.Encode(entry)) .. ")")
end

local function Change()
    local target = armed
    if not target then return end
    if not MapExists(target.map) then
        Disarm("Map " .. target.map .. " fehlt auf dem Server - abgebrochen")
        return
    end

    if target.back then
        Remember({from = game.GetMap(), to = target.map, at = os.time(), back = true})
    else
        local ship = Naval.GetMapShip()
        if ship then
            ship:Log("nav", target.by or "", "Umstationierung nach " .. target.name .. " (" .. (target.bodyName or "?") .. ")")
            Naval.SaveShip(ship)
        end
        if Naval.SaveDirty then Naval.SaveDirty() end
        Remember({from = game.GetMap(), to = target.map, bodyId = target.bodyId, bodyName = target.bodyName, name = target.name, at = os.time()})
    end

    if PD.LOGS and PD.LOGS.Add then PD.LOGS.Add("Naval", "Umstationierung: Mapwechsel nach " .. target.map, Color(120, 200, 255)) end
    -- Kurz warten, damit die Datenbank-Schreibvorgaenge durch sind
    timer.Simple(1.5, function() RunConsoleCommand("changelevel", target.map) end)
end

local function Trigger(ent)
    if armed.countdown then return end
    local seconds = math.max(3, Setting("relocate_countdown", 10))
    armed.countdown = CurTime() + seconds
    local who = {}
    for _, ply in ipairs(player.GetHumans()) do
        if ply:InVehicle() then
            local v = ply:GetVehicle()
            while IsValid(v:GetParent()) do v = v:GetParent() end
            if v == ent then who[#who + 1] = ply:Nick() end
        end
    end
    local text = (armed.back and "Rückflug zum Schiff" or ("Landeanflug auf " .. armed.name)) .. (" - Mapwechsel in %d s"):format(seconds)
    NotifyAll(text .. (#who > 0 and (" (" .. table.concat(who, ", ") .. ")") or ""))
    timer.Create("PD.Naval.RelocateGo", seconds, 1, Change)
end

-- Weltgrenze der Map (Bounds der Welt)
local function Bounds()
    local mins, maxs = game.GetWorld():GetModelBounds()
    if not mins or (maxs - mins):Length() < 1000 then return nil end
    return mins, maxs
end

-- Naechste Grenzflaeche: Abstand, Normale nach aussen
local function NearestFace(pos, mins, maxs)
    local faces = {
        {pos.x - mins.x, Vector(-1, 0, 0)}, {maxs.x - pos.x, Vector(1, 0, 0)},
        {pos.y - mins.y, Vector(0, -1, 0)}, {maxs.y - pos.y, Vector(0, 1, 0)},
        {pos.z - mins.z, Vector(0, 0, -1)}, {maxs.z - pos.z, Vector(0, 0, 1)},
    }
    table.sort(faces, function(a, b) return a[1] < b[1] end)
    return faces[1][1], faces[1][2]
end

local function Watch()
    if not armed or armed.countdown then return end
    if CurTime() > armed.untilT then Disarm("Freigabe abgelaufen") return end

    -- Schiff hat den Orbit verlassen
    if not armed.back then
        local ship = Naval.GetMapShip()
        local body = OrbitBody(ship)
        if not body or body.id ~= armed.bodyId then Disarm("Orbit verlassen - Umstationierung abgebrochen") return end
        armed.dir = MapDirection(ship, body)
    end

    local mins, maxs = Bounds()
    if not mins then return end
    local margin = Setting("relocate_border_margin", 400)
    local cone = math.cos(math.rad(Setting("relocate_cone", 60)))

    for _, ply in ipairs(player.GetHumans()) do
        if ply:InVehicle() then
            local ent = ply:GetVehicle()
            while IsValid(ent:GetParent()) do ent = ent:GetParent() end
            local dist, normal = NearestFace(ent:GetPos(), mins, maxs)
            if dist <= margin and (not armed.dir or normal:Dot(armed.dir) >= cone) then
                Trigger(ent)
                return
            end
        end
    end
end

timer.Create("PD.Naval.RelocateWatch", 0.25, 0, function()
    local ok, err = xpcall(Watch, debug.traceback)
    if not ok then ErrorNoHalt("[Naval] Umstationierung: " .. tostring(err) .. "\n") end
end)

--------------------------------------------------------------------------------
-- Konsole
--------------------------------------------------------------------------------

local function State()
    local mode = Mode()
    local out = {mode = mode}

    if armed then
        out.armed = {name = armed.name, back = armed.back or nil, remaining = math.max(0, math.floor(armed.untilT - CurTime())),
            countdown = armed.countdown and math.max(0, math.ceil(armed.countdown - CurTime())) or nil}
    end

    if mode == "ship" then
        local ship = Naval.GetMapShip()
        local body = OrbitBody(ship)
        if body then
            out.body = body.name
            out.maps = {}
            for _, m in ipairs(Naval.PlanetMaps[body.id] or {}) do
                out.maps[#out.maps + 1] = {id = m.id, name = m.name, map = m.map, description = m.description, exists = MapExists(m.map) or nil}
            end
        else
            out.reason = "Kein Planet mit Landezonen in Reichweite. In den Orbit eines Planeten mit hinterlegten Maps fliegen."
        end
    elseif mode == "planet" then
        local last = Naval.Settings.relocation
        out.back = {map = last.from, body = last.bodyName}
    else
        out.reason = "Von hier geht es nirgendwohin zurück."
    end
    return out
end

local function SendState(ply)
    net.Start("PD.Naval.RelocateState")
    net.WriteString(util.TableToJSON(State()) or "{}")
    net.Send(ply)
end

net.Receive("PD.Naval.Relocate", function(_, ply)
    local action = net.ReadString()
    local arg = net.ReadUInt(32)
    if (ply.PD_NavalRelocNext or 0) > CurTime() then return end
    ply.PD_NavalRelocNext = CurTime() + 0.3
    if not Naval.AtStation or not Naval.AtStation(ply, "relocation") then return end

    if action == "arm" and not armed then
        local mode = Mode()
        if mode == "ship" then
            local ship = Naval.GetMapShip()
            local body = OrbitBody(ship)
            local entry
            for _, m in ipairs(body and Naval.PlanetMaps[body.id] or {}) do
                if m.id == arg then entry = m end
            end
            if not entry then return end
            if not MapExists(entry.map) then
                Naval.Feedback(ply, "Map " .. entry.map .. " ist auf dem Server nicht installiert")
                return
            end
            armed = {map = entry.map, name = entry.name, bodyId = body.id, bodyName = body.name, by = ply:Nick(),
                untilT = CurTime() + Setting("relocate_window", 600), dir = MapDirection(ship, body)}
            ship:Log("nav", ply:Nick(), "Umstationierung nach " .. entry.name .. " freigegeben")
            NotifyAll(("%s gibt die Umstationierung nach %s (%s) frei. Mit einem Schiff Richtung %s an den Rand der Map fliegen!")
                :format(ply:Nick(), entry.name, body.name, body.name))
        elseif mode == "planet" then
            local last = Naval.Settings.relocation
            armed = {map = last.from, name = "Schiff", back = true, by = ply:Nick(), untilT = CurTime() + Setting("relocate_window", 600)}
            NotifyAll(ply:Nick() .. " gibt den Rückflug zum Schiff frei. Mit einem Schiff an den Rand der Map fliegen!")
        end
        if armed and PD.LOGS and PD.LOGS.Add then PD.LOGS.Add("Naval", ply:Nick() .. ": Umstationierung nach " .. armed.map .. " freigegeben", Color(120, 200, 255)) end
    elseif action == "cancel" and armed and not armed.countdown then
        Disarm(ply:Nick() .. " hat die Umstationierung abgebrochen")
    end
    SendState(ply)
end)

-- Zustand fuer offene Konsolen (jede Sekunde vom Client erfragt)
net.Receive("PD.Naval.RelocateState", function(_, ply)
    if (ply.PD_NavalRelocState or 0) > CurTime() then return end
    ply.PD_NavalRelocState = CurTime() + 0.5
    if Naval.AtStation and Naval.AtStation(ply, "relocation") then SendState(ply) end
end)

concommand.Add("pd_naval_relocate_info", function(ply)
    if IsValid(ply) and not ply:IsAdmin() then return end
    local mins, maxs = Bounds()
    local out = function(t) if IsValid(ply) then ply:ChatPrint(t) else print(t) end end
    out("[Naval] Weltgrenze: " .. (mins and (tostring(mins) .. " bis " .. tostring(maxs)) or "unbekannt"))
    if IsValid(ply) and mins then
        local d, n = NearestFace(ply:GetPos(), mins, maxs)
        out(("[Naval] Abstand zur nächsten Grenze: %.0f (Richtung %s), Auslösen ab %d"):format(d, tostring(n), Setting("relocate_border_margin", 400)))
    end
    out("[Naval] Modus: " .. Mode() .. (armed and (", freigegeben nach " .. armed.map) or ""))
end)
