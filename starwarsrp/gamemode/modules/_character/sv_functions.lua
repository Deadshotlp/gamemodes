PD.Char = PD.Char or {}

local playerTimers = {}

local function GetJobsTable()
    return PD.JOBS and PD.JOBS.Jobs or {}
end

function PD.Char:GetCharIndexByID(tbl, charID)
    if not istable(tbl) or not charID then return nil end

    for k, v in pairs(tbl) do
        if v.id == charID then
            return k
        end
    end
end

local function GetFirstModel(jobTable)
    if not istable(jobTable) then return nil end
    if istable(jobTable.model) then return jobTable.model[1] end
    if istable(jobTable.models) then return jobTable.models[1] end
    if isstring(jobTable.model) then return jobTable.model end
end

local function GetFallbackJob()
    local jobs = GetJobsTable()

    for unitIndex, unitData in pairs(jobs) do
        if unitData.default then
            for subIndex, subData in pairs(unitData.subunits or {}) do
                if subData.default then
                    for jobIndex, jobData in pairs(subData.jobs or {}) do
                        if jobData.default then
                            return unitIndex, subIndex, jobIndex, jobData
                        end
                    end
                end
            end
        end
    end

    local unitIndex, unitData = next(jobs)
    if not unitIndex or not unitData then return end

    local subIndex, subData = next(unitData.subunits or {})
    if not subIndex or not subData then return end

    local jobIndex, jobData = next(subData.jobs or {})
    if not jobIndex or not jobData then return end

    return unitIndex, subIndex, jobIndex, jobData
end

local function ResolveJobData(unitIndex, subIndex, jobIndex)
    local jobs = GetJobsTable()

    local jobTable = jobs[unitIndex]
        and jobs[unitIndex].subunits
        and jobs[unitIndex].subunits[subIndex]
        and jobs[unitIndex].subunits[subIndex].jobs
        and jobs[unitIndex].subunits[subIndex].jobs[jobIndex]

    if jobTable then
        return unitIndex, subIndex, jobIndex, jobTable
    end

    return GetFallbackJob()
end

local charDir = "modules/char"
local charFilePattern = "modules/char/*.json"
local charSQLTable = "pd_characters"
local migrationSaveTimeout = 15

local charCache = {}
local charStorageReady = false
local charStorageInitRunning = false

local function CharLog(msg)
    print("[PD.Char] " .. tostring(msg))
end

local function EnsureCharDir()
    if not file.IsDir(charDir, "DATA") then
        file.CreateDir(charDir)
    end
end

local function SQLAvailable()
    return PD.SQL and isfunction(PD.SQL.EscapeString) and isfunction(PD.SQL.Query)
end

local function SQLEscape(value)
    if SQLAvailable() then
        return PD.SQL.EscapeString(value)
    end

    local escaped = tostring(value or "")
    escaped = escaped:gsub("\\", "\\\\")
    escaped = escaped:gsub("\0", "\\0")
    escaped = escaped:gsub("\n", "\\n")
    escaped = escaped:gsub("\r", "\\r")
    escaped = escaped:gsub("\026", "\\Z")
    escaped = escaped:gsub("'", "\\'")
    escaped = escaped:gsub('"', '\\"')
    return "'" .. escaped .. "'"
end

local function SQLFetchOne(query, callback)
    if not SQLAvailable() then
        if isfunction(callback) then
            callback(nil)
        end
        return nil
    end

    if isfunction(PD.SQL.FetchOne) then
        return PD.SQL.FetchOne(query, callback)
    end

    return PD.SQL.Query(query, callback, true)
end

local function SQLFetchAll(query, callback)
    if not SQLAvailable() then
        if isfunction(callback) then
            callback({})
        end
        return nil
    end

    if isfunction(PD.SQL.FetchAll) then
        return PD.SQL.FetchAll(query, callback)
    end

    return PD.SQL.Query(query, callback, false)
end

local function SQLExecute(query, callback)
    if not SQLAvailable() then
        if isfunction(callback) then
            callback(false)
        end
        return nil
    end

    local fn = PD.SQL.Execute or PD.SQL.Query
    return fn(query, function(...)
        if isfunction(callback) then
            callback(true, ...)
        end
    end, false)
end

