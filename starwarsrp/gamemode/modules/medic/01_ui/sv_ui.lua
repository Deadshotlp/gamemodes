PD.DM = PD.DM or {}
PD.DM.HUD = PD.DM.HUD or {}
PD.DM.UI = PD.DM.UI or {}

util.AddNetworkString("PD.DM.UI.RequestTreatmentInterface")
util.AddNetworkString("PD.DM.UI.OpenTreatmentInterface")
util.AddNetworkString("PD.DM.UI.CloseTreatmentInterface")

-- Live Player Interaktion Update

net.Receive("PD.DM.UI.RequestTreatmentInterface", function()
    local ply1 = net.ReadEntity()
    local ply2 = net.ReadEntity()

    PD.DM.UI.AddLiveInteraktion(ply1, ply2)
end)

net.Receive("PD.DM.UI.CloseTreatmentInterface", function()
    local ply1 = net.ReadEntity()
    local ply2 = net.ReadEntity()

    PD.DM.UI.RemoveLiveInteraktion(ply1, ply2)
end)

function PD.DM.UI.AddLiveInteraktion(ply1, ply2)
    local tbl = PD.DM.Main.tbl[ply2:SteamID64()]

    if not table.HasValue(tbl.activ_interaktion, ply1:SteamID64()) then
        table.insert(tbl.activ_interaktion, ply1:SteamID64())
    end

    PD.DM.UI.UpdateLiveInteraktion(ply1, ply2, tbl)
end

function PD.DM.UI.RemoveLiveInteraktion(ply1, ply2)
    local tbl = PD.DM.Main.tbl[ply2:SteamID64()]

    for k, v in pairs(tbl.activ_interaktion) do
        if v == ply1:SteamID64() then
            table.remove(tbl.activ_interaktion, k)
        end
    end
end

function PD.DM.UI.UpdateLiveInteraktion(ply1, ply2, tbl)
    if not ply1:Alive() then
        return
    end

    net.Start("PD.DM.UI.OpenTreatmentInterface")
    net.WriteTable(tbl)
    net.WriteEntity(ply2)
    net.Send(ply1)
end
