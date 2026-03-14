PD.SQUAD = PD.SQUAD or {}
PD.SQUAD.SQUAD = PD.SQUAD.SQUAD or {
    -- name = "Alpha Squad",
    -- rolle = "Attack",
    -- members = {},
    -- show_in_hud = true,
    -- show_in_world = true,
}

PD.SQUAD.CONFIG = PD.SQUAD.CONFIG or {}
PD.SQUAD.CONFIG.Frame = nil


local rolle_rank_list_requested = false

local squad = {
    -- name = "Alpha Squad",
    -- rolle = "Attack",
    -- members = {
    --     [1] = {
    --         id = "76561198000000000",
    --         rank = "Leader",
    --     },
    --     [2] = {
    --         id = "76561198000000001",
    --         rank = "Member",
    --     },
    --     [3] = {
    --         id = "76561198000000002",
    --         rank = "Member",
    --     },
    --     [4] = {
    --         id = "76561198000000002",
    --         rank = "Member",
    --     },
    --     [5] = {
    --         id = "76561198000000002",
    --         rank = "Member",
    --     },
    --     [6] = {
    --         id = "76561198000000002",
    --         rank = "Member",
    --     },
    --     [7] = {
    --         id = "76561198000000002",
    --         rank = "Member",
    --     },
    --     [8] = {
    --         id = "76561198000000002",
    --         rank = "Member",
    --     },
    --     [9] = {
    --         id = "76561198000000002",
    --         rank = "Member",
    --     },
    --     [10] = {
    --         id = "76561198000000002",
    --         rank = "Medic",
    --     },

    -- },
    -- show_in_hud = true,
    -- show_in_world = true,
}

PD.SQUAD.Interactions = {
    ["player"] = {
        [1] = {
            id = "invite_to_squad",
            name = LANG.SQUAD_INTERACTION_INVITE,
            icon = nil,
            func = function(ply1, ply2)
                net.Start("PD.SQUAD.UpdateSquad")
                net.WriteString("invite_to_squad")
                net.WriteEntity(ply1)
                net.WriteEntity(ply2)
                net.SendToServer()
            end,
            ad = {"ValveBiped.Bip01_Spine"}
        },
        [2] = {
            id = "remove_from_squad",
            name = LANG.SQUAD_INTERACTION_REMOVE,
            icon = nil,
            func = function(ply1, ply2)
                net.Start("PD.SQUAD.UpdateSquad")
                net.WriteString("remove_from_squad")
                net.WriteEntity(ply1)
                net.WriteEntity(ply2)
                net.WriteString(squad.name)
                net.SendToServer()
            end,
            ad = {"ValveBiped.Bip01_Spine"}
        },
        [3] = {
            id = "squad_create",
            name = LANG.SQUAD_INTERACTION_CREATE,
            icon = nil,
            func = function(ply1, ply2)
                PD.SQUAD.OpenInterface()
            end,
            ad = {"self"}
        }
    }
}

local function_tbl = {
    ["join_squad"] = function()
        local tbl = net.ReadTable()

        squad.name = tbl.name or "Alpha Squad"
        squad.rolle = tbl.rolle or "Attack"
        squad.members = tbl.members or {}
        squad.show_in_hud = tbl.show_in_hud or true
        squad.show_in_world = tbl.show_in_world or true
    end,
    ["leave_squad"] = function()
        squad = {
            name = "",
            rolle = "",
            members = {},
            show_in_hud = false,
            show_in_world = false,
        }
    end,
    ["squad_update"] = function()

        chat.AddText("Squad updated!")
        local tbl = net.ReadTable()

        if squad then
            if isstring(tbl.name) then
                squad.name = nil
                squad.name = tbl.name
            else
                print("Invalid squad name provided.")
            end

            if isstring(tbl.rolle) then
                squad.rolle = nil
                squad.rolle = tbl.rolle
            else
                print("Invalid squad rolle provided.")
            end

            if isbool(tbl.show_in_hud) then
                squad.show_in_hud = nil
                squad.show_in_hud = tbl.show_in_hud
            else
                print("Invalid squad show_in_hud provided.")
            end

            if isbool(tbl.show_in_world) then
                squad.show_in_world = nil
                squad.show_in_world = tbl.show_in_world
            else
                print("Invalid squad show_in_world provided.")
            end

            if istable(tbl.members) then
                squad.members = nil
                squad.members = tbl.members
            else
                print("Invalid squad members provided.")
            end
        end

        if PD.SQUAD.CONFIG.Frame then
            PD.SQUAD.CONFIG.Frame:Remove()
            PD.SQUAD.OpenInterface()
        end
    end,
    ["squad_background"] = function()
        local tbl1 = net.ReadTable()
        local tbl2 = net.ReadTable()

        PD.SQUAD.rolle_list = tbl1
        PD.SQUAD.rank_list = tbl2

        if PD.SQUAD.CONFIG.Frame then
            PD.SQUAD.CONFIG.Frame:Remove()
            PD.SQUAD.OpenInterface()
        end
        rolle_rank_list_requested = false
    end,
    ["request_squad_background"] = function()
        rolle_rank_list_requested = true
        net.Start("PD.SQUAD.UpdateSquad")
        net.WriteString("squad_background")
        net.WriteEntity(LocalPlayer())
        net.SendToServer()
    end
}