local function ReadLegacyCharFile(steamid64)
    EnsureCharDir()

    local path = charDir .. "/" .. tostring(steamid64) .. ".json"
    if not file.Exists(path, "DATA") then
        return nil
    end

    local raw = file.Read(path, "DATA")
    local data = util.JSONToTable(raw or "")
    return istable(data) and data or {}
end

local function LoadAllLegacyChars()
    EnsureCharDir()

    local all = {}
    for _, fileName in pairs(file.Find(charFilePattern, "DATA")) do
        local steamid = string.gsub(fileName, "%.json$", "")
        local data = util.JSONToTable(file.Read(charDir .. "/" .. fileName, "DATA") or "")
        all[steamid] = istable(data) and data or {}
    end

    return all
end

local function SaveLegacyCharFile(steamid64, chars)
    EnsureCharDir()
    file.Write(charDir .. "/" .. tostring(steamid64) .. ".json", util.TableToJSON(chars or {}, true) or "[]")
end

local function BuildCharEntries(chars)
    local entries = {}

    if not istable(chars) then
        return entries
    end

    for key, value in pairs(chars) do
        if istable(value) then
            local numericKey = tonumber(key)
            local slot = numericKey and math.floor(numericKey) or nil
            if not slot or slot < 1 then
                slot = #entries + 1
            end

            table.insert(entries, {
                slot = slot,
                data = value
            })
        end
    end

    table.sort(entries, function(a, b)
        return (a.slot or 0) < (b.slot or 0)
    end)

    for i = 1, #entries do
        if entries[i].slot == entries[i - 1] and entries[i - 1] ~= nil then
            entries[i].slot = i
        end
    end

    return entries
end

local function CountCharEntries(chars)
    return #BuildCharEntries(chars)
end

local function HasCharEntries(chars)
    return CountCharEntries(chars) > 0
end

local function EnsureCharSQLTable(callback)
    if not SQLAvailable() then
        if isfunction(callback) then
            callback(false)
        end
        return
    end

    local query = "CREATE TABLE IF NOT EXISTS `" .. charSQLTable .. "` ("
        .. "`steamid64` VARCHAR(32) NOT NULL,"
        .. "`slot_index` INT NOT NULL DEFAULT 1,"
        .. "`char_id` VARCHAR(64) NOT NULL,"
        .. "`char_name` VARCHAR(128) NOT NULL DEFAULT '',"
        .. "`char_rank` VARCHAR(128) NOT NULL DEFAULT '',"
        .. "`char_money` BIGINT NOT NULL DEFAULT 0,"
        .. "`char_playtime` BIGINT NOT NULL DEFAULT 0,"
        .. "`char_cratedate` VARCHAR(32) NOT NULL DEFAULT '',"
        .. "`char_lastplaytime` VARCHAR(32) NOT NULL DEFAULT '',"
        .. "`faction_unit` VARCHAR(128) NOT NULL DEFAULT '',"
        .. "`faction_subunit` VARCHAR(128) NOT NULL DEFAULT '',"
        .. "`faction_job` VARCHAR(128) NOT NULL DEFAULT '',"
        .. "`job_id` VARCHAR(128) NOT NULL DEFAULT '',"
        .. "`job_name` VARCHAR(128) NOT NULL DEFAULT '',"
        .. "`job_model` VARCHAR(255) NOT NULL DEFAULT '',"
        .. "`job_unit` VARCHAR(128) NOT NULL DEFAULT '',"
        .. "PRIMARY KEY (`steamid64`, `char_id`),"
        .. "KEY `idx_steam_slot` (`steamid64`, `slot_index`)"
        .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

    SQLExecute(query, function(ok)
        if not ok then
            if isfunction(callback) then
                callback(false)
            end
            return
        end

        SQLExecute("ALTER TABLE `" .. charSQLTable .. "` MODIFY `char_money` BIGINT NOT NULL DEFAULT 0", function(okMoney)
            if not okMoney then
                if isfunction(callback) then
                    callback(false)
                end
                return
            end

            SQLExecute("ALTER TABLE `" .. charSQLTable .. "` MODIFY `char_playtime` BIGINT NOT NULL DEFAULT 0", function(okPlaytime)
                if isfunction(callback) then
                    callback(okPlaytime == true)
                end
            end)
        end)
    end)
end

local NormalizeSafeInt

