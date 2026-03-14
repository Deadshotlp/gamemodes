PD.List = PD.List or {}

util.AddNetworkString("PD.List.Invite")
util.AddNetworkString("PD.List.Kick")
util.AddNetworkString("PD.List.RankUp")
util.AddNetworkString("PD.List.RankDown")
util.AddNetworkString("PD.List.SendData")
util.AddNetworkString("PD.List.RequestData")
util.AddNetworkString("PD.List.AdminChange")

function PD.List:GetPlayerData(ply)
    local plyTable = PD.Char:PlayerActiveChar(ply)
    if not plyTable then print(PD.Char:GetCharacterID(ply)) print("Table nicht da") return end

    local factionTable = plyTable.faction

    return factionTable.unit, factionTable.subunit, factionTable.job
end

function PD.List:SendDataToAllClient()
    local allData = {}

    for k, v in pairs(player.GetAll()) do
        local tunit, tsub, tjob = PD.List:GetPlayerData(v)

        allData[v:SteamID64()] = {
            unit = tunit,
            subunit = tsub,
            job = tjob
        }
        -- print(v:Nick() .. " | " .. tunit .. " | " .. tsub .. " | " .. tjob)
    end

    net.Start("PD.List.SendData")
        net.WriteTable(allData)
    net.Broadcast()
end

function PD.List:SetPlayerData(ply, unit, sub, job)
    local tbl = PD.Char:LoadChar(ply:SteamID64(), "ShutDown")
    local id = FindPlayerCharbyName(string.sub(ply:Nick(), 9), tbl)

    if tbl and tbl[id] then
        tbl[id].faction.unit = unit
        tbl[id].faction.subunit = sub
        tbl[id].faction.job = job

        PD.Char:SaveChar(ply:SteamID64(),tbl)

        PD.List:SendDataToAllClient()

        local jobTable = {}
        local _, sub = PD.JOBS.GetSubUnit(sub, false)
        jobTable = sub.jobs[job] or {}

        hook.Run("PD_Faction_Change", ply, unit, sub, job, jobTable)
    end
end

timer.Simple(1, function()
    PD.List:SendDataToAllClient()
end)

function PD.List:SetDefault(ply)
    local factionName = PD.JOBS.GetUnit()
    local subfactionName = PD.JOBS.GetSubUnit()
    local jobName = PD.JOBS.GetJob()

    PD.List:SetPlayerData(ply, factionName, subfactionName, jobName)
end

function PD.List:SetFaction(ply, faction, sub, job)
    PD.List:SetPlayerData(ply, faction, sub, job)
end

PD.List.JobRanks = {
    ["Major"] = 16,
    ["Captain"] = 15,
    ["Lieutenant"] = 14,
    ["Sergeant Major"] = 13,
    ["Master Sergeant"] = 12,
    ["Detachment Commander"] = 11,
    ["Chief Operative"] = 10,
    ["Operative First Class"] = 9,
    ["Operative Second Class"] = 8,
    ["Sergeant"] = 7,
    ["Corporal"] = 6,
    ["Lance Corporal"] = 5,
    ["Specialist"] = 4,
    ["Private"] = 3,
    ["Trooper"] = 2,
    ["Cadet"] = 1
}

PD.List.JobRanksNavy = {
    ["Grand Admiral"] = 14,
    ["Captain"] = 13,
    ["Commander"] = 12,
    ["Lieutenant Commander"] = 11,
    ["Lieutenant"] = 10,
    ["Lieutenant Jr. Grade"] = 9,
    ["Ensign"] = 8,
    ["Master Chief Petty Officer"] = 7,
    ["Chief Petty Officer"] = 6,
    ["Petty Officer"] = 5,
    ["Leading Crewman"] = 4,
    ["Crewman First Class"] = 3,
    ["Crewman"] = 2,
    ["Cadet"] = 1
}

function PD.List:CheckPermission(ply)
    local uni, sub, job = PD.List:GetPlayerData(ply)
    local num = 0

    if unit == "Republic Navy" then
        for k, v in SortedPairs(PD.List.JobRanksNavy) do
            if k == job then
                num = v
            end
        end
    else
        for k, v in SortedPairs(PD.List.JobRanks) do
            if k == job then
                num = v
            end
        end
    end

    return num
