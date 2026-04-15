util.AddNetworkString("PD.JOBS.job_reorder")
util.AddNetworkString("PD.JOBS.Admin")
util.AddNetworkString("PD.JOBS.unit_update")
util.AddNetworkString("PD.JOBS.unit_delete")
util.AddNetworkString("PD.JOBS.subunit_update")
util.AddNetworkString("PD.JOBS.subunit_delete")
util.AddNetworkString("PD.JOBS.job_update")
util.AddNetworkString("PD.JOBS.job_delete")

local function CheckIndex()
    local tbl = PD.JOBS.Jobs
    local highest = 0

    local function collect(t)
        for k, v in pairs(t or {}) do
            if isstring(k) then
                local num = tonumber(string.match(k, "^JOB_(%d+)$"))
                if num and num > highest then
                    highest = num
                end
            end

            if istable(v) then
                if istable(v.subunits) then
                    collect(v.subunits)
                end

                if istable(v.jobs) then
                    collect(v.jobs)
                end
            end
        end
    end

    collect(tbl)

    return "JOB_" .. (highest + 1)
end

local function GetNextJobPosition(subunitTbl)
    local highest = 0

    for _, job in pairs((subunitTbl and subunitTbl.jobs) or {}) do
        local pos = tonumber(job.position) or 0
        if pos > highest then
            highest = pos
        end
    end

    return highest + 1
end

local function NormalizeJobPositions(subunitTbl)
    local jobs = {}

    for k, v in pairs((subunitTbl and subunitTbl.jobs) or {}) do
        table.insert(jobs, {
            index = k,
            data = v
        })
    end

    table.sort(jobs, function(a, b)
        local aPos = tonumber(a.data.position) or 999999
        local bPos = tonumber(b.data.position) or 999999

        if aPos == bPos then
            return tostring(a.index) < tostring(b.index)
        end

        return aPos < bPos
    end)

    for i, entry in ipairs(jobs) do
        entry.data.position = i
    end
end

net.Receive("PD.JOBS.Admin", function(len, ply)
    local typ = net.ReadString()
    local Table = net.ReadTable()

    if not IsValid(ply) or not ply:IsAdmin() then return end

    PD.JOBS.LoadJobs()

    local allJobs = PD.JOBS.Jobs

    if typ == "unit" then
        local index = Table.index or CheckIndex()

        PD.JOBS.Jobs[index] = {
            name = Table.name,
            default = false,
            color = Table.color or Color(255, 255, 255),
            equip = Table.equip or {},
            subunits = allJobs[index] and allJobs[index].subunits or {}
        }

        PD.Notify("Unit " .. Table.name .. " wurde erstellt!", Color(255, 0, 0), false, ply)
        PD.LOGS.Add("jobs", "Unit " .. Table.name .. " wurde erstellt!", Color(255, 0, 0))
    elseif typ == "subunit" then
        local unitIndex = Table.unitIndex

        if not unitIndex or not allJobs[unitIndex] then
            print("Unit index does not exist!")
            return
        end

        local index = Table.index or CheckIndex()

        PD.JOBS.Jobs[unitIndex].subunits = PD.JOBS.Jobs[unitIndex].subunits or {}
        PD.JOBS.Jobs[unitIndex].subunits[index] = {
            name = Table.name,
            maxmembers = Table.maxmembers or 10,
            default = false,
            equip = Table.equip or {},
            color = Table.color or Color(255, 255, 255),
            unit = allJobs[unitIndex].name,
            ismedic = Table.ismedic or false,
            isleo = Table.isleo or false,
            isengineer = Table.isengineer or false,
            jobs = {}
        }

        PD.Notify("Subunit " .. Table.name .. " wurde erstellt!", Color(255, 0, 0), false, ply)
        PD.LOGS.Add("jobs", "Subunit " .. Table.name .. " wurde erstellt!", Color(255, 0, 0))
    elseif typ == "job" then
        local unitIndex = Table.unitIndex
        local subIndex = Table.subIndex

        if not unitIndex or not subIndex then
            print("Missing unit/subunit index!")
            return
        end

        if not allJobs[unitIndex] or not allJobs[unitIndex].subunits or not allJobs[unitIndex].subunits[subIndex] then
            print("Subunit index does not exist!")
            return
        end

        local subunit = allJobs[unitIndex].subunits[subIndex]
        local jobIndex = Table.index or GetNextJobIndex(subunit)

        PD.JOBS.Jobs[unitIndex].subunits[subIndex].jobs = PD.JOBS.Jobs[unitIndex].subunits[subIndex].jobs or {}
        PD.JOBS.Jobs[unitIndex].subunits[subIndex].jobs[jobIndex] = {
            name = Table.name,
            color = Table.color or Color(255, 255, 255),
            model = Table.model or { "models/player/skeleton.mdl" },
            equip = Table.equip or {},
            default = false,
            unit = subunit.name,
            salary = Table.salary or 100,
            speed = Table.speed or 100,
            id = jobIndex,
            isleo = Table.isleo or false,
            ismedic = Table.ismedic or false,
            isengineer = Table.isengineer or false,
            showid = Table.showid or false,
            position = GetNextJobPosition(subunit)
        }

        NormalizeJobPositions(PD.JOBS.Jobs[unitIndex].subunits[subIndex])

        PD.Notify("Job " .. Table.name .. " wurde erstellt!", Color(255, 0, 0), false, ply)
        PD.LOGS.Add("jobs", "Job " .. Table.name .. " wurde erstellt!", Color(255, 0, 0))
    end

    PD.JOBS.SaveJobs()
    PD.JOBS.UpdateTabel()
end)

