AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include('shared.lua')

function ENT:Initialize()

	self:SetModel("models/lordtrilobite/starwars/isd/imp_console_medium03.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self.NextUse = CurTime()

	local phys = self:GetPhysicsObject()

	if(phys:IsValid()) then
		phys:Wake()
	end
end

