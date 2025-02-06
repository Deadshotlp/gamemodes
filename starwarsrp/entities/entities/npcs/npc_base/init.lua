AddCSLuaFile( "shared.lua" )
include( 'shared.lua' )

ENT.ClassToUse = ""
ENT.Model = ""
ENT.WeaponProficiency = WEAPON_PROFICIENCY_POOR
ENT.IdleChatter = ""
ENT.CombatChatter = ""
ENT.ReinforceChatter = ""
ENT.NadeThrowCall = ""
ENT.PainChatter = ""
ENT.GotAKillChatter = ""
ENT.PanicChatter = ""
ENT.DeathSound = ""
ENT.Hitpoints = 0
ENT.RocketUser = false
ENT.WeaponOverideIgnore = false
ENT.GrenadeCount = 0
ENT.HasWeaponSwap = false
ENT.ReinforcementTimer = 0
ENT.MinEngagementRange = 0
ENT.MaxEngagementRange = 0
ENT.PrimaryWeapon = ""
ENT.SecondaryWeapon = ""
ENT.CanSpawnReinforcements = false
ENT.HasJetpack = false
ENT.AdvancedDodges = false
ENT.CanDodge = false
ENT.HasPersonalCustomization = false
ENT.EliteMovement = false
ENT.Spotter = false
ENT.CheckToSwapWeapon = 0
ENT.TimeTillReinforcements = 0
ENT.TalkTimer = 0
ENT.MiscellaneousTimer = 0
ENT.JetPackRecharge = 0
ENT.DefaultWeaponLoadout = {}

function ENT:SpawnFunction( ply, tr, ClassName )
if ( !tr.Hit ) then return end

local SpawnPos = tr.HitPos + tr.HitNormal * 16
self.Spawn_angles = ply:GetAngles()
self.Spawn_angles.pitch = 0
self.Spawn_angles.roll = 0
self.Spawn_angles.yaw = self.Spawn_angles.yaw + 180

local ent = ents.Create( ClassName )
ent:SetKeyValue( "disableshadows", "1" )
ent:SetPos( SpawnPos )
ent:SetAngles( self.Spawn_angles )
ent:Spawn()
ent:Activate()

return ent
end

