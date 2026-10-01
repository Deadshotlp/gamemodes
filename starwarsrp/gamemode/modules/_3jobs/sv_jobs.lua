-- Jobs System by Deadshot
util.AddNetworkString("PD.JOBS.OpenUnitEditor")
util.AddNetworkString("PD.JOBS.UpdateTabel")
util.AddNetworkString("PD.JOBS.SyncJobs")
PD.JOBS = PD.JOBS or {}

-- Grundbaum fuer eine leere Datenbank. Der eigentliche Baum kommt aus den
-- Tabellen pd_jobs_units, pd_jobs_subunits und pd_jobs_jobs.
PD.JOBS.DefaultJobs = {
    ["Ausbildung"] = {
        default = true,
        equip = {},
        color = Color(255, 255, 255),
        subunits = {
            ["Rekruten"] = {
                default = true,
                equip = {},
                color = Color(255, 255, 255),
                maxmambers = 10,
                maxmembers = 10,
                unit = "Ausbildung",
                ismedic = false,
                isleo = false,
                isengineer = false,
                jobs = {
                    ["Rekrut"] = {
                        default = true,
                        equip = {"salute_swep", "cross_arms_swep"},
                        model = {"models/starwars/grady/gl/ct/ct_trooper.mdl"},
                        unit = "Rekruten",
                        salary = 100,
                        speed = 100,
                        id = "rekruten_rekrut",
                        color = Color(255, 255, 255)
                    }
                }
            }
        }
    }
}

-- Beim Laden und nach einem Lua-Refresh den geladenen Baum nicht mit dem
-- Grundbaum ueberschreiben - sonst stuende bis zum Nachladen der falsche Stand
-- im Speicher.
if not istable(PD.JOBS.Jobs) or next(PD.JOBS.Jobs) == nil then
    PD.JOBS.Jobs = table.Copy(PD.JOBS.DefaultJobs)
end

local sqlUnitsTable = "pd_jobs_units"
local sqlSubUnitsTable = "pd_jobs_subunits"
local sqlJobsTable = "pd_jobs_jobs"
local loadInProgress = false
local pendingLoadCallbacks = {}
local loadToken = nil
local LOAD_TIMEOUT = 20

local function log(msg)
    print("[PD.JOBS] " .. tostring(msg))
end

local function sqlEscape(value)
    if PD.SQL and isfunction(PD.SQL.EscapeString) then
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

local function sqlExecute(query, callback)
    if not PD.SQL then
        if isfunction(callback) then
            callback(false)
        end
        return nil
    end

    if isfunction(PD.SQL.Execute) then
        return PD.SQL.Execute(query, function(...)
            if isfunction(callback) then
                callback(true, ...)
            end
        end)
    end

    if isfunction(PD.SQL.Query) then
        return PD.SQL.Query(query, function(...)
            if isfunction(callback) then
                callback(true, ...)
            end
        end, false)
    end

    if isfunction(callback) then
        callback(false)
    end

    return nil
end

local function sqlFetchOne(query, callback)
    if not PD.SQL then
        if isfunction(callback) then
            callback(nil)
        end
        return nil
    end

    if isfunction(PD.SQL.FetchOne) then
        return PD.SQL.FetchOne(query, callback)
    end

    if isfunction(PD.SQL.Query) then
        return PD.SQL.Query(query, callback, true)
    end

    if isfunction(callback) then
        callback(nil)
    end

    return nil
end

local function sqlFetchAll(query, callback)
    if not PD.SQL then
        if isfunction(callback) then
            callback({})
        end
        return nil
    end

    if isfunction(PD.SQL.FetchAll) then
        return PD.SQL.FetchAll(query, callback)
    end

    if isfunction(PD.SQL.Query) then
        return PD.SQL.Query(query, callback, false)
    end

    if isfunction(callback) then
        callback({})
    end

    return nil
end

local function runLoadCallbacks(ok, source)
    local callbacks = pendingLoadCallbacks
    pendingLoadCallbacks = {}

    for i = 1, #callbacks do
        local cb = callbacks[i]
        if isfunction(cb) then
            cb(ok, source)
        end
    end
