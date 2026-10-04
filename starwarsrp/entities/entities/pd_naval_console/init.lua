AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    local def = self:StationDef()
    local model = def and def.model or "models/lordtrilobite/starwars/isd/imp_console_medium03.mdl"
    if not util.IsValidModel(model) then model = "models/props_lab/workspace003.mdl" end

    self:SetModel(model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:EnableMotion(false) end
end

function ENT:Use(activator)
    if not IsValid(activator) or not activator:IsPlayer() then return end

    if PD.Naval and PD.Naval.OpenStation then
        PD.Naval.OpenStation(activator, self)
    end
end
