--[[
    Naval - Galaxie aus "Star Wars Universe" (SWU) importieren.

    SWU bringt ~850 Planeten mit 2D-Galaxie-Koordinaten und Texturen mit
    (star-wars-universe/server/data/universe.lua, JSON, nach "Chunks"
    gruppiert). Daraus wird je Planet ein Sternsystem:
      - der Stern (ist der Planet selbst eine Sonne, ist er der Stern)
      - der Planet mit seiner SWU-Textur und ggf. Wolken
      - 0-3 Monde
    Werften und Raumstationen landen als Stationen im naechsten System.

    Alles Zufaellige ist aus der SWU-ID abgeleitet (gleiche Galaxie bei jedem
    Import). Die Hoehe ueber der Galaxieebene (SWU ist flach) ebenso.

    Befehl (Konsole/RCON): pd_naval_import_swu [overwrite]
      ohne overwrite werden vorhandene Systeme nicht angefasst.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local esc = function(value) return PD.SQL.EscapeString(tostring(value == nil and "" or value)) end

local SOURCE = "star-wars-universe/server/data/universe.lua"
local PLANET_PREFIX = "the-coding-ducks/swu/planets/"
local CLOUDS = {
    PLANET_PREFIX .. "clouds/cloud_1",
    PLANET_PREFIX .. "clouds/cloud_2",
    PLANET_PREFIX .. "clouds/cloud_3",
}
local SUNS = {PLANET_PREFIX .. "sun/terrain_1", PLANET_PREFIX .. "sun/terrain_2", PLANET_PREFIX .. "sun/terrain_3"}
local MOONS = {PLANET_PREFIX .. "moon/terrain_1", PLANET_PREFIX .. "moon/terrain_2", PLANET_PREFIX .. "moon/terrain_3"}

-- Kleiner deterministischer Zufallsgenerator (LCG) je Saat.
local function Rng(seedText)
    local state = tonumber(util.CRC(tostring(seedText))) or 1

    return function(lo, hi)
        state = (state * 1103515245 + 12345) % 2147483648
        local f = state / 2147483648

        if lo == nil then return f end
        return lo + (hi - lo) * f
    end
end

local function TerrainType(terrain)
    return string.match(tostring(terrain or ""), "planets/([%w_]+)/") or ""
end

local function Pick(list, rng)
    return list[math.floor(rng(1, #list + 0.999))] or list[1]
end

-- Aus den SWU-Daten die Liste unserer Systeme und Koerper bauen.
local function BuildGalaxy(universe)
    local systems, bodies, stations = {}, {}, {}

    for _, chunk in pairs(universe) do
        for _, entry in ipairs(chunk) do
            if entry.type == "planet" and entry.id and entry.pos then
                local rng = Rng("swu" .. entry.id)
                local systemId = "swu_" .. entry.id
                local terrainType = TerrainType(entry.terrain)
                local isSun = terrainType == "sun"

                -- SWU ist flach: Hoehe deterministisch +-5 Galaxie-Einheiten.
                systems[#systems + 1] = {
                    id = systemId,
                    name = entry.name or ("System " .. entry.id),
                    gx = entry.pos.x, gy = entry.pos.y, gz = rng(-5, 5),
                    starClass = isSun and string.match(entry.terrain, "terrain_(%d)") or "",
                    swuId = entry.id,
                }

                local starId = systemId .. "_star"
                bodies[#bodies + 1] = {
                    id = starId, systemId = systemId, parentId = "", type = Naval.BodyType.STAR,
                    name = isSun and entry.name or ((entry.name or "?") .. " (Stern)"),
                    orbitRadius = 0, orbitPhase = 0, orbitPeriod = 0, orbitIncl = 0,
                    radius = rng(60000, 100000),
                    material = isSun and entry.terrain or Pick(SUNS, rng),
                    cloud = "",
                }

                if not isSun then
                    local planetId = systemId .. "_planet"
                    local orbitRadius = rng(400000, 3000000)

                    bodies[#bodies + 1] = {
                        id = planetId, systemId = systemId, parentId = starId,
                        type = Naval.BodyType.PLANET, name = entry.name or "?",
                        orbitRadius = orbitRadius, orbitPhase = rng(0, 360),
                        orbitPeriod = 0, orbitIncl = rng(-4, 4),
                        radius = terrainType == "gas" and rng(50000, 80000) or rng(20000, 45000),
                        material = entry.terrain or Pick(MOONS, rng),
                        cloud = entry.weather and Pick(CLOUDS, rng) or "",
                    }

                    -- Monde (Mondwelten selbst haben keine)
                    local moonCount = terrainType == "moon" and 0 or math.floor(rng(0, 3.999))
                    for i = 1, moonCount do
                        bodies[#bodies + 1] = {
                            id = planetId .. "_moon" .. i, systemId = systemId, parentId = planetId,
                            type = Naval.BodyType.MOON,
                            name = (entry.name or "?") .. " " .. string.char(96 + i),
                            orbitRadius = rng(100000, 300000) * (1 + (i - 1) * 0.6), orbitPhase = rng(0, 360),
                            orbitPeriod = 0, orbitIncl = rng(-15, 15),
                            radius = rng(3000, 10000),
                            material = Pick(MOONS, rng),
                            cloud = "",
                        }
                    end
                end
            elseif (entry.type == "shipyard" or entry.type == "model_object") and entry.pos and entry.model then
                stations[#stations + 1] = entry
            end
        end
    end

    -- Stationen dem naechsten System zuordnen.
    for _, entry in ipairs(stations) do
        local best, bestDist

        for _, s in ipairs(systems) do
            local d = (s.gx - entry.pos.x) ^ 2 + (s.gy - entry.pos.y) ^ 2
            if not bestDist or d < bestDist then
                best, bestDist = s, d
            end
        end

        if best then
            local rng = Rng("swustation" .. tostring(entry.id))

            bodies[#bodies + 1] = {
                id = best.id .. "_station_" .. tostring(entry.id), systemId = best.id,
                parentId = best.id .. "_planet",
                type = entry.type == "shipyard" and Naval.BodyType.SHIPYARD or Naval.BodyType.STATION,
                name = entry.name or "Station",
                orbitRadius = rng(60000, 150000), orbitPhase = rng(0, 360), orbitPeriod = 0, orbitIncl = rng(-10, 10),
                radius = 2000 * (tonumber(entry.baseScale) or 1),
                material = "", cloud = "",
                data = {model = entry.model, modelScale = tonumber(entry.baseScale) or 1},
            }
        end
    end

    return systems, bodies
end

function Naval.ImportSWU(overwrite, callback)
    local raw = file.Read(SOURCE, "LUA")

    if not raw or raw == "" then
        callback(false, "SWU-Daten nicht gefunden (" .. SOURCE .. ") - ist das Addon installiert?")
        return
    end

    local universe = util.JSONToTable(raw)
    if not istable(universe) then
        callback(false, "SWU-Daten nicht lesbar")
        return
    end

    universe = table.DeSanitise(universe)

    local systems, bodies = BuildGalaxy(universe)
    local verb = overwrite and "REPLACE" or "INSERT IGNORE"
    local queries = {}

    for _, s in ipairs(systems) do
        queries[#queries + 1] = verb .. " INTO `pd_naval_systems` (`id`, `name`, `gx`, `gy`, `gz`, `region`, `star_class`, `swu_id`, `hidden`, `jumpable`) VALUES ("
            .. esc(s.id) .. ", " .. esc(s.name) .. ", " .. s.gx .. ", " .. s.gy .. ", " .. s.gz .. ", '', "
            .. esc(s.starClass) .. ", " .. esc(s.swuId) .. ", 0, 1)"
    end

    for _, b in ipairs(bodies) do
        queries[#queries + 1] = verb .. " INTO `pd_naval_bodies` (`id`, `system_id`, `parent_id`, `type`, `name`, `orbit_radius`, `orbit_phase`, `orbit_period`, `orbit_incl`, `radius`, `material`, `cloud_material`, `data`) VALUES ("
            .. esc(b.id) .. ", " .. esc(b.systemId) .. ", " .. esc(b.parentId) .. ", " .. esc(b.type) .. ", " .. esc(b.name) .. ", "
            .. b.orbitRadius .. ", " .. b.orbitPhase .. ", " .. b.orbitPeriod .. ", " .. b.orbitIncl .. ", " .. b.radius .. ", "
            .. esc(b.material) .. ", " .. esc(b.cloud) .. ", " .. esc(util.TableToJSON(b.data or {})) .. ")"
    end

    -- In Paketen zu je 200 Abfragen, jedes Paket eine Transaktion.
    local BATCH = 200
    local index = 0

    local function nextBatch()
        if index >= #queries then
            callback(true, #systems .. " Systeme, " .. #bodies .. " Himmelskoerper importiert")
            return
        end

        local add = PD.SQL.Begin()
        if not add then
            callback(false, "Datenbank nicht verbunden")
            return
        end

        for i = index + 1, math.min(index + BATCH, #queries) do
            add(queries[i])
        end

        index = math.min(index + BATCH, #queries)

        PD.SQL.Commit(function()
            nextBatch()
        end, function(err)
            callback(false, "Import abgebrochen: " .. tostring(err))
        end)
    end

    nextBatch()
end

concommand.Add("pd_naval_import_swu", function(ply, cmd, args)
    if IsValid(ply) then return end

    local overwrite = args[1] == "overwrite"

    Naval.Log("SWU-Import gestartet" .. (overwrite and " (ueberschreiben)" or ""))

    Naval.ImportSWU(overwrite, function(ok, text)
        Naval.Log("SWU-Import: " .. tostring(text))

        if ok and Naval.DB and Naval.DB.LoadGalaxy then
            Naval.DB.LoadGalaxy(function(systems, bodies)
                Naval.Log("Galaxie neu geladen: " .. systems .. " Systeme, " .. bodies .. " Himmelskoerper")
                if Naval.OnGalaxyLoaded then Naval.OnGalaxyLoaded() end
            end)
        end
    end)
end)
