WarningSystem = WarningSystem or {}
WarningSystem.DB = WarningSystem.DB or {}

-- JSON storage paths
local DATA_DIR = "warningsystem/"
local WARNINGS_FILE = DATA_DIR .. "warnings.json"
local BANS_FILE = DATA_DIR .. "bans.json"
local PLAYERS_FILE = DATA_DIR .. "players.json"

-- Auto-increment counters
local warnings_counter = 0
local bans_counter = 0

-- Helper functions for JSON operations
local function EnsureDataDir()
    if not file.Exists(DATA_DIR, "DATA") then
        file.CreateDir(string.gsub(DATA_DIR, "/$", ""))
    end
end

local function LoadJSON(filepath)
    if not file.Exists(filepath, "DATA") then
        return {}
    end

    local content = file.Read(filepath, "DATA")
    if not content or content == "" then
        return {}
    end

    local data = util.JSONToTable(content)
    return data or {}
end

local function SaveJSON(filepath, data)
    EnsureDataDir()
    local json = util.TableToJSON(data, true)
    file.Write(filepath, json)
end

local function GetNextID(data)
    local maxID = 0
    for _, entry in pairs(data) do
        if entry.id and tonumber(entry.id) > maxID then
            maxID = tonumber(entry.id)
        end
    end
    return maxID + 1
end

function WarningSystem.DB:Initialize()
    EnsureDataDir()

    -- Load initial data to set counters
    local warnings = LoadJSON(WARNINGS_FILE)
    local bans = LoadJSON(BANS_FILE)

    warnings_counter = GetNextID(warnings)
    bans_counter = GetNextID(bans)

    print("[Warning System] JSON Database initialized")
    print("[Warning System] Data directory: " .. DATA_DIR)
end

-- Player Cache
function WarningSystem.DB:UpdatePlayerCache(steamid, name)
    local players = LoadJSON(PLAYERS_FILE)

    players[steamid] = {
        steamid = steamid,
        playername = name,
        last_seen = os.time()
    }

    SaveJSON(PLAYERS_FILE, players)
end

function WarningSystem.DB:GetPlayerName(steamid)
    local players = LoadJSON(PLAYERS_FILE)

    if players[steamid] then
        return players[steamid].playername
    end

    return "Unknown Player"
end

function WarningSystem.DB:GetAllPlayers()
    local allPlayers = {}
    local playerMap = {}

    -- Get players from cache
    local players = LoadJSON(PLAYERS_FILE)
    for steamid, data in pairs(players) do
        playerMap[steamid] = {
            steamid = steamid,
            playername = data.playername,
            last_seen = data.last_seen
        }
    end

    -- Get players from warnings
    local warnings = LoadJSON(WARNINGS_FILE)
    for _, warning in pairs(warnings) do
        if not playerMap[warning.steamid] or playerMap[warning.steamid].last_seen < warning.timestamp then
            playerMap[warning.steamid] = {
                steamid = warning.steamid,
                playername = warning.playername,
                last_seen = warning.timestamp
            }
        end
    end

    -- Get players from bans
    local bans = LoadJSON(BANS_FILE)
    for _, ban in pairs(bans) do
        if not playerMap[ban.steamid] or playerMap[ban.steamid].last_seen < ban.timestamp then
            playerMap[ban.steamid] = {
                steamid = ban.steamid,
                playername = ban.playername,
                last_seen = ban.timestamp
            }
        end
    end

    -- Convert to array and sort by last_seen
    for _, player in pairs(playerMap) do
        table.insert(allPlayers, player)
    end

    table.sort(allPlayers, function(a, b)
        return (a.last_seen or 0) > (b.last_seen or 0)
    end)

    return allPlayers
end

-- Warning Functions
function WarningSystem.DB:AddWarning(steamid, playername, admin_steamid, admin_name, reason, expires)
    local warnings = LoadJSON(WARNINGS_FILE)

    local id = GetNextID(warnings)

    warnings[tostring(id)] = {
        id = id,
        steamid = steamid,
        playername = playername,
        admin_steamid = admin_steamid,
        admin_name = admin_name,
        reason = reason,
        timestamp = os.time(),
        expires_at = expires,
        active = 1
    }

    SaveJSON(WARNINGS_FILE, warnings)
    return id
end

function WarningSystem.DB:GetWarnings(steamid)
    local warnings = LoadJSON(WARNINGS_FILE)
    local result = {}

    for _, warning in pairs(warnings) do
        if warning.steamid == steamid and warning.active == 1 then
            table.insert(result, warning)
        end
    end

    -- Sort by timestamp descending
    table.sort(result, function(a, b)
        return a.timestamp > b.timestamp
    end)

    return result
end

