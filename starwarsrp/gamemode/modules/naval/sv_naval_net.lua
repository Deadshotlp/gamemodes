--[[
    Naval - Netzwerk (Server).

    Alle Spieler auf der Map teilen eine Sicht (die des Map-Schiffs): Daten
    werden einmal gebaut und an alle geschickt.

      PD.Naval.Data      komprimiert + gestueckelt (wie PD.ACW.Sync):
                         "static" = Klassen, Fraktionen, Beziehungen, Systeme, Routen
                         "system" = Himmelskoerper des aktuellen Systems
                         "shipinfo" = Name/Klasse/Fraktion der sichtbaren Schiffe
      PD.Naval.Snap      10 Hz, unzuverlaessig: Uhr, Map-Schiff (doubles),
                         sichtbare Schiffe relativ dazu
      PD.Naval.Event     Ereignisse des Map-Schiffs (Hyperraum usw.)
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3, Q = Naval.V3, Naval.Q

util.AddNetworkString("PD.Naval.Data")
util.AddNetworkString("PD.Naval.Snap")
util.AddNetworkString("PD.Naval.Event")

local CHUNK = 60000
local serial = 0

-- Zustaende als Zahl fuers Netz
Naval.StateIndex = {normal = 1, spooling = 2, jumping = 3, hyperspace = 4, exiting = 5, disabled = 6, destroyed = 7}

local function Recipients()
    local list = {}
    for _, ply in ipairs(player.GetHumans()) do
        if ply.PD_NavalReady then list[#list + 1] = ply end
    end
    return list
end

-- Tabelle komprimiert (in Teilen) senden; target = Spieler oder Liste
function Naval.SendData(kind, payload, target)
    local data = util.Compress(util.TableToJSON(payload) or "{}") or ""
    local total = math.max(1, math.ceil(#data / CHUNK))

    serial = (serial % 65535) + 1
    local id = serial

    for index = 1, total do
        timer.Simple((index - 1) * 0.1, function()
            -- Empfaenger zuerst: eine begonnene, nie gesendete Nachricht
            -- blockiert sonst die naechste (auch anderer Module)
            local valid = {}
            if istable(target) then
                for _, p in ipairs(target) do if IsValid(p) then valid[#valid + 1] = p end end
            elseif IsValid(target) then
                valid[1] = target
            end
            if #valid == 0 then return end

            local part = string.sub(data, (index - 1) * CHUNK + 1, index * CHUNK)

            net.Start("PD.Naval.Data")
                net.WriteString(kind)
                net.WriteUInt(id, 16)
                net.WriteUInt(index, 8)
                net.WriteUInt(total, 8)
                net.WriteUInt(#part, 16)
                net.WriteData(part, #part)
            net.Send(valid)
        end)
    end

    return #data
end

--------------------------------------------------------------------------------
-- Feste Daten
--------------------------------------------------------------------------------

local function BuildStatic()
    local classes, factions, systems, routes = {}, {}, {}, {}

    for id, c in pairs(Naval.Classes) do
        classes[id] = {name = c.name, model = c.model, lodModel = c.lodModel, lengthM = c.lengthM, faction = c.faction}
    end

    for id, f in pairs(Naval.Factions) do
        factions[id] = {name = f.name, color = {f.color.r, f.color.g, f.color.b}, iff = f.iff, player = f.player}
    end

    -- Systeme kompakt: id, Name, x, y, z, Region, Routen, Planetennamen
    -- (fuer die Suche: "Tatooine" liegt im System "Tatoo")
    for id, s in pairs(Naval.Systems) do
        if not s.hidden then
            local planets = {}
            for _, b in ipairs(Naval.BodiesBySystem[id] or {}) do
                if b.type == "planet" and b.name ~= s.name then planets[#planets + 1] = b.name end
            end

            systems[#systems + 1] = {id, s.name, math.Round(s.g.x, 1), math.Round(s.g.y, 1), math.Round(s.g.z, 1), s.region or "", s.routes or {},
                table.concat(planets, ", ")}
        end
    end

    for id, r in pairs(Naval.Routes or {}) do
        routes[id] = {name = r.name, major = r.major, lines = r.lines}
    end

    local s = Naval.Settings
    return {
        settings = {render_scale = s.render_scale, near_ship_range = s.near_ship_range, render_far = s.render_far,
            jump_align_tolerance = s.jump_align_tolerance, galaxy_unit = s.galaxy_unit,
            ["mapcal_" .. ((Naval.GetProfile() or {}).key or "")] = Naval.GetProfile() and s["mapcal_" .. Naval.GetProfile().key] or nil},
        classes = classes, factions = factions, relations = Naval.Relations,
        systems = systems, routes = routes,
    }
end

local function BuildSystem(systemId)
    local bodies = {}

    for _, b in ipairs(Naval.BodiesBySystem[systemId] or {}) do
        bodies[#bodies + 1] = {
            id = b.id, parentId = b.parentId, type = b.type, name = b.name, orbit = b.orbit,
            radius = b.radius, material = b.material, cloud = b.cloud,
            model = b.data and b.data.model, modelScale = b.data and b.data.modelScale,
        }
    end

    return {systemId = systemId, bodies = bodies}
end

Naval.BuildStaticForTest = BuildStatic

function Naval.SendStatic(target)
    local size = Naval.SendData("static", BuildStatic(), target or Recipients())
    Naval.DebugLog("Static gesendet: " .. math.Round(size / 1024, 1) .. " KB")
end

function Naval.SendSystem(target)
    local ship = Naval.GetMapShip()
    if not ship then return end

    Naval.SendData("system", BuildSystem(ship.systemId), target or Recipients())
end

--------------------------------------------------------------------------------
-- Sichtbare Schiffe
--------------------------------------------------------------------------------

local visibleKey = ""
local visible = {}

local function VisibleShips(mapShip)
    local list = {}
    local range = mapShip:Stat("sensorRange")
    local rangeSqr = range * range

    if mapShip.state == Naval.State.HYPERSPACE then return list end

    for id, ship in pairs(Naval.Ships) do
        if ship ~= mapShip and ship.systemId == mapShip.systemId and ship.state ~= Naval.State.HYPERSPACE
            and not (ship.flags and ship.flags.hidden)
            and V3.LenSqr(V3.Sub(ship.pos, mapShip.pos)) <= rangeSqr then
            list[#list + 1] = ship
        end
    end

    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function SendShipInfo(list, target)
    local info = {}

    for _, ship in ipairs(list) do
        info[#info + 1] = {ship.id, ship.name, ship.classId, ship.factionId}
    end

    local mapShip = Naval.GetMapShip()
    if mapShip then
        info[#info + 1] = {mapShip.id, mapShip.name, mapShip.classId, mapShip.factionId, true}
    end

    Naval.SendData("shipinfo", info, target or Recipients())
end

--------------------------------------------------------------------------------
-- Snapshot
--------------------------------------------------------------------------------

local function WriteQuat(q)
    net.WriteFloat(q.w) net.WriteFloat(q.x) net.WriteFloat(q.y) net.WriteFloat(q.z)
end

local lastSystem

local function SendSnap()
    local mapShip = Naval.GetMapShip()
    if not mapShip then return end

    local recipients = Recipients()
    if #recipients == 0 then return end

    -- Systemwechsel: neue Koerper
    if lastSystem ~= mapShip.systemId then
        lastSystem = mapShip.systemId
        Naval.SendSystem(recipients)
    end

    local list = VisibleShips(mapShip)
    local ids = {}
    for _, s in ipairs(list) do ids[#ids + 1] = s.id .. ":" .. s.factionId .. ":" .. s.name end
    local key = table.concat(ids, ",")

    if key ~= visibleKey then
        visibleKey = key
        SendShipInfo(list, recipients)
    end

    visible = list

    net.Start("PD.Naval.Snap", true)
        net.WriteDouble(Naval.Now())
        net.WriteUInt(mapShip.id, 16)
        net.WriteString(mapShip.systemId or "")
        net.WriteUInt(Naval.StateIndex[mapShip.state] or 1, 4)
        net.WriteDouble(mapShip.pos.x) net.WriteDouble(mapShip.pos.y) net.WriteDouble(mapShip.pos.z)
        WriteQuat(mapShip.rot)
        net.WriteFloat(mapShip.vel.x) net.WriteFloat(mapShip.vel.y) net.WriteFloat(mapShip.vel.z)
        net.WriteFloat(mapShip.angVel.x) net.WriteFloat(mapShip.angVel.y) net.WriteFloat(mapShip.angVel.z)
        net.WriteFloat(mapShip.ctrl.throttle or 0)

        net.WriteUInt(#list, 12)
        for _, ship in ipairs(list) do
            local rel = V3.Sub(ship.pos, mapShip.pos)
            net.WriteUInt(ship.id, 16)
            net.WriteFloat(rel.x) net.WriteFloat(rel.y) net.WriteFloat(rel.z)
            WriteQuat(ship.rot)
            net.WriteUInt(Naval.StateIndex[ship.state] or 1, 4)
        end
    net.Send(recipients)
end

local function SafeSnap()
    local ok, err = xpcall(SendSnap, debug.traceback)
    if not ok then ErrorNoHalt("[Naval] Fehler beim Snapshot: " .. tostring(err) .. "\n") end
end

--------------------------------------------------------------------------------
-- Ereignisse an alle
--------------------------------------------------------------------------------

hook.Add("PD.Naval.Event", "PD.Naval.Net", function(ship, kind, data)
    if not ship:IsPlayerShip() then return end

    net.Start("PD.Naval.Event")
        net.WriteString(kind)
        net.WriteString(util.TableToJSON(data or {}) or "{}")
        net.WriteString(util.TableToJSON(ship.hyper or {}) or "{}")
        net.WriteDouble(Naval.Now())
    net.Send(Recipients())
end)

--------------------------------------------------------------------------------
-- Beitreten / Start
--------------------------------------------------------------------------------

local function SendAllTo(ply)
    if not IsValid(ply) or not Naval.SimRunning then return end

    ply.PD_NavalReady = true
    Naval.SendStatic(ply)
    Naval.SendSystem(ply)
    SendShipInfo(visible, ply)
end

hook.Add("PlayerInitialSpawn", "PD.Naval.Net", function(ply)
    timer.Simple(6, function() SendAllTo(ply) end)
end)

hook.Add("PD.Naval.SimStarted", "PD.Naval.Net", function()
    visibleKey = ""
    lastSystem = nil

    for _, ply in ipairs(player.GetHumans()) do
        SendAllTo(ply)
    end

    timer.Create("PD.Naval.Snap", 0.1, 0, SafeSnap)
end)

-- Nach pd_reload naval / naval_galaxy neu verteilen
Naval.OnConfigLoaded = function()
    if Naval.SimRunning then Naval.SendStatic() end
end

Naval.OnGalaxyLoaded = function()
    if Naval.SimRunning then
        Naval.SendStatic()
        Naval.SendSystem()
    end
end
