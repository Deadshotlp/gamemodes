--[[
    Naval - Admin-Werkzeug "Raumflotte" (Server).

    Gegenstueck zu cl_naval_admin.lua (Admin-Menue). Alle Aktionen nur fuer
    Admins, jede landet in den Admin-Logs.

      PD.Naval.Admin       Client -> Server: Aktion + JSON-Argumente
      PD.Naval.AdminData   Server -> Client (1 Hz an Admins mit offenem Tab):
                           alle Schiffe, Pause, Map-Schiff

    Positionen kommen relativ zum Map-Schiff (Meter, System-Achsen).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3, Q = Naval.V3, Naval.Q

util.AddNetworkString("PD.Naval.Admin")
util.AddNetworkString("PD.Naval.AdminData")
util.AddNetworkString("PD.Naval.AdminSettings")

local watchers = {}

local function Allowed(ply)
    return IsValid(ply) and ply:IsAdmin()
end

local function Notify(ply, text, ok)
    PD.Notify(text, ok and Color(80, 200, 120) or Color(255, 90, 90), false, ply)
end

local function Log(ply, text)
    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("Naval", ply:Nick() .. " (" .. ply:SteamID64() .. "): " .. text, Color(120, 170, 255))
    end
end

local function NumV(t)
    if not istable(t) then return nil end
    local x, y, z = tonumber(t.x), tonumber(t.y), tonumber(t.z)
    if not x or not y or not z then return nil end
    return {x = math.Clamp(x, -1e10, 1e10), y = math.Clamp(y, -1e10, 1e10), z = math.Clamp(z, -1e10, 1e10)}
end

--------------------------------------------------------------------------------
-- Daten an offene Admin-Tabs
--------------------------------------------------------------------------------

local function BuildData()
    local mapShip = Naval.GetMapShip()
    local ships = {}

    for id, ship in pairs(Naval.Ships) do
        local row = {
            id = id, name = ship.name, classId = ship.classId, factionId = ship.factionId,
            systemId = ship.systemId, state = ship.state, speed = math.Round(ship:Speed()),
            order = ship.orders.queue[1] and ship.orders.queue[1].type or nil,
            orders = #ship.orders.queue, map = ship:IsPlayerShip() or nil,
            hull = math.Round((ship.hull or 0) / math.max((ship:Class() or {}).hull or 1, 1) * 100),
            roe = ship.subs and ship.subs.roe or nil,
            target = ship.subs and ship.subs.target or nil,
        }

        if mapShip and ship.systemId == mapShip.systemId then
            local rel = V3.Sub(ship.pos, mapShip.pos)
            row.rel = {x = math.Round(rel.x), y = math.Round(rel.y), z = math.Round(rel.z)}
        end

        if ship.state ~= Naval.State.NORMAL and ship.hyper and ship.hyper.to then
            row.to = ship.hyper.to
        end

        ships[#ships + 1] = row
    end

    return {
        paused = Naval.Paused == true,
        running = Naval.SimRunning == true,
        mapShipId = mapShip and mapShip.id,
        systemId = mapShip and mapShip.systemId,
        ships = ships,
    }
end

timer.Create("PD.Naval.AdminData", 1, 0, function()
    local list = {}
    for ply in pairs(watchers) do
        if Allowed(ply) then list[#list + 1] = ply else watchers[ply] = nil end
    end
    if #list == 0 then return end

    local data = util.Compress(util.TableToJSON(BuildData()) or "{}") or ""
    if #data > 60000 then return end

    net.Start("PD.Naval.AdminData")
        net.WriteUInt(#data, 16)
        net.WriteData(data, #data)
    net.Send(list)
end)

hook.Add("PlayerDisconnected", "PD.Naval.AdminTool", function(ply) watchers[ply] = nil end)

--------------------------------------------------------------------------------
-- Aktionen
--------------------------------------------------------------------------------

local Actions = {}

Actions.watch = function(ply, args)
    watchers[ply] = args.on and true or nil
end

Actions.pause = function(ply)
    Naval.Paused = not Naval.Paused
    Notify(ply, "Simulation " .. (Naval.Paused and "pausiert" or "läuft"), true)
    Log(ply, "Simulation " .. (Naval.Paused and "pausiert" or "fortgesetzt"))
end

Actions.spawn = function(ply, args)
    local mapShip = Naval.GetMapShip()
    local class = Naval.Classes[tostring(args.classId or "")]
    if not mapShip or not class then Notify(ply, "Klasse unbekannt") return end

    local factionId = Naval.Factions[tostring(args.factionId or "")] and args.factionId or class.faction
    local rel = NumV(args.rel)

    if not rel then
        local dist = math.Clamp(tonumber(args.distanceKm) or 5, 0.5, 5000) * 1000
        rel = V3.Scale(Q.Forward(mapShip.rot), dist)
    end

    local pos = V3.Add(mapShip.pos, rel)
    local toMap = V3.Sub(mapShip.pos, pos)
    local yaw = math.deg(math.atan2(toMap.y, toMap.x))
    local name = string.sub(string.Trim(tostring(args.name or "")), 1, 64)

    local ship = Naval.CreateShip({
        classId = class.id,
        factionId = factionId,
        name = name ~= "" and name or nil,
        systemId = mapShip.systemId,
        pos = pos,
        rot = Q.FromAngle(0, yaw, 0),
    })

    if not ship then return end
    Naval.SaveShip(ship)
    Notify(ply, ship.name .. " erzeugt", true)
    Log(ply, ("Schiff #%d %s (%s, %s) erzeugt"):format(ship.id, ship.name, class.id, factionId))
end

local function GetShip(ply, args, allowMap)
    local ship = Naval.Ships[tonumber(args.id) or -1]
    if not ship then Notify(ply, "Schiff nicht gefunden") return nil end
    if ship:IsPlayerShip() and not allowMap then Notify(ply, "Das Map-Schiff steuern die Konsolen") return nil end
    return ship
end

Actions.delete = function(ply, args)
    local ship = GetShip(ply, args)
    if not ship then return end

    Naval.RemoveShip(ship.id)
    Notify(ply, ship.name .. " gelöscht", true)
    Log(ply, "Schiff #" .. ship.id .. " " .. ship.name .. " gelöscht")
end

Actions.edit = function(ply, args)
    local ship = GetShip(ply, args, true)
    if not ship then return end

    local name = string.sub(string.Trim(tostring(args.name or "")), 1, 64)
    if name ~= "" then ship.name = name end
    if Naval.Factions[tostring(args.factionId or "")] and not ship:IsPlayerShip() then ship.factionId = args.factionId end

    ship.dirty = true
    Naval.SaveShip(ship)
    Log(ply, "Schiff #" .. ship.id .. " bearbeitet: " .. ship.name .. " / " .. ship.factionId)
end

Actions.order = function(ply, args)
    local ship = GetShip(ply, args)
    if not ship then return end

    local mapShip = Naval.GetMapShip()
    local kind = tostring(args.type or "")
    local order

    if kind == "hold" then
        order = {type = "hold"}
    elseif kind == "move" then
        local rel = NumV(args.rel)
        if not rel or not mapShip then return end
        order = {type = "move", pos = V3.Add(mapShip.pos, rel)}
    elseif kind == "approach" or kind == "orbit" then
        local body = Naval.Bodies[tostring(args.bodyId or "")]
        if not body or body.systemId ~= ship.systemId then Notify(ply, "Himmelskörper nicht im System des Schiffs") return end

        if kind == "orbit" then
            order = {type = "orbit", bodyId = body.id, radius = tonumber(args.radiusKm) and tonumber(args.radiusKm) * 1000 or nil}
        else
            order = {type = "move", bodyId = body.id}
        end
    elseif kind == "patrol" then
        if not mapShip or not istable(args.points) then return end
        local points = {}
        for i = 1, math.min(#args.points, 16) do
            local rel = NumV(args.points[i])
            if rel then points[#points + 1] = V3.Add(mapShip.pos, rel) end
        end
        if #points < 2 then Notify(ply, "Patrouille braucht mindestens 2 Punkte") return end
        order = {type = "patrol", points = points}
    elseif kind == "jump" then
        local system = Naval.Systems[tostring(args.systemId or "")]
        if not system then Notify(ply, "System unbekannt") return end
        order = {type = "jump", systemId = system.id}
    elseif kind == "attack" then
        local target = Naval.Ships[tonumber(args.targetId) or -1]
        if not target or target == ship or target.systemId ~= ship.systemId then Notify(ply, "Ziel nicht im selben System") return end
        order = {type = "attack", targetId = target.id}
    elseif kind == "jumpnear" then
        if not mapShip then return end
        order = {type = "jump", systemId = mapShip.systemId, arriveNear = mapShip.id}
    else
        return
    end

    if args.append then
        Naval.AddOrder(ship, order, ply:Nick())
    else
        Naval.SetOrders(ship, {order}, ply:Nick())
    end

    Notify(ply, ship.name .. ": " .. kind, true)
    Log(ply, "Befehl an #" .. ship.id .. " " .. ship.name .. ": " .. kind)
end

-- Map-Schiff ohne Sprung in ein anderes System setzen (Event-Vorbereitung)
Actions.relocate = function(ply, args)
    local ship = Naval.GetMapShip()
    local system = Naval.Systems[tostring(args.systemId or "")]
    if not ship or not system then Notify(ply, "System unbekannt") return end
    if ship.state ~= Naval.State.NORMAL then Notify(ply, "Nicht während eines Sprungs") return end

    ship.systemId = system.id
    ship.pos = Naval.ArrivalPoint(system.id, math.random())
    ship.vel = V3.New()
    ship.angVel = V3.New()
    ship.ctrl.throttle = 0
    ship.ctrl.autopilot = nil
    ship.nav = nil
    ship.dirty = true
    Naval.SaveShip(ship)

    ship:Log("admin", ply:Nick(), "Schiff nach " .. system.name .. " versetzt")
    Notify(ply, "Map-Schiff nach " .. system.name .. " versetzt", true)
    Log(ply, "Map-Schiff nach " .. system.name .. " versetzt")
end

Actions.roe = function(ply, args)
    local ship = GetShip(ply, args)
    if not ship or not Naval.Combat then return end
    local roe = args.roe
    if roe ~= "hold" and roe ~= "return" and roe ~= "free" then return end

    Naval.Combat(ship).roe = roe
    ship.dirty = true
    Log(ply, "Feuerverhalten #" .. ship.id .. " " .. ship.name .. ": " .. roe)
end

Actions.repair = function(ply, args)
    local ship = GetShip(ply, args, true)
    if not ship or not Naval.Repair then return end

    Naval.Repair(ship)
    Notify(ply, ship.name .. " repariert", true)
    Log(ply, "Schiff #" .. ship.id .. " " .. ship.name .. " repariert")
end

Actions.console_lock = function(ply, args)
    local ent = Entity(tonumber(args.ent) or -1)
    if not IsValid(ent) or ent:GetClass() ~= "pd_naval_console" then return end

    local locked = not ent:GetLocked()
    ent:SetLocked(locked)
    PD.SQL.Query("UPDATE `pd_naval_consoles` SET `locked` = " .. (locked and 1 or 0) .. " WHERE `id` = " .. ent:GetConsoleId())
    Log(ply, "Konsole " .. ent:GetStation() .. (locked and " gesperrt" or " entsperrt"))
end

local function ConsoleArg(args)
    local ent = Entity(tonumber(args.ent) or -1)
    if IsValid(ent) and ent:GetClass() == "pd_naval_console" then return ent end
end

Actions.console_save = function(ply, args)
    local list = {}
    if args.all then
        list = ents.FindByClass("pd_naval_console")
    else
        list = {ConsoleArg(args)}
    end

    for _, ent in ipairs(list) do Naval.SaveConsole(ent) end
    Notify(ply, #list .. " Konsole(n) gespeichert", true)
    Log(ply, #list .. " Konsole(n) Position/Ausrichtung gespeichert")
end

-- An den Blickpunkt des Admins setzen (auch der unsichtbare Projektor)
Actions.console_here = function(ply, args)
    local ent = ConsoleArg(args)
    if not ent then return end

    local tr = ply:GetEyeTrace()
    ent:SetPos(tr.HitPos)
    Naval.SaveConsole(ent)
    Log(ply, "Konsole " .. ent:GetStation() .. " versetzt")
end

Actions.console_rotate = function(ply, args)
    local ent = ConsoleArg(args)
    if not ent then return end

    local ang = ent:GetAngles()
    local axis = args.axis == "p" and "p" or (args.axis == "r" and "r" or "y")
    ang[axis] = math.NormalizeAngle(ang[axis] + math.Clamp(tonumber(args.deg) or 15, -180, 180))
    ent:SetAngles(ang)
    Naval.SaveConsole(ent)
end

Actions.console_remove = function(ply, args)
    local ent = Entity(tonumber(args.ent) or -1)
    if not IsValid(ent) or ent:GetClass() ~= "pd_naval_console" then return end

    local station = ent:GetStation()
    PD.SQL.Query("DELETE FROM `pd_naval_consoles` WHERE `id` = " .. ent:GetConsoleId(), function()
        if Naval.SpawnConsoles then Naval.SpawnConsoles() end
    end)
    Log(ply, "Konsole " .. station .. " entfernt")
end

--------------------------------------------------------------------------------
-- Einstellungen (dieselben wie im Web-Panel)
--------------------------------------------------------------------------------

local function SendSettings(ply)
    local out = {}
    for key, value in pairs(Naval.Settings or {}) do
        if not string.StartWith(key, "mapcal_") and (isnumber(value) or isstring(value) or isbool(value)) then
            out[key] = value
        end
    end

    net.Start("PD.Naval.AdminSettings")
    net.WriteString(util.TableToJSON(out) or "{}")
    net.Send(ply)
end

Actions.settings_get = function(ply)
    SendSettings(ply)
end

local READONLY = {galaxy_version = true, galaxy_unit = true}

Actions.settings_save = function(ply, args)
    local values = istable(args.values) and args.values or {}
    local defaults = Naval.Defaults.Settings
    local queries, changed = {}, {}

    for key, value in pairs(values) do
        key = tostring(key)
        local default = defaults[key]

        if default ~= nil and not READONLY[key] and Naval.Settings[key] ~= value then
            if isnumber(default) then value = tonumber(value) end
            if isstring(default) then value = string.sub(tostring(value), 1, 200) end

            if value ~= nil and (not isnumber(value) or (value == value and math.abs(value) < 1e9)) then
                queries[#queries + 1] = "REPLACE INTO `pd_naval_settings` (`config_key`, `config_value`) VALUES ("
                    .. PD.SQL.EscapeString(key) .. ", " .. PD.SQL.EscapeString(Naval.DB.Encode(value)) .. ")"
                changed[#changed + 1] = key .. "=" .. tostring(value)
            end
        end
    end

    if #queries == 0 then Notify(ply, "Keine Änderungen") return end

    local pending = #queries
    for _, q in ipairs(queries) do
        PD.SQL.Query(q, function()
            pending = pending - 1
            if pending > 0 then return end

            Naval.ReloadConfig(function()
                if IsValid(ply) then
                    Notify(ply, #changed .. " Einstellung(en) gespeichert", true)
                    SendSettings(ply)
                end
            end)
        end)
    end

    Log(ply, "Einstellungen: " .. table.concat(changed, ", "))
end

net.Receive("PD.Naval.Admin", function(_, ply)
    if not Allowed(ply) then return end
    if (ply.PD_NavalAdminNext or 0) > CurTime() then return end
    ply.PD_NavalAdminNext = CurTime() + 0.2

    local action = net.ReadString()
    local args = util.JSONToTable(net.ReadString()) or {}
    local fn = Actions[action]
    if not fn then return end

    if action ~= "watch" and action ~= "pause" and action ~= "settings_get" and action ~= "settings_save"
        and not Naval.SimRunning then
        Notify(ply, "Simulation läuft nicht")
        return
    end

    local ok, err = xpcall(fn, debug.traceback, ply, args)
    if not ok then ErrorNoHalt("[Naval] Admin-Aktion " .. action .. ": " .. tostring(err) .. "\n") end
end)
