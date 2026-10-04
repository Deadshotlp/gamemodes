AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:Initialize()
    if not self:GetModel() or self:GetModel() == "" then
        self:SetModel(self.DefaultModel)
    end

    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end
end

-- Kisten ohne Inhalt (z. B. von Hand gespawnt) kennt das Auspacken nicht.
function ENT:HasContent()
    return istable(self.PD_Packed)
end
