AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

function ENT:Initialize()
    self:SetModel(self.Model)
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local kind = self:GetKind()

    if kind then
        self:SetColor(kind.color)
        self:SetStock(kind.stock)
    end

    self:SetRefillAt(0)

    local phys = self:GetPhysicsObject()
    if IsValid(phys) then
        phys:Wake()
    end
end

function ENT:Use(activator)
    if PD.WB and PD.WB.UseAmmoBox then
        PD.WB.UseAmmoBox(self, activator)
    end
end

-- Leere Kiste nach Ablauf der Wartezeit wieder auffuellen.
function ENT:Think()
    local refill = self:GetRefillAt()

    if self:GetStock() <= 0 and refill > 0 and CurTime() >= refill then
        local kind = self:GetKind()

        self:SetStock(kind and kind.stock or 0)
        self:SetRefillAt(0)
    end

    self:NextThink(CurTime() + 1)
    return true
end
