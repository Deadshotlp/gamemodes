PD.LOGS = PD.LOGS or {}
util.AddNetworkString("PD.LOGS.Addcl")
util.AddNetworkString("PD.LOGS.Add")
util.AddNetworkString("PD.LOGS.Sync")

PD.LOGS.Tbl = PD.LOGS.Tbl or {}

net.Receive("PD.LOGS.Addcl", function()
    local typ = net.ReadString()
    local text = net.ReadString()
    local color = net.ReadColor()

    table.insert(PD.LOGS.Tbl, {
        typ = typ,
        text = text,
        color = color,
        date = os.date("%H:%M:%S - %d.%m.%Y")
    })

    net.Start("PD.LOGS.Add")
        net.WriteTable(PD.LOGS.Tbl)
    net.Broadcast()
end)

net.Receive("PD.LOGS.Sync", function(len, ply)
    net.Start("PD.LOGS.Add")
        net.WriteTable(PD.LOGS.Tbl)
    net.Send(ply)
end)


timer.Simple(1, function()
    PD.JSON.Create("modules/logs")
end)

hook.Add("ShutDown", "SaveLogs", function()
    if PD.JSON.Read("modules/logs/" .. os.date("%d.%m.%Y") .. ".json") then
        local old = PD.JSON.Read("modules/logs/" .. os.date("%d.%m.%Y") .. ".json")
    end

    if old then
        for k,v in pairs(old) do
            table.insert(PD.LOGS.Tbl, v)
        end
    end

    PD.JSON.Write("modules/logs/" .. os.date("%d.%m.%Y") .. ".json", PD.LOGS.Tbl)
end)

