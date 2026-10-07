--[[
    Naval - Kampf (Server): Energie, Schilde, Waffen, Schaden.

    Takt 0,5 s (Timer "PD.Naval.Combat"):
      1. Energie: Reaktorleistung (Reaktor-Zustand) auf Antrieb, Schilde,
         Waffen, Sensoren verteilt; Faktor je System = Zuteilung / 25.
      2. Schilde: 6 Zonen mit Strahlen- (e) und Partikelanteil (m); laden
         nach (Schildgenerator, Schildenergie), gesenkt laufen sie leer.
      3. Waffen: Batterien sammeln Schuesse (Kadenz x Waffenenergie), feuern
         auf das Ziel, wenn es in Reichweite und im Feuerbogen liegt.
         Treffer kommen nach der Flugzeit an (Warteschlange).
      4. Treffer: Zone aus der Richtung des Schuetzen; Energie -> e-Schild,
         Materie -> m-Schild, Ionen vor allem Schilde und Subsysteme; Rest
         auf die Huelle, ein Teil davon auf ein Subsystem der Zone.
      5. Huelle 0: KI-Schiffe zerstoert (nach combat_wreck_time entfernt),
         das Map-Schiff nur kampfunfaehig (Admin repariert).

    Zustand je Schiff (gespeichert in den Spalten shields/subs):
      ship.shields = {up, ratio, dist = {zone=Gewicht}, zones = {zone={e,m}}}
      ship.subs    = {hp = {id=hp}, power = {engines,shields,weapons,sensors},
                      ammo = {[i]=n}, off = {[i]=true}, roe, target, fire}
    ROE: "hold" nie, "return" nur zurueck, "free" auf jeden Feind.

    Netz: PD.Naval.Shots (unzuverlaessig) mit den sichtbaren Schuessen im
    System des Map-Schiffs.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3, Q = Naval.V3, Naval.Q
local S = Naval.State

local TICK = 0.5

util.AddNetworkString("PD.Naval.Shots")

Naval.PendingHits = Naval.PendingHits or {}

--------------------------------------------------------------------------------
-- Zustand
--------------------------------------------------------------------------------

local function SubMax(ship, id)
    for _, s in ipairs((ship:Class() or {}).subsystems or {}) do
        if s.id == id then return s.hp or 1 end
    end
    return 1
end

-- Geschuetzstellungen des Map-Schiffs aus dem Map-Profil (sonst die der Klasse)
function Naval.HardpointsFor(ship)
    if not ship:IsPlayerShip() then return nil end
    local profile = Naval.GetProfile()
    local list = profile and Naval.Settings["hardpoints_" .. profile.key]
    return (istable(list) and #list > 0) and list or nil
end

function Naval.HardpointMax(class, hp)
    return math.max(10, ((class and class.hull) or 1000) * 0.02 * (tonumber(hp.count) or 1))
end

-- Stellungen einer Batterie, die intakt sind und das Ziel im Bogen haben.
-- localRel: Ziel relativ zum Schiff in Schiffsachsen. Liefert Anzahl
-- Geschuetze und die Liste der Stellungen.
function Naval.HardpointsInArc(ship, cc, battery, localRel)
    local len = (ship:Class() or {}).lengthM or 300
    local hphp = ship.subs and ship.subs.hphp or {}
    local count, list = 0, {}
    for _, idx in ipairs(battery.hps or {}) do
        local hp = cc.hardpoints[idx]
        if hp and (hphp[idx] or 1) > 0 then
            local off = {x = (tonumber(hp.x) or 0) * len, y = (tonumber(hp.y) or 0) * len, z = (tonumber(hp.z) or 0) * len}
            if Naval.InArc(hp, V3.Normalize(V3.Sub(localRel, off))) then
                count = count + (tonumber(hp.count) or 1)
                list[#list + 1] = idx
            end
        end
    end
    return count, list
end

function Naval.Combat(ship)
    local class = ship:Class()
    local cc = Naval.ClassCombat(class, Naval.HardpointsFor(ship))

    ship.subs = istable(ship.subs) and ship.subs or {}
    local subs = ship.subs
    subs.hp = istable(subs.hp) and subs.hp or {}
    for _, s in ipairs((class or {}).subsystems or {}) do
        if subs.hp[s.id] == nil then subs.hp[s.id] = s.hp end
    end
    subs.power = istable(subs.power) and subs.power or {engines = 25, shields = 25, weapons = 25, sensors = 25}
    subs.ammo = istable(subs.ammo) and subs.ammo or {}
    subs.off = istable(subs.off) and subs.off or {}
    subs.roe = subs.roe or (ship:IsPlayerShip() and "hold" or "return")
    subs.due = subs.due or {}

    ship.shields = istable(ship.shields) and ship.shields or {}
    local sh = ship.shields
    if sh.up == nil then sh.up = true end
    sh.ratio = tonumber(sh.ratio) or cc.shields.ratio
    sh.dist = istable(sh.dist) and sh.dist or {}
    sh.zones = istable(sh.zones) and sh.zones or {}
    for _, z in ipairs(Naval.Zones) do
        sh.dist[z] = tonumber(sh.dist[z]) or 1
        if not istable(sh.zones[z]) then
            local cap = cc.shields.perZone
            sh.zones[z] = {e = cap * sh.ratio, m = cap * (1 - sh.ratio)}
        end
    end

    -- Haltbarkeit der Geschuetzstellungen
    subs.hphp = istable(subs.hphp) and subs.hphp or {}
    for i, hp in ipairs(cc.hardpoints or {}) do
        if subs.hphp[i] == nil then subs.hphp[i] = Naval.HardpointMax(class, hp) end
    end

    -- Munition
    for i, b in ipairs(cc.weapons) do
        local wt = Naval.WeaponTypes[b.type]
        if wt and wt.ammo and subs.ammo[i] == nil then subs.ammo[i] = b.ammo or 50 end
    end

    if ship.hull == nil or ship.hull > (class and class.hull or 1000) then ship.hull = class and class.hull or 1000 end

    return subs, sh, cc
end

-- 0..1: Zustand eines Subsystems (unter 50 % wirkt es schwaecher, 0 = aus)
function Naval.SubFactor(ship, id)
    local subs = ship.subs
    if not subs or not subs.hp or subs.hp[id] == nil then return 1 end

    local f = subs.hp[id] / SubMax(ship, id)
    if f <= 0 then return 0 end
    if f >= 0.5 then return 1 end
    return 0.3 + f * 1.4
end

-- Reaktorleistung und Faktor je Energiesystem (1 = Normal bei 25 Einheiten)
function Naval.PowerFactors(ship)
    local subs = ship.subs or {}
    local power = subs.power or {}
    local cc = Naval.ClassCombat(ship:Class())
    local output = cc.reactor * Naval.SubFactor(ship, "reactor")

    local sum = 0
    for _, sys in ipairs(Naval.PowerSystems) do sum = sum + (tonumber(power[sys.id]) or 0) end

    -- Mehr verteilt als der Reaktor liefert: alle anteilig weniger
    local scale = (sum > 0 and sum > output) and output / sum or 1
    local factors = {}
    for _, sys in ipairs(Naval.PowerSystems) do
        factors[sys.id] = math.Clamp((tonumber(power[sys.id]) or 0) * scale / 25, 0, 1.6)
    end

    return factors, output, sum
end

--------------------------------------------------------------------------------
-- Auswirkungen auf Flugwerte
--------------------------------------------------------------------------------

local function Disabled(ship)
    return ship.state == S.DISABLED or ship.state == S.DESTROYED
end

Naval.RegisterModifier("maxSpeed", "combat", function(ship)
    if Disabled(ship) then return 0 end
    if not ship.subs then return 1 end
    local f = Naval.PowerFactors(ship).engines
    return math.Clamp(0.25 + 0.75 * f, 0, 1.2) * Naval.SubFactor(ship, "engines")
end)

Naval.RegisterModifier("accel", "combat", function(ship)
    if not ship.subs then return 1 end
    return math.max(0.05, Naval.SubFactor(ship, "engines"))
end)

Naval.RegisterModifier("turnRate", "combat", function(ship)
    if Disabled(ship) then return 0 end
    if not ship.subs then return 1 end
    return math.max(0.15, Naval.SubFactor(ship, "maneuver"))
end)

Naval.RegisterModifier("sensorRange", "combat", function(ship)
    if not ship.subs then return 1 end
    local f = Naval.PowerFactors(ship).sensors
    return math.Clamp(0.4 + 0.6 * f, 0.4, 1.3) * math.max(0.3, Naval.SubFactor(ship, "sensors"))
end)

Naval.RegisterModifier("spoolTime", "combat", function(ship)
    if not ship.subs then return 1 end
    local f = Naval.SubFactor(ship, "hyperdrive")
    return f > 0 and 1 / f or 1
end)

-- Sprung nur mit funktionierendem Hyperantrieb
Naval.JumpBlockers = Naval.JumpBlockers or {}
Naval.JumpBlockers.combat = function(ship)
    if Disabled(ship) then return "Schiff ist kampfunfähig" end
    if ship.subs and Naval.SubFactor(ship, "hyperdrive") <= 0 then return "Hyperantrieb ausgefallen" end
end

--------------------------------------------------------------------------------
-- Treffer
--------------------------------------------------------------------------------

local function ShipLength(ship)
    return (ship:Class() or {}).lengthM or 300
end

-- Ein Subsystem der Zone (oder irgendeins) beschaedigen; preferred =
-- vom Waffenleitstand gezielt beschossenes Subsystem (nach Sensor-Scan)
local function DamageSubsystem(ship, zone, amount, preferred)
    local subs = ship.subs
    local list = Naval.ZoneSubsystems[zone] or {}
    local id = list[math.random(#list)]
    if preferred and subs.hp[preferred] ~= nil and math.random() < 0.7 then
        id = preferred
    elseif not id or subs.hp[id] == nil or math.random() < 0.25 then
        local all = table.GetKeys(subs.hp)
        id = all[math.random(#all)]
    end
    if not id then return end

    local before = subs.hp[id]
    subs.hp[id] = math.max(0, before - amount)

    if ship:IsPlayerShip() then hook.Run("PD.Naval.SubDamaged", ship, id, amount) end

    if before > 0 and subs.hp[id] <= 0 then
        Naval.Event(ship, "sub_offline", {sub = id})
        if ship:IsPlayerShip() then
            ship:Log("damage", "", (Naval.SubsystemNames[id] or id) .. " ausgefallen")
        end
    end
end

local function DestroyOrDisable(ship, attacker)
    ship.hull = 0

    if ship:IsPlayerShip() or (ship.flags and ship.flags.invulnerable) then
        ship.state = S.DISABLED
        ship.ctrl.throttle = 0
        ship.ctrl.autopilot = nil
        ship.hyper = {}
        Naval.Event(ship, "disabled", {by = attacker and attacker.id})
        ship:Log("damage", "", "Schiff kampfunfähig")
        if PD.LOGS and PD.LOGS.Add and not ship.flags.test then PD.LOGS.Add("Naval", ship.name .. " ist kampfunfähig", Color(255, 120, 80)) end
    else
        ship.state = S.DESTROYED
        ship.ctrl.throttle = 0
        ship.ctrl.autopilot = nil
        ship.orders = {queue = {}}
        ship.wreckUntil = CurTime() + (Naval.Settings.combat_wreck_time or 20)
        Naval.Event(ship, "destroyed", {by = attacker and attacker.id})
        if PD.LOGS and PD.LOGS.Add and not ship.flags.test then PD.LOGS.Add("Naval", ship.name .. " zerstört", Color(255, 120, 80)) end
    end

    ship.dirty = true
end

-- Schaden anwenden (amount nach Multiplikator). Gibt shieldOnly zurueck.
function Naval.ApplyHit(target, attacker, wtype, amount)
    if target.state == S.DESTROYED or target.state == S.DISABLED or target.state == S.HYPERSPACE then return end
    local tsubs, sh, tcc = Naval.Combat(target)

    -- Zone: Richtung zum Schuetzen in Schiffsachsen
    local zone = "front"
    if attacker and attacker.systemId == target.systemId then
        local dir = Q.RotateVec(Q.Conj(target.rot), V3.Sub(attacker.pos, target.pos))
        zone = Naval.ZoneOf(dir)
    end

    local wt = Naval.WeaponTypes[wtype] or {}
    local kind = wt.dmgType or "energy"
    local z = sh.zones[zone]
    local toShield, toHull, toSub = amount, 0, 0

    if kind == "ion" then
        toShield = amount * 1.5
    end

    -- Schildmodulation: Schilde verbrauchen weniger je Treffer
    local eff = 1
    if sh.mod and (sh.mod.untilT or 0) > Naval.Now() then
        eff = 1 - math.Clamp(Naval.Settings.shield_mod_bonus or 0.35, 0, 0.9)
    end

    local key = kind == "matter" and "m" or "e"
    local cost = toShield * eff
    local absorbedCost = math.min(z[key], cost)
    z[key] = z[key] - absorbedCost

    local absorbed = absorbedCost / eff
    local rest = toShield - absorbed
    if kind == "ion" then
        -- Ionen: kaum Huellenschaden, dafuer Subsysteme
        toHull = rest / 1.5 * 0.15
        toSub = rest / 1.5 * 0.8
    else
        toHull = rest
        toSub = rest * 0.3
    end

    if toHull > 0 then
        target.hull = math.max(0, (target.hull or 0) - toHull)

        -- Geschuetzstellung auf der Seite zum Angreifer
        if tcc.hardpoints and attacker and attacker.systemId == target.systemId and math.random() < 0.35 then
            local toAtt = V3.Normalize(Q.RotateVec(Q.Conj(target.rot), V3.Sub(attacker.pos, target.pos)))
            local candidates = {}
            for idx, hp in ipairs(tcc.hardpoints) do
                if (tsubs.hphp[idx] or 0) > 0 and V3.Dot(Naval.HardpointDir(hp), toAtt) > 0.2 then candidates[#candidates + 1] = idx end
            end
            local idx = candidates[math.random(math.max(#candidates, 1))]
            if idx then
                tsubs.hphp[idx] = math.max(0, tsubs.hphp[idx] - toHull * 0.6)
                if tsubs.hphp[idx] <= 0 then
                    local hp = tcc.hardpoints[idx]
                    Naval.Event(target, "hardpoint_lost", {idx = idx, group = hp.group})
                    if target:IsPlayerShip() then target:Log("damage", "", "Geschützstellung ausgefallen: " .. (hp.group or hp.type or "?")) end
                end
            end
        end
    end
    if toSub > 0 then
        local focus = attacker and attacker.subs and attacker.subs.target == target.id and attacker.subs.targetSub or nil
        DamageSubsystem(target, zone, focus and toSub * 1.5 or toSub, focus)
    end

    -- Waffenruhe (Kapitulation des Map-Schiffs angenommen): Beschuss beendet sie
    if attacker and attacker:IsPlayerShip() and target.subs and target.subs.ceasefire then
        target.subs.ceasefire = nil
        target.subs.roe = "free"
        if Naval.CommsMessage then Naval.CommsMessage(target, "Verrat! Feuer frei auf " .. attacker.name .. "!", "combat") end
    end
    if attacker and attacker:IsPlayerShip() and target.flags and target.flags.surrendered and not target.firedOnSurrender then
        target.firedOnSurrender = true
        attacker:Log("combat", "", "Feuer auf das kapitulierte Schiff " .. target.name)
    end

    target.lastAttacker = attacker and attacker.id
    target.lastAttacked = CurTime()
    target.dirty = true

    if target.hull <= 0 then DestroyOrDisable(target, attacker) end

    -- Map-Schiff: Treffer je Takt sammeln (eine Meldung an die Spieler)
    if target:IsPlayerShip() then
        local fx = target.hitFx or {shield = 0, hull = 0, zones = {}}
        fx.shield = fx.shield + absorbed
        fx.hull = fx.hull + toHull
        fx.zones[zone] = true
        target.hitFx = fx
    end

    return toHull <= 0
end

--------------------------------------------------------------------------------
-- Ziel und Feuer
--------------------------------------------------------------------------------

local function Valid(target, ship)
    return target and target ~= ship and target.systemId == ship.systemId
        and target.state ~= S.DESTROYED and target.state ~= S.HYPERSPACE
        and target.state ~= S.JUMPING and target.state ~= S.EXITING
end

local function Hostile(a, b)
    return Naval.GetRelation(a.factionId, b.factionId) == Naval.Relation.HOSTILE
end

function Naval.MaxWeaponRange(ship)
    local cc = Naval.ClassCombat(ship:Class(), Naval.HardpointsFor(ship))
    local r = 0
    for _, b in ipairs(cc.weapons) do
        local wt = Naval.WeaponTypes[b.type]
        if wt and not wt.pointDefense then r = math.max(r, wt.range) end
    end
    return r
end

local function PickTarget(ship, bySystem)
    local subs = ship.subs
    local current = subs.target and Naval.Ships[subs.target]
    if Valid(current, ship) then return current end
    subs.target = nil

    if ship:IsPlayerShip() then return nil end   -- Map-Schiff: Ziel nur vom Waffenleitstand

    -- Zurueckschiessen
    if subs.roe == "return" or subs.roe == "free" then
        local att = ship.lastAttacker and Naval.Ships[ship.lastAttacker]
        if Valid(att, ship) and (ship.lastAttacked or 0) > CurTime() - 60 then
            subs.target = att.id
            return att
        end
    end

    if subs.roe ~= "free" then return nil end

    -- Naechster Feind in Reichweite
    local range = Naval.MaxWeaponRange(ship) * 1.3
    local best, bestD = nil, range * range
    for _, other in ipairs(bySystem[ship.systemId] or {}) do
        if Valid(other, ship) and other.state ~= S.DISABLED and Hostile(ship, other)
            and not (Naval.Concealed and Naval.Concealed(ship, other)) then
            local d = V3.LenSqr(V3.Sub(other.pos, ship.pos))
            if d < bestD then best, bestD = other, d end
        end
    end

    if best then subs.target = best.id end
    return best
end

-- Trefferchance gegen ein Ziel
function Naval.HitChance(ship, target, wt, dist)
    local size = math.Clamp(ShipLength(target) / math.max(dist * 0.004, 1), 0.15, 1)
    local evade = 1 - math.min(0.35, target:Speed() / 20000)
    local chance = wt.accuracy * size * evade * math.max(0.4, Naval.SubFactor(ship, "sensors"))
    if Naval.FieldHitFactor then chance = chance * Naval.FieldHitFactor(ship, target) end

    -- Punktverteidigung des Ziels gegen Raketen/Torpedos
    if wt.dmgType == "matter" then
        local pd = 0
        for _, b in ipairs(Naval.ClassCombat(target:Class(), Naval.HardpointsFor(target)).weapons) do
            if b.type == "pd" then pd = pd + (b.count or 0) end
        end
        chance = chance * (1 - math.min(0.6, pd * 0.015))
    end

    return math.Clamp(chance, 0.02, 0.98)
end

local visual = {}

local function Fire(ship, target, dt, focusSystem, sink)
    local subs, _, cc = Naval.Combat(ship)
    local factors = Naval.PowerFactors(ship)
    local wf = factors.weapons
    if wf <= 0 then return end

    local rel = V3.Sub(target.pos, ship.pos)
    local dist = V3.Len(rel)
    local localRel = Q.RotateVec(Q.Conj(ship.rot), rel)
    local zone = Naval.ZoneOf(localRel)
    local mult = Naval.Settings.combat_damage_mult or 0.5

    for i, b in ipairs(cc.weapons) do
        local wt = Naval.WeaponTypes[b.type]
        local inArc, active, sources = false, b.count or 1, nil
        if b.hps then
            -- Geschuetzstellungen: nur die mit dem Ziel im Bogen
            active, sources = Naval.HardpointsInArc(ship, cc, b, localRel)
            inArc = active > 0
        else
            for _, a in ipairs(b.arc or {}) do if a == zone then inArc = true break end end
        end

        if wt and not subs.off[i] and inArc and dist <= wt.range and (not wt.ammo or (subs.ammo[i] or 0) > 0) then
            subs.due[i] = (subs.due[i] or 0) + active * wt.rof / 60 * dt * wf
            local shots = math.floor(subs.due[i])

            if shots > 0 then
                subs.due[i] = subs.due[i] - shots
                if wt.ammo then
                    shots = math.min(shots, subs.ammo[i])
                    subs.ammo[i] = subs.ammo[i] - shots
                end

                local chance = Naval.HitChance(ship, target, wt, dist)
                local hits = 0
                for _ = 1, math.min(shots, 40) do
                    if math.random() < chance then hits = hits + 1 end
                end
                if shots > 40 then hits = math.Round(hits * shots / 40) end

                local travel = dist / wt.speed
                if hits > 0 then
                    table.insert(sink or Naval.PendingHits, {t = CurTime() + travel, target = target.id, attacker = ship.id,
                        type = b.type, amount = hits * wt.damage * mult})
                end

                -- Sichtbare Schuesse (begrenzt) im System des Map-Schiffs
                if ship.systemId == focusSystem and not wt.pointDefense then
                    for n = 1, math.min(shots, 3) do
                        local src = sources and sources[math.random(#sources)] or 0
                        visual[#visual + 1] = {ship.id, target.id, Naval.WeaponTypeIndex[b.type] or 1, n <= hits, travel, src}
                    end
                end

                ship.dirty = true
            end
        else
            subs.due[i] = 0
        end
    end
end

--------------------------------------------------------------------------------
-- Takt
--------------------------------------------------------------------------------

Naval.CombatFire = function(ship, target, dt, sink) return Fire(ship, target, dt, nil, sink) end

local function Regen(ship, dt)
    local _, sh, cc = Naval.Combat(ship)
    local f = Naval.PowerFactors(ship).shields * Naval.SubFactor(ship, "shieldgen") * (Naval.Settings.combat_shield_regen_mult or 1)
    if Naval.FieldShieldFactor then f = f * Naval.FieldShieldFactor(ship) end

    for _, zone in ipairs(Naval.Zones) do
        local z = sh.zones[zone]
        local cap = cc.shields.perZone * (sh.dist[zone] or 1)

        if sh.up and f > 0 and not Disabled(ship) then
            local capE, capM = cap * sh.ratio, cap * (1 - sh.ratio)
            local add = cc.shields.regen * f * dt * (sh.dist[zone] or 1)
            z.e = math.min(capE, z.e + add * sh.ratio)
            z.m = math.min(capM, z.m + add * (1 - sh.ratio))
            -- Umverteilt: ueber der Grenze langsam abbauen
            if z.e > capE then z.e = math.max(capE, z.e - cap * 0.05 * dt) end
            if z.m > capM then z.m = math.max(capM, z.m - cap * 0.05 * dt) end
        else
            z.e = math.max(0, z.e - cap * 0.2 * dt)
            z.m = math.max(0, z.m - cap * 0.2 * dt)
        end
    end
end

-- Ueberlast: mehr als 100 % verteilt schaedigt langsam den Reaktor
local function Overload(ship, dt)
    local _, output, sum = Naval.PowerFactors(ship)
    if sum > 100 and output > 0 then
        local over = (sum - 100) / 25
        if math.random() < over * dt * 0.2 then
            ship.subs.hp.reactor = math.max(0, (ship.subs.hp.reactor or 0) - SubMax(ship, "reactor") * 0.05)
            Naval.Event(ship, "overload", {})
        end
    end
end

Naval.CombatRegen = Regen

function Naval.CombatTick()
    if Naval.Paused then return end

    local mapShip = Naval.GetMapShip()
    local focusSystem = mapShip and mapShip.systemId
    local now = CurTime()

    -- Schiffe je System
    local bySystem = {}
    for _, ship in pairs(Naval.Ships) do
        bySystem[ship.systemId] = bySystem[ship.systemId] or {}
        table.insert(bySystem[ship.systemId], ship)
    end

    visual = {}

    for _, ship in pairs(Naval.Ships) do
        Naval.Combat(ship)

        if ship.state == S.DESTROYED then
            if ship.wreckUntil and now > ship.wreckUntil then Naval.RemoveShip(ship.id) end
        elseif ship.state ~= S.HYPERSPACE then
            Regen(ship, TICK)
            Overload(ship, TICK)

            -- Map-Schiff feuert nur mit "Feuer frei" vom Waffenleitstand,
            -- KI-Schiffe nach ihrer ROE
            local canFire
            if ship:IsPlayerShip() then
                canFire = ship.subs.fire == true
            else
                canFire = ship.subs.roe ~= "hold" and not (ship.flags and (ship.flags.surrendered or ship.flags.prisoner))
            end

            if canFire and ship.state == S.NORMAL then
                local target = PickTarget(ship, bySystem)
                if target then Fire(ship, target, TICK, focusSystem) end
            end
        end
    end

    -- Angekommene Treffer
    local keep = {}
    for _, hit in ipairs(Naval.PendingHits) do
        if hit.t <= now then
            local target = Naval.Ships[hit.target]
            if target then Naval.ApplyHit(target, Naval.Ships[hit.attacker], hit.type, hit.amount) end
        else
            keep[#keep + 1] = hit
        end
    end
    Naval.PendingHits = keep

    if mapShip and mapShip.hitFx then
        local fx = mapShip.hitFx
        mapShip.hitFx = nil
        Naval.Event(mapShip, "hit", {shield = math.Round(fx.shield), hull = math.Round(fx.hull), zones = table.GetKeys(fx.zones)})
        hook.Run("PD.Naval.MapShipHit", mapShip, fx)
    end

    -- Schuesse an die Spieler
    if #visual > 0 then
        local recipients = {}
        for _, ply in ipairs(player.GetHumans()) do
            if ply.PD_NavalReady then recipients[#recipients + 1] = ply end
        end

        if #recipients > 0 then
            net.Start("PD.Naval.Shots", true)
                net.WriteUInt(math.min(#visual, 255), 8)
                for i = 1, math.min(#visual, 255) do
                    local v = visual[i]
                    net.WriteUInt(v[1], 16)
                    net.WriteUInt(v[2], 16)
                    net.WriteUInt(v[3], 4)
                    net.WriteBool(v[4])
                    net.WriteFloat(v[5])
                    net.WriteUInt(math.Clamp(v[6] or 0, 0, 255), 8)
                end
            net.Send(recipients)
        end
    end
end

local function SafeCombat()
    local ok, err = xpcall(Naval.CombatTick, debug.traceback)
    if not ok then ErrorNoHalt("[Naval] Fehler im Kampftakt: " .. tostring(err) .. "\n") end
end

hook.Add("PD.Naval.SimStarted", "PD.Naval.Combat", function()
    timer.Create("PD.Naval.Combat", TICK, 0, SafeCombat)
end)

--------------------------------------------------------------------------------
-- Reparatur (Admin)
--------------------------------------------------------------------------------

function Naval.Repair(ship)
    local class = ship:Class()
    -- Einstellungen (Energie, ROE, Schildverteilung) bleiben erhalten
    if istable(ship.subs) then ship.subs.hp = nil ship.subs.ammo = nil ship.subs.due = nil ship.subs.hphp = nil end
    if istable(ship.shields) then ship.shields.zones = nil end
    ship.hull = class and class.hull or 1000
    if ship.state == S.DISABLED or ship.state == S.DESTROYED then ship.state = S.NORMAL end
    ship.wreckUntil = nil
    Naval.Combat(ship)
    ship.dirty = true
    Naval.SaveShip(ship)
    hook.Run("PD.Naval.Repaired", ship)
end
