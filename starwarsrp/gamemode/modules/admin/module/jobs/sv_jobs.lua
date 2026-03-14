-- Jobs System by Deadshot

PD.JOBS = PD.JOBS or {}

util.AddNetworkString("PD.JOBS.Admin")
util.AddNetworkString("PD.JOBS.job_update")
util.AddNetworkString("PD.JOBS.job_delete")
util.AddNetworkString("PD.JOBS.unit_update")
util.AddNetworkString("PD.JOBS.unit_delete")
util.AddNetworkString("PD.JOBS.subunit_update")
util.AddNetworkString("PD.JOBS.subunit_delete")

net.Receive("PD.JOBS.Admin", function(len, ply)
    local typ = net.ReadString()
    local Table = net.ReadTable()
 
    if not IsValid(ply) or not ply:IsAdmin() then return end

    PD.JOBS.LoadJobs()

    local allJobs = PD.JOBS.Jobs

    if typ == "unit" then
        if allJobs[Table.name] then
            PD.JOBS.Jobs[Table.name] = Table

            PD.Notify("Unit " .. Table.name .. " wurde aktualisiert!", Color(255, 0, 0), false, ply)
            PD.LOGS.Add("jobs", "Unit " .. Table.name .. " wurde aktualisiert!", Color(255, 0, 0))
        else
            PD.JOBS.Jobs[Table.name] = {
                default = false,
                color = Table.color or Color(255, 255, 255),
                subunits = {}
            }

            PD.Notify("Unit " .. Table.name .. " wurde erstellt!", Color(255, 0, 0), false, ply)
            PD.LOGS.Add("jobs", "Unit " .. Table.name .. " wurde erstellt!", Color(255, 0, 0))
        end
    elseif typ == "subunit" then
        local unitName = Table.unit or "Fallback Unit!"
        if not allJobs[unitName] then
            print("Unit " .. unitName .. " does not exist!")
            return
        end

        if allJobs[unitName].subunits[Table.name] then
            PD.JOBS.Jobs[unitName].subunits[Table.name] = Table

            PD.Notify("Subunit " .. Table.name .. " in Unit " .. unitName .. " wurde aktualisiert!", Color(255, 0, 0), false, ply)
            PD.LOGS.Add("jobs", "Subunit " .. Table.name .. " in Unit " .. unitName .. " wurde aktualisiert!", Color(255, 0, 0))
        else
            PD.JOBS.Jobs[unitName].subunits[Table.name] = {
                maxmembers = Table.maxmembers or 10,
                default = false,
                equip = Table.equip or {},
                color = Table.color or Color(255, 255, 255),
                unit = unitName,
                ismedic = Table.ismedic or false,
                isleo = Table.isleo or false,
                isengineer = Table.isengineer or false,
                jobs = {}
            }

            PD.Notify("Subunit " .. Table.name .. " in Unit " .. unitName .. " wurde erstellt!", Color(255, 0, 0), false, ply)
            PD.LOGS.Add("jobs", "Subunit " .. Table.name .. " in Unit " .. unitName .. " wurde erstellt!", Color(255, 0, 0))
        end
    elseif typ == "job" then
        local subunitName = Table.subunit or "Fallback Subunit!"
        local subunitName, subunitTable = PD.JOBS.GetSubUnit(Table.subunit, false)

        local unitName = allJobs[subunitTable.unit] and subunitTable.unit or "Fallback Unit!"

        if not allJobs[unitName] or not allJobs[unitName].subunits[subunitName] then
            print("Subunit " .. subunitName .. " does not exist in unit " .. unitName)
            return
        end

        if allJobs[unitName].subunits[subunitName].jobs[Table.name] then
            PD.JOBS.Jobs[unitName].subunits[subunitName].jobs[Table.name] = Table

            PD.Notify("Job " .. Table.name .. " in Subunit " .. subunitName .. " in Unit " .. unitName .. " wurde aktualisiert!", Color(255, 0, 0), false, ply)
            PD.LOGS.Add("jobs", "Job " .. Table.name .. " in Subunit " .. subunitName .. " in Unit " .. unitName .. " wurde aktualisiert!", Color(255, 0, 0))
        else
            PD.JOBS.Jobs[unitName].subunits[subunitName].jobs[Table.name] = {
                color = Table.color or Color(255, 255, 255),
                model = Table.model or {"models/player/skeleton.mdl"},
                equip = Table.equip or {},
                default = false,
                unit = subunitName,
                salary = Table.salary or 100,
                speed = Table.speed or 100,
                id = string.lower(Table.subunit) .. "_" .. string.lower(Table.name)
            }

            PD.Notify("Job " .. Table.name .. " in Subunit " .. subunitName .. " in Unit " .. unitName .. " wurde erstellt!", Color(255, 0, 0), false, ply)
            PD.LOGS.Add("jobs", "Job " .. Table.name .. " in Subunit " .. subunitName .. " in Unit " .. unitName .. " wurde erstellt!", Color(255, 0, 0))
        end
    end

    PD.JOBS.SaveJobs()

    PD.JOBS.UpdateTabel()
end)

