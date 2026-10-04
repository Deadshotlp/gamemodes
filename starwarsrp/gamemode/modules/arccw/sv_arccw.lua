--[[
    ArcCW-Werte: Datenbank, Anwendung, Verteilung.

    Vier Tabellen, alle mit JSON-Spalte statt einer Spalte je Wert. So kommt ein
    neues Feld ohne Wanderung der Datenbank dazu - die Liste in sh_arccw.lua
    bestimmt, was es gibt, und das Panel richtet sich danach.

    pd_arccw_stats      Ausgangswerte der Waffen aus dem Addon, nur zur Anzeige
    pd_arccw_overrides  Abweichungen der Waffen
    pd_arccw_atts       Ausgangswerte der Aufsaetze, nur zur Anzeige
    pd_arccw_att_over   Abweichungen der Aufsaetze und Trefferzonen

    Geaendert wird nie das Addon selbst. Bei einem Update der ArcCW-Pakete
    bleiben die Anpassungen deshalb bestehen.
]]

PD = PD or {}
PD.ACW = PD.ACW or {}

local TBL_STATS = "pd_arccw_stats"
local TBL_OVERRIDES = "pd_arccw_overrides"
local TBL_ATTS = "pd_arccw_atts"
local TBL_ATT_OVER = "pd_arccw_att_over"
local TBL_ZONES = "pd_arccw_zones"
local TBL_BLOCKS = "pd_arccw_blocks"

-- Weit genug nach dem Start, dass alle Addons ihre Waffen angemeldet haben.
local SNAPSHOT_DELAY = 15

util.AddNetworkString("PD.ACW:Sync")
-- Neues Format (komprimiert, in Teilen) unter eigenem Namen: ein Client mit
-- der alten Datei bekommt sie gar nicht erst, statt sie falsch zu lesen.
util.AddNetworkString("PD.ACW:SyncZ")

local function esc(value)
    return PD.SQL.EscapeString(tostring(value or ""))
end

local function serverKey()
    local convar = GetConVar("pd_server_key")

    return convar and convar:GetString() or "main"
end

--------------------------------------------------------------------------------
-- Tabellen
--------------------------------------------------------------------------------

--[[
    Spalten, die es geben muss.

    CREATE TABLE IF NOT EXISTS legt eine vorhandene Tabelle nicht um. Die erste
    Fassung dieses Moduls hatte je eine Spalte pro Wert; seit der Umstellung auf
    JSON fehlt solchen Tabellen die JSON-Spalte, und jedes Schreiben scheitert
    still an der Transaktion - im Panel stehen dann leere Felder, obwohl im
    Speicher alles gefuellt ist. Deshalb wird beim Start nachgesehen.

    Alte Spalten bleiben stehen. Sie stoeren nicht, und sie zu loeschen waere die
    einzige Aktion hier, die Daten vernichten koennte.
]]
local REQUIRED_COLUMNS = {
    [TBL_STATS] = {
        {"slots_json", "TEXT NULL"},
        {"stats_json", "TEXT NULL"}
    },
    [TBL_OVERRIDES] = {
        {"values_json", "TEXT NULL"},
        {"note", "VARCHAR(255) NOT NULL DEFAULT ''"}
    },
    [TBL_ATTS] = {
        {"name", "VARCHAR(191) NOT NULL DEFAULT ''"},
        {"slot", "VARCHAR(191) NOT NULL DEFAULT ''"},
        {"stats_json", "TEXT NULL"}
    },
    [TBL_ATT_OVER] = {
        {"values_json", "TEXT NULL"},
        {"note", "VARCHAR(255) NOT NULL DEFAULT ''"}
    },
    [TBL_ZONES] = {
        {"values_json", "TEXT NULL"}
    },
    [TBL_BLOCKS] = {
        {"atts_json", "TEXT NULL"}
    }
}

