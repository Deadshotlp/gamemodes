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
