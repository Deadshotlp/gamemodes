util.AddNetworkString("PD.Char.Admin")
util.AddNetworkString("PD.Char.RequestPlayers")
util.AddNetworkString("PD.Char.RequestPlayerData")

net.Receive("PD.Char.RequestPlayers", function(len, ply)
    if not ply:IsAdmin() then return end

    local tbl = PD.Char:LoadAllChars()

    local tbl2 = {}

    for k, v in pairs(tbl) do
        table.insert(tbl2, k)
    end

    net.Start("PD.Char.RequestPlayers")
    net.WriteTable(tbl2)
    net.Send(ply)
end)

net.Receive("PD.Char.RequestPlayerData", function(len, ply)
    if not ply:IsAdmin() then return end

    local plyid = net.ReadString()

    local tbl = PD.Char:LoadChar(plyid, "Admin Menu Char Editor: sv_adminchar.lua Line 26")

    net.Start("PD.Char.RequestPlayerData")
    net.WriteTable(tbl or {})
    net.Send(ply)
end)

local function AdminNotify(ply, text, ok)
    if PD.Notify then
        PD.Notify(text, ok and Color(90, 200, 90) or Color(255, 60, 60), false, ply)
    end
end

--[[
    Charakter aus dem Admin-Menue speichern, loeschen oder setzen.

    Die Charaktere eines Spielers sind eine Liste nach Slot (1, 2, ...).
    Frueher wurde mit der Charakter-ID ("95-3404") als Schluessel geschrieben.
    Das legte einen zweiten Eintrag mit derselben ID an, die Datenbank lehnte
    das Speichern wegen des doppelten Schluessels ab, und der Name blieb der
    alte. Loeschen und Setzen hatten denselben Fehler. Jetzt wird der Slot ueber
    die ID gesucht.
]]
net.Receive("PD.Char.Admin", function(len, ply)
    if not ply:IsAdmin() then return end

    local typ = net.ReadString()
    local plyid = net.ReadString()
    local playerTable = net.ReadTable()

    local chars = PD.Char:LoadChar(plyid, "AdminSave")

    if not chars then
        AdminNotify(ply, "Keine Charaktere zu " .. plyid .. " gefunden.")
        return
    end

    -- Die ID ist im Menue gesperrt. originalid schickt der Client mit, damit
    -- der Charakter sicher gefunden wird.
    local charID = tostring(playerTable.originalid or playerTable.id or "")
    local index = PD.Char:GetCharIndexByID(chars, charID)

    if not index then
        AdminNotify(ply, "Charakter " .. charID .. " nicht gefunden.")
        return
    end

    local char = chars[index]
    local target = FindPlayerbyID(plyid)
    local isActive = IsValid(target) and PD.Char:GetCharacterID(target) == char.id

    if typ == "save" then
        local name = string.Trim(tostring(playerTable.name or ""))

        if name == "" then
            AdminNotify(ply, "Der Name darf nicht leer sein.")
            return
        end

        -- Neue ID? Dann zuerst umbenennen (alle Tabellen), danach Name und
        -- Credits mit dem frischen Stand speichern.
        local newID = string.Trim(tostring(playerTable.id or charID))

        if newID ~= charID then
            PD.Char:RenameCharID(plyid, charID, newID, function(ok, err)
                if not IsValid(ply) then return end

                if not ok then
                    AdminNotify(ply, "ID nicht geändert: " .. tostring(err))
                    return
                end

                PD.LOGS.Add("char", "Charakter-ID " .. charID .. " von Spieler " .. plyid .. " wurde von " .. ply:Nick() .. " in " .. newID .. " geändert.", Color(0, 255, 0))

                local fresh = PD.Char:LoadChar(plyid, "AdminSave") or {}
                local freshIndex = PD.Char:GetCharIndexByID(fresh, newID)
                if not freshIndex then return end

                local freshChar = fresh[freshIndex]
                local oldName = freshChar.name

                freshChar.name = string.sub(name, 1, 64)
                freshChar.money = math.max(0, math.floor(tonumber(playerTable.money) or tonumber(freshChar.money) or 0))

                PD.Char:SaveChar(plyid, fresh)

                if IsValid(target) and PD.Char:GetCharacterID(target) == newID then
                    target:SetNWString("rpname", PD.Char.BuildRPName(newID, freshChar.name))
                    PD.Char:SyncChar(target, "AdminSave")
                end

                if PD.List and PD.List.LoadFactions then
                    PD.List:LoadFactions()
                    PD.List:SyncAll()
                end

                -- Menue des Admins mit den neuen IDs neu aufbauen - sonst
                -- zeigte ein zweites Speichern noch auf die alte ID.
                net.Start("PD.Char.RequestPlayerData")
                net.WriteTable(PD.Char:LoadChar(plyid, "AdminSave") or {})
                net.Send(ply)

                AdminNotify(ply, "Charakter " .. newID .. " gespeichert (vorher " .. charID .. ").", true)
                PD.LOGS.Add("char", "Charakter " .. newID .. " von Spieler " .. plyid .. " wurde von " .. ply:Nick() .. " gespeichert (Name: " .. tostring(oldName) .. " -> " .. freshChar.name .. ").", Color(0, 255, 0))
            end)

            return
        end

        local oldName = char.name

        char.name = string.sub(name, 1, 64)
        char.money = math.max(0, math.floor(tonumber(playerTable.money) or tonumber(char.money) or 0))

        PD.Char:SaveChar(plyid, chars)

        if isActive then
            target:SetNWString("rpname", PD.Char.BuildRPName(char.id, char.name))
        end

        if IsValid(target) then
            PD.Char:SyncChar(target, "AdminSave")
        end

        -- Namen im Fraktionsbaum nachziehen.
        if PD.List and PD.List.LoadFactions then
            PD.List:LoadFactions()
            PD.List:SyncAll()
        end

        AdminNotify(ply, "Charakter " .. char.id .. " gespeichert.", true)
        PD.LOGS.Add("char", "Charakter " .. char.id .. " von Spieler " .. plyid .. " wurde von " .. ply:Nick() .. " gespeichert (Name: " .. tostring(oldName) .. " -> " .. char.name .. ").", Color(0, 255, 0))
    elseif typ == "delete" then
        hook.Run("PlayerDeleteCharacter", target, char)

        table.remove(chars, index)
        PD.Char:SaveChar(plyid, chars)

        if isActive then
            PD.Char:StopTimer(plyid)
            target.CharID = nil
            target:SetNWString("character_id", "9999")
            target:SetNWString("rpname", "")
        end

        if IsValid(target) then
            PD.Char:SyncChar(target, "AdminDelete")

            if isActive then
                net.Start("OpenCharbyDelete")
                net.Send(target)
            end
        end

        AdminNotify(ply, "Charakter " .. char.id .. " gelöscht.", true)
        PD.LOGS.Add("char", "Charakter mit der ID " .. char.id .. " von Spieler " .. plyid .. " wurde von " .. ply:Nick() .. " gelöscht!", Color(255, 0, 0))
    elseif typ == "set" then
        if not IsValid(target) then
            AdminNotify(ply, "Der Spieler ist nicht online.")
            return
        end

        PD.Char:PlayerSetChar(target, index)

        AdminNotify(ply, "Charakter " .. char.id .. " gesetzt.", true)
        PD.LOGS.Add("char", "Charakter mit der ID " .. char.id .. " von Spieler " .. plyid .. " wurde von " .. ply:Nick() .. " ausgewählt!", Color(0, 255, 0))
    end
end)

