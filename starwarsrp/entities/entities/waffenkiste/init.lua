AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include('shared.lua')

util.AddNetworkString("WaffenkisteReparieren")

net.Receive("WaffenkisteReparieren", function(len, ply)
	if GetGlobal2Bool("WaffenkisteKaputt") then
		ENT:SetHealth(100)
		SetGlobal2Bool("WaffenkisteKaputt", false)
		ENT:SetBodygroup(1, 0)
		ply:ChatPrint("Die Waffenkiste wurde repariert!")
	else
		ply:ChatPrint("Die Waffenkiste ist nicht kaputt!")
	end
end)

function ENT:Initialize()

	self:SetModel("models/reizer_props/srsp/sci_fi/armory_02/armory_02.mdl")
	self:PhysicsInit(SOLID_VPHYSICS)
	self:SetMoveType(MOVETYPE_VPHYSICS)
	self:SetSolid(SOLID_VPHYSICS)
	self:SetUseType(SIMPLE_USE)
	self.NextUse = CurTime()

	self:SetHealth(100)
	self:SetMaxHealth(100)
end

function ENT:AcceptInput( Name, Activator, ply )
	self:SetHealth(100)
	SetGlobal2Bool("WaffenkisteKaputt", false)
	self:SetBodygroup(1, 0)
end

function ENT:OnTakeDamage(dmg)
	if self:Health() <= 0 then return end

	self:SetHealth(self:Health() - dmg:GetDamage())

	if self:Health() <= 0 then
		self:Kaputt()
	end
end

function ENT:Kaputt()
	self:EmitSound("ambient/explosions/explode_" .. math.random(1, 4) .. ".wav", SNDLVL_NONE, 100, 1, CHAN_AUTO, SND_STOP_LOOPING)
	SetGlobal2Bool("WaffenkisteKaputt", true)
end

function ENT:Repair(bool)
	if bool then
		SetGlobal2Bool("WaffenkisteKaputt", false)
		self:SetBodygroup(1, 0)
	end
end

function ENT:Think()
	if self:Health() <= 0 then
		--self:EmitSound("physics/metal/metal_box_break"..math.random(1, 2)..".wav")

		self:SetBodygroup(1, 1)
	-- elseif self:Health() == self:GetMaxHealth() then
	-- 	self:SetBodygroup(1, 0)
	-- 	SetGlobal2Bool("WaffenkisteKaputt", false)
	end
end