local function BuildCharFromRow(row)
    local char = {}

    char.id = row.char_id or ""
    char.name = row.char_name or ""
    char.rank = row.char_rank or ""
    char.money = NormalizeSafeInt(row.char_money)
    char.playtime = NormalizeSafeInt(row.char_playtime)
    char.cratedate = row.char_cratedate or ""
    char.lastplaytime = row.char_lastplaytime or ""

    char.faction = {
        unit = row.faction_unit or "",
        subunit = row.faction_subunit or "",
        job = row.faction_job or ""
    }

    char.job = {
        id = row.job_id or "",
        name = row.job_name or "",
        model = row.job_model or "",
        unit = row.job_unit or ""
    }

    return char
end

local function NormalizeJobModelValue(modelValue)
    if istable(modelValue) then
        return tostring(modelValue[1] or "")
    end

    return tostring(modelValue or "")
end

NormalizeSafeInt = function(value)
    local n = tonumber(value) or 0
    if n ~= n or n == math.huge or n == -math.huge then
        return 0
    end

    n = math.floor(n)

    if n > 2147483647 then
        return 2147483647
    end

    if n < -2147483648 then
        return -2147483648
    end

    return n
end

local function SaveSteamCharsToSQL(steamid64, chars, callback)
    if not SQLAvailable() or not isfunction(PD.SQL.Begin) or not isfunction(PD.SQL.Commit) then
        if isfunction(callback) then
            callback(false)
        end
        return
    end

    local addQuery = PD.SQL.Begin()
    if not isfunction(addQuery) then
        if isfunction(callback) then
            callback(false)
        end
        return
    end

    addQuery("DELETE FROM `" .. charSQLTable .. "` WHERE `steamid64` = " .. SQLEscape(steamid64))

    local allowedFields = {
        "steamid64", "slot_index", "char_id", "char_name", "char_rank", "char_money", "char_playtime",
        "char_cratedate", "char_lastplaytime", "faction_unit", "faction_subunit", "faction_job",
        "job_id", "job_name", "job_model", "job_unit"
    }

    local charEntries = BuildCharEntries(chars)

    for i = 1, #charEntries do
        local index = charEntries[i].slot
        local charData = charEntries[i].data
        local insertQuery = PD.SQL.BuildInsert(charSQLTable, {
            steamid64 = tostring(steamid64),
            slot_index = tonumber(index) or index,
            char_id = tostring(charData.id or ("char_" .. tostring(index))),
            char_name = tostring(charData.name or ""),
            char_rank = tostring(charData.rank or ""),
            char_money = NormalizeSafeInt(charData.money),
            char_playtime = NormalizeSafeInt(charData.playtime),
            char_cratedate = tostring(charData.cratedate or ""),
            char_lastplaytime = tostring(charData.lastplaytime or ""),
            faction_unit = tostring(charData.faction and charData.faction.unit or ""),
            faction_subunit = tostring(charData.faction and charData.faction.subunit or ""),
            faction_job = tostring(charData.faction and charData.faction.job or ""),
            job_id = tostring(charData.job and charData.job.id or ""),
            job_name = tostring(charData.job and charData.job.name or ""),
            job_model = NormalizeJobModelValue(charData.job and charData.job.model),
            job_unit = tostring(charData.job and charData.job.unit or "")
        }, allowedFields)

        if insertQuery then
            addQuery(insertQuery)
        end
    end

    PD.SQL.Commit(function()
        if isfunction(callback) then
            callback(true)
        end
    end, function(err)
        CharLog("SQL Save fehlgeschlagen: " .. tostring(err))
        if isfunction(callback) then
            callback(false)
        end
    end)
end

local function SaveSteamCharsToSQLWithTimeout(steamid64, chars, callback)
    local done = false
    local timerName = "PD.Char.MigrationTimeout." .. tostring(steamid64)

    if timer.Exists(timerName) then
        timer.Remove(timerName)
    end

    timer.Create(timerName, migrationSaveTimeout, 1, function()
        if done then return end
        done = true
        CharLog("Migration timeout fuer SteamID " .. tostring(steamid64))
        if isfunction(callback) then
            callback(false)
        end
    end)

    SaveSteamCharsToSQL(steamid64, chars, function(ok)
        if done then return end
        done = true

        if timer.Exists(timerName) then
            timer.Remove(timerName)
        end

        if isfunction(callback) then
            callback(ok)
        end
    end)
end

