PD.FB = PD.FB or {}

local TBL_COURSES = "pd_fb_courses"
local TBL_GRANTED = "pd_fb_granted"
local TBL_SESSIONS = "pd_fb_sessions"
local TBL_PARTICIPANTS = "pd_fb_participants"

local SYNC_COOLDOWN = 5
local nextSessionID = 1
local syncCooldowns = {}

PD.FB.Ready = false

util.AddNetworkString("PD.FB.SyncCatalog")
util.AddNetworkString("PD.FB.CourseDelta")
util.AddNetworkString("PD.FB.SyncPlayer")
util.AddNetworkString("PD.FB.PublicBadges")
util.AddNetworkString("PD.FB.Admin")
util.AddNetworkString("PD.FB.Grant")
util.AddNetworkString("PD.FB.Revoke")
util.AddNetworkString("PD.FB.Session")
util.AddNetworkString("PD.FB.SessionState")
util.AddNetworkString("PD.FB.History")

--------------------------------------------------------------------------------
-- Hilfsfunktionen
--------------------------------------------------------------------------------

local function esc(value)
    return PD.SQL.EscapeString(tostring(value or ""))
end

local function encodeJson(tbl)
    return util.TableToJSON(tbl or {}) or "[]"
end

local function decodeJson(str, fallback)
    if not str or str == "" then return fallback end

    local decoded = util.JSONToTable(str)

    return istable(decoded) and decoded or fallback
end

local function colorToColumns(color)
    color = color or Color(255, 255, 255)

    return math.floor(color.r), math.floor(color.g), math.floor(color.b), math.floor(color.a or 255)
end

local function columnsToColor(row)
    return Color(tonumber(row.color_r) or 255, tonumber(row.color_g) or 255, tonumber(row.color_b) or 255, tonumber(row.color_a) or 255)
end

local function log(text)
    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("fortbildung", text, Color(60, 140, 60))
    end
end

--------------------------------------------------------------------------------
-- Schema
--------------------------------------------------------------------------------

function PD.FB.EnsureTables(callback)
    local createCourses = "CREATE TABLE IF NOT EXISTS `" .. TBL_COURSES .. "` ("
        .. "`fb_key` VARCHAR(128) NOT NULL,"
        .. "`name` VARCHAR(128) NOT NULL,"
        .. "`description` TEXT NOT NULL,"
        .. "`position` INT NOT NULL DEFAULT 0,"
        .. "`color_r` INT NOT NULL DEFAULT 255,"
        .. "`color_g` INT NOT NULL DEFAULT 255,"
        .. "`color_b` INT NOT NULL DEFAULT 255,"
        .. "`color_a` INT NOT NULL DEFAULT 255,"
        .. "`equip_json` LONGTEXT NOT NULL,"
        .. "`model_json` LONGTEXT NOT NULL,"
        .. "`badge_json` LONGTEXT NOT NULL,"
        .. "`access_json` LONGTEXT NOT NULL,"
        .. "`teach_json` LONGTEXT NOT NULL,"
        .. "`requires_json` LONGTEXT NOT NULL,"
        .. "`duration_days` INT NOT NULL DEFAULT 0,"
        .. "`max_holders` INT NOT NULL DEFAULT 0,"
        .. "PRIMARY KEY (`fb_key`)"
        .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

    -- Bewusst kein FOREIGN KEY auf pd_characters: PD.Char:SaveChar löscht dort alle
    -- Zeilen einer SteamID und fügt sie neu ein, ein FK würde die Transaktion sprengen.
    local createGranted = "CREATE TABLE IF NOT EXISTS `" .. TBL_GRANTED .. "` ("
        .. "`char_id` VARCHAR(64) NOT NULL,"
        .. "`fb_key` VARCHAR(128) NOT NULL,"
        .. "`steamid64` VARCHAR(32) NOT NULL DEFAULT '',"
        .. "`granted_at` BIGINT NOT NULL DEFAULT 0,"
        .. "`expires_at` BIGINT NOT NULL DEFAULT 0,"
        .. "`granted_by` VARCHAR(64) NOT NULL DEFAULT '',"
        .. "`session_id` INT NOT NULL DEFAULT 0,"
        .. "PRIMARY KEY (`char_id`, `fb_key`),"
        .. "KEY `idx_steam` (`steamid64`)"
        .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

    local createSessions = "CREATE TABLE IF NOT EXISTS `" .. TBL_SESSIONS .. "` ("
        .. "`session_id` INT NOT NULL,"
        .. "`fb_key` VARCHAR(128) NOT NULL,"
        .. "`instructor_char` VARCHAR(64) NOT NULL DEFAULT '',"
        .. "`instructor_name` VARCHAR(128) NOT NULL DEFAULT '',"
        .. "`started_at` BIGINT NOT NULL DEFAULT 0,"
        .. "`ended_at` BIGINT NOT NULL DEFAULT 0,"
        .. "`state` TINYINT NOT NULL DEFAULT 0,"
        .. "`note` TEXT NOT NULL,"
        .. "PRIMARY KEY (`session_id`),"
        .. "KEY `idx_fb` (`fb_key`),"
        .. "KEY `idx_instructor` (`instructor_char`)"
        .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

    local createParticipants = "CREATE TABLE IF NOT EXISTS `" .. TBL_PARTICIPANTS .. "` ("
        .. "`session_id` INT NOT NULL,"
        .. "`char_id` VARCHAR(64) NOT NULL,"
        .. "`steamid64` VARCHAR(32) NOT NULL DEFAULT '',"
        .. "`name` VARCHAR(128) NOT NULL DEFAULT '',"
        .. "`result` TINYINT NOT NULL DEFAULT 0,"
        .. "`note` VARCHAR(255) NOT NULL DEFAULT '',"
        .. "PRIMARY KEY (`session_id`, `char_id`),"
        .. "KEY `idx_char` (`char_id`)"
        .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

    -- Sequentiell verketten: PD.SQL puffert Queries zwar bis die Verbindung steht,
    -- aber die Reihenfolge der Callbacks ist sonst nicht garantiert.
    PD.SQL.Query(createCourses, function()
        PD.SQL.Query(createGranted, function()
            PD.SQL.Query(createSessions, function()
                PD.SQL.Query(createParticipants, function()
                    if callback then callback() end
                end)
            end)
        end)
    end)