end

local function colorToColumns(c)
    if not istable(c) then
        return 255, 255, 255, 255
    end

    return tonumber(c.r) or 255, tonumber(c.g) or 255, tonumber(c.b) or 255, tonumber(c.a) or 255
end

local function columnsToColor(r, g, b, a)
    return Color(
        tonumber(r) or 255,
        tonumber(g) or 255,
        tonumber(b) or 255,
        tonumber(a) or 255
    )
end

local function boolToNum(v)
    return v and 1 or 0
end

local function numToBool(v)
    return tonumber(v) == 1
end

local function decodeJsonArray(raw)
    if not raw or raw == "" then
        return {}
    end

    local decoded = util.JSONToTable(raw)
    if istable(decoded) then
        return decoded
    end

    return {}
end

local function ensureSQLTable(callback)
    if not PD.SQL or (not isfunction(PD.SQL.Execute) and not isfunction(PD.SQL.Query)) then
        log("PD.SQL API ist nicht verfuegbar")
        if isfunction(callback) then
            callback(false)
        end
        return
    end

    local createUnits = "CREATE TABLE IF NOT EXISTS `" .. sqlUnitsTable .. "` ("
        .. "`unit_key` VARCHAR(128) NOT NULL,"
        .. "`name` VARCHAR(128) NULL,"
        .. "`is_default` TINYINT(1) NOT NULL DEFAULT 0,"
        .. "`equip_json` LONGTEXT NOT NULL,"
        .. "`color_r` INT NOT NULL DEFAULT 255,"
        .. "`color_g` INT NOT NULL DEFAULT 255,"
        .. "`color_b` INT NOT NULL DEFAULT 255,"
        .. "`color_a` INT NOT NULL DEFAULT 255,"
        .. "PRIMARY KEY (`unit_key`)"
        .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

    local createSubunits = "CREATE TABLE IF NOT EXISTS `" .. sqlSubUnitsTable .. "` ("
        .. "`unit_key` VARCHAR(128) NOT NULL,"
        .. "`subunit_key` VARCHAR(128) NOT NULL,"
        .. "`name` VARCHAR(128) NULL,"
        .. "`unit` VARCHAR(128) NULL,"
        .. "`is_default` TINYINT(1) NOT NULL DEFAULT 0,"
        .. "`maxmembers` INT NOT NULL DEFAULT 0,"
        .. "`ismedic` TINYINT(1) NOT NULL DEFAULT 0,"
        .. "`isleo` TINYINT(1) NOT NULL DEFAULT 0,"
        .. "`isengineer` TINYINT(1) NOT NULL DEFAULT 0,"
        .. "`equip_json` LONGTEXT NOT NULL,"
        .. "`color_r` INT NOT NULL DEFAULT 255,"
        .. "`color_g` INT NOT NULL DEFAULT 255,"
        .. "`color_b` INT NOT NULL DEFAULT 255,"
        .. "`color_a` INT NOT NULL DEFAULT 255,"
        .. "PRIMARY KEY (`unit_key`, `subunit_key`)"
        .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

    local createJobs = "CREATE TABLE IF NOT EXISTS `" .. sqlJobsTable .. "` ("
        .. "`unit_key` VARCHAR(128) NOT NULL,"
        .. "`subunit_key` VARCHAR(128) NOT NULL,"
        .. "`job_key` VARCHAR(128) NOT NULL,"
        .. "`name` VARCHAR(128) NULL,"
        .. "`unit` VARCHAR(128) NULL,"
        .. "`job_id` VARCHAR(128) NULL,"
        .. "`salary` INT NOT NULL DEFAULT 0,"
        .. "`speed` INT NOT NULL DEFAULT 100,"
        .. "`position` INT NOT NULL DEFAULT 0,"
        .. "`showid` TINYINT(1) NOT NULL DEFAULT 0,"
        .. "`is_default` TINYINT(1) NOT NULL DEFAULT 0,"
        .. "`equip_json` LONGTEXT NOT NULL,"
        .. "`model_json` LONGTEXT NOT NULL,"
        .. "`color_r` INT NOT NULL DEFAULT 255,"
        .. "`color_g` INT NOT NULL DEFAULT 255,"
        .. "`color_b` INT NOT NULL DEFAULT 255,"
        .. "`color_a` INT NOT NULL DEFAULT 255,"
        .. "PRIMARY KEY (`unit_key`, `subunit_key`, `job_key`)"
        .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

    sqlExecute(createUnits, function(okUnits)
        if not okUnits then
            if isfunction(callback) then
                callback(false)
            end
            return
        end

        sqlExecute(createSubunits, function(okSubunits)
            if not okSubunits then
                if isfunction(callback) then
                    callback(false)
                end
                return
            end

            sqlExecute(createJobs, function(okJobs)
                if isfunction(callback) then
                    callback(okJobs == true)
                end
            end)
        end)
    end)
