--[[
    Naval - Traktorstrahl und Entern (Server, Stufe 4e).

    Traktorstrahl (Naval.ClassTractor: Staerke je Klasse, 0 = keiner):
      Reichweite tractor_range * Staerke. Greifen laesst sich ein Schiff im
      selben System, das wehrlos ist (kampfunfaehig, kapituliert, gefangen,
      Haupttriebwerke ausgefallen) oder hoechstens halb so lang wie das
      eigene und ohne Schilde. Gehaltene Schiffe haengen fest am Halter
      (gleiche Lage relativ zu ihm, drehen mit), die KI ruht, Springen ist
      fuer beide gesperrt. "Heranziehen" holt das Ziel bis zur Andockweite.
      Nicht wehrlose Ziele koennen sich mit ihren Triebwerken losreissen.
      ship.subs.tractor = {target, rel, relRot, hold, pull}

    Entern (nur bei herangezogenem Ziel mit gesenkten Schilden):
      Dauer boarding_time je nach Schiffsgroesse (kapituliert schneller),
      Erfolg bei kapitulierten/gefangenen Schiffen sicher, sonst nach Moral
      der Besatzung. Erfolg: das Schiff wechselt die Fraktion (flags.captured,
      flags.capturedFrom). Mit boarding_live = 1 entscheidet die Spielleitung
      (Leitstand-Knoepfe fuer Admins bzw. pd_naval_boarding <id> ok|fail).
      ship.subs.boarding = {target, done (os.time), chance, live}

    Das Map-Schiff wird nie selbst gegriffen oder geentert.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3, Q = Naval.V3, Naval.Q
local S = Naval.State

Naval.TractorHeld = Naval.TractorHeld or {}

local function Setting(key, default)
    return tonumber(Naval.Settings and Naval.Settings[key]) or default
end

local function Len(ship)
    return (ship:Class() or {}).lengthM or 300
end

local function Strength(ship)
    return Naval.ClassTractor(ship:Class()) * (ship.subs and Naval.SubFactor(ship, "reactor") or 1)
end

local function Range(ship)
    return Setting("tractor_range", 5000) * Strength(ship)
end

local function DockDist(ship, target)
    return (Len(ship) + Len(target)) * 0.5 + 150
end

local function Test(ship)
    return ship.flags and ship.flags.test
end

function Naval.Defenseless(t)
    return t.state == S.DISABLED or (t.flags and (t.flags.surrendered or t.flags.prisoner))
        or (t.subs and Naval.SubFactor(t, "engines") <= 0) or false
end

local function ShieldsUp(t)
    return t.shields and t.shields.up ~= false
end

-- Darf ship das Ziel greifen? -> true | false, Grund
function Naval.TractorCheck(ship, t)
    if Strength(ship) <= 0 then return false, "Kein Traktorstrahl an Bord" end
    if ship.state ~= S.NORMAL then return false, "Schiff nicht bereit" end
    if not t or t == ship or t:IsPlayerShip() then return false, "Kein gültiges Ziel" end
    if t.systemId ~= ship.systemId or (t.state ~= S.NORMAL and t.state ~= S.DISABLED) then return false, "Ziel nicht erreichbar" end
    if Naval.TractorHeld[t.id] and Naval.TractorHeld[t.id] ~= ship.id then return false, "Wird bereits gehalten" end
    if V3.Dist(t.pos, ship.pos) > Range(ship) then return false, "Außer Reichweite" end
    if not Naval.Defenseless(t) then
        if Len(t) > Len(ship) * 0.5 then return false, "Zu groß – nur wehrlose Schiffe" end
        if ShieldsUp(t) then return false, "Schilde des Ziels sind oben" end
    end
    return true
end

function Naval.TractorLock(ship, t)
    local ok, reason = Naval.TractorCheck(ship, t)
    if not ok then return false, reason end

    local rel = V3.Sub(t.pos, ship.pos)
    local inv = Q.Conj(ship.rot)
    ship.subs = ship.subs or {}
    ship.subs.tractor = {
        target = t.id, rel = Q.RotateVec(inv, V3.Normalize(rel)), relRot = Q.Mul(inv, t.rot),
        hold = V3.Len(rel), pull = false,
    }
    Naval.TractorHeld[t.id] = ship.id
    ship.dirty = true
    Naval.Event(ship, "tractor_lock", {target = t.id})
    return true
end

function Naval.TractorRelease(ship, reason)
    local tr = ship.subs and ship.subs.tractor
    if not tr then return end
    ship.subs.tractor = nil
    if Naval.TractorHeld[tr.target] == ship.id then Naval.TractorHeld[tr.target] = nil end
    ship.dirty = true
    Naval.Event(ship, "tractor_release", {target = tr.target, reason = reason})
    if ship:IsPlayerShip() and reason then ship:Log("combat", "", "Traktorstrahl: " .. reason) end
end

-- Ziel am Halter fuehren (aus Naval.Tick nach dem Schiffsschritt)
local function Hold(ship, t, tr, dt)
    if tr.pull then tr.hold = math.max(DockDist(ship, t), tr.hold - Setting("tractor_reel_speed", 150) * dt) end

    local want = V3.Add(ship.pos, V3.Scale(Q.RotateVec(ship.rot, tr.rel), tr.hold))
    local diff = V3.Sub(want, t.pos)
    local d = V3.Len(diff)
    local step = (Setting("tractor_reel_speed", 150) * 2 + V3.Len(ship.vel)) * dt
    t.pos = d <= step and want or V3.Add(t.pos, V3.Scale(diff, step / d))
    t.vel = V3.Copy(ship.vel)
    t.rot = Q.Slerp(t.rot, Q.Mul(ship.rot, tr.relRot), math.min(1, dt * 0.5))
    t.angVel = V3.New()
    t.ctrl.throttle = 0
    t.ctrl.autopilot = nil
    t.ctrl.rate = {p = 0, y = 0, r = 0}
    t.ctrl.thrust = {x = 0, y = 0, z = 0}
    t.hyper = {}
    t.dirty = true

    -- Losreissen: nur nicht wehrlose Ziele, je nach Triebwerken
    if not Naval.Defenseless(t) and not Test(t) then
        local chance = 0.03 * Naval.SubFactor(t, "engines") / math.max(Strength(ship), 0.2)
        if math.random() < chance * dt then return false end
    end
    return true
end

function Naval.TractorTick(dt)
    local held = {}
    for _, ship in pairs(Naval.Ships) do
        local tr = ship.subs and ship.subs.tractor
        if tr then
            local t = Naval.Ships[tr.target or -1]
            local reason
            if not t or t.state == S.DESTROYED or t.state == S.HYPERSPACE or t.systemId ~= ship.systemId then
                reason = "Ziel verloren"
            elseif ship.state ~= S.NORMAL then
                reason = "Strahl abgeschaltet"
            elseif held[t.id] then
                reason = "Ziel wird bereits gehalten"
            elseif not tr.rel or V3.Dist(t.pos, ship.pos) > math.max(Range(ship) * 1.5, tr.hold + 2000) then
                reason = "Ziel außer Reichweite"
            end

            if not reason then
                held[t.id] = ship.id
                if not Hold(ship, t, tr, dt) then reason = t.name .. " hat sich losgerissen" end
            end
            if reason then
                held[tr.target or -1] = nil
                Naval.TractorRelease(ship, reason)
            end
        end
    end
    Naval.TractorHeld = held
end

-- Gehaltene Schiffe springen nicht, Halter erst nach dem Loesen
Naval.JumpBlockers = Naval.JumpBlockers or {}
Naval.JumpBlockers.tractor = function(ship)
    if Naval.TractorHeld[ship.id] then return "Im Traktorstrahl gefangen" end
    if ship.subs and ship.subs.tractor then return "Traktorstrahl aktiv (erst lösen)" end
end

--------------------------------------------------------------------------------
-- Entern
--------------------------------------------------------------------------------

local function Docked(ship, t)
    local tr = ship.subs and ship.subs.tractor
    return tr and tr.target == t.id and V3.Dist(t.pos, ship.pos) <= DockDist(ship, t) + 300
end

function Naval.BoardCheck(ship, t)
    if not t or not Docked(ship, t) then return false, "Ziel erst mit dem Traktorstrahl heranziehen" end
    if ShieldsUp(t) then return false, "Schilde des Ziels sind oben" end
    if ship.subs.boarding then return false, "Enterkommando ist schon unterwegs" end
    if (ship.subs.boardingCooldown or 0) > os.time() then
        return false, ("Enterkommando sammelt sich (%d s)"):format(ship.subs.boardingCooldown - os.time())
    end
    return true
end

local function Chance(t)
    if t.flags and (t.flags.surrendered or t.flags.prisoner) then return 1 end
    local morale = t.subs and t.subs.morale or 75
    local c = 0.85 - morale / 100 * 0.6
    if t.state == S.DISABLED then c = c + 0.2 end
    return math.Clamp(c, 0.15, 0.95)
end

function Naval.Board(ship, t)
    local ok, reason = Naval.BoardCheck(ship, t)
    if not ok then return false, reason end

    local yielded = t.flags and (t.flags.surrendered or t.flags.prisoner)
    local duration = Setting("boarding_time", 90) * math.Clamp(Len(t) / 600, 0.5, 2.5) * (yielded and 0.5 or 1)
    ship.subs.boarding = {
        target = t.id, start = os.time(), done = os.time() + math.ceil(duration), chance = Chance(t),
        live = ship:IsPlayerShip() and Setting("boarding_live", 0) == 1 or nil,
    }
    ship.dirty = true
    Naval.Event(ship, "boarding", {target = t.id})
    if not Test(ship) and Naval.CommsMessage and not yielded then
        Naval.CommsMessage(t, "Eindringlinge an Bord! Alle Mann zu den Waffen!", "distress")
    end
    if not Test(ship) and PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("Naval", ship.name .. " entert " .. t.name, Color(255, 200, 80))
    end
    return true
end

function Naval.Capture(t, by)
    t.flags = t.flags or {}
    t.flags.capturedFrom = t.flags.capturedFrom or t.factionId
    t.flags.captured = true
    t.flags.surrendered = nil
    t.flags.prisoner = nil
    t.factionId = by.factionId
    t.fleeing = nil
    if t.fleetId and t.fleetId > 0 and Naval.FleetRemove then Naval.FleetRemove(t) end

    if Naval.Combat then
        local subs = Naval.Combat(t)
        subs.roe = "hold"
        subs.target = nil
        subs.fire = nil
        subs.morale = 50
    end
    Naval.SetOrders(t, {}, by.name)
    t.ctrl.throttle = 0
    t.dirty = true

    Naval.Event(t, "captured", {by = by.id})
    if not Test(t) then
        if Naval.CommsMessage then Naval.CommsMessage(t, "Hier Enterkommando der " .. by.name .. ": Schiff gesichert, wir haben die Brücke.", "msg") end
        if PD.LOGS and PD.LOGS.Add then PD.LOGS.Add("Naval", t.name .. " wurde von " .. by.name .. " erobert", Color(120, 255, 160)) end
    end
end

local function Resolve(ship, success, by)
    local b = ship.subs and ship.subs.boarding
    if not b then return end
    local t = Naval.Ships[b.target or -1]
    ship.subs.boarding = nil
    ship.dirty = true
    if not t then return end

    if success then
        Naval.Capture(t, ship)
        if ship:IsPlayerShip() then ship:Log("combat", by or "", t.name .. " geentert und übernommen") end
    else
        ship.subs.boardingCooldown = os.time() + Setting("boarding_cooldown", 120)
        if t.subs then t.subs.morale = math.min(100, (t.subs.morale or 75) + 15) end
        Naval.Event(ship, "boarding_failed", {target = t.id})
        if ship:IsPlayerShip() then ship:Log("combat", by or "", "Enterversuch auf " .. t.name .. " abgewehrt") end
        if not Test(ship) and Naval.CommsMessage then Naval.CommsMessage(t, "Die Eindringlinge sind zurückgeschlagen!", "reply") end
    end
end

local function BoardingStep(ship)
    local b = ship.subs and ship.subs.boarding
    if not b then return end
    local t = Naval.Ships[b.target or -1]
    if not t or not Docked(ship, t) then
        ship.subs.boarding = nil
        ship.subs.boardingCooldown = os.time() + Setting("boarding_cooldown", 120)
        ship.dirty = true
        if ship:IsPlayerShip() then ship:Log("combat", "", "Enterkommando abgebrochen: Verbindung verloren") end
        return
    end
    if os.time() < b.done then return end

    if b.live then
        if not b.notified then
            b.notified = true
            for _, ply in ipairs(player.GetHumans()) do
                if ply:IsAdmin() then
                    PD.Notify("[Naval] Entern von " .. t.name .. ": Ausgang festlegen (Leitstand oder pd_naval_boarding " .. ship.id .. " ok|fail)", Color(255, 200, 80), false, ply)
                end
            end
        end
        return
    end
    Resolve(ship, math.random() < b.chance)
end

Naval.BoardingStepForTest = BoardingStep

-- KI: kapitulierte feindliche Schiffe in Reichweite greifen und entern
local function BoardingAI(ship)
    if ship:IsPlayerShip() or ship.state ~= S.NORMAL or Naval.TractorHeld[ship.id] or Strength(ship) <= 0
        or (ship.flags and (ship.flags.surrendered or ship.flags.prisoner or ship.flags.aiOff)) then return end

    local tr = ship.subs and ship.subs.tractor
    if tr then
        local t = Naval.Ships[tr.target]
        tr.pull = true
        if t and not ship.subs.boarding and Naval.BoardCheck(ship, t) then Naval.Board(ship, t) end
        return
    end
    if ship.subs and ship.subs.target then return end -- im Gefecht nicht

    for _, t in pairs(Naval.Ships) do
        if t.systemId == ship.systemId and t.flags and t.flags.surrendered and not t:IsPlayerShip()
            and Naval.GetRelation(ship.factionId, t.factionId) == Naval.Relation.HOSTILE
            and Naval.TractorCheck(ship, t) then
            Naval.TractorLock(ship, t)
            return
        end
    end
end

timer.Create("PD.Naval.Boarding", 1, 0, function()
    if not Naval.SimRunning or Naval.Paused then return end
    local ok, err = xpcall(function()
        local ai = Setting("boarding_ai", 1) == 1
        for _, ship in pairs(Naval.Ships) do
            BoardingStep(ship)
            if ai then BoardingAI(ship) end
        end
    end, debug.traceback)
    if not ok then ErrorNoHalt("[Naval] Entern: " .. tostring(err) .. "\n") end
end)

concommand.Add("pd_naval_boarding", function(ply, _, args)
    if IsValid(ply) and not ply:IsAdmin() then return end
    local ship = Naval.Ships[tonumber(args[1]) or -1]
    if not ship or not (ship.subs and ship.subs.boarding) then print("[Naval] Kein Enterkommando unterwegs") return end
    Resolve(ship, args[2] == "ok", IsValid(ply) and ply:Nick() or "Konsole")
    print("[Naval] Entern entschieden: " .. (args[2] == "ok" and "Erfolg" or "abgewehrt"))
end)

--------------------------------------------------------------------------------
-- Leitstand "Traktorstrahl & Enterkommando"
--------------------------------------------------------------------------------

Naval.CombatCommands = Naval.CombatCommands or {}
Naval.CombatCommands.tractor = Naval.CombatCommands.tractor or {}
local TC = Naval.CombatCommands.tractor

local function Fail(ply, text)
    Naval.Feedback(ply, text)
end

TC.lock = function(ply, ship, args)
    local t = Naval.Ships[tonumber(args.id) or -1]
    if ship.subs.tractor then Fail(ply, "Erst den aktuellen Strahl lösen") return end
    local ok, reason = Naval.TractorLock(ship, t)
    if not ok then Fail(ply, reason) return end
    ship:Log("combat", ply:Nick(), "Traktorstrahl auf " .. t.name)
end

TC.pull = function(ply, ship, args)
    local tr = ship.subs.tractor
    if tr then tr.pull = args.on ~= false end
end

TC.release = function(ply, ship)
    if ship.subs.boarding then Fail(ply, "Enterkommando ist noch drüben") return end
    Naval.TractorRelease(ship, "gelöst von " .. ply:Nick())
end

TC.board = function(ply, ship)
    local tr = ship.subs.tractor
    local t = tr and Naval.Ships[tr.target]
    local ok, reason = Naval.Board(ship, t)
    if not ok then Fail(ply, reason) return end
    ship:Log("combat", ply:Nick(), "Enterkommando zur " .. t.name .. " entsandt")
end

TC.resolve = function(ply, ship, args)
    if not ply:IsAdmin() or not (ship.subs.boarding and ship.subs.boarding.live) then return end
    Resolve(ship, args.ok == true, ply:Nick())
end

Naval.StatusExtras = Naval.StatusExtras or {}
Naval.StatusExtras.tractor = function(ship)
    if Strength(ship) <= 0 and Naval.ClassTractor(ship:Class()) <= 0 then return nil end
    local subs = ship.subs or {}
    local range = Range(ship)
    local out = {range = math.Round(range), cooldown = math.max(0, (subs.boardingCooldown or 0) - os.time())}

    local tr = subs.tractor
    local t = tr and Naval.Ships[tr.target]
    if t then
        out.held = {id = t.id, name = t.name, dist = math.Round(V3.Dist(t.pos, ship.pos)), dock = math.Round(DockDist(ship, t)),
            pull = tr.pull or nil, docked = Docked(ship, t) or nil, shields = ShieldsUp(t) or nil, defenseless = Naval.Defenseless(t) or nil}
    end

    local b = subs.boarding
    local bt = b and Naval.Ships[b.target]
    if bt then
        local total = math.max(1, b.done - b.start)
        out.boarding = {name = bt.name, progress = math.Clamp((os.time() - b.start) / total, 0, 1),
            remaining = math.max(0, b.done - os.time()), chance = math.Round(b.chance * 100), live = b.live or nil}
    end

    -- Ziele in der Naehe
    local list = {}
    for _, o in pairs(Naval.Ships) do
        if o ~= ship and o.systemId == ship.systemId and (o.state == S.NORMAL or o.state == S.DISABLED)
            and not (o.flags and o.flags.hidden) then
            local d = V3.Dist(o.pos, ship.pos)
            if d <= math.max(range * 3, 15000) then
                local ok, reason = Naval.TractorCheck(ship, o)
                list[#list + 1] = {id = o.id, name = o.name, dist = math.Round(d), ok = ok or nil, reason = reason,
                    defenseless = Naval.Defenseless(o) or nil}
            end
        end
    end
    table.sort(list, function(a, c) return a.dist < c.dist end)
    for i = #list, 13, -1 do list[i] = nil end
    out.contacts = list
    return out
end