end

--------------------------------------------------------------------------------
-- Katalog laden und speichern
--------------------------------------------------------------------------------

local function rowToCourse(row)
    local course = PD.FB.NewCourse()

    course.fb_key = row.fb_key
    course.name = row.name or ""
    course.description = row.description or ""
    course.position = tonumber(row.position) or 0
    course.color = columnsToColor(row)
    course.equip = decodeJson(row.equip_json, {})
    course.model = decodeJson(row.model_json, {})
    course.badge = decodeJson(row.badge_json, {bodygroups = {}})
    course.access = decodeJson(row.access_json, {units = {}, subunits = {}, jobs = {}})
    course.teach = decodeJson(row.teach_json, {})
    course.requires = decodeJson(row.requires_json, {})
    course.duration_days = tonumber(row.duration_days) or 0
    course.max_holders = tonumber(row.max_holders) or 0

    course.badge.bodygroups = course.badge.bodygroups or {}
    course.access.units = course.access.units or {}
    course.access.subunits = course.access.subunits or {}
    course.access.jobs = course.access.jobs or {}

    return course
end

function PD.FB.LoadCourses(callback)
    PD.SQL.FetchAll("SELECT * FROM `" .. TBL_COURSES .. "`", function(rows)
        PD.FB.Courses = {}

        for _, row in ipairs(rows or {}) do
            PD.FB.Courses[row.fb_key] = rowToCourse(row)
        end

        if callback then callback() end
    end)
end

local COURSE_FIELDS = {
    "fb_key", "name", "description", "position",
    "color_r", "color_g", "color_b", "color_a",
    "equip_json", "model_json", "badge_json", "access_json",
    "teach_json", "requires_json", "duration_days", "max_holders"
}

local function courseToRow(course)
    local r, g, b, a = colorToColumns(course.color)

    return {
        fb_key = course.fb_key,
        name = course.name,
        description = course.description,
        position = course.position,
        color_r = r,
        color_g = g,
        color_b = b,
        color_a = a,
        equip_json = encodeJson(course.equip),
        model_json = encodeJson(course.model),
        badge_json = encodeJson(course.badge),
        access_json = encodeJson(course.access),
        teach_json = encodeJson(course.teach),
        requires_json = encodeJson(course.requires),
        duration_days = course.duration_days,
        max_holders = course.max_holders
    }
end

-- Katalog komplett neu schreiben. Nur der Admin-Editor ruft das auf, und dort
-- ändern sich Reihenfolge und Querverweise oft zusammen.
function PD.FB.SaveCourses(callback)
    local addQuery = PD.SQL.Begin()

    if not addQuery then
        if callback then callback(false) end
        return
    end

    addQuery("DELETE FROM `" .. TBL_COURSES .. "`")

    for _, course in pairs(PD.FB.Courses) do
        local query = PD.SQL.BuildInsert(TBL_COURSES, courseToRow(course), COURSE_FIELDS)

        if query then
            addQuery(query)
        end
    end

    PD.SQL.Commit(function()
        if callback then callback(true) end
    end, function(err)
        ErrorNoHalt("[Fortbildung] Katalog speichern fehlgeschlagen: " .. tostring(err) .. "\n")
        if callback then callback(false) end
    end)
end

--------------------------------------------------------------------------------
-- Vergaben laden
--------------------------------------------------------------------------------

