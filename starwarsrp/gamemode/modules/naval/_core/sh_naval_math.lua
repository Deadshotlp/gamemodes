--[[
    Naval - Mathematik in doppelter Genauigkeit.

    V3: Vektor als Lua-Tabelle {x, y, z} (doubles). GMods Vector speichert nur
        float32 - bei Systemen mit Millionen Metern reicht das nicht.
    Q:  Einheits-Quaternion {w, x, y, z} fuer Orientierungen. Euler-Winkel
        (Angle) haben bei Pitch/Roll einen Gimbal-Lock und taugen nur fuer die
        Anzeige.

    Koordinatensystem wie in Source: x = vorwaerts, y = links, z = oben.
    Ein Schiff mit Orientierung q schaut entlang Q.Forward(q).

    Selbsttest: pd_naval_selftest (laeuft auch einmal beim Laden).
]]

PD.Naval = PD.Naval or {}

local sqrt, abs, sin, cos, acos, atan2, asin, rad, deg, min, max =
    math.sqrt, math.abs, math.sin, math.cos, math.acos, math.atan2, math.asin, math.rad, math.deg, math.min, math.max

--------------------------------------------------------------------------------
-- V3
--------------------------------------------------------------------------------

local V3 = {}
PD.Naval.V3 = V3

function V3.New(x, y, z)
    return {x = x or 0, y = y or 0, z = z or 0}
end

function V3.Copy(a)
    return {x = a.x, y = a.y, z = a.z}
end

function V3.FromVector(v)
    return {x = v.x, y = v.y, z = v.z}
end

-- Nur fuer kleine, kameranahe Werte (Darstellung)!
function V3.ToVector(a)
    return Vector(a.x, a.y, a.z)
end

function V3.Add(a, b) return {x = a.x + b.x, y = a.y + b.y, z = a.z + b.z} end
function V3.Sub(a, b) return {x = a.x - b.x, y = a.y - b.y, z = a.z - b.z} end
function V3.Scale(a, s) return {x = a.x * s, y = a.y * s, z = a.z * s} end
function V3.Dot(a, b) return a.x * b.x + a.y * b.y + a.z * b.z end

function V3.Cross(a, b)
    return {
        x = a.y * b.z - a.z * b.y,
        y = a.z * b.x - a.x * b.z,
        z = a.x * b.y - a.y * b.x,
    }
end

function V3.LenSqr(a) return a.x * a.x + a.y * a.y + a.z * a.z end
function V3.Len(a) return sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end
function V3.Dist(a, b) return V3.Len(V3.Sub(a, b)) end

function V3.Normalize(a)
    local len = V3.Len(a)
    if len < 1e-12 then return {x = 1, y = 0, z = 0} end
    return {x = a.x / len, y = a.y / len, z = a.z / len}
end

function V3.Lerp(a, b, t)
    return {x = a.x + (b.x - a.x) * t, y = a.y + (b.y - a.y) * t, z = a.z + (b.z - a.z) * t}
end

-- Laenge begrenzen
function V3.Clamp(a, maxLen)
    local len = V3.Len(a)
    if len <= maxLen or len < 1e-12 then return a end
    return V3.Scale(a, maxLen / len)
end

--------------------------------------------------------------------------------
-- Q (Quaternion)
--------------------------------------------------------------------------------

local Q = {}
PD.Naval.Q = Q

function Q.Identity()
    return {w = 1, x = 0, y = 0, z = 0}
end

function Q.Copy(q)
    return {w = q.w, x = q.x, y = q.y, z = q.z}
end

function Q.Normalize(q)
    local len = sqrt(q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z)
    if len < 1e-12 then return Q.Identity() end
    return {w = q.w / len, x = q.x / len, y = q.y / len, z = q.z / len}
end

function Q.Conj(q)
    return {w = q.w, x = -q.x, y = -q.y, z = -q.z}
end

-- Hamilton-Produkt: erst b, dann a anwenden (wie Matrizen a*b).
function Q.Mul(a, b)
    return {
        w = a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z,
        x = a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
        y = a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
        z = a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
    }
end

function Q.FromAxisAngle(axis, angleRad)
    local n = V3.Normalize(axis)
    local h = angleRad * 0.5
    local s = sin(h)
    return {w = cos(h), x = n.x * s, y = n.y * s, z = n.z * s}
end

