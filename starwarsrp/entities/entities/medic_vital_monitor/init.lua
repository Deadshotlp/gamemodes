AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include('shared.lua')

function ENT:Initialize()
    self:SetModel("models/reizer_props/alysseum_project/medicine_obj/med_monitor_01/med_monitor_01.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)

    local phys = self:GetPhysicsObject()
    self.nodupe = true
    self.ShareGravgun = true

    if phys and phys:IsValid() then
        phys:Wake()
    end
    self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE_DEBRIS)

end

function ENT:SpawnFunction(ply, tr)
    if not tr.Hit then
        return
    end

    local SpawnPos = tr.HitPos + tr.HitNormal * 40

    local ent = ents.Create("medic_vital_monitor")
    ent:SetPos(SpawnPos)
    ent:Spawn()
    ent:Activate()

    return ent
end

function ENT:Use(ply)
    -- Use-Funktionalität hier hinzufügen, falls benötigt
end

function ENT:OnRemove()
    self:Remove()
end