function WarningSystem.DB:GetActiveWarningCount(steamid)
    local warnings = LoadJSON(WARNINGS_FILE)
    local count = 0
    local needsSave = false

    -- Update expired warnings first
    if WarningSystem.Config:Get("WarnDecayEnabled") then
        for key, warning in pairs(warnings) do
            if warning.steamid == steamid and warning.active == 1 then
                if warning.expires_at and warning.expires_at <= os.time() then
                    warnings[key].active = 0
                    needsSave = true
                end
            end
        end

        if needsSave then
            SaveJSON(WARNINGS_FILE, warnings)
        end
    end

    -- Count active warnings
    for _, warning in pairs(warnings) do
        if warning.steamid == steamid and warning.active == 1 then
            count = count + 1
        end
    end

    return count
end

function WarningSystem.DB:RemoveWarning(id)
    local warnings = LoadJSON(WARNINGS_FILE)

    warnings[tostring(id)] = nil

    SaveJSON(WARNINGS_FILE, warnings)
end

function WarningSystem.DB:UpdateWarning(id, reason)
    local warnings = LoadJSON(WARNINGS_FILE)

    if warnings[tostring(id)] then
        warnings[tostring(id)].reason = reason
        SaveJSON(WARNINGS_FILE, warnings)
    end
end

function WarningSystem.DB:ClearWarnings(steamid)
    local warnings = LoadJSON(WARNINGS_FILE)

    for key, warning in pairs(warnings) do
        if warning.steamid == steamid then
            warnings[key] = nil
        end
    end

    SaveJSON(WARNINGS_FILE, warnings)
end

-- Ban Functions
function WarningSystem.DB:AddBan(steamid, playername, admin_steamid, admin_name, reason, duration)
    local bans = LoadJSON(BANS_FILE)

    local id = GetNextID(bans)
    local unban_time = duration and (os.time() + duration) or nil

    bans[tostring(id)] = {
        id = id,
        steamid = steamid,
        playername = playername,
        admin_steamid = admin_steamid,
        admin_name = admin_name,
        reason = reason,
        timestamp = os.time(),
        unban_time = unban_time,
        active = 1
    }

    SaveJSON(BANS_FILE, bans)
    return id
end

function WarningSystem.DB:GetBans(steamid)
    local bans = LoadJSON(BANS_FILE)
    local result = {}

    for _, ban in pairs(bans) do
        if ban.steamid == steamid and ban.active == 1 then
            table.insert(result, ban)
        end
    end

    -- Sort by timestamp descending
    table.sort(result, function(a, b)
        return a.timestamp > b.timestamp
    end)

    return result
end

function WarningSystem.DB:GetActiveBan(steamid)
    local bans = LoadJSON(BANS_FILE)
    local needsSave = false

    -- First, deactivate expired bans
    for key, ban in pairs(bans) do
        if ban.steamid == steamid and ban.active == 1 then
            if ban.unban_time and ban.unban_time <= os.time() then
                bans[key].active = 0
                needsSave = true
            end
        end
    end

    if needsSave then
        SaveJSON(BANS_FILE, bans)
    end

    -- Find most recent active ban
    local activeBan = nil
    local latestTimestamp = 0

    for _, ban in pairs(bans) do
        if ban.steamid == steamid and ban.active == 1 then
            if ban.timestamp > latestTimestamp then
                activeBan = ban
                latestTimestamp = ban.timestamp
            end
        end
    end

    return activeBan
end

function WarningSystem.DB:RemoveBan(id)
    local bans = LoadJSON(BANS_FILE)

    bans[tostring(id)] = nil

    SaveJSON(BANS_FILE, bans)
end

function WarningSystem.DB:UpdateBan(id, reason)
    local bans = LoadJSON(BANS_FILE)

    if bans[tostring(id)] then
        bans[tostring(id)].reason = reason
        SaveJSON(BANS_FILE, bans)
    end
end

function WarningSystem.DB:UnbanPlayer(steamid)
    local bans = LoadJSON(BANS_FILE)

    for key, ban in pairs(bans) do
        if ban.steamid == steamid then
            bans[key].active = 0
        end
    end

    SaveJSON(BANS_FILE, bans)
end

-- Get all warnings/bans for overview
function WarningSystem.DB:GetAllWarnings()
    local warnings = LoadJSON(WARNINGS_FILE)
    local result = {}

    -- Count warnings per player
    local warnCounts = {}
    for _, warning in pairs(warnings) do
        if warning.active == 1 then
            warnCounts[warning.steamid] = (warnCounts[warning.steamid] or 0) + 1
        end
    end

    -- Build result with total_warns
    for _, warning in pairs(warnings) do
        if warning.active == 1 then
            local w = table.Copy(warning)
            w.total_warns = warnCounts[warning.steamid]
            table.insert(result, w)
        end
    end

    -- Sort by timestamp descending
    table.sort(result, function(a, b)
        return a.timestamp > b.timestamp
    end)

    return result
end

function WarningSystem.DB:GetAllBans()
    local bans = LoadJSON(BANS_FILE)
    local result = {}

    for _, ban in pairs(bans) do
        if ban.active == 1 then
            table.insert(result, ban)
        end
    end

    -- Sort by timestamp descending
    table.sort(result, function(a, b)
        return a.timestamp > b.timestamp
    end)

    return result
end
