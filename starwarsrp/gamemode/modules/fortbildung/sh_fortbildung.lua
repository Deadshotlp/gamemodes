PD = PD or {}
PD.FB = PD.FB or {}

-- Katalog aller Fortbildungen: fb_key -> Definition. Auf Server und Client identisch.
PD.FB.Courses = PD.FB.Courses or {}

-- Vergebene Fortbildungen: char_id -> { fb_key -> entry }
-- Server: alle Charaktere. Client: nur der eigene.
PD.FB.Granted = PD.FB.Granted or {}

-- Fortbildungen, die der lokale Spieler machen darf. Nur Client, wird vom Server
-- gesetzt - die Zugangsprüfung braucht Fraktionsdaten, die nur serverseitig
-- zuverlässig als Keys vorliegen.
PD.FB.Eligible = PD.FB.Eligible or {}

-- Abzeichen aller Spieler für Scoreboard und ID-Karte: char_id -> { fb_key, ... }
PD.FB.PublicBadges = PD.FB.PublicBadges or {}

-- Offene Kurse, die den lokalen Spieler betreffen (Client) bzw. alle (Server)
PD.FB.Sessions = PD.FB.Sessions or {}

PD.FB.RESULT_OPEN = 0
PD.FB.RESULT_PASSED = 1
PD.FB.RESULT_FAILED = 2

PD.FB.STATE_OPEN = 0
PD.FB.STATE_DONE = 1
PD.FB.STATE_CANCELLED = 2

PD.FB.WarnDays = 3 -- Vorlauf in Tagen für die Ablaufwarnung
PD.FB.AnyModel = "*" -- Platzhalter im Abzeichen für "gilt für jedes Model"

PD.FB.ResultNames = {
    [PD.FB.RESULT_OPEN] = "Offen",
    [PD.FB.RESULT_PASSED] = "Bestanden",
    [PD.FB.RESULT_FAILED] = "Durchgefallen"
}

PD.FB.StateNames = {
    [PD.FB.STATE_OPEN] = "Läuft",
    [PD.FB.STATE_DONE] = "Abgeschlossen",
    [PD.FB.STATE_CANCELLED] = "Abgebrochen"
}

-- Leere Fortbildung mit allen Feldern. Einzige Stelle, an der die Defaults stehen -
-- Editor, SQL-Laden und Migration bauen ihre Datensätze darauf auf.
function PD.FB.NewCourse()
    return {
        fb_key = "",
        name = "Neue Fortbildung",
        description = "",
        position = 0,
        color = Color(60, 140, 60),
        equip = {},
        model = {},
        badge = {skin = nil, bodygroups = {}, icon = nil},
        access = {units = {}, subunits = {}, jobs = {}},
        teach = {},
        requires = {},
        duration_days = 0,
        max_holders = 0
    }
end

-- charID des Spielers, oder nil wenn kein Charakter aktiv ist. Das Char-System
-- setzt "9999" für "kein Charakter gewählt".
function PD.FB.GetCharID(ply)
    if not IsValid(ply) then return nil end

    local charID = ply:GetCharacterID()

    if not charID or charID == "" or charID == "9999" then return nil end

    return charID
end

function PD.FB.GetCourse(key)
    if not key then return nil end

    return PD.FB.Courses[key]
end

function PD.FB.GetCourseName(key)
    local course = PD.FB.GetCourse(key)

    return course and course.name or key or "?"
end

-- Nach position sortierte Liste. Die Reihenfolge ist gleichzeitig die Priorität,
-- mit der Abzeichen kollidierende Bodygroups überschreiben.
function PD.FB.GetSortedCourses()
    local list = {}

    for _, course in pairs(PD.FB.Courses) do
        table.insert(list, course)
    end

    table.sort(list, function(a, b)
        if a.position == b.position then
            return a.name < b.name
        end

        return a.position < b.position
    end)

    return list
end

function PD.FB.IsExpired(entry)
    if not entry then return true end
    if not entry.expires_at or entry.expires_at <= 0 then return false end

    return os.time() >= entry.expires_at
end

-- Besitz inklusive Ablaufprüfung. Abgelaufene Einträge bleiben in der Datenbank
-- stehen (für die Historie), zählen hier aber nicht mehr.
function PD.FB.HasCourse(charID, key)
    if not charID or not key then return false end

    local granted = PD.FB.Granted[charID]
    if not granted then return false end

    local entry = granted[key]
    if not entry then return false end

    return not PD.FB.IsExpired(entry)
end

function PD.FB.GetActiveCourses(charID)
    local active = {}

    if not charID then return active end

    local granted = PD.FB.Granted[charID]
    if not granted then return active end

    for key, entry in pairs(granted) do
        if PD.FB.Courses[key] and not PD.FB.IsExpired(entry) then
            active[key] = entry
        end
    end

    return active
