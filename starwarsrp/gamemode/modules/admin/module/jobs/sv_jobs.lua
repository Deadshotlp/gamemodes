-- Jobs System by Deadshot

local function SafeGetOrCreate(tbl, key, default)
    if not tbl[key] then
        tbl[key] = default
    end
    return tbl[key]
end

net.Receive("PD.JOBS.SaveJob", function(len, ply)
    local type = net.ReadString()
    local tbl = net.ReadTable()

    if not ply:IsAdmin() then
        return
    end

    print("Type: " .. type)
    PrintTable(tbl)

    for name, data in pairs(tbl) do
        if type == "unit" then
            local unit = SafeGetOrCreate(PD.JOBS.Jobs, name, {
                subunits = {},
                color = data.color
            })
            unit.color = data.color or Color(255, 0, 0)
            -- unit.default = data.default

            PD.Notify("Du hast die Unit " .. name .. " erfolgreich gespeichert!", Color(255, 0, 0), false, ply)
        elseif type == "subunit" then
            local unit = SafeGetOrCreate(PD.JOBS.Jobs, data.unit, {
                subunits = {}
            })
            local subunit = SafeGetOrCreate(unit.subunits, name, {
                color = data.color or Color(255, 0, 0),
                maxmembers = data.maxmembers or 10,
                ismedic = data.ismedic or false,
                isleo = data.isleo or false,
                isengineer = data.isengineer or false,
                jobs = {}
            })
            subunit.color = data.color or Color(255, 0, 0)
            subunit.maxmembers = data.maxmembers or 10
            subunit.ismedic = data.ismedic or false
            subunit.isleo = data.isleo or false
            subunit.isengineer = data.isengineer or false
            subunit.unit = data.unit 

            PD.Notify("Du hast die Subunit " .. name .. " erfolgreich gespeichert!", Color(255, 0, 0), false, ply)
        elseif type == "job" then
            local unit = PD.JOBS.Jobs[data.unit]
            local subunit = unit.subunits[data.subunit]

            local job = {
                salary = data.salary or 100,
                speed = data.speed or 100,
                id = #subunit.jobs + 1,
                model = data.model,
                equip = data.equip or {},
                color = data.color or Color(255, 0, 0),
                subunit = data.subunit,
                unit = data.unit,
            }

            subunit.jobs[name] = job

            PD.Notify("Du hast den Job " .. name .. " erfolgreich gespeichert!", Color(255, 0, 0), false, ply)
        end
    end

    PD.Notify("Du hast die Änderungen erfolgreich gespeichert!", Color(255, 0, 0), false, ply)

    hook.Run("PD.JOBS.SaveJob", type, tbl)

    PD.JOBS.SaveJobs()
    PD.JOBS.UpdateTabel()
end)

net.Receive("PD.JOBS.DeleteJob", function(len, ply)
    local type = net.ReadString()
    local tbl = net.ReadTable()

    if not ply:IsAdmin() then
        return
    end

    for name, data in pairs(tbl) do
        if type == "unit" then
            PD.JOBS.Jobs[name] = nil
            PD.Notify("Du hast die Unit " .. name .. " erfolgreich gelöscht!", Color(255, 0, 0), false, ply)
        elseif type == "subunit" then
            local unit = PD.JOBS.Jobs[data.unit]
            unit.subunits[name] = nil
            PD.Notify("Du hast die Subunit " .. name .. " erfolgreich gelöscht!", Color(255, 0, 0), false, ply)
        elseif type == "job" then
            local unit = PD.JOBS.Jobs[data.unit]
            local subunit = unit.subunits[data.subunit]
            subunit.jobs[name] = nil
            PD.Notify("Du hast den Job " .. name .. " erfolgreich gelöscht!", Color(255, 0, 0), false, ply)
        end
    end

    PD.Notify("Du hast die Änderungen erfolgreich gespeichert!", Color(255, 0, 0), false, ply)

    hook.Run("PD.JOBS.DeleteJob", type, tbl)

    PD.JOBS.SaveJobs()
    PD.JOBS.UpdateTabel()
end)



function PD.JOBS.UpdateTabel()
    net.Start("PD.JOBS.UpdateTabel")
    net.WriteTable(PD.JOBS.Jobs)
    net.Broadcast()
end

