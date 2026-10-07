--[[
    Naval - Asteroidenfelder und Nebel (Server, Stufe 4e).

    Felder je System: automatisch erzeugt (gleicher Startwert je System, also
    immer gleich; abschaltbar mit field_procedural) plus eigene Eintraege aus
    pd_naval_fields. Eine Zeile mit kind = "none" schaltet die erzeugten
    Felder eines Systems ab. Bekannte Orte (Hoth, Polis Massa, Kessel ...)
    bekommen ihr Feld immer.

    Wirkungen (Werte im Admin-Tab "Raumflotte"):
      Asteroiden  schneller als field_asteroid_safe x Hoechstfahrt -> Einschlaege
                  (Materieschaden am Bug); Sensoren x field_asteroid_sensors;
                  schwer zu treffen; versteckt ab field_asteroid_hide m;
                  der Autopilot bremst vor und in Feldern auf sichere Fahrt
      Nebel       Sensoren x field_nebula_sensors, Schilde laden langsamer
                  (x field_nebula_shields), schwerer zu treffen, versteckt ab
                  field_nebula_hide m
    Admins: pd_naval_field add|list|remove|procedural (am Ort des Map-Schiffs).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3 = Naval.V3
local S = Naval.State

local esc = function(value) return PD.SQL.EscapeString(tostring(value == nil and "" or value)) end

Naval.FieldRows = Naval.FieldRows or {}
Naval.FieldCache = {}

local function Setting(key, default)
    return tonumber(Naval.Settings and Naval.Settings[key]) or default
end

--------------------------------------------------------------------------------
-- Erzeugung
--------------------------------------------------------------------------------

local NEBULA_COLORS = {
    {150, 90, 255}, {255, 90, 130}, {80, 200, 230}, {255, 160, 70}, {120, 230, 150}, {90, 120, 255},
}

-- Bekannte Orte: Systemname (klein) -> erzwungene Felder
local KNOWN = {
    ["hoth"] = {belt = true},
    ["polis massa"] = {belt = true, cluster = true},
    ["kessel"] = {nebula = "Der Schlund", cluster = true},
    ["subterrel"] = {belt = true},
    ["bespin"] = {cluster = true},
    ["dagobah"] = {nebula = "Dagobah-Nebel"},
    ["ord mantell"] = {cluster = true},
    ["scarif"] = {belt = true},
    ["lothal"] = {cluster = true},
}

-- Kleiner Zufallsgenerator mit festem Startwert (math.random bleibt unberuehrt)
local function Rng(seed)
    local s = (tonumber(util.CRC(seed)) or 1) % 2147483646 + 1
    return function(a, b)
        s = (s * 16807) % 2147483647
        local r = s / 2147483647
        if a then return a + r * (b - a) end
        return r
    end
end

local function BodyList(systemId)
    local list = {}
    for _, b in ipairs(Naval.BodiesBySystem[systemId] or {}) do
        list[#list + 1] = {body = b, pos = Naval.BodyPos(b, Naval.Bodies)}
    end
    return list
end

-- Freier Platz fuer eine Kugel (nicht im Massenschatten eines Koerpers)
local function FreeSpot(rnd, bodies, minR, maxR, radius)
    local factor = Setting("mass_shadow_factor", 4)
    for _ = 1, 16 do
        local r, a = rnd(minR, maxR), rnd(0, math.pi * 2)
        local p = {x = math.cos(a) * r, y = math.sin(a) * r, z = rnd(-0.04, 0.04) * r}
        local free = true
        for _, e in ipairs(bodies) do
            if V3.Dist(p, e.pos) < (e.body.radius or 0) * factor + radius then free = false break end
        end
        if free then return p end
    end
end

local function Generate(systemId)
    local sys = Naval.Systems[systemId]
    if not sys then return {} end
    local rnd = Rng("fields:" .. systemId)
    local known = KNOWN[string.lower(sys.name or "")] or {}
    local bodies = BodyList(systemId)
    local out = {}

    local starR, orbits, asteroidHint = 80000, {}, false
    for _, e in ipairs(bodies) do
        local b = e.body
        if b.type == "star" then starR = math.max(starR, b.radius or 0) end
        if b.type == "planet" and b.orbit and (b.orbit.radius or 0) > 0 then orbits[#orbits + 1] = b.orbit.radius end
        local d = istable(b.data) and b.data or {}
        if tostring(d.terrain or ""):lower():find("asteroid", 1, true) or tostring(d.planetType or ""):lower() == "asteroid" then
            asteroidHint = true
        end
    end
    table.sort(orbits)
    local inner = starR * Setting("mass_shadow_factor", 4) * 2
    local outer = math.max((orbits[#orbits] or 600000) * 1.3, inner * 3)

    -- Asteroidenguertel in einer Luecke zwischen den Planetenbahnen
    if known.belt or asteroidHint or rnd() < 0.35 then
        local edges = {inner}
        for _, r in ipairs(orbits) do if r > inner then edges[#edges + 1] = r end end
        edges[#edges + 1] = (orbits[#orbits] or inner * 2) * 1.6
        local i = math.max(1, math.min(#edges - 1, math.floor(rnd(1, #edges))))
        local a, b = edges[i], edges[i + 1] or edges[i] * 1.6
        local width = math.Clamp((b - a) * 0.25, 20000, 250000)
        out[#out + 1] = {kind = "belt", name = (sys.name or "") .. "-Asteroidengürtel", pos = {x = 0, y = 0, z = 0},
            radius = (a + b) * 0.5, width = width, thickness = math.max(8000, width * 0.15), density = rnd(0.7, 1.3)}
    end

    -- Asteroidenfeld (Kugel)
    if known.cluster or rnd() < 0.15 then
        local radius = rnd(30000, 80000)
        local p = FreeSpot(rnd, bodies, inner, outer, radius)
        if p then
            out[#out + 1] = {kind = "cluster", name = (sys.name or "") .. "-Asteroidenfeld", pos = p, radius = radius, density = rnd(0.8, 1.5)}
        end
    end

    -- Nebel
    if known.nebula or rnd() < 0.12 then
        local radius = rnd(150000, 400000)
        local p = FreeSpot(rnd, bodies, inner, outer * 1.2, radius)
        if p then
            local c = NEBULA_COLORS[math.floor(rnd(1, #NEBULA_COLORS + 0.999))]
            out[#out + 1] = {kind = "nebula", name = isstring(known.nebula) and known.nebula or ((sys.name or "") .. "-Nebel"),
                pos = p, radius = radius, density = 1, color = {c[1], c[2], c[3]}}
        end
    end

    for i, f in ipairs(out) do f.id = "p" .. i end
    return out
end

-- Alle Felder eines Systems (zwischengespeichert)
function Naval.SystemFields(systemId)
    if not systemId then return {} end
    local cached = Naval.FieldCache[systemId]
    if cached then return cached end

    local rows = Naval.FieldRows[systemId] or {}
    local list = {}
    local off = Setting("field_procedural", 1) ~= 1
    for _, r in ipairs(rows) do
        if r.kind == "none" then off = true end
    end
    if not off then list = Generate(systemId) end
    for _, r in ipairs(rows) do
        if r.kind ~= "none" then list[#list + 1] = r end
    end

    Naval.FieldCache[systemId] = list
    return list
end

--------------------------------------------------------------------------------
-- Datenbank
--------------------------------------------------------------------------------

local CREATE = [[CREATE TABLE IF NOT EXISTS `pd_naval_fields` (
    `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `system_id` VARCHAR(64) NOT NULL,
    `kind` VARCHAR(16) NOT NULL DEFAULT 'cluster',
    `name` VARCHAR(128) NOT NULL DEFAULT '',
    `x` DOUBLE NOT NULL DEFAULT 0,
    `y` DOUBLE NOT NULL DEFAULT 0,
    `z` DOUBLE NOT NULL DEFAULT 0,
    `radius` DOUBLE NOT NULL DEFAULT 50000,
    `width` DOUBLE NOT NULL DEFAULT 0,
    `thickness` DOUBLE NOT NULL DEFAULT 0,
    `density` FLOAT NOT NULL DEFAULT 1,
    `color` VARCHAR(32) NOT NULL DEFAULT '',
    `updated_at` BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    KEY `system_id` (`system_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4]]

function Naval.LoadFields(callback)
    PD.SQL.Query(CREATE, function()
        PD.SQL.FetchAll("SELECT * FROM `pd_naval_fields`", function(rows)
            local bySystem = {}
            for _, row in ipairs(rows or {}) do
                local list = bySystem[row.system_id] or {}
                bySystem[row.system_id] = list
                local col = string.Explode(",", row.color or "")
                list[#list + 1] = {
                    id = "db" .. row.id, dbId = tonumber(row.id), kind = row.kind, name = row.name,
                    pos = {x = tonumber(row.x) or 0, y = tonumber(row.y) or 0, z = tonumber(row.z) or 0},
                    radius = tonumber(row.radius) or 50000, width = tonumber(row.width) or 0, thickness = tonumber(row.thickness) or 0,
                    density = tonumber(row.density) or 1,
                    color = tonumber(col[3]) and {tonumber(col[1]), tonumber(col[2]), tonumber(col[3])} or (row.kind == "nebula" and {150, 90, 255} or nil),
                }
            end
            Naval.FieldRows = bySystem
            Naval.FieldCache = {}
            if Naval.SimRunning and Naval.SendSystem then Naval.SendSystem() end
            if callback then callback(#(rows or {})) end
        end)
    end)
end

hook.Add("PD.Naval.Ready", "PD.Naval.Fields", function() Naval.LoadFields() end)
if Naval.Systems and next(Naval.Systems) then Naval.LoadFields() end

--------------------------------------------------------------------------------
-- Wirkungen
--------------------------------------------------------------------------------

local function Nebula(f) return f.kind == "nebula" end

-- Feld, in dem ein Schiff steht (vom Sekundentakt gesetzt)
local function Update(ship)
    local fields = Naval.SystemFields(ship.systemId)
    if ship.state == S.HYPERSPACE or #fields == 0 then
        ship.fieldId, ship.fieldKind, ship.fieldNebula = nil, nil, nil
        return
    end
    local rock = Naval.FieldAt(fields, ship.pos, Naval.IsAsteroidField)
    local neb = Naval.FieldAt(fields, ship.pos, Nebula)
    local f = rock or neb
    ship.fieldId, ship.fieldKind, ship.fieldNebula = f and f.id, f and (rock and "asteroids" or "nebula"), neb and true or nil
    return rock, neb
end

-- Einschlaege bei zu hoher Fahrt im Asteroidenfeld
local function Collide(ship, f)
    local maxSpeed = math.max(ship:Stat("maxSpeed"), 1)
    local over = ship:Speed() / maxSpeed - Setting("field_asteroid_safe", 0.35)
    if over <= 0 then return end
    if math.random() >= math.min(0.9, (f.density or 1) * (0.3 + over * 1.5)) then return end

    local hullMax = (ship:Class() or {}).hull or 1000
    Naval.ApplyHit(ship, nil, "missile", hullMax * 0.006 * (1 + over * 4) * Setting("field_asteroid_damage", 1))
end

local function Announce(ship, f, entering)
    local text = entering and ("Einflug: " .. f.name .. " (" .. Naval.FieldKinds[f.kind] .. ")") or ("Verlassen: " .. f.name)
    if Naval.IsAsteroidField(f) and entering then
        text = text .. (" - sichere Fahrt unter %d %%"):format(Setting("field_asteroid_safe", 0.35) * 100)
    end
    ship:Log("nav", "", text)
    for _, ply in ipairs(player.GetHumans()) do
        if ply.PD_NavalReady then PD.Notify("[Navigation] " .. text, Color(240, 200, 90), false, ply) end
    end
end

local function Step(ship)
    local before = ship.fieldId
    local rock, neb = Update(ship)
    if rock and ship.state == S.NORMAL then Collide(ship, rock) end

    if ship:IsPlayerShip() and ship.fieldId ~= before then
        local fields = Naval.SystemFields(ship.systemId)
        for _, f in ipairs(fields) do
            if f.id == before then Announce(ship, f, false) end
        end
        local now = rock or neb
        if now then Announce(ship, now, true) end
    end
end

Naval.FieldStepForTest = Step

timer.Create("PD.Naval.Fields", 1, 0, function()
    if not Naval.SimRunning or Naval.Paused then return end
    local ok, err = xpcall(function()
        for _, ship in pairs(Naval.Ships) do Step(ship) end
    end, debug.traceback)
    if not ok then ErrorNoHalt("[Naval] Felder: " .. tostring(err) .. "\n") end
end)

Naval.RegisterModifier("sensorRange", "fields", function(ship)
    if ship.fieldKind == "asteroids" then
        return Setting("field_asteroid_sensors", 0.7) * (ship.fieldNebula and Setting("field_nebula_sensors", 0.35) or 1)
    end
    if ship.fieldNebula then return Setting("field_nebula_sensors", 0.35) end
    return 1
end)

-- Schildladung im Nebel
function Naval.FieldShieldFactor(ship)
    return ship.fieldNebula and Setting("field_nebula_shields", 0.4) or 1
end

-- Trefferchance: Ziel im Feld schwer zu treffen, Schuetze im Nebel ungenauer
function Naval.FieldHitFactor(ship, target)
    local f = 1
    if target.fieldKind == "asteroids" then f = f * 0.6 elseif target.fieldNebula then f = f * 0.75 end
    if ship.fieldNebula then f = f * 0.85 end
    return f
end

-- Versteckt sich target vor observer?
function Naval.Concealed(observer, target)
    if not target.fieldKind then return false end
    local hide = target.fieldKind == "nebula" and Setting("field_nebula_hide", 20000) or Setting("field_asteroid_hide", 40000)
    if target.fieldNebula then hide = math.min(hide, Setting("field_nebula_hide", 20000)) end
    if observer.fieldId and observer.fieldId == target.fieldId then hide = hide * 1.5 end
    return V3.Dist(observer.pos, target.pos) > hide
end

-- Autopilot: sichere Fahrt in und kurz vor Asteroidenfeldern
function Naval.FieldSpeedLimit(ship)
    local fields = Naval.SystemFields(ship.systemId)
    if #fields == 0 then return math.huge end
    local ahead = V3.Add(ship.pos, V3.Scale(ship.vel, 12))
    for _, f in ipairs(fields) do
        if Naval.IsAsteroidField(f) and (Naval.FieldDepth(f, ship.pos) <= 0 or Naval.FieldDepth(f, ahead) <= 0) then
            return math.max(ship:Stat("maxSpeed"), 1) * Setting("field_asteroid_safe", 0.35) * 0.9
        end
    end
    return math.huge
end

--------------------------------------------------------------------------------
-- Admin-Befehle
--------------------------------------------------------------------------------

local function Reply(ply, text)
    if IsValid(ply) then ply:ChatPrint("[Naval] " .. text) else print("[Naval] " .. text) end
end

local function Reload(ply, text)
    Naval.LoadFields(function() Reply(ply, text) end)
    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("Naval", (IsValid(ply) and ply:Nick() or "Konsole") .. ": " .. text, Color(120, 170, 255))
    end
end

concommand.Add("pd_naval_field", function(ply, _, args)
    if IsValid(ply) and not ply:IsAdmin() then return end
    local ship = Naval.GetMapShip()
    if not ship then Reply(ply, "Kein Map-Schiff") return end
    local sys = ship.systemId
    local action = args[1] or "list"

    if action == "list" then
        for _, f in ipairs(Naval.SystemFields(sys)) do
            Reply(ply, ("%s  %s  %s  Radius %.0f km  Abstand %.0f km"):format(f.id, Naval.FieldKinds[f.kind] or f.kind, f.name,
                f.radius / 1000, math.max(0, Naval.FieldDepth(f, ship.pos)) / 1000))
        end
        Reply(ply, "pd_naval_field add <cluster|nebula|belt> <Radius km bzw. Breite km> [Name]  |  remove <dbN>  |  procedural on|off")
    elseif action == "add" then
        local kind = args[2]
        local size = (tonumber(args[3]) or 50) * 1000
        if kind ~= "cluster" and kind ~= "nebula" and kind ~= "belt" then Reply(ply, "Art: cluster, nebula oder belt") return end
        local name = table.concat(args, " ", 4)
        if name == "" then name = Naval.FieldKinds[kind] end
        local p, radius, width, thickness, color = ship.pos, size, 0, 0, ""
        if kind == "belt" then
            -- Ring um den Stern durch die Position des Map-Schiffs
            radius = math.sqrt(p.x * p.x + p.y * p.y)
            width, thickness = size, math.max(8000, size * 0.15)
            p = {x = 0, y = 0, z = 0}
        elseif kind == "nebula" then
            color = "150,90,255"
        end
        PD.SQL.Query(("INSERT INTO `pd_naval_fields` (`system_id`, `kind`, `name`, `x`, `y`, `z`, `radius`, `width`, `thickness`, `color`, `updated_at`) VALUES (%s, %s, %s, %f, %f, %f, %f, %f, %f, %s, %d)")
            :format(esc(sys), esc(kind), esc(name), p.x, p.y, p.z or 0, radius, width, thickness, esc(color), os.time()), function()
            Reload(ply, name .. " angelegt")
        end)
    elseif action == "remove" then
        local id = tonumber(string.match(args[2] or "", "%d+"))
        if not id then Reply(ply, "Nur eigene Felder (dbN) lassen sich entfernen; erzeugte: procedural off") return end
        PD.SQL.Query("DELETE FROM `pd_naval_fields` WHERE `id` = " .. id, function() Reload(ply, "Feld db" .. id .. " entfernt") end)
    elseif action == "procedural" then
        local on = args[2] ~= "off"
        PD.SQL.Query("DELETE FROM `pd_naval_fields` WHERE `kind` = 'none' AND `system_id` = " .. esc(sys), function()
            if on then Reload(ply, "Erzeugte Felder in " .. sys .. " an") return end
            PD.SQL.Query("INSERT INTO `pd_naval_fields` (`system_id`, `kind`, `updated_at`) VALUES (" .. esc(sys) .. ", 'none', " .. os.time() .. ")",
                function() Reload(ply, "Erzeugte Felder in " .. sys .. " aus") end)
        end)
    end
end)
