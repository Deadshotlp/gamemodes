--[[
    Naval - Schiffe (Server).

    Ein Schiff ist eine Lua-Tabelle, kein Entity:
      id, name, classId, factionId, fleetId, systemId
      pos (V3, m, system-lokal), rot (Q), vel (V3 m/s), angVel (V3 rad/s, Schiffsachsen:
        x = Rollen, y = Nicken, z = Gieren)
      ctrl = { throttle (-0.25..1), rate {p,y,r} (-1..1), thrust {x,y,z} (-1..1), autopilot }
      state, hyper, hull, subs, shields, orders, flags {player, profile, hidden, invulnerable, aiOff}
      dirty (muss gespeichert werden)

    Gespeichert in pd_naval_ships (je server_key). Autosave fuer geaenderte
    Schiffe, sofort bei Spawn/Loeschen/Systemwechsel.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3, Q = Naval.V3, Naval.Q
local DB = Naval.DB

Naval.Ships = Naval.Ships or {}
Naval.NextShipId = Naval.NextShipId or 1

local ShipMeta = Naval.ShipMeta or {}
ShipMeta.__index = ShipMeta
Naval.ShipMeta = ShipMeta

local esc = function(value) return PD.SQL.EscapeString(tostring(value == nil and "" or value)) end

--------------------------------------------------------------------------------
-- Werte mit Modifikatoren
--------------------------------------------------------------------------------

-- Stufe 2 haengt hier Schaden, Energie und Alarmstufe an:
-- Naval.RegisterModifier("maxSpeed", function(ship) return 0.5 end)
Naval.Modifiers = Naval.Modifiers or {}

function Naval.RegisterModifier(stat, id, fn)
    Naval.Modifiers[stat] = Naval.Modifiers[stat] or {}
    Naval.Modifiers[stat][id] = fn
end

function ShipMeta:Class()
    return Naval.Classes[self.classId]
end

-- Grundwert aus der Klasse, multipliziert mit allen Modifikatoren.
function ShipMeta:Stat(stat)
    local class = self:Class()
    if not class then return 0 end

    local move = class.move or {}
    local base

    if stat == "maxSpeed" then base = move.maxSpeed or 1000
    elseif stat == "accel" then base = move.accel or 20
    elseif stat == "decel" then base = move.decel or 30
    elseif stat == "thrusterSpeed" then base = move.thrusterSpeed or 30
    elseif stat == "sensorRange" then base = class.sensors and class.sensors.range or (Naval.Settings.sensor_default or 300000)
    elseif stat == "hyperRating" then base = class.hyper and class.hyper.rating or 1
    elseif stat == "spoolTime" then base = class.hyper and class.hyper.spool or (Naval.Settings.spool_time or 10)
    else base = 1 end

    for _, fn in pairs(Naval.Modifiers[stat] or {}) do
        local ok, mult = pcall(fn, self)
        if ok and isnumber(mult) then base = base * mult end
    end

    return base
end

-- Drehraten/-beschleunigung in rad (Klasse in Grad)
function ShipMeta:Rates()
    local move = (self:Class() or {}).move or {}
    local r = move.maxRate or {p = 3, y = 3, r = 4}
    local a = move.angAccel or {p = 1, y = 1, r = 1.5}
    local mult = 1

    for _, fn in pairs(Naval.Modifiers["turnRate"] or {}) do
        local ok, m = pcall(fn, self)
        if ok and isnumber(m) then mult = mult * m end
    end

    return {x = math.rad(r.r) * mult, y = math.rad(r.p) * mult, z = math.rad(r.y) * mult},
        {x = math.rad(a.r), y = math.rad(a.p), z = math.rad(a.y)}
end

function ShipMeta:Forward() return Q.Forward(self.rot) end

function ShipMeta:Speed() return V3.Len(self.vel) end

function ShipMeta:IsPlayerShip() return self.flags and self.flags.player == true end

function ShipMeta:Log(kind, author, text)
    DB.AddLog(self.id, kind, author, text)
end

--------------------------------------------------------------------------------
-- Anlegen / Entfernen
--------------------------------------------------------------------------------

function Naval.CreateShip(data)
    local class = Naval.Classes[data.classId]
    if not class then return nil, "Unbekannte Klasse " .. tostring(data.classId) end

    local id = data.id or Naval.NextShipId
    Naval.NextShipId = math.max(Naval.NextShipId, id + 1)

    local ship = setmetatable({
        id = id,
        name = data.name or class.name,
        classId = class.id,
        factionId = data.factionId or class.faction or "neutral",
        fleetId = data.fleetId or 0,
        systemId = data.systemId,
        pos = data.pos or V3.New(),
        rot = data.rot or Q.Identity(),
        vel = data.vel or V3.New(),
        angVel = V3.New(),
        ctrl = {throttle = 0, rate = {p = 0, y = 0, r = 0}, thrust = {x = 0, y = 0, z = 0}},
        state = data.state or Naval.State.NORMAL,
        hyper = data.hyper or {},
        hull = data.hull or class.hull,
        subs = data.subs or {},
        shields = data.shields or {},
        orders = data.orders or {queue = {}},
        flags = data.flags or {},
        nav = nil,
        dirty = true,
    }, ShipMeta)

    ship.orders.queue = ship.orders.queue or {}

    Naval.Ships[id] = ship
    hook.Run("PD.Naval.ShipAdded", ship)

    return ship
end

function Naval.RemoveShip(id)
    local ship = Naval.Ships[id]
    if not ship then return false end

    Naval.Ships[id] = nil
    PD.SQL.Query("DELETE FROM `pd_naval_ships` WHERE `server_key` = " .. esc(DB.ServerKey()) .. " AND `id` = " .. tonumber(id))
    hook.Run("PD.Naval.ShipRemoved", ship)

    return true
end

-- Das Schiff, auf dem die Map spielt (oder nil)
function Naval.GetMapShip()
    local profile = Naval.GetProfile()
    if not profile then return nil end

    for _, ship in pairs(Naval.Ships) do
        if ship.flags.profile == profile.key then return ship end
    end
end

--------------------------------------------------------------------------------
-- Speichern / Laden
--------------------------------------------------------------------------------

local function ShipRow(ship)
    local p, q, v = ship.pos, ship.rot, ship.vel

    return "REPLACE INTO `pd_naval_ships` (`id`, `server_key`, `name`, `class_id`, `faction_id`, `fleet_id`, `system_id`, "
        .. "`px`, `py`, `pz`, `qw`, `qx`, `qy`, `qz`, `vx`, `vy`, `vz`, `state`, `hyper`, `hull`, `subs`, `shields`, `orders`, `flags`, `profile`, `updated_at`) VALUES ("
        .. ship.id .. ", " .. esc(DB.ServerKey()) .. ", " .. esc(ship.name) .. ", " .. esc(ship.classId) .. ", "
        .. esc(ship.factionId) .. ", " .. (tonumber(ship.fleetId) or 0) .. ", " .. esc(ship.systemId) .. ", "
        .. p.x .. ", " .. p.y .. ", " .. p.z .. ", " .. q.w .. ", " .. q.x .. ", " .. q.y .. ", " .. q.z .. ", "
        .. v.x .. ", " .. v.y .. ", " .. v.z .. ", " .. esc(ship.state) .. ", " .. esc(util.TableToJSON(ship.hyper or {})) .. ", "
        .. (tonumber(ship.hull) or 0) .. ", " .. esc(util.TableToJSON(ship.subs or {})) .. ", "
        .. esc(util.TableToJSON(ship.shields or {})) .. ", " .. esc(util.TableToJSON(ship.orders or {})) .. ", "
        .. esc(util.TableToJSON(ship.flags or {})) .. ", "
        .. (ship.flags.profile and esc(ship.flags.profile) or "NULL") .. ", " .. os.time() .. ")"
end

function Naval.SaveShip(ship)
    if not ship then return end
    ship.dirty = false
    PD.SQL.Query(ShipRow(ship))
end

-- Alle geaenderten Schiffe in einer Transaktion
function Naval.SaveDirty(force)
    local rows = {}

    for _, ship in pairs(Naval.Ships) do
        if ship.dirty or force then
            rows[#rows + 1] = ShipRow(ship)
            ship.dirty = false
        end
    end

    if #rows == 0 then return 0 end

    local add = PD.SQL.Begin()
    if not add then
        for _, sql in ipairs(rows) do PD.SQL.Query(sql) end
        return #rows
    end

    for _, sql in ipairs(rows) do add(sql) end
    PD.SQL.Commit(nil, function(err) Naval.Log("Speichern fehlgeschlagen: " .. tostring(err)) end)

    return #rows
end

function Naval.LoadShips(callback)
    PD.SQL.FetchAll("SELECT * FROM `pd_naval_ships` WHERE `server_key` = " .. esc(DB.ServerKey()), function(rows)
        Naval.Ships = {}
        Naval.NextShipId = 1

        for _, row in ipairs(rows or {}) do
            local ship = Naval.CreateShip({
                id = tonumber(row.id),
                name = row.name,
                classId = row.class_id,
                factionId = row.faction_id,
                fleetId = tonumber(row.fleet_id),
                systemId = row.system_id,
                pos = {x = tonumber(row.px), y = tonumber(row.py), z = tonumber(row.pz)},
                rot = Q.Normalize({w = tonumber(row.qw), x = tonumber(row.qx), y = tonumber(row.qy), z = tonumber(row.qz)}),
                vel = {x = tonumber(row.vx), y = tonumber(row.vy), z = tonumber(row.vz)},
                state = row.state,
                hyper = DB.DecodeTable(row.hyper),
                hull = tonumber(row.hull),
                subs = DB.DecodeTable(row.subs),
                shields = DB.DecodeTable(row.shields),
                orders = DB.DecodeTable(row.orders),
                flags = DB.DecodeTable(row.flags),
            })

            if ship then ship.dirty = false end
        end

        if callback then callback(table.Count(Naval.Ships)) end
    end)
end

--------------------------------------------------------------------------------
-- Startpunkt fuer neue Schiffe
--------------------------------------------------------------------------------

-- Startsystem: Einstellung start_system, sonst Coruscant, sonst irgendeins.
function Naval.StartSystemId()
    local wanted = Naval.Settings.start_system
    if wanted and wanted ~= "" and Naval.Systems[wanted] then return wanted end

    for id, s in pairs(Naval.Systems) do
        if s.name == "Coruscant" then return id end
    end

    return next(Naval.Systems)
end

-- Eine Position im Orbit des Hauptplaneten (Abstand: ~8 Planetenradien).
function Naval.ArrivalPoint(systemId, seed)
    local bodies = Naval.BodiesBySystem[systemId] or {}
    local main = Naval.MainBody(bodies)
    if not main then return V3.New(500000, 0, 0) end

    local center = Naval.BodyPos(main, Naval.Bodies)
    local r = main.radius * 8 + 50000
    local angle = (seed or math.random()) * math.pi * 2

    return V3.Add(center, {x = math.cos(angle) * r, y = math.sin(angle) * r, z = (math.random() - 0.5) * 20000})
end
