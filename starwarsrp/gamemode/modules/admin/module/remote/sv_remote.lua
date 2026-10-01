PD = PD or {}
PD.Remote = PD.Remote or {}

-- Fernsteuerung für das Web-Panel.
--
-- GMod kann keine eingehenden Verbindungen annehmen, deshalb läuft der Weg von
-- außen über die Serverkonsole: das Panel schickt über die Pterodactyl-API einen
-- Befehl, der hier ankommt. Alle Befehle sind bewusst NUR aus der Konsole bzw.
-- per RCON ausführbar - ein verbundener Spieler kann sie nicht auslösen.

local TBL_STATUS = "pd_server_status"
local TBL_ONLINE = "pd_online_players"

local HEARTBEAT_INTERVAL = 15
local startTime = os.time()

-- Erlaubt mehrere Server auf derselben Datenbank. Über die server.cfg setzbar:
-- pd_server_key "live"
local serverKey = CreateConVar("pd_server_key", "main", FCVAR_ARCHIVE, "Schlüssel dieses Servers im Web-Panel"):GetString()

local function esc(value)
    return PD.SQL.EscapeString(tostring(value or ""))
end

-- Nur Serverkonsole/RCON. Ein gültiger ply bedeutet: der Befehl kam von einem
-- verbundenen Spieler, und dann brechen wir ab.
local function consoleOnly(ply)
    return not IsValid(ply)
end

--------------------------------------------------------------------------------
-- Schema
--------------------------------------------------------------------------------

function PD.Remote.EnsureTables(callback)
    local createStatus = "CREATE TABLE IF NOT EXISTS `" .. TBL_STATUS .. "` ("
        .. "`server_key` VARCHAR(64) NOT NULL,"
        .. "`last_seen` BIGINT NOT NULL DEFAULT 0,"
        .. "`map` VARCHAR(64) NOT NULL DEFAULT '',"
        .. "`gamemode` VARCHAR(64) NOT NULL DEFAULT '',"
        .. "`player_count` INT NOT NULL DEFAULT 0,"
        .. "`max_players` INT NOT NULL DEFAULT 0,"
        .. "`defcon` INT NOT NULL DEFAULT 5,"
        .. "`defcon_text` VARCHAR(255) NOT NULL DEFAULT '',"
        .. "`uptime` BIGINT NOT NULL DEFAULT 0,"
        .. "PRIMARY KEY (`server_key`)"
        .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

    local createOnline = "CREATE TABLE IF NOT EXISTS `" .. TBL_ONLINE .. "` ("
        .. "`server_key` VARCHAR(64) NOT NULL,"
        .. "`steamid64` VARCHAR(32) NOT NULL,"
        .. "`char_id` VARCHAR(64) NOT NULL DEFAULT '',"
        .. "`name` VARCHAR(128) NOT NULL DEFAULT '',"
        .. "`job_key` VARCHAR(128) NOT NULL DEFAULT '',"
        .. "`unit_key` VARCHAR(128) NOT NULL DEFAULT '',"
        .. "`subunit_key` VARCHAR(128) NOT NULL DEFAULT '',"
        .. "`ping` INT NOT NULL DEFAULT 0,"
        .. "`since` BIGINT NOT NULL DEFAULT 0,"
        .. "PRIMARY KEY (`server_key`, `steamid64`)"
        .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

    PD.SQL.Query(createStatus, function()
        PD.SQL.Query(createOnline, function()
            if callback then callback() end
        end)
    end)
end

--------------------------------------------------------------------------------
-- Heartbeat
--------------------------------------------------------------------------------

