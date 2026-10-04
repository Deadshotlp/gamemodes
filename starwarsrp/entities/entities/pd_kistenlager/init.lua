AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    --[[
        Immer das Modell aus shared.lua (ENT.Model). Frueher nur, wenn noch
        keines gesetzt war - beim Spawnen aus dem Menue galt das nicht, und das
        Lager stand ohne Modell da. Perma-Props speichern ohnehin dasselbe
        Modell; ein geaendertes ENT.Model gilt so auch fuer schon gespeicherte
        Lager.

        Fehlt das Modell auf dem Server (z. B. CS:S-Modelle, CS:S ist hier
        nicht gemountet), gibt es die Standardkiste und eine Warnung.
    ]]
    local model = self.Model

    if not util.IsValidModel(model) then
        print("[Kistenlager] Modell " .. tostring(model) .. " fehlt auf dem Server - nehme Standardkiste")
        model = PD.Kiste and PD.Kiste.DefaultCrateModel or "models/props_junk/wood_crate002a.mdl"
    end

    self:SetModel(model)

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    -- Ein Lager steht fest.
    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    if PD.Kiste and PD.Kiste.OpenSpawner then
        PD.Kiste.OpenSpawner(activator, self)
    end
end
