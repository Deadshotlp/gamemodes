PD.List = PD.List or {}

util.AddNetworkString("PD.List.Invite")
util.AddNetworkString("PD.List.Kick")
util.AddNetworkString("PD.List.RankUp")
util.AddNetworkString("PD.List.RankDown")
util.AddNetworkString("PD.List.SendData")
util.AddNetworkString("PD.List.RequestData")
util.AddNetworkString("PD.List.AdminChange")

local function GetJobNode(unit, subunit, job)
    return PD.List.Tbl[unit]
        and PD.List.Tbl[unit].subunits
        and PD.List.Tbl[unit].subunits[subunit]
        and PD.List.Tbl[unit].subunits[subunit].jobs
        and PD.List.Tbl[unit].subunits[subunit].jobs[job]
end

local function GetDefaultJobForSubunit(unit, subunit)
    local unitNode = PD.JOBS and PD.JOBS.Jobs and PD.JOBS.Jobs[unit]
    local subNode = unitNode and unitNode.subunits and unitNode.subunits[subunit]
    if not subNode then return nil end

    for jobIndex, jobData in pairs(subNode.jobs or {}) do
        if jobData.default then
            return jobIndex
        end
    end

    return next(subNode.jobs or {})
end

local function FindTargetFromRankNet(len)
    if len <= 40 then
        local actor = net.ReadEntity()
        local target = net.ReadEntity()

        if actor ~= nil then
            return target
        end

        return nil
    end

    local charID = net.ReadString()
    return FindPlayerbyCharID(charID)
end

function PD.List:GetPlayerData(ply)
    if not IsValid(ply) then return end
    return PD.List:GetPlayerFaction(ply)
end

function PD.List:GetAllData()
    local allData = {}

    for _, v in pairs(player.GetAll()) do
        if not IsValid(v) then continue end

        local unit, subunit, job = PD.List:GetPlayerData(v)
        allData[v:SteamID64()] = {
            unit = unit,
            subunit = subunit,
            job = job
        }
    end

    return allData
end

function PD.List:SendDataToAllClient()
    net.Start("PD.List.SendData")
    net.WriteTable(PD.List:GetAllData())
    net.Broadcast()
end

function PD.List:SetPlayerData(ply, unit, sub, job)
    if not IsValid(ply) then return end
    PD.List:ChangeFaction(ply, unit, sub, job)
end

function PD.List:SetDefault(ply)
    if not IsValid(ply) then return end
    PD.List:SetPlayerDefaultFaction(ply)
end

function PD.List:SetFaction(ply, faction, sub, job)
    if not IsValid(ply) then return end
    PD.List:ChangeFaction(ply, faction, sub, job)
end

function PD.List:CheckPermission(ply)
    if not IsValid(ply) then return 0 end
    if ply:IsAdmin() then return 9999 end

    local unit, sub, job = PD.List:GetPlayerFaction(ply)
    local jobNode = GetJobNode(unit, sub, job)
    if not jobNode then return 0 end

    return tonumber(jobNode.rank or 0)
end

function PD.List:RankUP(officer, target)
    if not IsValid(officer) or not IsValid(target) then return end

    local unit, sub, job = PD.List:GetPlayerFaction(target)
    if not unit or not sub or not job then return end
    if not PD.List:CheckPermissionLevel(officer, unit, sub, job) then return end

    PD.List:RankUp(target, unit, sub, job)

    if PD.LOGS and PD.LOGS.Add then
        local _, _, newJob = PD.List:GetPlayerFaction(target)
        PD.LOGS.Add("[Beförderung]", officer:Nick() .. " hat " .. target:Nick() .. " zu " .. tostring(newJob) .. " befördert.", Color(0, 255, 0))
    end
end

function PD.List:RankDown(officer, target)
    if not IsValid(officer) or not IsValid(target) then return end

    local unit, sub, job = PD.List:GetPlayerFaction(target)
    if not unit or not sub or not job then return end
    if not PD.List:CheckPermissionLevel(officer, unit, sub, job) then return end

    PD.List:RankDown(target, unit, sub, job)

    if PD.LOGS and PD.LOGS.Add then
        local _, _, newJob = PD.List:GetPlayerFaction(target)
        PD.LOGS.Add("[Degradierung]", officer:Nick() .. " hat " .. target:Nick() .. " zu " .. tostring(newJob) .. " degradiert.", Color(255, 165, 0))
    end
end

function PD.List:KickPlayer(officer, target)
    if not IsValid(officer) or not IsValid(target) then return end

    local unit, sub, job = PD.List:GetPlayerFaction(target)
    if not unit or not sub or not job then return end
    if not PD.List:CheckPermissionLevel(officer, unit, sub, job) then return end

    PD.List:RemoveFactionByCharID(target:GetCharacterID(), true, target)

    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("[Entfernung]", officer:Nick() .. " hat " .. target:Nick() .. " aus der Einheit entfernt.", Color(255, 0, 0))
    end
end

