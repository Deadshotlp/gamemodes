-- Default Functions

util.AddNetworkString("PD.DataPad:SendDataToServer")
util.AddNetworkString("PD.DataPad:DeleteData")
util.AddNetworkString("PD.DataPad:SyncData")
util.AddNetworkString("PD.DataPad:SyncDataCL")

net.Receive("PD.DataPad:SendDataToServer", function(len, ply)
    local type = net.ReadString()
    local data = net.ReadTable()

    -- if not PD.DataPad.CheckEntry("Akten", type) then return end

    local plyer = player.GetBySteamID64(data.ply)
    if not IsValid(plyer) then return end

    plyer:ChatPrint("Akte von " .. ply:Nick() .. " erstellt.")

    PD.DataPad.AddData(type, data)
end)

PD.DataPad.AktenData = PD.DataPad.AktenData or {}

function PD.DataPad.AddData(type, data)
    if not data then return end

    if not PD.DataPad.AktenData[type] then
        PD.DataPad.AktenData[type] = {}
    end

    table.insert(PD.DataPad.AktenData[type], data)

    PD.JSON.Create("akten")

    PD.JSON.Write("akten/" .. type .. ".json", PD.DataPad.AktenData[type])
end

timer.Simple(1, function()
    local alldata = file.Find("akten/*.json", "DATA")

    for k, v in pairs(alldata) do
        local data = PD.JSON.Read("akten/" .. v)

        PD.DataPad.AktenData[string.StripExtension(v)] = data
    end

    net.Start("PD.DataPad:SyncData")
        net.WriteTable(PD.DataPad.AktenData)
    net.Broadcast()
end)

net.Receive("PD.DataPad:DeleteData", function(len, ply)
    local type = net.ReadString()
    local id = net.ReadInt(32)

    if not PD.DataPad.AktenData[type] then return end

    table.remove(PD.DataPad.AktenData[type], id)

    PD.JSON.Create("akten")

    PD.JSON.Write("akten/" .. type .. ".json", PD.DataPad.AktenData[type])
end)

net.Receive("PD.DataPad:SyncDataCL", function(len, ply)
    net.Start("PD.DataPad:SyncData")
        net.WriteTable(PD.DataPad.AktenData)
    net.Send(ply)
end)