function PD.FB.LoadGranted(callback)
    PD.SQL.FetchAll("SELECT * FROM `" .. TBL_GRANTED .. "`", function(rows)
        PD.FB.Granted = {}

        for _, row in ipairs(rows or {}) do
            PD.FB.Granted[row.char_id] = PD.FB.Granted[row.char_id] or {}
            PD.FB.Granted[row.char_id][row.fb_key] = {
                fb_key = row.fb_key,
                char_id = row.char_id,
                steamid64 = row.steamid64 or "",
                granted_at = tonumber(row.granted_at) or 0,
                expires_at = tonumber(row.expires_at) or 0,
                granted_by = row.granted_by or "",
                session_id = tonumber(row.session_id) or 0
            }
        end

        if callback then callback() end
    end)
end

--------------------------------------------------------------------------------
-- Zugangsprüfung
--------------------------------------------------------------------------------

-- Unit-, Subunit- und Job-Keys des Spielers. PD.List liefert Keys, der Fallback
-- über das Char-Table ebenfalls.
local function getFactionKeys(ply)
    if PD.List and PD.List.GetPlayerData then
        local unit, subunit, job = PD.List:GetPlayerData(ply)

        if unit then
            return unit, subunit, job
        end
    end

    return nil, nil, nil
end

local function isSetEmpty(set)
    return not set or table.Count(set) == 0
end

-- Darf dieser Spieler die Fortbildung machen? Leere Zugangslisten bedeuten
-- "für alle offen". Sind Listen gefüllt, muss mindestens ein Eintrag passen.
function PD.FB.CanAccess(ply, key)
    local course = PD.FB.GetCourse(key)
    if not course then return false, "Unbekannte Fortbildung" end

    local charID = PD.FB.GetCharID(ply)
    if not charID then return false, "Kein Charakter aktiv" end

    if PD.FB.HasCourse(charID, key) then
        return false, "Fortbildung bereits vorhanden"
    end

    local hasRequirements, reason = PD.FB.HasRequirements(charID, key)
    if not hasRequirements then
        return false, reason
    end

    if course.max_holders > 0 and PD.FB.CountHolders(key) >= course.max_holders then
        return false, "Maximale Anzahl an Inhabern erreicht"
    end

    local access = course.access or {}

    if isSetEmpty(access.units) and isSetEmpty(access.subunits) and isSetEmpty(access.jobs) then
        return true
    end

    local unit, subunit, job = getFactionKeys(ply)

    if unit and access.units and access.units[unit] then return true end
    if subunit and access.subunits and access.subunits[subunit] then return true end
    if job and access.jobs and access.jobs[job] then return true end

    return false, "Einheit oder Job nicht freigegeben"
end

function PD.FB.CanTeach(ply, key)
    if not IsValid(ply) then return false end
    if ply:IsAdmin() then return true end

    local charID = PD.FB.GetCharID(ply)
    if not charID then return false end

    return PD.FB.CanTeachCourse(charID, key)
end

--------------------------------------------------------------------------------
-- Effektive Freigaben: Job + Subunit + Fortbildungen
--------------------------------------------------------------------------------

-- Baut immer eine neue Tabelle. Der alte Code in sv_waffenkiste.lua benutzte
-- table.Add auf jobTbl.equip - das mutiert die geteilte PD.JOBS-Tabelle.
function PD.FB.GetAllowedEquip(ply)
    local allowed = {}

    if not IsValid(ply) then return allowed end

    local _, jobTbl = ply:GetJob()

    if istable(jobTbl) then
        for _, wep in pairs(jobTbl.equip or {}) do
            allowed[wep] = true
        end

        local _, subunit = PD.JOBS.GetSubUnit(jobTbl.unit)

        if istable(subunit) then
            for _, wep in pairs(subunit.equip or {}) do
                allowed[wep] = true
            end
        end
    end

    for key in pairs(PD.FB.GetActiveCourses(PD.FB.GetCharID(ply))) do
        for _, wep in pairs(PD.FB.Courses[key].equip or {}) do
            allowed[wep] = true
        end
    end

    return allowed
end

function PD.FB.GetAllowedModels(ply)
    local allowed = {}

    if not IsValid(ply) then return allowed end

    local _, jobTbl = ply:GetJob()

    if istable(jobTbl) then
        for _, model in pairs(jobTbl.model or {}) do
            allowed[string.lower(model)] = model
        end

        -- Unit-Models wie bisher in sv_umkleide.lua mit einbeziehen
        for _, unitData in pairs(PD.JOBS.GetUnit(false, true) or {}) do
            if unitData.name == jobTbl.unit then
                for _, model in pairs(unitData.model or {}) do
                    allowed[string.lower(model)] = model
                end
            end
        end
    end

    for key in pairs(PD.FB.GetActiveCourses(PD.FB.GetCharID(ply))) do
        for _, model in pairs(PD.FB.Courses[key].model or {}) do
            allowed[string.lower(model)] = model
        end
    end

    return allowed
