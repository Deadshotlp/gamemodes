PD.DM = PD.DM or {}
PD.DM.HUD = PD.DM.HUD or {}
PD.DM.UI = PD.DM.UI or {}

util.AddNetworkString("PD.DM.HUD.ReciveBoneInfo")
util.AddNetworkString("PD.DM.HUD.RequestBoneInfo")
util.AddNetworkString("PD.DM.UI.Open")
util.AddNetworkString("PD.DM.UI.SaveTable")

net.Receive("PD.DM.HUD.RequestBoneInfo", function()
    local ply1 = net.ReadEntity()
    local ply2 = net.ReadEntity()
    local index = net.ReadInt(16)

    local tbl = PD.DM:RequestTable(ply1, "body_part")

    net.Start("PD.DM.HUD.ReciveBoneInfo")
    net.WriteTable(tbl[index])
    net.Send(ply1)
end)

net.Receive("PD.DM.UI.SaveTable", function()
    local tbl = net.ReadTable()

    for k, v in pairs(tbl) do
        if k == "Verletzungen" then
            PD.DM.Injury.tbl = v
        elseif k == "Behandlungen" then
            PD.DM.Treatments.tbl = v
        elseif k == "Medikamente" then
            PD.DM.Medication.tbl = v
        end
    end

    local dir = "deadshot/dm"

    PD.DM.SaveDir(dir .. "/injuries.json", PD.DM.Injury.tbl)
    PD.DM.SaveDir(dir .. "/treatments.json", PD.DM.Treatments.tbl)
    PD.DM.SaveDir(dir .. "/medication.json", PD.DM.Medication.tbl)
end)

hook.Add("PlayerButtonUp", "Deadshot_OpenMedicalEditor", function(ply, button)
    if not ply:IsAdmin() then
        return
    end

    if button == KEY_F9 then
        PD.DM.OpenMedicalEditor(ply)
        return
    end
end)

function PD.DM.OpenMedicalEditor(ply)
    local tbl = {}

    tbl.Verletzungen = PD.DM.Injury.tbl
    tbl.Behandlungen = PD.DM.Treatments.tbl
    tbl.Medikamente = PD.DM.Medication.tbl

    net.Start("PD.DM.UI.Open")
    net.WriteTable(tbl)
    net.Send(ply)
end