-- Vektor drehen: v' = q * v * q^-1
function Q.RotateVec(q, v)
    -- Optimierte Form: t = 2 * cross(q.xyz, v); v' = v + w*t + cross(q.xyz, t)
    local qx, qy, qz, qw = q.x, q.y, q.z, q.w
    local tx = 2 * (qy * v.z - qz * v.y)
    local ty = 2 * (qz * v.x - qx * v.z)
    local tz = 2 * (qx * v.y - qy * v.x)

    return {
        x = v.x + qw * tx + (qy * tz - qz * ty),
        y = v.y + qw * ty + (qz * tx - qx * tz),
        z = v.z + qw * tz + (qx * ty - qy * tx),
    }
end

-- Lokale Achsen eines Schiffs
function Q.Forward(q) return Q.RotateVec(q, {x = 1, y = 0, z = 0}) end
function Q.Left(q) return Q.RotateVec(q, {x = 0, y = 1, z = 0}) end
function Q.Up(q) return Q.RotateVec(q, {x = 0, y = 0, z = 1}) end

--[[
    Aus Source-Winkeln (Pitch, Yaw, Roll in Grad). Source dreht zuerst Roll um
    x, dann Pitch um y, dann Yaw um z; ein positiver Pitch neigt die Nase nach
    UNTEN - daher das Vorzeichen.
]]
function Q.FromAngle(p, y, r)
    local qYaw = Q.FromAxisAngle({x = 0, y = 0, z = 1}, rad(y))
    local qPitch = Q.FromAxisAngle({x = 0, y = 1, z = 0}, rad(p))
    local qRoll = Q.FromAxisAngle({x = 1, y = 0, z = 0}, rad(r))

    return Q.Normalize(Q.Mul(qYaw, Q.Mul(qPitch, qRoll)))
end

-- Zurueck in Source-Winkel (fuer SetAngles bei der Darstellung).
function Q.ToAngle(q)
    local f = Q.Forward(q)
    local l = Q.Left(q)
    local u = Q.Up(q)

    local pitch = deg(asin(max(-1, min(1, -f.z))))
    local yaw, roll

    if abs(f.z) < 0.99999 then
        yaw = deg(atan2(f.y, f.x))
        roll = deg(atan2(l.z, u.z))
    else
        -- Senkrecht nach oben/unten: Yaw und Roll fallen zusammen.
        yaw = deg(atan2(-l.x, l.y))
        roll = 0
    end

    return Angle(pitch, yaw, roll)
end

function Q.Dot(a, b)
    return a.w * b.w + a.x * b.x + a.y * b.y + a.z * b.z
end

function Q.Slerp(a, b, t)
    local d = Q.Dot(a, b)

    -- Kuerzeren Weg nehmen
    if d < 0 then
        b = {w = -b.w, x = -b.x, y = -b.y, z = -b.z}
        d = -d
    end

    if d > 0.9995 then
        return Q.Normalize({
            w = a.w + (b.w - a.w) * t,
            x = a.x + (b.x - a.x) * t,
            y = a.y + (b.y - a.y) * t,
            z = a.z + (b.z - a.z) * t,
        })
    end

    local theta = acos(d)
    local s = sin(theta)
    local wa = sin((1 - t) * theta) / s
    local wb = sin(t * theta) / s

    return {
        w = a.w * wa + b.w * wb,
        x = a.x * wa + b.x * wb,
        y = a.y * wa + b.y * wb,
        z = a.z * wa + b.z * wb,
    }
end

--[[
    Drehung um die Winkelgeschwindigkeit omega (rad/s, Schiffskoordinaten:
    x = Rollen, y = Nicken, z = Gieren) ueber dt Sekunden.
]]
function Q.Integrate(q, omega, dt)
    local angle = V3.Len(omega) * dt
    if angle < 1e-12 then return q end

    local step = Q.FromAxisAngle(omega, angle)
    return Q.Normalize(Q.Mul(q, step))
end

-- Winkel (Grad) zwischen zwei Richtungen
function PD.Naval.AngleBetween(a, b)
    local d = V3.Dot(V3.Normalize(a), V3.Normalize(b))
    return deg(acos(max(-1, min(1, d))))
end

--------------------------------------------------------------------------------
-- Selbsttest
--------------------------------------------------------------------------------

local function near(a, b, eps)
    return abs(a - b) <= (eps or 1e-6)