net.Receive("PD.JOBS.job_update", function(len, ply)
    local Table = net.ReadTable()

    if not IsValid(ply) or not ply:IsAdmin() then return end

    PD.JOBS.LoadJobs()

    local allJobs = PD.JOBS.Jobs

    local oldSubunitName, oldSubunitTable = PD.JOBS.GetSubUnit(Table.sub, false)
    local oldUnitName = allJobs[oldSubunitTable.unit] and oldSubunitTable.unit or "Fallback Unit!"

    if not allJobs[oldUnitName] or not allJobs[oldUnitName].subunits[oldSubunitName] then
        print("Subunit " .. oldSubunitName .. " does not exist in unit " .. oldUnitName)
        return
    end

    if not allJobs[oldUnitName].subunits[oldSubunitName].jobs[Table.job] then
        print("Job " .. Table.job .. " does not exist in Subunit " .. oldSubunitName .. " in Unit " .. oldUnitName)
        return
    end

    -- Hole das alte Job-Objekt
    local oldJob = allJobs[oldUnitName].subunits[oldSubunitName].jobs[Table.job]
    
    -- Berechne neue SubUnit falls geändert
    local newSubunitName, newSubunitTable = PD.JOBS.GetSubUnit(Table.subunit, false)
    local newUnitName = allJobs[newSubunitTable.unit] and newSubunitTable.unit or oldUnitName
    
    -- Prüfe ob die neue SubUnit existiert
    if not allJobs[newUnitName] or not allJobs[newUnitName].subunits[newSubunitName] then
        print("Ziel Subunit " .. newSubunitName .. " does not exist in unit " .. newUnitName)
        return
    end
    
    -- Entferne Job aus alter Position
    PD.JOBS.Jobs[oldUnitName].subunits[oldSubunitName].jobs[Table.job] = nil
    
    -- Erstelle aktualisiertes Job-Objekt
    local updatedJob = {
        color = Table.color or oldJob.color or Color(255, 255, 255),
        model = Table.model or oldJob.model or {"models/player/skeleton.mdl"},
        equip = Table.equip or oldJob.equip or {},
        default = oldJob.default or false,
        unit = newSubunitName,
        salary = Table.salary or oldJob.salary or 100,
        speed = Table.speed or oldJob.speed or 100,
        id = Table.id or (string.lower(newSubunitName) .. "_" .. string.lower(Table.name)),
        name = Table.name
    }
    
    -- Füge Job an neuer Position ein
    PD.JOBS.Jobs[newUnitName].subunits[newSubunitName].jobs[Table.name] = updatedJob

    PD.Notify("Job " .. Table.job .. " wurde aktualisiert und nach " .. Table.name .. " umbenannt!", Color(255, 0, 0), false, ply)
    PD.LOGS.Add("jobs", "Job " .. Table.job .. " in Subunit " .. oldSubunitName .. " wurde zu " .. Table.name .. " in " .. newSubunitName .. " aktualisiert!", Color(255, 0, 0))

    PD.JOBS.SaveJobs()

    PD.JOBS.UpdateTabel()
end)

net.Receive("PD.JOBS.job_delete", function(len, ply)
    local Table = net.ReadTable()

    if not IsValid(ply) or not ply:IsAdmin() then return end

    PD.JOBS.LoadJobs()

    local allJobs = PD.JOBS.Jobs

    local subunitName, subunitTable = PD.JOBS.GetSubUnit(Table.sub, false)
    local unitName = allJobs[subunitTable.unit] and subunitTable.unit or "Fallback Unit!"

    if not allJobs[unitName] or not allJobs[unitName].subunits[subunitName] then
        print("Subunit " .. subunitName .. " does not exist in unit " .. unitName)
        return
    end

    if allJobs[unitName].subunits[subunitName].jobs[Table.job] then
        PD.JOBS.Jobs[unitName].subunits[subunitName].jobs[Table.job] = nil

        PD.Notify("Job " .. Table.job .. " in Subunit " .. subunitName .. " in Unit " .. unitName .. " wurde gelöscht!", Color(255, 0, 0), false, ply)
        PD.LOGS.Add("jobs", "Job " .. Table.job .. " in Subunit " .. subunitName .. " in Unit " .. unitName .. " wurde gelöscht!", Color(255, 0, 0))
    else
        print("Job " .. Table.job .. " does not exist in Subunit " .. subunitName .. " in Unit " .. unitName)
        return
    end

    PD.JOBS.SaveJobs()

    PD.JOBS.UpdateTabel()
end)

