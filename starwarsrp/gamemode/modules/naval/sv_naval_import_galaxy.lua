--[[
    Naval - Galaxie aus swgalaxymap.com + Wookieepedia importieren.

    Die Datei data/naval/galaxy.json wird ausserhalb des Spiels erzeugt
    (Positionen und Hyperraumrouten von swgalaxymap.com / Henry Bernberg,
    Klima, Gelaende, Monde, Sonnen und Bahnposition aus Wookieepedia,
    CC BY-SA; Texturen aus Star Wars Universe). Galaxie-Einheit: Parsec,
    Coruscant = 0/0.

    Ersetzt die komplette Galaxie (Systeme, Koerper, Systemdetails, Routen)
    in einer Transaktion. Laeuft automatisch beim Start, wenn die Datei neuer
    ist als der letzte Import; von Hand: pd_naval_import_galaxy (Konsole).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local FILE = "naval/galaxy.json"
local ROWS_PER_INSERT = 100

local esc = function(value) return PD.SQL.EscapeString(tostring(value == nil and "" or value)) end
local num = function(value) return tostring(tonumber(value) or 0) end

-- Galaxie-Einheit ist jetzt Parsec (~30.000 pc Durchmesser) statt SWU
-- (~2.000): Sprung- und Berechnungszeiten passend umstellen.
local UNIT_SETTINGS = {
    galaxy_unit = "parsec",
    hyper_time_per_gu = 0.0085,   -- 45 s + 0,0085 s/pc -> ~5 min quer durch
    nav_calc_per_gu = 0.002,
    route_speed_factor = 0.5,     -- auf einer Hyperraumroute halbe Sprungzeit
}

local function BuildInserts(tableName, columns, rows, rowToValues)
    local queries = {}
    local head = "INSERT INTO `" .. tableName .. "` (`" .. table.concat(columns, "`, `") .. "`) VALUES "

    for i = 1, #rows, ROWS_PER_INSERT do
        local values = {}

        for j = i, math.min(i + ROWS_PER_INSERT - 1, #rows) do
            values[#values + 1] = "(" .. table.concat(rowToValues(rows[j]), ", ") .. ")"
        end

        queries[#queries + 1] = head .. table.concat(values, ", ")
    end

    return queries
end

function Naval.ImportGalaxy(callback)
    local raw = file.Read(FILE, "DATA")
    if not raw or raw == "" then
        callback(false, "Datei data/" .. FILE .. " fehlt")
        return
    end

    local galaxy = util.JSONToTable(raw)
    if not istable(galaxy) or not istable(galaxy.systems) then
        callback(false, "Datei data/" .. FILE .. " nicht lesbar")
        return
    end

    local queries = {
        "DELETE FROM `pd_naval_bodies`",
        "DELETE FROM `pd_naval_systems`",
        "DELETE FROM `pd_naval_system_info`",
        "DELETE FROM `pd_naval_routes`",
    }

    local function append(list)
        for _, q in ipairs(list) do queries[#queries + 1] = q end
    end

    append(BuildInserts("pd_naval_systems",
        {"id", "name", "gx", "gy", "gz", "region", "star_class", "swu_id", "hidden", "jumpable"},
        galaxy.systems, function(s)
            return {esc(s.id), esc(s.name), num(s.gx), num(s.gy), num(s.gz), esc(s.region), "''", "''", "0", "1"}
        end))

    append(BuildInserts("pd_naval_system_info",
        {"system_id", "sector", "grid", "canon", "legends", "routes"},
        galaxy.systems, function(s)
            return {esc(s.id), esc(s.sector), esc(s.grid), num(s.canon), num(s.legends), esc(util.TableToJSON(s.routes or {}))}
        end))

    append(BuildInserts("pd_naval_bodies",
        {"id", "system_id", "parent_id", "type", "name", "orbit_radius", "orbit_phase", "orbit_period", "orbit_incl", "radius", "material", "cloud_material", "data"},
        galaxy.bodies, function(b)
            return {esc(b.id), esc(b.systemId), esc(b.parentId), esc(b.type), esc(b.name), num(b.orbitRadius), num(b.orbitPhase),
                num(b.orbitPeriod), num(b.orbitIncl), num(b.radius), esc(b.material), esc(b.cloud), esc(util.TableToJSON(b.data or {}))}
        end))

    -- Routen einzeln: ihre Linienzuege koennen gross sein.
    for _, r in ipairs(galaxy.routes or {}) do
        queries[#queries + 1] = "INSERT INTO `pd_naval_routes` (`id`, `name`, `major`, `length_pc`, `systems`, `lines`) VALUES ("
            .. esc(r.id) .. ", " .. esc(r.name) .. ", " .. (r.major and 1 or 0) .. ", " .. num(r.length) .. ", "
            .. esc(util.TableToJSON(r.systems or {})) .. ", " .. esc(util.TableToJSON(r.lines or {})) .. ")"
    end

    for key, value in pairs(UNIT_SETTINGS) do
        queries[#queries + 1] = "REPLACE INTO `pd_naval_settings` (`config_key`, `config_value`) VALUES ("
            .. esc(key) .. ", " .. esc(Naval.DB.Encode(value)) .. ")"
    end

    queries[#queries + 1] = "REPLACE INTO `pd_naval_settings` (`config_key`, `config_value`) VALUES ('galaxy_version', "
        .. esc(Naval.DB.Encode(tostring(galaxy.generated or ""))) .. ")"

    -- Alles in einer Transaktion: entweder die ganze neue Galaxie oder die alte.
    local add = PD.SQL.Begin()
    if not add then
        callback(false, "Datenbank nicht verbunden")
        return
    end

    for _, q in ipairs(queries) do add(q) end

    PD.SQL.Commit(function()
        callback(true, #galaxy.systems .. " Systeme, " .. #galaxy.bodies .. " Himmelskoerper, "
            .. #(galaxy.routes or {}) .. " Hyperraumrouten importiert (Quelle: " .. tostring(galaxy.source) .. ")")
    end, function(err)
        callback(false, "Import abgebrochen, alte Galaxie bleibt: " .. tostring(err))
    end)
end

-- Neuer als der letzte Import?
function Naval.GalaxyFileVersion()
    local raw = file.Read(FILE, "DATA")
    if not raw then return nil end

    return string.match(string.sub(raw, 1, 400), "\"generated\"%s*:%s*\"([^\"]+)\"")
end

concommand.Add("pd_naval_import_galaxy", function(ply)
    if IsValid(ply) then return end

    Naval.Log("Galaxie-Import gestartet")

    Naval.ImportGalaxy(function(ok, text)
        Naval.Log("Galaxie-Import: " .. tostring(text))

        if ok then
            Naval.ReloadConfig(function()
                Naval.ReloadGalaxy()
            end)
        end
    end)
end)