end

local function saveJobsToSQL(jobsTable, callback)
    if not PD.SQL or not isfunction(PD.SQL.Begin) or not isfunction(PD.SQL.Commit) then
        log("PD.SQL Transaction API ist nicht verfuegbar")
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

    addQuery("DELETE FROM `" .. sqlJobsTable .. "`")
    addQuery("DELETE FROM `" .. sqlSubUnitsTable .. "`")
    addQuery("DELETE FROM `" .. sqlUnitsTable .. "`")

    for unitKey, unitData in SortedPairs(jobsTable or {}) do
        local ur, ug, ub, ua = colorToColumns(unitData.color)
        local unitInsert = PD.SQL.BuildInsert(sqlUnitsTable, {
            unit_key = unitKey,
            name = unitData.name,
            is_default = boolToNum(unitData.default == true),
            equip_json = util.TableToJSON(unitData.equip or {}, false) or "[]",
            color_r = ur,
            color_g = ug,
            color_b = ub,
            color_a = ua
        })

        if unitInsert then
            addQuery(unitInsert)
        end

        if istable(unitData.subunits) then
            for subUnitKey, subUnitData in SortedPairs(unitData.subunits) do
                local sr, sg, sb, sa = colorToColumns(subUnitData.color)
                local subInsert = PD.SQL.BuildInsert(sqlSubUnitsTable, {
                    unit_key = unitKey,
                    subunit_key = subUnitKey,
                    name = subUnitData.name,
                    unit = subUnitData.unit,
                    is_default = boolToNum(subUnitData.default == true),
                    maxmembers = tonumber(subUnitData.maxmembers or subUnitData.maxmambers or 0) or 0,
                    ismedic = boolToNum(subUnitData.ismedic == true),
                    isleo = boolToNum(subUnitData.isleo == true),
                    isengineer = boolToNum(subUnitData.isengineer == true),
                    equip_json = util.TableToJSON(subUnitData.equip or {}, false) or "[]",
                    color_r = sr,
                    color_g = sg,
                    color_b = sb,
                    color_a = sa
                })

                if subInsert then
                    addQuery(subInsert)
                end

                if istable(subUnitData.jobs) then
                    for jobKey, jobData in SortedPairs(subUnitData.jobs) do
                        local jr, jg, jb, ja = colorToColumns(jobData.color)
                        local jobInsert = PD.SQL.BuildInsert(sqlJobsTable, {
                            unit_key = unitKey,
                            subunit_key = subUnitKey,
                            job_key = jobKey,
                            name = jobData.name,
                            unit = jobData.unit,
                            job_id = jobData.id,
                            salary = tonumber(jobData.salary or 0) or 0,
                            speed = tonumber(jobData.speed or 100) or 100,
                            position = tonumber(jobData.position or 0) or 0,
                            showid = boolToNum(jobData.showid == true),
                            is_default = boolToNum(jobData.default == true),
                            equip_json = util.TableToJSON(jobData.equip or {}, false) or "[]",
                            model_json = util.TableToJSON(jobData.model or {}, false) or "[]",
                            color_r = jr,
                            color_g = jg,
                            color_b = jb,
                            color_a = ja
                        })

                        if jobInsert then
                            addQuery(jobInsert)
                        end
                    end
                end
            end
        end
    end

    PD.SQL.Commit(function()
        if isfunction(callback) then
            callback(true)
        end
    end, function(err)
        log("Speichern in normalisierte SQL-Tabellen fehlgeschlagen: " .. tostring(err))
        if isfunction(callback) then
            callback(false)
        end
    end)
