ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Reaktor Fuel Tank"
ENT.Category = "Progama057"

ENT.Spawnable = true
ENT.AdminSpawnable = true

ENT.Defaultfuel = 50000
function ENT:SetupDataTables()
    self:NetworkVar( "Int", 0, "Fuel" )
    self:NetworkVar( "String", 0, "PName" )
	if SERVER then
        self:SetFuel( self.Defaultfuel )
        self:SetPName( "Fuel" )
	end
end