function ENT:Initialize()
	self:SetModel("models/props_lab/huladoll.mdl")
	self:SetNoDraw(true)
	self:DrawShadow(false)
	self:SetCollisionGroup(COLLISION_GROUP_NONE)
	self:SetOwner(self.Owner)
	--self:DropToFloor()
	self:SetMoveType(MOVETYPE_NONE)
	self.npc = ents.Create( self.ClassToUse )
	self.npc:SetPos(self:GetPos())
	self.npc:SetAngles(self:GetAngles())
	self.npc:SetModel(self.Model)
	self.npc:SetMoveType(MOVETYPE_NONE)
	local faction = ""
	if self.ClassToUse == "npc_combine_s" then
		self.npc:SetKeyValue( "NumGrenades", "0")
		faction = "SEP_H"
	end
	if self.ClassToUse == "npc_citizen" then
		self.npc:SetKeyValue( "citizentype", "4")
		faction = "SEP_F"
	end
	self.npc:SetKeyValue( "additionalequipment", GetConVarString("gmod_npcweapon") )
	if GetConVarString("gmod_npcweapon") == "" or self.WeaponOverideIgnore then
		self.npc:SetKeyValue( "additionalequipment", table.Random(self.DefaultWeaponLoadout) )
	end
	self.npc:Spawn()
	self.npc:Activate()
	self:SetParent(self.npc)
	self.npc:SetBloodColor(3)
	self.npc:SetHealth(self.Hitpoints)
	self.npc:SetMaxHealth(self.Hitpoints)
	self.npc:SetCurrentWeaponProficiency(self.WeaponProficiency)
	self.npc:CapabilitiesAdd(256)
	self.npc:CapabilitiesAdd(1024) 
	self.npc:CapabilitiesAdd(2048)
	self.npc:CapabilitiesAdd(32768)
	self.npc:CapabilitiesAdd(2) 
	self.npc:CapabilitiesAdd(134217728)
	self.npc:CapabilitiesAdd(1)
	if IsValid(self.npc) and IsValid(self) then self.npc:DeleteOnRemove(self) end
	self:DeleteOnRemove(self.npc)
	if( IsValid(self.npc))then
		local min,max = self.npc:GetCollisionBounds()
		local min2 = Vector(min.x,min.y,0.100000)
		local hull = self.npc:GetHullType()
		self.npc:SetSolid(SOLID_BBOX)
		self.npc:SetHullType(hull)
		self.npc:SetHullSizeNormal()
		self.npc:SetCollisionBounds(min2,max)
		--self.npc:DropToFloor()
		self.Speaking = false
		--self.JetPack = false
		self.drowning = false
		self.WeaponHasSwaped = false
		self.npc.originalReference = self
		if self.HasWeaponSwap and self.PrimaryWeapon == "" then
			self.PrimaryWeapon = self.npc:GetActiveWeapon():GetClass()
		end
		if self.HasPersonalCustomization then
			self:UsePersonalCustomization(self.npc)
		end
		self.npc:Fire("GagEnable")
		--self.npc:SetPos(self.npc:GetPos() + Vector(0,0,5))
		self.npc:SetSolid(SOLID_BBOX)
		self.npc:SetHullType(hull)
		self.npc:SetHullSizeNormal()
		self.npc:SetCollisionBounds(min,max)
	end
	self.npc:SetNWBool("SEP", true)
	self.npc:Fire("startpatrolling","",10)
	self.npc:SetNWFloat("SEP_MeleeDelay", 0)
	self.npc:SetNWFloat("SEP_MeleeSpeed", 1)
	self.npc:SetNWFloat("SEP_TGDelay", 0)
	self.npc:SetNWFloat("SEP_TGSpeed", 5)
	self.npc:SetKeyValue("squadname", faction)
	self.npc:Fire("SetSquad", faction)
	self.TimeTillReinforcements = CurTime() + self.ReinforcementTimer
	if !util.IsInWorld( self.npc:GetPos() ) and !self.npc:GetNWBool("Pilot_In_Flight") and !self.npc:GetNWBool("Gunner_In_Flight") and !self.npc:GetNWBool("In_Turret") then
		self.npc:Remove()
	end
end

function ENT:Think()
	if IsValid(self) and IsValid(self.npc) and self.npc:Health() > 0 and GetConVar("cis_troops_enable"):GetInt() == 1 and GetConVarNumber( "ai_disabled" ) != 1 then
		--[[local entIndex = self:EntIndex()
		local weaponSwap = {"weaponSwap",entIndex}
		local WeaponSwap = table.concat( weaponSwap )
		local reinforcementTable = {"reinforcement",entIndex}
		local TroopReinforcements = table.concat( reinforcementTable )]]
		self:EnemyPresent(self.npc)
		if GetConVar("cis_communication_enable"):GetInt() == 1 then
			self:UnitChatter(self.npc)
		end
		if self.HasWeaponSwap and self.Enemy then
			self:WeaponSwap(self.npc)--WeaponSwap
		end
		if self.CanSpawnReinforcements and GetConVar("cis_reinforcements_enable"):GetInt() == 1 then
			self:SpawnReinforcements(self.npc)--TroopReinforcements
		end
		self:MiscellaneousFunction(self.npc)
		
		if self.HasJetpack then
			self:JetPackUtility(self.npc,false)
		end
		self:ShouldMeleeBeUsed(self.npc)
		if GetConVar("cis_grenade_enable"):GetInt() == 1 then
			self:ExplosiveOrdanance(self.npc)
		end
		if self.Enemy then
			self:EngageEnemy(self.npc)
			self:CheckifUnreachableTarget(self.npc)
		else
			if self.Spotter then
				self:SpotForEnemies(self.npc)
			end
		end
	end
end

function ENT:CheckifUnreachableTarget(npc)
	local enemy = npc:GetEnemy()
	local tr = util.TraceHull( {
		start = enemy:GetPos(),
		endpos = enemy:GetPos() + Vector(0,0,-50),
		filter = enemy,
		mins = Vector( -10, -10, -10 ),
		maxs = Vector( 10, 10, 10 ),
		mask = MASK_SOLID_BRUSHONLY
	} )
	if (enemy:IsOnGround() or tr.HitWorld) then
		
	else
		if npc:GetPos():Distance(enemy:GetPos()) >= 7500 then
			npc:SetEnemy(nil)
			npc:ClearEnemyMemory()
			self:SpotForEnemies(self.npc)
		end
	end