hook.Add("PD.Interaction.Requested", "PD.Squad.Interaction.Answer", function(ent_class)
    PD.IA.AddEntityActions(PD.SQUAD.Interactions[ent_class], "Squad")
end)

net.Receive("PD.SQUAD.UpdateSquad", function()
    local str = net.ReadString()

    if function_tbl[str] then
        function_tbl[str]()
    end
end)

AddSmoothElement(PD.W(20), ScrH() / 2 - PD.H(250) / 2, PD.W(280), PD.H(350), function(smoothX, smoothY)
    if PD.FOV.thirdPerson then return end
    if not squad.show_in_hud then return end

    local ply = LocalPlayer()
    surface.SetFont("MLIB.24")
    local nameW, nameH = surface.GetTextSize(squad.name)
    local panelW = PD.W(280)
    local panelH = PD.H(350)

    -- Hintergrund Panel
    PD.DrawPanel(smoothX, smoothY, panelW, panelH, {
        background = PD.Theme.Colors.BackgroundLight,
        accent = PD.Theme.Colors.AccentRed,
        accentTop = false,
        accentBottom = false,
        corners = false,
        borders = false
    })

    -- Linke Akzentlinie (Imperial Red)
    surface.SetDrawColor(PD.Theme.Colors.AccentRed)
    surface.DrawRect(smoothX, smoothY, PD.W(4), panelH)

    -- Obere Linie
    surface.SetDrawColor(PD.Theme.Colors.AccentGray)
    surface.DrawRect(smoothX + PD.W(4), smoothY, panelW - PD.W(4), 1)

    -- Untere Linie
    surface.DrawRect(smoothX + PD.W(4), smoothY + panelH - 1, panelW - PD.W(4), 1)

    -- Squad Name Titel
    draw.DrawText(squad.name, "MLIB.24", smoothX + PD.W(15), smoothY + PD.H(12), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)

    -- Trennlinie unter dem Namen
    PD.DrawDivider(smoothX + PD.W(15), smoothY + PD.H(38), panelW - PD.W(30))

    -- Members List
    local memberY = smoothY + PD.H(50)
    for k, v in pairs(squad.members) do
        if memberY > smoothY + panelH - PD.H(25) then break end

        local ply_member = player.GetBySteamID64(v.id)
        local member_name = IsValid(ply_member) and ply_member:Nick() or "Unknown"

        surface.SetFont("MLIB.14")
        local nameW2, nameH2 = surface.GetTextSize(member_name)

        -- Member Name
        draw.DrawText(member_name, "MLIB.14", smoothX + PD.W(15), memberY, PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)

        -- Member Rank/Status
        draw.DrawText(v.rank, "MLIB.12", smoothX + PD.W(15), memberY + PD.H(14), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)

        -- Status Indicator
        PD.DrawStatusIndicator(smoothX + panelW - PD.W(20), memberY + PD.H(5), PD.W(6), PD.Theme.Colors.AccentBlue, false)

        memberY = memberY + PD.H(32)
    end
end)

