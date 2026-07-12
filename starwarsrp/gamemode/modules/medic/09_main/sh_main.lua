PD.DM = PD.DM or {}
PD.DM.Main = PD.DM.Main or {}

function PD.DM.IsMedic(ply)
    local job_id, job_tbl = ply:GetJob()
    local subunit_id, subunit_tbl = PD.JOBS.GetSubUnit(job_tbl.unit, false)
    if subunit_tbl.ismedic or job_tbl.ismedic then
        return true
    end

    return false
end
