WarningSystem = WarningSystem or {}
-- Early ban check: runs before PlayerInitialSpawn
hook.Add("CheckPassword", "WarningSystem_EarlyBanCheck", function(steamID64, ip, svPassword, clPassword, name)
    local steamid = util.SteamIDFrom64(steamID64)
    local ban = WarningSystem.DB:GetActiveBan(steamid)
    if ban then
        local banDate = os.date("%d.%m.%Y %H:%M" or os.time())
        local banEnd = "Nie"
        if ban.unban_time and tonumber(ban.unban_time) > 0 then
            banEnd = os.date("%d.%m.%Y %H:%M")
        end
        local msg = "\n>>> Du wurdest vom Server verbannt <<<\n\nGrund: " .. (ban.reason or "") ..
            "\nBan Datum: " .. banDate ..
            "\nBan Ende: " .. banEnd ..
            "\nAdmin: " .. (ban.admin_name or "Unbekannt") ..
            "\nEntbannungsanträge via https://discord.gg/thrawnsrevenge"
        return false, msg
    end
end)
-- Initialize database on server start
hook.Add("Initialize", "WarningSystem_Init", function()
    WarningSystem.DB:Initialize()
    WarningSystem.Config:Load()
end)

-- Update player cache when they connect
hook.Add("PlayerInitialSpawn", "WarningSystem_PlayerCache", function(ply)
    WarningSystem.DB:UpdatePlayerCache(ply:SteamID(), ply:Nick())
end)

-- Core Functions
function WarningSystem:WarnPlayer(target_steamid, target_name, admin_ply, reason, temporary)
    local admin_steamid = IsValid(admin_ply) and admin_ply:SteamID() or "CONSOLE"
    local admin_name = IsValid(admin_ply) and admin_ply:Nick() or "Console"

    -- Update player cache
    WarningSystem.DB:UpdatePlayerCache(target_steamid, target_name)

    -- Calculate expiration if temporary warnings are enabled
    local expires = nil
    if temporary and WarningSystem.Config:Get("WarnDecayEnabled") then
        expires = os.time() + WarningSystem.Config:Get("WarnDecayTime")
    end

    -- Add warning to database
    local warn_id = WarningSystem.DB:AddWarning(target_steamid, target_name, admin_steamid, admin_name, reason, expires)

    -- Get current warning count
    local warnCount = WarningSystem.DB:GetActiveWarningCount(target_steamid)

    -- Notify online players
    local target = player.GetBySteamID(target_steamid)
    if IsValid(target) then
        target:ChatPrint("[Warning System] You have been warned by " .. admin_name)
        target:ChatPrint("Reason: " .. reason)
        target:ChatPrint("Total warnings: " .. warnCount .. "/" .. WarningSystem.Config:Get("MaxWarns"))
    end

    -- Notify admin
    if IsValid(admin_ply) then
        admin_ply:ChatPrint("[Warning System] " .. target_name .. " has been warned (" .. warnCount .. "/" .. WarningSystem.Config:Get("MaxWarns") .. ")")
    end

    -- Log to server console
    print(string.format("[Warning System] %s warned %s for: %s (%d/%d warnings)",
        admin_name, target_name, reason, warnCount, WarningSystem.Config:Get("MaxWarns")))

    -- Check if auto-ban should be triggered
    if WarningSystem.Config:Get("AutoBanEnabled") and warnCount >= WarningSystem.Config:Get("MaxWarns") then
        self:BanPlayer(target_steamid, target_name, admin_ply, "Exceeded maximum warnings (" .. warnCount .. ")", WarningSystem.Config:Get("BanDuration"))
    end

    -- Network update to all admins
    self:NetworkUpdate()

    return warn_id
end

