PD = PD or {}
PD.Armor = PD.Armor or {}
PD.Armor.Data = PD.Armor.Data or {}

PD.Armor.TableName = "pd_armor"

local function QuoteIdentifier(identifier)
    identifier = tostring(identifier or "")
    identifier = identifier:gsub("`", "``")
    return "`" .. identifier .. "`"
end

util.AddNetworkString("PD.Armor.RequestData")
util.AddNetworkString("PD.Armor.UpdateData")

if SERVER then
    -- Global statt local, damit ein Reload von außen (pd_reload armor) die Daten
    -- neu einlesen kann. Ohne Callback verhält sie sich wie die frühere LoadData.
    function PD.Armor.Load(callback)
        PD.SQL.Query("SELECT `namen`, `model`, `armorvalue`, `description` FROM " .. QuoteIdentifier(PD.Armor.TableName), function(rows)
            PD.Armor.Data = {}

            for _, row in ipairs(rows or {}) do
                table.insert(PD.Armor.Data, {
                    Name = row.namen,
                    Model = row.model,
                    ArmorValue = tonumber(row.armorvalue) or 0,
                    Description = row.description
                })
            end

            -- isfunction statt nur truthy: PD.SQL reicht seinen Callbacks das
            -- Abfrageergebnis durch. Wird Load versehentlich direkt als Callback
            -- übergeben, landet hier eine Tabelle statt einer Funktion.
            if isfunction(callback) then callback(PD.Armor.Data) end
        end)
    end

    -- Schickt den aktuellen Stand an alle Admins, die das Menü offen haben könnten.
    function PD.Armor.Broadcast()
        for _, ply in ipairs(player.GetAll()) do
            if ply:IsAdmin() then
                net.Start("PD.Armor.RequestData")
                    net.WriteTable(PD.Armor.Data)
                net.Send(ply)
            end
        end
    end

    -- Bewusst in einer eigenen Funktion gekapselt: PD.SQL ruft den Callback mit
    -- dem Abfrageergebnis auf, und das darf nicht als Callback bei Load landen.
    PD.SQL.Query([[
        CREATE TABLE IF NOT EXISTS ]] .. QuoteIdentifier(PD.Armor.TableName) .. [[ (
            `id` INT UNSIGNED NOT NULL AUTO_INCREMENT,
            `namen` VARCHAR(255) NOT NULL DEFAULT '',
            `model` VARCHAR(255) NOT NULL,
            `armorvalue` INT NOT NULL,
            `description` TEXT NOT NULL,
            PRIMARY KEY (`id`)
        )
    ]], function()
        PD.Armor.Load()
    end)
end

net.Receive("PD.Armor.RequestData", function(len, ply)


    if ply:IsAdmin() then
        net.Start("PD.Armor.RequestData")
        net.WriteTable(PD.Armor.Data)
        net.Send(ply)
    end
end)

net.Receive("PD.Armor.UpdateData", function(len, ply)
    if ply:IsAdmin() then
        local armor_list = net.ReadTable()

        PD.Armor.Data = {}

        for _, armor in ipairs(armor_list) do
            table.insert(PD.Armor.Data, {
                Name = armor.Name,
                Model = armor.Model,
                ArmorValue = tonumber(armor.ArmorValue) or 0,
                Description = armor.Description
            })
        end

        -- In einer Transaktion: Löschen und Neuanlegen gelingen gemeinsam oder gar
        -- nicht. Vorher liefen die Abfragen einzeln - schlug eine fehl, war die
        -- Tabelle danach halb leer.
        local addQuery = isfunction(PD.SQL.Begin) and PD.SQL.Begin()

        if not isfunction(addQuery) then
            PD.Notify("Rüstungen nicht gespeichert: keine Datenbankverbindung.", Color(255, 60, 60), false, ply)
            PD.Armor.Load(function() PD.Armor.Broadcast() end)
            return
        end

        addQuery("DELETE FROM " .. QuoteIdentifier(PD.Armor.TableName))

        for _, armor in ipairs(PD.Armor.Data) do
            addQuery("INSERT INTO " .. QuoteIdentifier(PD.Armor.TableName) .. " (namen, model, armorvalue, description) VALUES (" ..
                PD.SQL.EscapeString(armor.Name) .. ", " ..
                PD.SQL.EscapeString(armor.Model) .. ", " ..
                math.floor(tonumber(armor.ArmorValue) or 0) .. ", " ..
                PD.SQL.EscapeString(armor.Description) .. ")")
        end

        PD.SQL.Commit(function()
            PD.Notify("Rüstungen gespeichert.", Color(90, 200, 90), false, ply)

            net.Start("PD.Armor.RequestData")
            net.WriteTable(PD.Armor.Data)
            net.Broadcast()
        end, function(err)
            ErrorNoHalt("[PD.Armor] Speichern fehlgeschlagen: " .. tostring(err) .. "\n")
            PD.Notify("Rüstungen nicht gespeichert: " .. tostring(err), Color(255, 60, 60), false, ply)

            -- Stand wieder aus der Datenbank, damit das Menü nichts zeigt, was
            -- nicht gespeichert ist.
            PD.Armor.Load(function() PD.Armor.Broadcast() end)
        end)
    end
end)