end

local function angleNear(a, b)
    local diff = (a - b + 180) % 360 - 180
    return abs(diff) < 0.01
end

function PD.Naval.MathSelfTest()
    local results = {}
    local function check(name, ok)
        results[#results + 1] = {name = name, ok = ok and true or false}
    end

    -- Identitaet
    local f = Q.Forward(Q.Identity())
    check("Identitaet vorwaerts = +x", near(f.x, 1) and near(f.y, 0) and near(f.z, 0))

    -- Yaw 90 -> vorwaerts = +y (Source: Yaw dreht nach links)
    f = Q.Forward(Q.FromAngle(0, 90, 0))
    check("Yaw 90 vorwaerts = +y", near(f.x, 0) and near(f.y, 1) and near(f.z, 0))

    -- Pitch 30 -> Nase nach unten
    f = Q.Forward(Q.FromAngle(30, 0, 0))
    check("Pitch 30 senkt die Nase", f.z < 0 and near(f.z, -0.5))

    -- Abgleich mit Angle:Forward() fuer gemischte Winkel
    local samples = {{10, 20, 30}, {-45, 135, 60}, {80, -170, -20}, {0, 0, 90}}
    for _, s in ipairs(samples) do
        local q = Q.FromAngle(s[1], s[2], s[3])
        local a = Angle(s[1], s[2], s[3])
        local qf, ql, qu = Q.Forward(q), Q.Left(q), Q.Up(q)
        local af, ar, au = a:Forward(), a:Right(), a:Up()

        check(("Achsen wie Angle %d/%d/%d"):format(s[1], s[2], s[3]),
            near(qf.x, af.x, 1e-5) and near(qf.y, af.y, 1e-5) and near(qf.z, af.z, 1e-5)
            and near(ql.x, -ar.x, 1e-5) and near(ql.y, -ar.y, 1e-5) and near(ql.z, -ar.z, 1e-5)
            and near(qu.x, au.x, 1e-5) and near(qu.y, au.y, 1e-5) and near(qu.z, au.z, 1e-5))

        local back = Q.ToAngle(q)
        check(("Rueckweg Angle %d/%d/%d"):format(s[1], s[2], s[3]),
            angleNear(back.p, s[1]) and angleNear(back.y, s[2]) and angleNear(back.r, s[3]))
    end

    -- Slerp-Endpunkte
    local qa, qb = Q.FromAngle(0, 0, 0), Q.FromAngle(0, 90, 0)
    local s0, s1 = Q.Slerp(qa, qb, 0), Q.Slerp(qa, qb, 1)
    check("Slerp t=0", near(Q.Dot(s0, qa), 1, 1e-6))
    check("Slerp t=1", near(abs(Q.Dot(s1, qb)), 1, 1e-6))

    -- Integration: 90 Grad Gieren in 1 s
    local qi = Q.Integrate(Q.Identity(), {x = 0, y = 0, z = rad(90)}, 1)
    f = Q.Forward(qi)
    check("Integrieren 90 Grad Gieren", near(f.y, 1, 1e-6))

    -- Doppelte Genauigkeit bei grossen Werten
    local big = V3.New(1e9, 0, 0)
    local moved = V3.Add(big, V3.New(0.001, 0, 0))
    check("Praezision 1 mm bei 1e9 m", near(V3.Sub(moved, big).x, 0.001, 1e-6))

    local passed = 0
    for _, r in ipairs(results) do
        if r.ok then passed = passed + 1 end
    end

    return passed, #results, results
end

local function RunSelfTest(verbose)
    local passed, total, results = PD.Naval.MathSelfTest()

    if passed == total then
        print(("[Naval] Mathe-Selbsttest: PASS (%d/%d)"):format(passed, total))
    else
        print(("[Naval] Mathe-Selbsttest: FAIL (%d/%d)"):format(passed, total))
    end

    for _, r in ipairs(results) do
        if verbose or not r.ok then
            print("  " .. (r.ok and "ok   " or "FEHL ") .. r.name)
        end
    end
end

if SERVER then
    concommand.Add("pd_naval_selftest", function(ply)
        if IsValid(ply) and not ply:IsAdmin() then return end
        RunSelfTest(true)
    end)

    -- Einmal beim Laden, damit Fehler sofort in der Konsole stehen.
    timer.Simple(1, function() RunSelfTest(false) end)
end
