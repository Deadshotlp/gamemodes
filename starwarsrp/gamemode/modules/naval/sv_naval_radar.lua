--[[
    Naval - Radar und Sensoren (Server).

    Jedes Schiff sieht nur, was seine Sensoren erfassen (auch die KI). Je
    Beobachter gibt es Spuren (Naval.Tracks[beobachterId][zielId]):
      precise = {src, pos, t, q}   Position (Optik, Rundum-Radar, Drehradar,
                                   Verfolgung, Datenlink); q = Guete 0..1
      passive = {dir, dist, t}     nur Richtung + grobe Entfernung (EM)
      mass    = {pos, err, t}      grob, durch nichts zu verdecken (Masse)

    Sensoren (Werte im Admin-Tab "Radar und Sensoren"):
      Optik         radar_optical_range, Sichtlinie
      Rundum-Radar  360 Grad, radar_near_range, staendig (nicht bei Schleichfahrt)
      Drehradar     5-Grad-Strahl, radar_sweep_range, ein Umlauf je
                    radar_sweep_period; "Verfolgung" haelt den Strahl auf
                    einem Ziel (staendig, genau), der Rest wird nicht abgetastet
      EM passiv     Abstrahlung des Ziels (Reaktor, Schub, Schilde, Waffenfeuer,
                    aktives Radar, Stoersender) -> Richtung
      Masse         grosse Schiffe weit und ungenau; kuendigt Hyperraum-
                    Austritte im System an
    Radar und Optik brauchen Sichtlinie: Sterne, Planeten und Monde werfen
    Radarschatten. Nebel und Asteroidenfelder daempfen, die Rueckstrahlflaeche
    haengt von Groesse und Lage (Bug voraus = klein) ab.

    Gegenmassnahmen: Schleichfahrt (EMCON: kein aktives Radar, wenig
    Abstrahlung, halbe Hoechstfahrt), ECM-Stoersender (verkuerzt feindliche
    Radare in Richtung des Stoerers, Stoerer leuchtet im EM-Sensor),
    Taeuschkoerper (falsche Radarkontakte, lenken Torpedos/Raketen ab),
    Frequenzabgleich (Minispiel an der Radar-Konsole hebt Stoerung auf).

    Feuerleitung: Naval.TrackFactor(schuetze, ziel, waffe) - Verfolgung voll,
    Optik/Rundum gut, alte Drehradar-Spur schwaecher, EM kaum; Raketen und
    Torpedos des Map-Schiffs nur mit Verfolgung (KI: naher, guter Spur).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3, Q = Naval.V3, Naval.Q
local S = Naval.State

util.AddNetworkString("PD.Naval.EccmGame")

Naval.Tracks = Naval.Tracks or {}
Naval.Decoys = Naval.Decoys or {}

local function Setting(key, default)
    return tonumber(Naval.Settings and Naval.Settings[key]) or default
end

local function Len(ship)
    return (ship:Class() or {}).lengthM or 300
end

local function Hostile(a, b)
    return Naval.GetRelation(a.factionId, b.factionId) == Naval.Relation.HOSTILE
end

local function Radar(ship)
    ship.subs = ship.subs or {}
    local r = ship.subs.radar
    if not istable(r) then
        r = {}
        ship.subs.radar = r
    end
    return r
end
Naval.RadarState = Radar

local function ActiveRadar(ship)
    local r = Radar(ship)
    return not r.emcon and not r.off and ship.state ~= S.DISABLED and Naval.SubFactor(ship, "sensors") > 0
end

--------------------------------------------------------------------------------
-- Sichtlinie, Signatur, Abstrahlung
--------------------------------------------------------------------------------

-- Himmelskoerper eines Systems (Position, Radius), je Takt einmal berechnet
local obstacleCache, obstacleFrame = {}, -1
local function Obstacles(systemId)
    if obstacleFrame ~= math.floor(CurTime() * 4) then
        obstacleFrame = math.floor(CurTime() * 4)
        obstacleCache = {}
    end
    local list = obstacleCache[systemId]
    if list then return list end
    list = {}
    for _, body in ipairs(Naval.BodiesBySystem[systemId] or {}) do
        if body.type == "star" or body.type == "planet" or body.type == "moon" then
            list[#list + 1] = {c = Naval.BodyPos(body, Naval.Bodies), r = (body.radius or 0) * 0.98, body = body}
        end
    end
    obstacleCache[systemId] = list
    return list
end

-- Verdeckt ein Himmelskoerper die Strecke a-b?
local function Blocked(systemId, a, b)
    local d = V3.Sub(b, a)
    local len2 = V3.LenSqr(d)
    if len2 < 1 then return false end
    for _, o in ipairs(Obstacles(systemId)) do
        local t = math.Clamp(V3.Dot(V3.Sub(o.c, a), d) / len2, 0, 1)
        local p = V3.Add(a, V3.Scale(d, t))
        if V3.LenSqr(V3.Sub(p, o.c)) < o.r * o.r then return o.body end
    end
    return false
end
Naval.RadarBlocked = Blocked

-- Rueckstrahlflaeche: Groesse und Lage (vom Beobachter aus)
local function Signature(target, observer)
    local toObs = Q.RotateVec(Q.Conj(target.rot), V3.Sub(observer.pos, target.pos))
    local l = V3.Len(toObs)
    local along = l > 1 and math.abs(toObs.x / l) or 0
    local aspect = 0.6 + 0.4 * math.sqrt(math.max(0, 1 - along * along))
    return math.Clamp(math.sqrt(Len(target) / 300), 0.4, 2) * aspect
end

-- Daempfung durch Felder (Ziel oder Beobachter im Nebel/Asteroidenfeld)
local function Environment(target)
    local f = 1
    if target.fieldKind == "asteroids" then f = f * Setting("field_asteroid_sensors", 0.7) end
    if target.fieldNebula then f = f * Setting("field_nebula_sensors", 0.35) end
    return f
end

-- Sensorwirkung des Beobachters (Energie, Schaden, eigenes Feld)
local function SensorMult(ship)
    local class = ship:Class() or {}
    local base = class.sensors and class.sensors.range or Setting("sensor_default", 300000)
    return math.Clamp(ship:Stat("sensorRange") / math.max(base, 1), 0, 2)
end

-- Elektromagnetische Abstrahlung
function Naval.Emission(ship)
    local r = Radar(ship)
    local e = 0.3 + math.abs(ship.ctrl and ship.ctrl.throttle or 0) * 0.6
    if ship.shields and ship.shields.up ~= false then e = e + 0.3 end
    if (ship.lastFired or 0) > CurTime() - 6 then e = e + 1 end
    if ActiveRadar(ship) then e = e + 0.8 end
    if r.emcon then e = e * 0.35 end
    if r.ecm then e = e + 3 end
    return e * math.Clamp(math.sqrt(Len(ship) / 300), 0.4, 2)
end

-- Stoerung: Faktor fuer die Radarreichweite von observer zu target (1 = keine)
local function JamFactor(observer, target, jammers)
    if #jammers == 0 then return 1 end
    if (Radar(observer).eccmUntil or 0) > CurTime() then return 1 end
    local f = 1
    local cone = math.cos(math.rad(Setting("radar_ecm_cone", 30)))
    local toT = V3.Normalize(V3.Sub(target.pos, observer.pos))
    for _, j in ipairs(jammers) do
        if j ~= observer and Hostile(j, observer) then
            local toJ = V3.Sub(j.pos, observer.pos)
            local dj = V3.Len(toJ)
            local range = Setting("radar_ecm_range", 200000)
            if dj <= range and (j == target or V3.Dot(V3.Scale(toJ, 1 / math.max(dj, 1)), toT) >= cone) then
                -- Je naeher der Stoerer, desto staerker (Durchbrennen nur nah)
                f = math.min(f, 0.25 + 0.75 * (dj / range))
            end
        end
    end
    return f
end

--------------------------------------------------------------------------------
-- Drehradar
--------------------------------------------------------------------------------

local function Azimuth(ship, pos)
    local l = Q.RotateVec(Q.Conj(ship.rot), V3.Sub(pos, ship.pos))
    return math.deg(math.atan2(l.y, l.x)) % 360
end

-- Ueberstrichener Bereich seit dem letzten Takt
local function SweepCovers(r, az)
    if not r.sweepFrom then return false end
    local half = Setting("radar_beam", 5) / 2
    local span = r.sweepTo - r.sweepFrom
    local a = r.sweepFrom % 360 - half
    local b = a + span + half * 2
    az = az % 360
    return (az >= a and az <= b) or (az + 360 >= a and az + 360 <= b) or (az - 360 >= a and az - 360 <= b)
end

local function SweepAngle(t)
    local period = math.max(2, Setting("radar_sweep_period", 12))
    return (t / period * 360)
end

--------------------------------------------------------------------------------
-- Erfassung
--------------------------------------------------------------------------------

local function TrackOf(observer, id)
    local list = Naval.Tracks[observer.id]
    if not list then
        list = {}
        Naval.Tracks[observer.id] = list
    end
    local t = list[id]
    if not t then
        t = {}
        list[id] = t
    end
    return t
end

local function Detect(observer, others, jammers, now)
    local r = Radar(observer)
    local active = ActiveRadar(observer)
    local sens = SensorMult(observer)
    local optical = Setting("radar_optical_range", 15000) * math.max(sens, 0.3)
    local near = Setting("radar_near_range", 100000)
    local far = Setting("radar_sweep_range", 250000)
    local emRange = Setting("radar_em_range", 150000)
    local massRange = Setting("radar_mass_range", 600000)
    local massMin = Setting("radar_mass_min_length", 200)

    -- Drehradar: Strahl seit dem letzten Takt
    local sweepNow = SweepAngle(now) + (observer.id * 37) % 360
    if r.lock then
        r.sweepFrom, r.sweepTo = nil, nil
    else
        r.sweepFrom = r.lastSweep or sweepNow
        r.sweepTo = sweepNow
        if r.sweepTo - r.sweepFrom > 360 then r.sweepFrom = r.sweepTo - 360 end
    end
    r.lastSweep = sweepNow

    for _, target in ipairs(others) do
        if target ~= observer and target.state ~= S.HYPERSPACE and target.state ~= S.DESTROYED and not (target.flags and target.flags.hidden) then
            local d = V3.Dist(target.pos, observer.pos)
            local blocked = Blocked(observer.systemId, observer.pos, target.pos)
            local tr = TrackOf(observer, target.id)

            if not blocked then
                local sig = Signature(target, observer) * Environment(target)
                local jam = JamFactor(observer, target, jammers)
                local src, q
                if d <= optical * Environment(target) then
                    src, q = "optical", 1
                elseif active and r.lock == target.id and d <= far * sig * sens * jam then
                    src, q = "track", 1
                elseif active and d <= near * sig * sens * jam then
                    src, q = "near", 0.9
                elseif active and not r.lock and d <= far * sig * sens * jam and SweepCovers(r, Azimuth(observer, target.pos)) then
                    src, q = "sweep", 0.8
                end
                if src then tr.precise = {src = src, pos = V3.Copy(target.pos), t = now, q = q} end

                -- Passiv (EM): Richtung und grobe Entfernung
                local em = Naval.Emission(target) * Environment(target)
                if d <= emRange * em * math.max(sens, 0.3) then
                    tr.passive = {dir = V3.Normalize(V3.Sub(target.pos, observer.pos)), dist = d * (0.7 + ((target.id * 13) % 7) / 10), t = now}
                end
            end

            -- Masse: grosse Schiffe, nicht verdeckbar, ungenau
            local len = Len(target)
            if len >= massMin and d <= massRange * math.min(len / 600, 2) * math.max(sens, 0.3) then
                local err = math.max(5000, d * 0.08)
                local seed = math.floor(now / 10) + target.id
                local fuzz = {x = math.sin(seed * 1.7) * err, y = math.cos(seed * 2.3) * err, z = math.sin(seed * 0.9) * err * 0.3}
                tr.mass = {pos = V3.Add(target.pos, fuzz), err = err, t = now}
            end
        end
    end

    -- Verfolgung: Ziel nicht mehr erfasst -> zurueck zum Drehen
    if r.lock then
        local lt = Naval.Tracks[observer.id] and Naval.Tracks[observer.id][r.lock]
        if not lt or not lt.precise or now - lt.precise.t > 2 then
            r.lock = nil
            r.lockLost = now
        end
    end
end

-- Veraltete Spuren entfernen
local function Expire(observer, now)
    local list = Naval.Tracks[observer.id]
    if not list then return end
    local timeout = Setting("radar_track_timeout", 30)
    for id, t in pairs(list) do
        local target = Naval.Ships[id]
        if not target or target.systemId ~= observer.systemId or target.state == S.DESTROYED then
            list[id] = nil
        else
            if t.precise and now - t.precise.t > timeout then t.precise = nil end
            if t.passive and now - t.passive.t > 10 then t.passive = nil end
            if t.mass and now - t.mass.t > 20 then t.mass = nil end
            if not t.precise and not t.passive and not t.mass then list[id] = nil end
        end
    end
end

-- Datenlink: Verbuendete im System teilen ihre genauen Spuren mit dem Map-Schiff
local function DataLink(ship, others, now)
    local own = Naval.Tracks[ship.id] or {}
    Naval.Tracks[ship.id] = own
    for _, ally in ipairs(others) do
        if ally ~= ship and ally.state == S.NORMAL and not Hostile(ally, ship)
            and Naval.GetRelation(ally.factionId, ship.factionId) == Naval.Relation.ALLY then
            for id, t in pairs(Naval.Tracks[ally.id] or {}) do
                if id ~= ship.id and t.precise and now - t.precise.t < 5 then
                    local mine = own[id] or {}
                    own[id] = mine
                    if not mine.precise or mine.precise.t < t.precise.t - 1 then
                        mine.precise = {src = "link", pos = t.precise.pos, t = t.precise.t, q = 0.7}
                    end
                end
            end
        end
    end
end

-- Hyperraum-Austritte im System (Masse-Sensoren): Vorwarnung
local function IncomingFor(ship, now)
    local list = {}
    local warn = Setting("radar_hyper_warning", 30)
    for _, o in pairs(Naval.Ships) do
        local h = o.hyper
        if o.state == S.HYPERSPACE and h and h.to == ship.systemId and h.tExit and h.arrive then
            local left = h.tExit - Naval.Now()
            if left <= warn and left > 0 then list[#list + 1] = {id = o.id, pos = h.arrive, eta = left} end
        end
    end
    return list
end

--------------------------------------------------------------------------------
-- Takt
--------------------------------------------------------------------------------

local ticks = 0
local function Tick()
    local now = CurTime()
    ticks = ticks + 1
    local mapShip = Naval.GetMapShip()
    local focus = mapShip and mapShip.systemId

    local bySystem, jammersBy = {}, {}
    for _, ship in pairs(Naval.Ships) do
        local list = bySystem[ship.systemId] or {}
        bySystem[ship.systemId] = list
        list[#list + 1] = ship
        if Radar(ship).ecm and ship.state == S.NORMAL then
            jammersBy[ship.systemId] = jammersBy[ship.systemId] or {}
            table.insert(jammersBy[ship.systemId], ship)
        end
    end

    -- Taeuschkoerper bewegen / ablaufen lassen
    for i = #Naval.Decoys, 1, -1 do
        local dc = Naval.Decoys[i]
        if now > dc.untilT then table.remove(Naval.Decoys, i) else dc.pos = V3.Add(dc.pos, V3.Scale(dc.vel, 0.25)) end
    end

    for _, ship in pairs(Naval.Ships) do
        if ship.state ~= S.HYPERSPACE and ship.state ~= S.DESTROYED then
            -- Map-Schiff jeden Takt (0.25 s), KI im selben System jede Sekunde,
            -- in anderen Systemen alle 4 s
            local every = ship == mapShip and 1 or (ship.systemId == focus and 4 or 16)
            if (ticks + ship.id) % every == 0 then
                local others = bySystem[ship.systemId] or {}
                Detect(ship, others, jammersBy[ship.systemId] or {}, now)
                Expire(ship, now)
                if ship == mapShip then DataLink(ship, others, now) end
            end
        end
    end
end

timer.Create("PD.Naval.Radar", 0.25, 0, function()
    if not Naval.SimRunning or Naval.Paused then return end
    local ok, err = xpcall(Tick, debug.traceback)
    if not ok then ErrorNoHalt("[Naval] Radar: " .. tostring(err) .. "\n") end
end)

Naval.RadarDetectForTest = Detect

--------------------------------------------------------------------------------
-- Abfragen fuer Sicht, Netz und Kampf
--------------------------------------------------------------------------------

local function Precise(observer, target)
    local list = Naval.Tracks[observer.id]
    local t = list and list[target.id]
    return t and t.precise
end

-- Verborgen = keine genaue Spur (sv_naval_fields.lua ruft das auf)
function Naval.RadarConcealed(observer, target)
    if Naval.GetRelation(observer.factionId, target.factionId) == Naval.Relation.ALLY and observer:IsPlayerShip() then
        return false -- eigene Verbuendete kennt man (Kennung)
    end
    return Precise(observer, target) == nil
end

-- Position, an der der Beobachter das Ziel sieht (letzte Messung)
function Naval.TrackPos(observer, target)
    local p = Precise(observer, target)
    if not p or p.src == "optical" or p.src == "near" or p.src == "track" then return target.pos end
    return p.pos
end

-- Feuerleitung: Faktor auf die Trefferchance (0 = kein Schuss)
function Naval.TrackFactor(ship, target, wt)
    local p = Precise(ship, target)
    local now = CurTime()
    if not p then
        local t = Naval.Tracks[ship.id] and Naval.Tracks[ship.id][target.id]
        if t and t.passive and not (wt and wt.dmgType == "matter") then return 0.25 end
        return 0
    end
    local age = now - p.t
    local f
    if p.src == "track" then f = 1
    elseif p.src == "optical" or p.src == "near" then f = 0.9
    else f = math.max(0.4, (p.src == "link" and 0.75 or 0.8) - age * 0.02) end

    -- Raketen und Torpedos: Map-Schiff braucht Verfolgung, KI eine gute, frische Spur
    if wt and wt.dmgType == "matter" then
        if ship:IsPlayerShip() then
            if p.src ~= "track" then return 0 end
        elseif f < 0.85 or age > 2 then
            return 0
        end
        -- Taeuschkoerper des Ziels lenken ab
        for _, dc in ipairs(Naval.Decoys) do
            if dc.owner == target.id then f = f * 0.4 break end
        end
    end
    return f
end

-- Schleichfahrt: halbe Hoechstfahrt
Naval.RegisterModifier("maxSpeed", "radar", function(ship)
    local r = ship.subs and ship.subs.radar
    return r and r.emcon and Setting("radar_emcon_speed", 0.5) or 1
end)

--------------------------------------------------------------------------------
-- KI: Stoersender im Gefecht, Taeuschkoerper bei Torpedobeschuss
--------------------------------------------------------------------------------

local ECM_CLASSES = {venator = true, acclamator = true, arquitens = true, munificent = true, recusant = true, providence = true, lucrehulk = true}

function Naval.Decoy(ship)
    local r = Radar(ship)
    local now = CurTime()
    r.decoys = r.decoys or Setting("radar_decoy_count", 6)
    if r.decoys <= 0 or (r.decoyNext or 0) > now then return false end
    r.decoys = r.decoys - 1
    r.decoyNext = now + Setting("radar_decoy_cooldown", 45)
    for i = 1, 3 do
        local dir = V3.Normalize({x = math.Rand(-1, 1), y = math.Rand(-1, 1), z = math.Rand(-0.3, 0.3)})
        Naval.Decoys[#Naval.Decoys + 1] = {owner = ship.id, systemId = ship.systemId, id = -(ship.id * 10 + i),
            pos = V3.Add(ship.pos, V3.Scale(dir, 800)), vel = V3.Add(ship.vel, V3.Scale(dir, 120)),
            untilT = now + Setting("radar_decoy_time", 20)}
    end
    ship.dirty = true
    return true
end

timer.Create("PD.Naval.RadarAI", 2, 0, function()
    if not Naval.SimRunning or Naval.Paused then return end
    for _, ship in pairs(Naval.Ships) do
        if not ship:IsPlayerShip() and ship.state == S.NORMAL and ECM_CLASSES[ship.classId]
            and not (ship.flags and (ship.flags.surrendered or ship.flags.aiOff)) then
            local r = Radar(ship)
            local target = ship.subs and ship.subs.target and Naval.Ships[ship.subs.target]
            local fighting = target and target.systemId == ship.systemId and V3.Dist(target.pos, ship.pos) < 150000
            r.ecm = fighting or nil
            if fighting and (ship.lastMatterHit or 0) > CurTime() - 4 then Naval.Decoy(ship) end
        end
    end
end)

--------------------------------------------------------------------------------
-- Radar-Konsole
--------------------------------------------------------------------------------

Naval.CombatCommands = Naval.CombatCommands or {}
Naval.CombatCommands.radar = Naval.CombatCommands.radar or {}
local RC = Naval.CombatCommands.radar

RC.lock = function(ply, ship, args)
    local r = Radar(ship)
    local target = Naval.Ships[tonumber(args.id) or -1]
    if not target then return end
    local p = Precise(ship, target)
    if not p then Naval.Feedback(ply, "Kein Radarkontakt") return end
    if not ActiveRadar(ship) then Naval.Feedback(ply, "Aktives Radar ist aus") return end
    r.lock = target.id
    ship:Log("combat", ply:Nick(), "Radar verfolgt " .. target.name)
end

RC.sweep = function(ply, ship)
    Radar(ship).lock = nil
end

RC.emcon = function(ply, ship, args)
    local r = Radar(ship)
    r.emcon = args.on == true or nil
    if r.emcon then r.lock = nil r.ecm = nil end
    ship:Log("combat", ply:Nick(), r.emcon and "Schleichfahrt (Emissionskontrolle)" or "Schleichfahrt beendet")
    ship.dirty = true
end

RC.ecm = function(ply, ship, args)
    local r = Radar(ship)
    if r.emcon and args.on then Naval.Feedback(ply, "Bei Schleichfahrt kein Störsender") return end
    r.ecm = args.on == true or nil
    ship:Log("combat", ply:Nick(), r.ecm and "Störsender an" or "Störsender aus")
    ship.dirty = true
end

RC.decoy = function(ply, ship)
    if not Naval.Decoy(ship) then
        local r = Radar(ship)
        Naval.Feedback(ply, (r.decoys or 0) <= 0 and "Keine Täuschkörper mehr" or "Werfer lädt nach")
        return
    end
    ship:Log("combat", ply:Nick(), "Täuschkörper ausgestoßen")
end

-- Frequenzabgleich gegen Stoersender (Minispiel)
RC.eccm_start = function(ply, ship)
    local r = Radar(ship)
    r.eccmGame = {f = math.Rand(2, 8), p = math.random(0, 35) * 10, start = CurTime()}
    net.Start("PD.Naval.EccmGame")
    net.WriteFloat(r.eccmGame.f)
    net.WriteUInt(r.eccmGame.p, 9)
    net.Send(ply)
end

RC.eccm_submit = function(ply, ship, args)
    local r = Radar(ship)
    local g = r.eccmGame
    r.eccmGame = nil
    if not g or CurTime() - g.start > 35 then Naval.Feedback(ply, "Zu spät") return end
    local df = math.abs((tonumber(args.f) or 0) - g.f)
    local dp = math.abs(((tonumber(args.p) or 0) - g.p + 180) % 360 - 180)
    if df <= 0.3 and dp <= 20 then
        r.eccmUntil = CurTime() + Setting("radar_eccm_time", 60)
        Naval.Feedback(ply, "Frequenzsprung erfolgreich - Störung aufgehoben", true)
        ship:Log("combat", ply:Nick(), "Störung durch Frequenzabgleich aufgehoben")
    else
        Naval.Feedback(ply, "Abgleich fehlgeschlagen")
    end
end

-- Daten fuer die Radar-Konsole
Naval.StatusExtras = Naval.StatusExtras or {}
Naval.StatusExtras.radar = function(ship)
    local r = Radar(ship)
    local now = CurTime()
    local tracks = {}
    for id, t in pairs(Naval.Tracks[ship.id] or {}) do
        local target = Naval.Ships[id]
        if target then
            local e = {id = id}
            if t.precise then
                local rel = V3.Sub(t.precise.pos, ship.pos)
                e.p = {math.Round(rel.x), math.Round(rel.y), math.Round(rel.z)}
                e.src = t.precise.src
                e.age = math.Round(now - t.precise.t, 1)
            elseif t.passive then
                e.dir = {math.Round(t.passive.dir.x, 3), math.Round(t.passive.dir.y, 3), math.Round(t.passive.dir.z, 3)}
                e.dist = math.Round(t.passive.dist)
                e.src = "em"
            elseif t.mass then
                local rel = V3.Sub(t.mass.pos, ship.pos)
                e.p = {math.Round(rel.x), math.Round(rel.y), math.Round(rel.z)}
                e.err = math.Round(t.mass.err)
                e.src = "mass"
            end
            if e.src then
                e.hostile = Hostile(ship, target) or nil
                e.jam = Radar(target).ecm or nil
                tracks[#tracks + 1] = e
            end
        end
    end

    -- Feindliche Taeuschkoerper erscheinen als unbekannte Radarkontakte
    for _, dc in ipairs(Naval.Decoys) do
        local owner = Naval.Ships[dc.owner]
        if owner and dc.systemId == ship.systemId and owner ~= ship and Hostile(owner, ship) and ActiveRadar(ship)
            and V3.Dist(dc.pos, ship.pos) <= Setting("radar_near_range", 100000) and not Blocked(ship.systemId, ship.pos, dc.pos) then
            local rel = V3.Sub(dc.pos, ship.pos)
            tracks[#tracks + 1] = {id = dc.id, p = {math.Round(rel.x), math.Round(rel.y), math.Round(rel.z)}, src = "near", age = 0, decoy = true}
        end
    end

    local incoming = {}
    for _, inc in ipairs(IncomingFor(ship, now)) do
        local rel = V3.Sub(inc.pos, ship.pos)
        incoming[#incoming + 1] = {p = {math.Round(rel.x), math.Round(rel.y), math.Round(rel.z)}, eta = math.Round(inc.eta)}
    end

    -- Werden wir gestoert?
    local jammed = false
    for _, o in pairs(Naval.Ships) do
        if o.systemId == ship.systemId and Radar(o).ecm and Hostile(o, ship) and V3.Dist(o.pos, ship.pos) <= Setting("radar_ecm_range", 200000) then
            jammed = true
            break
        end
    end

    local period = math.max(2, Setting("radar_sweep_period", 12))
    return {
        tracks = tracks, incoming = incoming, lock = r.lock, emcon = r.emcon, ecm = r.ecm, active = ActiveRadar(ship) or nil,
        jammed = jammed or nil, eccm = math.max(0, math.Round((r.eccmUntil or 0) - now)), lockLost = r.lockLost and now - r.lockLost < 5 or nil,
        decoys = r.decoys or Setting("radar_decoy_count", 6), decoyCd = math.max(0, math.Round((r.decoyNext or 0) - now)),
        near = Setting("radar_near_range", 100000), far = Setting("radar_sweep_range", 250000),
        period = period, sweepOffset = (ship.id * 37) % 360, curTime = now,
    }
end

-- Reparatur in der Werft fuellt die Taeuschkoerper auf
hook.Add("PD.Naval.Repaired", "PD.Naval.Radar", function(ship)
    local r = ship.subs and ship.subs.radar
    if r then r.decoys = nil r.decoyNext = nil end
end)
