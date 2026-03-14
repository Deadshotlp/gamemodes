PD.Officer = PD.Officer or {}

net.Receive("PD.Officer:Sync", function()
    local t = net.ReadTable()
    PD.Officer.Table = t or PD.Officer.Table
    hook.Run("PD.Officer:Updated", PD.Officer.Table)
end)

timer.Simple(0, function()
    net.Start("PD.Officer:Request")
    net.SendToServer()
end)
