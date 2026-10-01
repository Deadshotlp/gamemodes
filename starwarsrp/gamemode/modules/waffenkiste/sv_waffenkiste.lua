PD.WB = PD.WB or {}

util.AddNetworkString("PD.WB:GiveWeapon")
util.AddNetworkString("PD.WB:RemoveWeapon")
util.AddNetworkString("PD.WB:Refresh")
util.AddNetworkString("PD.WB:Config")

--------------------------------------------------------------------------------
-- Konfiguration in der Datenbank
--------------------------------------------------------------------------------

local function esc(value)
    return PD.SQL.EscapeString(tostring(value or ""))
end

function PD.WB.EnsureTables(callback)
    local queries = {
        "CREATE TABLE IF NOT EXISTS `pd_wb_config` ("
            .. "`config_key` VARCHAR(64) NOT NULL,"
            .. "`config_value` VARCHAR(191) NOT NULL DEFAULT '',"
            .. "PRIMARY KEY (`config_key`)"
            .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",

        "CREATE TABLE IF NOT EXISTS `pd_wb_categories` ("
            .. "`name` VARCHAR(64) NOT NULL,"
            .. "`position` INT NOT NULL DEFAULT 0,"
            .. "`max_items` INT NOT NULL DEFAULT 0,"
            .. "PRIMARY KEY (`name`)"
            .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",

        "CREATE TABLE IF NOT EXISTS `pd_wb_weapons` ("
            .. "`class` VARCHAR(128) NOT NULL,"
            .. "`category` VARCHAR(64) NOT NULL DEFAULT '',"
            .. "`weight` DOUBLE NOT NULL DEFAULT 2,"
            .. "PRIMARY KEY (`class`)"
            .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",

        "CREATE TABLE IF NOT EXISTS `pd_wb_always` ("
            .. "`class` VARCHAR(128) NOT NULL,"
            .. "PRIMARY KEY (`class`)"
            .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"
    }

    local index = 0

    local function step()
        index = index + 1

        if not queries[index] then
            if callback then callback() end
            return
        end

        PD.SQL.Query(queries[index], step)
    end

    step()
end

-- Beim allerersten Start ist die Datenbank leer. Dann wandern die Startwerte
-- aus sh_waffenkiste.lua einmalig hinein, damit nichts verloren geht.
function PD.WB.SeedFromDefaults(callback)
    local addQuery = PD.SQL.Begin()

    if not addQuery then
        if callback then callback(false) end
        return
    end

    local defaults = PD.WB.Defaults

    addQuery("REPLACE INTO `pd_wb_config` (`config_key`, `config_value`) VALUES "
        .. "('max_weight', " .. esc(defaults.MaxWeight) .. "), "
        .. "('default_weight', " .. esc(defaults.DefaultWeight) .. "), "
        .. "('default_category', " .. esc(defaults.DefaultCategory) .. ")")

    for position, category in ipairs(defaults.Categories) do
        addQuery("REPLACE INTO `pd_wb_categories` (`name`, `position`, `max_items`) VALUES ("
            .. esc(category.name) .. ", " .. position .. ", " .. (tonumber(category.max) or 0) .. ")")
    end

    for categoryName, weapons in pairs(defaults.Weapons) do
        for class, weight in pairs(weapons) do
            addQuery("REPLACE INTO `pd_wb_weapons` (`class`, `category`, `weight`) VALUES ("
                .. esc(class) .. ", " .. esc(categoryName) .. ", " .. (tonumber(weight) or 2) .. ")")
        end
    end

    for _, class in ipairs(defaults.Always) do
        addQuery("REPLACE INTO `pd_wb_always` (`class`) VALUES (" .. esc(class) .. ")")
    end

    PD.SQL.Commit(function()
        if callback then callback(true) end
    end, function(err)
        ErrorNoHalt("[Waffenkiste] Startwerte schreiben fehlgeschlagen: " .. tostring(err) .. "\n")
        if callback then callback(false) end
    end)