net.Receive("PD.JOBS.unit_update", function(len, ply)
    local Table = net.ReadTable()

    if not IsValid(ply) or not ply:IsAdmin() then return end

    PD.JOBS.LoadJobs()

    local allJobs = PD.JOBS.Jobs
    local unit = allJobs[Table.index]

    if not unit then
        print("Unit index does not exist!")
        return
    end

    unit.name = Table.name or unit.name
    unit.color = Table.color or unit.color

    for _, subunit in pairs(unit.subunits or {}) do
        subunit.unit = unit.name
    end

    PD.Notify("Unit wurde aktualisiert!", Color(255, 0, 0), false, ply)
    PD.LOGS.Add("jobs", "Unit " .. Table.index .. " wurde aktualisiert!", Color(255, 0, 0))

    PD.JOBS.SaveJobs()
    PD.JOBS.UpdateTabel()
end)

net.Receive("PD.JOBS.unit_delete", function(len, ply)
    local Table = net.ReadTable()

    if not IsValid(ply) or not ply:IsAdmin() then return end

    PD.JOBS.LoadJobs()

    if PD.JOBS.Jobs[Table.index] then
        PD.JOBS.Jobs[Table.index] = nil

        PD.Notify("Unit wurde gelöscht!", Color(255, 0, 0), false, ply)
        PD.LOGS.Add("jobs", "Unit " .. Table.index .. " wurde gelöscht!", Color(255, 0, 0))
    else
        print("Unit index does not exist!")
        return
    end

    PD.JOBS.SaveJobs()
    PD.JOBS.UpdateTabel()
end)