end

function PD.FB.GetAllowedModelList(ply)
    local list = {}

    for _, model in pairs(PD.FB.GetAllowedModels(ply)) do
        table.insert(list, model)
    end

    table.sort(list)

    return list
end

-- Abzeichen des Spielers, aufgelöst auf sein aktuelles Model. Kollidieren zwei
-- Fortbildungen auf demselben Bodygroup-Index, gewinnt die mit der niedrigeren
-- position - deshalb wird der Katalog sortiert durchlaufen und rückwärts gesetzt.
function PD.FB.GetBadges(ply)
    local result = {skin = nil, bodygroups = {}}

    if not IsValid(ply) then return result end

    local charID = PD.FB.GetCharID(ply)
    if not charID then return result end

    local active = PD.FB.GetActiveCourses(charID)
    local currentModel = string.lower(ply:GetModel() or "")
    local sorted = PD.FB.GetSortedCourses()

    for i = #sorted, 1, -1 do
        local course = sorted[i]

        if active[course.fb_key] then
            local badge = course.badge or {}

            for _, entry in pairs(badge.bodygroups or {}) do
                local target = entry.model or PD.FB.AnyModel

                if target == PD.FB.AnyModel or string.lower(target) == currentModel then
                    result.bodygroups[tonumber(entry.index) or 0] = tonumber(entry.value) or 0
                end
            end

            if badge.skin then
                result.skin = tonumber(badge.skin)
            end
        end
    end

    return result
end

function PD.FB.IsBadgeBodygroup(ply, index)
    return PD.FB.GetBadges(ply).bodygroups[index] ~= nil
end

-- Bewusst KEINE automatische Ausgabe der Ausrüstung.
--
-- Eine Fortbildung schaltet Ausrüstung frei, sie händigt sie nicht aus. Wer sie
-- haben will, holt sie an der Waffenkiste - dort greift dann auch das
-- Gewichtssystem. Die Freigabe selbst läuft über PD.WB.GetAllowedClasses
-- (Waffenkiste) und PD.FB.GetAllowedModels (Umkleide), die beide die aktiven
-- Fortbildungen einbeziehen.

function PD.FB.ApplyBadges(ply)
    if not IsValid(ply) or not PD.FB.Ready then return end

    local badges = PD.FB.GetBadges(ply)

    for index, value in pairs(badges.bodygroups) do
        if index >= 0 and index < ply:GetNumBodyGroups() then
            ply:SetBodygroup(index, value)
        end
    end

    if badges.skin then
        ply:SetSkin(badges.skin)
    end
end

--------------------------------------------------------------------------------
-- Synchronisation
--------------------------------------------------------------------------------

function PD.FB.SyncCatalog(ply)
    net.Start("PD.FB.SyncCatalog")
        net.WriteTable(PD.FB.Courses)

    if IsValid(ply) then
        net.Send(ply)
    else
        net.Broadcast()
    end
end

-- Einzelne Fortbildung statt des kompletten Katalogs. key mit data = nil löscht
-- den Eintrag beim Client.
function PD.FB.SendCourseDelta(key, data)
    net.Start("PD.FB.CourseDelta")
        net.WriteString(key)
        net.WriteBool(data ~= nil)

        if data ~= nil then
            net.WriteTable(data)
        end
    net.Broadcast()
end

function PD.FB.SyncPlayer(ply)
    if not IsValid(ply) then return end

    local charID = PD.FB.GetCharID(ply)
    local granted = charID and PD.FB.Granted[charID] or {}
    local eligible = {}

    for key in pairs(PD.FB.Courses) do
        if PD.FB.CanAccess(ply, key) then
            eligible[key] = true
        end
    end

    -- Die Charakter-ID geht mit: die NW-Variable character_id kommt beim
    -- Client oft erst nach dieser Nachricht an. Er las dann noch "9999" und
    -- verwarf die Vergaben - nach der Charakterwahl fehlte die Zusatzausrüstung
    -- bis zum nächsten Lua-Refresh.
    net.Start("PD.FB.SyncPlayer")
        net.WriteString(charID or "")
        net.WriteTable(granted)
        net.WriteTable(eligible)
    net.Send(ply)
end

-- Kompakte Liste für Scoreboard und ID-Karte: nur char_id -> {fb_key, ...},
-- keine Vergabedaten.
function PD.FB.SyncPublicBadges(ply)
    local public = {}

    for _, target in ipairs(player.GetAll()) do
        local charID = PD.FB.GetCharID(target)

        if charID then
            local keys = {}

            for key in pairs(PD.FB.GetActiveCourses(charID)) do
                table.insert(keys, key)
            end

            if #keys > 0 then
                public[charID] = keys
            end
        end
    end

    net.Start("PD.FB.PublicBadges")
        net.WriteTable(public)

    if IsValid(ply) then
        net.Send(ply)
    else
        net.Broadcast()
    end
