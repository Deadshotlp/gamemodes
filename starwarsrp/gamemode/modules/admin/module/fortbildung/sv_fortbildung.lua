PD.FB = PD.FB or {}

util.AddNetworkString("PD.FB.Admin")
util.AddNetworkString("PD.FB.Grant")
util.AddNetworkString("PD.FB.Revoke")
util.AddNetworkString("PD.FB.AdminGrants")

local function isAllowed(ply)
    return IsValid(ply) and ply:IsAdmin()
end

local function nextCourseKey()
    local index = 1

    while PD.FB.Courses["FB_" .. index] do
        index = index + 1
    end

    return "FB_" .. index
end

local function log(ply, text)
    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("fortbildung", (IsValid(ply) and ply:Nick() or "System") .. " " .. text, Color(60, 140, 60))
    end
end

-- Werte feldweise aus der Client-Tabelle übernehmen. Nie die Tabelle direkt
-- speichern - sonst schleust ein manipulierter Client beliebige Felder ein.
local function sanitizeCourse(key, input, existing)
    local course = existing or PD.FB.NewCourse()

    course.fb_key = key
    course.name = string.sub(tostring(input.name or "Neue Fortbildung"), 1, 128)
    course.description = string.sub(tostring(input.description or ""), 1, 2000)
    course.position = math.Clamp(tonumber(input.position) or 0, 0, 9999)
    course.duration_days = math.Clamp(tonumber(input.duration_days) or 0, 0, 3650)
    course.max_holders = math.Clamp(tonumber(input.max_holders) or 0, 0, 9999)

    if IsColor(input.color) then
        course.color = Color(input.color.r, input.color.g, input.color.b, input.color.a or 255)
    end

    local function stringArray(source, limit)
        local out = {}

        for _, value in pairs(source or {}) do
            if isstring(value) and value ~= "" and #out < (limit or 128) then
                table.insert(out, string.sub(value, 1, 190))
            end
        end

        return out
    end

    local function keySet(source, limit)
        local out = {}
        local count = 0

        for value, enabled in pairs(source or {}) do
            if enabled and isstring(value) and count < (limit or 256) then
                out[string.sub(value, 1, 190)] = true
                count = count + 1
            end
        end

        return out
    end

    course.equip = stringArray(input.equip)
    course.model = stringArray(input.model)
    course.teach = stringArray(input.teach)
    course.requires = stringArray(input.requires)

    -- Eine Fortbildung darf sich nicht selbst voraussetzen
    for i = #course.requires, 1, -1 do
        if course.requires[i] == key then
            table.remove(course.requires, i)
        end
    end

    course.access = {
        units = keySet((input.access or {}).units),
        subunits = keySet((input.access or {}).subunits),
        jobs = keySet((input.access or {}).jobs)
    }

    local badge = {bodygroups = {}}
    local inputBadge = input.badge or {}

    if inputBadge.skin ~= nil then
        badge.skin = math.Clamp(tonumber(inputBadge.skin) or 0, 0, 63)
    end

    for _, entry in pairs(inputBadge.bodygroups or {}) do
        if istable(entry) and #badge.bodygroups < 32 then
            table.insert(badge.bodygroups, {
                model = isstring(entry.model) and string.sub(entry.model, 1, 190) or PD.FB.AnyModel,
                index = math.Clamp(tonumber(entry.index) or 0, 0, 63),
                value = math.Clamp(tonumber(entry.value) or 0, 0, 63)
            })
        end
    end

    course.badge = badge

    return course
end

local adminActions = {}

adminActions["create"] = function(ply)
    local input = net.ReadTable()
    local key = nextCourseKey()
    local course = sanitizeCourse(key, input)

    PD.FB.Courses[key] = course

    PD.FB.SaveCourses(function(ok)
        if not ok then
            PD.Notify("Speichern fehlgeschlagen", Color(178, 60, 60), false, ply)
            return
        end

        PD.FB.SendCourseDelta(key, course)
        log(ply, "hat die Fortbildung '" .. course.name .. "' angelegt")
    end)
