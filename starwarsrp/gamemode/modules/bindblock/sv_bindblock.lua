PD.BB = PD.BB or {}

util.AddNetworkString("PD.CheckAdmin")

net.Receive("PD.CheckAdmin", function(len, ply)
    if not ply:IsAdmin() then
        RunConsoleCommand("sam", "banid", ply:SteamID64(), 525600,
            "Du hast versucht dir Zugriff auf das C oder Q menu zu verschaffen! \n Du kannst im Discord Gegen den Ban einspruch erheben: https://discord.gg/YEHfCffp4M")
    end
end)
