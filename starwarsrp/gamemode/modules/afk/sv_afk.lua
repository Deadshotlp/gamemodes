local AFKTimeLimit = 300
local CheckInterval = 10
local PlayerLastActivity = {}

local function UpdatePlayerActivity(ply)
    if PlayerLastActivity[ply:SteamID()] and (CurTime() - PlayerLastActivity[ply:SteamID()] > 175) then
        net.Start("PD_UpdateAFKStatus")
        net.WriteBool(false)
        net.Send(ply)
    end

    PlayerLastActivity[ply:SteamID()] = CurTime()
end

util.AddNetworkString("PD_UpdateAFKStatus")

local function CheckAFKPlayers()
    for _, ply in ipairs(player.GetAll()) do
        local lastActivity = PlayerLastActivity[ply:SteamID()]

        if lastActivity and (CurTime() - lastActivity > 180) and not ply:IsAdmin() and not ply:IsBot() then
            net.Start("PD_UpdateAFKStatus")
            net.WriteBool(true)
            net.Send(ply)
        end

        if lastActivity and (CurTime() - lastActivity > AFKTimeLimit) and not ply:IsAdmin() and not ply:IsBot() then
            ply:Kick("Du wurdest wegen Inaktivität gekickt.")
            PD.LOGS.Add("[AFK]", ply:Nick() .. " wurde für zu langes AFK gekickt.", Color(255, 0, 0))
        end
    end
end

hook.Add("KeyPress", "UpdatePlayerActivityOnKeyPress", function(ply, key)
    UpdatePlayerActivity(ply)
end)

hook.Add("PlayerSay", "UpdatePlayerActivityOnChat", function(ply, text)
    UpdatePlayerActivity(ply)
end)

timer.Create("AFKCheckTimer", CheckInterval, 0, function()
    CheckAFKPlayers()
end)

hook.Add("PlayerInitialSpawn", "SetInitialPlayerActivity", function(ply)
    UpdatePlayerActivity(ply)
end)

hook.Add("PlayerDisconnected", "RemovePlayerActivity", function(ply)
    PlayerLastActivity[ply:SteamID()] = nil
end)