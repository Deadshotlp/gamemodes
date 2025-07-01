-- Jobs System by Deadshot
util.AddNetworkString("PD.JOBS.OpenUnitEditor")
util.AddNetworkString("PD.JOBS.SaveJob")
util.AddNetworkString("PD.JOBS.UpdateTabel")
util.AddNetworkString("PD.JOBS.SyncJobs")
util.AddNetworkString("PD.JOBS.DeleteJob")
PD.JOBS = PD.JOBS or {}

PD.JOBS.Jobs = {
    ["Ausbildung"] = {
        default = true,
        equip = {},
        color = Color(255, 255, 255),
        subunits = {
            ["Rekruten"] = {
                default = true,
                equip = {},
                color = Color(255, 255, 255),
                maxmambers = 10,
                unit = "Ausbildung",
                ismedic = false,
                isleo = false,
                isengineer = false,
                jobs = {
                    ["Rekrut"] = {
                        default = true,
                        equip = {"salute_swep", "cross_arms_swep"},
                        model = {"models/starwars/grady/gl/ct/ct_trooper.mdl"},
                        unit = "Rekruten",
                        salary = 100,
                        speed = 100,
                        id = 1,
                        color = Color(255, 255, 255)
                    }
                }
            }
        }
    }
}

--- load all units, subunits and jobs
local dir = "deadshot/jobs"
local file = "/jobs.json"

function PD.JOBS.LoadDir()
    if not PD.JSON.Exists(dir) then
        PD.JSON.Create(dir)
    end

    PD.JOBS.LoadJobs()
end

function PD.JOBS.LoadJobs()
    if not PD.JSON.Exists(dir .. file) then
        PD.JSON.Write(dir .. file, PD.JOBS.Jobs)
    end

    PD.JOBS.Jobs = PD.JSON.Read(dir .. file)
end

-- save all units, subunits and jobs
function PD.JOBS.SaveJobs()
    if PD.JSON.Exists(dir .. file) then
        PD.JSON.Delete(dir .. file)
    end

    PD.JSON.Write(dir .. file, PD.JOBS.Jobs)
end

hook.Add("PostPDLoaded", "Deadshot_LoadUnits", function()
    PD.JOBS.LoadDir()
end)
PD.JOBS.LoadDir()

hook.Add("PlayerInitialSpawn", "PD.SendJobData", function(ply)
    PD.JOBS.LoadDir()

    PD.JOBS.UpdateTabel()
end)

net.Receive("PD.JOBS.SyncJobs", function(len, ply)
    PD.JOBS.LoadDir()

    timer.Simple(0.1, function()
        PD.JOBS.UpdateTabel()
    end)
end)

function PD.JOBS.UpdateTabel()
    net.Start("PD.JOBS.UpdateTabel")
    net.WriteTable(PD.JOBS.Jobs)
    net.Broadcast()
end

-- get all units, subunits and jobs
local fallback = {
    ["Fallback Unit!"] = {
        default = false,
        equip = {},
        color = Color(255, 0, 0),
        subunits = {
            ["Fallback Subunit!"] = {
                maxmambers = 10,
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
            if _ == name then
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
            subunits[_] = j
        end
    end

    if all then
        return subunits
    end

    if name then
        for _, i in SortedPairs(subunits) do
            if _ == name then
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
            jobs[_] = j
        end
    end

    if all then
        return jobs
    end

    if name then
        for _, i in SortedPairs(jobs) do
            if _ == name then
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

concommand.Add("pd_jobs_prints", function()
    print("===============================Start=======================================")
    PrintTable(PD.JOBS.Jobs)
    print("================================Ende=======================================")
end)
