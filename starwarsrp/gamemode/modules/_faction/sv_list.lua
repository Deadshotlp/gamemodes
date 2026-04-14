PD.List = PD.List or {}

util.AddNetworkString("PD.List.Sync")
util.AddNetworkString("PD.List.SetPlayerFaction")
util.AddNetworkString("PD.List.kick")
util.AddNetworkString("PD.List.ChangeUnit")

net.Receive("PD.List.Sync", function(_, ply)
    if not IsValid(ply) then return end

    PD.List:LoadFactions()
    PD.List:Sync(ply)
end)

net.Receive("PD.List.SetPlayerFaction", function(_, ply)
    local target = net.ReadEntity()
    local unit = net.ReadString()
    local subunit = net.ReadString()
    local job = net.ReadString()

    if not IsValid(ply) or not ply:IsAdmin() then return end
    if not IsValid(target) then return end

    PD.List:SetPlayerFaction(target, unit, subunit, job)
end)

net.Receive("PD.List.ChangeUnit", function(_, ply)
    local targetCharID = net.ReadString()
    local jobName = net.ReadString()

    if not IsValid(ply) or not ply:IsAdmin() then return end
    if not targetCharID or targetCharID == "" then return end

    local target = FindPlayerbyCharID(targetCharID)
    if not IsValid(target) then return end

    local jobID, jobTable = PD.JOBS.GetJob(jobName)
    if not jobID or not jobTable then return end

    local unitIndex, subIndex = nil, nil

    for possibleUnitIndex, unitData in pairs(PD.JOBS.Jobs or {}) do
        for possibleSubIndex, subData in pairs(unitData.subunits or {}) do
            for possibleJobIndex in pairs(subData.jobs or {}) do
                if possibleJobIndex == jobID then
                    unitIndex = possibleUnitIndex
                    subIndex = possibleSubIndex
                    break
                end
            end

            if unitIndex and subIndex then break end
        end

        if unitIndex and subIndex then break end
    end

    if not unitIndex or not subIndex then return end

    PD.List:ChangeFaction(target, unitIndex, subIndex, jobID)
end)

net.Receive("PD.List.kick", function(_, ply)
    local targetCharID = net.ReadString()

    if not IsValid(ply) then return end
    if not targetCharID or targetCharID == "" then return end

    local target = FindPlayerbyCharID(targetCharID)
    if not IsValid(target) then return end

    local unit, subunit, job = PD.List:GetPlayerFaction(target)
    if not unit or not subunit or not job then return end
    if not PD.List:CheckPermissionLevel(ply, unit, subunit, job) then return end

    PD.List:RemoveFactionByCharID(targetCharID, true, target)
end)

hook.Add("PlayerInitialSpawn", "PD.List.PlayerInitialSpawn.Core", function(ply)
    timer.Simple(0.2, function()
        if not IsValid(ply) then return end
        PD.List:Sync(ply)
    end)
end)

hook.Add("PD_Faction_Change", "PD.List.SyncOnFactionChange", function()
    PD.List:SyncAll()
end)

hook.Add("PlayerSay", "PD.List.ChatCommandFaction", function(ply, text)
    if string.sub(text or "", 1, 8) ~= "!faction" then return end

    local unit, subunit, job = PD.List:GetPlayerFaction(ply)
    if not unit or not subunit or not job then return end

    if PD.Notify then
        PD.Notify("Du bist in der Fraktion: " .. tostring(unit) .. " " .. tostring(subunit) .. " " .. tostring(job), Color(255, 0, 0), false, ply)
    end
end)

hook.Add("PlayerDeleteCharacter", "PD.List.PlayerDeleteCharacter.Core", function(_, charTbl)
    if not charTbl or not charTbl.id then return end
    PD.List:RemoveFactionByCharID(charTbl.id, false)
end)