end

function PD.List:RankUP(officer, ply)
    local permissionOfficer = PD.List:CheckPermission(officer)
    local permissionPlayer = PD.List:CheckPermission(ply)

    if permissionOfficer > permissionPlayer then
        if permissionOfficer - permissionPlayer == 1 then
            print("Du kannst diesen Spieler nicht befördern, da du nur eine Stufe über ihm bist.")
            return
        end

        local unit, sub, job = PD.List:GetPlayerData(ply)
        local newJob = nil
        local newRank = 0

        if unit == "Republic Navy" then
            for k, v in SortedPairs(PD.List.JobRanksNavy) do
                if v == permissionPlayer + 1 then
                    newJob = k
                    newRank = v
                end
            end
        else
            for k, v in SortedPairs(PD.List.JobRanks) do
                if v == permissionPlayer + 1 then
                    newJob = k
                    newRank = v
                end
            end
        end

        if newJob and newRank > 0 then
            PD.List:SetPlayerData(ply, unit, sub, newJob)
            print("Du hast "..ply:Nick().." zu "..newJob.." befördert.")

            PD.LOGS.Add("[Beförderung]", officer:Nick() .. " hat " .. ply:Nick() .. " zu " .. newJob .. " befördert.", Color(0, 255, 0))
        else
            print("Fehler bei der Beförderung.")

            PD.LOGS.Add("[Beförderung]", "Fehler bei der Beförderung von " .. ply:Nick() .. " Versuch von " .. officer:Nick(), Color(255, 0, 0))
        end
    else
        print("Du hast nicht die nötigen Rechte um diesen Spieler zu befördern.")
        
        PD.LOGS.Add("[Beförderung]", officer:Nick() .. " hat versucht " .. ply:Nick() .. " zu befördern, hat aber nicht die nötigen Rechte.", Color(255, 0, 0))
    end
end

function PD.List:RankDown(officer, ply)
    local permissionOfficer = PD.List:CheckPermission(officer)
    local permissionPlayer = PD.List:CheckPermission(ply)

    if permissionOfficer > permissionPlayer then
        if permissionPlayer == 1 then
            print("Du kannst diesen Spieler nicht weiter degradieren.")
            return
        end

        local unit, sub, job = PD.List:GetPlayerData(ply)
        local newJob = nil
        local newRank = 0

        if unit == "Republic Navy" then
            for k, v in SortedPairs(PD.List.JobRanksNavy) do
                if v == permissionPlayer - 1 then
                    newJob = k
                    newRank = v
                end
            end
        else
            for k, v in SortedPairs(PD.List.JobRanks) do
                if v == permissionPlayer - 1 then
                    newJob = k
                    newRank = v
                end
            end
        end

        if newJob and newRank > 0 then
            PD.List:SetPlayerData(ply, unit, sub, newJob)
            print("Du hast "..ply:Nick().." zu "..newJob.." degradiert.")

            PD.LOGS.Add("[Degradierung]", officer:Nick() .. " hat " .. ply:Nick() .. " zu " .. newJob .. " degradiert.", Color(255, 165, 0))
        else
            print("Fehler bei der Degradierung.")

            PD.LOGS.Add("[Degradierung]", "Fehler bei der Degradierung von " .. ply:Nick() .. " Versuch von " .. officer:Nick(), Color(255, 0, 0))
        end
    else
        print("Du hast nicht die nötigen Rechte um diesen Spieler zu degradieren.")
        
        PD.LOGS.Add("[Degradierung]", officer:Nick() .. " hat versucht " .. ply:Nick() .. " zu degradieren, hat aber nicht die nötigen Rechte.", Color(255, 0, 0))
    end
end