local function squad_interface()
    local pnl_settings = PD.Panel(PD.SQUAD.CONFIG.Frame)
    pnl_settings:Dock(LEFT)
    pnl_settings:SetWide(PD.SQUAD.CONFIG.Frame:GetWide() / 2 - PD.W(25))
    local pnl_members = PD.Panel(PD.SQUAD.CONFIG.Frame)
    pnl_members:Dock(LEFT)
    pnl_members:SetWide(PD.SQUAD.CONFIG.Frame:GetWide() / 2 - PD.W(25))

    local name = PD.TextEntry(pnl_settings, "Squad Name")
    if squad.name then
        name:SetPlaceholder(squad.name)
    end

    local rolle = PD.Dropdown(pnl_settings, squad.rolle or "Squad Rolle", function() end)
    if not table.IsEmpty(PD.SQUAD.rolle_list) then
        for _, v in pairs(PD.SQUAD.rolle_list) do
            rolle:AddOption(v.name)
        end
    elseif not rolle_rank_list_requested then
        function_tbl["request_squad_background"]()
    end

    local show_in_hud = PD.Checkbox(pnl_settings, "Show in HUD", squad.show_in_hud or false, function() end)
    --local show_in_world = PD.Checkbox(pnl_settings, "Show in World", squad.show_in_world or false, function() end)

    local btn_save = PD.Button("Save Squad", pnl_settings)
    btn_save:Dock(BOTTOM)
    btn_save.DoClick = function()
        local new_squad = {}
        if name:GetValue() == "" and squad.name ~= "" then
            new_squad.name = squad.name
        else
            new_squad.name = name:GetValue()
        end
        new_squad.rolle = rolle:GetValue()
        new_squad.show_in_hud = show_in_hud:GetValue()
        --new_squad.show_in_world = show_in_world:GetValue()

        local str

        if not squad.name or squad.name == "" then
            str = "create_squad"
        else
            str = "update_squad"
        end

        net.Start("PD.SQUAD.UpdateSquad")
        net.WriteString(str)
        net.WriteEntity(LocalPlayer())
        net.WriteTable(squad)
        net.WriteTable(new_squad)
        net.SendToServer()
    end


    local member_list = PD.Scroll(pnl_members)
    for k, v in SortedPairs(squad.members or {}) do
        local memberPnl = PD.Panel(member_list)
        memberPnl:Dock(TOP)
        --memberPnl:SetTall(PD.H(40))

        local ply_member = player.GetBySteamID64(v.id)
        local member_name = IsValid(ply_member) and ply_member:Nick() or "Unknown"

        local btn_remove = PD.Button("Remove", memberPnl)
        btn_remove:Dock(RIGHT)
        btn_remove:SetWide(PD.SQUAD.CONFIG.Frame:GetWide() / 10)
        btn_remove.DoClick = function()
            net.Start("PD.SQUAD.UpdateSquad")
            net.WriteString("remove_from_squad")
            net.WriteEntity(LocalPlayer())
            net.WriteEntity(player.GetBySteamID64(v.id))
            net.WriteString(squad.name)
            net.SendToServer()
        end

        local lbl_rank = PD.Dropdown(memberPnl, v.rank, function(k2, v2)
            net.Start("PD.SQUAD.UpdateSquad")
            net.WriteString("change_squad_pos")
            net.WriteEntity(LocalPlayer())
            net.WriteEntity(player.GetBySteamID64(v.id))
            net.WriteString(squad.name)
            net.WriteString(k2)
            net.SendToServer()
        end)

        if not table.IsEmpty(PD.SQUAD.rank_list) then
            for _, rank in pairs(PD.SQUAD.rank_list) do
                --chat.AddText(rank.name)
                lbl_rank:AddOption(rank.name)
            end
        elseif not rolle_rank_list_requested then
            function_tbl["request_squad_background"]()
        end
        
        lbl_rank:Dock(RIGHT)
        lbl_rank:SetWide(PD.SQUAD.CONFIG.Frame:GetWide() / 10)

        surface.SetFont("MLIB.20")
        local nameW2, nameH2 = surface.GetTextSize(member_name)

        local lbl_name = PD.Label(member_name, memberPnl, {color = PD.Theme.Colors.Text, font = "MLIB.20"})
        lbl_name:Dock(FILL)
    end
end

function PD.SQUAD.OpenInterface()
    -- for _, v in SortedPairs(squad.members) do
    --     if v.rank == "Leader" then
    --         if v.id ~= LocalPlayer():SteamID64() then
    --             return
    --         end
    --     end
    -- end

    if IsValid(PD.SQUAD.CONFIG.Frame) then
        PD.SQUAD.CONFIG.Frame:Remove()
    end

    PD.SQUAD.CONFIG.Frame = PD.Frame("Squad Verwaltung", ScrW() / 2, ScrH() / 2, true)



    squad_interface()
end