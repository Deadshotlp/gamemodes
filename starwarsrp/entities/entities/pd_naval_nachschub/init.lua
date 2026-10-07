AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    local model = self.Model
    if not util.IsValidModel(model) then model = "models/props_junk/wood_crate001a.mdl" end
    self:SetModel(model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local def = self:KindDef()
    if def and def.color then self:SetColor(def.color) end

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then phys:Wake() end
end
