PD.DataPad = PD.DataPad or {}

PD.DataPad.AddCategory("Akten")

function PD.DataPad.SendDataToServer(type, data)
    if not data then return end

    net.Start("PD.DataPad:SendDataToServer")
        net.WriteString(type)
        net.WriteTable(data)
    net.SendToServer()
end

timer.Simple(1, function()
    net.Start("PD.DataPad:SyncDataCL")
    net.SendToServer()
end)


PD.DataPad.AktenData = {}
net.Receive("PD.DataPad:SyncData", function()
    PD.DataPad.AktenData = net.ReadTable()
end)

function PD.DataPad.GetData(type)
    if not PD.DataPad.AktenData[type] then return {} end

    return PD.DataPad.AktenData[type]
end

concommand.Add("print_getData", function()
    PrintTable(PD.DataPad.GetData("Stoßtruppen"))
end)

