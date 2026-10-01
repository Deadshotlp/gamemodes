WarningSystem = WarningSystem or {}

util.AddNetworkString("WarningSystem_ConfigSync")
util.AddNetworkString("WarningSystem_ConfigUpdate")
util.AddNetworkString("WarningSystem_OpenMenu")
util.AddNetworkString("WarningSystem_OpenConfig")
util.AddNetworkString("WarningSystem_RequestData")
util.AddNetworkString("WarningSystem_SendData")
util.AddNetworkString("WarningSystem_WarnPlayer")
util.AddNetworkString("WarningSystem_BanPlayer")
util.AddNetworkString("WarningSystem_RemoveWarning")
util.AddNetworkString("WarningSystem_RemoveBan")
util.AddNetworkString("WarningSystem_UnbanPlayer")
util.AddNetworkString("WarningSystem_ClearWarnings")
util.AddNetworkString("WarningSystem_EditWarning")
util.AddNetworkString("WarningSystem_EditBan")
util.AddNetworkString("WarningSystem_UpdateData")
util.AddNetworkString("WarningSystem_GetPlayerData")
util.AddNetworkString("WarningSystem_SendPlayerData")

-- Send config to newly connected players
hook.Add("PlayerInitialSpawn", "WarningSystem_SendConfig", function(ply)
    timer.Simple(1, function()
        if IsValid(ply) then
            WarningSystem.Config:SyncToClients(ply)
        end
    end)
end)

-- Request all data
net.Receive("WarningSystem_RequestData", function(len, ply)
    if not WarningSystem:HasPermission(ply) then return end

    local onlinePlayers = {}
    for _, p in ipairs(player.GetAll()) do
        table.insert(onlinePlayers, {
            steamid = p:SteamID(),
            name = p:Nick(),
            warns = WarningSystem.DB:GetActiveWarningCount(p:SteamID()),
            online = true
        })
    end

    local allPlayers = WarningSystem.DB:GetAllPlayers()

    -- Warn-Counts für alle Spieler hinzufügen und Namen aktualisieren
    for _, playerData in ipairs(allPlayers) do
        playerData.warns = WarningSystem.DB:GetActiveWarningCount(playerData.steamid)

        -- Wenn kein Name vorhanden ist, versuche ihn vom Player-Objekt zu holen
        local needsUpdate = not playerData.playername or playerData.playername == "" or playerData.playername == "Unknown Player" or playerData.playername == "Unknown" or string.find(string.lower(playerData.playername), "unknown")

        if needsUpdate then
            -- Versuche den Spieler zu finden, falls er online ist
            local foundPlayer = player.GetBySteamID(playerData.steamid)
            if IsValid(foundPlayer) then
                playerData.playername = foundPlayer:Nick()
                -- In Datenbank cachen
                WarningSystem.DB:UpdatePlayerCache(playerData.steamid, foundPlayer:Nick())
            else
                -- Spieler ist offline, verwende Fallback
                playerData.playername = "Unknown Player"
            end
        end
    end

    net.Start("WarningSystem_SendData")
    net.WriteTable(onlinePlayers)
    net.WriteTable(allPlayers)
    net.Send(ply)
end)

-- Get specific player data
net.Receive("WarningSystem_GetPlayerData", function(len, ply)
    if not WarningSystem:HasPermission(ply) then return end

    local steamid = net.ReadString()

    local warnings = WarningSystem.DB:GetWarnings(steamid)
    local bans = WarningSystem.DB:GetBans(steamid)
    local activeBan = WarningSystem.DB:GetActiveBan(steamid)

    net.Start("WarningSystem_SendPlayerData")
    net.WriteString(steamid)
    net.WriteTable(warnings)
    net.WriteTable(bans)
    net.WriteBool(activeBan ~= nil)
    if activeBan then
        net.WriteTable(activeBan)
    end
    net.Send(ply)
end)

-- Warn Player
net.Receive("WarningSystem_WarnPlayer", function(len, ply)
    if not WarningSystem:HasPermission(ply) then return end

    local steamid = net.ReadString()
    local name = net.ReadString()
    local reason = net.ReadString()
    local temporary = net.ReadBool()

    WarningSystem:WarnPlayer(steamid, name, ply, reason, temporary)
end)

-- Ban Player
net.Receive("WarningSystem_BanPlayer", function(len, ply)
    if not WarningSystem:HasPermission(ply) then return end

    local steamid = net.ReadString()
    local name = net.ReadString()
    local reason = net.ReadString()
    local duration = net.ReadUInt(32)

    if duration == 0 then duration = nil end

    WarningSystem:BanPlayer(steamid, name, ply, reason, duration)
end)

-- Remove Warning
net.Receive("WarningSystem_RemoveWarning", function(len, ply)
    if not WarningSystem:HasPermission(ply) then return end

    local warn_id = net.ReadUInt(32)
    WarningSystem:RemoveWarning(warn_id, ply)
end)

-- Remove Ban
net.Receive("WarningSystem_RemoveBan", function(len, ply)
    if not WarningSystem:HasPermission(ply) then return end

    local ban_id = net.ReadUInt(32)
    WarningSystem:RemoveBan(ban_id, ply)
end)

-- Unban Player
net.Receive("WarningSystem_UnbanPlayer", function(len, ply)
    if not WarningSystem:HasPermission(ply) then return end

    local steamid = net.ReadString()
    WarningSystem:UnbanPlayer(steamid, ply)
end)

-- Clear All Warnings
net.Receive("WarningSystem_ClearWarnings", function(len, ply)
    if not WarningSystem:HasPermission(ply) then return end

    local steamid = net.ReadString()
    WarningSystem:ClearWarnings(steamid, ply)
end)

-- Edit Warning
net.Receive("WarningSystem_EditWarning", function(len, ply)
    if not WarningSystem:HasPermission(ply) then return end

    local warn_id = net.ReadUInt(32)
    local new_reason = net.ReadString()
    WarningSystem:EditWarning(warn_id, new_reason, ply)
end)

-- Edit Ban
net.Receive("WarningSystem_EditBan", function(len, ply)
    if not WarningSystem:HasPermission(ply) then return end

    local ban_id = net.ReadUInt(32)
    local new_reason = net.ReadString()
    WarningSystem:EditBan(ban_id, new_reason, ply)
end)