end

function PD.WB.LoadConfig(callback)
    PD.SQL.FetchAll("SELECT * FROM `pd_wb_categories` ORDER BY `position`", function(categoryRows)
        if not categoryRows or #categoryRows == 0 then
            -- Noch nichts in der Datenbank: einmalig befüllen und dann erneut laden.
            PD.WB.SeedFromDefaults(function(ok)
                if ok then
                    PD.WB.LoadConfig(callback)
                elseif callback then
                    callback(false)
                end
            end)

            return
        end

        PD.SQL.FetchAll("SELECT * FROM `pd_wb_weapons`", function(weaponRows)
            PD.SQL.FetchAll("SELECT * FROM `pd_wb_always`", function(alwaysRows)
                PD.SQL.FetchAll("SELECT * FROM `pd_wb_config`", function(configRows)
                    local config = {
                        categories = {},
                        weapons = {},
                        always = {}
                    }

                    for _, row in ipairs(categoryRows) do
                        table.insert(config.categories, {
                            name = row.name,
                            max = tonumber(row.max_items) or 0
                        })

                        config.weapons[row.name] = {}
                    end

                    for _, row in ipairs(weaponRows or {}) do
                        local category = row.category or ""

                        config.weapons[category] = config.weapons[category] or {}
                        config.weapons[category][row.class] = tonumber(row.weight) or 2
                    end

                    for _, row in ipairs(alwaysRows or {}) do
                        table.insert(config.always, row.class)
                    end

                    for _, row in ipairs(configRows or {}) do
                        if row.config_key == "max_weight" then
                            config.max_weight = tonumber(row.config_value)
                        elseif row.config_key == "default_weight" then
                            config.default_weight = tonumber(row.config_value)
                        elseif row.config_key == "default_category" then
                            config.default_category = row.config_value
                        end
                    end

                    PD.WB.ApplyConfig(config)
                    PD.WB.LoadedConfig = config

                    if callback then callback(true) end
                end)
            end)
        end)
    end)
end

-- Client und Server müssen dieselbe Konfiguration haben, sonst weicht die
-- Anzeige von der Serverprüfung ab.
function PD.WB.SyncConfig(ply)
    if not PD.WB.LoadedConfig then return end

    net.Start("PD.WB:Config")
        net.WriteTable(PD.WB.LoadedConfig)

    if IsValid(ply) then
        net.Send(ply)
    else
        net.Broadcast()
    end
end

