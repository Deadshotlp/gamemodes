--[[
    Charakter-Einstellungen aus der Datenbank (Web-Panel, Seite "Charaktere").

      pd_char_config   config_key, config_value (JSON)

    Schluessel und Startwerte stehen in DEFAULTS - das sind die bisher in
    sh_char.lua fest eingetragenen Werte. Beim ersten Start werden sie in die
    Tabelle geschrieben. Neu laden: pd_reload charakter.

    Die Werte landen in den bekannten Feldern (PD.Char.MaxChars, MinName, ...),
    damit der restliche Code unveraendert bleibt. Der Client bekommt sie per
    Netzwerk, weil das Charaktermenue dieselben Grenzen anzeigt.
]]

PD.Char = PD.Char or {}

local DEFAULTS = {
    max_chars = 5,
    default_slots = 2,
    slots_by_group = {
        user = 2,
        projekt = 5,
        Developer = 5,
        teamleitung = 4,
        moderator = 3,
        supporter = 3,
        eventler = 3,
        superadmin = 5,
    },
    name_min = 3,
    name_max = 20,
    name_blacklist = {},
    id_prefix = "CT-",
    -- "#" = Ziffer; die erste Ziffer eines Blocks ist nie 0 (wie bisher 10-99 / 1000-9999).
    id_format = "##-####",
    id_blocked = {},
    background = "mario/void_logo.png",
    discord = "",
    kollektion = "",
    default_job = "",
}

PD.Char.ConfigDefaults = DEFAULTS

-- Werte auf die bisherigen Felder abbilden.
function PD.Char.ApplyConfig(cfg)
    local function get(key)
        local value = cfg[key]
        if value == nil then return DEFAULTS[key] end
        return value
    end

    PD.Char.MaxChars = math.Clamp(tonumber(get("max_chars")) or 5, 1, 20)
    PD.Char.DefaultSlots = math.Clamp(tonumber(get("default_slots")) or 2, 0, 20)
    PD.Char.UserGroupChar = istable(get("slots_by_group")) and get("slots_by_group") or DEFAULTS.slots_by_group
    PD.Char.MinName = math.Clamp(tonumber(get("name_min")) or 3, 1, 64)
    PD.Char.MaxName = math.Clamp(tonumber(get("name_max")) or 20, PD.Char.MinName, 64)

    local blacklist = {}
    for _, word in ipairs(istable(get("name_blacklist")) and get("name_blacklist") or {}) do
        word = string.Trim(tostring(word))
        if word ~= "" then blacklist[word] = true end
    end
    PD.Char.NameBlacklist = blacklist

    PD.Char.IDPrefix = tostring(get("id_prefix") or "")
    PD.Char.IDFormat = tostring(get("id_format") or "##-####")

    local blocked = {}
    for _, entry in ipairs(istable(get("id_blocked")) and get("id_blocked") or {}) do
        entry = string.upper(string.Trim(tostring(entry)))
        if entry ~= "" then blocked[entry] = true end
    end
    PD.Char.NotAllowedNumbers = blocked

    PD.Char.Background = tostring(get("background") or "")
    PD.Char.Discord = tostring(get("discord") or "")
    PD.Char.Kollektion = tostring(get("kollektion") or "")
    PD.Char.DefaultJob = tostring(get("default_job") or "")

    PD.Char.Config = cfg
end

-- Slots fuer die Benutzergruppe eines Spielers (gedeckelt durch MaxChars).
function PD.Char.GetSlotLimit(ply)
    local group = IsValid(ply) and ply:GetUserGroup() or "user"
    local slots = (PD.Char.UserGroupChar or {})[group] or PD.Char.DefaultSlots or 2

    return math.min(tonumber(slots) or 2, PD.Char.MaxChars or 5)
end

