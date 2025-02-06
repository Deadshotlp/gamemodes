AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include('shared.lua')

function ENT:Initialize()
    self:SetModel("models/reizer_props/alysseum_project/medicine_obj/med_sofa_01/med_sofa_01.mdl")
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

    self.pod = ents.Create("prop_vehicle_prisoner_pod")
    self.pod:SetParent(self)
    self.pod:SetPos(self:GetPos() + (self:GetUp() * 45) + (self:GetForward() * 30))
    local podAng = self:GetAngles()
    podAng:RotateAroundAxis(self:GetRight(), 90)
    self.pod:SetAngles(podAng)
    self.pod:SetModel("models/vehicles/prisoner_pod_inner.mdl")
    self.pod:SetKeyValue("vehiclescript", "scripts/vehicles/prisoner_pod.txt")
    self.pod:Spawn()
    self.pod:Activate()
    self.pod:SetVehicleClass("Pod")

    self.pod:SetColor(Color(0, 0, 0, 0))
    self.pod:SetRenderMode(RENDERMODE_TRANSALPHA)
end

function ENT:SpawnFunction(ply, tr)
    if not tr.Hit then
        return
    end

    local SpawnPos = tr.HitPos + tr.HitNormal * 40

    local ent = ents.Create("medic_mrt")
    ent:SetPos(SpawnPos)
    ent:Spawn()
    ent:Activate()

    return ent
end

function ENT:Use(ply)
    if not (self.pod:GetDriver() == NULL) then
        return
    end -- Someone is already in it

    ply:EnterVehicle(self.pod)
    return
end

function ENT:OnRemove()
    self:Remove()
end
