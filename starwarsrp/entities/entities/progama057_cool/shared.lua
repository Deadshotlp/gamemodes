ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Reaktor Cool Tank"
ENT.Category = "Progama057"

ENT.Spawnable = true
ENT.AdminSpawnable = true

ENT.DefaultCool = 50000
function ENT:SetupDataTables()
    self:NetworkVar( "Int", 0, "Cool" )
    self:NetworkVar( "String", 0, "PName" )

	if SERVER then
        self:SetCool( self.DefaultCool )
        self:SetPName( "Cool" )
	end
end

