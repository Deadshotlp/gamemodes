--[[
    Naval - Asteroidenfelder und Nebel: Geometrie (Server und Client, Stufe 4e).

    Feld = {id, kind, name, pos = {x, y, z} (system-lokal, m), radius,
            width, thickness (nur Guertel), density, color = {r, g, b}}
      belt     Asteroidenguertel: Ring um pos (Stern) mit Bahnradius radius,
               Breite width, Dicke thickness
      cluster  Asteroidenfeld: Kugel
      nebula   Nebel: Kugel
    Erzeugt und verschickt werden die Felder vom Server (sv_naval_fields.lua,
    im System-Paket: C.system.fields).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval

Naval.FieldKinds = {belt = "Asteroidengürtel", cluster = "Asteroidenfeld", nebula = "Nebel"}

function Naval.IsAsteroidField(f)
    return f and (f.kind == "belt" or f.kind == "cluster")
end

-- Abstand zum Feldrand: < 0 = drin (Tiefe), > 0 = draussen
function Naval.FieldDepth(f, p)
    local c = f.pos or {x = 0, y = 0, z = 0}
    local dx, dy, dz = p.x - c.x, p.y - c.y, (p.z or 0) - (c.z or 0)

    if f.kind == "belt" then
        local radial = math.abs(math.sqrt(dx * dx + dy * dy) - f.radius) - (f.width or 0) * 0.5
        local vertical = math.abs(dz) - (f.thickness or 0) * 0.5
        return math.max(radial, vertical)
    end

    return math.sqrt(dx * dx + dy * dy + dz * dz) - (f.radius or 0)
end

-- Feld an einer Stelle (das tiefste; Nebel und Asteroiden getrennt filterbar)
function Naval.FieldAt(fields, p, filter)
    local best, bestDepth
    for _, f in ipairs(fields or {}) do
        if not filter or filter(f) then
            local d = Naval.FieldDepth(f, p)
            if d <= 0 and (not bestDepth or d < bestDepth) then best, bestDepth = f, d end
        end
    end
    return best, bestDepth
end