local function ensureColumns(callback)
    local tables = {}

    for name in pairs(REQUIRED_COLUMNS) do
        table.insert(tables, name)
    end

    local index = 0

    local function step()
        index = index + 1

        local name = tables[index]

        if not name then
            if isfunction(callback) then callback() end
            return
        end

        PD.SQL.FetchAll("SELECT `COLUMN_NAME` AS `column_name` FROM `information_schema`.`columns` "
            .. "WHERE `TABLE_SCHEMA` = DATABASE() AND `TABLE_NAME` = " .. esc(name),
        function(rows)
            local have = {}

            for _, row in ipairs(rows or {}) do
                have[string.lower(tostring(row.column_name))] = true
            end

            local adds = {}

            for _, column in ipairs(REQUIRED_COLUMNS[name]) do
                if not have[string.lower(column[1])] then
                    table.insert(adds, "ADD COLUMN `" .. column[1] .. "` " .. column[2])
                end
            end

            if #adds == 0 then
                step()
                return
            end

            PD.RemoteLog("[ArcCW] " .. name .. ": " .. #adds .. " fehlende Spalte(n) werden ergaenzt")

            PD.SQL.Query("ALTER TABLE `" .. name .. "` " .. table.concat(adds, ", "), step)
        end)
    end

    step()
end

function PD.ACW.EnsureTables(callback)
    local queries = {
        "CREATE TABLE IF NOT EXISTS `" .. TBL_STATS .. "` ("
            .. "`server_key` VARCHAR(64) NOT NULL,"
            .. "`class` VARCHAR(128) NOT NULL,"
            .. "`name` VARCHAR(191) NOT NULL DEFAULT '',"
            .. "`category` VARCHAR(191) NOT NULL DEFAULT '',"
            .. "`slots_json` TEXT NULL,"
            .. "`stats_json` TEXT NULL,"
            .. "`updated_at` BIGINT NOT NULL DEFAULT 0,"
            .. "PRIMARY KEY (`server_key`, `class`)"
            .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",

        "CREATE TABLE IF NOT EXISTS `" .. TBL_OVERRIDES .. "` ("
            .. "`server_key` VARCHAR(64) NOT NULL,"
            .. "`class` VARCHAR(128) NOT NULL,"
            .. "`values_json` TEXT NULL,"
            .. "`note` VARCHAR(255) NOT NULL DEFAULT '',"
            .. "`updated_at` BIGINT NOT NULL DEFAULT 0,"
            .. "PRIMARY KEY (`server_key`, `class`)"
            .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",

        "CREATE TABLE IF NOT EXISTS `" .. TBL_ATTS .. "` ("
            .. "`server_key` VARCHAR(64) NOT NULL,"
            .. "`att_id` VARCHAR(128) NOT NULL,"
            .. "`name` VARCHAR(191) NOT NULL DEFAULT '',"
            .. "`slot` VARCHAR(191) NOT NULL DEFAULT '',"
            .. "`stats_json` TEXT NULL,"
            .. "`updated_at` BIGINT NOT NULL DEFAULT 0,"
            .. "PRIMARY KEY (`server_key`, `att_id`)"
            .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",

        "CREATE TABLE IF NOT EXISTS `" .. TBL_ATT_OVER .. "` ("
            .. "`server_key` VARCHAR(64) NOT NULL,"
            .. "`att_id` VARCHAR(128) NOT NULL,"
            .. "`values_json` TEXT NULL,"
            .. "`note` VARCHAR(255) NOT NULL DEFAULT '',"
            .. "`updated_at` BIGINT NOT NULL DEFAULT 0,"
            .. "PRIMARY KEY (`server_key`, `att_id`)"
            .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",

        -- Gesperrte Aufsaetze. "*" sperrt ueberall, ein Klassenname nur dort.
        "CREATE TABLE IF NOT EXISTS `" .. TBL_BLOCKS .. "` ("
            .. "`server_key` VARCHAR(64) NOT NULL,"
            .. "`class` VARCHAR(128) NOT NULL,"
            .. "`atts_json` TEXT NULL,"
            .. "`updated_at` BIGINT NOT NULL DEFAULT 0,"
            .. "PRIMARY KEY (`server_key`, `class`)"
            .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",

        -- Der Schluessel "*" gilt fuer alle Waffen, ein Klassenname nur fuer die.
        "CREATE TABLE IF NOT EXISTS `" .. TBL_ZONES .. "` ("
            .. "`server_key` VARCHAR(64) NOT NULL,"
            .. "`class` VARCHAR(128) NOT NULL,"
            .. "`values_json` TEXT NULL,"
            .. "`updated_at` BIGINT NOT NULL DEFAULT 0,"
            .. "PRIMARY KEY (`server_key`, `class`)"
            .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
    }

    local index = 0

    local function step()
        index = index + 1

        if not queries[index] then
            -- Erst wenn alle Tabellen da sind, laesst sich pruefen, ob ihnen
            -- Spalten aus einer aelteren Fassung fehlen.
            ensureColumns(callback)
            return
        end

        PD.SQL.Query(queries[index], step)
    end

    step()
end

--------------------------------------------------------------------------------
-- Ausgangswerte festhalten
--------------------------------------------------------------------------------

--[[
    Die Aufsatzplaetze einer Waffe.

    SWEP.Attachments ist eine Liste von Plaetzen, jeder mit einer Liste von
    Kategorien (Slot). Ein Aufsatz passt auf einen Platz, wenn seine eigene
    Kategorie in dieser Liste steht. Damit weiss das Panel, welche Aufsaetze zu
    welcher Waffe gehoeren, ohne dass man es von Hand pflegen muesste.
]]
local function slotsOf(swep)
    local slots = {}

    for _, entry in ipairs(istable(swep.Attachments) and swep.Attachments or {}) do
        local slot = entry.Slot

        if isstring(slot) then
            table.insert(slots, slot)
        elseif istable(slot) then
            for _, name in ipairs(slot) do
                if isstring(name) then table.insert(slots, name) end
            end
        end
    end

    return slots
end

--[[
    Einmal ueber alle angemeldeten Waffen gehen und von den ArcCW-Waffen die
    Werte festhalten, bevor irgendetwas daran geaendert wurde.

    Gelesen wird ueber weapons.Get: das liefert die Tabelle einschliesslich der
    von der Basis geerbten Felder. weapons.GetStored gaebe nur das her, was in
    der Waffendatei selbst steht - Werte aus arccw_base fehlten dann.

    Gefuellt wird nur beim ersten Mal: bei einem spaeteren Nachladen sind die
    Werte bereits angepasst, ein zweiter Durchgang wuerde also die Anpassung zum
    neuen Ausgangswert machen.
]]
function PD.ACW.Snapshot()
    if table.Count(PD.ACW.Defaults) > 0 then
        return table.Count(PD.ACW.Defaults)
    end

    for _, entry in ipairs(weapons.GetList()) do
        local class = entry.ClassName
        if not class then continue end

        local merged = weapons.Get(class)
        if not PD.ACW.IsArcCW(class, merged) then continue end

        local present = {}

        local values = {
            name = merged.PrintName or class,
            category = merged.Category or "",
            slots = slotsOf(merged),
            present = present
        }

        for _, field in ipairs(PD.ACW.Fields) do
            local raw = PD.ACW.GetField(merged, field.swep)

            -- Nur was die Waffe wirklich mitbringt, darf spaeter zurueck-
            -- geschrieben werden. Sonst legt das Modul Felder an, die es im
            -- Addon nie gab.
            if raw ~= nil then
                present[field.key] = true
            end

            local converted = PD.ACW.Convert(field, raw) or 0

            values[field.key] = field.whole and math.Round(converted) or converted
        end

        PD.ACW.Defaults[class] = values
    end

    return table.Count(PD.ACW.Defaults)
end

-- Dasselbe fuer die Aufsaetze.
function PD.ACW.SnapshotAttachments()
    if table.Count(PD.ACW.AttDefaults) > 0 then
        return table.Count(PD.ACW.AttDefaults)
    end

    local registry = PD.ACW.AttachmentRegistry()
    if not registry then return 0 end

    for id, att in pairs(registry) do
        if not istable(att) then continue end

        local slot = att.Slot

        if istable(slot) then
            slot = table.concat(slot, ", ")
        end

        local present = {}

        local values = {
            name = att.PrintName or id,
            slot = isstring(slot) and slot or "",
            present = present
        }

        for _, field in ipairs(PD.ACW.AttFields) do
            local raw = tonumber(att[field.att])

            -- Ein fehlender Faktor heisst "keine Wirkung", im Panel also 1.
            -- Zurueckgeschrieben wird er trotzdem nicht, solange ihn niemand
            -- einstellt: ein OverrideClipSize von 0 naehme der Waffe sonst das
            -- Magazin, obwohl der Aufsatz damit gar nichts zu tun hat.
            if raw == nil then
                values[field.key] = field.whole and 0 or 1
            else
                present[field.key] = true
                values[field.key] = raw
            end
        end

        PD.ACW.AttDefaults[id] = values
    end

    return table.Count(PD.ACW.AttDefaults)
end

--------------------------------------------------------------------------------
-- Ausgangswerte in die Datenbank
--------------------------------------------------------------------------------

function PD.ACW.WriteStats(callback)
    local key = serverKey()
    local now = os.time()

    local addQuery = PD.SQL.Begin()

    if not addQuery then
        if isfunction(callback) then callback(false, "Keine Datenbankverbindung") end
        return
    end

    -- Vorher leeren: deinstallierte Waffenpakete sollen verschwinden.
    addQuery("DELETE FROM `" .. TBL_STATS .. "` WHERE `server_key` = " .. esc(key))
    addQuery("DELETE FROM `" .. TBL_ATTS .. "` WHERE `server_key` = " .. esc(key))

    local weaponCount, attCount = 0, 0

    for class, values in pairs(PD.ACW.Defaults) do
        weaponCount = weaponCount + 1

        local stats = {}
        for _, field in ipairs(PD.ACW.Fields) do
            stats[field.key] = values[field.key]
        end

        addQuery("INSERT INTO `" .. TBL_STATS .. "` "
            .. "(`server_key`, `class`, `name`, `category`, `slots_json`, `stats_json`, `updated_at`) VALUES ("
            .. esc(key) .. ", " .. esc(class) .. ", " .. esc(values.name) .. ", "
            .. esc(values.category) .. ", " .. esc(util.TableToJSON(values.slots or {})) .. ", "
            .. esc(util.TableToJSON(stats)) .. ", " .. now .. ")")
    end

    for id, values in pairs(PD.ACW.AttDefaults) do
        attCount = attCount + 1

        local stats = {}
        for _, field in ipairs(PD.ACW.AttFields) do
            stats[field.key] = values[field.key]
        end

        addQuery("INSERT INTO `" .. TBL_ATTS .. "` "
            .. "(`server_key`, `att_id`, `name`, `slot`, `stats_json`, `updated_at`) VALUES ("
            .. esc(key) .. ", " .. esc(id) .. ", " .. esc(values.name) .. ", "
            .. esc(values.slot) .. ", " .. esc(util.TableToJSON(stats)) .. ", " .. now .. ")")
    end

    PD.SQL.Commit(function()
        if isfunction(callback) then
            callback(true, weaponCount .. " Waffen, " .. attCount .. " Aufsaetze")
        end
    end, function(err)
        ErrorNoHalt("[ArcCW] Ausgangswerte schreiben fehlgeschlagen: " .. tostring(err) .. "\n")

        if isfunction(callback) then callback(false, tostring(err)) end
    end)
end

--------------------------------------------------------------------------------
-- Abweichungen laden und anwenden
--------------------------------------------------------------------------------

local function decode(row)
    local raw = row and row.values_json

    if not isstring(raw) or raw == "" then return {} end

    local decoded = util.JSONToTable(raw)

    return istable(decoded) and decoded or {}
end

local function pick(source, fields)
    local values = {}
    local any = false

    for _, field in ipairs(fields) do
        local number = tonumber(source[field.key])

        -- Nicht gesetzt ist etwas anderes als auf null gesetzt: nur was
        -- tatsaechlich eine Zahl ist, gilt als Abweichung.
        if number then
            values[field.key] = number
            any = true
        end
    end

    return values, any
end

function PD.ACW.LoadOverrides(callback)
    local key = esc(serverKey())

    PD.SQL.FetchAll("SELECT * FROM `" .. TBL_OVERRIDES .. "` WHERE `server_key` = " .. key,
    function(weaponRows)
        PD.ACW.Overrides = {}

        for _, row in ipairs(weaponRows or {}) do
            local values, any = pick(decode(row), PD.ACW.Fields)

            if any and row.class and row.class ~= "" then
                PD.ACW.Overrides[row.class] = values
            end
        end

        PD.SQL.FetchAll("SELECT * FROM `" .. TBL_ATT_OVER .. "` WHERE `server_key` = " .. key,
        function(attRows)
            PD.ACW.AttOverrides = {}

            for _, row in ipairs(attRows or {}) do
                local values, any = pick(decode(row), PD.ACW.AttFields)

                if any and row.att_id and row.att_id ~= "" then
                    PD.ACW.AttOverrides[row.att_id] = values
                end
            end

            PD.SQL.FetchAll("SELECT * FROM `" .. TBL_ZONES .. "` WHERE `server_key` = " .. key,
            function(zoneRows)
                PD.ACW.ZoneMults = {}

                for _, row in ipairs(zoneRows or {}) do
                    local values, any = pick(decode(row), PD.ACW.Zones)

                    if any and row.class and row.class ~= "" then
                        PD.ACW.ZoneMults[row.class] = values
                    end
                end

                PD.SQL.FetchAll("SELECT * FROM `" .. TBL_BLOCKS .. "` WHERE `server_key` = " .. key,
                function(blockRows)
                    PD.ACW.Blocked = {}

                    for _, row in ipairs(blockRows or {}) do
                        local list = util.JSONToTable(row.atts_json or "") or {}
                        local set = {}

                        for _, id in ipairs(istable(list) and list or {}) do
                            if isstring(id) and id ~= "" then set[id] = true end
                        end

                        if table.Count(set) > 0 and row.class and row.class ~= "" then
                            PD.ACW.Blocked[row.class] = set
                        end
                    end

                    PD.ACW.ApplyBlocks()
                    PD.ACW.StripBlockedAll()

                    local classes = PD.ACW.RefreshAll()
                    local atts = PD.ACW.RefreshAttachments()
                    PD.ACW.SyncAll()

                    if isfunction(callback) then
                        callback(true, {
                            weapons = table.Count(PD.ACW.Overrides),
                            attachments = table.Count(PD.ACW.AttOverrides),
                            zones = table.Count(PD.ACW.ZoneMults),
                            blocks = table.Count(PD.ACW.Blocked),
                            classes = classes,
                            attsApplied = atts
                        })
                    end
                end)
            end)
        end)
    end)
end

--------------------------------------------------------------------------------
-- Trefferzonen
--------------------------------------------------------------------------------

--[[
    Die Schadensfaktoren je Trefferzone.

    Bewusst ueber ScalePlayerDamage statt ueber eine Tabelle in ArcCW: die
    Trefferzone steht nur in diesem Hook zur Verfuegung, und der Weg gilt fuer
    jede Waffe gleich - auch fuer die, die gar nicht von ArcCW kommen, falls
    spaeter mal welche dazukommen.

    Der Faktor wirkt zusaetzlich zu dem, was ArcCW und das Grundgamemode ohnehin
    schon rechnen. 1 heisst also unveraendert, nicht "kein Kopfschussbonus".
]]
hook.Add("ScalePlayerDamage", "PD.ACW.Zones", function(ply, hitgroup, dmg)
    if table.Count(PD.ACW.ZoneMults) == 0 then return end

    local inflictor = dmg:GetInflictor()
    local class = IsValid(inflictor) and inflictor:GetClass() or ""

    -- Bei Spielern ist der Inflictor der Spieler selbst, nicht die Waffe.
    if IsValid(inflictor) and inflictor:IsPlayer() then
        local active = inflictor:GetActiveWeapon()
        class = IsValid(active) and active:GetClass() or class
    end

    local mult = PD.ACW.ZoneMult(class, hitgroup)

    if mult ~= 1 then
        dmg:ScaleDamage(mult)
    end
end)

--------------------------------------------------------------------------------
-- Gesperrte Aufsaetze durchsetzen
--------------------------------------------------------------------------------

--[[
    Die Sperre selbst - Blacklisted, RejectAttachments und die umschlossenen
    ArcCW-Funktionen - steht jetzt in sh_arccw.lua (PD.ACW.ApplyBlocks), damit
    Server und Client dasselbe entscheiden. Hier bleibt, was nur der Server
    kann: Aufsaetze abnehmen, die schon an einer Waffe stecken.
]]

local detachWarned = false

function PD.ACW.StripBlocked(wep)
    if not IsValid(wep) or not istable(wep.Attachments) then return 0 end

    local class = wep:GetClass()
    local removed = 0

    for slot, entry in pairs(wep.Attachments) do
        local installed = istable(entry) and entry.Installed

        if isstring(installed) and PD.ACW.IsBlocked(class, installed) then
            -- Ueber ArcCW selbst, damit es den neuen Zustand an die Clients meldet.
            if isfunction(wep.Detach) then
                pcall(wep.Detach, wep, slot, true)
            end

            -- Hat Detach nicht gegriffen oder gibt es nicht: direkt entfernen.
            if entry.Installed == installed then
                if not detachWarned then
                    detachWarned = true
                    PD.RemoteLog("[ArcCW] SWEP:Detach hat nicht gegriffen - verbaute Aufsaetze werden direkt entfernt.")
                end

                entry.Installed = nil
            end

            removed = removed + 1
        end
    end

    if removed > 0 then
        if isfunction(wep.AdjustAtts) then pcall(wep.AdjustAtts, wep) end
        if isfunction(wep.NetworkWeapon) then pcall(wep.NetworkWeapon, wep) end
    end

    return removed
end

function PD.ACW.StripBlockedAll()
    local total = 0

    for _, ply in ipairs(player.GetAll()) do
        for _, wep in ipairs(ply:GetWeapons()) do
            if wep.ArcCW then
                total = total + PD.ACW.StripBlocked(wep)
            end
        end
    end

    return total
end

-- Kurz warten: ArcCW baut Standardaufsaetze und Voreinstellungen beim
-- Ausruesten selbst ein, und das soll vorher fertig sein.
hook.Add("WeaponEquip", "PD.ACW.StripBlocked", function(wep)
    timer.Simple(0.5, function()
        if IsValid(wep) and wep.ArcCW then
            PD.ACW.StripBlocked(wep)
        end
    end)
end)

--------------------------------------------------------------------------------
-- An die Clients verteilen
--------------------------------------------------------------------------------

--[[
    Die Werte muessen auch beim Client ankommen.

    Den Schaden rechnet zwar der Server aus, aber ArcCW zeigt die Werte im
    Waffenmenue an - und die kaemen sonst aus der unveraenderten Addon-Datei.
    Verschickt werden nur die geaenderten Eintraege, das sind wenige.
]]
local SYNC_CHUNK = 60000
local syncSerial = 0

function PD.ACW.Sync(ply)
    local weaponPayload = {}

    for class in pairs(PD.ACW.Overrides) do
        local values = PD.ACW.Effective(class)

        if values then weaponPayload[class] = values end
    end

    local attPayload = {}

    for id in pairs(PD.ACW.AttOverrides) do
        local values = PD.ACW.EffectiveAtt(id)

        if values then attPayload[id] = values end
    end

    --[[
        Frueher drei WriteTable in einer Nachricht. Mit wachsender Sperrliste
        aus dem Panel wurde das groesser als die 64 KB einer Netznachricht
        ("Trying to send an overflowed net message") und kam gar nicht mehr an.
        Jetzt als JSON, komprimiert und notfalls in Teilen; der Client setzt sie
        ueber die Seriennummer wieder zusammen.
    ]]
    local json = util.TableToJSON({
        weapons = weaponPayload,
        atts = attPayload,
        -- Die Sperrliste: das Aufsatzmenue laeuft beim Client und muss sie kennen.
        blocked = PD.ACW.Blocked,
    }) or "{}"

    local data = util.Compress(json) or ""
    local total = math.max(1, math.ceil(#data / SYNC_CHUNK))

    syncSerial = (syncSerial % 65535) + 1
    local serial = syncSerial

    local target = IsValid(ply) and ply or nil

    if not target then
        print(string.format("[PD.ACW] Werte an alle: %.1f KB (%.1f KB unkomprimiert), %d Teil(e)",
            #data / 1024, #json / 1024, total))
    end

    for index = 1, total do
        -- Teile ueber mehrere Ticks verteilen, damit der zuverlaessige
        -- Netzpuffer der Clients nicht auf einmal volllaeuft.
        timer.Simple((index - 1) * 0.1, function()
            if target ~= nil and not IsValid(target) then return end

            local part = string.sub(data, (index - 1) * SYNC_CHUNK + 1, index * SYNC_CHUNK)

            net.Start("PD.ACW:SyncZ")
                net.WriteUInt(serial, 16)
                net.WriteUInt(index, 8)
                net.WriteUInt(total, 8)
                net.WriteUInt(#part, 16)
                net.WriteData(part, #part)

            if target then
                net.Send(target)
            else
                net.Broadcast()
            end
        end)
    end
end

function PD.ACW.SyncAll()
    PD.ACW.Sync(nil)
end

hook.Add("PlayerInitialSpawn", "PD.ACW.Sync", function(ply)
    -- Kurz warten: direkt beim ersten Spawn ist der Client noch nicht bereit,
    -- Netznachrichten anzunehmen.
    timer.Simple(5, function()
        if IsValid(ply) then
            PD.ACW.Sync(ply)
        end
    end)
end)

--------------------------------------------------------------------------------
-- Start und Nachladen
--------------------------------------------------------------------------------

function PD.ACW.Reload(callback)
    PD.ACW.LoadOverrides(callback)
end

timer.Simple(SNAPSHOT_DELAY, function()
    local weaponCount = PD.ACW.Snapshot()
    local attCount = PD.ACW.SnapshotAttachments()

    if weaponCount == 0 then
        PD.RemoteLog("[ArcCW] Keine ArcCW-Waffen gefunden - Modul bleibt untaetig.")
        return
    end

    local _, registryName = PD.ACW.AttachmentRegistry()
    PD.RemoteLog("[ArcCW] " .. weaponCount .. " Waffen, " .. attCount
        .. " Aufsaetze (" .. tostring(registryName) .. ")")
    PD.RemoteLog("[ArcCW] Sperrpruefung eingehaengt: " .. tostring(PD.ACW.WrapChecks()) .. " Funktionen")

    PD.ACW.EnsureTables(function()
        PD.ACW.WriteStats(function(ok, info)
            if ok then PD.RemoteLog("[ArcCW] Erfasst: " .. info) end

            PD.ACW.LoadOverrides(function(_, stats)
                PD.RemoteLog("[ArcCW] Angepasst: " .. stats.weapons .. " Waffen, "
                    .. stats.attachments .. " Aufsaetze, "
                    .. stats.zones .. " Trefferzonen-Eintraege")
            end)
        end)
    end)
end)

--------------------------------------------------------------------------------
-- Konsolenbefehle
--------------------------------------------------------------------------------

concommand.Add("pd_arccw_write", function(ply)
    -- Nur Serverkonsole und RCON, wie die uebrigen Fernsteuerungsbefehle.
    if IsValid(ply) then return end

    PD.ACW.Snapshot()
    PD.ACW.SnapshotAttachments()

    PD.ACW.EnsureTables(function()
        PD.ACW.WriteStats(function(ok, info)
            PD.RemoteLog("[ArcCW] " .. (ok and ("erfasst: " .. info) or ("fehlgeschlagen: " .. tostring(info))))
        end)
    end)
end)

concommand.Add("pd_arccw_status", function(ply, cmd, args)
    if IsValid(ply) then return end

    local class = args[1]

    if class and class ~= "" then
        local defaults = PD.ACW.Defaults[class]

        if not defaults then
            print("[ArcCW] " .. class .. " ist keine erfasste ArcCW-Waffe.")
            return
        end

        local values = PD.ACW.Effective(class)
        local stored = weapons.GetStored(class)

        print("[ArcCW] " .. class .. " (" .. defaults.name .. ")")

        for _, field in ipairs(PD.ACW.Fields) do
            local inWeapon = istable(stored) and stored[field.swep] or nil

            print(string.format("  %-24s Ausgang %-10s Soll %-10s Waffe %s",
                field.label,
                tostring(defaults[field.key]),
                tostring(values[field.key]),
                tostring(PD.ACW.Convert(field, inWeapon) or "?")))
        end

        print("  Aufsatzplaetze: " .. table.concat(defaults.slots or {}, ", "))

        return
    end

    local _, registryName = PD.ACW.AttachmentRegistry()

    print("[ArcCW] " .. table.Count(PD.ACW.Defaults) .. " Waffen erfasst, "
        .. table.Count(PD.ACW.Overrides) .. " angepasst")
    print("[ArcCW] " .. table.Count(PD.ACW.AttDefaults) .. " Aufsaetze erfasst ("
        .. tostring(registryName) .. "), " .. table.Count(PD.ACW.AttOverrides) .. " angepasst")
    print("[ArcCW] " .. table.Count(PD.ACW.ZoneMults) .. " Trefferzonen-Eintraege")

    -- Was im Speicher steht, muss nicht in der Datenbank stehen: schlaegt das
    -- Schreiben fehl, sieht das Panel nichts, waehrend hier alles gefuellt ist.
    PD.SQL.FetchOne("SELECT COUNT(*) AS `c` FROM `" .. TBL_STATS .. "` WHERE `server_key` = "
        .. esc(serverKey()) .. " AND `stats_json` IS NOT NULL", function(row)

        print("[ArcCW] In der Datenbank: " .. tostring(row and row.c or "?")
            .. " Waffen mit Werten")
    end)

    for blockClass, set in SortedPairs(PD.ACW.Blocked) do
        print("[ArcCW] gesperrt fuer " .. blockClass .. ": "
            .. table.concat(table.GetKeys(set), ", "))
    end
end)

--[[
    Zeigt, was ArcCW auf diesem Server tatsaechlich bereitstellt.

    Das Grundaddon liegt als Workshop-Paket vor und damit nicht auf der Platte -
    die Namen seiner Tabellen und Funktionen lassen sich also nicht nachlesen,
    nur erfragen. Genau dafuer ist dieser Befehl da.
]]
concommand.Add("pd_arccw_probe", function(ply, cmd, args)
    if IsValid(ply) then return end

    if not istable(ArcCW) then
        print("[ArcCW] Die globale Tabelle ArcCW gibt es nicht - Addon nicht geladen.")
        return
    end

    print("[ArcCW] Inhalt der Tabelle ArcCW:")

    for name, value in SortedPairs(ArcCW) do
        local extra = ""

        if istable(value) then
            extra = " (" .. table.Count(value) .. " Eintraege)"
        end

        print(string.format("  %-30s %s%s", name, type(value), extra))
    end

    local registry, registryName = PD.ACW.AttachmentRegistry()

    if registry then
        print("[ArcCW] Aufsatztabelle: ArcCW." .. registryName)

        local shown = 0

        for id, att in SortedPairs(registry) do
            if shown >= 3 then break end
            shown = shown + 1

            print("  " .. id .. ":")

            for field, value in SortedPairs(att) do
                if not istable(value) and not isfunction(value) then
                    print(string.format("      %-26s %s", field, tostring(value)))
                end
            end
        end
    else
        print("[ArcCW] Keine Aufsatztabelle gefunden: " .. tostring(registryName))
    end

    if istable(ArcCW.AttachmentBlacklistTable) then
        print("[ArcCW] AttachmentBlacklistTable:")

        for key, value in SortedPairs(ArcCW.AttachmentBlacklistTable) do
            print("  " .. tostring(key) .. " = " .. tostring(value))
        end
    end

    local class = args[1]

    if class and class ~= "" then
        local merged = weapons.Get(class)

        -- Die Ablehnliste der Waffe. Ihr Aufbau steht nicht in den
        -- Inhaltspaketen, sondern im Grundaddon.
        if istable(merged) and istable(merged.RejectAttachments) then
            print("[ArcCW] RejectAttachments von " .. class .. ":")

            for key, value in pairs(merged.RejectAttachments) do
                print("  " .. tostring(key) .. " = " .. tostring(value))
            end
        end

        if istable(merged) then
            print("[ArcCW] Felder von " .. class .. ":")

            for field, value in SortedPairs(merged) do
                if not isfunction(value) then
                    local text = istable(value) and ("Tabelle mit " .. table.Count(value) .. " Eintraegen")
                        or tostring(value)

                    print(string.format("  %-30s %s", field, text))
                end
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- Sounds nachverfolgen
--------------------------------------------------------------------------------

--[[
    Warum spielt ein Sound nicht zuverlaessig?

    Dafuer gibt es drei uebliche Gruende, und alle drei sind von aussen nicht
    zu sehen: der Wert ist ein roher Dateipfad statt eines registrierten
    Sound-Skripts und wird deshalb nie precached; das Skript existiert, zeigt
    aber auf eine Datei, die es nicht gibt; oder der Pfad ist schlicht falsch
    geschrieben.

    Aufsaetze aus dem Workshop liegen in einer .gma und lassen sich nicht im
    Dateisystem nachlesen - zur Laufzeit stehen sie aber vollstaendig in
    ArcCWs Registrierung. Also hier nachsehen statt raten.
]]

-- Sound-Skripte duerfen dem Pfad Steuerzeichen voranstellen (Raumklang,
-- Stream, Lautstaerkeklasse). Fuer die Dateipruefung muessen sie weg.
local SOUND_FLAGS = "^[%)%^%*%#%@%<%>%}%$%!%?%(]+"

local function reportSound(indent, label, value)
    if not isstring(value) or value == "" then return end

    print(string.format("%s%-24s %s", indent, label, value))

    local props = sound.GetProperties(value)
    local files

    if istable(props) then
        local s = props.sound

        if isstring(s) then
            files = {s}
        elseif istable(s) then
            files = s
        else
            files = {}
        end

        print(indent .. "    Sound-Skript vorhanden, " .. #files .. " Datei(en)")
    else
        files = {value}

        print(indent .. "    KEIN Sound-Skript - roher Dateipfad, wird nicht precached")
    end

    for _, entry in ipairs(files) do
        local path = "sound/" .. string.gsub(tostring(entry), SOUND_FLAGS, "")

        print(string.format("%s    %-52s %s", indent, path,
            file.Exists(path, "GAME") and "vorhanden" or "FEHLT"))
    end
end

local function reportEntity(indent, label, class)
    if not isstring(class) or class == "" then return end

    local stored = scripted_ents.Get(class)

    print(string.format("%s%-24s %s   (%s)", indent, label, class,
        stored and "registriert" or "NICHT REGISTRIERT"))
end

--[[
    Alles ausgeben, was an einer Tabelle nach Sound aussieht, plus das
    Projektil. SoundTable-Eintraege werden mitgenommen: dort stecken bei ArcCW
    die Nachladegeraeusche und gelegentlich auch der Abschuss.
]]
local function reportTable(indent, tbl)
    for field, value in SortedPairs(tbl) do
        if isstring(value) and string.find(string.lower(field), "sound", 1, true) then
            reportSound(indent, field, value)
        elseif field == "ShootEntity" then
            reportEntity(indent, field, value)
        end
    end

    if istable(tbl.SoundTable) then
        for index, entry in ipairs(tbl.SoundTable) do
            if istable(entry) then
                reportSound(indent .. "  ", "SoundTable[" .. index .. "]",
                    entry.s or entry.sound or entry.Sound)
            end
        end
    end
end

local function matches(needle, ...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)

        if isstring(value) and string.find(string.lower(value), needle, 1, true) then
            return true
        end

        if istable(value) then
            for _, inner in pairs(value) do
                if isstring(inner) and string.find(string.lower(inner), needle, 1, true) then
                    return true
                end
            end
        end
    end

    return false
end

concommand.Add("pd_arccw_sound", function(ply, cmd, args)
    if IsValid(ply) then return end

    local needle = string.lower(args[1] or "")

    if needle == "" then
        print("[ArcCW] Aufruf: pd_arccw_sound <suchbegriff>")
        print("[ArcCW] Sucht in Aufsaetzen und Waffen nach Kennung, Slot oder Anzeigename.")
        return
    end

    print("[ArcCW] Suche nach \"" .. needle .. "\"")

    local registry = PD.ACW.AttachmentRegistry()
    local found = 0

    if istable(registry) then
        for id, att in SortedPairs(registry) do
            if istable(att) and matches(needle, id, att.Slot, att.PrintName, att.ShortName) then
                found = found + 1

                print("")
                print("[ArcCW] Aufsatz " .. id
                    .. "   (" .. tostring(att.PrintName or "ohne Namen") .. ")")

                local slot = att.Slot

                print("    Slot                     "
                    .. (istable(slot) and table.concat(slot, ", ") or tostring(slot)))

                reportTable("    ", att)
            end
        end
    end

    for _, entry in ipairs(weapons.GetList()) do
        local class = entry.ClassName or entry.Classname

        if isstring(class) and matches(needle, class, entry.PrintName) then
            found = found + 1

            print("")
            print("[ArcCW] Waffe " .. class
                .. "   (" .. tostring(entry.PrintName or "ohne Namen") .. ")")

            reportTable("    ", entry)
        end
    end

    if found == 0 then
        print("[ArcCW] Nichts gefunden. Ohne Treffer hilft pd_arccw_probe weiter.")
    else
        print("")
        print("[ArcCW] " .. found .. " Treffer.")
    end
end)
