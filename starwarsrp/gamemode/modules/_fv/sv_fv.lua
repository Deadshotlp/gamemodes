PD.FV = PD.FV or {}

util.AddNetworkString("PD.FV.RequestPlayerInfo")
util.AddNetworkString("PD.FV.SendPlayerInfo")

local function sendTouser(ply, tbl)
    net.Start("PD.FV.SendPlayerInfo")

    if table.IsEmpty(tbl) then
        net.WriteBool(false)
    else
        net.WriteBool(true)
        net.WriteTable(tbl)
    end

    net.Send(ply)
end

net.Receive("PD.FV.RequestPlayerInfo", function(len, ply)
    local str = string.Split(net.ReadString(), ",")
    local unit, subunit, job = str[1], str[2], str[3]
    if unit == "" then
        sendTouser(ply, {})
        return
    end

    local tbl = PD.Char:LoadAllChars()

    local charsTabel = {}

    for k,v in pairs(tbl) do
        for i,j in pairs(v) do
            if unit == j.faction.unit then
                if subunit == "" then
                    local char = {
                        name = j.name,
                        id = j.id,
                        faction = j.faction,
                        lastplaytime = j.lastplaytime
                    }

                    table.insert(charsTabel, char)
                else
                    if subunit == j.faction.subunit then
                        if job == "" then
                            local char = {
                                name = j.name,
                                id = j.id,
                                faction = j.faction,
                                lastplaytime = j.lastplaytime
                            }

                            table.insert(charsTabel, char)
                        else
                            if job == j.faction.job then
                                local char = {
                                    name = j.name,
                                    id = j.id,
                                    faction = j.faction,
                                    lastplaytime = j.lastplaytime
                                }

                                table.insert(charsTabel, char)
                            end
                        end
                    end
                end
            end
        end
    end

    sendTouser(ply, charsTabel)
end)