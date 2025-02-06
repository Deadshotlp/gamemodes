PD.Death = PD.Death or {}

util.AddNetworkString("PD.Respawn")
util.AddNetworkString("PD.AdminRespawn")
util.AddNetworkString("PD.DeadTime")

hook.Add( "PlayerDeath", "GlobalDeathMessage", function( victim, inflictor, attacker )
    net.Start( "PD.DeadTime" )
    net.Send( victim )

    if attacker:IsPlayer() then
        PD.LOGS.Add("DeathScreen", victim:Nick() .. " wurde von " .. attacker:Nick() .. " getötet!", Color(255, 30, 30, 255))
    else
        PD.LOGS.Add("DeathScreen", victim:Nick() .. " ist gestorben!", Color(255, 30, 30, 255))
    end

end )

net.Receive("PD.Respawn", function(len, ply)
    if not ply:Alive() then
        ply:Spawn()

        local jobID, jobTable = ply:GetJob()

        if jobTable.model then
            ply:SetModel(jobTable.model[1])
        end
    end
end)

net.Receive("PD.AdminRespawn", function(len, ply)
    if not ply:Alive() then
        local pos = ply:GetPos()
        ply:Spawn()
        ply:SetPos(pos)
        --ply:GodEnable()
        --PD.Notify("Du bist nun im Godmode!", Color(255, 30, 30, 255), false, ply)
    end
end)