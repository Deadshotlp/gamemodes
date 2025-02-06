PD.DM = PD.DM or {}
PD.DM.Main = PD.DM.Main or {}

net.Receive("TESTTESTTESTTEST", function()
    PrintTable(net.ReadTable())
end)
