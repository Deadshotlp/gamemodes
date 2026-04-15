PD.Squad = PD.Squad or {}
PD.Squad.Squads = { --PD.Squad.Squads or {
    -- [1] = {
    --     name = "Alpha Squad",
    --     rolle = "Attack",
    --     members = {
    --         [1] = {id = ply:SteamID64(), rank = "Leader"},
    --         [2] = {id = ply:SteamID64(), rank = "Member"},
    --     },
    --     show_in_hud = true,
    --     show_in_world = true,

    -- }
}

local function_tbl = {
    ["create_squad"] = function()
        local ply1 = net.ReadEntity()
        local tbl = net.ReadTable()
        local tbl2 = net.ReadTable()

        for k, v in SortedPairs(PD.Squad.Squads) do
            if v.name == tbl2.name then
                print("Duplicate squad name detected: " .. tbl2.name)
                return -- Prevent duplicate squad names
            end
        end

        for k, v in SortedPairs(PD.Squad.Squads) do
            for k2, v2 in SortedPairs(v.members) do
                if v2.id == ply1:SteamID64() then
                    print("Player is already in a squad, removing from previous squad.")

                    table.RemoveByValue(PD.Squad.Squads, v)
                    if #v.members == 0 then
                        print("Previous squad is now empty, removing squad: " .. v.name)
                        table.RemoveByValue(PD.Squad.Squads, v)
                    end
                    --return -- Prevent a player from creating multiple squads
                end
            end
        end

        local squad_tbl = {
            name = tbl2.name or PD.SQUAD.name_list[math.random(1, #PD.SQUAD.name_list)],
            rolle = tbl2.rolle or "Attack",
            members = {
                [1] = {
                    id = ply1:SteamID64(),
                    rank = "Leader",
                },
            },
            show_in_hud = tbl2["show_in_hud"],
            show_in_world = tbl2["show_in_world"],
        }

        table.insert(PD.Squad.Squads, squad_tbl)

        net.Start("PD.SQUAD.UpdateSquad")
        net.WriteString("squad_update")
        net.WriteTable(squad_tbl)
        net.Send(ply1)
    end,
    ["update_squad"] = function()
        local ply1 = net.ReadEntity()
        local tbl1 = net.ReadTable()
        local tbl2 = net.ReadTable()

        local squad
        
        for k, v in SortedPairs(PD.Squad.Squads) do
            if v.name == tbl1.name then
                squad = v
                continue
            end
        end

        for k, v in SortedPairs(PD.Squad.Squads) do
            if v.name == tbl2.name and v ~= squad then
                return -- Prevent duplicate squad names
            end
        end

        if squad then
            if isstring(tbl2.name) then
                squad.name = nil
                squad.name = tbl2.name
            else
                print("Invalid squad name provided.")
            end

            if isstring(tbl2.rolle) then
                squad.rolle = nil
                squad.rolle = tbl2.rolle
            else
                print("Invalid squad rolle provided.")
            end

            if isbool(tbl2.show_in_hud) then
                squad.show_in_hud = nil
                squad.show_in_hud = tbl2.show_in_hud
            else
                print("Invalid squad show_in_hud provided.")
            end

            if isbool(tbl2.show_in_world) then
                squad.show_in_world = nil
                squad.show_in_world = tbl2.show_in_world
            else
                print("Invalid squad show_in_world provided.")
            end
        end

        if #squad.members == 0 then
            table.RemoveByValue(PD.Squad.Squads, squad)
        else
            -- If the leader leaves, assign a new leader
            local is_leader_present = false
            for k, v in SortedPairs(squad.members) do
                if v.rank == "Leader" then
                    is_leader_present = true
                    break
                end
            end

            if not is_leader_present then
                squad.members[1].rank = "Leader"
            end
        end

        for k, v in SortedPairs(squad.members) do
            net.Start("PD.SQUAD.UpdateSquad")
            net.WriteString("squad_update")
            net.WriteTable(squad)
            net.Send(player.GetBySteamID64(v.id))
        end

    end,
    ["invite_to_squad"] = function()
        local ply1 = net.ReadEntity()
        local ply2 = net.ReadEntity()
        -- Logic to invite a player to a squad

        local is_in_squad = false
        local squad

        for k, v in SortedPairs(PD.Squad.Squads) do
            for k2, v2 in SortedPairs(v.members) do
                if v2.id == ply1:SteamID64() then
                    squad = v
                elseif v2.id == ply2:SteamID64() then
                    is_in_squad = true
                end
            end
        end

        if is_in_squad then return end

        if squad then
            table.insert(squad.members, {
                id = ply2:SteamID64(),
                rank = "Member",
            })

            net.Start("PD.SQUAD.UpdateSquad")
            net.WriteString("squad_update")
            net.WriteTable(squad)
            net.Send(ply2)

            for k, v in SortedPairs(squad.members) do
                net.Start("PD.SQUAD.UpdateSquad")
                net.WriteString("squad_update")
                net.WriteTable(squad)
                net.Send(player.GetBySteamID64(v.id))
            end
        end
    end,
    ["change_squad_pos"] = function()
        local ply1 = net.ReadEntity()
        local ply2 = net.ReadEntity()
        local squad_name = net.ReadString()
        local new_rank = net.ReadString()

        local squad

        for k, v in SortedPairs(PD.Squad.Squads) do
            if v.name ~= squad_name then continue end
            for k2, v2 in SortedPairs(v.members) do
                if v2.id == ply1:SteamID64() then
                    squad = v
                    continue
                end
            end
        end

        if not squad then return end

        for k, v in SortedPairs(squad.members) do
            if v.id == ply2:SteamID64() then
                v.rank = new_rank
                continue
            end
        end

        for k, v in SortedPairs(squad.members) do
            net.Start("PD.SQUAD.UpdateSquad")
            net.WriteString("squad_update")
            net.WriteTable(squad)
            net.Send(player.GetBySteamID64(v.id))
        end
    end,
    ["remove_from_squad"] = function()
        local ply1 = net.ReadEntity()
        local ply2 = net.ReadEntity()
        local squad_name = net.ReadString()

        local squad

        for k, v in SortedPairs(PD.Squad.Squads) do
            if v.name ~= squad_name then continue end
            for k2, v2 in SortedPairs(v.members) do
                if v2.id == ply1:SteamID64() and v2.rank == "Leader" then
                    squad = v
                    continue
                end
            end
        end

        if not squad then return end

        for k, v in SortedPairs(squad.members) do
            if v.id == ply2:SteamID64() then
                table.remove(squad.members, k)
                continue
            end
        end

        if #squad.members == 0 then
            table.RemoveByValue(PD.Squad.Squads, squad)
        else
            -- If the leader leaves, assign a new leader
            local is_leader_present = false
            for k, v in SortedPairs(squad.members) do
                if v.rank == "Leader" then
                    is_leader_present = true
                    break
                end
            end

            if not is_leader_present then
                squad.members[1].rank = "Leader"
            end
        end

        net.Start("PD.SQUAD.UpdateSquad")
        net.WriteString("leave_squad")
        net.Send(player.GetBySteamID64(ply2:SteamID64()))

        for k, v in SortedPairs(squad.members) do
            net.Start("PD.SQUAD.UpdateSquad")
            net.WriteString("squad_update")
            net.WriteTable(squad)
            net.Send(player.GetBySteamID64(v.id))
        end
    end,
    ["leave_from_squad"] = function(ply)
        local ply1 = net.ReadEntity()

        if not IsValid(ply1) then
            if IsValid(ply) then  
                ply1 = ply
            else
                return
            end
        end

        local squad

        for k, v in SortedPairs(PD.Squad.Squads) do
            for k2, v2 in SortedPairs(v.members) do
                if v2.id == ply1:SteamID64() then
                    squad = v
                    continue
                end
            end
        end

        if not squad then return end

        squad.members = table.RemoveByValue(squad.members, ply1:SteamID64())

        if #squad.members == 0 then
            table.RemoveByValue(PD.Squad.Squads, squad)
        else
            -- If the leader leaves, assign a new leader
            local is_leader_present = false
            for k, v in SortedPairs(squad.members) do
                if v.rank == "Leader" then
                    is_leader_present = true
                    break
                end
            end

            if not is_leader_present then
                squad.members[1].rank = "Leader"
            end
        end

        if IsValid(ply1) then
            net.Start("PD.SQUAD.UpdateSquad")
            net.WriteString("leave_squad")
            net.Send(ply1)
        end

        for k, v in SortedPairs(squad.members) do
            net.Start("PD.SQUAD.UpdateSquad")
            net.WriteString("update_squad")
            net.WriteTable(squad)
            net.Send(player.GetBySteamID64(v.id))
        end
    end,
    ["squad_background"] = function()
        local ply = net.ReadEntity()

        net.Start("PD.SQUAD.UpdateSquad")
        net.WriteString("squad_background")
        net.WriteTable(PD.SQUAD.rolle_list)
        net.WriteTable(PD.SQUAD.rank_list)
        net.Send(ply)
    end,
}


util.AddNetworkString("PD.SQUAD.UpdateSquad")

function PD.SQUAD.LoadTables()
    local dir = "modules/squadsystem/"
    PD.JSON.Create(dir)
    PD.SQUAD.rolle_list = {}

    if PD.JSON.Exists(dir .. "rolles.json") then
        PD.SQUAD.rolle_list = PD.JSON.Read(dir .. "rolles.json")
    else
        PD.JSON.Write(dir .. "rolles.json", PD.SQUAD.rolle_list)
    end

    if PD.JSON.Exists(dir .. "ranks.json") then
        PD.SQUAD.rank_list = PD.JSON.Read(dir .. "ranks.json")
    else
        PD.JSON.Write(dir .. "ranks.json", PD.SQUAD.rank_list)
    end

    if PD.JSON.Exists(dir .. "names.json") then
        PD.SQUAD.name_list = PD.JSON.Read(dir .. "names.json")
    else
        PD.JSON.Write(dir .. "names.json", PD.SQUAD.name_list)
    end

end

net.Receive("PD.SQUAD.UpdateSquad", function(len, ply)
    local str = net.ReadString()

    if function_tbl[str] then
        function_tbl[str]()
    end
end)

hook.Add("ShutDown", "PD.SQUAD.SaveTables", function()
    local dir = "modules/squadsystem/"

    PD.JSON.Write(dir .. "rolles.json", PD.SQUAD.rolle_list)
    PD.JSON.Write(dir .. "ranks.json", PD.SQUAD.rank_list)
    PD.JSON.Write(dir .. "names.json", PD.SQUAD.name_list)
end)

hook.Add("PlayerDisconnected", "PD.SQUAD.HandleLeave", function(ply)
    function_tbl.leave_from_squad(ply)
end)

PD.SQUAD.LoadTables() 