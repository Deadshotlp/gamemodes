PD.Squad = PD.Squad or {}

PD.Squad.SquadList = {}
PD.Squad.Rolls = {
    [1] = {name = "SL", color = Color(0, 50, 255, 255), prio = 1},
    [2] = {name = "STV", color = Color(0, 200, 255, 255), prio = 2},
    [3] = {name = "MEDIC", color = Color(255, 0, 0, 255), prio = 3},
    [4] = {name = "EOD", color = Color(255, 130, 0, 255), prio = 3},
    [5] = {name = "TRP", color = Color(255, 255, 255, 255), prio = 4},
}

PD.Squad.LastRefresh = 0

--[[
    [1] = {}
        name = "Squad Name",
        id = 1,
        showrole = true,
        showmembers = true,
        showmemberpos = true,
        members = {
            [1] = {
                name = "Player Name",
                id = 1,
                role = "Squad Rank",
                prio = 1
                pos = Vector(0, 0, 0),
            }
        }
    }
]]--


util.AddNetworkString("PD.Squad.Manag")
util.AddNetworkString("PD.Squad.Save")
util.AddNetworkString("PD.Squad.Leave")
util.AddNetworkString("PD.Squad.Delete")
util.AddNetworkString("PD.Squad.Refresh")

hook.Add("PlayerSay", "PD.Squad.Toggle", function( ply, text )
    local parts = string.Split(text, " ")

    if string.lower(parts[1]) == "/squads" then
        net.Start("PD.Squad.Manag")
        net.WriteTable(PD.Squad.SquadList)
        if ply:IsAdmin() then
            net.WriteBool(true)
        else
            net.WriteBool(false)
        end
        net.Send(ply)
    
    elseif string.lower(parts[1]) == "/createsquad" then
        if PD.Squad.IsValid(parts[2]) then
            PD.Squad.Create(ply, parts[2])
        end
    elseif string.lower(parts[1]) == "/joinsquad" then
        if PD.Squad.IsValid(parts[2]) then
            PD.Squad.Join(ply, parts[2])
        end
    elseif string.lower(parts[1]) == "/leavesquad" then
        PD.Squad.Leave(ply)
    elseif string.lower(parts[1]) == "/squadpos" then
        PD.Squad.Pos(ply, parts[2])
    end
end)

hook.Add( "PlayerDisconnected", "PD.Squad.Leave", function(ply)
    for k, v in pairs(PD.Squad.SquadList) do
        for _, i in pairs(v.members) do
            if i.name == ply:Nick() then
                PD.Squad.Leave(ply, v.name)
            end
        end
    end
end )

hook.Add("Think", "PD.Squad.Refresh", function()
    if CurTime() > (PD.Squad.LastRefresh + 1) and #PD.Squad.SquadList > 0 then
        PD.Squad.LastRefresh = CurTime()

        for k, v in pairs(PD.Squad.SquadList) do
            for _, i in pairs(v.members) do
                for z, y in pairs(player.GetAll()) do
                    if i.name == y:Nick() then

                        net.Start("PD.Squad.Refresh")
                        net.WriteTable(v)
                        net.Send(y)
                    end
                end
            end
        end
    end
end)

net.Receive("PD.Squad.Save", function(len, ply)
    local squad = net.ReadTable()
    local new = net.ReadBool()

    if #squad.members == 0 and not new then
        table.remove(PD.Squad.SquadList, squad.id)
    end

    if new then
        table.insert(PD.Squad.SquadList, squad)
    else
        PD.Squad.SquadList[squad.id] = squad
    end

    net.Start("PD.Squad.Manag")
    net.WriteTable(PD.Squad.SquadList)
    if ply:IsAdmin() then
        net.WriteBool(true)
    else
        net.WriteBool(false)
    end
    net.Send(ply)
end)

net.Receive("PD.Squad.Delete", function(len, ply)
    local squad = net.ReadTable()

    for k, v in pairs(PD.Squad.SquadList) do
        if v == squad then
            table.remove(PD.Squad.SquadList, k)
            return
        end
    end
end)

function PD.Squad.IsValid(text)
    if text == nil or text == "" then
        return false
    end
    return true
end

function PD.Squad.Create(ply, squad)
    for k, v in pairs(PD.Squad.SquadList) do
        if v.name == squad then
            PD.Notify("Squad Existiert Bereits!", Color(255, 30, 30, 255), false, ply)
            return
        end
    end
    table.insert(PD.Squad.SquadList, {
        name = squad, 
        id = #PD.Squad.SquadList + 1,
        showrole = true, 
        showmembers = true, 
        showmemberpos = false, 
        members = {}
    })
    PD.Notify("Squad Erstellt!", Color(0, 255, 0, 255), false, ply)

    PD.Squad.Join(ply, squad, "SL")
end

function PD.Squad.Join(ply, squad, prole)
    local squadid
 
    for k, v in pairs(PD.Squad.SquadList) do
        for _, i in pairs(v.members) do
            if i.name == ply:Nick() then
                PD.Notify("Du bist bereits in einem Squad!", Color(255, 30, 30, 255), false, ply)
                return
            end
        end

        if v.name == squad then
            squadid = k
        end
    end

    if squadid == nil then
        PD.Notify("Squad existiert nicht!", Color(255, 30, 30, 255), false, ply)
        return
    end

    local prio   

    if prole == nil then
        prole = "TRP"
    end

    for k, v in pairs(PD.Squad.Rolls) do 
        if v.name == prole then 
            prio = v.prio
        end 
    end

    table.insert(PD.Squad.SquadList[squadid].members, {
        name = ply:Nick(), 
        id = #PD.Squad.SquadList[squadid].members + 1,
        role = prole,
        prio = prio,
    })

    PD.Notify("Squad "..PD.Squad.SquadList[squadid].name.." beigetreten!", Color(0, 255, 0, 255), false, ply)
end

function PD.Squad.Leave(ply)
    for k, v in pairs(PD.Squad.SquadList) do
        for _, i in pairs(v.members) do
            if i.name == ply:Nick() then
                table.remove(PD.Squad.SquadList[k].members, _)
                PD.Notify("Du hast das Squad verlassen!", Color(0, 255, 0, 255), false, ply)

                net.Start("PD.Squad.Leave")
                net.Send(ply)

                if #v.members == 0 then
                    table.remove(PD.Squad.SquadList, k)
                end

                return
            end
        end
    end
    PD.Notify("Du befindest dich nicht in einem Squad!", Color(255, 30, 30, 255), false, ply)
end