function PD.Remote.WriteHeartbeat()
    if not PD.SQL.IsConnected() then return end

    local defcon, defconText = 5, ""

    if DEFCON and DEFCON.GetCurrent then
        defcon, defconText = DEFCON.GetCurrent()
    end

    local players = player.GetAll()

    local statusQuery = "REPLACE INTO `" .. TBL_STATUS .. "` "
        .. "(`server_key`, `last_seen`, `map`, `gamemode`, `player_count`, `max_players`, `defcon`, `defcon_text`, `uptime`) VALUES ("
        .. esc(serverKey) .. ", "
        .. os.time() .. ", "
        .. esc(game.GetMap()) .. ", "
        .. esc(engine.ActiveGamemode()) .. ", "
        .. #players .. ", "
        .. game.MaxPlayers() .. ", "
        .. (tonumber(defcon) or 5) .. ", "
        .. esc(defconText) .. ", "
        .. (os.time() - startTime)
        .. ")"

    -- Spielerliste komplett ersetzen: alte Zeilen dieses Servers weg, dann neu.
    -- In einer Transaktion, damit das Panel nie eine leere Liste sieht.
    local addQuery = PD.SQL.Begin()

    if not addQuery then
        PD.SQL.Query(statusQuery)
        return
    end

    addQuery(statusQuery)
    addQuery("DELETE FROM `" .. TBL_ONLINE .. "` WHERE `server_key` = " .. esc(serverKey))

    for _, ply in ipairs(players) do
        if not ply:IsBot() then
            local charID = (PD.FB and PD.FB.GetCharID and PD.FB.GetCharID(ply)) or ""
            local jobID, jobTbl = ply:GetJob()
            local unitKey, subunitKey = "", ""

            if PD.List and PD.List.GetPlayerData then
                local unit, subunit = PD.List:GetPlayerData(ply)
                unitKey = unit or ""
                subunitKey = subunit or ""
            end

            addQuery("INSERT INTO `" .. TBL_ONLINE .. "` "
                .. "(`server_key`, `steamid64`, `char_id`, `name`, `job_key`, `unit_key`, `subunit_key`, `ping`, `since`) VALUES ("
                .. esc(serverKey) .. ", "
                .. esc(ply:SteamID64()) .. ", "
                .. esc(charID) .. ", "
                .. esc(ply:Nick()) .. ", "
                .. esc(jobID or "") .. ", "
                .. esc(unitKey) .. ", "
                .. esc(subunitKey) .. ", "
                .. (ply:Ping() or 0) .. ", "
                .. os.time()
                .. ")")
        end
    end

    PD.SQL.Commit(nil, function(err)
        ErrorNoHalt("[Remote] Heartbeat fehlgeschlagen: " .. tostring(err) .. "\n")
    end)
end

--------------------------------------------------------------------------------
-- Reload-Bereiche
--------------------------------------------------------------------------------

-- Jeder Eintrag bekommt ein done(text), das er nach Abschluss aufruft. So kann
-- der Befehl eine ehrliche Rückmeldung in die Konsole schreiben, die das Panel
-- aus der Konsolenausgabe wieder einsammeln kann.
PD.Remote.Reloaders = {}

PD.Remote.Reloaders["jobs"] = function(done)
    PD.JOBS.LoadJobs(function()
        PD.JOBS.UpdateTabel()

        -- Der Fraktionsbaum wird aus PD.JOBS.Jobs gebaut und hängt sonst an
        -- veralteten Keys.
        if PD.List then
            PD.List:LoadFactions()
            PD.List:SyncAll()
        end

        done(table.Count(PD.JOBS.Jobs) .. " Units geladen")
    end)
end

PD.Remote.Reloaders["fortbildung"] = function(done)
    PD.FB.LoadCourses(function()
        PD.FB.LoadGranted(function()
            PD.FB.SyncAll()
            done(table.Count(PD.FB.Courses) .. " Fortbildungen geladen")
        end)
    end)
end

