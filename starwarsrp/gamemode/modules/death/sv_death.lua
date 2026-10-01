PD.Death = PD.Death or {}

util.AddNetworkString("PD.Respawn")
util.AddNetworkString("PD.AdminRespawn")
util.AddNetworkString("PD.DeadTime")

function PD.Death.Kill(victim_ent, victim_name, attacker_ent, attacker_name)
    net.Start("PD.DeadTime")
    net.Send(victim_ent)

    if attacker_ent then
        PD.LOGS.Add("DeathScreen", victim_name .. " wurde von " .. attacker_name .. " getötet!", Color(255, 30, 30, 255))
    else
        PD.LOGS.Add("DeathScreen", victim_name .. " ist gestorben!", Color(255, 30, 30, 255))
    end
end

local function createRagdoll(ply)
    local ragdoll = ents.Create("prop_ragdoll")
    ragdoll:SetModel(ply:GetModel() or "models/player/kleiner.mdl") -- Oder ein anderes Model
    ragdoll:SetPos(ply:GetPos() or Vector(0, 0, 100)) -- Position setzen
    ragdoll:SetAngles(ply:GetAngles() or Angle(0, 0, 0)) -- Rotation setzen
    ragdoll:Spawn()
    ragdoll:Activate()
    ragdoll.equip = {}

    for k, v in pairs(ply:GetWeapons()) do
        ragdoll.equip[k] = v:GetClass()
    end

    ragdoll.ammo = ply:GetAmmo()

    for k, v in pairs(ply:GetBodyGroups()) do
        ragdoll:SetBodygroup(k, ply:GetBodygroup(k))
    end

    local ragdoll_phys = ragdoll:GetPhysicsObject()
    local ply_phys = ply:GetPhysicsObject()
    if IsValid(ragdoll_phys) then
        -- ragdoll_phys:Wake()
    end

    ragdoll:SetNW2Entity("PD.DM.RagdollOwner", ply)
    ply:SetNW2Entity("PD.DM.Ragdoll", ragdoll)
    ply:SpectateEntity(ragdoll)
    ply:Spectate(OBS_MODE_DEATHCAM)

    ply:SetViewOffset(Vector(0,0,64))
    print(ply:GetViewOffset())

    return ragdoll
end

net.Receive("PD.Respawn", function(len, ply)
    if not ply:Alive() then
        ply:Spawn()

        -- Nach Spawn(), also nachdem die Spielerklasse ihre Vorgaben gesetzt
        -- hat. Job-Geschwindigkeit und ein fester Wert am Spieler liegen in
        -- PD.Char.ApplySpeed, damit es nur eine Stelle dafuer gibt.
        PD.Char.ApplySpeed(ply)
    end
end)

net.Receive("PD.AdminRespawn", function(len, ply)
    if not ply:IsAdmin() or ply:Alive() then
        return
    end

    local pos
    local mdl
    local ent = ply:GetNW2Entity("PD.DM.Ragdoll")

    if IsValid(ent) then
        pos = ent:GetPos()
        mdl = ent:GetModel()
        ent:Remove()
    else
        pos = ply:GetPos()
    end

    ply:Spawn()
    if IsValid(pos) then
        ply:SetPos(pos)
    end

    if IsValid(mdl) then
        ply:SetModel(mdl)
    end

    ply:Freeze(false)
    ply:SetViewEntity(ply)

    PD.Char.ApplySpeed(ply)


    ply:GodEnable()
    PD.Notify("Du bist nun im Godmode!", Color(255, 30, 30, 255), false, ply)
end)

hook.Add("PlayerDeathThink", "DisableDeathRespawn", function(ply)
    return false
end)

--[[
    Hier stand ein zweiter PlayerSpawn-Hook, der Job- und Untereinheiten-
    Ausruestung ausgegeben hat - unabhaengig von PD.Char.SetModelOnSpawn in
    _character/sv_functions.lua.

    Die Reihenfolge machte ihn unsichtbar: _character wird vor death geladen,
    also lief SetModelOnSpawn zuerst, raeumte mit StripWeapons ab und gab die
    permanente Ausruestung aus - und direkt danach gab dieser Hook das volle
    Loadout wieder dazu. Gespawnt wird jetzt nur noch mit dem, was
    SetModelOnSpawn ausgibt; Waffen kommen aus der Waffenkammer.

    Ausdruecklich abgemeldet statt nur geloescht: ein Lua-Refresh laedt die
    Datei neu, entfernt aber keinen Hook, der beim vorigen Durchlauf
    registriert wurde.
]]
hook.Remove("PlayerSpawn", "PD.PlayerSpawn")

hook.Add("PlayerDeath", "PD.PlayerDeath", function(victim, inflictor, attacker)
    if not IsValid(victim) or not IsValid(attacker) then return end

    local victim_name = victim:Nick() .." (" .. victim:SteamID() .. ")"
    local attacker_name = attacker and attacker:Nick() or "Unbekannt" .." (" .. attacker:SteamID() or "Unbekannt" .. ")" or "Environment"

    PD.Death.Kill(victim, victim_name, attacker, attacker_name)

    if victim:GetRagdollEntity() and IsValid(victim:GetRagdollEntity()) then
        victim:GetRagdollEntity():Remove()
    end

    local ragdoll = createRagdoll(victim)
end)