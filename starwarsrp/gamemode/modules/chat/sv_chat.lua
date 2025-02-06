-- 

util.AddNetworkString("PD_AddChat")

net.Receive("PD_AddChat", function(len, ply)
    local text = net.ReadString()
    local name = ply:Nick()

    if (ply:IsAdmin()) then
        for k, v in pairs(player.GetAll()) do
            -- ChatText(name, text, "admin")
        end
    else
        for k, v in pairs(player.GetAll()) do
            -- ChatText(name, text, "chat")
        end
    end
end)