end

adminActions["update"] = function(ply)
    local key = net.ReadString()
    local input = net.ReadTable()

    if not PD.FB.Courses[key] then return end

    local course = sanitizeCourse(key, input, PD.FB.Courses[key])
    PD.FB.Courses[key] = course

    PD.FB.SaveCourses(function(ok)
        if not ok then
            PD.Notify("Speichern fehlgeschlagen", Color(178, 60, 60), false, ply)
            return
        end

        PD.FB.SendCourseDelta(key, course)
        log(ply, "hat die Fortbildung '" .. course.name .. "' bearbeitet")

        -- Freigaben können sich geändert haben
        for _, target in ipairs(player.GetAll()) do
            PD.FB.SyncPlayer(target)
        end
    end)
end

adminActions["delete"] = function(ply)
    local key = net.ReadString()
    local course = PD.FB.Courses[key]

    if not course then return end

    local name = course.name

    PD.FB.Courses[key] = nil

    -- Querverweise anderer Fortbildungen mit aufräumen
    for _, other in pairs(PD.FB.Courses) do
        for i = #other.teach, 1, -1 do
            if other.teach[i] == key then table.remove(other.teach, i) end
        end

        for i = #other.requires, 1, -1 do
            if other.requires[i] == key then table.remove(other.requires, i) end
        end
    end

    -- Vergaben mitlöschen, sonst bleiben verwaiste Zeilen zurück
    for charID, granted in pairs(PD.FB.Granted) do
        granted[key] = nil
    end

    PD.SQL.Query("DELETE FROM `pd_fb_granted` WHERE `fb_key` = " .. PD.SQL.EscapeString(key))

    PD.FB.SaveCourses(function()
        PD.FB.SendCourseDelta(key, nil)
        PD.FB.SyncAll()
        log(ply, "hat die Fortbildung '" .. name .. "' gelöscht")
    end)
end

net.Receive("PD.FB.Admin", function(len, ply)
    if not isAllowed(ply) then return end

    local action = net.ReadString()

    if adminActions[action] then
        adminActions[action](ply)
    end
end)

net.Receive("PD.FB.Grant", function(len, ply)
    if not isAllowed(ply) then return end

    local target = net.ReadEntity()
    local key = net.ReadString()

    if not IsValid(target) then return end

    local charID = PD.FB.GetCharID(target)

    if not charID then
        PD.Notify("Zielspieler hat keinen Charakter aktiv", Color(178, 60, 60), false, ply)
        return
    end

    if not PD.FB.GetCourse(key) then return end

    -- Bewusst ohne CanAccess: das ist der Admin-Override für RP-Sonderfälle.
    PD.FB.Grant(charID, key, target:SteamID64(), PD.FB.GetCharID(ply) or "", 0, function()
        PD.Notify("Fortbildung vergeben", Color(60, 140, 60), false, ply)
        log(ply, "hat " .. target:Nick() .. " die Fortbildung '" .. PD.FB.GetCourseName(key) .. "' vergeben (Override)")
    end)
end)

net.Receive("PD.FB.Revoke", function(len, ply)
    if not isAllowed(ply) then return end

    local charID = net.ReadString()
    local key = net.ReadString()

    if not PD.FB.GetCourse(key) then return end

    PD.FB.Revoke(charID, key, function()
        PD.Notify("Fortbildung entzogen", Color(200, 150, 40), false, ply)
        log(ply, "hat die Fortbildung '" .. PD.FB.GetCourseName(key) .. "' von " .. charID .. " entzogen")
    end)
end)

-- Vergaben eines beliebigen Spielers für die Admin-Ansicht
net.Receive("PD.FB.AdminGrants", function(len, ply)
    if not isAllowed(ply) then return end

    local charID = net.ReadString()

    net.Start("PD.FB.AdminGrants")
        net.WriteString(charID)
        net.WriteTable(PD.FB.Granted[charID] or {})
    net.Send(ply)
end)