end

function PD.FB.SyncAll()
    PD.FB.SyncCatalog()
    PD.FB.SyncPublicBadges()

    for _, ply in ipairs(player.GetAll()) do
        PD.FB.SyncPlayer(ply)
    end
end

--------------------------------------------------------------------------------
-- Vergabe und Entzug
--------------------------------------------------------------------------------

local GRANT_FIELDS = {"char_id", "fb_key", "steamid64", "granted_at", "expires_at", "granted_by", "session_id"}

function PD.FB.Grant(charID, key, steamid64, byCharID, sessionID, callback)
    local course = PD.FB.GetCourse(key)

    if not charID or not course then
        if callback then callback(false, "Unbekannte Fortbildung") end
        return
    end

    local now = os.time()
    local entry = {
        fb_key = key,
        char_id = charID,
        steamid64 = steamid64 or "",
        granted_at = now,
        expires_at = course.duration_days > 0 and (now + course.duration_days * 86400) or 0,
        granted_by = byCharID or "",
        session_id = sessionID or 0
    }

    PD.FB.Granted[charID] = PD.FB.Granted[charID] or {}
    PD.FB.Granted[charID][key] = entry

    -- REPLACE statt INSERT: eine abgelaufene Fortbildung wird so aufgefrischt,
    -- ohne dass der alte Datensatz vorher gelöscht werden muss.
    local query = PD.SQL.BuildInsert(TBL_GRANTED, entry, GRANT_FIELDS)

    if query then
        query = string.gsub(query, "^INSERT INTO", "REPLACE INTO", 1)
        PD.SQL.Query(query)
    end

    local target = FindPlayerbyCharID and FindPlayerbyCharID(charID)

    if IsValid(target) then
        PD.FB.SyncPlayer(target)

        -- Nur das Abzeichen sofort setzen. Die Ausrüstung wird freigeschaltet,
        -- nicht ausgehändigt - abzuholen ist sie an der Waffenkiste.
        PD.FB.ApplyBadges(target)

        PD.Notify("Fortbildung erhalten: " .. course.name
            .. " (Ausrüstung an der Waffenkiste abholbar)", Color(60, 140, 60), false, target)
    end

    PD.FB.SyncPublicBadges()

    if callback then callback(true) end
end

function PD.FB.Revoke(charID, key, callback)
    if not charID or not key then
        if callback then callback(false) end
        return
    end

    if PD.FB.Granted[charID] then
        PD.FB.Granted[charID][key] = nil
    end

    PD.SQL.Query("DELETE FROM `" .. TBL_GRANTED .. "` WHERE `char_id` = " .. esc(charID) .. " AND `fb_key` = " .. esc(key))

    local target = FindPlayerbyCharID and FindPlayerbyCharID(charID)

    if IsValid(target) then
        PD.FB.SyncPlayer(target)
        PD.Notify("Fortbildung entzogen: " .. PD.FB.GetCourseName(key), Color(178, 60, 60), false, target)
    end

    PD.FB.SyncPublicBadges()

    if callback then callback(true) end
end

--------------------------------------------------------------------------------
-- Kurse
--------------------------------------------------------------------------------

local SESSION_FIELDS = {"session_id", "fb_key", "instructor_char", "instructor_name", "started_at", "ended_at", "state", "note"}
local PARTICIPANT_FIELDS = {"session_id", "char_id", "steamid64", "name", "result", "note"}

local function writeSession(session)
    local query = PD.SQL.BuildInsert(TBL_SESSIONS, {
        session_id = session.session_id,
        fb_key = session.fb_key,
        instructor_char = session.instructor_char,
        instructor_name = session.instructor_name,
        started_at = session.started_at,
        ended_at = session.ended_at,
        state = session.state,
        note = session.note or ""
    }, SESSION_FIELDS)

    if query then
        PD.SQL.Query((string.gsub(query, "^INSERT INTO", "REPLACE INTO", 1)))
    end
end

local function writeParticipant(sessionID, participant)
    local query = PD.SQL.BuildInsert(TBL_PARTICIPANTS, {
        session_id = sessionID,
        char_id = participant.char_id,
        steamid64 = participant.steamid64 or "",
        name = participant.name or "",
        result = participant.result or PD.FB.RESULT_OPEN,
        note = participant.note or ""
    }, PARTICIPANT_FIELDS)

    if query then
        PD.SQL.Query((string.gsub(query, "^INSERT INTO", "REPLACE INTO", 1)))
    end
end

