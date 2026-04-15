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

net.Receive("PD.Char.Admin",function(len, ply)
    if not ply:IsAdmin() then return end

    local typ = net.ReadString()
    local plyid = net.ReadString()
    local playerTable = net.ReadTable()

    local tbl = PD.Char:LoadChar(plyid, "AdminSave")

    if tbl then
        if typ == "save" then
            playerTable.admin = ply:SteamID64()
            playerTable.lastupdateadin = os.date("%d.%m.%Y %H:%M:%S", os.time())

            tbl[playerTable.id] = playerTable
            PD.Char:SaveChar(plyid, tbl)

            PD.LOGS.Add("char", "Charakter mit der ID " .. playerTable.id .. " von Spieler " .. plyid .. " wurde von " .. ply:Nick() .. " gespeichert!", Color(0, 255, 0))
        elseif typ == "delete" then
            local charid = playerTable.id
            table.remove(tbl, charid)
            PD.Char:SaveChar(plyid, tbl)

            if #tbl > 0 then
                local charID = 0

                for k, v in pairs(tbl) do
                    if v.id ~= charid then
                        charID = k
                        break
                    end
                end

                if charID == 0 then 
                    net.Start("OpenCharbyDelete")
                    net.Send(FindPlayerbyID(plyid))
                    return 
                end

                PD.Char:PlayerSetChar(FindPlayerbyID(plyid), charID)

                PD.LOGS.Add("char", "Charakter mit der ID " .. charid .. " von Spieler " .. plyid .. " wurde von " .. ply:Nick() .. " gelöscht!", Color(255, 0, 0))
            end
        elseif typ == "set" then
            local charID = playerTable.id

            PD.Char:PlayerSetChar(FindPlayerbyID(plyid), charID)

            PD.LOGS.Add("char", "Charakter mit der ID " .. charID .. " von Spieler " .. plyid .. " wurde von " .. ply:Nick() .. " ausgewählt!", Color(0, 255, 0))
        end
    end
end)

net.Receive("PD.Char.AdminDelete",function(len,ply)
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