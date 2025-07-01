AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include('shared.lua')

util.AddNetworkString("ShowBodygroups")

function ENT:Initialize()
    self.Entity:SetModel("models/reizer_props/srsp/sci_fi/armory_02_2/armory_02_2.mdl")
    self.Entity:PhysicsInit(SOLID_VPHYSICS)
    self.Entity:SetMoveType(MOVETYPE_VPHYSICS)
    self.Entity:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self.Entity:GetPhysicsObject()
    self.nodupe = true
    self.ShareGravgun = true

    if phys and phys:IsValid() then
        phys:Wake()
    end
    self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE_DEBRIS)
end

function ENT:Use(ply)
    net.Start("ShowBodygroups")
    net.Send(ply)
end