timer.Simple(2, function()
    PD.WB.EnsureTables(function()
        PD.WB.LoadConfig(function(ok)
            if not ok then
                ErrorNoHalt("[Waffenkiste] Konfiguration konnte nicht geladen werden\n")
                return
            end

            PD.WB.SyncConfig()

            PD.RemoteLog("[Waffenkiste] Konfiguration geladen: "
                .. #PD.WB.Categories .. " Kategorien, Tragelast " .. PD.WB.MaxWeight .. " Kg")
        end)
    end)
end)

hook.Add("PlayerInitialSpawn", "PD.WB:SyncConfigOnJoin", function(ply)
    timer.Simple(4, function()
        if IsValid(ply) then
            PD.WB.SyncConfig(ply)
        end
    end)
end)

-- Der Client baut sein Menü aus ply:GetWeapons() auf. Nach jeder Änderung braucht
-- er einen Anstoß, weil die Waffenliste beim Client erst verzögert ankommt.
local function refresh(ply)
    if not IsValid(ply) then return end

    net.Start("PD.WB:Refresh")
    net.Send(ply)
end

-- Das Menü öffnet der Client nur an einer Kiste in bis zu 300 Einheiten und
-- nur, wenn sie nicht kaputt ist. Hier dasselbe verbindlich, mit etwas Luft.
local BOX_RANGE = 350

local function NearWorkingBox(ply)
    if GetGlobal2Bool("WaffenkisteKaputt") then
        return false, "Die Waffenkiste ist kaputt."
    end

    local pos = ply:EyePos()

    for _, box in ipairs(ents.FindByClass("waffenkiste")) do
        if box:GetPos():DistToSqr(pos) <= BOX_RANGE * BOX_RANGE then
            return true
        end
    end

    return false, "Keine Waffenkiste in der Nähe."
end

function PD.WB.GiveAlways(ply)
    if not IsValid(ply) then return end

    for _, class in ipairs(PD.WB.Always) do
        if not ply:HasWeapon(class) then
            ply:Give(class)
        end
    end
end

net.Receive("PD.WB:GiveWeapon", function(len, ply)
    if not IsValid(ply) then return end

    local wep = net.ReadString()

    local near, nearReason = NearWorkingBox(ply)
    if not near then
        PD.Notify(nearReason, Color(200, 150, 40), false, ply)
        return
    end

    -- Vollständige Prüfung serverseitig: Freigabe, Kategorielimit und Gewicht.
    -- Der Client prüft dasselbe nur zur Anzeige.
    local ok, reason = PD.WB.CanTake(ply, wep)

    if not ok then
        PD.Notify(reason or "Nicht möglich", Color(200, 150, 40), false, ply)
        refresh(ply)
        return
    end

    ply:Give(wep)
    refresh(ply)
end)

net.Receive("PD.WB:RemoveWeapon", function(len, ply)
    if not IsValid(ply) then return end

    local wep = net.ReadString()

    -- Immer-Ausrüstung bleibt am Spieler
    if PD.WB.IsAlways(wep) then
        PD.Notify("Diese Ausrüstung kannst du nicht ablegen.", Color(200, 150, 40), false, ply)
        return
    end

    if ply:HasWeapon(wep) then
        ply:StripWeapon(wep)
    end

    refresh(ply)
end)

local wepDeadTbl = {}

hook.Add("PlayerDeath", "PD.WB:PlayerDeath", function(victim, inflictor, attacker)
    if PD.WB.StripWeapnsDead then
        local weapons = victim:GetWeapons()

        wepDeadTbl[victim:SteamID64()] = wepDeadTbl[victim:SteamID64()] or {}

        for _, wep in ipairs(weapons) do
            table.insert(wepDeadTbl[victim:SteamID64()], wep:GetClass())
        end
    end
end)

hook.Add("PlayerSpawn", "PD.WB:PlayerSpawn", function(ply)
    if PD.WB.StripWeapons then
        for _, wep in ipairs(ply:GetWeapons()) do
            -- PD.WB.Always ist eine Liste von Klassen, keine Map. Der alte Code
            -- griff mit PD.WB.DontStrip[class] darauf zu und traf damit nie zu.
            if PD.WB.IsAlways(wep:GetClass()) then continue end

            ply:StripWeapon(wep:GetClass())
        end
    end

    if PD.WB.GiveDeadWeapons and wepDeadTbl[ply:SteamID64()] then
        for _, wep in ipairs(wepDeadTbl[ply:SteamID64()]) do
            ply:Give(wep)
        end

        wepDeadTbl[ply:SteamID64()] = nil
    end

    if PD.Admin and PD.Admin.Equip then
        for _, wep in ipairs(PD.Admin.Equip) do
            ply:Give(wep)
        end
    end

    -- Nach dem Spawn, damit ein vorheriges Strip die Immer-Ausrüstung nicht frisst
    timer.Simple(0, function()
        PD.WB.GiveAlways(ply)
        refresh(ply)
    end)
end)

hook.Add("PlayerInitialSpawn", "PD.WB:PlayerInitialSpawn", function(ply)
    if PD.WB.StripWeapons then
        for _, wep in ipairs(ply:GetWeapons()) do
            if PD.WB.IsAlways(wep:GetClass()) then continue end

            ply:StripWeapon(wep:GetClass())
        end
    end
end)

hook.Add("PlayerDisconnected", "PD.WB:ClearDeadTable", function(ply)
    wepDeadTbl[ply:SteamID64()] = nil
end)
