PD.Death = PD.Death or {}

util.AddNetworkString("PD.Respawn")
util.AddNetworkString("PD.AdminRespawn")
util.AddNetworkString("PD.DeadTime")

hook.Add("PlayerDeathThink", "DisableDeathRespawn", function(ply)
    return false
end)

function PD.Death.Kill(victim, attacker)
    net.Start("PD.DeadTime")
    net.Send(victim)

    if attacker then
        PD.LOGS.Add("DeathScreen", victim:Nick() .. " wurde von " .. attacker .. " getötet!", Color(255, 30, 30, 255))
    else
        PD.LOGS.Add("DeathScreen", victim:Nick() .. " ist gestorben!", Color(255, 30, 30, 255))
    end
end

net.Receive("PD.Respawn", function(len, ply)
    if not ply:Alive() then
        ply:Spawn()
    end
end)

net.Receive("PD.AdminRespawn", function(len, ply)
    if not ply:IsAdmin() then
        return
    end

    local pos
    local ent = ply:GetNW2Entity("PD.DM.Ragdoll")

    if not ply:Alive() then
        if IsValid(ent) then
            pos = ent:GetPos()
        else
            pos = ply:GetPos()
        end

        PD.DM.Main.tbl[ply:SteamID64()] = nil
        ply:Spawn()
        ply:SetPos(pos)
        ply:Freeze(false)
        ply:SetViewEntity(ply)
        ply:GodEnable()
        PD.Notify("Du bist nun im Godmode!", Color(255, 30, 30, 255), false, ply)
    end
end)

hook.Add("PlayerSpawn", "PD.PlayerSpawn", function(ply)
    local jobname, jobTable = ply:GetJob()

    for k, v in SortedPairs(jobTable.equip) do
        ply:Give(v)
    end

    local name, subunit = PD.JOBS.GetSubUnit(jobTable.unit)

    for k, v in SortedPairs(subunit.equip) do
        ply:Give(v)
    end
end)