function PD.List:KickPlayer(officer, ply)
    local permissionOfficer = PD.List:CheckPermission(officer)
    local permissionPlayer = PD.List:CheckPermission(ply)

    if permissionOfficer > permissionPlayer then
        PD.List:SetDefault(ply)
        ply:Respawn()
        print("Du hast "..ply:Nick().." aus der Einheit entfernt.")

        PD.LOGS.Add("[Entfernung]", officer:Nick() .. " hat " .. ply:Nick() .. " aus der Einheit entfernt.", Color(255, 0, 0))
    else
        print("Du hast nicht die nötigen Rechte um diesen Spieler zu entfernen.")

        PD.LOGS.Add("[Entfernung]", officer:Nick() .. " hat versucht " .. ply:Nick() .. " aus der Einheit zu entfernen, hat aber nicht die nötigen Rechte.", Color(255, 0, 0))
    end
end

function PD.List:InvitePlayer(officer, ply)
    local permissionOfficer = PD.List:CheckPermission(officer)

    if permissionOfficer >= 9 then
        local unit, sub, job = PD.List:GetPlayerData(officer)
        local unit2, sub2, job2 = PD.List:GetPlayerData(ply)

        if unit2 == unit then
            print("Der Spieler ist bereits in der Einheit.")
            return
        end

        PD.List:SetPlayerData(ply, unit, sub, "Private")
        ply:Respawn()
        print("Du hast "..ply:Nick().." in die Einheit aufgenommen.")

        PD.LOGS.Add("[Aufnahme]", officer:Nick() .. " hat " .. ply:Nick() .. " in die Einheit aufgenommen.", Color(0, 255, 0))
    else
        print("Du hast nicht die nötigen Rechte um diesen Spieler in die Einheit aufzunehmen." .. permissionOfficer)

        PD.LOGS.Add("[Aufnahme]", officer:Nick() .. " hat versucht " .. ply:Nick() .. " in die Einheit aufzunehmen, hat aber nicht die nötigen Rechte.", Color(255, 0, 0))
    end
end

net.Receive("PD.List.Invite", function(len, ply)
    local ply2 = net.ReadEntity()
    PD.List:InvitePlayer(ply, ply2)
end)

net.Receive("PD.List.Kick", function(len, ply)
    local ply2 = net.ReadEntity()
    PD.List:KickPlayer(ply, ply2)
end)

net.Receive("PD.List.RankUp", function(len, ply)
    local ply2 = net.ReadEntity()
    PD.List:RankUP(ply, ply2)
end)

net.Receive("PD.List.RankDown", function(len, ply)
    local ply2 = net.ReadEntity()
    PD.List:RankDown(ply, ply2)
end)

net.Receive("PD.List.RequestData", function(len, ply)
    PD.List:SendDataToAllClient()
end)

net.Receive("PD.List.AdminChange", function(len, ply)
    if ply:IsAdmin() then
        local steamid = net.ReadString()
        local charID = net.ReadString()
        local unit = net.ReadString()
        local subunit = net.ReadString()
        local job = net.ReadString()

        local tbl = PD.Char:LoadChar(steamid, "PD.List.AdminChange")

        for k, v in pairs(tbl) do
            if v.id == charID then
                tbl[k].faction.unit = unit
                tbl[k].faction.subunit = subunit
                tbl[k].faction.job = job

                PD.Char:SaveChar(steamid, tbl)

                local player = FindPlayerbyID(steamid)
                if player and IsValid(player) then
                    PD.List:SendDataToAllClient()
                end

                local jobTable = {}
                local _, sub = PD.JOBS.GetSubUnit(subunit, false)
                jobTable = sub.jobs[job] or {}

                hook.Run("PD_Faction_Change", player, unit, subunit, job, jobTable)

                print("Du hast die Fraktion von "..steamid.." geändert.")

                PD.LOGS.Add("[Fraktionsänderung]", ply:Nick() .. " hat die Fraktion von " .. steamid .. " geändert.", Color(0, 255, 0))
                break
            end
        end
    else
        print(ply:Nick() .. " hat versucht die Fraktion eines Spielers zu ändern, hat aber keine Admin Rechte.")

        PD.LOGS.Add("[Fraktionsänderung]", ply:Nick() .. " hat versucht die Fraktion eines Spielers zu ändern, hat aber keine Admin Rechte.", Color(255, 0, 0))
    end
end)