end

local function loadJobsFromNormalizedSQL(callback)
    sqlFetchOne("SELECT COUNT(*) AS c FROM `" .. sqlUnitsTable .. "`", function(countRow)
        local count = tonumber(countRow and countRow.c or 0) or 0
        if count <= 0 then
            if isfunction(callback) then
                callback(false, nil)
            end
            return
        end

        local jobsTree = {}

        sqlFetchAll("SELECT * FROM `" .. sqlUnitsTable .. "`", function(unitRows)
            unitRows = unitRows or {}

            for i = 1, #unitRows do
                local row = unitRows[i]
                jobsTree[row.unit_key] = {
                    name = row.name,
                    default = numToBool(row.is_default),
                    equip = decodeJsonArray(row.equip_json),
                    color = columnsToColor(row.color_r, row.color_g, row.color_b, row.color_a),
                    subunits = {}
                }
            end

            sqlFetchAll("SELECT * FROM `" .. sqlSubUnitsTable .. "`", function(subRows)
                subRows = subRows or {}

                for i = 1, #subRows do
                    local row = subRows[i]
                    jobsTree[row.unit_key] = jobsTree[row.unit_key] or {
                        name = row.unit_key,
                        default = false,
                        equip = {},
                        color = Color(255, 255, 255),
                        subunits = {}
                    }

                    jobsTree[row.unit_key].subunits[row.subunit_key] = {
                        name = row.name,
                        default = numToBool(row.is_default),
                        equip = decodeJsonArray(row.equip_json),
                        color = columnsToColor(row.color_r, row.color_g, row.color_b, row.color_a),
                        maxmembers = tonumber(row.maxmembers) or 0,
                        maxmambers = tonumber(row.maxmembers) or 0,
                        unit = row.unit,
                        ismedic = numToBool(row.ismedic),
                        isleo = numToBool(row.isleo),
                        isengineer = numToBool(row.isengineer),
                        jobs = {}
                    }
                end

                sqlFetchAll("SELECT * FROM `" .. sqlJobsTable .. "`", function(jobRows)
                    jobRows = jobRows or {}

                    for i = 1, #jobRows do
                        local row = jobRows[i]
                        jobsTree[row.unit_key] = jobsTree[row.unit_key] or {
                            name = row.unit_key,
                            default = false,
                            equip = {},
                            color = Color(255, 255, 255),
                            subunits = {}
                        }

                        jobsTree[row.unit_key].subunits[row.subunit_key] = jobsTree[row.unit_key].subunits[row.subunit_key] or {
                            name = row.subunit_key,
                            default = false,
                            equip = {},
                            color = Color(255, 255, 255),
                            maxmembers = 0,
                            maxmambers = 0,
                            unit = row.unit_key,
                            ismedic = false,
                            isleo = false,
                            isengineer = false,
                            jobs = {}
                        }

                        jobsTree[row.unit_key].subunits[row.subunit_key].jobs[row.job_key] = {
                            salary = tonumber(row.salary) or 0,
                            unit = row.unit,
                            id = row.job_id,
                            model = decodeJsonArray(row.model_json),
                            speed = tonumber(row.speed) or 100,
                            equip = decodeJsonArray(row.equip_json),
                            color = columnsToColor(row.color_r, row.color_g, row.color_b, row.color_a),
                            position = tonumber(row.position) or 0,
                            showid = numToBool(row.showid),
                            name = row.name,
                            default = numToBool(row.is_default)
                        }
                    end

                    if isfunction(callback) then
                        callback(true, jobsTree)
                    end
                end)
            end)
        end)
    end)