end

-- Welche Fortbildungen darf dieser Charakter ausbilden? Ergibt sich aus dem
-- teach-Feld seiner eigenen aktiven Fortbildungen - eine Fortbildung "Ausbilder
-- Sanitätswesen" trägt dort die Keys der Sani-Lehrgänge.
function PD.FB.GetTeachableCourses(charID)
    local teachable = {}

    for key in pairs(PD.FB.GetActiveCourses(charID)) do
        local course = PD.FB.Courses[key]

        for _, target in ipairs(course.teach or {}) do
            teachable[target] = true
        end
    end

    return teachable
end

function PD.FB.CanTeachCourse(charID, key)
    if not key then return false end

    return PD.FB.GetTeachableCourses(charID)[key] == true
end

-- Voraussetzungen erfüllt? Getrennt von der Unit-Prüfung, weil sie auf beiden
-- Realms funktioniert und der Client sie zur Anzeige braucht.
function PD.FB.HasRequirements(charID, key)
    local course = PD.FB.GetCourse(key)
    if not course then return false, "Unbekannte Fortbildung" end

    for _, required in ipairs(course.requires or {}) do
        if not PD.FB.HasCourse(charID, required) then
            return false, "Voraussetzung fehlt: " .. PD.FB.GetCourseName(required)
        end
    end

    return true
end

-- Nur der Fortbildungsanteil an Ausrüstung und Models, ohne Job und Subunit.
-- Umkleide und Waffenkiste hängen ihn clientseitig an ihre bestehenden Listen an;
-- serverseitig übernimmt das PD.FB.GetAllowedEquip/GetAllowedModels komplett.
function PD.FB.GetCourseEquip(charID)
    local list = {}

    for key in pairs(PD.FB.GetActiveCourses(charID)) do
        for _, weapon in pairs(PD.FB.Courses[key].equip or {}) do
            if not table.HasValue(list, weapon) then
                table.insert(list, weapon)
            end
        end
    end

    return list
end

function PD.FB.GetCourseModels(charID)
    local list = {}

    for key in pairs(PD.FB.GetActiveCourses(charID)) do
        for _, model in pairs(PD.FB.Courses[key].model or {}) do
            if not table.HasValue(list, model) then
                table.insert(list, model)
            end
        end
    end

    return list
end

function PD.FB.CountHolders(key)
    local count = 0

    for charID, granted in pairs(PD.FB.Granted) do
        if granted[key] and not PD.FB.IsExpired(granted[key]) then
            count = count + 1
        end
    end

    return count
end

-- net.WriteTable liefert Farben je nach Version als Color oder als einfache
-- Tabelle zurück. Hier wird immer eine echte Color daraus.
function PD.FB.ToColor(value, fallback)
    if not istable(value) then
        return fallback or Color(255, 255, 255)
    end

    return Color(value.r or 255, value.g or 255, value.b or 255, value.a or 255)
end

function PD.FB.FormatDate(timestamp)
    if not timestamp or timestamp <= 0 then return "-" end

    return os.date("%d.%m.%Y %H:%M", timestamp)
end

function PD.FB.FormatRemaining(entry)
    if not entry then return "-" end
    if not entry.expires_at or entry.expires_at <= 0 then return "unbefristet" end

    local remaining = entry.expires_at - os.time()

    if remaining <= 0 then return "abgelaufen" end

    local days = math.floor(remaining / 86400)

    if days >= 1 then
        return "noch " .. days .. (days == 1 and " Tag" or " Tage")
    end

    local hours = math.floor(remaining / 3600)

    if hours >= 1 then
        return "noch " .. hours .. (hours == 1 and " Stunde" or " Stunden")
    end

    return "noch unter einer Stunde"
end

--[[
    Kleines Icon einer Fortbildung (badge.icon, Material-Pfad wie
    "icon16/star.png"). Gibt das Material oder nil zurueck.
]]
if CLIENT then
    local iconCache = {}

    function PD.FB.IconMaterial(course)
        local path = course and course.badge and course.badge.icon
        if not isstring(path) or path == "" or not string.match(path, "^[%w_/%-%.]+$") then return nil end
        if iconCache[path] == nil then
            local mat = Material(path, "smooth mips")
            iconCache[path] = (mat and not mat:IsError()) and mat or false
        end
        return iconCache[path] or nil
    end

    -- Icon zeichnen (16 x 16 skaliert); gibt die Breite inkl. Abstand zurueck
    function PD.FB.DrawIcon(course, x, y, size)
        local mat = PD.FB.IconMaterial(course)
        if not mat then return 0 end
        size = size or 16
        surface.SetMaterial(mat)
        surface.SetDrawColor(255, 255, 255)
        surface.DrawTexturedRect(x, y, size, size)
        return size + 6
    end
end