end

function ENT:IsCloseRangeWeapon(weapon)
	for i = 1,table.getn(CIS_NPCS_EquipmentToIgnore) do
		if weapon == CIS_NPCS_EquipmentToIgnore[i] then
			return true
		end
	end
	return false
end

function ENT:EngageEnemy(npc)
	local strafing = npc:IsCurrentSchedule(SCHED_RUN_RANDOM)
	if strafing then
		return
	end	
	local currentActivity = npc:GetActivity()
	local reloading = npc:IsCurrentSchedule(SCHED_RELOAD) or npc:IsCurrentSchedule(SCHED_HIDE_AND_RELOAD) or currentActivity == ACT_RELOAD
	if reloading then
		return
	end
	local getLineOfFire = npc:IsCurrentSchedule(SCHED_ESTABLISH_LINE_OF_FIRE)
	if getLineOfFire then
		return
	end
	local chasingEnemy = npc:IsCurrentSchedule(SCHED_CHASE_ENEMY)
	if chasingEnemy then
		return
	end
	local fallingBack = npc:IsCurrentSchedule(SCHED_RUN_FROM_ENEMY_FALLBACK)
	if fallingBack then
		return
	end
	local specialAttack = npc:IsCurrentSchedule(SCHED_RANGE_ATTACK2) or npc:IsCurrentSchedule(SCHED_MELEE_ATTACK1) or npc:IsCurrentSchedule(SCHED_MELEE_ATTACK2) or npc:IsCurrentSchedule(SCHED_SPECIAL_ATTACK1) or npc:IsCurrentSchedule(SCHED_SPECIAL_ATTACK2)
	if specialAttack then
		return
	end
	local forcedRunning = npc:IsCurrentSchedule(SCHED_FORCED_GO_RUN)
	if forcedRunning and not IsValid(npc:GetEnemy()) then
		return
	end
	npc:Fire("Wake")
	if IsValid(npc:GetEnemy()) then
		self:PursueTarget(npc)
		npc:SetNPCState(NPC_STATE_COMBAT)
		npc:Fire("SetReadinessHigh")
		if IsValid(npc:GetActiveWeapon()) then
			local weapon = npc:GetActiveWeapon()
			local weaponcl = weapon:GetClass()
			local weaponIsCloseRange = self:IsCloseRangeWeapon(weaponcl)
			if weaponIsCloseRange then
				return
			end
			local weaponIsEmpty = weapon:Clip1() == 0
			if weaponIsEmpty then	
				npc:SetSchedule(SCHED_RELOAD)
				return
			end
			local distanceFromEnemy = npc:GetPos():Distance(npc:GetEnemy():GetPos())
			local enemyTooClose = distanceFromEnemy <= 500
			if enemyTooClose and self.EliteMovement then
				npc:SetSchedule(SCHED_RUN_FROM_ENEMY_FALLBACK)
				return
			end
			local rangeAttacking = npc:IsCurrentSchedule(SCHED_RANGE_ATTACK1)
			if not rangeAttacking then
				npc:SetSchedule(SCHED_ESTABLISH_LINE_OF_FIRE)
				return
			end
			if rangeAttacking and self.EliteMovement then
				npc:SetSchedule(SCHED_RUN_RANDOM)
				return
			end
		end
	end
end

function ENT:SpotForEnemies(npc)
	if (!targetsInTheMap) then return end
	for k, v in pairs(targetsInTheMap) do
		if IsValid(v) and !v:IsFlagSet(65536) then
			if v:Health() > 0 and npc:Visible(v) and npc:Disposition( v ) == D_HT then	
				if (v:IsPlayer() and GetConVar("ai_ignoreplayers"):GetInt() == 0) or !v:IsPlayer() then 
					npc:SetEnemy(v)
					self:PursueTarget(npc)
					return	
				end
			end
		end
	end
	--[[for k, v in pairs(player.GetAll()) do
		if IsValid(v) and v:IsPlayer() and !v:IsFlagSet(65536) then
			if GetConVar("ai_ignoreplayers"):GetInt() == 0 and v:Health() > 0 and v:Visible(npc) and npc:Disposition( v ) == D_HT then
				npc:SetEnemy(v)
				self:PursueTarget(npc)
				return
			end
		end
	end]]