end

function PD.JOBS.LoadDir(callback)
    return PD.JOBS.LoadJobs(callback)
end

--[[
    Jobbaum aus der Datenbank laden.

    Die frueheren Wege ueber data/modules/jobs/jobs.json und die Alt-Tabelle
    pd_jobs_data sind entfernt. Sind die Tabellen leer, wird der aktuelle
    Stand (bei neuer Datenbank der Grundbaum) hineingeschrieben.

    Eine fehlgeschlagene Abfrage ruft keinen Callback auf. Vorher blieb
    loadInProgress dann fuer immer gesetzt, jedes weitere Laden - auch
    pd_reload jobs aus dem Web-Panel - kam nie mehr an, und der Job-Editor
    speicherte seinen veralteten Stand ueber die Datenbank. Deshalb die
    Zeitgrenze.
]]
function PD.JOBS.LoadJobs(callback)
    if isfunction(callback) then
        table.insert(pendingLoadCallbacks, callback)
    end

    if loadInProgress then
        return
    end

    loadInProgress = true

    local token = {}
    loadToken = token

    local function finish(ok, source)
        if loadToken ~= token then return end

        loadToken = nil
        loadInProgress = false
        timer.Remove("PD.JOBS.LoadTimeout")

        if ok then
            PD.JOBS.LoadedOnce = true
        end

        runLoadCallbacks(ok, source)

        if ok then
            hook.Run("PD.JOBS.Loaded", source)
        end
    end

    timer.Create("PD.JOBS.LoadTimeout", LOAD_TIMEOUT, 1, function()
        if loadToken ~= token then return end

        log("Laden der Jobs hat nach " .. LOAD_TIMEOUT .. "s nicht geantwortet - bisheriger Stand bleibt")
        finish(false, "timeout")
    end)

    ensureSQLTable(function(tableOk)
        if not tableOk then
            log("Job-Tabellen nicht verfuegbar - bisheriger Stand bleibt")
            finish(false, "no_table")
            return
        end

        loadJobsFromNormalizedSQL(function(ok, tree)
            if ok and istable(tree) and next(tree) ~= nil then
                PD.JOBS.Jobs = tree
                finish(true, "sql")
                return
            end

            log("Job-Tabellen sind leer - schreibe den aktuellen Stand hinein")

            saveJobsToSQL(PD.JOBS.Jobs, function(saved)
                finish(saved == true, "seeded")
            end)
        end)
    end)
end

function PD.JOBS.SaveJobs(callback)
    ensureSQLTable(function(tableOk)
        if not tableOk then
            if isfunction(callback) then
                callback(false)
            end
            return
        end

        saveJobsToSQL(PD.JOBS.Jobs, function(saved)
            if isfunction(callback) then
                callback(saved)
            end
        end)
    end)
end

hook.Add("PostPDLoaded", "Deadshot_LoadUnits", function()
    PD.JOBS.LoadJobs(function()
        PD.JOBS.UpdateTabel()
    end)
end)

PD.JOBS.LoadJobs()

--[[
    Jobbaum an einen Spieler schicken.

    Frueher lud jeder Join und jede Client-Anfrage den kompletten Baum neu aus
    der Datenbank, und die Anfrage schickte ihn danach an ALLE Spieler. Jetzt
    gilt der Stand im Speicher; neu geladen wird nur beim Start, vor
    Aenderungen im Job-Editor und bei pd_reload jobs. Nur solange noch nie
    geladen wurde, wartet die Antwort auf das Laden.
]]
local function SendJobsTo(ply)
    if PD.JOBS.LoadedOnce then
        PD.JOBS.UpdateTabel(ply)
        return
    end

    PD.JOBS.LoadJobs(function(ok)
        if ok and IsValid(ply) then
            PD.JOBS.UpdateTabel(ply)
        end
    end)
end

hook.Add("PlayerInitialSpawn", "PD.SendJobData", function(ply)
    SendJobsTo(ply)
end)

local syncJobsCooldown = {}

