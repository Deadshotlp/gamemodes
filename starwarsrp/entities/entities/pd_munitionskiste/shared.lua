--[[
    Basis der Munitionskisten je Munitionsart. Spawnbar sind nur die
    abgeleiteten Kisten (pd_munitionskiste_<art>), die ENT.AmmoKind setzen.
    Was eine Art ausgibt, steht in gamemode/modules/waffenkiste/sh_munition.lua.
]]

ENT.Type = "anim"
ENT.Base = "base_gmodentity"
ENT.PrintName = "Munitionskiste (Basis)"
ENT.Author = "PD"
ENT.Category = "PD - Gamemode"
ENT.Spawnable = false

ENT.AmmoKind = "blaster"
ENT.Model = "models/reizer_props/srsp/sci_fi/crate_01/crate_01.mdl"

function ENT:SetupDataTables()
    self:NetworkVar("Int", 0, "Stock")
    self:NetworkVar("Float", 0, "RefillAt")
end

function ENT:GetKind()
    return PD and PD.WB and PD.WB.AmmoKinds and PD.WB.AmmoKinds[self.AmmoKind]
end
