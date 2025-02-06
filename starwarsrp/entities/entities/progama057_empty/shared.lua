ENT.Type = "anim"
ENT.Base = "base_gmodentity"

ENT.PrintName = "Reaktor Empty Tank"
ENT.Category = "Progama057"

ENT.Spawnable = true
ENT.AdminSpawnable = true

ENT.Default = 0
function ENT:SetupDataTables()
    self:NetworkVar( "Int", 0, "empty" )
    self:NetworkVar( "String", 0, "PName" )
	if SERVER then
        -- self:SetFuel( self.Default )
        self:SetPName( "Empty" )
	end
end