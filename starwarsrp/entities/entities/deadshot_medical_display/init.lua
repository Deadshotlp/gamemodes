AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include('shared.lua')

function ENT:Initialize()
    self.Entity:SetModel("models/reizer_props/srsp/sci_fi/console_02_1/console_02_1.mdl")
    self.Entity:PhysicsInit(SOLID_VPHYSICS)
    self.Entity:SetMoveType(MOVETYPE_VPHYSICS)
    self.Entity:SetSolid(SOLID_VPHYSICS)

    local phys = self:GetPhysicsObject()
    self.nodupe = true
    self.ShareGravgun = true

    if phys and phys:IsValid() then
        phys:Wake()
    end
    self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE_DEBRIS)

    self:SetNW2Bool("pd_medical_display_active", false)
end

function ENT:Use(ply)
    
end

function ENT:OnRemove()
    self:Remove()
end

local time = 0
local delay = 1

function ENT:Think()
    if os.time() < (time + delay) then
        return
    end

    time = os.time()

    -- print(self:GetNW2Bool("active"))

    if not self:GetNW2Bool("pd_medical_display_active") then
        return
    end

    local ply = self:GetParent().pod:GetDriver()

    if (ply == NULL) or not (ply:IsPlayer()) then
        self:SetNW2Int("puls", -1)

        self:SetNW2Int("bp_1", -1)
        self:SetNW2Int("bp_2", -1)

        self:SetNW2Int("spo2", -1)

        return
    end

    self:SetNW2Int("puls", PD.DM:RequestTable(ply, "puls"))

    self:SetNW2Int("bp_1", PD.DM:RequestTable(ply, "bp")[1])
    self:SetNW2Int("bp_2", PD.DM:RequestTable(ply, "bp")[2])

    self:SetNW2Int("spo2", PD.DM:RequestTable(ply, "spo2"))

end