end

function ENT:PursueTarget(npc)
	local enemy = npc:GetEnemy()
	local enemyPos = enemy:GetPos()
	npc:SetLastPosition(enemyPos)
	npc:SetTarget(enemy)
	npc:NavSetGoal(enemyPos)
	npc:UpdateEnemyMemory(enemy, enemyPos)
end

function ENT:EnemyPresent(npc)
	if IsValid(npc:GetEnemy()) and npc:GetEnemy() and npc:GetEnemy():Health() > 0 then
		if !self.Enemy and !self.Spotter then
			local act = math.random(1,5)
			if act == 1 then
				self.Spotter = true
			end
		end
		self.Enemy = true
	else
		self.Enemy = false
	end
end

function ENT:UnitChatter(npc)
	--if self.NoEnemy == true then return false end
	if GetConVarNumber( "ai_disabled" ) == 1 then return false end
	if self.TalkTimer < CurTime() then
		self.TalkTimer = CurTime() + math.Rand(5,15)
		if self.Enemy == true and self.CombatChatter != "" then
			local shouldTalk = math.random(1,5)
			if shouldTalk == 1 then
				npc:EmitSound(self.CombatChatter)
			end
		elseif self.Enemy == false and self.IdleChatter != "" then
			local shouldTalk = math.random(1,5)
			if shouldTalk == 1 then
				npc:EmitSound(self.IdleChatter)
			end
		end
	end
end

