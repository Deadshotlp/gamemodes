--[[
    Naval - Datenbank.

    Konfiguration (im Web-Panel pflegbar, beim ersten Start mit den Werten aus
    _core/sh_naval_defaults.lua befuellt):
      pd_naval_settings   key -> JSON-Wert
      pd_naval_classes    Schiffsklassen (Kernfelder + JSON "data")
      pd_naval_factions   Fraktionen
      pd_naval_relations  Beziehungen zwischen Fraktionen
      pd_naval_systems    Sternsysteme (Galaxie, Import aus SWU)
      pd_naval_bodies     Himmelskoerper je System
      pd_naval_consoles   Konsolen-Positionen je Map

    Laufzeit (schreibt nur der Server; das Panel liest und aendert ueber
    Konsolenbefehle):
      pd_naval_ships      Schiffe mit Position, Orientierung, Zustand
      pd_naval_fleets     Flotten (ab Stufe 3)
      pd_naval_log        Logbuch

    Neu laden: pd_reload naval (Konfiguration), pd_reload naval_galaxy.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local DB = Naval.DB or {}
Naval.DB = DB

Naval.Settings = Naval.Settings or {}
Naval.Classes = Naval.Classes or {}
Naval.Factions = Naval.Factions or {}
Naval.Relations = Naval.Relations or {}
Naval.Systems = Naval.Systems or {}
Naval.Bodies = Naval.Bodies or {}
Naval.BodiesBySystem = Naval.BodiesBySystem or {}

local esc = function(value) return PD.SQL.EscapeString(tostring(value == nil and "" or value)) end

function DB.ServerKey()
    local cvar = GetConVar("pd_server_key")
    return cvar and cvar:GetString() or "main"
end

-- Einzelwerte als JSON speichern ("5", "\"text\"", "[1,2]", "{...}").
function DB.Encode(value)
    local json = util.TableToJSON({v = value}) or "{}"
    return string.match(json, "^{\"v\":(.*)}$") or "null"
end

function DB.Decode(text)
    local t = util.JSONToTable("{\"v\":" .. tostring(text or "null") .. "}")
    return t and t.v
end

function DB.DecodeTable(text)
    local t = util.JSONToTable(tostring(text or ""))
    return istable(t) and t or {}
end

-- Asynchrone Schritte nacheinander: steps = { function(next) ... end, ... }
local function Sequence(steps, done)
    local index = 0

    local function nextStep()
        index = index + 1
        local step = steps[index]

        if not step then
            if done then done() end
            return
        end

        step(nextStep)
    end

    nextStep()
end

DB.Sequence = Sequence

--------------------------------------------------------------------------------
-- Tabellen
--------------------------------------------------------------------------------

local TABLES = {
    [[CREATE TABLE IF NOT EXISTS `pd_naval_settings` (
        `config_key` VARCHAR(64) NOT NULL,
        `config_value` TEXT NOT NULL,
        PRIMARY KEY (`config_key`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `pd_naval_classes` (
        `id` VARCHAR(64) NOT NULL,
        `name` VARCHAR(128) NOT NULL DEFAULT '',
        `faction` VARCHAR(64) NOT NULL DEFAULT '',
        `model` VARCHAR(255) NOT NULL DEFAULT '',
        `lod_model` VARCHAR(255) NOT NULL DEFAULT '',
        `length_m` DOUBLE NOT NULL DEFAULT 100,
        `hull` DOUBLE NOT NULL DEFAULT 1000,
        `data` LONGTEXT NOT NULL,
        `position` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `pd_naval_factions` (
        `id` VARCHAR(64) NOT NULL,
        `name` VARCHAR(128) NOT NULL DEFAULT '',
        `r` INT NOT NULL DEFAULT 255,
        `g` INT NOT NULL DEFAULT 255,
        `b` INT NOT NULL DEFAULT 255,
        `iff_code` VARCHAR(16) NOT NULL DEFAULT '',
        `player_faction` TINYINT NOT NULL DEFAULT 0,
        `position` INT NOT NULL DEFAULT 0,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `pd_naval_relations` (
        `faction_a` VARCHAR(64) NOT NULL,
        `faction_b` VARCHAR(64) NOT NULL,
        `relation` VARCHAR(16) NOT NULL DEFAULT 'neutral',
        PRIMARY KEY (`faction_a`, `faction_b`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `pd_naval_systems` (
        `id` VARCHAR(64) NOT NULL,
        `name` VARCHAR(128) NOT NULL DEFAULT '',
        `gx` DOUBLE NOT NULL DEFAULT 0,
        `gy` DOUBLE NOT NULL DEFAULT 0,
        `gz` DOUBLE NOT NULL DEFAULT 0,
        `region` VARCHAR(64) NOT NULL DEFAULT '',
        `star_class` VARCHAR(32) NOT NULL DEFAULT '',
        `swu_id` VARCHAR(32) NOT NULL DEFAULT '',
        `hidden` TINYINT NOT NULL DEFAULT 0,
        `jumpable` TINYINT NOT NULL DEFAULT 1,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `pd_naval_bodies` (
        `id` VARCHAR(64) NOT NULL,
        `system_id` VARCHAR(64) NOT NULL,
        `parent_id` VARCHAR(64) NOT NULL DEFAULT '',
        `type` VARCHAR(32) NOT NULL DEFAULT 'planet',
        `name` VARCHAR(128) NOT NULL DEFAULT '',
        `orbit_radius` DOUBLE NOT NULL DEFAULT 0,
        `orbit_phase` DOUBLE NOT NULL DEFAULT 0,
        `orbit_period` DOUBLE NOT NULL DEFAULT 0,
        `orbit_incl` DOUBLE NOT NULL DEFAULT 0,
        `radius` DOUBLE NOT NULL DEFAULT 1000,
        `material` VARCHAR(255) NOT NULL DEFAULT '',
        `cloud_material` VARCHAR(255) NOT NULL DEFAULT '',
        `data` TEXT NOT NULL,
        PRIMARY KEY (`id`),
        KEY `system` (`system_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `pd_naval_system_info` (
        `system_id` VARCHAR(64) NOT NULL,
        `sector` VARCHAR(128) NOT NULL DEFAULT '',
        `grid` VARCHAR(16) NOT NULL DEFAULT '',
        `canon` TINYINT NOT NULL DEFAULT 0,
        `legends` TINYINT NOT NULL DEFAULT 0,
        `routes` TEXT NOT NULL,
        PRIMARY KEY (`system_id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `pd_naval_routes` (
        `id` VARCHAR(80) NOT NULL,
        `name` VARCHAR(128) NOT NULL DEFAULT '',
        `major` TINYINT NOT NULL DEFAULT 0,
        `length_pc` DOUBLE NOT NULL DEFAULT 0,
        `systems` MEDIUMTEXT NOT NULL,
        `lines` MEDIUMTEXT NOT NULL,
        PRIMARY KEY (`id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `pd_naval_consoles` (
        `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
        `map` VARCHAR(128) NOT NULL,
        `station` VARCHAR(32) NOT NULL,
        `px` DOUBLE NOT NULL, `py` DOUBLE NOT NULL, `pz` DOUBLE NOT NULL,
        `pitch` DOUBLE NOT NULL DEFAULT 0, `yaw` DOUBLE NOT NULL DEFAULT 0, `roll` DOUBLE NOT NULL DEFAULT 0,
        `locked` TINYINT NOT NULL DEFAULT 0,
        `data` TEXT NOT NULL,
        PRIMARY KEY (`id`),
        KEY `map` (`map`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `pd_naval_ships` (
        `id` INT UNSIGNED NOT NULL,
        `server_key` VARCHAR(64) NOT NULL DEFAULT 'main',
        `name` VARCHAR(128) NOT NULL DEFAULT '',
        `class_id` VARCHAR(64) NOT NULL,
        `faction_id` VARCHAR(64) NOT NULL,
        `fleet_id` INT UNSIGNED NOT NULL DEFAULT 0,
        `system_id` VARCHAR(64) NOT NULL DEFAULT '',
        `px` DOUBLE NOT NULL DEFAULT 0, `py` DOUBLE NOT NULL DEFAULT 0, `pz` DOUBLE NOT NULL DEFAULT 0,
        `qw` DOUBLE NOT NULL DEFAULT 1, `qx` DOUBLE NOT NULL DEFAULT 0, `qy` DOUBLE NOT NULL DEFAULT 0, `qz` DOUBLE NOT NULL DEFAULT 0,
        `vx` DOUBLE NOT NULL DEFAULT 0, `vy` DOUBLE NOT NULL DEFAULT 0, `vz` DOUBLE NOT NULL DEFAULT 0,
        `state` VARCHAR(16) NOT NULL DEFAULT 'normal',
        `hyper` TEXT NOT NULL,
        `hull` DOUBLE NOT NULL DEFAULT 0,
        `subs` TEXT NOT NULL,
        `shields` TEXT NOT NULL,
        `orders` TEXT NOT NULL,
        `flags` TEXT NOT NULL,
        `profile` VARCHAR(64) NULL DEFAULT NULL,
        `updated_at` BIGINT NOT NULL DEFAULT 0,
        PRIMARY KEY (`server_key`, `id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `pd_naval_fleets` (
        `id` INT UNSIGNED NOT NULL,
        `server_key` VARCHAR(64) NOT NULL DEFAULT 'main',
        `name` VARCHAR(128) NOT NULL DEFAULT '',
        `faction_id` VARCHAR(64) NOT NULL DEFAULT '',
        `flagship_id` INT UNSIGNED NOT NULL DEFAULT 0,
        `formation` VARCHAR(32) NOT NULL DEFAULT 'line',
        `slots` TEXT NOT NULL,
        PRIMARY KEY (`server_key`, `id`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],

    [[CREATE TABLE IF NOT EXISTS `pd_naval_log` (
        `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
        `server_key` VARCHAR(64) NOT NULL DEFAULT 'main',
        `ts` BIGINT NOT NULL,
        `ship_id` INT UNSIGNED NOT NULL DEFAULT 0,
        `kind` VARCHAR(16) NOT NULL DEFAULT 'manual',
        `author` VARCHAR(128) NOT NULL DEFAULT '',
        `text` TEXT NOT NULL,
        PRIMARY KEY (`id`),
        KEY `ship` (`server_key`, `ship_id`, `ts`)
    ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]],
}

function DB.EnsureTables(callback)
    local steps = {}

    for _, sql in ipairs(TABLES) do
        steps[#steps + 1] = function(nextStep)
            PD.SQL.Query(sql, function() nextStep() end)
        end
    end

    Sequence(steps, function()
        Naval.Log("Tabellen bereit")
        if callback then callback() end
    end)
end

--------------------------------------------------------------------------------
-- Startwerte
--------------------------------------------------------------------------------

local function ClassRow(def, position)
    local data = {
        move = def.move, hyper = def.hyper, sensors = def.sensors,
        subsystems = def.subsystems, shields = def.shields, weapons = def.weapons,
        power = def.power, hangar = def.hangar, crew = def.crew,
    }

    return "INSERT IGNORE INTO `pd_naval_classes` (`id`, `name`, `faction`, `model`, `lod_model`, `length_m`, `hull`, `data`, `position`) VALUES ("
        .. esc(def.id) .. ", " .. esc(def.name) .. ", " .. esc(def.faction) .. ", " .. esc(def.model) .. ", "
        .. esc(def.lodModel or "") .. ", " .. tonumber(def.lengthM) .. ", " .. tonumber(def.hull) .. ", "
        .. esc(util.TableToJSON(data)) .. ", " .. position .. ")"
end

function DB.Seed(callback)
    local D = Naval.Defaults

    PD.SQL.FetchOne("SELECT (SELECT COUNT(*) FROM `pd_naval_classes`) AS c, (SELECT COUNT(*) FROM `pd_naval_factions`) AS f, "
        .. "(SELECT COUNT(*) FROM `pd_naval_relations`) AS r", function(row)
        local queries = {}

        if row and tonumber(row.c) == 0 then
            for index, def in ipairs(D.Classes) do
                queries[#queries + 1] = ClassRow(def, index)
            end
        end

        if row and tonumber(row.f) == 0 then
            for index, f in ipairs(D.Factions) do
                queries[#queries + 1] = "INSERT IGNORE INTO `pd_naval_factions` (`id`, `name`, `r`, `g`, `b`, `iff_code`, `player_faction`, `position`) VALUES ("
                    .. esc(f.id) .. ", " .. esc(f.name) .. ", " .. f.color[1] .. ", " .. f.color[2] .. ", " .. f.color[3] .. ", "
                    .. esc(f.iff) .. ", " .. (f.player and 1 or 0) .. ", " .. index .. ")"
            end
        end

        if row and tonumber(row.r) == 0 then
            for _, r in ipairs(D.Relations) do
                queries[#queries + 1] = "INSERT IGNORE INTO `pd_naval_relations` (`faction_a`, `faction_b`, `relation`) VALUES ("
                    .. esc(r[1]) .. ", " .. esc(r[2]) .. ", " .. esc(r[3]) .. ")"
            end
        end

        -- Fehlende Einstellungen immer nachtragen (neue Schluessel in Updates).
        for key, value in pairs(D.Settings) do
            queries[#queries + 1] = "INSERT IGNORE INTO `pd_naval_settings` (`config_key`, `config_value`) VALUES ("
                .. esc(key) .. ", " .. esc(DB.Encode(value)) .. ")"
        end

        local steps = {}
        for _, sql in ipairs(queries) do
            steps[#steps + 1] = function(nextStep)
                PD.SQL.Query(sql, function() nextStep() end)
            end
        end

        Sequence(steps, callback)
    end)
end

--------------------------------------------------------------------------------
-- Konfiguration laden
--------------------------------------------------------------------------------

function DB.LoadConfig(callback)
    Sequence({
        function(nextStep)
            PD.SQL.FetchAll("SELECT * FROM `pd_naval_settings`", function(rows)
                local settings = table.Copy(Naval.Defaults.Settings)

                for _, row in ipairs(rows or {}) do
                    local value = DB.Decode(row.config_value)
                    if value ~= nil then settings[row.config_key] = value end
                end

                Naval.Settings = settings
                nextStep()
            end)
        end,

        function(nextStep)
            PD.SQL.FetchAll("SELECT * FROM `pd_naval_classes` ORDER BY `position`, `id`", function(rows)
                local classes = {}

                for _, row in ipairs(rows or {}) do
                    local data = DB.DecodeTable(row.data)

                    local class = {
                        id = row.id,
                        name = row.name,
                        faction = row.faction,
                        model = row.model,
                        lodModel = row.lod_model ~= "" and row.lod_model or nil,
                        lengthM = tonumber(row.length_m) or 100,
                        hull = tonumber(row.hull) or 1000,
                        position = tonumber(row.position) or 0,
                    }

                    for key, value in pairs(data) do
                        class[key] = value
                    end

                    class.move = class.move or {}
                    class.hyper = class.hyper or {}
                    class.sensors = class.sensors or {}

                    if not util.IsValidModel(class.model) then
                        Naval.Log("Klasse " .. class.id .. ": Modell fehlt auf dem Server (" .. tostring(class.model) .. ")")
                    end

                    classes[class.id] = class
                end

                Naval.Classes = classes
                nextStep()
            end)
        end,

        function(nextStep)
            PD.SQL.FetchAll("SELECT * FROM `pd_naval_factions` ORDER BY `position`, `id`", function(rows)
                local factions = {}

                for _, row in ipairs(rows or {}) do
                    factions[row.id] = {
                        id = row.id,
                        name = row.name,
                        color = Color(tonumber(row.r) or 255, tonumber(row.g) or 255, tonumber(row.b) or 255),
                        iff = row.iff_code,
                        player = tonumber(row.player_faction) == 1,
                        position = tonumber(row.position) or 0,
                    }
                end

                Naval.Factions = factions
                nextStep()
            end)
        end,

        function(nextStep)
            PD.SQL.FetchAll("SELECT * FROM `pd_naval_relations`", function(rows)
                local relations = {}

                for _, row in ipairs(rows or {}) do
                    relations[row.faction_a] = relations[row.faction_a] or {}
                    relations[row.faction_b] = relations[row.faction_b] or {}
                    relations[row.faction_a][row.faction_b] = row.relation
                    relations[row.faction_b][row.faction_a] = row.relation
                end

                Naval.Relations = relations
                nextStep()
            end)
        end,
    }, function()
        if callback then callback(table.Count(Naval.Classes), table.Count(Naval.Factions)) end
    end)
end

-- Beziehung zweier Fraktionen (gleiche Fraktion = verbuendet).
function Naval.GetRelation(a, b)
    if a == b then return Naval.Relation.ALLY end

    local row = Naval.Relations[a]
    return row and row[b] or Naval.Relation.NEUTRAL
end

function DB.LoadGalaxy(callback)
    PD.SQL.FetchAll("SELECT * FROM `pd_naval_systems`", function(systemRows)
        PD.SQL.FetchAll("SELECT * FROM `pd_naval_bodies`", function(bodyRows)
            local systems, bodies, bySystem = {}, {}, {}

            for _, row in ipairs(systemRows or {}) do
                systems[row.id] = {
                    id = row.id,
                    name = row.name,
                    g = {x = tonumber(row.gx) or 0, y = tonumber(row.gy) or 0, z = tonumber(row.gz) or 0},
                    region = row.region,
                    starClass = row.star_class,
                    swuId = row.swu_id,
                    hidden = tonumber(row.hidden) == 1,
                    jumpable = tonumber(row.jumpable) ~= 0,
                }
            end

            for _, row in ipairs(bodyRows or {}) do
                local body = {
                    id = row.id,
                    systemId = row.system_id,
                    parentId = row.parent_id ~= "" and row.parent_id or nil,
                    type = row.type,
                    name = row.name,
                    orbit = {
                        radius = tonumber(row.orbit_radius) or 0,
                        phase = tonumber(row.orbit_phase) or 0,
                        period = tonumber(row.orbit_period) or 0,
                        incl = tonumber(row.orbit_incl) or 0,
                    },
                    radius = tonumber(row.radius) or 1000,
                    material = row.material,
                    cloud = row.cloud_material ~= "" and row.cloud_material or nil,
                    data = DB.DecodeTable(row.data),
                }

                bodies[body.id] = body
                bySystem[body.systemId] = bySystem[body.systemId] or {}
                table.insert(bySystem[body.systemId], body)
            end

            Naval.Systems = systems
            Naval.Bodies = bodies
            Naval.BodiesBySystem = bySystem

            -- Zusatzangaben (Sektor, Planquadrat, Kanon) und Hyperraumrouten
            PD.SQL.FetchAll("SELECT * FROM `pd_naval_system_info`", function(infoRows)
                for _, row in ipairs(infoRows or {}) do
                    local s = systems[row.system_id]

                    if s then
                        s.sector = row.sector
                        s.grid = row.grid
                        s.canon = tonumber(row.canon) == 1
                        s.legends = tonumber(row.legends) == 1
                        s.routes = DB.DecodeTable(row.routes)
                    end
                end

                PD.SQL.FetchAll("SELECT * FROM `pd_naval_routes`", function(routeRows)
                    local routes = {}

                    for _, row in ipairs(routeRows or {}) do
                        routes[row.id] = {
                            id = row.id,
                            name = row.name,
                            major = tonumber(row.major) == 1,
                            length = tonumber(row.length_pc) or 0,
                            systems = DB.DecodeTable(row.systems),
                            lines = DB.DecodeTable(row.lines),
                        }
                    end

                    Naval.Routes = routes

                    if callback then callback(table.Count(systems), table.Count(bodies), table.Count(routes)) end
                end)
            end)
        end)
    end)
end

--------------------------------------------------------------------------------
-- Logbuch
--------------------------------------------------------------------------------

function DB.AddLog(shipId, kind, author, text)
    PD.SQL.Query("INSERT INTO `pd_naval_log` (`server_key`, `ts`, `ship_id`, `kind`, `author`, `text`) VALUES ("
        .. esc(DB.ServerKey()) .. ", " .. os.time() .. ", " .. (tonumber(shipId) or 0) .. ", "
        .. esc(kind or "manual") .. ", " .. esc(author or "") .. ", " .. esc(text or "") .. ")")
end
