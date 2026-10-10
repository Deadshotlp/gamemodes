--[[
    Naval - Szenarien und Orbit-Events (Server, Stufe 4e).

    Ein Szenario (Tabelle pd_naval_scenarios, Editor im Web-Panel unter
    Raumflotte > Szenarien) hat einen Ausloeser und eine Liste von Aktionen.

    Ausloeser (trigger_kind, trigger_data als JSON):
      manual       nur von Hand (Panel, pd_naval_scenario start <id>)
      enter_system Map-Schiff kommt in einem System an {systemId?, territory?}
      orbit        Map-Schiff erreicht die Umlaufbahn eines Koerpers
                   {bodyId?, bodyType? (planet|moon|station), territory?}
      field        Map-Schiff fliegt in ein Feld {kind? (asteroids|nebula)}
      interval     alle {minutes} Minuten wuerfeln {minutes, territory?}
      hull_below   Huelle des Map-Schiffs faellt unter {percent}
    territory: any | own | hostile | none | contested (Gebiet des Systems)
    Dazu: chance (0..1), cooldown (s), once (nur einmal).

    Aktionen (actions, JSON-Liste, nacheinander; delay = Sekunden davor):
      spawn    {classId, factionId?, count, name?, distanceKm, bearing
                (front|back|left|right|above|below|random), arrive
                (hyperspace|here), orders (attack|hold|patrol|derelict)}
      comms    {from? (leer = erstes gespawntes Schiff), text, kind (msg|distress)}
      announce {title?, text}
      alert    {level 0..2}
      damage   {percent, weapon?}
      supply   {crates = {torpedo = n, ...}}
      log      {text}
    Gespawnte Schiffe tragen flags.scenario; pd_naval_scenario cleanup [id]
    entfernt sie wieder.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3, Q = Naval.V3, Naval.Q
local S = Naval.State

local esc = function(value) return PD.SQL.EscapeString(tostring(value == nil and "" or value)) end

Naval.Scenarios = Naval.Scenarios or {}
Naval.ScenarioRuns = Naval.ScenarioRuns or {}

local state = Naval.ScenarioState or {armed = {}, nextRoll = {}}
Naval.ScenarioState = state

local function Setting(key, default)
    return tonumber(Naval.Settings and Naval.Settings[key]) or default
end

--------------------------------------------------------------------------------
-- Datenbank
--------------------------------------------------------------------------------

local CREATE = [[CREATE TABLE IF NOT EXISTS `pd_naval_scenarios` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `name` VARCHAR(128) NOT NULL DEFAULT '',
    `description` VARCHAR(255) NOT NULL DEFAULT '',
    `enabled` TINYINT NOT NULL DEFAULT 0,
    `trigger_kind` VARCHAR(24) NOT NULL DEFAULT 'manual',
    `trigger_data` TEXT NOT NULL,
    `actions` TEXT NOT NULL,
    `chance` FLOAT NOT NULL DEFAULT 1,
    `cooldown` INT NOT NULL DEFAULT 3600,
    `once` TINYINT NOT NULL DEFAULT 0,
    `runs` INT NOT NULL DEFAULT 0,
    `last_run` BIGINT NOT NULL DEFAULT 0,
    `updated_at` BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

-- Beispiele (ausgeschaltet), damit man sieht, wie es geht
local EXAMPLES = {
    {name = "Piratenhinterhalt im Asteroidenfeld", description = "Piraten lauern im Feld und greifen an",
        trigger = "field", data = {kind = "asteroids"}, chance = 0.35, cooldown = 3600, actions = {
            {type = "spawn", classId = "cr90", factionId = "piraten", count = 3, name = "Piratenkorvette", distanceKm = 9, bearing = "back", arrive = "here", orders = "attack"},
            {type = "comms", delay = 3, from = "", text = "Hier spricht Kapitän Vosk. Drosseln Sie die Triebwerke - Ihre Ladung gehört jetzt uns!", kind = "msg"},
            {type = "alert", delay = 2, level = 2},
        }},
    {name = "Notruf eines Frachters", description = "Ein havarierter Frachter bittet um Hilfe (Traktorstrahl/Entern)",
        trigger = "interval", data = {minutes = 40}, chance = 0.3, cooldown = 3600, actions = {
            {type = "spawn", classId = "frachter", factionId = "neutral", count = 1, name = "Corellian Dawn", distanceKm = 40, bearing = "front", arrive = "here", orders = "derelict"},
            {type = "comms", delay = 2, from = "", text = "Mayday, Mayday! Hier Frachter Corellian Dawn, Antrieb ausgefallen, Lebenserhaltung kritisch. Erbitten Unterstützung!", kind = "distress"},
        }},
    {name = "Separatistischer Hinterhalt", description = "Beim Eintritt in feindliches Gebiet springen Fregatten hinterher",
        trigger = "enter_system", data = {territory = "hostile"}, chance = 0.5, cooldown = 1800, actions = {
            {type = "spawn", delay = 20, classId = "munificent", factionId = "kus", count = 2, distanceKm = 25, bearing = "back", arrive = "hyperspace", orders = "attack"},
            {type = "comms", delay = 6, from = "", text = "Republikanisches Schiff, Sie befinden sich im Raum der Konföderation. Ergeben Sie sich!", kind = "msg"},
            {type = "alert", delay = 1, level = 2},
        }},
    {name = "Orbitalverteidigung", description = "Ein feindlicher Planet warnt und schickt Verstärkung",
        trigger = "orbit", data = {bodyType = "planet", territory = "hostile"}, chance = 1, cooldown = 3600, actions = {
            {type = "comms", from = "Planetare Verteidigung", text = "Unidentifiziertes Schiff, verlassen Sie sofort den Orbit oder wir eröffnen das Feuer!", kind = "msg"},
            {type = "alert", delay = 5, level = 1},
            {type = "spawn", delay = 45, classId = "recusant", factionId = "kus", count = 1, distanceKm = 20, bearing = "front", arrive = "hyperspace", orders = "attack"},
        }},
    {name = "Konvoi zur Eskorte", description = "Drei Frachter warten auf Geleitschutz (von Hand starten)",
        trigger = "manual", data = {}, chance = 1, cooldown = 0, actions = {
            {type = "spawn", classId = "frachter", factionId = "republik", count = 3, name = "Konvoi", distanceKm = 12, bearing = "left", arrive = "hyperspace", orders = "hold"},
            {type = "comms", delay = 8, from = "", text = "Hier Konvoi-Führer. Wir sind bereit und warten auf Ihr Signal.", kind = "msg"},
        }},
}

local function Decode(text, default)
    local t = util.JSONToTable(text or "")
    return istable(t) and t or default
end

local function Seed(done)
    local pending = #EXAMPLES
    for _, ex in ipairs(EXAMPLES) do
        PD.SQL.Query(("INSERT INTO `pd_naval_scenarios` (`name`, `description`, `enabled`, `trigger_kind`, `trigger_data`, `actions`, `chance`, `cooldown`, `updated_at`) VALUES (%s, %s, 0, %s, %s, %s, %f, %d, %d)")
            :format(esc(ex.name), esc(ex.description), esc(ex.trigger), esc(util.TableToJSON(ex.data)), esc(util.TableToJSON(ex.actions)),
            ex.chance, ex.cooldown, os.time()), function()
            pending = pending - 1
            if pending == 0 then done() end
        end)
    end
end

function Naval.LoadScenarios(callback)
    PD.SQL.Query(CREATE, function()
        PD.SQL.FetchAll("SELECT * FROM `pd_naval_scenarios` ORDER BY `id`", function(rows)
            if (not rows or #rows == 0) and not Naval.ScenarioSeeded then
                Naval.ScenarioSeeded = true
                Seed(function() Naval.LoadScenarios(callback) end)
                return
            end

            local list = {}
            for _, row in ipairs(rows or {}) do
                local id = tonumber(row.id)
                list[id] = {
                    id = id, name = row.name, enabled = tonumber(row.enabled) == 1, trigger = row.trigger_kind,
                    data = Decode(row.trigger_data, {}), actions = Decode(row.actions, {}),
                    chance = tonumber(row.chance) or 1, cooldown = tonumber(row.cooldown) or 0, once = tonumber(row.once) == 1,
                    runs = tonumber(row.runs) or 0, lastRun = tonumber(row.last_run) or 0,
                }
            end
            Naval.Scenarios = list
            if callback then callback(table.Count(list)) end
        end)
    end)
end

hook.Add("PD.Naval.Ready", "PD.Naval.Scenarios", function() Naval.LoadScenarios() end)
if Naval.Systems and next(Naval.Systems) then Naval.LoadScenarios() end

--------------------------------------------------------------------------------
-- Aktionen
--------------------------------------------------------------------------------

local BEARING = {
    front = function(r) return Q.Forward(r) end,
    back = function(r) return V3.Scale(Q.Forward(r), -1) end,
    left = function(r) return Q.Left(r) end,
    right = function(r) return V3.Scale(Q.Left(r), -1) end,
    above = function(r) return Q.Up(r) end,
    below = function(r) return V3.Scale(Q.Up(r), -1) end,
}

local function RandomDir()
    local u, a = math.Rand(-1, 1), math.Rand(0, math.pi * 2)
    local s = math.sqrt(1 - u * u)
    return {x = s * math.cos(a), y = s * math.sin(a), z = u * 0.3}
end

local function Derelict(ship)
    ship.flags.surrendered = true
    if Naval.Combat then
        local subs, sh = Naval.Combat(ship)
        sh.up = false
        subs.roe = "hold"
        subs.hp.engines = 0
        subs.hp.hyperdrive = 0
        ship.hull = math.floor(((ship:Class() or {}).hull or 1000) * 0.4)
    end
end

local function Spawn(ctx, a, mapShip)
    local class = Naval.Classes[tostring(a.classId or "")]
    if not class then return end
    local factionId = Naval.Factions[tostring(a.factionId or "")] and a.factionId or class.faction
    local count = math.Clamp(math.floor(tonumber(a.count) or 1), 1, 12)
    local dist = math.Clamp(tonumber(a.distanceKm) or 20, 0.5, 2000) * 1000
    local dir = (BEARING[a.bearing] or RandomDir)(mapShip.rot)
    dir = V3.Normalize(dir)
    local side = V3.Normalize(V3.Cross(dir, Q.Up(mapShip.rot)))
    if V3.Len(side) < 0.5 then side = Q.Left(mapShip.rot) end
    local spacing = math.max((class.lengthM or 300) * 2.5, 1200)
    local now = Naval.Now()

    for i = 1, count do
        local offset = (i - (count + 1) / 2) * spacing
        local pos = V3.Add(mapShip.pos, V3.Add(V3.Scale(dir, dist), V3.Scale(side, offset)))
        local toMap = V3.Sub(mapShip.pos, pos)
        local rot = Q.FromAngle(0, math.deg(math.atan2(toMap.y, toMap.x)), 0)
        local name = tostring(a.name or "")
        if name ~= "" and count > 1 then name = name .. " " .. i end

        local ship = Naval.CreateShip({classId = class.id, factionId = factionId, name = name ~= "" and name or nil,
            systemId = mapShip.systemId, pos = pos, rot = rot})
        if ship then
            ship.flags = ship.flags or {}
            ship.flags.scenario = ctx.id
            ctx.spawned[#ctx.spawned + 1] = ship

            if a.arrive == "hyperspace" then
                -- Austritt aus dem Hyperraum am Zielpunkt (gleiche Effekte wie ein Sprung)
                local tExit = now + 1 + i * 0.6
                ship.state = S.HYPERSPACE
                ship.hyper = {from = mapShip.systemId, to = mapShip.systemId, tExit = tExit, tDone = tExit + (Setting("exit_anim_time", 3)),
                    arrive = pos, arriveRot = rot}
            end

            local orders = a.orders or "hold"
            if orders == "derelict" then
                Derelict(ship)
            elseif orders == "attack" then
                if Naval.Combat then Naval.Combat(ship).roe = "free" end
                Naval.SetOrders(ship, {{type = "attack", targetId = mapShip.id}}, "Szenario")
            elseif orders == "patrol" then
                local points = {}
                for k = 0, 3 do
                    local ang = k * math.pi / 2
                    points[#points + 1] = V3.Add(pos, V3.Add(V3.Scale(dir, math.cos(ang) * 10000), V3.Scale(side, math.sin(ang) * 10000)))
                end
                Naval.SetOrders(ship, {{type = "patrol", points = points}}, "Szenario")
            else
                Naval.SetOrders(ship, {{type = "hold"}}, "Szenario")
            end
            ship.dirty = true
            Naval.SaveShip(ship)
        end
    end
end

local Actions = {}

Actions.spawn = Spawn

Actions.comms = function(ctx, a)
    local from = tostring(a.from or "")
    local sender = from ~= "" and from or ctx.spawned[1] or ctx.name
    if Naval.CommsMessage then Naval.CommsMessage(sender, tostring(a.text or ""), a.kind == "distress" and "distress" or "msg") end
end

Actions.announce = function(ctx, a)
    local title, text = tostring(a.title or ""), tostring(a.text or "")
    if PD.Announce then
        PD.Announce({title = title ~= "" and title or ctx.name, text = text, color = Color(30, 90, 178), duration = 10})
    else
        for _, ply in ipairs(player.GetHumans()) do PD.Notify(text, Color(120, 200, 255), false, ply) end
    end
end

Actions.alert = function(ctx, a)
    if Naval.SetAlert then Naval.SetAlert(tonumber(a.level) or 0, "Szenario: " .. ctx.name) end
end

Actions.damage = function(ctx, a, mapShip)
    local hullMax = (mapShip:Class() or {}).hull or 1000
    local weapon = Naval.WeaponTypes[tostring(a.weapon or "")] and a.weapon or "turbolaser"
    Naval.ApplyHit(mapShip, nil, weapon, hullMax * math.Clamp(tonumber(a.percent) or 2, 0, 50) / 100)
end

Actions.supply = function(ctx, a, mapShip)
    if Naval.SupplyDeliver and istable(a.crates) then Naval.SupplyDeliver(mapShip, a.crates) end
end

Actions.log = function(ctx, a, mapShip)
    mapShip:Log("event", ctx.name, tostring(a.text or ""))
end

local function Record(sc)
    sc.runs = (sc.runs or 0) + 1
    sc.lastRun = os.time()
    PD.SQL.Query("UPDATE `pd_naval_scenarios` SET `runs` = `runs` + 1, `last_run` = " .. sc.lastRun .. " WHERE `id` = " .. sc.id)
end

function Naval.RunScenario(sc, by)
    local mapShip = Naval.GetMapShip()
    if not mapShip then return false, "Kein Map-Schiff" end

    local ctx = {id = sc.id, name = sc.name, spawned = {}, started = os.time(), by = by}
    Naval.ScenarioRuns[#Naval.ScenarioRuns + 1] = ctx
    while #Naval.ScenarioRuns > 20 do table.remove(Naval.ScenarioRuns, 1) end
    Record(sc)

    if PD.LOGS and PD.LOGS.Add then PD.LOGS.Add("Naval", "Szenario: " .. sc.name .. (by and (" (" .. by .. ")") or ""), Color(200, 160, 255)) end
    for _, ply in ipairs(player.GetHumans()) do
        if ply:IsAdmin() then PD.Notify("[Szenario] " .. sc.name .. " läuft", Color(200, 160, 255), false, ply) end
    end

    local t = 0
    for i, a in ipairs(sc.actions or {}) do
        local fn = Actions[a.type or ""]
        if fn then
            t = t + math.Clamp(tonumber(a.delay) or 0, 0, 3600)
            timer.Create("PD.Naval.Scenario." .. sc.id .. "." .. ctx.started .. "." .. i, math.max(t, 0.01), 1, function()
                local ship = Naval.GetMapShip()
                if ctx.cancelled or not ship or not Naval.SimRunning then return end
                local ok, err = pcall(fn, ctx, a, ship)
                if not ok then ErrorNoHalt("[Naval] Szenario " .. sc.name .. ", Aktion " .. i .. ": " .. tostring(err) .. "\n") end
            end)
        end
    end
    return true
end

--------------------------------------------------------------------------------
-- Ausloeser
--------------------------------------------------------------------------------

local function TerritoryOk(filter, ship)
    if not filter or filter == "" or filter == "any" then return true end
    local t = Naval.Territory and Naval.Territory[ship.systemId]
    local owner = t and t.f
    if filter == "contested" then return t and t.c == true end
    if filter == "none" then return owner == nil end
    if filter == "own" then return owner == ship.factionId end
    if filter == "hostile" then return owner ~= nil and Naval.GetRelation(ship.factionId, owner) == Naval.Relation.HOSTILE end
    return true
end

-- Orbit eines passenden Koerpers? -> Koerper
local function OrbitBody(ship, data)
    local factor = Setting("mass_shadow_factor", 4) * 1.5
    for _, b in ipairs(Naval.BodiesBySystem[ship.systemId] or {}) do
        if (not data.bodyId or data.bodyId == "" or data.bodyId == b.id)
            and (not data.bodyType or data.bodyType == "" or data.bodyType == b.type)
            and b.type ~= "star"
            and V3.Dist(ship.pos, Naval.BodyPos(b, Naval.Bodies)) <= (b.radius or 0) * factor then
            return b
        end
    end
end

-- Liegt die Bedingung gerade an? (fuer orbit/field/hull_below: nur beim Wechsel ausloesen)
local Conditions = {
    orbit = function(sc, ship) return OrbitBody(ship, sc.data) ~= nil end,
    field = function(sc, ship)
        if not ship.fieldKind then return false end
        local kind = sc.data.kind
        if kind == "nebula" then return ship.fieldNebula == true end
        if kind == "asteroids" then return ship.fieldKind == "asteroids" end
        return true
    end,
    hull_below = function(sc, ship)
        local max = (ship:Class() or {}).hull or 1000
        return (ship.hull or max) / max * 100 < (tonumber(sc.data.percent) or 50)
    end,
}

local function Ready(sc)
    if not sc.enabled or sc.trigger == "manual" then return false end
    if sc.once and sc.runs > 0 then return false end
    if os.time() - (sc.lastRun or 0) < (sc.cooldown or 0) then return false end
    return true
end

local function Roll(sc)
    return math.random() < math.Clamp(sc.chance or 1, 0, 1)
end

local function Check()
    local ship = Naval.GetMapShip()
    if not ship or ship.state ~= S.NORMAL then return end

    -- Systemwechsel
    local arrived = state.system and state.system ~= ship.systemId
    if state.system ~= ship.systemId then state.system = ship.systemId end

    for id, sc in pairs(Naval.Scenarios) do
        local fire = false
        local okTerritory = TerritoryOk(sc.data.territory, ship)

        if sc.trigger == "enter_system" then
            fire = arrived and (not sc.data.systemId or sc.data.systemId == "" or sc.data.systemId == ship.systemId) and okTerritory
        elseif Conditions[sc.trigger] then
            local now = Conditions[sc.trigger](sc, ship) and okTerritory
            local was = state.armed[id]
            state.armed[id] = now
            fire = now and was == false
        elseif sc.trigger == "interval" then
            local every = math.max(1, tonumber(sc.data.minutes) or 30) * 60
            state.nextRoll[id] = state.nextRoll[id] or (os.time() + every)
            if os.time() >= state.nextRoll[id] then
                state.nextRoll[id] = os.time() + every
                fire = okTerritory
            end
        end

        if fire and Ready(sc) and Roll(sc) then Naval.RunScenario(sc) end
    end
end

timer.Create("PD.Naval.Scenarios", 3, 0, function()
    if not Naval.SimRunning or Naval.Paused then return end
    local ok, err = xpcall(Check, debug.traceback)
    if not ok then ErrorNoHalt("[Naval] Szenarien: " .. tostring(err) .. "\n") end
end)

Naval.ScenarioCheckForTest = Check

--------------------------------------------------------------------------------
-- Befehle (Konsole, Web-Panel)
--------------------------------------------------------------------------------

local function Reply(ply, text)
    if IsValid(ply) then ply:ChatPrint("[Naval] " .. text) else print("[Naval] " .. text) end
end

function Naval.CleanupScenarioShips(id)
    local n = 0
    for sid, ship in pairs(Naval.Ships) do
        if ship.flags and ship.flags.scenario and (not id or ship.flags.scenario == id) then
            Naval.RemoveShip(sid)
            n = n + 1
        end
    end
    return n
end

concommand.Add("pd_naval_scenario", function(ply, _, args)
    if IsValid(ply) and not ply:IsAdmin() then return end
    local action = args[1] or "list"
    local by = IsValid(ply) and ply:Nick() or "Web-Panel/Konsole"

    if action == "list" then
        for id, sc in SortedPairs(Naval.Scenarios) do
            Reply(ply, ("#%d %s [%s] %s, %d x gelaufen"):format(id, sc.name, sc.trigger, sc.enabled and "an" or "aus", sc.runs))
        end
    elseif action == "reload" then
        Naval.LoadScenarios(function(n) Reply(ply, n .. " Szenarien geladen") end)
    elseif action == "start" then
        local sc = Naval.Scenarios[tonumber(args[2]) or -1]
        if not sc then Reply(ply, "Szenario nicht gefunden") return end
        if not Naval.SimRunning then Reply(ply, "Simulation läuft nicht") return end
        local ok, err = Naval.RunScenario(sc, by)
        Reply(ply, ok and (sc.name .. " gestartet") or err)
    elseif action == "stop" then
        for _, ctx in ipairs(Naval.ScenarioRuns) do ctx.cancelled = true end
        Reply(ply, "Laufende Szenarien angehalten (gespawnte Schiffe bleiben)")
    elseif action == "cleanup" then
        local n = Naval.CleanupScenarioShips(tonumber(args[2]))
        Reply(ply, n .. " Szenario-Schiffe entfernt")
        if PD.LOGS and PD.LOGS.Add then PD.LOGS.Add("Naval", by .. ": " .. n .. " Szenario-Schiffe entfernt", Color(200, 160, 255)) end
    end
end)