function ENT:WeaponSwap(npc) --WeaponSwap
	if IsValid(npc:GetActiveWeapon()) then
		if self.WeaponSwapMethod == 1 then
			if npc:GetPos():Distance(npc:GetEnemy():GetPos()) <= self.MinEngagementRange then
				if npc:GetActiveWeapon():GetClass() != self.SecondaryWeapon then
					npc:GetActiveWeapon():Remove()
					npc:Give(self.SecondaryWeapon)
					npc:SetCurrentWeaponProficiency(self.WeaponProficiency)
				end
			elseif npc:GetActiveWeapon():GetClass() != self.PrimaryWeapon then
				npc:GetActiveWeapon():Remove()
				npc:Give(self.PrimaryWeapon)
				npc:SetCurrentWeaponProficiency(self.WeaponProficiency)
			end
		elseif self.WeaponSwapMethod == 2 then
			if npc:GetPos():Distance(npc:GetEnemy():GetPos()) < self.MinEngagementRange and npc:GetActiveWeapon():GetClass() != self.PrimaryWeapon then
				npc:GetActiveWeapon():Remove()
				npc:Give(self.PrimaryWeapon)
				npc:SetCurrentWeaponProficiency(self.WeaponProficiency)
			end
			if npc:GetPos():Distance(npc:GetEnemy():GetPos()) >= self.MinEngagementRange then -- !timer.Exists(WeaponSwap) and
				if self.CheckToSwapWeapon < CurTime() then
					self.CheckToSwapWeapon = CurTime() + math.Rand(5,15)
				--local timeToThink = math.Rand(5,15)
				--timer.Create( WeaponSwap, timeToThink, 1, function()
					if IsValid(npc:GetEnemy()) and IsValid(npc:GetActiveWeapon()) then
						local mood = math.random(0,10)
						if  mood == 1 and npc:GetPos():Distance(npc:GetEnemy():GetPos()) >= self.MinEngagementRange then
							if npc:GetActiveWeapon():GetClass() != self.SecondaryWeapon then
								npc:GetActiveWeapon():Remove()
								npc:Give(self.SecondaryWeapon)
								npc:SetCurrentWeaponProficiency(self.WeaponProficiency)
							end
						elseif npc:GetActiveWeapon():GetClass() != self.PrimaryWeapon then
							npc:GetActiveWeapon():Remove()
							npc:Give(self.PrimaryWeapon)
							npc:SetCurrentWeaponProficiency(self.WeaponProficiency)
						end
					end
				end
			end
		elseif self.WeaponSwapMethod == 3 then
			local mood3 = math.random(1,250)
			if mood3 == 1 and npc:GetPos():Distance(npc:GetEnemy():GetPos()) <= self.MinEngagementRange then
				if npc:GetActiveWeapon():GetClass() != self.ThirdWeapon then
					npc:GetActiveWeapon():Remove()
					npc:Give(self.ThirdWeapon)
					npc:SetCurrentWeaponProficiency(self.WeaponProficiency)
				end
			end
			if npc:GetPos():Distance(npc:GetEnemy():GetPos()) > self.MinEngagementRange then --!timer.Exists(WeaponSwap) and 
				if self.CheckToSwapWeapon < CurTime() then
					self.CheckToSwapWeapon = CurTime() + math.Rand(2,7)
				--local timeToThink = math.Rand(2,7)
				--timer.Create( WeaponSwap, timeToThink, 1, function()
					if IsValid(npc) and IsValid(npc:GetEnemy()) and IsValid(npc:GetActiveWeapon()) then
						local mood = math.random(0,5)
						local mood2 = math.random(0,15)
						if mood2 == 1 and npc:GetPos():Distance(npc:GetEnemy():GetPos()) >= self.MaxEngagementRange then
							if npc:GetActiveWeapon():GetClass() != self.SecondaryWeapon then
								npc:GetActiveWeapon():Remove()
								npc:Give(self.SecondaryWeapon)
								npc:SetCurrentWeaponProficiency(self.WeaponProficiency)
							end
						elseif mood == 1 and npc:GetActiveWeapon():GetClass() != self.PrimaryWeapon then
							npc:GetActiveWeapon():Remove()
							npc:Give(self.PrimaryWeapon)
							npc:SetCurrentWeaponProficiency(self.WeaponProficiency)
						end
					end
				end
			end
		end
	else
		if self.PrimaryWeapon != "" and !npc:GetNWBool("In_Turret") then
			npc:Give(self.PrimaryWeapon)
			npc:SetCurrentWeaponProficiency(self.WeaponProficiency)
		end
	end
end

function ENT:SpawnReinforcements(npc)--TroopReinforcements
	--if !timer.Exists(TroopReinforcements) then
	--	timer.Create( TroopReinforcements, self.ReinforcementTimer, 1, function()
	if self.TimeTillReinforcements < CurTime() then
		self.TimeTillReinforcements = CurTime() + self.ReinforcementTimer
	--if npc:IsValid() then	
		local x = -140
		local y = 200
		for i=1,self.ReinforcementCount do
			local ReinforcementToSpawn = self:DetermineUnitToSpawn()
			local Trooper = ents.Create( ReinforcementToSpawn )
			Trooper:SetPos( npc:GetPos() + npc:GetForward()*x + npc:GetRight()*y + npc:GetUp()*128)
			Trooper:SetAngles(self:GetAngles())
			Trooper:Spawn()
			Trooper:Activate()
			if math.fmod( i, 5 )  == 0 then
				y = 200
				x = x - 140
			else 
				y = y - 100
			end
		end
		if self.ReinforceChatter != "" then
			npc:EmitSound(self.ReinforceChatter)
		end
		if self.HasSpecialReinforcements then
			self:SummonSpecialReinforcements(self.npc)
		end
	end
	--	end)
	--end
end

function ENT:MiscellaneousFunction(npc)
	if npc:WaterLevel() >= 1 and self.HasJetpack then
		self:JetPackUtility(self.npc,true)
	end
	if npc:WaterLevel() == 3 and self.MiscellaneousTimer < CurTime() then
		npc:TakeDamage( 5, npc, npc ) 
		self.MiscellaneousTimer = CurTime() + 2
	end
	if npc:IsOnFire() and self.ImmuneToFire then
		npc:Extinguish()
	end
end

function ENT:JetPackUtility(npc,forcedJump)
	if IsValid(npc:GetEnemy()) and npc:GetPos():Distance(npc:GetEnemy():GetPos()) <= 500 or forcedJump then
		if self.JetPackRecharge < CurTime() and (npc:IsOnGround() or forcedJump) then --!self.JetPack
			--self.JetPack = true
			self.JetPackRecharge = CurTime() + 1
			if npc:IsValid() and (npc:IsOnGround() or forcedJump) then
				npc:PlayScene("scenes/jump.vcd")
				local mathNum = math.random(1,4)
				if mathNum == 1 then
					npc:SetVelocity(npc:GetForward() * -1500 + npc:GetUp() * 450)
				elseif mathNum == 2 then
					npc:SetVelocity(npc:GetForward() * 1500 + npc:GetUp() * 450)
				elseif mathNum == 3 then
					npc:SetVelocity(npc:GetUp() * 450 + npc:GetRight() * -1500 )
				else
					npc:SetVelocity(npc:GetUp() * 450 + npc:GetRight() * 1500 )
				end
				npc:EmitSound("CIS.JetPack")
				if npc:IsValid() then
					local fx = EffectData()
					fx:SetEntity(npc)
					util.Effect("npcjetsmoke", fx, true, true)
					npc:SetNWFloat("NextJetEffect",CurTime()+5)
				end
			end
			--timer.Simple(1, function()
			--	self.JetPack = false
			--end)
		end
	end
end

function ENT:ShouldMeleeBeUsed(npc)
	if npc:IsValid() and npc:Health() > 0 then
		if IsValid(npc:GetEnemy()) and npc:Visible(npc:GetEnemy()) and (!npc:IsMoving()) and npc:GetPos():Distance(npc:GetEnemy():GetPos()) < 65 and npc:GetEnemy():Health() > 0 then
			npc:AddEntityRelationship( npc:GetEnemy(), D_HT, 99 )
			npc:StopMoving()
			if (npc:GetNWFloat("SEP_MeleeDelay") > CurTime()) then return false end
			MeleeAttack(npc, npc:GetEnemy(),"swing")
			npc:SetTarget(npc:GetEnemy())
			if IsValid(npc:GetTarget()) and !npc:IsCurrentSchedule(SCHED_TARGET_FACE) then
				npc:SetSchedule(SCHED_TARGET_FACE)
			end
			npc:SetNWFloat("SEP_MeleeDelay", CurTime() + npc:GetNWFloat("SEP_MeleeSpeed"))
		end
	end
end

function ENT:MeleeAttack(npc, npcenemy, name)
npc:RestartGesture(npc:GetSequenceInfo(npc:LookupSequence(name)).activity)
npc:SetNWBool("SEP_PlayAnim", true)
local time = npc:SequenceDuration()
timer.Create("DealDamage"..npc:EntIndex(),npc:GetNWFloat("SEP_MeleeSpeed")*0.4,1,function()
if IsValid(npc) then
npc:SetNWBool("SEP_PlayAnim", false)
end
if !IsValid(npc) or !IsValid(npcenemy) then return end
if npc:GetPos():Distance(npcenemy:GetPos()) > 65 or !npc:IsAliveNPC() then return end
npcenemy:TakeDamage(math.random(12,16),npc,npc)
npcenemy:SetVelocity(npc:GetForward()*1000)
if npcenemy:IsPlayer() then
npcenemy:ViewPunch( Angle( -20, math.random(-50,50), math.random(-15,15) ) )
end
npcenemy:EmitSound("CIS.Melee")
end)
end

function ENT:ExplosiveOrdanance(npc)
	if npc:IsValid() and npc:Health() > 0 then
		local Pos = npc:GetPos()
		if IsValid(npc:GetEnemy()) and npc:Visible(npc:GetEnemy()) and npc:GetPos():Distance(npc:GetEnemy():GetPos()) > 500 and npc:GetPos():Distance(npc:GetEnemy():GetPos()) <= 2000 and self.GrenadeCount > 0 then
			if (npc:GetNWFloat("SEP_TGDelay") > CurTime()) then return false end
			npc:SetNWFloat("SEP_TGDelay", CurTime() + npc:GetNWFloat("SEP_TGSpeed"))
			if npc:IsValid() then	
				if math.random(1,150) != 2 then return end
				if self.RocketUser then
					npc:SetNWFloat("SEP_TGDelay", CurTime() + npc:GetNWFloat("SEP_TGSpeed") + npc:GetNWFloat("SEP_TGSpeed")*0.5)
					npc:SetTarget(npc:GetEnemy())
					local enemy = npc:GetEnemy()
					local aim = npc:GetAimVector()
					local side = aim:Cross(Vector(0,0,1))
					local up = side:Cross(aim)
					local dirx = aim.x
					dirx = dirx/3
					local diry = aim.y
					diry = diry/3
					local dirz = aim.z
					dirz = dirz/3
					aim = Vector(dirx,diry,dirz)
					local pos = npc:GetShootPos() +  aim * 24 + side * 8 + up * -1	--offsets the rocket so it spawns from the muzzle (hopefully)
					local dir = enemy:WorldSpaceCenter()
					dir = (dir - pos):GetNormalized()
					local rocket = ents.Create("b2_wrist_rockets")
					if !rocket:IsValid() then return false end
					rocket:SetAngles((dir+aim):Angle())
					rocket:SetPos(pos)
					rocket:SetOwner(npc)
					rocket:Spawn()
					rocket:Activate()
					rocket:SetVelocity(rocket:GetForward()*2500)
					self.GrenadeCount = self.GrenadeCount - 1
				else
					npc:SetNWFloat("SEP_TGDelay", CurTime() + npc:GetNWFloat("SEP_TGSpeed") + npc:GetNWFloat("SEP_TGSpeed")*0.5)
					self:SeperatistGrenadeThrow(npc, npc:GetEnemy(), "throw1")
					npc:SetTarget(npc:GetEnemy())
					if IsValid(npc:GetTarget()) and !npc:IsCurrentSchedule(SCHED_TARGET_FACE) then
						if self.NadeThrowCall != "" then
							npc:EmitSound(self.NadeThrowCall)
						end
					end
				end
			end
		end
	end
end

function ENT:SeperatistGrenadeThrow(npc, npcenemy, name)
npc:RestartGesture(npc:GetSequenceInfo(npc:LookupSequence(name)).activity)

npc:SetNWBool("SEP_PlayAnim", true)
local time = npc:SequenceDuration()
timer.Create("ThrowGrenade"..npc:EntIndex(),0.8,1,function()
if IsValid(npc) then
npc:SetNWBool("SEP_PlayAnim", false)
end
if !IsValid(npc) or !IsValid(npcenemy) then return end

local shoot_angle = Vector(0,0,0)
local Dist=(npcenemy:GetPos()-npc:GetPos()):Length() 
if npc:IsNPC() then
if npcenemy != NULL and npcenemy != nil then
shoot_angle = npcenemy:GetPos() - npc:GetPos()
shoot_angle = shoot_angle + Vector(math.random(-30,30),math.random(-30,30),85)*(shoot_angle:Distance(Vector(0,0,0))/math.random(1800,1000))
shoot_angle:Normalize()
else
return
end
end
local shoot_pos = npc:GetShootPos() + npc:GetRight() * 0 + npc:GetUp() * -10 + shoot_angle * 30
local grenade = ents.Create( table.Random(CIS_Grenades) )
local bone = npc:LookupBone("ValveBiped.Bip01_R_Hand")
local pos, ang = npc:GetBonePosition(bone)
if (IsValid(grenade)) then	
grenade:SetPos(pos + ang:Right() + ang:Forward() + ang:Up())
grenade:SetAngles(shoot_angle:Angle())
grenade:SetOwner(npc)
grenade:Spawn()
grenade:Activate()
self.GrenadeCount = self.GrenadeCount - 1
local phys = grenade:GetPhysicsObject()
if IsValid(phys) and npc:Health() > 0 then
--self.Force = 1000
phys:SetVelocity( (npc:GetAimVector() * Dist*math.Rand(.5,1.5)) + npc:GetUp()*Dist*math.Rand(.2,.5) )
phys:AddAngleVelocity(Vector(math.random(-800,800),math.random(-800,800),math.random(-800,800)))
--phys:ApplyForceCenter(npc:GetAimVector() *npc.Force *2 + Vector(0,0,200) )
--phys:AddAngleVelocity(Vector(math.random(-500,500),math.random(-500,500),math.random(-500,500)))
end
end

end)
if(stationary)then
npc:StopMoving()
timer.Create("PlayThrowAnim"..npc:EntIndex(),.1,math.Round(1*10),function()
if IsValid(npc) and IsValid(npcenemy) then
npc:StopMoving()
npc:SetTarget(npcenemy)
if IsValid(npc:GetTarget()) and !npc:IsCurrentSchedule(SCHED_TARGET_FACE) then
npc:SetSchedule(SCHED_TARGET_FACE)
end
end
end)
end
end

