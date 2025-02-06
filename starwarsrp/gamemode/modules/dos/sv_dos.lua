-- PD.DOS = PD.DOS or {}
-- PD.DOS.Accounts = {
--     [1] = {
--         id = 1,
--         name = "Deadshot",
--         verifikation = "45-2342", --Die ID des Klones
--         rang = "Commander",
--         subunit = "Torrent Comany",
--         unit = "501st",
--         permissionLevel = 100,
--         personalakte = {},
--         medizinischeakte = {},
--         strafakte = {},
--     }
-- }

-- util.AddNetworkString("PD.RequestLogin")

-- hook.Add("PlayerSay", "PD.DOS.AddUserManuel", function(sender, text , teamChat)
--     local parts = string.Split(text, " ")

--     if sender:IsAdmin() and parts[1] == "!dos_adduser" then
--         for _, ply in ipairs(player.GetAll()) do
--             if string.find(ply:Nick():lower(), parts[2]:lower()) then
--                 for k, v in pairs(PD.DOS.Accounts) do
--                     if v.name == ply:Nick() then
--                         PD.Notify("Der Benutzer Existiert Bereits!", Color(255, 30, 30, 255), false, sender)
--                         return
--                     end
--                 end
--                 if not PD.Char:GetPlayerCharTBL(ply).job.id then
--                     PD.DOS.CreateUserEntry(ply, PD.JOBS.GetJob())
--                 else
--                     PD.DOS.CreateUserEntry(ply, PD.JOBS.GetJobByID(PD.Char:GetPlayerCharTBL(ply).job.id))
--                 end

--             end
--         end
--     end
-- end)

-- hook.Add("PostPDLoaded", "PD.DOS.LoadeAccounts", function()
--     PD.DOS.LoadDir()
-- end)

-- hook.Add("ShutDown", "PD.DOS.SaveAccounts", function()
--     PD.DOS.SaveDir()
-- end)

-- hook.Add("PlayerCreateCharacter", "PD.DOS.CreateUserEntry", function(ply, DataTable)
--     local job = PD.JOBS.GetJobByID(DataTable.job.id)

--     PD.DOS.CreateUserEntry(ply, job)
-- end)

-- hook.Add("PlayerDeleteCharacter", "PD.DOS.DeleateUserEntry", function(ply, DataTable)
--     for k, v in pairs(PD.DOS.Accounts) do
--         if v.verifikation == DataTable.id and v.name == DataTable.name then
--             table.remove(PD.DOS.Accounts, k)
--         end
--     end
-- end)

-- net.Receive("PD.RequestLogin", function(len, ply)
--     local ent = net.ReadEntity()
--     local ver = net.ReadString()

--     for k, v in pairs(PD.DOS.Accounts) do
--         if tostring(v.verifikation) == ver then --and v.permissionLevel >= 15 then
--             ent:SetNWBool("LoggdIn", true)
--             return
--         end
--     end
-- end)

-- function PD.DOS.LoadDir()
--     local dir = "deadshot/dos"
--     if not PD.JSON.Exists(dir) then
--         PD.JSON.Create(dir)
--     end

--     PD.DOS.LoadAccounts()
-- end

-- function PD.DOS.LoadAccounts()
--     local dir = "deadshot/dos/accounts.json"
--     if not PD.JSON.Exists(dir) then
--         PD.JSON.Write(dir, PD.DOS.Accounts)
--     end

--     PD.DOS.Accounts = PD.JSON.Read(dir)
-- end

-- function PD.DOS.SaveDir()
--     local dir = "deadshot/dos"
--     if not PD.JSON.Exists(dir) then
--         PD.JSON.Create(dir)
--     end
--     PD.DOS.SaveAccounts()
-- end

-- function PD.DOS.SaveAccounts()
--     local dir = "deadshot/dos/accounts.json"
--     if PD.JSON.Exists(dir) then
--         PD.JSON.Delete(dir)
--     end

--     PD.JSON.Write(dir, PD.DOS.Accounts)
-- end

-- function PD.DOS.CreateUserEntry(ply, job)
--     local name_parts = string.Split(ply:GetNWString("rpname"), " ")

--     local newAccount = {
--         id = #PD.DOS.Accounts + 1,
--         name = name_parts[2],
--         verifikation = name_parts[1], --Die ID des Klones
--         rang = job.name,
--         subunit = PD.JOBS.GetSubUnit(job.subunit).name,
--         unit = PD.JOBS.GetSubUnit(job.subunit).unit,
--         permissionLevel = job.permissionlevel,
--         personalakte = {},
--         medizinischeakte = {},
--         strafakte = {},
--     }

--     table.insert(PD.DOS.Accounts, newAccount) 
-- end