function PD.FB.GetSessionOf(ply)
    local charID = PD.FB.GetCharID(ply)
    if not charID then return nil end

    for _, session in pairs(PD.FB.Sessions) do
        if session.state == PD.FB.STATE_OPEN and session.instructor_char == charID then
            return session
        end
    end

    return nil
end

function PD.FB.StartSession(ply, key)
    if not PD.FB.CanTeach(ply, key) then
        return nil, "Keine Berechtigung für diese Fortbildung"
    end

    if PD.FB.GetSessionOf(ply) then
        return nil, "Du leitest bereits einen Kurs"
    end

    local charID = PD.FB.GetCharID(ply)
    if not charID then return nil, "Kein Charakter aktiv" end

    local session = {
        session_id = nextSessionID,
        fb_key = key,
        instructor_char = charID,
        instructor_name = ply:Nick(),
        started_at = os.time(),
        ended_at = 0,
        state = PD.FB.STATE_OPEN,
        note = "",
        participants = {}
    }

    nextSessionID = nextSessionID + 1
    PD.FB.Sessions[session.session_id] = session

    writeSession(session)
    log(ply:Nick() .. " hat den Kurs '" .. PD.FB.GetCourseName(key) .. "' eröffnet")

    return session
end

function PD.FB.AddParticipant(session, target, allowOverride)
    if not session or session.state ~= PD.FB.STATE_OPEN then return false, "Kurs nicht offen" end
    if not IsValid(target) then return false, "Spieler nicht gefunden" end

    local charID = PD.FB.GetCharID(target)
    if not charID then return false, "Spieler hat keinen Charakter aktiv" end
    if session.participants[charID] then return false, "Bereits eingetragen" end

    local canAccess, reason = PD.FB.CanAccess(target, session.fb_key)

    if not canAccess and not allowOverride then
        return false, reason
    end

    session.participants[charID] = {
        char_id = charID,
        steamid64 = target:SteamID64(),
        name = target:Nick(),
        result = PD.FB.RESULT_OPEN,
        note = ""
    }

    writeParticipant(session.session_id, session.participants[charID])
    PD.Notify("Du wurdest zum Kurs '" .. PD.FB.GetCourseName(session.fb_key) .. "' hinzugefügt", Color(60, 140, 60), false, target)

    return true
end

function PD.FB.RemoveParticipant(session, charID)
    if not session or not session.participants[charID] then return false end

    session.participants[charID] = nil

    PD.SQL.Query("DELETE FROM `" .. TBL_PARTICIPANTS .. "` WHERE `session_id` = " .. tonumber(session.session_id)
        .. " AND `char_id` = " .. esc(charID))

    return true
end

function PD.FB.SetParticipantResult(session, charID, result, note)
    if not session or not session.participants[charID] then return false end

    local participant = session.participants[charID]
    participant.result = result
    participant.note = note or participant.note or ""

    writeParticipant(session.session_id, participant)

    return true
end

-- Kurs abschließen: alle Bestandenen bekommen die Fortbildung, der Rest bleibt
-- als Durchgefallen in der Historie stehen.
function PD.FB.FinishSession(session, ply)
    if not session or session.state ~= PD.FB.STATE_OPEN then return false, "Kurs nicht offen" end

    session.state = PD.FB.STATE_DONE
    session.ended_at = os.time()

    local passed = 0
    local instructorChar = PD.FB.GetCharID(ply) or session.instructor_char

    for charID, participant in pairs(session.participants) do
        if participant.result == PD.FB.RESULT_PASSED then
            passed = passed + 1
            PD.FB.Grant(charID, session.fb_key, participant.steamid64, instructorChar, session.session_id)
        end
    end

    writeSession(session)
    PD.FB.Sessions[session.session_id] = nil

    log((IsValid(ply) and ply:Nick() or "System") .. " hat den Kurs '" .. PD.FB.GetCourseName(session.fb_key)
        .. "' abgeschlossen (" .. passed .. " bestanden)")

    return true
end

function PD.FB.CancelSession(session, ply)
    if not session or session.state ~= PD.FB.STATE_OPEN then return false end

    session.state = PD.FB.STATE_CANCELLED
    session.ended_at = os.time()

    writeSession(session)
    PD.FB.Sessions[session.session_id] = nil

    log((IsValid(ply) and ply:Nick() or "System") .. " hat den Kurs '" .. PD.FB.GetCourseName(session.fb_key) .. "' abgebrochen")

    return true
end

function PD.FB.SendSessionState(session)
    if not session then return end

    local payload = {
        session_id = session.session_id,
        fb_key = session.fb_key,
        instructor_name = session.instructor_name,
        started_at = session.started_at,
        state = session.state,
        participants = session.participants
    }

    local instructor = FindPlayerbyCharID and FindPlayerbyCharID(session.instructor_char)

    if IsValid(instructor) then
        net.Start("PD.FB.SessionState")
            net.WriteBool(true)
            net.WriteTable(payload)
        net.Send(instructor)
    end
