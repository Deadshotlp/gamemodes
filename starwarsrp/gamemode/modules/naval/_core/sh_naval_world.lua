--[[
    Naval - Zeit und Positionen der Himmelskoerper (Server und Client).

    Naval.Now(): Sekunden, an der Wanduhr (os.time) ausgerichtet, aber stetig
    (SysTime). Gespeicherte Zeitpunkte (Hyperraum-Ankunft) ueberstehen so
    einen Neustart. Der Client gleicht seine Uhr mit jedem Snapshot an.

    Koerper-Positionen sind system-lokal in Metern und werden aus den
    Bahndaten berechnet (Server und Client identisch, nichts zu senden).
    Bahnperiode 0 = Koerper steht still (Standard fuer RP-Ruhe).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3 = Naval.V3

Naval.TimeBase = Naval.TimeBase or os.time()
Naval.SysBase = Naval.SysBase or SysTime()
Naval.ClockOffset = Naval.ClockOffset or 0

function Naval.Now()
    return Naval.TimeBase + (SysTime() - Naval.SysBase) + Naval.ClockOffset
end

-- Position eines Koerpers (rekursiv ueber den Elternkoerper), system-lokal.
function Naval.BodyPos(body, bodies, now, depth)
    depth = depth or 0
    if not body or depth > 4 then return V3.New() end

    local origin = V3.New()

    if body.parentId and body.parentId ~= "" then
        local parent = bodies[body.parentId]
        if parent then origin = Naval.BodyPos(parent, bodies, now, depth + 1) end
    end

    local orbit = body.orbit
    if not orbit or (orbit.radius or 0) <= 0 then return origin end

    local angle = math.rad(orbit.phase or 0)
    if (orbit.period or 0) > 0 then
        angle = angle + (now or Naval.Now()) / orbit.period * math.pi * 2
    end

    local incl = math.rad(orbit.incl or 0)
    local r = orbit.radius

    return V3.Add(origin, {
        x = math.cos(angle) * r,
        y = math.sin(angle) * r * math.cos(incl),
        z = math.sin(angle) * r * math.sin(incl),
    })
end

-- Hauptplanet eines Systems (der erste Planet, sonst der Stern)
function Naval.MainBody(bodiesOfSystem)
    local star

    for _, b in ipairs(bodiesOfSystem or {}) do
        if b.type == "planet" then return b end
        if b.type == "star" and not star then star = b end
    end

    return star
end

-- Galaktische Entfernung zweier Systeme (Parsec)
function Naval.SystemDistance(a, b)
    if not a or not b then return 0 end
    return V3.Len(V3.Sub(a.g, b.g))
end

-- Liegen beide Systeme auf derselben Hyperraumroute?
function Naval.SharedRoute(a, b)
    if not a or not b or not istable(a.routes) or not istable(b.routes) then return nil end

    for _, ra in ipairs(a.routes) do
        for _, rb in ipairs(b.routes) do
            if ra == rb then return ra end
        end
    end
end

-- Sprungdauer in Sekunden (Einstellungen aus pd_naval_settings)
function Naval.JumpDuration(fromSystem, toSystem, rating, settings)
    settings = settings or Naval.Settings or {}

    -- Server: Weg entlang der Hyperraumrouten (effektive Parsec)
    local plan = Naval.PlanJump and Naval.PlanJump(fromSystem, toSystem)
    local dist = plan and plan.cost or Naval.SystemDistance(fromSystem, toSystem)
    local t = (settings.hyper_base_time or 45) + dist * (settings.hyper_time_per_gu or 0.0085)

    if not plan and Naval.SharedRoute(fromSystem, toSystem) then
        t = t * (settings.route_speed_factor or 0.5)
    end

    t = t / math.max(rating or 1, 0.1)

    return math.Clamp(t, settings.hyper_base_time or 45, settings.hyper_max_time or 300)
end
