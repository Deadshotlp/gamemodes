--[[
    Spawnpunkte je Einheit und Untereinheit.

    Ein Punkt gehoert zu einer Untereinheit, oder - mit leerem sub_unit - zur
    ganzen Einheit. Beim Spawn gewinnt der genauere Treffer.

    Spawns wird ausschliesslich als Liste gefuehrt. Frueher hat die Netzwerk-
    Annahme mit Spawns[unit] = v Zeichenketten-Schluessel in dieselbe Tabelle
    geschrieben, in der das Laden Zahlen-Schluessel angelegt hatte. SortedPairs
    sortiert die Schluessel, und table.sort bricht bei gemischten Typen mit
    "attempt to compare number with string" ab - der Spawn-Hook starb dann still,
    obwohl die Punkte in der Datenbank standen und im HUD angezeigt wurden.
]]

util.AddNetworkString("PDSyncPlayerSpawns")
util.AddNetworkString("PDPlayerSpawnSet")
util.AddNetworkString("PDDeletePlayerSpawns")

local TABLE_NAME = "pd_player_spawns"

local Spawns = {}

local function GetMapName()
    return game.GetMap() or ""
end

PD.SQL.Query([[
    CREATE TABLE IF NOT EXISTS `]] .. TABLE_NAME .. [[` (
        `map` VARCHAR(64) NOT NULL,
        `unit` VARCHAR(64) NOT NULL,
        `sub_unit` VARCHAR(64) NOT NULL,
        `pos_x` DOUBLE NOT NULL,
        `pos_y` DOUBLE NOT NULL,
        `pos_z` DOUBLE NOT NULL,
        `ang_p` DOUBLE NOT NULL,
        `ang_y` DOUBLE NOT NULL,
        `ang_r` DOUBLE NOT NULL,
        PRIMARY KEY (`map`, `unit`, `sub_unit`)
    )
]])

local function LoadSpawns(callback)
    local mapName = GetMapName()

    PD.SQL.FetchAll("SELECT * FROM `" .. TABLE_NAME .. "` WHERE `map` = " .. PD.SQL.EscapeString(mapName), function(rows)
        local result = {}

        for _, row in ipairs(rows or {}) do
            table.insert(result, {
                unit = tostring(row.unit or ""),
                sub_unit = tostring(row.sub_unit or ""),
                pos = Vector(tonumber(row.pos_x) or 0, tonumber(row.pos_y) or 0, tonumber(row.pos_z) or 0),
                ang = Angle(tonumber(row.ang_p) or 0, tonumber(row.ang_y) or 0, tonumber(row.ang_r) or 0)
            })
        end

        if callback then callback(result) end
    end)
end

local function UpsertSpawn(unit, sub_unit, data)
    local pos = data.pos
    local ang = data.ang
    local mapName = GetMapName()

    local query = "INSERT INTO `" .. TABLE_NAME .. "` (`map`, `unit`, `sub_unit`, `pos_x`, `pos_y`, `pos_z`, `ang_p`, `ang_y`, `ang_r`) VALUES ("
        .. PD.SQL.EscapeString(mapName) .. ", "
        .. PD.SQL.EscapeString(unit) .. ", "
        .. PD.SQL.EscapeString(sub_unit) .. ", "
        .. tostring(pos.x) .. ", " .. tostring(pos.y) .. ", " .. tostring(pos.z) .. ", "
        .. tostring(ang.p) .. ", " .. tostring(ang.y) .. ", " .. tostring(ang.r)
        .. ") ON DUPLICATE KEY UPDATE `pos_x` = VALUES(`pos_x`), `pos_y` = VALUES(`pos_y`), `pos_z` = VALUES(`pos_z`), "
        .. "`ang_p` = VALUES(`ang_p`), `ang_y` = VALUES(`ang_y`), `ang_r` = VALUES(`ang_r`)"

    PD.SQL.Execute(query)
end

local function DeleteAllSpawns()
    local mapName = GetMapName()
    PD.SQL.Execute("DELETE FROM `" .. TABLE_NAME .. "` WHERE `map` = " .. PD.SQL.EscapeString(mapName))
end

--[[
    Einen Punkt in die Liste schreiben - vorhandenen Eintrag derselben
    Einheit/Untereinheit ersetzen, sonst anhaengen. Damit bleibt die Liste im
    laufenden Betrieb genauso aufgebaut wie nach dem Laden aus der Datenbank.
]]
local function StoreSpawn(unit, sub_unit, pos, ang)
    unit = tostring(unit or "")
    sub_unit = tostring(sub_unit or "")

    if unit == "" then return nil end
    if not isvector(pos) then return nil end
    if not isangle(ang) then ang = Angle(0, 0, 0) end

    local entry

    for _, v in ipairs(Spawns) do
        if v.unit == unit and v.sub_unit == sub_unit then
            entry = v
            break
        end
    end

    if not entry then
        entry = {unit = unit, sub_unit = sub_unit}
        table.insert(Spawns, entry)
    end

    entry.pos = Vector(pos)
    entry.ang = Angle(ang.p, ang.y, ang.r)

    UpsertSpawn(unit, sub_unit, entry)

    return entry
end

LoadSpawns(function(result)
    Spawns = result
end)