end

function PD.FB.SendSessionClosed(charID)
    local ply = FindPlayerbyCharID and FindPlayerbyCharID(charID)
    if not IsValid(ply) then return end

    net.Start("PD.FB.SessionState")
        net.WriteBool(false)
    net.Send(ply)
end

--------------------------------------------------------------------------------
-- Historie
--------------------------------------------------------------------------------

function PD.FB.FetchHistory(charID, callback)
    local query = "SELECT p.*, s.fb_key, s.instructor_name, s.started_at, s.ended_at, s.state "
        .. "FROM `" .. TBL_PARTICIPANTS .. "` p "
        .. "JOIN `" .. TBL_SESSIONS .. "` s ON s.session_id = p.session_id "
        .. "WHERE p.char_id = " .. esc(charID) .. " ORDER BY s.started_at DESC LIMIT 100"

    PD.SQL.FetchAll(query, function(rows)
        callback(rows or {})
    end)
end

function PD.FB.FetchCourseHistory(key, callback)
    local query = "SELECT * FROM `" .. TBL_SESSIONS .. "` WHERE `fb_key` = " .. esc(key)
        .. " ORDER BY `started_at` DESC LIMIT 100"

    PD.SQL.FetchAll(query, function(rows)
        callback(rows or {})
    end)
end

--------------------------------------------------------------------------------
-- Ablauf
--------------------------------------------------------------------------------

function PD.FB.CheckExpiries()
    if not PD.FB.Ready then return end

    local now = os.time()
    local warnThreshold = now + PD.FB.WarnDays * 86400

    for _, ply in ipairs(player.GetAll()) do
        local charID = PD.FB.GetCharID(ply)
        if not charID then continue end

        local granted = PD.FB.Granted[charID]
        if not granted then continue end

        local changed = false

        for key, entry in pairs(granted) do
            if entry.expires_at and entry.expires_at > 0 then
                if entry.expires_at <= now then
                    if not entry.expired_notified then
                        entry.expired_notified = true
                        changed = true
                        PD.Notify("Fortbildung abgelaufen: " .. PD.FB.GetCourseName(key), Color(178, 60, 60), false, ply)
                    end
                elseif entry.expires_at <= warnThreshold and not entry.warn_notified then
                    entry.warn_notified = true
                    PD.Notify("Fortbildung läuft bald ab: " .. PD.FB.GetCourseName(key)
                        .. " (" .. PD.FB.FormatRemaining(entry) .. ")", Color(200, 150, 40), false, ply)
                end
            end
        end

        if changed then
            PD.FB.SyncPlayer(ply)
            PD.FB.SyncPublicBadges()
        end
    end
end

function PD.FB.CleanupChar(charID)
    if not charID then return end

    PD.FB.Granted[charID] = nil

    PD.SQL.Query("DELETE FROM `" .. TBL_GRANTED .. "` WHERE `char_id` = " .. esc(charID))
end

--------------------------------------------------------------------------------
-- Netzwerk
--------------------------------------------------------------------------------

local function onCooldown(ply)
    local sid = ply:SteamID64()

    if syncCooldowns[sid] and syncCooldowns[sid] > CurTime() then
        return true
    end

    syncCooldowns[sid] = CurTime() + SYNC_COOLDOWN

    return false
end

net.Receive("PD.FB.SyncCatalog", function(len, ply)
    if not IsValid(ply) then return end
    if onCooldown(ply) then return end

    PD.FB.SyncCatalog(ply)
    PD.FB.SyncPlayer(ply)
    PD.FB.SyncPublicBadges(ply)
end)

local sessionActions = {}

sessionActions["start"] = function(ply)
    local key = net.ReadString()
    local session, err = PD.FB.StartSession(ply, key)

    if not session then
        PD.Notify(err or "Kurs konnte nicht gestartet werden", Color(178, 60, 60), false, ply)
        return
    end

    PD.FB.SendSessionState(session)
end

sessionActions["add"] = function(ply)
    local target = net.ReadEntity()
    local session = PD.FB.GetSessionOf(ply)

    if not session then return end

    local ok, err = PD.FB.AddParticipant(session, target, ply:IsAdmin())

    if not ok then
        PD.Notify(err or "Teilnehmer konnte nicht eingetragen werden", Color(178, 60, 60), false, ply)
        return
    end

    PD.FB.SendSessionState(session)
end

sessionActions["remove"] = function(ply)
    local charID = net.ReadString()
    local session = PD.FB.GetSessionOf(ply)

    if not session then return end

    PD.FB.RemoveParticipant(session, charID)
    PD.FB.SendSessionState(session)
end

