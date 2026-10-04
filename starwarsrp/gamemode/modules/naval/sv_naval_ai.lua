--[[
    Naval - KI und Befehle (Server, 2 Hz).

    Befehle stehen in ship.orders.queue, der erste ist aktiv. Format ueberall
    gleich (Admin-Werkzeug, Konsolenbefehle, spaeter Kommunikation):
      {type = "hold"}
      {type = "move", pos = V3}                 Position im System anfliegen
      {type = "move", bodyId = id, alt = m}     Koerper anfliegen (Abstand alt)
      {type = "patrol", points = {V3...}, loop = true}
      {type = "orbit", bodyId = id, radius = m}
      {type = "jump", systemId = id}            ausrichten und springen
    Ab Stufe 2/3: attack, defend, follow, formation, flee, surrender.

    Das Map-Schiff steuern die Spieler - die KI laesst es aus.
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3, Q = Naval.V3, Naval.Q
local S = Naval.State

function Naval.SetOrders(ship, orders, issuedBy)
    ship.orders = {queue = {}}

    for _, order in ipairs(orders or {}) do
        order.issuedBy = order.issuedBy or issuedBy
        order.t = order.t or os.time()
        table.insert(ship.orders.queue, order)
    end

    ship.ctrl.autopilot = nil
    ship.dirty = true
end

function Naval.AddOrder(ship, order, issuedBy)
    order.issuedBy = order.issuedBy or issuedBy
    order.t = order.t or os.time()
    table.insert(ship.orders.queue, order)
    ship.dirty = true
end

local function PopOrder(ship)
    local done = table.remove(ship.orders.queue, 1)
    ship.ctrl.autopilot = nil
    ship.ctrl.throttle = 0
    ship.dirty = true
    return done
end

-- Zielpunkt eines Bewegungsbefehls
local function OrderTarget(ship, order)
    if order.pos then return order.pos end

    local body = order.bodyId and Naval.Bodies[order.bodyId]
    if body then
        local center = Naval.BodyPos(body, Naval.Bodies)
        local alt = order.alt or body.radius * 3
        local away = V3.Sub(ship.pos, center)
        if V3.LenSqr(away) < 1 then away = {x = 1, y = 0, z = 0} end

        return V3.Add(center, V3.Scale(V3.Normalize(away), body.radius + alt))
    end
end

-- Fliegt auf target zu, bremst rechtzeitig. Gibt true zurueck, wenn da.
local function FlyTo(ship, target, tolerance)
    local toTarget = V3.Sub(target, ship.pos)
    local dist = V3.Len(toTarget)
    local speed = ship:Speed()
    local class = ship:Class() or {}
    tolerance = tolerance or ((class.lengthM or 300) * 3 + 1000)

    if dist <= tolerance then
        ship.ctrl.throttle = 0
        ship.ctrl.autopilot = nil
        return speed < 50
    end

    ship.ctrl.autopilot = {dir = toTarget}

    local _, _, _, err = Naval.FaceRates(ship, toTarget)
    local maxSpeed = math.max(ship:Stat("maxSpeed"), 1)
    local decel = math.max(ship:Stat("decel"), 1)
    local brake = speed * speed / (2 * decel)

    -- Erst grob ausrichten, dann Schub; vor dem Ziel abbremsen.
    local throttle = err > 25 and 0.1 or 1
    if dist < brake * 1.3 then
        throttle = math.Clamp(math.sqrt(2 * decel * dist) / maxSpeed * 0.8, 0.02, 1)
    end

    ship.ctrl.throttle = throttle
    return false
end

local Handlers = {}
Naval.AIHandlers = Handlers

Handlers.hold = function(ship)
    ship.ctrl.throttle = 0
    ship.ctrl.autopilot = nil
    return false -- haelt bis zum naechsten Befehl
end

Handlers.move = function(ship, order)
    local target = OrderTarget(ship, order)
    if not target then return true end

    return FlyTo(ship, target)
end

Handlers.patrol = function(ship, order)
    local points = order.points or {}
    if #points == 0 then return true end

    order.index = order.index or 1
    local target = points[order.index]

    if FlyTo(ship, target, ((ship:Class() or {}).lengthM or 300) * 5 + 3000) then
        order.index = order.index + 1

        if order.index > #points then
            if order.loop == false then return true end
            order.index = 1
        end

        ship.dirty = true
    end

    return false
end

Handlers.orbit = function(ship, order)
    local body = order.bodyId and Naval.Bodies[order.bodyId]
    if not body then return true end

    local center = Naval.BodyPos(body, Naval.Bodies)
    local radius = order.radius or (body.radius * 4)
    local rel = V3.Sub(ship.pos, center)
    rel.z = 0
    if V3.LenSqr(rel) < 1 then rel = {x = radius, y = 0, z = 0} end

    -- Zielpunkt 20 Grad weiter auf der Kreisbahn
    local angle = math.atan2(rel.y, rel.x) + math.rad(20)
    local target = V3.Add(center, {x = math.cos(angle) * radius, y = math.sin(angle) * radius, z = 0})

    FlyTo(ship, target, 1)
    ship.ctrl.throttle = math.min(ship.ctrl.throttle, 0.4)

    return false
end

Handlers.jump = function(ship, order)
    if ship.state ~= S.NORMAL then
        -- Laufender Sprung: fertig, sobald angekommen
        return ship.systemId == order.systemId and ship.state == S.NORMAL
    end

    if ship.systemId == order.systemId then return true end

    local from, to = Naval.Systems[ship.systemId], Naval.Systems[order.systemId]
    if not from or not to then return true end

    -- Aus dem Massenschatten heraus
    local body, _, limit = Naval.MassShadow(ship)
    if body then
        local center = Naval.BodyPos(body, Naval.Bodies)
        local away = V3.Normalize(V3.Sub(ship.pos, center))
        FlyTo(ship, V3.Add(center, V3.Scale(away, limit * 1.2)), 1)
        return false
    end

    -- Ausrichten, dann springen
    ship.ctrl.throttle = 0.2
    ship.ctrl.autopilot = {dir = Naval.JumpVector(from, to)}

    if Naval.AlignmentError(ship, order.systemId) <= (Naval.Settings.jump_align_tolerance or 2) * 0.8 then
        Naval.StartJump(ship, order.systemId, order.issuedBy or "KI", {arriveNear = order.arriveNear})
    end

    return false
end

function Naval.AITick()
    for _, ship in pairs(Naval.Ships) do
        if ship:IsPlayerShip() or (ship.flags and ship.flags.aiOff) then continue end

        local state = ship.state
        if state == S.DESTROYED or state == S.DISABLED then continue end

        local queue = ship.orders and ship.orders.queue
        local order = queue and queue[1]

        if not order then
            -- Ohne Befehl: anhalten (Hyperraum laeuft weiter)
            if state == S.NORMAL then
                ship.ctrl.throttle = 0
                ship.ctrl.autopilot = nil
            end
            continue
        end

        local handler = Handlers[order.type]
        if not handler then
            PopOrder(ship)
            continue
        end

        if handler(ship, order) then
            PopOrder(ship)
        end
    end
end