-- Nach aussen sichtbarer Reload (pd_reload spawns). Fuellt dieselbe lokale Tabelle,
-- mit der der Rest der Datei arbeitet.
PD.PlayerSpawns = PD.PlayerSpawns or {}

function PD.PlayerSpawns.Load(callback)
    LoadSpawns(function(result)
        Spawns = result

        if callback then callback(Spawns) end
    end)
end

function PD.PlayerSpawns.Get()
    return Spawns
end

--[[
    Den passenden Punkt zu einem Spieler suchen.

    Genauer Treffer (Einheit + Untereinheit) schlaegt den einheitsweiten Punkt.
    Getrennt vom Hook, damit der Diagnosebefehl unten dieselbe Entscheidung
    trifft wie der Spawn selbst.
]]
function PD.PlayerSpawns.Resolve(ply)
    if not IsValid(ply) then return nil end

    local _, jobTbl = ply:GetJob()
    if not istable(jobTbl) then return nil end

    local subUnitId, subUnitTbl = PD.JOBS.GetSubUnit(jobTbl.unit)
    if not istable(subUnitTbl) then return nil end

    local unitId = PD.JOBS.GetUnit(subUnitTbl.unit)

    unitId = tostring(unitId or "")
    subUnitId = tostring(subUnitId or "")

    local exact, wide

    for _, v in ipairs(Spawns) do
        if v.unit == unitId then
            if v.sub_unit == subUnitId then
                exact = v
                break
            elseif v.sub_unit == "" then
                wide = v
            end
        end
    end

    return exact or wide, unitId, subUnitId
end

net.Receive("PDPlayerSpawnSet", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local tbl = net.ReadTable()
    if not istable(tbl) then return end

    local count = 0

    for key, v in pairs(tbl) do
        if istable(v) then
            -- Die Einheit steht im Eintrag; nur wenn sie fehlt, gilt der
            -- Schluessel als Einheit (alter Client, der nach Einheit ablegte).
            local unit = v.unit or key

            if StoreSpawn(unit, v.sub_unit, v.pos, v.ang) then
                count = count + 1
            end
        end
    end

    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("Admin", ply:Nick() .. " hat " .. count .. " Spawnpunkte gesetzt.", Color(80, 160, 220))
    end
end)

net.Receive("PDDeletePlayerSpawns", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    Spawns = {}

    DeleteAllSpawns()
end)

net.Receive("PDSyncPlayerSpawns", function(len, ply)
    net.Start("PDSyncPlayerSpawns")
    net.WriteTable(Spawns)
    net.Send(ply)
end)

hook.Add("PlayerSpawn", "PlayerSpawnPD", function(ply)
    local spawn = PD.PlayerSpawns.Resolve(ply)
    if not spawn then return end

    local radius = 100
    local attempts = 15
    local basePos = spawn.pos
    local finalPos = basePos

    for i = 1, attempts do
        local offset = Vector(math.Rand(-radius, radius), math.Rand(-radius, radius), 0)
        local testPos = basePos + offset

        local tr = util.TraceHull({
            start = testPos,
            endpos = testPos,
            mins = Vector(-16, -16, 0),
            maxs = Vector(16, 16, 72),
            filter = ply
        })

        if not tr.Hit then
            finalPos = testPos
            break
        end
    end

    ply:SetPos(finalPos)

    -- SetAngles dreht beim Spieler nur das Model, die Blickrichtung kommt vom
    -- Client. Fuer die gespeicherte Ausrichtung braucht es SetEyeAngles.
    ply:SetEyeAngles(Angle(0, spawn.ang.y, 0))
end)

--------------------------------------------------------------------------------
-- Diagnose
--------------------------------------------------------------------------------

concommand.Add("pd_spawns_debug", function(ply, _, args)
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    local function say(text)
        if IsValid(ply) then
            ply:PrintMessage(HUD_PRINTCONSOLE, text)
        else
            print(text)
        end
    end

    say("[Spawns] Karte " .. GetMapName() .. ", " .. #Spawns .. " Punkte geladen:")

    for i, v in ipairs(Spawns) do
        say(string.format("  %2d  Einheit %-22s Untereinheit %-22s %s",
            i, v.unit, v.sub_unit == "" and "(gesamte Einheit)" or v.sub_unit,
            tostring(v.pos)))
    end

    local target = ply

    if args[1] then
        target = player.GetBySteamID(args[1]) or ply
    end

    if not IsValid(target) then
        say("[Spawns] Kein Spieler zum Pruefen. Aufruf: pd_spawns_debug <SteamID>")
        return
    end

    local spawn, unitId, subUnitId = PD.PlayerSpawns.Resolve(target)
    local jobID = target:GetJob()

    say("[Spawns] " .. target:Nick() .. ": Job " .. tostring(jobID)
        .. " -> Einheit " .. tostring(unitId) .. ", Untereinheit " .. tostring(subUnitId))

    if spawn then
        say("[Spawns] Treffer: " .. tostring(spawn.pos)
            .. (spawn.sub_unit == "" and " (einheitsweit)" or " (Untereinheit)"))
    else
        say("[Spawns] Kein Treffer - die Schluessel oben passen zu keinem Punkt.")
    end
end)
