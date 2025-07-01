PD.DM = PD.DM or {}
PD.DM.HUD = PD.DM.HUD or {}
PD.DM.UI = PD.DM.UI or {}

util.AddNetworkString("PD.DM.UI.OpenAdminInterface")
util.AddNetworkString("PD.DM.UI.SaveTable")
util.AddNetworkString("PD.DM.UI.RequestTreatmentInterface")
util.AddNetworkString("PD.DM.UI.OpenTreatmentInterface")

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

    net.Start("PD.DM.UI.OpenAdminInterface")
    net.WriteTable(tbl)
    net.Send(ply)
end

-- Live Player Interaktion Update

net.Receive("PD.DM.UI.RequestTreatmentInterface", function()
    local ply1 = net.ReadEntity()
    local ply2 = net.ReadEntity()

    PD.DM.UI.AddLiveInteraktion(ply1, ply2)
end)

local function update(ply1, ply2)
    local tbl = PD.DM.Main.tbl[ply2:SteamID64()]

    net.Start("PD.DM.UI.OpenTreatmentInterface")
    net.WriteTable(tbl)
    net.WriteEntity(ply2)
    net.Send(ply1)
end

function PD.DM.UI.AddLiveInteraktion(ply1, ply2)
    PD.DM:UpdateTable(ply1, "activ_interaktion", ply2:SteamID64())

    update(ply1, ply2)
end

function PD.DM.UI.RemoveLiveInteraktion(ply1)
    PD.DM:UpdateTable(ply1, "activ_interaktion", nil)
end

function PD.DM.UI.UpdateLiveInteraktion(ply1)
    for _, ply2 in player.Iterator() do
        if PD.DM:RequestTable(ply2, "activ_interaktion") == ply1:SteamID64() then
            update(ply2, ply1)
        end
    end
end