-- Neue ID nach dem Format erzeugen, z. B. "##-####" -> "47-3820".
function PD.Char.GenerateID()
    local out = {}
    local previousDigit = false

    for char in string.gmatch(PD.Char.IDFormat or "##-####", ".") do
        if char == "#" then
            out[#out + 1] = tostring(previousDigit and math.random(0, 9) or math.random(1, 9))
            previousDigit = true
        else
            out[#out + 1] = char
            previousDigit = false
        end
    end

    return table.concat(out)
end

-- Gesperrt, wenn die ganze ID oder einer ihrer Bloecke auf der Sperrliste steht.
function PD.Char.IsIDBlocked(id)
    local blocked = PD.Char.NotAllowedNumbers or {}
    id = string.upper(tostring(id or ""))

    if blocked[id] then return true end

    for block in string.gmatch(id, "[^%-_]+") do
        if blocked[block] then return true end
    end

    return false
end

-- Beim Lua-Refresh die zuletzt geladenen Werte behalten, nicht auf Startwerte fallen.
PD.Char.ApplyConfig(PD.Char.Config or {})

if CLIENT then
    net.Receive("PD.Char.Config", function()
        local cfg = util.JSONToTable(net.ReadString() or "") or {}
        PD.Char.ApplyConfig(cfg)
    end)

    return
end

--------------------------------------------------------------------------------
-- Server
--------------------------------------------------------------------------------

util.AddNetworkString("PD.Char.Config")

local TBL = "pd_char_config"

-- Nur was der Client anzeigt; die Sperrlisten bleiben auf dem Server.
local CLIENT_KEYS = {
    "max_chars", "default_slots", "slots_by_group", "name_min", "name_max",
    "id_prefix", "background", "discord", "kollektion",
}

function PD.Char.SendConfig(target)
    local cfg = PD.Char.Config or {}
    local out = {}

    for _, key in ipairs(CLIENT_KEYS) do
        out[key] = cfg[key]
    end

    net.Start("PD.Char.Config")
    net.WriteString(util.TableToJSON(out) or "{}")

    if target then net.Send(target) else net.Broadcast() end
end

function PD.Char.LoadConfig(callback)
    local create = "CREATE TABLE IF NOT EXISTS `" .. TBL .. "` ("
        .. "`config_key` VARCHAR(64) NOT NULL,"
        .. "`config_value` TEXT NOT NULL,"
        .. "PRIMARY KEY (`config_key`)"
        .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

    PD.SQL.Query(create, function()
        PD.SQL.FetchAll("SELECT * FROM `" .. TBL .. "`", function(rows)
            local cfg = {}
            local present = {}

            for _, row in ipairs(rows or {}) do
                present[row.config_key] = true

                local decoded = util.JSONToTable("{\"v\":" .. tostring(row.config_value) .. "}")
                if decoded and decoded.v ~= nil then
                    cfg[row.config_key] = decoded.v
                end
            end

            -- Fehlende Schluessel mit den Startwerten anlegen.
            for key, value in pairs(DEFAULTS) do
                if not present[key] then
                    cfg[key] = value

                    local json = util.TableToJSON({v = value})
                    json = string.match(json or "", "^{\"v\":(.*)}$") or "null"

                    PD.SQL.Query("INSERT IGNORE INTO `" .. TBL .. "` (`config_key`, `config_value`) VALUES ("
                        .. PD.SQL.EscapeString(key) .. ", " .. PD.SQL.EscapeString(json) .. ")")
                end
            end

            PD.Char.ApplyConfig(cfg)
            PD.Char.SendConfig()

            if callback then callback(true) end
        end)
    end)
end

hook.Add("PlayerInitialSpawn", "PD.Char.Config", function(ply)
    -- Vor dem Charaktermenue, damit Slots und Namensgrenzen stimmen.
    timer.Simple(1, function()
        if IsValid(ply) then PD.Char.SendConfig(ply) end
    end)
end)

timer.Simple(2, function()
    PD.Char.LoadConfig(function()
        print("[PD.Char] Charakter-Einstellungen geladen (Praefix " .. tostring(PD.Char.IDPrefix)
            .. ", Format " .. tostring(PD.Char.IDFormat) .. ", max. " .. tostring(PD.Char.MaxChars) .. " Charaktere)")
    end)
end)
