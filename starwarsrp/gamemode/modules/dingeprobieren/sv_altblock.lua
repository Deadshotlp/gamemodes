PD.AB = PD.AB or {}

util.AddNetworkString("PD.AB.SecBan")

net.Receive("PD.AB.SecBan", function(len, ply)
    RunConsoleCommand("sam", "banid", ply:SteamID64(), 525600,
        "Du hast versucht dich mit einem Alt Acount einzulogen! \n Du kannst im Discord Gegen den Ban einspruch erheben: https://discord.gg/YEHfCffp4M")
end)
