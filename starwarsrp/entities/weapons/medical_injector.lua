-- if SERVER then
--     AddCSLuaFile("shared.lua")
-- end
SWEP.PrintName = "Medical Injector - Combat Stimulant"
SWEP.Author = "Speedy, OG Zeus | Deadshot"
SWEP.Slot = 2
SWEP.SlotPos = 0
SWEP.Base = "zeus_weaponbasesck"
SWEP.Description = "Deadshot Edit for PD GM"
SWEP.Purpose = ""
SWEP.Instructions = "Left click to heal someone\nRight click to heal yourself"

SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Category = "PD - Gamemode"
SWEP.IconOverride = "materials/zeus/hydronthumbnail.png"

SWEP.ViewModel = "models/weapons/c_crowbar_frame.mdl"
SWEP.WorldModel = "models/weapons/w_medkit.mdl"
SWEP.UseHands = true
SWEP.ViewModelFOV = 72
SWEP.ShowViewModel = false
SWEP.ShowWorldModel = false
SWEP.Primary.Recoil = 0
SWEP.Primary.ClipSize  = -1
SWEP.Primary.DefaultClip = 1
SWEP.Primary.Automatic  = true
SWEP.Primary.Delay = 0.1
SWEP.Primary.Ammo = "none"
SWEP.HoldType = "slam"
SWEP.WElements = {
	["syringe"] = { 
		type = "Model",
		model = "models/speedy/props/medics/hydronkit.mdl",
		bone = "ValveBiped.Bip01_R_Hand", rel = "",
		pos = Vector(3, 5.8, -2.5), angle = Angle(80, 180, 180),
		size = Vector(1, 1, 1), color = Color(255, 255, 255, 255),
		surpresslightning = false, material = "", skin = 0, bodygroup = {} }
}

SWEP.VElements = {
	["syringe"] = {
		type = "Model",
		model = "models/speedy/props/medics/hydronkit.mdl",
		bone = "ValveBiped.Bip01_R_Hand", rel = "",
		pos = Vector(5, 10, -4), angle = Angle(75, 110, 270),
		size = Vector(1.7, 1.7, 1.7), color = Color(255, 255, 255, 255),
		surpresslightning = false, material = "", skin = 0, bodygroup = {} }
}

SWEP.Secondary.Recoil = 0
SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = 1
SWEP.Secondary.Automatic = true
SWEP.Secondary.Delay = 0.3
SWEP.Secondary.Ammo = "none"

local MEDIGUN_TARGET_EFFECT = "medicgun_beam_blue_healing"
local MEDIGUN_TARGET_EFFECT_OFFSET = Vector(0, 0, 50)
local MEDIGUN_TARGET_EFFECT_DURATION = 0.75

if SERVER then
    PrecacheParticleSystem(MEDIGUN_TARGET_EFFECT)
end

local function PlayMedigunTargetEffect(target, owner)
    if not SERVER or not IsValid(target) then return end

    local effect = ents.Create("info_particle_system")
    if not IsValid(effect) then return end

    local effectPos = target:GetPos() + MEDIGUN_TARGET_EFFECT_OFFSET
    local controlPoint = ents.Create("tf_target_medigun")
    if not IsValid(controlPoint) then
        effect:Remove()
        return
    end

    local controlName = "hydron_medigun_target_cp_" .. effect:EntIndex()
    controlPoint:SetKeyValue("targetname", controlName)
    controlPoint:SetPos(effectPos)
    controlPoint:Spawn()
    controlPoint:Activate()
    controlPoint:SetNoDraw(true)
    controlPoint:AddEffects(EF_NODRAW)
    controlPoint:DrawShadow(false)
    controlPoint:SetSolid(SOLID_NONE)

    local actualControlName = controlPoint:GetName()
    if not actualControlName or actualControlName == "" then
        actualControlName = controlName
    end

    effect:SetKeyValue("effect_name", MEDIGUN_TARGET_EFFECT)
    effect:SetKeyValue("cpoint1", actualControlName)

    if IsValid(owner) then
        effect:SetOwner(owner)
        controlPoint:SetOwner(owner)
    end

    effect:SetPos(effectPos)
    effect:Spawn()
    effect:Activate()
    effect:Fire("start", "", 0)

    local timerName = "hydron_medigun_target_effect_" .. effect:EntIndex()
    local function StopTargetEffect()
        timer.Remove(timerName)

        if IsValid(effect) then
            effect:Fire("kill", "", 0)
        end

        if IsValid(controlPoint) then
            controlPoint:Remove()
        end
    end

    timer.Create(timerName, 0.04, 0, function()
        if not IsValid(effect) then
            if IsValid(controlPoint) then
                controlPoint:Remove()
            end

            timer.Remove(timerName)
            return
        end

        if not IsValid(target) or not IsValid(controlPoint) then
            StopTargetEffect()
            return
        end

        local targetPos = target:GetPos() + MEDIGUN_TARGET_EFFECT_OFFSET
        effect:SetPos(targetPos)
        controlPoint:SetPos(targetPos)
    end)

    timer.Simple(MEDIGUN_TARGET_EFFECT_DURATION, StopTargetEffect)
end

function SWEP:PrimaryAttack()
    if CLIENT then return end

    local Traced = self:CheckTrace()

    if not IsValid(Traced) or Traced:GetClass() ~= "prop_ragdoll" then return end

    local ragdoll_owner = Traced:GetNW2Entity("PD.DM.RagdollOwner")

    if not IsValid(ragdoll_owner) then return end

    ragdoll_owner:Spawn()
    ragdoll_owner:SetPos(Traced:GetPos())
    ragdoll_owner:SetModel(Traced:GetModel())

    for k, v in pairs(Traced:GetBodyGroups()) do
        ragdoll_owner:SetBodygroup(k, Traced:GetBodygroup(k))
    end

    -- Beide Tabellen setzt createRagdoll in sv_death.lua. Stammt die Leiche von
    -- woanders, fehlen sie - pairs(nil) haette hier abgebrochen, und dann waere
    -- auch das Aufraeumen unten nie gelaufen.
    for _, v in pairs(Traced.equip or {}) do
        ragdoll_owner:Give(v)
    end

    for ammoID, amount in pairs(Traced.ammo or {}) do
        ragdoll_owner:SetAmmo(amount, ammoID)
    end

    --[[
        Die Ansicht zurueck auf den Spieler, BEVOR die Leiche verschwindet.

        Beim Tod setzt createRagdoll die Kamera per SetViewEntity auf die
        Leiche. Wird die entfernt, ohne die Ansicht vorher zurueckzuholen,
        haengt der Client an einer ungueltigen Entity - genau das war der
        Kamerafehler nach dem Wiederbeleben. Die beiden Respawn-Wege in
        sv_death.lua machen das laengst, dieser hier nicht.
    ]]
    ragdoll_owner:SetViewEntity(ragdoll_owner)

    -- Der Verweis auf die Leiche muss mit weg: sv_death.lua und die
    -- Reichweitenpruefung im Chat lesen ihn, und er zeigt gleich ins Leere.
    ragdoll_owner:SetNW2Entity("PD.DM.Ragdoll", NULL)
    ragdoll_owner:Freeze(false)

    Traced:Remove()
end

function SWEP:CheckTrace()
    local Owner = self:GetOwner()
    Owner:LagCompensation(true)

    local Trace = util.TraceLine({
        start = Owner:GetShootPos(),
        endpos = Owner:GetShootPos() + Owner:GetAimVector() * 64,
        filter = Owner
    })

    Owner:LagCompensation(false)

    return Trace.Entity
end