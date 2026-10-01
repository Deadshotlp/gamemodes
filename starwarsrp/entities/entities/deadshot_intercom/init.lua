AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include('shared.lua')

-- Der Sprachfilter liegt in gamemode/modules/voice_effect (PD.VoiceFX).
-- Hier wird nur der Intercom-Status gesetzt.

local USE_RANGE = 150

local function SetIntercom(ply, state)
    if not IsValid(ply) then return end

    ply.UsingIntercom = state or nil
    ply:SetNW2Bool("PD.Comlink.Using", state)

    if PD.VoiceFX then PD.VoiceFX.Refresh(ply) end
end

function ENT:Initialize()
    self.Entity:SetModel("models/lordtrilobite/starwars/isd/imp_console_medium03.mdl")
    self.Entity:PhysicsInit(SOLID_VPHYSICS)
    self.Entity:SetMoveType(MOVETYPE_VPHYSICS)
    self.Entity:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self.Entity:GetPhysicsObject()
    self.nodupe = true
    self.ShareGravgun = true
    self.Users = {}

    if phys and phys:IsValid() then
        phys:Wake()
    end
    self:SetCollisionGroup(COLLISION_GROUP_INTERACTIVE_DEBRIS)
end

function ENT:Use(ply)
    if not IsValid(ply) or not ply:IsPlayer() then return end

    local active = not ply.UsingIntercom

    SetIntercom(ply, active)
    self.Users[ply] = active or nil

    ply:EmitSound(active and "buttons/button14.wav" or "buttons/button15.wav", 60, 100, 0.6)
end

-- Sicherheitsnetz: Intercom abschalten, wenn der Nutzer weglaeuft oder stirbt.
-- Sonst bliebe er dauerhaft fuer den ganzen Server hoerbar.
function ENT:Think()
    if not table.IsEmpty(self.Users) then
        for ply in pairs(self.Users) do
            if not IsValid(ply) or not ply:Alive() or ply:GetPos():DistToSqr(self:GetPos()) > USE_RANGE * USE_RANGE then
                self.Users[ply] = nil
                SetIntercom(ply, false)
            end
        end
    end

    self:NextThink(CurTime() + 0.5)
    return true
end

function ENT:OnRemove()
    for ply in pairs(self.Users or {}) do
        SetIntercom(ply, false)
    end
end

hook.Add("PlayerDisconnected", "PD.Intercom.Cleanup", function(ply)
    ply.UsingIntercom = nil
end)
