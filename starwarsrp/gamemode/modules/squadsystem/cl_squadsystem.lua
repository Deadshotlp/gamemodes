PD.Squad = PD.Squad or {}

PD.Squad.SquadList = {}

PD.Squad.Rolls = {
    [1] = {name = "SL", color = Color(0, 50, 255, 255), prio = 1},
    [2] = {name = "STV", color = Color(0, 200, 255, 255), prio = 2},
    [3] = {name = "MEDIC", color = Color(255, 0, 0, 255), prio = 3},
    [4] = {name = "EOD", color = Color(255, 130, 0, 255), prio = 3},
    [5] = {name = "TRP", color = Color(255, 255, 255, 255), prio = 4},
}


PD.Squad.IsAdmin = false

PD.Squad.Selected = nil

PD.Squad.Config = {
    activ = false,
    squad = {}
}

net.Receive("PD.Squad.Manag", function()
    PD.Squad.Selected = nil
    PD.Squad.SquadList = net.ReadTable()
    PD.Squad.IsAdmin = net.ReadBool()
    PD.Squad.OpenManagMenu()
end)

net.Receive("PD.Squad.Leave", function()
    PD.Squad.Config.squad = {}
    PD.Squad.Config.activ = false
end)

net.Receive("PD.Squad.Refresh", function()
    PD.Squad.Config.squad = net.ReadTable()
    PD.Squad.Config.activ = true
end)

local SquadFrame

hook.Add("PostDrawHUD", "PD.Squad.ShowHUD", function()
    if PD.Squad.Config.activ then
        PD.Squad.DrawHUD()
    elseif SquadFrame then
        SquadFrame:Remove()
    end
end)

