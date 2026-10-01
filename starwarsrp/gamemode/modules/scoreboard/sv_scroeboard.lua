util.AddNetworkString("MarioScoreboard")

hook.Add("PlayerInitialSpawn", "MarioScoreboardReady", function(ply)
    net.Start("MarioScoreboard")
        net.WriteUInt(RealTime(), 32)
    net.Send(ply)
end)


