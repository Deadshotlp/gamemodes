include("shared.lua")

-- Konsolen ohne Beschriftung; bedient wird mit E. Unsichtbare Ortsmarker
-- (Hologramm-Projektor, Schadenspunkte) sehen nur Admins mit Physgun oder
-- Toolgun in der Hand, damit sie sie finden und versetzen koennen.
local function AdminPlacing()
    local ply = LocalPlayer()
    if not IsValid(ply) or not ply:IsAdmin() then return false end

    local wep = ply:GetActiveWeapon()
    return IsValid(wep) and (wep:GetClass() == "weapon_physgun" or wep:GetClass() == "gmod_tool")
end

function ENT:Draw()
    local def = self:StationDef()
    if def and def.marker then
        if AdminPlacing() then
            render.SetColorModulation(1, 0.45, 0.2)
            self:DrawModel()
            render.SetColorModulation(1, 1, 1)
        end
        return
    end

    self:DrawModel()
end