local function LoadAllCharsFromSQL(callback)
    SQLFetchAll("SELECT * FROM `" .. charSQLTable .. "` ORDER BY `steamid64` ASC, `slot_index` ASC", function(rows)
        local all = {}

        for i = 1, #(rows or {}) do
            local row = rows[i]
            local sid = tostring(row.steamid64 or "")
            if sid ~= "" then
                all[sid] = all[sid] or {}
                table.insert(all[sid], BuildCharFromRow(row))
            end
        end

        if isfunction(callback) then
            callback(all)
        end
    end)
end

function PD.Char:InitStorage()
    if charStorageInitRunning then return end
    charStorageInitRunning = true

    charCache = LoadAllLegacyChars()

    EnsureCharSQLTable(function(ok)
        if not ok then
            charStorageReady = false
            charStorageInitRunning = false
            CharLog("SQL nicht verfuegbar, nutze Legacy-JSON fuer Character")
            return
        end

        SQLFetchOne("SELECT COUNT(*) AS c FROM `" .. charSQLTable .. "`", function(countRow)
            local count = tonumber(countRow and countRow.c or 0) or 0

            if count > 0 then
                LoadAllCharsFromSQL(function(allFromSQL)
                    charCache = allFromSQL or {}
                    charStorageReady = true

                    local legacyAll = LoadAllLegacyChars()
                    local backfillQueue = {}

                    for sid, legacyChars in pairs(legacyAll) do
                        local sqlCount = CountCharEntries(charCache[sid])
                        local legacyCount = CountCharEntries(legacyChars)

                        if legacyCount > sqlCount then
                            table.insert(backfillQueue, {
                                sid = sid,
                                chars = legacyChars,
                                legacyCount = legacyCount,
                                sqlCount = sqlCount
                            })
                        end
                    end

                    table.sort(backfillQueue, function(a, b)
                        return tostring(a.sid) < tostring(b.sid)
                    end)

                    if #backfillQueue == 0 then
                        charStorageInitRunning = false
                        CharLog("Character aus SQL geladen")
                        return
                    end

                    CharLog("Starte Character-Backfill aus Legacy JSON: " .. tostring(#backfillQueue) .. " SteamIDs")

                    local function backfillNext(index)
                        local item = backfillQueue[index]
                        if not item then
                            charStorageInitRunning = false
                            CharLog("Character-Backfill abgeschlossen")
                            return
                        end

                        SaveSteamCharsToSQLWithTimeout(item.sid, item.chars, function(okSave)
                            if okSave then
                                charCache[item.sid] = table.Copy(item.chars)
                            else
                                CharLog("Backfill fehlgeschlagen fuer " .. tostring(item.sid))
                            end

                            if index % 25 == 0 then
                                CharLog("Backfill Fortschritt: " .. tostring(index) .. "/" .. tostring(#backfillQueue))
                            end

                            backfillNext(index + 1)
                        end)
                    end

                    backfillNext(1)
                end)
                return
            end

            local migratedAny = false
            for sid, chars in pairs(charCache) do
                if HasCharEntries(chars) then
                    migratedAny = true
                    break
                end
            end

            if not migratedAny then
                charStorageReady = true
                charStorageInitRunning = false
                CharLog("Keine Legacy-Character zur Migration gefunden")
                return
            end

            local migrationQueue = {}
            for sid, chars in pairs(charCache) do
                if HasCharEntries(chars) then
                    table.insert(migrationQueue, {
                        sid = sid,
                        chars = chars
                    })
                end
            end

            table.sort(migrationQueue, function(a, b)
                return tostring(a.sid) < tostring(b.sid)
            end)

            local function migrateNext(index)
                local item = migrationQueue[index]
                if not item then
                    charStorageReady = true
                    charStorageInitRunning = false
                    CharLog("Character JSON -> SQL Migration abgeschlossen")
                    return
                end

                SaveSteamCharsToSQLWithTimeout(item.sid, item.chars, function(okSave)
                    if not okSave then
                        SaveLegacyCharFile(item.sid, item.chars)
                        CharLog("Character Migration fehlgeschlagen fuer " .. tostring(item.sid))
                    end

                    if index % 25 == 0 then
                        CharLog("Migration Fortschritt: " .. tostring(index) .. "/" .. tostring(#migrationQueue))
                    end

                    migrateNext(index + 1)
                end)
            end

            migrateNext(1)
        end)
    end)
end

function PD.Char:SaveChar(plyid, tbl)
    local sid = tostring(plyid or "")
    if sid == "" then return end

    tbl = istable(tbl) and tbl or {}
    charCache[sid] = table.Copy(tbl)

    if charStorageReady then
        SaveSteamCharsToSQL(sid, charCache[sid], function(ok)
            if not ok then
                SaveLegacyCharFile(sid, charCache[sid])
            end
        end)
        return
    end

    SaveLegacyCharFile(sid, charCache[sid])
end

function PD.Char:LoadChar(plyid, wo)
    local sid = tostring(plyid or "")
    if sid == "" then
        return nil
    end

    if charCache[sid] then
        return table.Copy(charCache[sid])
    end

    local legacy = ReadLegacyCharFile(sid)
    if legacy then
        charCache[sid] = legacy
        return table.Copy(legacy)
    end

    print("Char Daten nicht gefunden (" .. tostring(sid) .. " | " .. tostring(wo) .. ")")
    return nil
end

function PD.Char:LoadAllChars()
    if next(charCache) == nil then
        charCache = LoadAllLegacyChars()
    end

    return table.Copy(charCache)
end

hook.Add("PostPDLoaded", "PD.Char.InitStorage", function()
    PD.Char:InitStorage()
end)

PD.Char:InitStorage()

function PD.Char:SyncChar(ply, wo)
    if not IsValid(ply) then return end

    local tbl = PD.Char:LoadChar(ply:SteamID64(), wo)

    net.Start("PD.Char.Synccl")
    net.WriteTable(tbl or {})
    net.Send(ply)
end

function PD.Char:SetPlayerCharID(ply, setid)
    if not IsValid(ply) then return false end

    if setid and setid ~= "" and setid ~= "9999" then
        ply.CharID = setid
        ply:SetNWString("character_id", setid)
        return setid
    end

    local nwID = ply:GetNWString("character_id", "9999")
    if nwID ~= "9999" and nwID ~= "" then
        ply.CharID = nwID
        return nwID
    end

    ply.CharID = nil
    ply:SetNWString("character_id", "9999")
    return false
end

function PD.Char:GetCharacterID(ply)
    if not IsValid(ply) then return false end

    if ply.CharID and ply.CharID ~= "" and ply.CharID ~= "9999" then
        return ply.CharID
    end

    local nwID = ply:GetNWString("character_id", "9999")
    if nwID ~= "9999" and nwID ~= "" then
        ply.CharID = nwID
        return nwID
    end

    return false
end

function PD.Char:GetPlayerCharTBL(ply)
    if not IsValid(ply) then return nil end

    local tbl = PD.Char:LoadChar(ply:SteamID64(), "GetPlayerCharTBL")
    if not tbl then return nil end

    local charID = PD.Char:GetCharacterID(ply)
    if not charID then return nil end

    local charIndex = PD.Char:GetCharIndexByID(tbl, charID)
    if not charIndex then return nil end

    return tbl[charIndex]
end

function PD.Char:UpdateStoredCharJobData(steamid, charID, unitIndex, subIndex, jobID)
    if not steamid or not charID then return false end

    local tbl = PD.Char:LoadChar(steamid, "UpdateStoredCharJobData")
    if not tbl then return false end

    local charIndex = PD.Char:GetCharIndexByID(tbl, charID)
    if not charIndex or not tbl[charIndex] then return false end

    local resolvedUnit, resolvedSub, resolvedJob, jobTable = ResolveJobData(unitIndex, subIndex, jobID)
    if not resolvedUnit or not resolvedSub or not resolvedJob or not jobTable then return false end

    tbl[charIndex].faction = {
        unit = resolvedUnit,
        subunit = resolvedSub,
        job = resolvedJob
    }

    tbl[charIndex].job = {
        name = jobTable.name,
        model = GetFirstModel(jobTable) or "",
        unit = resolvedSub,
        id = resolvedJob
    }

    PD.Char:SaveChar(steamid, tbl)
    return true, tbl[charIndex], jobTable
end

function PD.Char:ChangePlayerJob(ply, jobID, unitIndex, subIndex)
    if not IsValid(ply) then return end

    local charID = PD.Char:GetCharacterID(ply)
    if not charID then
        print("Kein aktiver Char für ChangePlayerJob gefunden.")
        return
    end

    local ok, _, jobTable = PD.Char:UpdateStoredCharJobData(ply:SteamID64(), charID, unitIndex, subIndex, jobID)
    if not ok then
        print("Char nicht gefunden.")
        return
    end

    if jobTable then
        ply:SetJob(jobID, jobTable)
    end

    PD.Char:SyncChar(ply, "ChangePlayerJob")
end

function PD.Char:StartTimer(playerSteamID)
    if not playerTimers[playerSteamID] then
        playerTimers[playerSteamID] = RealTime()
    end
end

function PD.Char:GetTimer(playerSteamID)
    return playerTimers[playerSteamID] ~= nil
end

function PD.Char:StopTimer(playerSteamID)
    if not playerTimers[playerSteamID] then
        return 0
    end

    local elapsedTime = RealTime() - playerTimers[playerSteamID]
    playerTimers[playerSteamID] = nil

    return elapsedTime or 0
end

function getRightJob(info)
    local unitIndex = info and info.jobunitIndex
    local subIndex = info and info.jobsubunitIndex
    local jobIndex = info and info.jobIndex

    local resolvedUnit, resolvedSub, resolvedJob, jobTable = ResolveJobData(unitIndex, subIndex, jobIndex)
    if not resolvedUnit or not resolvedSub or not resolvedJob or not jobTable then
        return nil, nil
    end

    return resolvedJob, jobTable, resolvedUnit, resolvedSub
end

function PD.Char:PlayerSetChar(ply, charIndex)
    if not IsValid(ply) then return end

    local chars = PD.Char:LoadChar(ply:SteamID64(), "PlayerSetChar")
    if not chars or not chars[charIndex] then return end

    local oldCharID = PD.Char:GetCharacterID(ply)
    if oldCharID then
        local oldCharIndex = PD.Char:GetCharIndexByID(chars, oldCharID)
        if oldCharIndex and chars[oldCharIndex] then
            chars[oldCharIndex].playtime = (chars[oldCharIndex].playtime or 0) + PD.Char:StopTimer(ply:SteamID64())
            chars[oldCharIndex].lastplaytime = os.date("%d.%m.%Y %H:%M:%S", os.time())
        else
            PD.Char:StopTimer(ply:SteamID64())
        end
    else
        PD.Char:StopTimer(ply:SteamID64())
    end

    local charData = chars[charIndex]
    local unitIndex, subIndex, jobIndex, jobTable = ResolveJobData(
        charData.faction and charData.faction.unit,
        charData.faction and charData.faction.subunit,
        charData.faction and charData.faction.job
    )

    if not unitIndex or not subIndex or not jobIndex or not jobTable then
        print("Kein Job für PlayerSetChar gefunden.")
        return
    end

    charData.faction = {
        unit = unitIndex,
        subunit = subIndex,
        job = jobIndex
    }

    charData.job = {
        name = jobTable.name,
        model = GetFirstModel(jobTable) or "",
        unit = subIndex,
        id = jobIndex
    }

    charData.lastplaytime = os.date("%d.%m.%Y %H:%M:%S", os.time())

    ply.CharID = charData.id
    ply:SetNWString("character_id", charData.id)
    ply:SetNWString("rpname", charData.id .. " " .. charData.name)

    PD.Char:SaveChar(ply:SteamID64(), chars)
    PD.Char:StartTimer(ply:SteamID64())
    PD.Char:SyncChar(ply, "PlayerSetChar")

    ply:changeTeam({
        jobIndex = jobIndex,
        jobsubunitIndex = subIndex,
        jobunitIndex = unitIndex
    }, true)

    ply:SetJob(jobIndex, jobTable)
    ply:SetModel(GetFirstModel(jobTable) or ply:GetModel())

    if PD.List and PD.List.SetPlayerFaction then
        PD.List:SetPlayerFaction(ply, unitIndex, subIndex, jobIndex)
    end

    net.Start("PD.Char.JobChange")
    net.WriteEntity(ply)
    net.WriteString(jobIndex)
    net.WriteTable(jobTable or {})
    net.WriteTable(GetAllPlayerJobs and GetAllPlayerJobs() or {})
    net.Broadcast()

    return jobIndex
end

function PD.Char:PlayerActiveChar(ply)
    if not IsValid(ply) then return false end

    local tbl = PD.Char:LoadChar(ply:SteamID64(), "PlayerActiveChar")
    if not tbl then return false end

    local charID = PD.Char:GetCharacterID(ply)
    if not charID then return false end

    local charIndex = PD.Char:GetCharIndexByID(tbl, charID)
    if not charIndex then return false end

    return tbl[charIndex]
end

local PLAYER = FindMetaTable("Player")

function PLAYER:changeTeam(jobindexTable, force)
    if not jobindexTable then return end

    local jobindex, jobTable = getRightJob({
        jobIndex = jobindexTable.jobIndex,
        jobsubunitIndex = jobindexTable.jobsubunitIndex,
        jobunitIndex = jobindexTable.jobunitIndex
    })

    if not jobindex or not jobTable then
        print("Job kann nicht gewechselt werden.")
        return
    end

    self:StripWeapons()
    self:UnSpectate()

    if force then
        self:KillSilent()
        self:Spawn()
    end

    self:SetHealth(jobTable.maxhealth or 100)
    self:SetArmor(jobTable.startarmor or 0)
    self:SetMaxHealth(jobTable.maxhealth or 100)
    self:SetMaxArmor(jobTable.maxarmor or 100)
    self:SetWalkSpeed(175)
    self:SetRunSpeed(250)
    self:SetJob(jobindex, jobTable)

    if PD.Admin and (self:IsAdmin() or (PD.Admin.Ranks and PD.Admin.Ranks[self:GetUserGroup()])) then
        for _, v in SortedPairs(PD.Admin.Equip or {}) do
            self:Give(v)
        end
    end

    for _, v in SortedPairs(jobTable.equip or {}) do
        self:Give(v)
    end

    local jobs = GetJobsTable()
    local subunit = jobs[jobindexTable.jobunitIndex]
        and jobs[jobindexTable.jobunitIndex].subunits
        and jobs[jobindexTable.jobunitIndex].subunits[jobindexTable.jobsubunitIndex]

    for _, v in SortedPairs(subunit and subunit.equip or {}) do
        self:Give(v)
    end

    local mdl = GetFirstModel(jobTable)
    if mdl then
        self:SetModel(mdl)
    end

    hook.Run("PlayerChangedChar", self)
end

function PLAYER:SetJob(jobID, jobTbl)
    self.JobID = jobID
    self.JobTbl = jobTbl
end

function PLAYER:GetJob()
    if self.JobID and self.JobTbl then
        return self.JobID, self.JobTbl
    end

    local _, _, fallbackID, fallbackTbl = GetFallbackJob()
    self.JobID = self.JobID or fallbackID
    self.JobTbl = self.JobTbl or fallbackTbl

    return self.JobID, self.JobTbl
end

local function SetPlayerPhaseModel(ply)
    local _, jobTable = ply:GetJob()
    local mdl = GetFirstModel(jobTable) or CONFIG.BackModel

    if mdl then
        ply:SetModel(mdl)
    end

    ply:SetColor(color_white)
    ply:SetMaterial("")
    ply:SetRenderMode(RENDERMODE_NORMAL)
    ply:SetModelScale(1, 0)

    if ply.SetBodygroup and ply.PD_Bodygroups then
        for id, val in pairs(ply.PD_Bodygroups) do
            ply:SetBodygroup(id, val)
        end
    end
end

hook.Add("PlayerSpawn", "PD.Char.SetModelOnSpawn", function(ply)
    local _, jobTable = ply:GetJob()

    local mdl = GetFirstModel(jobTable)
    if mdl then
        ply:SetModel(tostring(mdl))
    end

    ply:StripWeapons()

    if PD.Admin and (ply:IsAdmin() or (PD.Admin.Ranks and PD.Admin.Ranks[ply:GetUserGroup()])) then
        for _, v in SortedPairs(PD.Admin.Equip or {}) do
            ply:Give(v)
        end
    end

    for _, v in SortedPairs(jobTable and jobTable.equip or {}) do
        ply:Give(v)
    end

    local jobs = GetJobsTable()
    local subunit = jobs[jobTable and jobTable.unit]
        and jobs[jobTable.unit].subunits
        and jobs[jobTable.unit].subunits[jobTable.unit]

    for _, v in SortedPairs(subunit and subunit.equip or {}) do
        ply:Give(v)
    end

    timer.Simple(0, function()
        if not IsValid(ply) then return end
        SetPlayerPhaseModel(ply)
    end)
end)