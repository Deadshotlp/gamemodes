PD.Char.AdminData = PD.Char.AdminData or {}

net.Receive("PD.Char.AdminSync", function()
    PD.Char.AdminData = net.ReadTable()
end)

function PD.Char:GetAdminData(player)
    if not IsValid(player) or not player:IsPlayer() then return end

    local data = PD.Char.AdminData[player:SteamID64()]
    if not data then print("No Admin Data for player: " .. player:Nick()) PrintTable(PD.Char.AdminData) return end

    return data
end

net.Start("PD.Char.AdminSync")
net.SendToServer()

hook.Add("InitPostEntity", "SyncCharMenuCharsProgama057Admin", function()
    net.Start("PD.Char.AdminSync")
    net.SendToServer()
end)

concommand.Add("pd_AdminCharPrintData", function(ply, cmd, args)
    -- if not ply:IsAdmin() then return end

    -- local target = FindPlayerbyID(args[1])
    -- if not IsValid(target) then return end

    local data = PD.Char:GetAdminData(ply)
    print("Admin Data for player: " .. ply:Nick())
    PrintTable(data)
end)