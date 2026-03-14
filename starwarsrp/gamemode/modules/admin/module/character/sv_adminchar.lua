
util.AddNetworkString("PD.Char.AdminSync")
util.AddNetworkString("PD.Char.Admin")

net.Receive("PD.Char.AdminSync",function(len,ply)
    local tbl = PD.Char:LoadAllChars()

    net.Start("PD.Char.AdminSync")
    net.WriteTable(tbl)
    net.Send(ply)
end)

net.Receive("PD.Char.Admin",function(len, ply)
    if not ply:IsAdmin() then return end

    local typ = net.ReadString()
    local plyid = net.ReadString()
    local playerTable = net.ReadTable()

    local tbl = PD.Char:LoadChar(plyid, "AdminSave")

    if tbl then
        if typ == "save" then
            playerTable.admin = ply:SteamID64()
            playerTable.lastupdateadin = os.date("%d.%m.%Y %H:%M:%S", os.time())

            tbl[playerTable.id] = playerTable
            PD.Char:SaveChar(plyid, tbl)

            PD.LOGS.Add("char", "Charakter mit der ID " .. playerTable.id .. " von Spieler " .. plyid .. " wurde von " .. ply:Nick() .. " gespeichert!", Color(0, 255, 0))
        elseif typ == "delete" then
            local charid = playerTable.id
            table.remove(tbl, charid)
            PD.Char:SaveChar(plyid, tbl)

            if #tbl > 0 then
                local charID = 0

                for k, v in pairs(tbl) do
                    if v.id ~= charid then
                        charID = k
                        break
                    end
                end

                if charID == 0 then 
                    net.Start("OpenCharbyDelete")
                    net.Send(FindPlayerbyID(plyid))
                    return 
                end

                PD.Char:PlayerSetChar(FindPlayerbyID(plyid), charID)

                PD.LOGS.Add("char", "Charakter mit der ID " .. charid .. " von Spieler " .. plyid .. " wurde von " .. ply:Nick() .. " gelöscht!", Color(255, 0, 0))
            end
        elseif typ == "set" then
            local charID = playerTable.id

            PD.Char:PlayerSetChar(FindPlayerbyID(plyid), charID)

            PD.LOGS.Add("char", "Charakter mit der ID " .. charID .. " von Spieler " .. plyid .. " wurde von " .. ply:Nick() .. " ausgewählt!", Color(0, 255, 0))
        end
    end
end)

net.Receive("PD.Char.AdminDelete",function(len,ply)
    local plyid = net.ReadString()
    local charid = net.ReadUInt(32)

    local tbl = PD.Char:LoadChar(plyid, "AdminDelete: " .. plyid)

    if tbl then
        table.remove(tbl,charid)
        PD.Char:SaveChar(plyid,tbl)

        PD.LOGS.Add("char", "Charakter mit der ID " .. charid .. " von Spieler " .. plyid .. " wurde von " .. ply:Nick() .. " gelöscht!", Color(255, 0, 0))
    end
end)

