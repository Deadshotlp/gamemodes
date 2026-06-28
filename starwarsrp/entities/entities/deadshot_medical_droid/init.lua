AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include('shared.lua')

function ENT:Initialize()
    self.Entity:SetModel("models/props/starwars/medical/health_droid.mdl")
    self.Entity:PhysicsInit(SOLID_VPHYSICS)
    self.Entity:SetMoveType(MOVETYPE_VPHYSICS)
    self.Entity:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()
    self.nodupe = true
    self.ShareGravgun = true

    if phys and phys:IsValid() then
        phys:Wake()
    end
    self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE_DEBRIS)

end

function ENT:Use(ply)
    for _, ent in ipairs(ents.GetAll()) do
        if ent == self then continue end

        if not ent:IsValid() then continue end

        if not ent:IsPlayer() or not ent:GetClass() == "prop_ragdoll" then continue 
        elseif ent:GetClass() == "prop_ragdoll" then ent = ent:GetNW2Entity("PD.DM.RagdollOwner")
        end

        if ent:GetPos():Distance(self:GetPos()) <= 500 then
            print("Found Entity: " .. ent:GetClass())

            local respiratory_system = {
                lungs_functional = true,
                airway_clear = true,
                breathing_rate = 15,
            }

            PD.DM:UpdateTable(ent, "injuries", {})
            PD.DM:UpdateTable(ent, "blood_amount", 5.5)
            PD.DM:UpdateTable(ent, "puls", 75)
            PD.DM:UpdateTable(ent, "pain_level", 0)
            PD.DM:UpdateTable(ent, "stunning_level", 0)
            PD.DM:UpdateTable(ent, "respiratory_system", respiratory_system)
        end
    end
end

function ENT:OnRemove()
    self:Remove()
end