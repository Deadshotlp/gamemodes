AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )

include( "shared.lua" )


function ENT:Initialize()
    self:SetModel("models/reizer_props/srsp/sci_fi/crate_01/crate_01.mdl")
    self:PhysicsInit(SOLID_VPHYSICS)
    self:SetMoveType(MOVETYPE_VPHYSICS)
    self:SetSolid(SOLID_VPHYSICS)
    self:SetUseType( SIMPLE_USE )

    

    local phys = self:GetPhysicsObject()

    if phys:IsValid() then
      phys:Wake()
    end

end

function ENT:Use(activator)
  if self:GetAmount() == 0 then activator:SendLua("chat.AddText(Color(255,0,0), '[SYSTEM] ', Color(255,255,255), 'Die Munitionskiste ist leer!')") return end

  self:EmitSound("items/ammo_pickup.wav", 75, 100, 1)
  self:SetAmount(math.Clamp(self:GetAmount()-1, 0, self.DefaultAmount))
  
  if self:GetAmount() == 0 then self:SetTime(CurTime() + self.Cooldown) self:SetLK(true) end

			wep = activator:GetActiveWeapon()
			if wep then
				activator:GiveAmmo(100, wep:GetPrimaryAmmoType())
				activator:GiveAmmo(100, wep:GetSecondaryAmmoType())
			end

end

function ENT:Think()
  if self:GetLK() then
    if self:GetTime() < CurTime() then 
      self:SetAmount(self.DefaultAmount)
      self:SetLK(true)
    end
  end
  self:NextThink(CurTime()+1)
  return true
end
