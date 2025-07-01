
util.AddNetworkString("PD.Char.AdminSync")
util.AddNetworkString("PD.Char.AdminSave")
util.AddNetworkString("PD.Char.AdminDelete")

net.Receive("PD.Char.AdminSave",function()
    local plyid = net.ReadString()
    local charid = net.ReadUInt(32)
    local id = net.ReadString()
    local name = net.ReadString()
    local job = net.ReadString()
    local money = net.ReadUInt(32)
    local jobName, jobTable = PD.JOBS.GetJob(job, false)

    local tbl = PD.Char:LoadChar(plyid, "AdminSave")

    if tbl then
        tbl[charid].id = id
        tbl[charid].name = name
        tbl[charid].job = {
            name = jobName,
            model = jobTable.model[1],
            unit = jobTable.unit,
            id = jobName
        }
        tbl[charid].money = money

        PD.Char:SaveChar(plyid,tbl)
    end
end)

net.Receive("PD.Char.AdminSync",function(len,ply)
    local tbl = PD.Char:LoadAllChars()

    net.Start("PD.Char.AdminSync")
    net.WriteTable(tbl)
    net.Send(ply)
end)

net.Receive("PD.Char.AdminDelete",function(len,ply)
    local plyid = net.ReadString()
    local charid = net.ReadUInt(32)

    local tbl = PD.Char:LoadChar(plyid, "AdminDelete: " .. plyid)

    if tbl then
        table.remove(tbl,charid)
        PD.Char:SaveChar(plyid,tbl)
    end
end)

