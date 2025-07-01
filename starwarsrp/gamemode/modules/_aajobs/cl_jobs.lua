PD.JOBS = PD.JOBS or {}

PD.JOBS.Jobs = PD.JOBS.Jobs or {}

PD.JOBS.Menu = {
    unit = "",
    subunit = "",
    job = ""
}

local selectedUnit = ""

local sampel = {
    ["Test Unit"] = {
        default = false,
        equip = {},
        color = Color(255, 255, 255),
        subunits = {
            ["Test Subunit"] = {
                default = false,
                equip = {},
                color = Color(255, 255, 255),
                maxmembers = 10,
                unit = "Test Unit",
                ismedic = false,
                isleo = false,
                isengineer = false,
                jobs = {
                    ["Test Job"] = {
                        default = false,
                        equip = {},
                        model = {},
                        unit = "Test Subunit",
                        salary = 100,
                        speed = 100,
                        id = 1
                    }
                }
            }
        }
    }
}

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
        equip = {},
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