net.Receive("PD.JOBS.SyncJobs", function(_, ply)
    if not IsValid(ply) then return end

    local steamid = ply:SteamID64()
    if syncJobsCooldown[steamid] and CurTime() - syncJobsCooldown[steamid] < 5 then return end
    syncJobsCooldown[steamid] = CurTime()

    SendJobsTo(ply)
end)

function PD.JOBS.UpdateTabel(targetPly)
    net.Start("PD.JOBS.UpdateTabel")
    net.WriteTable(PD.JOBS.Jobs)

    if IsValid(targetPly) then
        net.Send(targetPly)
        return
    end

    net.Broadcast()
end

local fallback = {
    ["Fallback Unit!"] = {
        default = false,
        color = Color(255, 0, 0),
        subunits = {
            ["Fallback Subunit!"] = {
                maxmambers = 10,
                maxmembers = 10,
                default = false,
                equip = {},
                color = Color(255, 0, 0),
                unit = "Fallback Unit!",
                ismedic = false,
                isleo = false,
                isengineer = false,
                jobs = {
                    ["Fallback Job!"] = {
                        color = Color(255, 0, 0),
                        model = {"models/player/skeleton.mdl"},
                        equip = {},
                        default = false,
                        unit = "Fallback Subunit!",
                        salary = 100,
                        speed = 100,
                        id = 1
                    }
                }
            }
        }
    }
}

function PD.JOBS.GetFallBackJob()
    return "Fallback Job!", fallback["Fallback Unit!"].subunits["Fallback Subunit!"].jobs["Fallback Job!"]
end

function PD.JOBS.GetUnit(name, all)
    if all then
        return PD.JOBS.Jobs
    end

    if name then
        for unitName, unitData in SortedPairs(PD.JOBS.Jobs) do
            if unitName == name or unitData.name == name then
                return unitName, unitData
            end
        end
    end

    for unitName, unitData in SortedPairs(PD.JOBS.Jobs) do
        if unitData.default then
            return unitName, unitData
        end
    end

    return "Fallback Unit!", fallback["Fallback Unit!"]
end

function PD.JOBS.GetSubUnit(name, all)
    local subunits = {}

    for _, unitData in SortedPairs(PD.JOBS.Jobs) do
        if istable(unitData.subunits) then
            for subUnitName, subUnitData in SortedPairs(unitData.subunits) do
                subunits[subUnitName] = subUnitData
            end
        end
    end

    if all then
        return subunits
    end

    if name then
        for subUnitName, subUnitData in SortedPairs(subunits) do
            if subUnitName == name or subUnitData.name == name then
                return subUnitName, subUnitData
            end
        end
    end

    for subUnitName, subUnitData in SortedPairs(subunits) do
        if subUnitData.default then
            return subUnitName, subUnitData
        end
    end

    return "Fallback Subunit!", fallback["Fallback Unit!"].subunits["Fallback Subunit!"]
end

function PD.JOBS.GetJob(name, all)
    local subunits = PD.JOBS.GetSubUnit(false, true)
    local jobs = {}

    for _, subUnitData in SortedPairs(subunits) do
        if istable(subUnitData.jobs) then
            for jobName, jobData in SortedPairs(subUnitData.jobs) do
                jobs[jobName] = jobData
            end
        end
    end

    if all then
        return jobs
    end

    if name then
        for jobName, jobData in SortedPairs(jobs) do
            if jobName == name or jobData.name == name then
                return jobName, jobData
            end
        end
    end

    for jobName, jobData in SortedPairs(jobs) do
        if jobData.default then
            return jobName, jobData
        end
    end

    return "Fallback Job!", fallback["Fallback Unit!"].subunits["Fallback Subunit!"].jobs["Fallback Job!"]
end

function PD.JOBS.GetTable()
    return PD.JOBS.Jobs
end

-- Serverbefehle kann jeder Client ausfuehren: nur Konsole und Superadmins.
concommand.Add("pd_jobs_prints", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    print("===============================Start=======================================")
    PrintTable(PD.JOBS.Jobs)
    print("================================Ende=======================================")
end)
