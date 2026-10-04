--[[
    Transportkisten: grosse Objekte (z. B. Zelte) zusammenpacken, als Kiste
    transportieren (auch im Fahrzeuginventar) und wieder aufbauen.

    Was sich packen laesst, steht in der Datenbank (pd_kiste_packables) und
    wird im Web-Panel gepflegt. Neu laden: pd_reload kisten.
]]

PD.Kiste = PD.Kiste or {}

PD.Kiste.CrateClass = "pd_transportkiste"
PD.Kiste.DefaultCrateModel = "models/reizer_props/srsp/sci_fi/crate_01/crate_01.mdl"

-- Wie weit der Spieler hoechstens vom Objekt entfernt sein darf (bis zur
-- naechstgelegenen Stelle der Huelle, nicht zum Ursprung - Zelte sind gross).
PD.Kiste.Range = 150

-- Wie weit man sich waehrend des Packens bewegen darf.
PD.Kiste.MoveTolerance = 40

-- modelpfad (klein, mit /) -> {name, pack_time, crate_model}
PD.Kiste.Packables = PD.Kiste.Packables or {}

-- Sortiment des Kistenlagers: { {model, name, limit}, ... }
PD.Kiste.Spawnables = PD.Kiste.Spawnables or {}

function PD.Kiste.NormalizeModel(model)
    return string.lower(string.gsub(tostring(model or ""), "\\", "/"))
end

function PD.Kiste.GetPackable(ent)
    if not IsValid(ent) then return nil end

    return PD.Kiste.Packables[PD.Kiste.NormalizeModel(ent:GetModel())]
end

-- Darf das Entity ueberhaupt gepackt werden? (Packliste allein reicht nicht.)
function PD.Kiste.CanPackEntity(ent)
    if not IsValid(ent) then return false end
    if ent:IsPlayer() or ent:IsNPC() or ent:IsVehicle() or ent:IsRagdoll() then return false end
    if ent:GetClass() == PD.Kiste.CrateClass then return false end
    if IsValid(ent:GetParent()) then return false end

    return PD.Kiste.GetPackable(ent) ~= nil
end

--[[
    Wo und wie ein Objekt aus einer Kiste aufgebaut wuerde.

    Server (Aufbauen) und Client (Vorschau) rechnen mit genau dieser Funktion,
    damit die Vorschau zeigt, was beim Aufbauen wirklich passiert.

    info: angles, crate_yaw, mins, maxs, scale (aus den Kistendaten)
    Gibt Position, Winkel und das Ergebnis der Platzpruefung (TraceHull) zurueck.
]]
function PD.Kiste.ComputePlacement(crate, info)
    local scale = info.scale or 1
    local base = crate:GetPos() + Vector(0, 0, 20)

    local tr = util.TraceLine({
        start = base + Vector(0, 0, 10),
        endpos = base - Vector(0, 0, 500),
        filter = {crate},
        mask = MASK_SOLID_BRUSHONLY,
    })

    local ground = tr.Hit and tr.HitPos or base

    -- Drehung der Kiste seit dem Packen auf das Objekt uebertragen.
    local yaw = crate:GetAngles().y
    local ang = Angle(info.angles.p, info.angles.y + (yaw - (info.crate_yaw or yaw)), info.angles.r)

    local pos = ground - Vector(0, 0, info.mins.z * scale) + Vector(0, 0, 2)

    -- Platz pruefen: Weltgeometrie und andere Objekte (die Kiste selbst nicht).
    local hull = util.TraceHull({
        start = pos + Vector(0, 0, 4),
        endpos = pos + Vector(0, 0, 4),
        mins = info.mins * scale * 0.9,
        maxs = info.maxs * scale * 0.9,
        filter = {crate},
        mask = MASK_SOLID,
    })

    return pos, ang, hull
end
