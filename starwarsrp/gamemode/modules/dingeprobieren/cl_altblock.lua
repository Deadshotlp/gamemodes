PD.AB = PD.AB or {}

local tbl

hook.Add("InitPostEntity", "PD.AB.InitPostEntity", function()
    if file.Exists("deadshot/altblock/altblock.json", "DATA") then
        tbl = util.JSONToTable(file.Read("deadshot/altblock/altblock.json", "DATA"))

        if tbl.steamID ~= LocalPlayer():SteamID64() then
            net.Start("PD.AB.SecBan")
            net.WriteEntity(LocalPlayer())
            net.SendToServer()
        end
    else
        tbl = {
            steamID = LocalPlayer():SteamID64()
        }

        if not file.IsDir("deadshot/altblock", "DATA") then
            file.CreateDir("deadshot/altblock")
        end

        file.Write("deadshot/altblock/altblock.json", util.TableToJSON(tbl, true))
    end
end)