function PD.List:InvitePlayer(officer, target)
    if not IsValid(officer) or not IsValid(target) then return end

    local unit, sub = PD.List:GetPlayerFaction(officer)
    if not unit or not sub then return end

    local officerRank = PD.List:CheckPermission(officer)
    if officerRank < 1 and not officer:IsAdmin() then return end

    local inviteJob = GetDefaultJobForSubunit(unit, sub)
    if not inviteJob then return end

    PD.List:SetPlayerFaction(target, unit, sub, inviteJob)

    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("[Aufnahme]", officer:Nick() .. " hat " .. target:Nick() .. " in die Einheit aufgenommen.", Color(0, 255, 0))
    end
end

net.Receive("PD.List.Invite", function(_, ply)
    local officer = net.ReadEntity()
    local target = net.ReadEntity()

    if officer ~= ply then officer = ply end
    PD.List:InvitePlayer(officer, target)
end)

net.Receive("PD.List.Kick", function(_, ply)
    local officer = net.ReadEntity()
    local target = net.ReadEntity()

    if officer ~= ply then officer = ply end
    PD.List:KickPlayer(officer, target)
end)

net.Receive("PD.List.RankUp", function(len, ply)
    local target = FindTargetFromRankNet(len)
    PD.List:RankUP(ply, target)
end)

net.Receive("PD.List.RankDown", function(len, ply)
    local target = FindTargetFromRankNet(len)
    PD.List:RankDown(ply, target)
end)

net.Receive("PD.List.RequestData", function(_, ply)
    if not IsValid(ply) then return end

    net.Start("PD.List.SendData")
    net.WriteTable(PD.List:GetAllData())
    net.Send(ply)
end)

