local AFKTimeLimit = 300
local CheckInterval = 10
local PlayerLastActivity = {}

local function UpdatePlayerActivity(ply)
    PlayerLastActivity[ply:SteamID()] = CurTime()
end

local function CheckAFKPlayers()
    for _, ply in ipairs(player.GetAll()) do
        local lastActivity = PlayerLastActivity[ply:SteamID()]
        if lastActivity and (CurTime() - lastActivity > AFKTimeLimit) and not ply:IsAdmin() then
            -- ply:Kick("You have been kicked for being AFK too long.")
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