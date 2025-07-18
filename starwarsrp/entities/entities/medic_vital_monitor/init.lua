AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include('shared.lua')

function ENT:Initialize()
    self.Entity:SetModel("models/reizer_props/alysseum_project/medicine_obj/med_monitor_01/med_monitor_01.mdl")
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
    if self:GetNW2Bool("active", false) then
        self:SetNW2Bool("active", false)
        print("Deactivated")
    else
        self:SetNW2Bool("active", true)
        print("Activated")
    end

    -- Use-Funktionalität hier hinzufügen, falls benötigt
end

function ENT:OnRemove()
    self:Remove()
end

local time = 0
local delay = 1

local tbl = {
    [1] = {"head", false, false},
    [2] = {"torso", false, false},
    [3] = {"belly", false, false},
    [4] = {"arm_l", false, false},
    [5] = {"arm_r", false, false},
    [6] = {"leg_l", false, false},
    [7] = {"leg_r", false, false},
}

function ENT:Think()
    if not self:GetNW2Bool("active", false) or (self.LinkedEnt == nil) then
        return
    end

    if os.time() < (time + delay) then
        return
    end

    time = os.time()

    local ply = self.LinkedEnt.pod:GetDriver()

    if (ply == NULL) or not (ply:IsPlayer()) then
        self:SetNW2Int("puls", -1)

        self:SetNW2Int("bp_1", -1)
        self:SetNW2Int("bp_2", -1)

        self:SetNW2Int("spo2", -1)

        for k, v in ipairs(tbl) do
            if v[2] == -1 then
                self:SetNW2Int(k, -1)
            else
                tbl[k] = {v[1], false, false}
            end
        end

        return
    end

    self:SetNW2Int("puls", PD.DM:RequestTable(ply, "puls"))

    self:SetNW2Int("bp_1", PD.DM:RequestTable(ply, "bp")[1])
    self:SetNW2Int("bp_2", PD.DM:RequestTable(ply, "bp")[2])

    self:SetNW2Int("spo2", PD.DM:RequestTable(ply, "spo2"))

    --legende: 0 = nichts, 1 = Verletzt,2 = Gebrochen,3 = Verletzt und Gebrochen

    for _, v in ipairs(PD.DM:RequestTable(ply, "body_part")) do
        if v.fractured == true then
            tbl[_][3] = true
        end
    end

    for _, v in ipairs(PD.DM:RequestTable(ply, "injureys")) do
        tbl[v.wo][2] = true
    end

    for k, v in ipairs(tbl) do
        if v[2] and v[3] then
            self:SetNW2Int(k, 3)
        elseif v[2] == true then
            self:SetNW2Int(k, 1)
        elseif v[3] == true then
            self:SetNW2Int(k, 2)
        else
            self:SetNW2Int(k, -1)
        end
    end
end
