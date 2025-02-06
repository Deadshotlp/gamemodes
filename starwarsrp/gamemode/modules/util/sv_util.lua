--

local function BlockSuicide(ply)
	ply:ChatPrint("Versuch es erst garnicht...")
	return false
end
hook.Add( "CanPlayerSuicide", "BlockSuicide", BlockSuicide )

util.AddNetworkString("PD.Notify")
util.AddNetworkString("PD.OpenYoutube")

hook.Add("PlayerInitialSpawn", "PD.Notify", function(ply)
    ply:GetNWString("rpname", "Unknown")
end)

util.AddNetworkString("PD.RuleDecline")

net.Receive("PD.RuleDecline", function(len, ply)
	ply:Kick("Du hast die Regeln abgelehnt.")
end)