net.Receive("PD.Char.AdminDelete",function(len,ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local plyid = net.ReadString()
    local charid = net.ReadUInt(32)

    local tbl = PD.Char:LoadChar(plyid, "AdminDelete: " .. plyid)

    if tbl then
        table.remove(tbl,charid)
        PD.Char:SaveChar(plyid,tbl)

        PD.LOGS.Add("char", "Charakter mit der ID " .. charid .. " von Spieler " .. plyid .. " wurde von " .. ply:Nick() .. " gelöscht!", Color(255, 0, 0))
    end
end)

-- local function GenerateMissingCharID()
--     local prefix = string.format("%02d", math.random(10, 99))
--     local suffix = string.format("%04d", math.random(1000, 9999))
--     return prefix .. "-" .. suffix
-- end

-- local function CharIDExists(id, allChars)
--     if not id or id == "" then return false end

--     for _, chars in pairs(allChars or {}) do
--         for _, char in pairs(chars or {}) do
--             if char.id == id then
--                 return true
--             end
--         end
--     end

--     return false
-- end

-- function PD.Char:AddMissingCharIDs()
--     if not file.IsDir("modules/char", "DATA") then
--         file.CreateDir("modules/char")
--     end

--     local files = file.Find("modules/char/*.json", "DATA")
--     local allChars = {}
--     local changedFiles = 0
--     local changedChars = 0

--     for _, fileName in pairs(files or {}) do
--         local steamid = string.gsub(fileName, "%.json$", "")
--         local path = "modules/char/" .. fileName
--         local data = util.JSONToTable(file.Read(path, "DATA") or "")

--         allChars[steamid] = istable(data) and data or {}
--     end

--     for steamid, chars in pairs(allChars) do
--         local fileChanged = false

--         for _, char in pairs(chars or {}) do
--             if not char.id or char.id == "" then
--                 local newID = GenerateMissingCharID()

--                 while CharIDExists(newID, allChars) do
--                     newID = GenerateMissingCharID()
--                 end

--                 char.id = newID
--                 fileChanged = true
--                 changedChars = changedChars + 1

--                 print("[PD.Char:AddMissingCharIDs] Neue CharID gesetzt:", steamid, newID, tostring(char.name))
--             end
--         end

--         if fileChanged then
--             file.Write("modules/char/" .. steamid .. ".json", util.TableToJSON(chars, true))
--             changedFiles = changedFiles + 1
--         end
--     end

--     print("[PD.Char:AddMissingCharIDs] Fertig. Geänderte Dateien:", changedFiles, "Geänderte Charaktere:", changedChars)
-- end

-- function PD.JOBS:AddValueToEveryJob(key, value, overwrite)
--     if not PD.JOBS or not PD.JOBS.Jobs then
--         print("[PD.JOBS:AddValueToEveryJob] Keine Jobs gefunden")
--         return
--     end

--     local changedJobs = 0

--     for unitIndex, unitData in pairs(PD.JOBS.Jobs or {}) do
--         for subIndex, subData in pairs(unitData.subunits or {}) do
--             for jobIndex, jobData in pairs(subData.jobs or {}) do
--                 if overwrite or jobData[key] == nil then
--                     jobData[key] = value
--                     changedJobs = changedJobs + 1
--                     print("[PD.JOBS:AddValueToEveryJob] Wert gesetzt:", tostring(unitIndex), tostring(subIndex), tostring(jobIndex), tostring(key), tostring(value))
--                 end
--             end
--         end
--     end

--     if PD.JOBS.SaveJobs then
--         PD.JOBS.SaveJobs()
--     elseif PD.JOBS.SaveJob then
--         PD.JOBS.SaveJob()
--     end

--     print("[PD.JOBS:AddValueToEveryJob] Fertig. Geänderte Jobs:", changedJobs)
-- end

-- PD.Char:AddMissingCharIDs()
-- PD.JOBS:AddValueToEveryJob("showid", false, false) -- Füge die "showid" Eigenschaft mit dem Standardwert false hinzu, ohne vorhandene Werte zu überschreiben