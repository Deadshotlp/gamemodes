PD = PD or {}
PD.Remote = PD.Remote or {}

-- Bestandsaufnahme der tatsächlich installierten Waffen und Playermodels.
--
-- Das Web-Panel kann damit anzeigen, welche Einträge in Jobs, Fortbildungen und
-- der Waffenkiste auf etwas verweisen, das es auf dem Server gar nicht gibt.
-- Genau die Sorte Tippfehler fällt im Spiel sonst erst auf, wenn jemand mit
-- leeren Händen dasteht.

local TABLE_NAME = "pd_server_assets"

local function esc(value)
    return PD.SQL.EscapeString(tostring(value or ""))
end

local function serverKey()
    local convar = GetConVar("pd_server_key")

    return convar and convar:GetString() or "main"
end

function PD.Remote.EnsureAssetTable(callback)
    PD.SQL.Query(
        "CREATE TABLE IF NOT EXISTS `" .. TABLE_NAME .. "` ("
            .. "`server_key` VARCHAR(64) NOT NULL,"
            .. "`asset_type` VARCHAR(16) NOT NULL,"
            .. "`asset_key` VARCHAR(191) NOT NULL,"
            .. "`label` VARCHAR(191) NOT NULL DEFAULT '',"
            .. "`updated_at` BIGINT NOT NULL DEFAULT 0,"
            .. "PRIMARY KEY (`server_key`, `asset_type`, `asset_key`)"
            .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4",
        callback
    )
end

-- Schreibt den Bestand neu. Bewusst als Transaktion mit vorherigem Löschen:
-- deinstallierte Addons sollen verschwinden, nicht ewig stehenbleiben.
function PD.Remote.WriteAssets(callback)
    local key = serverKey()
    local now = os.time()

    local addQuery = PD.SQL.Begin()

    if not addQuery then
        if isfunction(callback) then callback(false, "Keine Datenbankverbindung") end
        return
    end

    addQuery("DELETE FROM `" .. TABLE_NAME .. "` WHERE `server_key` = " .. esc(key))

    local weaponCount = 0

    for _, weapon in ipairs(weapons.GetList()) do
        local class = weapon.ClassName

        if class and class ~= "" then
            weaponCount = weaponCount + 1

            addQuery("INSERT INTO `" .. TABLE_NAME .. "` "
                .. "(`server_key`, `asset_type`, `asset_key`, `label`, `updated_at`) VALUES ("
                .. esc(key) .. ", 'weapon', " .. esc(class) .. ", "
                .. esc(weapon.PrintName or class) .. ", " .. now .. ")")
        end
    end

    local modelCount = 0

    for name, path in pairs(player_manager.AllValidModels() or {}) do
        modelCount = modelCount + 1

        addQuery("INSERT INTO `" .. TABLE_NAME .. "` "
            .. "(`server_key`, `asset_type`, `asset_key`, `label`, `updated_at`) VALUES ("
            .. esc(key) .. ", 'model', " .. esc(path) .. ", " .. esc(name) .. ", " .. now .. ")")
    end

    PD.SQL.Commit(function()
        if isfunction(callback) then
            callback(true, weaponCount .. " Waffen, " .. modelCount .. " Models")
        end
    end, function(err)
        ErrorNoHalt("[Assets] Schreiben fehlgeschlagen: " .. tostring(err) .. "\n")

        if isfunction(callback) then callback(false, tostring(err)) end
    end)
end

concommand.Add("pd_assets_write", function(ply)
    -- Nur Serverkonsole und RCON, wie die übrigen Fernsteuerungsbefehle.
    if IsValid(ply) then return end

    PD.Remote.WriteAssets(function(ok, info)
        PD.RemoteLog("[Assets] " .. (ok and ("geschrieben: " .. info) or ("fehlgeschlagen: " .. info)))
    end)
end)

-- Spät genug, dass alle Addons ihre Waffen und Models registriert haben.
timer.Simple(20, function()
    PD.Remote.EnsureAssetTable(function()
        PD.Remote.WriteAssets(function(ok, info)
            if ok then
                PD.RemoteLog("[Assets] Bestand erfasst: " .. info)
            end
        end)
    end)
end)