function PD.Squad.DrawHUD()
    if IsValid(SquadFrame) then
        SquadFrame:Remove()
    end

    SquadFrame = PD.Frame(PD.Squad.Config.squad.name, PD.W(225), PD.H(35), true, false, true)

    SquadFrame:SetSize(PD.W(225), PD.H(35 * #PD.Squad.Config.squad.members + 47))
    SquadFrame:SetPos(PD.W(0), PD.H(ScrH() / 5))
    SquadFrame:SetEnabled( true )

    for k, v in ipairs(PD.Squad.Config.squad.members) do
        if PD.Squad.Config.squad.showmembers then
            local btn = PD.Button(v.name, SquadFrame)
            btn:Dock(TOP)
            btn:SetTall(35)

            if PD.Squad.Config.squad.showrole then
                for _, i in pairs(PD.Squad.Rolls) do
                    if i.name == v.role then
                        if i.color ~= nil then
                            btn:SetTextColor( i.color )
                            btn:SetToolTip(v.role)
                        end
                    end
                end
            end
        end

        if PD.Squad.Config.squad.showmemberpos and LocalPlayer():Nick() ~= v.name then 
            for z, y in pairs(player.GetAll()) do
                if v.name == y:Nick() then
                    v.pos = y:GetPos()
                end
            end

            local pos = v.pos + Vector(0, 0, 35) -- Position des Spielers mit einer leichten Verschiebung nach oben
            local scrPos = pos:ToScreen()

            if scrPos.visible then
                local size = 50 
                if PD.Squad.Config.squad.showrole then
                    for _, i in pairs(PD.Squad.Rolls) do
                        if i.name == v.role then
                            surface.SetTextColor( i.color )
                        end
                    end
                end
                surface.SetFont( "MLIB_ENTS.30" )
	            surface.SetTextPos( scrPos.x - size * 2, scrPos.y - size / 2 )
                surface.DrawText(v.name) 
            end
        end
    end
end

function PD.Squad.OpenManagMenu()
    local mainFrame = PD.Frame("Squads", PD.W(900), PD.H(600), true)
    local scr_pnl = PD.Panel("", mainFrame)
    scr_pnl:Dock(NODOCK)
    scr_pnl:SetPos(PD.W(0), PD.H(35))
    scr_pnl:SetSize(PD.W(150), PD.H(565))

    local scr = PD.Scroll(scr_pnl)

    for k, v in ipairs(PD.Squad.SquadList) do
        local btn = PD.Button(v.name, scr, function()
            PD.Squad.Selected = v
            mainFrame:Remove()
            PD.Squad.OpenManagMenu()
        end)
        btn:Dock(TOP)
        btn:SetTall(PD.H(35))
    end

    local is_in_squad = false

    for k, v in ipairs(PD.Squad.SquadList) do
        for _, i in ipairs(v.members) do
            if i.name == LocalPlayer():Nick() then
                is_in_squad = true
            end
        end
    end

    if not is_in_squad then
        local create_btn = PD.Button("Create Squad", scr_pnl, function()
            table.insert(PD.Squad.SquadList, {
                name = "Enter Name",
                id = #PD.Squad.SquadList + 1,
                showrole = true,
                showmembers = true,
                showmemberpos = false,
                members = {
                    {name = LocalPlayer():Nick(), id = 1, role = "SL", pos = LocalPlayer():GetPos()}
                }
            })

            PD.Squad.Selected = PD.Squad.SquadList[#PD.Squad.SquadList + 1]
            mainFrame:Remove()
            PD.Squad.OpenManagMenu()
        end)
        create_btn:Dock(BOTTOM)
        create_btn:SetTall(PD.H(35))
    end

    if PD.Squad.Selected ~= nil then
        local sqd_pnl = PD.Panel("", mainFrame)
        sqd_pnl:Dock(NODOCK)
        sqd_pnl:SetPos(PD.W(155), PD.H(35))
        sqd_pnl:SetSize(PD.W(745), PD.H(565))

        local sqd_name = PD.TextEntry("", sqd_pnl, PD.Squad.Selected.name)
        sqd_name:Dock(NODOCK)
        sqd_name:SetPos(PD.W(5), PD.H(5))
        sqd_name:SetSize(PD.W(200), PD.H(50))

        local pnl1, sql_showrole = PD.SimpleCheck(sqd_pnl, "Show Role", PD.Squad.Selected.showrole, function(val) end)
        pnl1:Dock(NODOCK)
        pnl1:SetPos(PD.W(5), PD.H(60))
        pnl1:SetSize(PD.W(200), PD.H(50))

        local pnl2, sql_showmembers = PD.SimpleCheck(sqd_pnl, "Show Members", PD.Squad.Selected.showmembers, function(val) end)
        pnl2:Dock(NODOCK)
        pnl2:SetPos(PD.W(5), PD.H(115))
        pnl2:SetSize(PD.W(200), PD.H(50))

        local pnl3, sql_showmemberpos = PD.SimpleCheck(sqd_pnl, "Show Member Pos", PD.Squad.Selected.showmemberpos, function(val) end)
        pnl3:Dock(NODOCK)
        pnl3:SetPos(PD.W(5), PD.H(170))
        pnl3:SetSize(PD.W(200), PD.H(50))

        local member_pnl = PD.Panel("", sqd_pnl)
        member_pnl:Dock(NODOCK)
        member_pnl:SetPos(PD.W(210), PD.H(0))
        member_pnl:SetSize(PD.W(250), PD.H(475))

        local member_scr = PD.Scroll(member_pnl)
        member_scr:Dock(FILL)

        local properties 

        for k, v in ipairs(PD.Squad.Selected.members) do
            local btn = PD.Button(v.name, member_scr, function()
                PD.Squad.OpenDMenu(v.id, mainFrame)
            end)
            
            btn:Dock(TOP)
            btn:SetTall(PD.H(35))
        end


        local sqd_save_btn = PD.Button("Save", sqd_pnl, function()
            PD.Squad.Selected.name = sqd_name:GetValue()
            PD.Squad.Selected.showrole = sql_showrole:GetChecked()
            PD.Squad.Selected.showmembers = sql_showmembers:GetChecked()
            PD.Squad.Selected.showmemberpos = sql_showmemberpos:GetChecked()

            PD.Squad.Save(mainFrame)
        end)
        sqd_save_btn:Dock(BOTTOM)
        sqd_save_btn:SetTall(PD.H(35))

        local sqd_delete_btn = PD.Button("Delete", sqd_pnl, function()
            PD.Squad.Selected.members = {}
            PD.Squad.Save(mainFrame)
        end)
        sqd_delete_btn:Dock(BOTTOM)
        sqd_delete_btn:SetTall(PD.H(35))
        
        local is_sl = false

        if PD.Squad.Selected.name == PD.Squad.Config.squad.name then
            for k, v in pairs(PD.Squad.Config.squad.members) do
                if v.name == LocalPlayer():Nick() and (v.role == "SL" or v.role == "STV") then
                    is_sl = true
                end
            end
        end

        if is_sl or PD.Squad.IsAdmin then
            sqd_pnl:SetEnabled( true )
        else
            sqd_pnl:SetEnabled( false )
        end
    end
end

function PD.Squad.OpenDMenu(id, mainFrame)
    local dmenu = DermaMenu()

    local roleManage = dmenu:AddSubMenu( "Rollen Verwaltung" )
    for k, v in pairs(PD.Squad.Rolls) do
        roleManage:AddOption(v.name, function()
            PD.Squad.Selected.members[id].role = v.name
            PD.Squad.Save(mainFrame)
        end)
    end 

    dmenu:AddSpacer()

    local userMange = dmenu:AddSubMenu( "User Verwaltung" )
    userMange:AddOption("Kick", function() 
        table.remove(PD.Squad.Selected.members, id)
        PD.Squad.Save(mainFrame)
    end)

    dmenu:Open()
end

function PD.Squad.Save(mainFrame)
    net.Start("PD.Squad.Save")
    net.WriteTable(PD.Squad.Selected)
    net.SendToServer()

    mainFrame:Remove()
end