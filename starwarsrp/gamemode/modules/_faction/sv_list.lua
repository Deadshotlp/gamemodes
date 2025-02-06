PD.List = PD.List or {}

util.AddNetworkString("PD.List.Sync")
util.AddNetworkString("PD.List.SetPlayerFaction")
util.AddNetworkString("PD.List.RankUp")
util.AddNetworkString("PD.List.RankDown")
util.AddNetworkString("PD.List.kick")
util.AddNetworkString("PD.List.ChangeUnit")

net.Receive("PD.List.Sync", function(len, ply)
    PD.List:LoadFactions()

    net.Start("PD.List.Sync")
        net.WriteTable(PD.List.Tbl)
    net.Send(ply)

    print("Factions loaded for "..ply:Nick())
end)

net.Receive("PD.List.SetPlayerFaction", function(len, ply)
    local player = net.ReadEntity()
    local unit = net.ReadString()
    local subunit = net.ReadString()
    local job = net.ReadString()

    if not ply:IsAdmin() then return end
    if not player or not unit or not subunit or not job then return end

    PD.List:SetPlayerFaction(player, unit, subunit, job)
end)

net.Receive("PD.List.ChangeUnit", function(len, ply)
    local playerbycharID = FindPlayerbyCharID(net.ReadString())
    local job = net.ReadString()

    local jobID, jobTable = PD.JOBS.GetJob(job)

    if not ply:IsAdmin() then return end
    if not playerbycharID or not jobTable.unit or not jobTable.subunit or not jobTable then return end

    PD.Notify("Du hast den Job von "..playerbycharID:Nick().." zu "..jobTable.unit.." "..jobTable.subunit.." "..jobID.." geändert!", Color(255, 0, 0), false, ply)

    PD.List:ChangeFaction(playerbycharID, jobTable.unit, jobTable.subunit, jobID)
end)

net.Receive("PD.List.RankUp", function(len, ply)
    local playerbycharID = FindPlayerbyCharID(net.ReadString())
    local unit, subunit, job = PD.List:GetPlayerFaction(ply)

    if not PD.List:CheckPermissionLevel(ply, unit, subunit, job) or ply:IsAdmin() then return end
    if not playerbycharID or not unit or not subunit or not job then return end

    PD.List:RankUp(player, unit, subunit, job)
end)

net.Receive("PD.List.RankDown", function(len, ply)
    local playerbycharID = FindPlayerbyCharID(net.ReadString())
    local unit, subunit, job = PD.List:GetPlayerFaction(ply)

    if not PD.List:CheckPermissionLevel(ply, unit, subunit, job) or ply:IsAdmin() then return end
    if not playerbycharID or not unit or not subunit or not job then return end

    PD.List:RankDown(player, unit, subunit, job)
end)

net.Receive("PD.List.kick", function(len, ply)
    local playerbycharID = FindPlayerbyCharID(net.ReadString())
    local unit, subunit, job = PD.List:GetPlayerFaction(ply)

    if not PD.List:CheckPermissionLevel(ply, unit, subunit, job) or ply:IsAdmin() then return end
    if not playerbycharID or not unit or not subunit or not job then return end

    PD.List:RemovePlayerFaction(playerbycharID)
end)

hook.Add("ShutDown", "PD.List.ShutDown", function()
    PD.List.Save()
end)

hook.Add("PlayerDisconnected", "PD.List.PlayerDisconnected", function(ply)
    -- PD.List:StopTimer(ply:SteamID64())

    PD.List.Save()
end)

hook.Add("PlayerInitialSpawn", "PD.List.PlayerInitialSpawn", function(ply)
    net.Start("PD.List.Sync")
        net.WriteTable(PD.List.Tbl)
    net.Send(ply)
end)

hook.Add("PlayerSpawn", "PD.List.PlayerSpawn", function(ply)
    -- local factionName, subfactionName, jobName = PD.List:GetPlayerFaction(ply)

    -- if factionName then
    --     PD.List:ChangeFaction(ply, factionName, subfactionName, jobName)
    -- end
end)

hook.Add("PD_Faction_Change", "PD.List.PD_Faction_Change", function()
    net.Start("PD.List.Sync")
        net.WriteTable(PD.List.Tbl)
    net.Broadcast()
end)

-- hook.Add("PD.JOBS.Created", "PD.List.UpdateCreatedJobs", function(id, tbl)
--     PD.List:LoadFactions()

--     net.Start("PD.List.Sync")
--         net.WriteTable(PD.List.Tbl)
--     net.Broadcast()
-- end)

-- hook.Add("PD.JOBS.Removed", "PD.List.UpdeteremovedJobs", function(id, tbl)
--     PD.List:LoadFactions()

--     net.Start("PD.List.Sync")
--         net.WriteTable(PD.List.Tbl)
--     net.Broadcast()
-- end)

hook.Add("PlayerDeleteCharacter", "PD.List.PlayerDeleteCharacter", function(ply, charTbl)
    local playerbycharID = FindPlayerbyCharID(charTbl.id)

    if playerbycharID then
        PD.List:RemovePlayerFaction(playerbycharID)
    end
end)