sessionActions["result"] = function(ply)
    local charID = net.ReadString()
    local result = net.ReadUInt(4)
    local note = string.sub(net.ReadString(), 1, 255)
    local session = PD.FB.GetSessionOf(ply)

    if not session then return end
    if result ~= PD.FB.RESULT_OPEN and result ~= PD.FB.RESULT_PASSED and result ~= PD.FB.RESULT_FAILED then return end

    PD.FB.SetParticipantResult(session, charID, result, note)
    PD.FB.SendSessionState(session)
end

sessionActions["finish"] = function(ply)
    local session = PD.FB.GetSessionOf(ply)
    if not session then return end

    local charID = session.instructor_char

    PD.FB.FinishSession(session, ply)
    PD.FB.SendSessionClosed(charID)
end

sessionActions["cancel"] = function(ply)
    local session = PD.FB.GetSessionOf(ply)
    if not session then return end

    local charID = session.instructor_char

    PD.FB.CancelSession(session, ply)
    PD.FB.SendSessionClosed(charID)
end

net.Receive("PD.FB.Session", function(len, ply)
    if not IsValid(ply) then return end

    local action = net.ReadString()

    if sessionActions[action] then
        sessionActions[action](ply)
    end
end)

net.Receive("PD.FB.History", function(len, ply)
    if not IsValid(ply) then return end

    local charID = net.ReadString()

    -- Fremde Historie nur für Admins
    if charID ~= PD.FB.GetCharID(ply) and not ply:IsAdmin() then return end

    PD.FB.FetchHistory(charID, function(rows)
        if not IsValid(ply) then return end

        net.Start("PD.FB.History")
            net.WriteString(charID)
            net.WriteTable(rows)
        net.Send(ply)
    end)
end)

--------------------------------------------------------------------------------
-- Hooks
--------------------------------------------------------------------------------

-- Kein Abonnent für PD_Loadout_Applied: Fortbildungen geben keine Ausrüstung
-- aus, sie schalten sie frei. Siehe Kommentar bei PD.FB.ApplyBadges.

hook.Add("PD_Model_Applied", "PD.FB.ApplyBadges", function(ply)
    PD.FB.ApplyBadges(ply)
end)

-- Der Hook liefert die Charakter-Tabelle, nicht die ID (sv_char.lua:226).
hook.Add("PlayerDeleteCharacter", "PD.FB.CleanupChar", function(ply, deletingChar)
    if not istable(deletingChar) then return end

    PD.FB.CleanupChar(deletingChar.id)
end)

hook.Add("PD_Faction_Change", "PD.FB.ResyncOnFactionChange", function(ply)
    if not IsValid(ply) then return end

    timer.Simple(0, function()
        if IsValid(ply) then
            PD.FB.SyncPlayer(ply)
        end

        -- Auch die Abzeichen aller fuer Scoreboard und ID-Karte: der Hook
        -- feuert bei der Charakterwahl, und erst ab dann gibt es eine
        -- Charakter-ID, zu der Abzeichen gehoeren. Beim Join (noch ohne
        -- Charakter) war die Liste fuer diesen Spieler leer geblieben.
        PD.FB.SyncPublicBadges()
    end)
end)

hook.Add("PlayerInitialSpawn", "PD.FB.SyncOnJoin", function(ply)
    timer.Simple(3, function()
        if not IsValid(ply) then return end

        PD.FB.SyncCatalog(ply)
        PD.FB.SyncPlayer(ply)
        PD.FB.SyncPublicBadges()
    end)
end)

hook.Add("PlayerDisconnected", "PD.FB.CleanupSessions", function(ply)
    syncCooldowns[ply:SteamID64()] = nil

    local session = PD.FB.GetSessionOf(ply)

    if session then
        PD.FB.CancelSession(session, ply)
    end
end)

--------------------------------------------------------------------------------
-- Initialisierung
--------------------------------------------------------------------------------

-- PostPDLoaded ist in init.lua auskommentiert und feuert nie, daher wie die
-- übrigen Module über einen Timer nach dem Laden.
timer.Simple(1, function()
    PD.FB.EnsureTables(function()
        PD.FB.LoadCourses(function()
            PD.FB.LoadGranted(function()
                PD.SQL.FetchOne("SELECT MAX(`session_id`) AS `maxid` FROM `" .. TBL_SESSIONS .. "`", function(row)
                    nextSessionID = (tonumber(row and row.maxid) or 0) + 1

                    PD.FB.Ready = true
                    PD.FB.SyncAll()

                    PD.RemoteLog("[Fortbildung] " .. table.Count(PD.FB.Courses) .. " Fortbildungen geladen, "
                        .. table.Count(PD.FB.Granted) .. " Charaktere mit Vergaben")
                end)
            end)
        end)
    end)
end)

timer.Create("PD.FB.CheckExpiries", 60, 0, function()
    PD.FB.CheckExpiries()
end)

concommand.Add("pd_fb_print", function(ply)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    PrintTable(PD.FB.Courses)
end)
