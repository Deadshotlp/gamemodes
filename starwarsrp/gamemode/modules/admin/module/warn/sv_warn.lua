PD.Warn = PD.Warn or {}

util.AddNetworkString("PD.Warn.AddWarn")
util.AddNetworkString("PD.Warn.RemoveWarn")
util.AddNetworkString("PD.Warn.SendWarnsToClient")
util.AddNetworkString("PD.Warn.SendWarns")
util.AddNetworkString("PD.Warn.BanPlayer")
util.AddNetworkString("PD.Warn.GetWarns")

local warnTable = {}

timer.Simple(1,function()
    PD.JSON.Create("warn")
end)

hook.Add("Initialize", "PD.Warn.ReadWarns", function()
    warnTable = PD.JSON.Read("warn/warns.json")
end)

net.Receive("PD.Warn.GetWarns", function(_, ply)
    if not ply:IsAdmin() then return end

    warnTable = PD.JSON.Read("warn/warns.json")

    net.Start("PD.Warn.SendWarnsToClient")
        net.WriteTable(warnTable)
    net.Send(ply)
end)

net.Receive("PD.Warn.AddWarn", function(_, ply)
    if not ply:IsAdmin() then return end

    local target = net.ReadEntity()
    if not IsValid(target) then return end

    local plyID = target:SteamID()
    if not plyID then
        print("Error: plyID is nil for target:", target)
        return
    end

    local reason = {admin = ply:Nick(), reason = "No reason provided.", date = os.date("%d/%m/%Y %H:%M:%S")}
    PD.LOGS.Add("Warn", ply:Nick() .. " warned " .. target:Nick() .. " for: " .. reason.reason, Color(255,0,0))

    warnTable[plyID] = warnTable[plyID] or { Warns = 0, Reasons = {} }
    warnTable[plyID].Warns = warnTable[plyID].Warns + 1
    table.insert(warnTable[plyID].Reasons, reason)

    net.Start("PD.Warn.SendWarnsToClient")
        net.WriteTable(warnTable)
    net.Send(target)

    target:ChatPrint("You have been warned by " .. ply:Nick() .. " for: " .. reason.reason)

    PD.JSON.Write("warn/warns.json", warnTable)
end)

net.Receive("PD.Warn.RemoveWarn", function(_, ply)
    if not ply:IsAdmin() then return end

    local target = net.ReadEntity()

    if not IsValid(target) then return end

    local plyID = target:SteamID()

    if not warnTable[plyID] then return end

    PD.LOGS.Add("Warn", ply:Nick() .. " removed a warn from " .. target:Nick(), Color(255,0,0))

    warnTable[plyID].Warns = warnTable[plyID].Warns - 1

    if warnTable[plyID].Warns <= 0 then
        warnTable[plyID] = nil
    end

    net.Start("PD.Warn.SendWarnsToClient")
        net.WriteTable(warnTable)
    net.Send(target)

    target:ChatPrint("A warn has been removed by " .. ply:Nick())

    PD.JSON.Write("warn/warns.json", warnTable)
end)

net.Receive("PD.Warn.BanPlayer", function(_, ply)
    if not ply:IsAdmin() then return end

    local target = net.ReadEntity()

    if not IsValid(target) then return end

    local plyID = target:SteamID()

    warnTable[plyID] = 3

    target:Ban(0, true)
end)

hook.Add("PlayerInitialSpawn", "PD.Warn.SendWarns", function(ply)
    net.Start("PD.Warn.SendWarns")
        net.WriteTable(warnTable)
    net.Send(ply)
end)

concommand.Add("print_warn2", function()
    print("Printing warnTable")
    -- print(warnTable)

    PrintTable(warnTable)
end)