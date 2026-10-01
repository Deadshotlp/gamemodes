PD.JOBS = PD.JOBS or {}
PD.JOBS.Jobs = PD.JOBS.Jobs or {}

timer.Simple(1, function()
    net.Start("PD.JOBS.SyncJobs")
    net.SendToServer()
end)

net.Receive("PD.JOBS.UpdateTabel", function()
    PD.JOBS.Jobs = net.ReadTable()
end)

local fallback = {
    ["Fallback Unit!"] = {
        default = false,
        color = Color(255, 0, 0),
        subunits = {
            ["Fallback Subunit!"] = {
                maxmembers = 10,
                default = false,
                equip = {},
                color = Color(255, 0, 0),
                unit = "Fallback Unit!",
                ismedic = false,
                isleo = false,
                isengineer = false,
                jobs = {
                    ["Fallback Job!"] = {
                        color = Color(255, 0, 0),
                        model = {"models/player/skeleton.mdl"},
                        equip = {},
                        default = false,
                        unit = "Fallback Subunit!",
                        salary = 100,
                        speed = 100,
                        id = 1
                    }
                }
            }
        }
    }
}

function PD.JOBS.GetUnit(name, all)
    if all then
        return PD.JOBS.Jobs
    end

    if name then
        for _, i in SortedPairs(PD.JOBS.Jobs) do
            if i.name == name then
                return _, i
            end
        end
    end

    for _, i in SortedPairs(PD.JOBS.Jobs) do
        if i.default then
            return _, i
        end
    end

    return "Fallback Unit!", fallback["Fallback Unit!"]
end

function PD.JOBS.GetSubUnit(name, all)
    local subunits = {}

    for _, i in SortedPairs(PD.JOBS.Jobs) do
        for _, j in SortedPairs(i.subunits) do
            subunits[j.name] = j
        end
    end

    if all then
        return subunits
    end

    if name then
        for _, i in SortedPairs(subunits) do
            if i.name == name then
                return _, i
            end
        end
    end

    for _, i in SortedPairs(subunits) do
        if i.default then
            return _, i
        end
    end

    return "Fallback Subunit!", fallback["Fallback Unit!"].subunits["Fallback Subunit!"]
end

function PD.JOBS.GetJob(name, all)
    local subunits = PD.JOBS.GetSubUnit(false, true)
    local jobs = {}

    for _, i in SortedPairs(subunits) do
        for _, j in SortedPairs(i.jobs) do
            jobs[j.name] = j
        end
    end

    if all then
        return jobs
    end

    if name then
        for _, i in SortedPairs(jobs) do
            if i.name == name then
                return _, i
            end
        end
    end

    for _, i in SortedPairs(jobs) do
        if i.default then
            return _, i
        end
    end

    return "Fallback Job!", fallback["Fallback Unit!"].subunits["Fallback Subunit!"].jobs["Fallback Job!"]
end

function PD.JOBS.GetIndex(UnitIndex, SubIndex, JobIndex)
    local Unit = PD.JOBS.Jobs[UnitIndex]
    if not Unit then return "Fallback Unit!", fallback["Fallback Unit!"] end

    local SubUnit = Unit.subunits[SubIndex]
    if not SubUnit then return "Fallback Subunit!", fallback["Fallback Unit!"].subunits["Fallback Subunit!"] end

    local Job = SubUnit.jobs[JobIndex]
    if not Job then return "Fallback Job!", fallback["Fallback Unit!"].subunits["Fallback Subunit!"].jobs["Fallback Job!"] end

    return JobIndex, Job
end

--[[

Function zum bekommen aller Fraktionen für combobox

Struktur:

{
    [1] = {
        name = "Fraktion | Untereinheit | Rang",
        data = {
            faction = "Fraktion",
            subfaction = "Untereinheit",
            job = "Rang"
        }
    }
}
]]

function PD.JOBS.GetAllFactions()
    local tbl = {}
    local i = 1

    for k, v in SortedPairs(PD.JOBS.GetUnit(false, true)) do
        for k2, v2 in SortedPairs(v.subunits) do
            for k3, v3 in SortedPairs(v2.jobs) do
                tbl[i] = {
                    name = v.name .. " | " .. v2.name .. " | " .. v3.name,
                    data = {
                        faction = k,
                        subfaction = k2,
                        job = k3
                    }
                }
                i = i + 1
            end
        end
    end

    return tbl
end

concommand.Add("pd_jobs_print_AllFactions", function()
    print("===============================Start=======================================")
    PrintTable(PD.JOBS.GetAllFactions())
    print("================================Ende=======================================")
end)

concommand.Add("pd_jobs_prints_cl", function()
    print("===============================Start=======================================")
    PrintTable(PD.JOBS.Jobs)
    print("================================Ende=======================================")
end)