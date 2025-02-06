--

function PD.CheckSubUnitAccess(ply, subunit)
    local jobID, jobTable = ply:GetJob()
    if jobTable.unit == subunit then
        return true
    end
    return false
end

function PD.CheckJobAccess(ply, jobID)
    local jobID, jobTable = ply:GetJob()
    if jobID == jobID then
        return true
    end
    return false
end

function PD.CheckUnitAccess(ply, unit)
    local jobID, jobTable = ply:GetJob()
    local subunitID, subunitTable = PD.JOBS.GetSubUnit(unit)
    if subunitTable.unit == unit then
        return true
    end
    return false
end