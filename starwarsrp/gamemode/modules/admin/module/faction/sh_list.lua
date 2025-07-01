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

