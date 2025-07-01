PD.DM = PD.DM or {}
PD.DM.Main = PD.DM.Main or {}

PD.DM.Interactions = {
    [1] = {
        id = "tourniquet",
        name = "Apply Tourniquet",
        icon = nil,
        func = function(ply1, ply2, bone)
            net.Start("PD.DM.ChangeTourniquetStatus")
            net.WriteEntity(ply1)
            net.WriteEntity(ply2)
            net.WriteInt(bone, 16)
            net.SendToServer()
        end,
        not_ad = {1, 2}
    },
    [2] = {
        id = "check_puls",
        name = "Check Puls",
        icon = nil,
        func = function(ply1, ply2, bone)
            net.Start("PD.DM.RequestValue")
            net.WriteEntity(ply1)
            net.WriteEntity(ply2)
            net.WriteInt(bone, 16)
            net.WriteString("puls")
            net.SendToServer()
        end,
        not_ad = {}
    },
    [3] = {
        id = "check_bp",
        name = "Check BP",
        icon = nil,
        func = function(ply1, ply2, bone)
            net.Start("PD.DM.RequestValue")
            net.WriteEntity(ply1)
            net.WriteEntity(ply2)
            net.WriteInt(bone, 16)
            net.WriteString("bp")
            net.SendToServer()
        end,
        not_ad = {}
    },
    [4] = {
        id = "check_fractured",
        name = "Check for Fractures",
        icon = nil,
        func = function(ply1, ply2, bone)
            net.Start("PD.DM.RequestValue")
            net.WriteEntity(ply1)
            net.WriteEntity(ply2)
            net.WriteInt(bone, 16)
            net.WriteString("fractured")
            net.SendToServer()
        end,
        not_ad = {}
    },
    [5] = {
        id = "open_interface",
        name = "Open Medical Interface",
        icon = nil,
        func = function(ply1, ply2, bone)
            net.Start("PD.DM.UI.RequestTreatmentInterface")
            net.WriteEntity(ply1)
            net.WriteEntity(ply2)
            net.SendToServer()
        end,
        not_ad = {1, 3, 4, 5, 6, 7}
    }
}

function PD.DM.GetInteractions(index)
    local tbl = {}
    local bol

    for k, v in SortedPairs(PD.DM.Interactions) do
        bol = true

        if v["not_ad"] and v["not_ad"][1] ~= nil then
            for _, i in ipairs(v.not_ad) do
                if i == index then
                    bol = false
                    continue
                end
            end
        end

        if bol then
            table.insert(tbl, v)
        end
    end

    return tbl
end

function PD.DM.IsMedic(ply)
    local job_id, job_tbl = ply:GetJob()
    local subunit_id, subunit_tbl = PD.JOBS.GetSubUnit(job_tbl.unit, false)
    if subunit_tbl.ismedic then
        return true
    end

    return false
end

net.Receive("PD.DM.RecieveValue", function()
    local str = net.ReadString()

    if str == "injureys" then
        local val = net.ReadTable()

        for k, v in ipairs(val) do
            LocalPlayer():ChatPrint(v.name)
        end
    elseif str == "puls" then
        local val = net.ReadInt(16)

        LocalPlayer():ChatPrint("Puls: " .. val)
    elseif str == "bp" then
        local val = net.ReadTable()

        LocalPlayer():ChatPrint("BP: " .. val[1] .. "/" .. val[2])
    end
end)

function PD.DM.Main.Interact(task_class, task_tbl, patient)
    

    net.Start("PD.DM.Interact")
    net.WriteEntity(LocalPlayer())
    net.WriteEntity(patient)
    net.WriteString(task_class)
    net.WriteTable(task_tbl)
    net.SendToServer()

end
