AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    -- Das PermaProps-Tool setzt beim Laden das gespeicherte Modell vor Spawn.
    if not self:GetModel() or self:GetModel() == "" then
        self:SetModel(util.IsValidModel(self.Model) and self.Model or PD.Kiste.DefaultCrateModel)
    end

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