net.Receive("PD.JOBS.subunit_update", function(len, ply)
    local Table = net.ReadTable()

    if not IsValid(ply) or not ply:IsAdmin() then return end

    PD.JOBS.LoadJobs()

    local allJobs = PD.JOBS.Jobs
    local oldUnitIndex = Table.oldUnitIndex or Table.unitIndex
    local newUnitIndex = Table.unitIndex or oldUnitIndex

    if not allJobs[oldUnitIndex] or not allJobs[oldUnitIndex].subunits or not allJobs[oldUnitIndex].subunits[Table.index] then
        print("Old subunit index does not exist!")
        return
    end

    if not allJobs[newUnitIndex] then
        print("Target unit index does not exist!")
        return
    end

    local oldSubunit = allJobs[oldUnitIndex].subunits[Table.index]

    allJobs[oldUnitIndex].subunits[Table.index] = nil
    allJobs[newUnitIndex].subunits = allJobs[newUnitIndex].subunits or {}

    oldSubunit.name = Table.name or oldSubunit.name
    oldSubunit.maxmembers = Table.maxmembers or oldSubunit.maxmembers or 10
    oldSubunit.equip = Table.equip or oldSubunit.equip or {}
    oldSubunit.color = Table.color or oldSubunit.color or Color(255, 255, 255)
    oldSubunit.unit = allJobs[newUnitIndex].name
    oldSubunit.ismedic = Table.ismedic or false
    oldSubunit.isleo = Table.isleo or false
    oldSubunit.isengineer = Table.isengineer or false
    oldSubunit.jobs = oldSubunit.jobs or {}

    for _, job in pairs(oldSubunit.jobs) do
        job.unit = oldSubunit.name
        job.id = string.lower(oldSubunit.name or "subunit") .. "_" .. string.lower(job.name or "job")
    end

    allJobs[newUnitIndex].subunits[Table.index] = oldSubunit

    PD.Notify("Subunit wurde aktualisiert!", Color(255, 0, 0), false, ply)
    PD.LOGS.Add("jobs", "Subunit " .. Table.index .. " wurde aktualisiert!", Color(255, 0, 0))

    PD.JOBS.SaveJobs()
    PD.JOBS.UpdateTabel()
end)

net.Receive("PD.JOBS.subunit_delete", function(len, ply)
    local Table = net.ReadTable()

    if not IsValid(ply) or not ply:IsAdmin() then return end

    PD.JOBS.LoadJobs()

    local allJobs = PD.JOBS.Jobs

    if not allJobs[Table.unitIndex] then
        print("Unit index does not exist!")
        return
    end

    if allJobs[Table.unitIndex].subunits and allJobs[Table.unitIndex].subunits[Table.index] then
        allJobs[Table.unitIndex].subunits[Table.index] = nil

        PD.Notify("Subunit wurde gelöscht!", Color(255, 0, 0), false, ply)
        PD.LOGS.Add("jobs", "Subunit " .. Table.index .. " wurde gelöscht!", Color(255, 0, 0))
    else
        print("Subunit index does not exist!")
        return
    end

    PD.JOBS.SaveJobs()
    PD.JOBS.UpdateTabel()
end)

net.Receive("PD.JOBS.job_update", function(len, ply)
    local Table = net.ReadTable()

    if not IsValid(ply) or not ply:IsAdmin() then return end

    PD.JOBS.LoadJobs()

    local allJobs = PD.JOBS.Jobs
    local oldUnitIndex = Table.unitIndex
    local oldSubIndex = Table.subIndex
    local newUnitIndex = Table.newUnitIndex or oldUnitIndex
    local newSubIndex = Table.newSubIndex or oldSubIndex

    if not allJobs[oldUnitIndex] or not allJobs[oldUnitIndex].subunits or not allJobs[oldUnitIndex].subunits[oldSubIndex] then
        print("Old subunit index does not exist!")
        return
    end

    if not allJobs[oldUnitIndex].subunits[oldSubIndex].jobs or not allJobs[oldUnitIndex].subunits[oldSubIndex].jobs[Table.index] then
        print("Job index does not exist!")
        return
    end

    if not allJobs[newUnitIndex] or not allJobs[newUnitIndex].subunits or not allJobs[newUnitIndex].subunits[newSubIndex] then
        print("Target subunit index does not exist!")
        return
    end

    local oldJob = allJobs[oldUnitIndex].subunits[oldSubIndex].jobs[Table.index]
    local oldPosition = tonumber(oldJob.position) or 1
    local targetSub = allJobs[newUnitIndex].subunits[newSubIndex]
    local targetIndex = Table.index

    if oldUnitIndex ~= newUnitIndex or oldSubIndex ~= newSubIndex then
        targetIndex = GetNextJobIndex(targetSub)
    end

    allJobs[oldUnitIndex].subunits[oldSubIndex].jobs[Table.index] = nil
    targetSub.jobs = targetSub.jobs or {}

    oldJob.name = Table.name or oldJob.name
    oldJob.color = Table.color or oldJob.color or Color(255, 255, 255)
    oldJob.model = Table.model or oldJob.model or { "models/player/skeleton.mdl" }
    oldJob.equip = Table.equip or oldJob.equip or {}
    oldJob.salary = Table.salary or oldJob.salary or 100
    oldJob.speed = Table.speed or oldJob.speed or 100
    oldJob.unit = targetSub.name
    oldJob.id = targetIndex
    oldJob.isleo = Table.isleo or false
    oldJob.ismedic = Table.ismedic or false
    oldJob.isengineer = Table.isengineer or false
    oldJob.showid = Table.showid or false


    if oldUnitIndex ~= newUnitIndex or oldSubIndex ~= newSubIndex then
        oldJob.position = GetNextJobPosition(targetSub)
    else
        oldJob.position = oldPosition
    end

    targetSub.jobs[targetIndex] = oldJob

    NormalizeJobPositions(allJobs[oldUnitIndex].subunits[oldSubIndex])
    NormalizeJobPositions(targetSub)

    PD.Notify("Job wurde aktualisiert!", Color(255, 0, 0), false, ply)
    PD.LOGS.Add("jobs", "Job " .. Table.index .. " wurde aktualisiert!", Color(255, 0, 0))

    PD.JOBS.SaveJobs()
    PD.JOBS.UpdateTabel()
end)

