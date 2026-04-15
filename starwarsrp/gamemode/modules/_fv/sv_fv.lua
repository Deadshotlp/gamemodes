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
    PrintTable(str)
    local unit, subunit, job = str[1], str[2], str[3]
    if unit == "" then
        sendTouser(ply, {})
        return
    end

    local tbl = PD.Char:LoadAllChars()

    local charsTabel = {}

    local units = PD.JOBS.GetUnit(false, true)

    for k,v in pairs(tbl) do
        for i,j in pairs(v) do
            for _1, a in SortedPairs(units) do
                if _1 == j.faction.unit then
                    j.faction.unit = a.name
                    for _2, b in SortedPairs(units[_1].subunits) do
                        if _2 == j.faction.subunit then
                            j.faction.subunit = b.name
                            for _3, c in SortedPairs(units[_1].subunits[_2].jobs) do
                                if _3 == j.faction.job then
                                    j.faction.job = c.name
                                    continue
                                end
                            end

                            continue
                        end
                    end

                    continue
                end
            end

            for _1, a in SortedPairs(units) do
                if _1 == unit then
                    unit = a.name
                    for _2, b in SortedPairs(units[_1].subunits) do
                        if _2 == subunit then
                            subunit = b.name
                            for _3, c in SortedPairs(units[_1].subunits[_2].jobs) do
                                if _3 == job then
                                    job = c.name
                                    continue
                                end
                            end

                            continue
                        end
                    end

                    continue
                end
            end


            if j.faction.unit == unit and (subunit == "" or j.faction.subunit == subunit) and (job == "" or j.faction.job == job) then
                local newTBL = {}
                newTBL.faction = j.faction.unit .. "," .. j.faction.subunit .. "," .. j.faction.job
                newTBL.name = j.id .. " " .. j.name
                newTBL.lastplaytime = j.lastplaytime
                table.insert(charsTabel, newTBL)
            end
        end
    end

    sendTouser(ply, charsTabel)
end)