ENT.Type = "anim"
ENT.base = "base_gmodentity"

ENT.Category = "PD - Gamemode"
ENT.PrintName = "Rüstungsstation"
ENT.Cooldown = 40
ENT.DefaultAmount = 100

ENT.Spawnable = true


function ENT:SetupDataTables()

	self:NetworkVar( "Float", 0, "Time" )
  self:NetworkVar( "Int", 0, "Amount" )
  self:NetworkVar( "Bool", 0, "LK" )

	if SERVER then
		self:SetTime( 0 )
    self:SetAmount( self.DefaultAmount )
	end

end