net.Receive("PD.JOBS.job_delete", function(len, ply)
    local Table = net.ReadTable()

    if not IsValid(ply) or not ply:IsAdmin() then return end

    PD.JOBS.LoadJobs()

    local allJobs = PD.JOBS.Jobs

    if not allJobs[Table.unitIndex] or not allJobs[Table.unitIndex].subunits or not allJobs[Table.unitIndex].subunits[Table.subIndex] then
        print("Subunit index does not exist!")
        return
    end

    if allJobs[Table.unitIndex].subunits[Table.subIndex].jobs and allJobs[Table.unitIndex].subunits[Table.subIndex].jobs[Table.index] then
        allJobs[Table.unitIndex].subunits[Table.subIndex].jobs[Table.index] = nil

        PD.Notify("Job wurde gelöscht!", Color(255, 0, 0), false, ply)
        PD.LOGS.Add("jobs", "Job " .. Table.index .. " wurde gelöscht!", Color(255, 0, 0))
    else
        print("Job index does not exist!")
        return
    end

    PD.JOBS.SaveJobs()
    PD.JOBS.UpdateTabel()
end)

net.Receive("PD.JOBS.job_reorder", function(len, ply)
    local Table = net.ReadTable()

    if not IsValid(ply) or not ply:IsAdmin() then return end

    PD.JOBS.LoadJobs()

    local unitIndex = Table.unitIndex
    local subIndex = Table.subIndex
    local order = Table.order or {}

    if not PD.JOBS.Jobs[unitIndex] or not PD.JOBS.Jobs[unitIndex].subunits or not PD.JOBS.Jobs[unitIndex].subunits[subIndex] then
        print("Subunit index does not exist!")
        return
    end

    local subunit = PD.JOBS.Jobs[unitIndex].subunits[subIndex]
    local jobs = subunit.jobs or {}
    local used = {}
    local pos = 1

    for _, jobIndex in ipairs(order) do
        if jobs[jobIndex] and not used[jobIndex] then
            jobs[jobIndex].position = pos
            used[jobIndex] = true
            pos = pos + 1
        end
    end

    local rest = {}
    for jobIndex, jobData in pairs(jobs) do
        if not used[jobIndex] then
            table.insert(rest, {
                index = jobIndex,
                data = jobData
            })
        end
    end

    table.sort(rest, function(a, b)
        local aPos = tonumber(a.data.position) or 999999
        local bPos = tonumber(b.data.position) or 999999

        if aPos == bPos then
            return tostring(a.index) < tostring(b.index)
        end

        return aPos < bPos
    end)

    for _, entry in ipairs(rest) do
        jobs[entry.index].position = pos
        pos = pos + 1
    end

    NormalizeJobPositions(subunit)

    PD.JOBS.SaveJobs()
    PD.JOBS.UpdateTabel()
end)