PD.Remote.Reloaders["waffen"] = function(done)
    if not PD.WB or not PD.WB.LoadConfig then
        done("Waffenkisten-Modul nicht geladen")
        return
    end

    PD.WB.LoadConfig(function(ok)
        if not ok then
            done("Konfiguration konnte nicht geladen werden")
            return
        end

        -- Ohne den Sync rechnet der Client weiter mit alten Gewichten.
        PD.WB.SyncConfig()

        done(#PD.WB.Categories .. " Kategorien, Tragelast " .. PD.WB.MaxWeight .. " Kg")
    end)
end

PD.Remote.Reloaders["fraktionen"] = function(done)
    if not PD.List then
        done("Fraktionsmodul nicht geladen")
        return
    end

    PD.List:LoadFactions()
    PD.List:SyncAll()
    done("Fraktionsbaum neu aufgebaut")
end

PD.Remote.Reloaders["armor"] = function(done)
    if not PD.Armor or not PD.Armor.Load then
        done("Armor-Modul nicht geladen")
        return
    end

    PD.Armor.Load(function(data)
        if PD.Armor.Broadcast then PD.Armor.Broadcast() end

        done(#data .. " Rüstungen geladen")
    end)
end

PD.Remote.Reloaders["arccw"] = function(done)
    if not PD.ACW or not PD.ACW.Reload then
        done("Modul nicht geladen")
        return
    end

    PD.ACW.Reload(function(ok, stats)
        if not ok or not istable(stats) then
            done("fehlgeschlagen")
            return
        end

        done(stats.weapons .. " Waffen, " .. stats.attachments .. " Aufsaetze, "
            .. stats.zones .. " Trefferzonen, " .. (stats.blocks or 0) .. " Sperrlisten")
    end)
end

PD.Remote.Reloaders["spawns"] = function(done)
    if not PD.PlayerSpawns or not PD.PlayerSpawns.Load then
        done("Spawn-Modul nicht geladen")
        return
    end

    PD.PlayerSpawns.Load(function(spawns)
        done(table.Count(spawns) .. " Spawnpunkte geladen")
    end)
end

-- Charaktere aus der Datenbank neu laden - nach Änderungen im Web-Panel.
-- Verbundene Spieler bekommen Name und Zuordnung sofort, der Fraktionsbaum
-- baut sich über PD.Char.StorageLoaded neu auf.
PD.Remote.Reloaders["chars"] = function(done)
    if not PD.Char or not PD.Char.ReloadFromSQL then
        done("Charakter-Modul nicht geladen")
        return
    end

    PD.Char:ReloadFromSQL(function(ok, count)
        if not ok then
            done("Laden fehlgeschlagen")
            return
        end

        if PD.Char.ApplyStoredToOnlinePlayers then
            PD.Char:ApplyStoredToOnlinePlayers()
        end

        done(tostring(count) .. " Spieler mit Charakteren geladen")
    end)
end

function PD.Remote.Reload(area, done)
    done = done or function() end

    if area == "all" then
        local names = {}

        for name in pairs(PD.Remote.Reloaders) do
            table.insert(names, name)
        end

        table.sort(names)

        local index = 0

        local function step()
            index = index + 1

            local name = names[index]

            if not name then
                done("Alle Bereiche neu geladen")
                return
            end

            PD.Remote.Reloaders[name](function(text)
                PD.RemoteLog("[Remote] " .. name .. ": " .. tostring(text))
                step()
            end)
        end

        step()
        return
    end

    local reloader = PD.Remote.Reloaders[area]

    if not reloader then
        local available = {}

        for name in pairs(PD.Remote.Reloaders) do
            table.insert(available, name)
        end

        table.sort(available)
        done("Unbekannter Bereich '" .. tostring(area) .. "'. Möglich: " .. table.concat(available, ", ") .. ", all")
        return
    end

    reloader(done)
end

--------------------------------------------------------------------------------
-- Konsolenbefehle
--------------------------------------------------------------------------------

concommand.Add("pd_reload", function(ply, cmd, args)
    if not consoleOnly(ply) then return end

    local area = string.lower(args[1] or "")

    if area == "" then
        PD.RemoteLog("[Remote] Verwendung: pd_reload <jobs|fortbildung|waffen|arccw|fraktionen|armor|spawns|chars|all>")
        return
    end

    PD.Remote.Reload(area, function(text)
        PD.RemoteLog("[Remote] reload " .. area .. ": " .. tostring(text))
    end)
end)

concommand.Add("pd_status", function(ply)
    if not consoleOnly(ply) then return end

    PD.Remote.WriteHeartbeat()

    PD.RemoteLog("[Remote] status server=" .. serverKey
        .. " map=" .. game.GetMap()
        .. " spieler=" .. #player.GetAll() .. "/" .. game.MaxPlayers()
        .. " sql=" .. tostring(PD.SQL.IsConnected()))
end)

concommand.Add("pd_admin_say", function(ply, cmd, args, argStr)
    if not consoleOnly(ply) then return end

    local text = string.Trim(argStr or "")

    if text == "" then
        PD.RemoteLog("[Remote] Verwendung: pd_admin_say <text>")
        return
    end

    PD.Notify(text, Color(200, 150, 40), true)

    for _, target in ipairs(player.GetAll()) do
        target:ChatPrint("[Serverleitung] " .. text)
    end

    PD.RemoteLog("[Remote] say: " .. text)
end)

concommand.Add("pd_admin_kick", function(ply, cmd, args)
    if not consoleOnly(ply) then return end

    local steamid = args[1]

    if not steamid then
        PD.RemoteLog("[Remote] Verwendung: pd_admin_kick <steamid64> [grund]")
        return
    end

    local reason = table.concat(args, " ", 2)

    if reason == "" then
        reason = "Kein Grund angegeben"
    end

    local target = FindPlayerbyID and FindPlayerbyID(steamid)

    if not IsValid(target) then
        PD.RemoteLog("[Remote] kick: Spieler " .. steamid .. " ist nicht online")
        return
    end

    local name = target:Nick()
    target:Kick(reason)

    PD.RemoteLog("[Remote] kick: " .. name .. " (" .. steamid .. ") - " .. reason)
end)

concommand.Add("pd_defcon", function(ply, cmd, args)
    if not consoleOnly(ply) then return end

    local id = tonumber(args[1])

    if not id then
        PD.RemoteLog("[Remote] Verwendung: pd_defcon <0-5> [text]")
        return
    end

    local text = table.concat(args, " ", 2)

    if not DEFCON or not DEFCON.Set then
        PD.RemoteLog("[Remote] defcon: Modul nicht geladen")
        return
    end

    if DEFCON.Set(id, text, "Serverleitung") then
        PD.RemoteLog("[Remote] defcon: auf " .. id .. " gesetzt")
    else
        PD.RemoteLog("[Remote] defcon: Nummer " .. id .. " gibt es nicht")
    end
end)

concommand.Add("pd_announce", function(ply, cmd, args, argStr)
    if not consoleOnly(ply) then return end

    if not isfunction(PD.Announce) then
        PD.RemoteLog("[Remote] announce: PD.Announce fehlt - _1base/sh_ui.lua wurde nicht geladen")
        return
    end

    local raw = string.Trim(argStr or "")

    if raw == "" then
        PD.RemoteLog("[Remote] Verwendung: pd_announce <Titel> | <Text> [| Sekunden]")
        return
    end

    -- Titel und Text mit | trennen, weil beide Leerzeichen enthalten duerfen.
    local parts = string.Explode("|", raw)
    local title = string.Trim(parts[1] or "")
    local text = string.Trim(parts[2] or "")
    local duration = tonumber(string.Trim(parts[3] or "")) or 10

    -- Ohne | ist das Ganze der Text, der Titel kommt von der Serverleitung.
    if text == "" then
        text = title
        title = "Serverleitung"
    end

    PD.Announce({
        title = title,
        text = text,
        color = Color(200, 150, 40),
        duration = duration
    })

    PD.RemoteLog("[Remote] announce (" .. duration .. "s): " .. title .. " - " .. text)
end)

--------------------------------------------------------------------------------
-- Initialisierung
--------------------------------------------------------------------------------

-- PostPDLoaded ist in init.lua auskommentiert und feuert nie, deshalb wie die
-- übrigen Module über einen Timer nach dem Laden.
timer.Simple(2, function()
    PD.Remote.EnsureTables(function()
        PD.Remote.WriteHeartbeat()

        PD.RemoteLog("[Remote] Fernsteuerung bereit (server_key=" .. serverKey .. ")")
    end)
end)

timer.Create("PD.Remote.Heartbeat", HEARTBEAT_INTERVAL, 0, function()
    PD.Remote.WriteHeartbeat()
end)

-- Beim sauberen Herunterfahren die Spielerliste leeren, damit das Panel nicht
-- eine Geisterbesetzung anzeigt.
hook.Add("ShutDown", "PD.Remote.ClearOnline", function()
    if not PD.SQL.IsConnected() then return end

    PD.SQL.Query("DELETE FROM `" .. TBL_ONLINE .. "` WHERE `server_key` = " .. esc(serverKey))
    PD.SQL.Query("UPDATE `" .. TBL_STATUS .. "` SET `player_count` = 0 WHERE `server_key` = " .. esc(serverKey))
end)