net.Receive("PD.List.AdminChange", function(_, ply)
    print("[PD.List.AdminChange] Net receive gestartet")

    if not IsValid(ply) then
        print("[PD.List.AdminChange] Abbruch: ply ist nicht valide")
        return
    end

    print("[PD.List.AdminChange] Sender:", ply:Nick(), ply:SteamID64(), "Admin:", ply:IsAdmin())

    if not ply:IsAdmin() then
        print("[PD.List.AdminChange] Abbruch: Spieler ist kein Admin")
        return
    end

    local steamid = net.ReadString()
    local charID = net.ReadString()
    local unit = net.ReadString()
    local subunit = net.ReadString()
    local job = net.ReadString()

    print("[PD.List.AdminChange] Gelesene Daten:")
    print("  steamid =", tostring(steamid))
    print("  charID  =", tostring(charID))
    print("  unit    =", tostring(unit))
    print("  subunit =", tostring(subunit))
    print("  job     =", tostring(job))

    if not steamid or steamid == "" then
        print("[PD.List.AdminChange] Abbruch: steamid leer oder nil")
        return
    end

    if not charID or charID == "" then
        print("[PD.List.AdminChange] Abbruch: charID leer oder nil")
        return
    end

    print("[PD.List.AdminChange] Prüfe PD.Char.UpdateStoredCharJobData:", PD.Char and PD.Char.UpdateStoredCharJobData and "vorhanden" or "NICHT vorhanden")

    local ok = PD.Char and PD.Char.UpdateStoredCharJobData and PD.Char:UpdateStoredCharJobData(steamid, charID, unit, subunit, job)
    print("[PD.List.AdminChange] UpdateStoredCharJobData Ergebnis:", tostring(ok))

    if not ok then
        print("[PD.List.AdminChange] Abbruch: UpdateStoredCharJobData fehlgeschlagen")
        return
    end

    local target = FindPlayerbyID(steamid)
    print("[PD.List.AdminChange] FindPlayerbyID Ergebnis:", IsValid(target) and target:Nick() or "kein valider Spieler")

    if IsValid(target) then
        print("[PD.List.AdminChange] Target CharacterID:", tostring(target:GetCharacterID()))
    end

    if IsValid(target) and target:GetCharacterID() == charID then
        print("[PD.List.AdminChange] Zielspieler ist online und aktiver Char passt, SetPlayerFaction wird aufgerufen")
        PD.List:SetPlayerFaction(target, unit, subunit, job)
        print("[PD.List.AdminChange] SetPlayerFaction ausgeführt")
    else
        print("[PD.List.AdminChange] Offline- oder nicht aktiver Char-Pfad wird genutzt")

        local oldFactionUnit, oldFactionSub, oldFactionJob = PD.List:GetPlayerFactionByCharID(charID)
        print("[PD.List.AdminChange] Alte Fraktion:")
        print("  oldFactionUnit =", tostring(oldFactionUnit))
        print("  oldFactionSub  =", tostring(oldFactionSub))
        print("  oldFactionJob  =", tostring(oldFactionJob))

        if oldFactionUnit and oldFactionSub and oldFactionJob then
            local jobNode = PD.List.Tbl[oldFactionUnit]
                and PD.List.Tbl[oldFactionUnit].subunits
                and PD.List.Tbl[oldFactionUnit].subunits[oldFactionSub]
                and PD.List.Tbl[oldFactionUnit].subunits[oldFactionSub].jobs
                and PD.List.Tbl[oldFactionUnit].subunits[oldFactionSub].jobs[oldFactionJob]

            print("[PD.List.AdminChange] Alter JobNode gefunden:", jobNode and "ja" or "nein")

            if jobNode and jobNode.players then
                print("[PD.List.AdminChange] Entferne alten Faction-Eintrag für CharID:", tostring(charID))
                jobNode.players[charID] = nil
            else
                print("[PD.List.AdminChange] Konnte alten JobNode oder players nicht auflösen")
            end
        else
            print("[PD.List.AdminChange] Keine alte Fraktion für CharID gefunden")
        end

        local resolvedUnit = nil
        local resolvedSub = nil
        local resolvedJob = nil

        print("[PD.List.AdminChange] Starte Auflösung der Ziel-Fraktion aus PD.JOBS.Jobs")

        for unitIndex, unitData in pairs(PD.JOBS.Jobs or {}) do
            local unitMatch = unitIndex == unit or unitData.name == unit
            print("[PD.List.AdminChange] Prüfe Unit:", tostring(unitIndex), "Name:", tostring(unitData.name), "Match:", tostring(unitMatch))

            if not unitMatch then
                continue
            end

            for subIndex, subData in pairs(unitData.subunits or {}) do
                local subMatch = subIndex == subunit or subData.name == subunit
                print("[PD.List.AdminChange]   Prüfe SubUnit:", tostring(subIndex), "Name:", tostring(subData.name), "Match:", tostring(subMatch))

                if not subMatch then
                    continue
                end

                for jobIndex, jobData in pairs(subData.jobs or {}) do
                    local jobMatch = jobIndex == job or jobData.name == job
                    print("[PD.List.AdminChange]     Prüfe Job:", tostring(jobIndex), "Name:", tostring(jobData.name), "Match:", tostring(jobMatch))

                    if jobMatch then
                        resolvedUnit = unitIndex
                        resolvedSub = subIndex
                        resolvedJob = jobIndex
                        print("[PD.List.AdminChange]     Ziel-Fraktion erfolgreich aufgelöst")
                        break
                    end
                end

                if resolvedUnit then break end
            end

            if resolvedUnit then break end
        end

        print("[PD.List.AdminChange] Aufgelöste Werte:")
        print("  resolvedUnit =", tostring(resolvedUnit))
        print("  resolvedSub  =", tostring(resolvedSub))
        print("  resolvedJob  =", tostring(resolvedJob))

        if resolvedUnit and resolvedSub and resolvedJob then
            local targetJobNode = PD.List.Tbl[resolvedUnit]
                and PD.List.Tbl[resolvedUnit].subunits
                and PD.List.Tbl[resolvedUnit].subunits[resolvedSub]
                and PD.List.Tbl[resolvedUnit].subunits[resolvedSub].jobs
                and PD.List.Tbl[resolvedUnit].subunits[resolvedSub].jobs[resolvedJob]

            print("[PD.List.AdminChange] Ziel-JobNode gefunden:", targetJobNode and "ja" or "nein")

            if targetJobNode and targetJobNode.players then
                print("[PD.List.AdminChange] Trage Char in neue Fraktion ein:", tostring(charID))

                targetJobNode.players[charID] = {
                    name = charID,
                    steamid = steamid,
                    unit = resolvedUnit,
                    subunit = resolvedSub,
                    job = resolvedJob,
                    join = os.date("%d.%m.%Y %H:%M:%S", os.time()),
                    lastplay = os.date("%d.%m.%Y %H:%M:%S", os.time()),
                    playtime = 0
                }

                print("[PD.List.AdminChange] Neuer Eintrag gesetzt, speichere und synchronisiere")
                PD.List.Save()
                PD.List:SyncAll()
                print("[PD.List.AdminChange] Save und SyncAll abgeschlossen")
            else
                print("[PD.List.AdminChange] Fehler: Ziel-JobNode oder players fehlt")
            end
        else
            print("[PD.List.AdminChange] Fehler: Ziel-Fraktion konnte nicht aufgelöst werden")
        end
    end

    print("[PD.List.AdminChange] Sende Daten an alle Clients")
    PD.List:SendDataToAllClient()

    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("[Fraktionsänderung]", ply:Nick() .. " hat die Fraktion von " .. steamid .. " geändert.", Color(0, 255, 0))
        print("[PD.List.AdminChange] PD.LOGS.Add ausgeführt")
    else
        print("[PD.List.AdminChange] PD.LOGS.Add nicht verfügbar")
    end

    print("[PD.List.AdminChange] Verarbeitung abgeschlossen")
end)

hook.Add("PD_Faction_Change", "PD.List.SendDataOnFactionChange.Admin", function()
    PD.List:SendDataToAllClient()
end)

hook.Add("PlayerInitialSpawn", "PD.List.SendAdminFactionData.OnSpawn", function(ply)
    timer.Simple(0.4, function()
        if not IsValid(ply) then return end

        net.Start("PD.List.SendData")
        net.WriteTable(PD.List:GetAllData())
        net.Send(ply)
    end)
end)

timer.Simple(1, function()
    PD.List:SendDataToAllClient()
end)