function WarningSystem:BanPlayer(target_steamid, target_name, admin_ply, reason, duration)
    local admin_steamid = IsValid(admin_ply) and admin_ply:SteamID() or "CONSOLE"
    local admin_name = IsValid(admin_ply) and admin_ply:Nick() or "Console"

    -- Update player cache
    WarningSystem.DB:UpdatePlayerCache(target_steamid, target_name)

    -- Add ban to database
    local ban_id = WarningSystem.DB:AddBan(target_steamid, target_name, admin_steamid, admin_name, reason, duration)

    -- Build Nova ban parameters
    local comment = string.format("Banned by %s | Comment: %s", admin_name, reason)
    local internal_reason = "warningsystem_autoban"

    -- Get player if online
    local target = player.GetBySteamID(target_steamid)

    -- Ban via Nova - use player entity if online, otherwise use steamid
    if IsValid(target) then
        Nova.banPlayer(target, reason, comment, internal_reason, true)
        -- Kick player immediately (don't wait for Nova's 10 second delay)
        target:Kick(reason)
    else
        Nova.banPlayer(target_steamid, reason, comment, internal_reason, true)
    end

    -- Network update to all admins
    self:NetworkUpdate()

    return ban_id
end

function WarningSystem:RemoveWarning(warn_id, admin_ply)
    WarningSystem.DB:RemoveWarning(warn_id)

    if IsValid(admin_ply) then
        admin_ply:ChatPrint("[Warning System] Warning removed")
    end

    self:NetworkUpdate()
end

function WarningSystem:RemoveBan(ban_id, admin_ply)
    WarningSystem.DB:RemoveBan(ban_id)

    if IsValid(admin_ply) then
        admin_ply:ChatPrint("[Warning System] Ban removed")
    end

    self:NetworkUpdate()
end

function WarningSystem:UnbanPlayer(steamid, admin_ply)
    WarningSystem.DB:UnbanPlayer(steamid)

    Nova.unbanPlayer(steamid)

    if IsValid(admin_ply) then
        admin_ply:ChatPrint("[Warning System] Player unbanned")
    end

    self:NetworkUpdate()
end

function WarningSystem:ClearWarnings(steamid, admin_ply)
    WarningSystem.DB:ClearWarnings(steamid)

    if IsValid(admin_ply) then
        admin_ply:ChatPrint("[Warning System] All warnings cleared for player")
    end

    self:NetworkUpdate()
end

function WarningSystem:EditWarning(warn_id, new_reason, admin_ply)
    WarningSystem.DB:UpdateWarning(warn_id, new_reason)

    if IsValid(admin_ply) then
        admin_ply:ChatPrint("[Warning System] Warning updated")
    end

    self:NetworkUpdate()
end

function WarningSystem:EditBan(ban_id, new_reason, admin_ply)
    WarningSystem.DB:UpdateBan(ban_id, new_reason)

    if IsValid(admin_ply) then
        admin_ply:ChatPrint("[Warning System] Ban updated")
    end

    self:NetworkUpdate()
end

-- Network update function
function WarningSystem:NetworkUpdate()
    net.Start("WarningSystem_UpdateData")
    net.Broadcast()
end

-- Server console command to unban a player by SteamID
concommand.Add("ws_unban", function(_, _, args)
    if not args or not args[1] then
        print("[Warning System] Usage: ws_unban <steam64id>")
        return
    end
    local steam64 = args[1]
    local steamid = util.SteamIDFrom64(steam64)
    if not steamid or steamid == "STEAM_0:0:0" then
        print("[Warning System] Invalid Steam64 ID!")
        return
    end
    WarningSystem:UnbanPlayer(steamid)
    print("[Warning System] Unbanned player with Steam64 ID: " .. steam64 .. " (" .. steamid .. ")")
end)

-- Chat Commands
hook.Add("PlayerSay", "WarningSystem_Commands", function(ply, text)
    if not WarningSystem:HasPermission(ply) then return end

    local lower = string.lower(text)

    if lower == "!warns" or lower == "/warns" then
        net.Start("WarningSystem_OpenMenu")
        net.Send(ply)
        return ""
    end

    if lower == "!warnconfig" or lower == "/warnconfig" then
        net.Start("WarningSystem_OpenConfig")
        net.Send(ply)
        return ""
    end
end)
