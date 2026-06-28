AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")

include("shared.lua")

util.AddNetworkString("PD.Armor:GiveArmorEnt")

local Table = {}
Table["helm"] = 100
Table["panzer"] = 100
Table["beine"] = 100

function ENT:Initialize()
    self:SetModel("models/reizer_props/srsp/sci_fi/armory_02_2/armory_02_2.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType(SIMPLE_USE)

    local phys = self:GetPhysicsObject()

    if phys:IsValid() then
        phys:Wake()
    end
end

function ENT:Use(activator)
end

function ENT:Think()
    return true
end

net.Receive("PD.Armor:GiveArmorEnt", function(len, ply)
    local typ = net.ReadInt(8)

    if typ == 1 then
        -- if Table["panzer"] <= 0 then return end

        Table["panzer"] = Table["panzer"] - 1

        ply:SetBodygroup(1, 0)
        ply:PDSetArmor("panzer", 100)
    elseif typ == 2 then
        -- if Table["beine"] <= 0 then return end

        Table["beine"] = Table["beine"] - 1

        ply:SetBodygroup(2, 0)
        ply:PDSetArmor("beine", 100)
    elseif typ == 3 then
        -- if Table["helm"] <= 0 then return end

        Table["helm"] = Table["helm"] - 1

        ply:SetBodygroup(3, 0)
        ply:PDSetArmor("helm", 100)
    end
end)