net.Receive("PD.JOBS.unit_update", function(len, ply)
    local Table = net.ReadTable()

    if not IsValid(ply) or not ply:IsAdmin() then return end

    PD.JOBS.LoadJobs()

    local allJobs = PD.JOBS.Jobs

    if not allJobs[Table.old] then
        print("Unit " .. Table.old .. " does not exist!")
        return
    end
    
    -- Hole alte Unit
    local oldUnit = allJobs[Table.old]
    
    -- Entferne alte Unit
    PD.JOBS.Jobs[Table.old] = nil
    
    -- Erstelle aktualisierte Unit mit allen Subunits
    PD.JOBS.Jobs[Table.new] = {
        default = oldUnit.default or false,
        color = Table.color or oldUnit.color or Color(255, 255, 255),
        subunits = oldUnit.subunits or {}
    }
    
    -- Update die 'unit' Referenz in allen Subunits
    for subunitName, subunit in pairs(PD.JOBS.Jobs[Table.new].subunits) do
        subunit.unit = Table.new
    end

    PD.Notify("Unit " .. Table.old .. " wurde zu " .. Table.new .. " umbenannt!", Color(255, 0, 0), false, ply)
    PD.LOGS.Add("jobs", "Unit " .. Table.old .. " wurde zu " .. Table.new .. " umbenannt!", Color(255, 0, 0))

    PD.JOBS.SaveJobs()

    PD.JOBS.UpdateTabel()
end)

net.Receive("PD.JOBS.unit_delete", function(len, ply)
    local Table = net.ReadTable()

    if not IsValid(ply) or not ply:IsAdmin() then return end

    PD.JOBS.LoadJobs()

    local allJobs = PD.JOBS.Jobs

    if allJobs[Table.name] then
        PD.JOBS.Jobs[Table.name] = nil

        PD.Notify("Unit " .. Table.name .. " wurde gelöscht!", Color(255, 0, 0), false, ply)
        PD.LOGS.Add("jobs", "Unit " .. Table.name .. " wurde gelöscht!", Color(255, 0, 0))
    else
        print("Unit " .. Table.name .. " does not exist!")
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

    local unitName = Table.unit or "Fallback Unit!"

    if not allJobs[unitName] then
        print("Unit " .. unitName .. " does not exist!")
        return
    end

    if not allJobs[unitName].subunits[Table.old] then
        print("Subunit " .. Table.old .. " does not exist in unit " .. unitName)
        return
    end
    
    -- Hole alte Subunit
    local oldSubunit = allJobs[unitName].subunits[Table.old]
    
    -- Entferne alte Subunit
    PD.JOBS.Jobs[unitName].subunits[Table.old] = nil
    
    -- Erstelle aktualisierte Subunit mit allen Jobs
    PD.JOBS.Jobs[unitName].subunits[Table.new] = {
        maxmembers = Table.maxmembers or oldSubunit.maxmembers or 10,
        default = oldSubunit.default or false,
        equip = Table.equip or oldSubunit.equip or {},
        color = Table.color or oldSubunit.color or Color(255, 255, 255),
        unit = unitName,
        ismedic = Table.ismedic or oldSubunit.ismedic or false,
        isleo = Table.isleo or oldSubunit.isleo or false,
        isengineer = Table.isengineer or oldSubunit.isengineer or false,
        jobs = oldSubunit.jobs or {}
    }
    
    -- Update die 'unit' Referenz in allen Jobs
    for jobName, job in pairs(PD.JOBS.Jobs[unitName].subunits[Table.new].jobs) do
        job.unit = Table.new
    end

    PD.Notify("Subunit " .. Table.old .. " in Unit " .. unitName .. " wurde zu " .. Table.new .. " umbenannt!", Color(255, 0, 0), false, ply)
    PD.LOGS.Add("jobs", "Subunit " .. Table.old .. " in Unit " .. unitName .. " wurde zu " .. Table.new .. " umbenannt!", Color(255, 0, 0))

    PD.JOBS.SaveJobs()

    PD.JOBS.UpdateTabel()
end)

net.Receive("PD.JOBS.subunit_delete", function(len, ply)
    local Table = net.ReadTable()

    if not IsValid(ply) or not ply:IsAdmin() then return end

    PD.JOBS.LoadJobs()

    local allJobs = PD.JOBS.Jobs

    local unitName = Table.unit or "Fallback Unit!"

    if not allJobs[unitName] then
        print("Unit " .. unitName .. " does not exist!")
        return
    end

    if allJobs[unitName].subunits[Table.name] then
        PD.JOBS.Jobs[unitName].subunits[Table.name] = nil

        PD.Notify("Subunit " .. Table.name .. " in Unit " .. unitName .. " wurde gelöscht!", Color(255, 0, 0), false, ply)
        PD.LOGS.Add("jobs", "Subunit " .. Table.name .. " in Unit " .. unitName .. " wurde gelöscht!", Color(255, 0, 0))
    else
        print("Subunit " .. Table.name .. " does not exist in unit " .. unitName)
        return
    end

    PD.JOBS.SaveJobs()

    PD.JOBS.UpdateTabel()
end)