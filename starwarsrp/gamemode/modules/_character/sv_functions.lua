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

local charSQLTable = "pd_characters"
local reloadTimeout = 20

--[[
    Charakterdaten liegen nur noch in der Datenbank (pd_characters). Die
    frueheren JSON-Dateien unter data/modules/char werden weder gelesen noch
    geschrieben.

    Der Zwischenspeicher haengt an PD.Char, damit ein Lua-Refresh dieser Datei
    nicht alle Charaktere vergisst.

    pending: SteamIDs, die gespeichert wurden, waehrend die Datenbank gerade
    geladen wurde. Ihr Stand im Speicher ist neuer als das, was aus der
    Datenbank kommt - er gewinnt und wird danach nachgeschrieben.
]]
PD.Char.Storage = PD.Char.Storage or {
    cache = {},
    ready = false,
    pending = {}
}

local storage = PD.Char.Storage
storage.renaming = storage.renaming or {}
storage.loading = false
storage.callbacks = {}
storage.token = nil

local function CharLog(msg)
    print("[PD.Char] " .. tostring(msg))
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

    return entries
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
        if isfunction(callback) then
            callback(ok == true)
        end
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

    --[[
        Upsert je Charakter statt "alle loeschen und neu einfuegen": Zeilen
        bleiben erhalten (eine fortlaufende id-Spalte bleibt stabil), und es
        wird nur geloescht, was es im Speicher nicht mehr gibt. Der Schluessel
        fuer ON DUPLICATE KEY ist der Primaerschluessel (steamid64, char_id)
        bzw. nach einer Migration der eindeutige Schluessel auf char_id.
        steamid64 und char_id werden dabei nie ueberschrieben.
    ]]
    local allowedFields = {
        "steamid64", "slot_index", "char_id", "char_name", "char_rank", "char_money", "char_playtime",
        "char_cratedate", "char_lastplaytime", "faction_unit", "faction_subunit", "faction_job",
        "job_id", "job_name", "job_model", "job_unit"
    }

    local updateParts = {}
    for _, field in ipairs(allowedFields) do
        if field ~= "steamid64" and field ~= "char_id" then
            updateParts[#updateParts + 1] = "`" .. field .. "` = VALUES(`" .. field .. "`)"
        end
    end
    local onDuplicate = " ON DUPLICATE KEY UPDATE " .. table.concat(updateParts, ", ")

    local charEntries = BuildCharEntries(chars)

    local keepIDs = {}
    for i = 1, #charEntries do
        keepIDs[#keepIDs + 1] = SQLEscape(tostring(charEntries[i].data.id or ("char_" .. tostring(charEntries[i].slot))))
    end

    if #keepIDs > 0 then
        addQuery("DELETE FROM `" .. charSQLTable .. "` WHERE `steamid64` = " .. SQLEscape(steamid64)
            .. " AND `char_id` NOT IN (" .. table.concat(keepIDs, ", ") .. ")")
    else
        addQuery("DELETE FROM `" .. charSQLTable .. "` WHERE `steamid64` = " .. SQLEscape(steamid64))
    end

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
            addQuery(insertQuery .. onDuplicate)
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

local function FinishReload(token, ok, count)
    if storage.token ~= token then return end

    storage.token = nil
    storage.loading = false
    timer.Remove("PD.Char.ReloadTimeout")

    local callbacks = storage.callbacks
    storage.callbacks = {}

    for _, cb in ipairs(callbacks) do
        cb(ok, count)
    end
end

--[[
    Alle Charaktere aus der Datenbank laden. Beim Start und nach Aenderungen
    von aussen (Web-Panel, pd_reload chars).
]]
function PD.Char:ReloadFromSQL(callback)
    if isfunction(callback) then
        table.insert(storage.callbacks, callback)
    end

    if storage.loading then return end

    storage.loading = true

    local token = {}
    storage.token = token

    -- Eine fehlgeschlagene Abfrage ruft keinen Callback auf. Ohne Zeitgrenze
    -- bliebe loading dann fuer immer gesetzt und nichts wuerde mehr geladen.
    timer.Create("PD.Char.ReloadTimeout", reloadTimeout, 1, function()
        if storage.token ~= token then return end

        CharLog("Laden der Charaktere hat nach " .. reloadTimeout .. "s nicht geantwortet")
        FinishReload(token, false, 0)
    end)

    EnsureCharSQLTable(function(ok)
        if storage.token ~= token then return end

        if not ok then
            CharLog("Tabelle " .. charSQLTable .. " nicht verfuegbar - Charaktere nicht geladen")
            FinishReload(token, false, 0)
            return
        end

        LoadAllCharsFromSQL(function(all)
            if storage.token ~= token then return end

            all = all or {}

            local pending = storage.pending
            storage.pending = {}

            local resave = {}

            for sid in pairs(pending) do
                if storage.cache[sid] then
                    all[sid] = table.Copy(storage.cache[sid])
                    resave[sid] = true
                end
            end

            local firstLoad = not storage.ready

            storage.cache = all
            storage.ready = true

            for sid in pairs(resave) do
                SaveSteamCharsToSQL(sid, all[sid], function(saved)
                    if not saved then
                        CharLog("Nachschreiben fehlgeschlagen fuer " .. sid)
                    end
                end)
            end

            local count = table.Count(all)
            CharLog(count .. " Spieler mit Charakteren aus der Datenbank geladen")

            FinishReload(token, true, count)
            hook.Run("PD.Char.StorageLoaded", firstLoad)
        end)
    end)
end

function PD.Char:IsStorageReady()
    return storage.ready == true
end

function PD.Char:InitStorage()
    if storage.ready then return end

    PD.Char:ReloadFromSQL()
end

function PD.Char:SaveChar(plyid, tbl)
    local sid = tostring(plyid or "")
    if sid == "" then return end

    tbl = istable(tbl) and tbl or {}
    storage.cache[sid] = table.Copy(tbl)

    -- Laeuft gerade ein Laden, wuerde es diesen Stand gleich wieder mit dem
    -- aelteren aus der Datenbank ueberschreiben.
    if storage.loading or not storage.ready then
        storage.pending[sid] = true
    end

    if not storage.ready then
        -- Wird nach dem Laden nachgeschrieben (ReloadFromSQL).
        return
    end

    -- Laeuft fuer diesen Spieler gerade eine ID-Umbenennung, wuerde ein
    -- Speichern mit der alten ID die Zeile neu anlegen. Danach nachholen.
    if storage.renaming[sid] then
        storage.renaming[sid] = "dirty"
        return
    end

    SaveSteamCharsToSQL(sid, storage.cache[sid], function(ok)
        if not ok then
            storage.pending[sid] = true
            CharLog("Speichern fehlgeschlagen fuer " .. sid .. " - wird beim naechsten Laden erneut geschrieben")
        end
    end)
end

function PD.Char:LoadChar(plyid, wo)
    local sid = tostring(plyid or "")
    if sid == "" then
        return nil
    end

    if storage.cache[sid] then
        return table.Copy(storage.cache[sid])
    end

    return nil
end

function PD.Char:LoadAllChars()
    return table.Copy(storage.cache)
end

--[[
    Charakter-ID aendern (Admin-Menue).

    Die ID steht ausser in pd_characters auch in den Fortbildungstabellen und
    in pd_forced_models (Web-Panel). Alles wird in einer Transaktion
    umgeschrieben; erst wenn sie gelingt, werden Speicher, Fraktionsbaum,
    Fortbildungen und der Name des Spielers nachgezogen.

    callback(ok, fehlertext)
]]
local RENAME_TABLES = {
    {tbl = "pd_characters", col = "char_id"},
    {tbl = "pd_fb_granted", col = "char_id"},
    {tbl = "pd_fb_participants", col = "char_id"},
    {tbl = "pd_fb_sessions", col = "instructor_char"},
    {tbl = "pd_forced_models", col = "char_id"},
}

local CHAR_ID_MAX = 32

function PD.Char:IsValidCharID(id)
    id = tostring(id or "")
    return #id >= 1 and #id <= CHAR_ID_MAX and string.match(id, "^[%w%-_]+$") ~= nil
end

-- Vergleich ohne Gross-/Kleinschreibung: die Datenbank-Kollation
-- unterscheidet sie ebenfalls nicht.
function PD.Char:IsCharIDTaken(id, exceptID)
    local wanted = string.lower(tostring(id))
    local except = exceptID and string.lower(tostring(exceptID))

    for _, chars in pairs(storage.cache) do
        for _, char in pairs(chars or {}) do
            local cid = string.lower(tostring(char.id or ""))
            if cid == wanted and cid ~= except then
                return true
            end
        end
    end

    return false
end

function PD.Char:RenameCharID(steamid, oldID, newID, callback)
    callback = isfunction(callback) and callback or function() end

    local sid = tostring(steamid or "")
    oldID = tostring(oldID or "")
    newID = string.Trim(tostring(newID or ""))

    if oldID == newID then return callback(true) end
    if not storage.ready then return callback(false, "Charaktere werden noch geladen.") end
    if not PD.Char:IsValidCharID(newID) then
        return callback(false, "Ungültige ID: 1-" .. CHAR_ID_MAX .. " Zeichen, nur Buchstaben, Ziffern, - und _.")
    end
    if PD.Char:IsCharIDTaken(newID, oldID) then return callback(false, "Die ID " .. newID .. " ist bereits vergeben.") end
    if storage.renaming[sid] then return callback(false, "Für diesen Spieler läuft bereits eine Änderung.") end

    local chars = storage.cache[sid]
    local index = chars and PD.Char:GetCharIndexByID(chars, oldID)
    if not index then return callback(false, "Charakter " .. oldID .. " nicht gefunden.") end

    local names = {}
    for _, entry in ipairs(RENAME_TABLES) do
        names[#names + 1] = SQLEscape(entry.tbl)
    end

    storage.renaming[sid] = true

    local function finish(ok, err)
        local dirty = storage.renaming[sid] == "dirty"
        storage.renaming[sid] = nil

        -- Waehrend der Umbenennung aufgelaufene Aenderungen nachschreiben.
        if dirty and storage.cache[sid] then
            PD.Char:SaveChar(sid, storage.cache[sid])
        end

        callback(ok, err)
    end

    -- Nur Tabellen anfassen, die es gibt: pd_forced_models legt das Web-Panel an.
    SQLFetchAll("SELECT `table_name` AS `t` FROM information_schema.tables WHERE `table_schema` = DATABASE() AND `table_name` IN ("
        .. table.concat(names, ", ") .. ")", function(rows)
        local existing = {}
        for _, row in ipairs(rows or {}) do
            existing[row.t] = true
        end

        local addQuery = PD.SQL.Begin()
        if not isfunction(addQuery) then
            return finish(false, "Keine Datenbankverbindung.")
        end

        for _, entry in ipairs(RENAME_TABLES) do
            if existing[entry.tbl] then
                addQuery("UPDATE `" .. entry.tbl .. "` SET `" .. entry.col .. "` = " .. SQLEscape(newID)
                    .. " WHERE `" .. entry.col .. "` = " .. SQLEscape(oldID))
            end
        end

        PD.SQL.Commit(function()
            -- Speicher: Charakter
            local current = storage.cache[sid]
            local i = current and PD.Char:GetCharIndexByID(current, oldID)
            if i then
                current[i].id = newID
            end

            -- Speicher: Fortbildungen
            if PD.FB and PD.FB.Granted and PD.FB.Granted[oldID] then
                PD.FB.Granted[newID] = PD.FB.Granted[oldID]
                PD.FB.Granted[oldID] = nil

                for _, grant in pairs(PD.FB.Granted[newID]) do
                    grant.char_id = newID
                end
            end

            -- Spieler online mit diesem Charakter
            local ply = player.GetBySteamID64(sid)
            if IsValid(ply) then
                if PD.Char:GetCharacterID(ply) == oldID then
                    ply.CharID = newID
                    ply:SetNWString("character_id", newID)
                    ply:SetNWString("rpname", PD.Char.BuildRPName(newID, i and current[i].name or ""))
                end

                PD.Char:SyncChar(ply, "RenameCharID")
            end

            if PD.List and PD.List.LoadFactions then
                PD.List:LoadFactions()
                PD.List:SyncAll()
            end

            if PD.FB and PD.FB.Ready then
                if IsValid(ply) and PD.FB.SyncPlayer then PD.FB.SyncPlayer(ply) end
                if PD.FB.SyncPublicBadges then PD.FB.SyncPublicBadges() end
            end

            finish(true)
        end, function(err)
            CharLog("Umbenennen " .. oldID .. " -> " .. newID .. " fehlgeschlagen: " .. tostring(err))
            finish(false, "Datenbankfehler: " .. tostring(err))
        end)
    end)
end

hook.Add("PostPDLoaded", "PD.Char.InitStorage", function()
    PD.Char:InitStorage()
end)

-- Beim Start kann die Datenbank noch nicht verbunden sein - dann nachholen.
hook.Add("PD.Gamemode.DatabaseConnected", "PD.Char.LoadOnConnect", function()
    if not storage.ready then
        PD.Char:ReloadFromSQL()
    end
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
    ply:SetNWString("rpname", PD.Char.BuildRPName(charData.id, charData.name))

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

--[[
    Aenderungen von aussen (Web-Panel, pd_reload chars) auf verbundene Spieler
    anwenden: Name, Zuordnung und geloeschte Charaktere.
]]
function PD.Char:ApplyStoredToOnlinePlayers()
    for _, ply in ipairs(player.GetAll()) do
        local charID = PD.Char:GetCharacterID(ply)

        if charID then
            local chars = PD.Char:LoadChar(ply:SteamID64(), "ApplyStored") or {}
            local index = PD.Char:GetCharIndexByID(chars, charID)
            local char = index and chars[index]

            if not char then
                -- Der aktive Charakter wurde geloescht.
                PD.Char:StopTimer(ply:SteamID64())
                ply.CharID = nil
                ply:SetNWString("character_id", "9999")
                ply:SetNWString("rpname", "")

                PD.Char:SyncChar(ply, "ApplyStored")

                net.Start("OpenCharbyDelete")
                net.Send(ply)
            else
                ply:SetNWString("rpname", PD.Char.BuildRPName(char.id, char.name))
                PD.Char:SyncChar(ply, "ApplyStored")

                local faction = char.faction or {}

                if faction.job and faction.job ~= "" and faction.job ~= ply.JobID
                    and PD.List and PD.List.SetPlayerFaction then
                    PD.List:SetPlayerFaction(ply, faction.unit, faction.subunit, faction.job)
                end
            end
        end
    end
end

--[[
    Nach dem Nachladen der Jobs (Web-Panel, Job-Editor) zeigen verbundene
    Spieler noch auf die alten Job-Tabellen: neue Waffen- und Modellisten
    griffen erst nach einem Jobwechsel. Hier auf die frischen Tabellen
    umhaengen.
]]
function PD.Char:RefreshJobTables()
    for _, ply in ipairs(player.GetAll()) do
        local jobID = ply.JobID

        if jobID and jobID ~= "" then
            local fresh

            for _, unitData in pairs(GetJobsTable()) do
                for _, subData in pairs(unitData.subunits or {}) do
                    if subData.jobs and subData.jobs[jobID] then
                        fresh = subData.jobs[jobID]
                        break
                    end
                end

                if fresh then break end
            end

            if fresh and fresh ~= ply.JobTbl then
                local changed = util.TableToJSON(ply.JobTbl or {}) ~= util.TableToJSON(fresh)

                ply:SetJob(jobID, fresh)

                if changed then
                    net.Start("PD.Char.JobChange")
                    net.WriteEntity(ply)
                    net.WriteString(jobID)
                    net.WriteTable(fresh)
                    net.WriteTable(GetAllPlayerJobs and GetAllPlayerJobs() or {})
                    net.Broadcast()
                end
            end
        end
    end
end

-- Anzeigenamen verbundener Spieler neu setzen, damit ein geaendertes Format
-- (z. B. das CT-Praefix) ohne Charakterwechsel greift.
timer.Simple(0, function()
    for _, ply in ipairs(player.GetAll()) do
        local char = PD.Char:GetPlayerCharTBL(ply)

        if char then
            ply:SetNWString("rpname", PD.Char.BuildRPName(char.id, char.name))
        end
    end
end)

hook.Add("PD.JOBS.Loaded", "PD.Char.RefreshJobTables", function()
    PD.Char:RefreshJobTables()
end)

local PLAYER = FindMetaTable("Player")

--------------------------------------------------------------------------------
-- Bewegungsgeschwindigkeit
--------------------------------------------------------------------------------

--[[
    Grundgeschwindigkeit. Diese Werte standen bisher dreimal fest im Code -
    beim Jobwechsel und in beiden Respawn-Wegen.

    Beim Spawn setzt die Spielerklasse ihre eigenen Werte und ueberschreibt
    damit alles, was vorher gesetzt war. Aktiv ist player_sandbox mit
    WalkSpeed 200, RunSpeed 400 und SlowWalkSpeed 100 - Sandbox weist sie in
    GM:PlayerSpawn jedem Spieler zu. Die eigene Klasse player_pdgm wird zwar
    registriert, aber nirgends zugewiesen und greift deshalb nie.
]]
PD.Char.BaseWalkSpeed = 175
PD.Char.BaseRunSpeed = 250

-- Geschwindigkeit beim langsamen Gehen (+walk). Entspricht dem Wert der
-- aktiven Sandbox-Klasse und darf angepasst werden.
PD.Char.BaseSlowWalkSpeed = 100

--[[
    Die Geschwindigkeit eines Spielers setzen.

    Der Job skaliert sie ueber sein Feld 'speed': 100 bedeutet unveraendert,
    120 ein Fuenftel schneller. Das Feld gibt es im Job-Editor und in der
    Datenbank seit jeher - angewendet hat es bisher niemand.

    Ein ueber PD.Char.SetSpeed gesetzter Wert geht vor und uebersteht Respawn
    und Jobwechsel, weil er am Spieler haengt und nicht am Ablauf.
]]
function PD.Char.ApplySpeed(ply)
    if not IsValid(ply) then return end

    local walk, run = PD.Char.BaseWalkSpeed, PD.Char.BaseRunSpeed
    local slow = PD.Char.BaseSlowWalkSpeed
    local fest = ply.PD_Speed

    if istable(fest) then
        walk = tonumber(fest.walk) or walk
        run = tonumber(fest.run) or run
        slow = tonumber(fest.slow) or slow
    else
        local _, jobTable = ply:GetJob()
        local faktor = (tonumber(istable(jobTable) and jobTable.speed or nil) or 100) / 100

        -- Ein Job mit 0 oder einem Unsinnswert soll niemanden festnageln.
        if faktor <= 0 then faktor = 1 end

        walk = math.Round(walk * faktor)
        run = math.Round(run * faktor)
        slow = math.Round(slow * faktor)
    end

    -- Damit andere Module nachjustieren koennen, etwa fuer eine Verletzung
    -- oder getragene Last, ohne diese Funktion anfassen zu muessen.
    local a, b = hook.Run("PD_Speed_Applied", ply, walk, run)

    if isnumber(a) then walk = a end
    if isnumber(b) then run = b end

    ply:SetWalkSpeed(walk)
    ply:SetRunSpeed(run)

    -- Heisst SetSlowWalkSpeed. Ein blosses SlowWalkSpeed gibt es auf dem
    -- Spieler nicht - der Aufruf bricht mit "attempt to call method" ab und
    -- reisst alles mit, was in derselben Funktion danach kaeme.
    ply:SetSlowWalkSpeed(slow)

    return walk, run, slow
end

--[[
    Eine feste Geschwindigkeit setzen, die Respawn und Jobwechsel uebersteht.
    Ohne Werte faellt der Spieler auf die Geschwindigkeit seines Jobs zurueck.
]]
function PD.Char.SetSpeed(ply, walk, run, slow)
    if not IsValid(ply) then return end

    if walk or run or slow then
        ply.PD_Speed = {
            walk = tonumber(walk) or PD.Char.BaseWalkSpeed,
            run = tonumber(run) or tonumber(walk) or PD.Char.BaseRunSpeed,
            slow = tonumber(slow) or PD.Char.BaseSlowWalkSpeed
        }
    else
        ply.PD_Speed = nil
    end

    return PD.Char.ApplySpeed(ply)
end

function PD.Char.ClearSpeed(ply)
    return PD.Char.SetSpeed(ply, nil, nil, nil)
end

--[[
    Nachsehen, was gerade gilt und woher es kommt.
]]
concommand.Add("pd_speed_info", function(caller, _, args)
    if IsValid(caller) and not caller:IsAdmin() then return end

    local ply = caller

    if args[1] then
        ply = player.GetBySteamID(args[1]) or caller
    end

    if not IsValid(ply) then
        print("[Tempo] Kein Spieler. Aufruf: pd_speed_info <SteamID>")
        return
    end

    local jobID, jobTable = ply:GetJob()

    local function say(text)
        if IsValid(caller) then caller:PrintMessage(HUD_PRINTCONSOLE, text) else print(text) end
    end

    say("[Tempo] " .. ply:Nick() .. ", Job " .. tostring(jobID))
    say("[Tempo] Grundwerte: gehen " .. PD.Char.BaseWalkSpeed
        .. ", rennen " .. PD.Char.BaseRunSpeed
        .. ", langsam " .. PD.Char.BaseSlowWalkSpeed)
    say("[Tempo] Job-Faktor: " .. tostring(istable(jobTable) and jobTable.speed or "-") .. " %")
    say("[Tempo] Fester Wert am Spieler: "
        .. (istable(ply.PD_Speed) and "ja" or "nein"))
    say("[Tempo] Gesetzt: gehen " .. ply:GetWalkSpeed()
        .. ", rennen " .. ply:GetRunSpeed()
        .. ", langsam " .. ply:GetSlowWalkSpeed())
end)

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

    -- Den Job VOR dem Spawn setzen: der PlayerSpawn-Hook sucht den Spawnpunkt
    -- ueber GetJob. Stand dort noch der alte Job, landete man beim Jobwechsel
    -- am Spawnpunkt der alten Einheit.
    self:SetJob(jobindex, jobTable)

    if force then
        self:KillSilent()
        self:Spawn()
    end

    self:SetHealth(jobTable.maxhealth or 100)
    self:SetArmor(jobTable.startarmor or 0)
    self:SetMaxHealth(jobTable.maxhealth or 100)
    self:SetMaxArmor(jobTable.maxarmor or 100)
    PD.Char.ApplySpeed(self)

    if PD.Admin and (self:IsAdmin() or (PD.Admin.Ranks and PD.Admin.Ranks[self:GetUserGroup()])) then
        for _, v in SortedPairs(PD.Admin.Equip or {}) do
            self:Give(v)
        end
    end

    --[[
        Auch beim Jobwechsel nur die permanente Ausruestung, genau wie beim
        Spawn. Die Listen aus Job und Untereinheit werden nicht mehr vergeben -
        Waffen holt man sich an der Kiste.

        Der Aufruf ist hier keine Doppelung, sondern noetig: ganz oben steht ein
        StripWeapons, und ohne 'force' folgt kein Spawn. Der Spawn-Hook, der die
        permanente Ausruestung sonst nachreicht, laeuft dann gar nicht - der
        Spieler stuende ohne Haende und ohne Erkennungsmarke da.
    ]]
    if PD.WB and isfunction(PD.WB.GiveAlways) then
        PD.WB.GiveAlways(self)
    end

    -- Jobwechsel setzt das gemerkte Model zurück: es gehörte zum alten Job, und
    -- Bodygroup-Indizes bedeuten je Model etwas anderes.
    self.PD_Model = nil
    self.PD_Bodygroups = nil

    local mdl = GetFirstModel(jobTable)

    if mdl then
        self:SetModel(mdl)
    end

    -- Nach dem Job- und Subunit-Loadout: Module wie Fortbildungen hängen sich hier
    -- ein, um zusätzliche Ausrüstung zu geben.
    hook.Run("PD_Loadout_Applied", self, jobTable)

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

    -- Der Spieler behält das Model, das er vorher getragen hat. Bewusst OHNE
    -- Prüfung gegen die Job-Freigabe: bei Events bekommen Charaktere Models, die
    -- in keinem Job hinterlegt sind, und die sollen einen Respawn überstehen.
    -- Beim Jobwechsel wird der Wert geleert, dann greift wieder das Job-Model.
    if ply.PD_Model and ply.PD_Model ~= "" then
        mdl = ply.PD_Model
    end

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

    -- Zuletzt, damit Abzeichen (Fortbildungen) eine widersprüchliche
    -- Umkleide-Auswahl überschreiben statt umgekehrt.
    hook.Run("PD_Model_Applied", ply)
end

--[[
    Die Standardausruestung von Sandbox abschalten.

    Sandbox weist in GM:PlayerSpawn jedem Spieler die Klasse player_sandbox zu,
    und deren Loadout gibt ohne Bedingung gmod_tool, gmod_camera und
    weapon_physgun aus - an jeden Spieler, nicht nur an Admins. sbox_weapons 0
    in der server.cfg sperrt nur die HL2-Waffen, diese drei nicht.

    Das Ganze laeuft in GM:PlayerSpawn und damit nach allen PlayerSpawn-Hooks.
    Das StripWeapons unten kam also zu frueh, und Kamera, Physgun und Toolgun
    waren danach wieder da.

    Gibt der Hook true zurueck, wird GM:PlayerLoadout gar nicht erst
    aufgerufen. Adminwerkzeug und permanente Ausruestung verteilt weiterhin
    SetModelOnSpawn - das haengt nicht am Sandbox-Loadout.
]]
hook.Add("PlayerLoadout", "PD.Char.NoSandboxLoadout", function(ply)
    return true
end)

hook.Add("PlayerSpawn", "PD.Char.SetModelOnSpawn", function(ply)
    -- Das aktuelle Model festhalten, BEVOR es hier überschrieben wird. Damit
    -- übersteht auch ein Model einen Respawn, das von außen gesetzt wurde -
    -- etwa für einen Event-Charakter. Beim Jobwechsel wird der Wert geleert.
    -- Immer übernehmen, nicht nur beim ersten Mal: sonst würde ein später von
    -- außen gesetztes Model nie nachgezogen und der Respawn brächte den alten
    -- Stand zurück.
    local ent = ply:GetNW2Entity("PD.DM.Ragdoll")

        if IsValid(ent) then
            ent:Remove()
            ply:SetViewEntity(ply)
        end

    local current = ply:GetModel()

    if current and current ~= "" then
        ply.PD_Model = current
    end

    local _, jobTable = ply:GetJob()

    local mdl = GetFirstModel(jobTable)
    if mdl then
        ply:SetModel(tostring(mdl))
    end

    ply:StripWeapons()
    

    -- Adminwerkzeug bleibt: Physgun und Toolgun sind Dienstausruestung, kein
    -- Loadout. Der Waffenkisten-Hook versucht dasselbe, laeuft dabei aber mit
    -- ipairs ueber PD.Admin.Equip - und das ist eine Map, ueber die ipairs
    -- nichts findet. Ohne diese Schleife hier haetten Admins gar nichts.
    if PD.Admin and (ply:IsAdmin() or (PD.Admin.Ranks and PD.Admin.Ranks[ply:GetUserGroup()])) then
        for _, v in SortedPairs(PD.Admin.Equip or {}) do
            ply:Give(v)
        end
    end

    --[[
        Gespawnt wird nur mit der permanenten Ausruestung.

        Das ist PD.WB.Always aus dem Waffenkisten-Modul, derzeit Haende und
        Erkennungsmarke: was man immer traegt, was nichts wiegt und was sich
        nicht ablegen laesst. Waffen holt man sich an der Kiste - die Listen aus
        Job und Untereinheit werden beim Spawn bewusst nicht mehr ausgegeben.

        GiveAlways wird hier aufgerufen, obwohl das Waffenkisten-Modul es
        ebenfalls tut: die Reihenfolge zweier PlayerSpawn-Hooks liegt nicht
        fest, und diese Funktion soll fuer sich genommen stimmen. Der Aufruf
        prueft je Klasse auf HasWeapon, ein zweites Mal kostet also nichts.
    ]]
    if PD.WB and isfunction(PD.WB.GiveAlways) then
        PD.WB.GiveAlways(ply)
    end

    -- Bleibt bestehen, auch wenn hier kein Loadout mehr vergeben wird: das
    -- Ereignis markiert den Punkt, an dem die Spawn-Ausruestung steht.
    hook.Run("PD_Loadout_Applied", ply, jobTable)

    --[[
        Erst im naechsten Frame, und das ist der Kern des Ganzen: die
        Spielerklasse setzt ihre eigenen WalkSpeed/RunSpeed in GM:PlayerSpawn -
        also nach allen ueber hook.Add angemeldeten PlayerSpawn-Hooks. Wer die
        Geschwindigkeit hier direkt setzt, sieht sie einen Wimpernschlag spaeter
        wieder ueberschrieben.
    ]]
    timer.Simple(0, function()
        if not IsValid(ply) then return end

        SetPlayerPhaseModel(ply)
        PD.Char.ApplySpeed(ply)
    end)
end)