PD.List = PD.List or {}

PD.List.OpenKey = KEY_F4

function FindJobIDByName(jobName)
    for jobID, jobData in pairs(PD.JOBS.GetJob()) do
        if jobData.name == jobName then
            return jobID
        end
    end
    return nil
end

function FindJobNameByID(jobID)
    if PD.JOBS.GetJob()[jobID] then
        return PD.JOBS.GetJob()[jobID].name
    end
    return nil
end

function FindPlayerbyID(id)
    for k, v in pairs(player.GetAll()) do
        if v:SteamID64() == id then
            return v
        end
    end
    return nil
end

function FindPlayerbyCharID(id)
    for k, v in pairs(player.GetAll()) do
        if v:GetCharacterID() == id then
            return v
        end
    end
    return nil
end

function FindPlayerCharbyName(name,tbl)
    for k,v in pairs(tbl) do
        if v.name == name then
            return k
        end
    end

    -- print(name)
    -- PrintTable(tbl)

    return nil
end

PD.List.Permission = {
    ""
}

PD.List.JobRanks = {
    ["Major"] = 12,
    ["Captain"] = 11,
    ["1st Lieutenant"] = 10,
    ["2nd Lieutenant"] = 9,
    ["Master Sergeant"] = 8,
    ["Staff Sergeant"] = 7,
    ["Sergeant"] = 6,
    ["Corporal"] = 5,
    ["Lance Corporal"] = 4,
    ["Specialist"] = 3,
    ["Private First Class"] = 2,
    ["Private"] = 1
}

PD.List.JobRanksNavy = {
    ["Commodore"] = 12,
    ["Captain"] = 11,
    ["Lt. Commander"] = 10,
    ["Jr. Lieutenant"] = 9,
    ["Ensign"] = 8,
    ["Chief Warrant Officer"] = 7,
    ["Warrant Officer"] = 6,
    ["Master Chief Petty Officer"] = 5,
    ["Chief Petty Officer"] = 4,
    ["Petty Officer First Class"] = 3,
    ["Petty Officer"] = 2,
    ["Crewman"] = 1
}

function PD.GetRankPermission(minrank, plyrank)
    local rank = false
    if PD.List.JobRanks[minrank] and PD.List.JobRanks[plyrank] then
        rank = PD.List.JobRanks[plyrank] >= PD.List.JobRanks[minrank] and 1 or 0
    elseif PD.List.JobRanksNavy[minrank] and PD.List.JobRanksNavy[plyrank] then
        rank = PD.List.JobRanksNavy[plyrank] >= PD.List.JobRanksNavy[minrank] and 1 or 0
    end

    return rank
end