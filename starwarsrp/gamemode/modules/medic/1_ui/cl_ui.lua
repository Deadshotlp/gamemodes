PD.DM = PD.DM or {}
PD.DM.HUD = PD.DM.HUD or {}
PD.DM.UI = PD.DM.UI or {}

PD.DM.HUD.bones = {
    [1] = "ValveBiped.Bip01_Head1",
    [2] = "ValveBiped.Bip01_Spine4",
    [3] = "ValveBiped.Bip01_Spine",
    [4] = "ValveBiped.Bip01_L_Forearm",
    [5] = "ValveBiped.Bip01_R_Forearm",
    [6] = "ValveBiped.Bip01_L_Calf",
    [7] = "ValveBiped.Bip01_R_Calf"
}

PD.DM.HUD.lastBone = {
    index = 0,
    ply = nil,
    looked_at = false
}

local main_tbl

hook.Add("PostDrawHUD", "PD.DM.ShowwBoons", function()
    if input.IsButtonDown(80) then

        local ply = LocalPlayer()

        local vac1 = ply:GetPos() - Vector(250, 250, 250)
        local vac2 = ply:GetPos() + Vector(250, 250, 250)

        local trace = ply:GetEyeTrace()

        if trace.Entity:IsValid() and trace.Entity:IsPlayer() and ply:GetPos():Distance(trace.Entity:GetPos()) <= 100 then
            for k, v in pairs(PD.DM.HUD.bones) do
                if trace.Entity:LookupBone(v) ~= nil then
                    local mouseX, mouseY = input.GetCursorPos()
                    local pos = trace.Entity:GetBonePosition(trace.Entity:LookupBone(v)):ToScreen()

                    if mouseX >= pos.x - 16 and mouseX <= pos.x + 16 and mouseY >= pos.y - 16 and mouseY <= pos.y + 16 then
                        surface.SetDrawColor(255, 0, 0, 255)
                        PD.DM.HUD.lastBone.index = k
                        PD.DM.HUD.lastBone.ply = trace.Entity
                        PD.DM.HUD.lastBone.looked_at = true
                    else
                        surface.SetDrawColor(255, 255, 255, 255)
                    end
                    surface.DrawRect(pos.x - 16, pos.y - 0, 32, 32)
                end
            end
        end
    elseif PD.DM.HUD.lastBone.looked_at then
        PD.DM.HUD.lastBone.looked_at = false

        net.Start("PD.DM.HUD.RequestBoneInfo")
        net.WriteEntity(LocalPlayer())
        net.WriteEntity(PD.DM.HUD.lastBone.ply)
        net.WriteInt(PD.DM.HUD.lastBone.index, 16)
        net.SendToServer()
    end
end)

net.Receive("PD.DM.HUD.ReciveBoneInfo", function()
    local tbl = net.ReadTable()

    chat.AddText("---------------")
    for k, v in pairs(tbl) do
        chat.AddText(k .. ": " .. v)
    end
    chat.AddText("---------------")
end)

net.Receive("PD.DM.UI.Open", function()
    main_tbl = net.ReadTable()

    PD.DM.UI.Open()
end)

function PD.DM.UI.Open()
    if IsValid(PD.DM.UI.Frame) then
        PD.DM.UI.Frame:Remove()
    end

    PD.DM.UI.Frame = PD.Frame("Medic", PD.W(ScrW() / 1.5), PD.H(ScrH() / 1.5), true)

    local scrl = PD.Scroll(PD.DM.UI.Frame)
    scrl:Dock(FILL)

    local combo = PD.ComboBox("Wähle Kategorie", PD.DM.UI.Frame, function(val)
        scrl:Clear()

        PD.DM.UI.AddTablVal(scrl, main_tbl[val], val)
    end)
    combo:Dock(TOP)

    for k, v in SortedPairs(main_tbl) do
        combo:AddChoice(k)
    end
end

function PD.DM.UI.AddTablVal(scrl, tbl, val)
    for k, v in pairs(tbl) do
        local parent_panel = PD.Panel("", scrl)
        parent_panel:DockMargin(PD.W(5), PD.H(10), PD.W(5), PD.H(10))

        local count, elements = PD.DM.UI.CreatePanelContant(parent_panel, v)

        local remove_button = PD.Button("Remove", parent_panel, function()
            tbl[k] = nil
            PD.DM.UI.SaveTable(tbl, val)
            parent_panel:Remove()
        end, false)
        remove_button:Dock(BOTTOM)

        local save_button = PD.Button("Save", parent_panel, function()
            for k2, v2 in pairs(v) do
                if type(v2) == "string" then
                    tbl[k][k2] = elements[k2]:GetValue()
                elseif type(v2) == "number" then
                    tbl[k][k2] = tonumber(elements[k2]:GetValue(), 10)
                    if tbl[k][k2] == nil then
                        tbl[k][k2] = v2
                        PD.Notify("Value mismatch", Color(255, 0, 0, 255))
                    end
                end
            end

            PD.DM.UI.SaveTable(tbl, val)
        end, false)
        save_button:Dock(BOTTOM)

        parent_panel:SetSize(parent_panel:GetWide(), count * save_button:GetTall())
    end
end

function PD.DM.UI.CreatePanelContant(parent_panel, v)
    local count = 2
    local elements = {}

    for k2, v2 in pairs(v) do
        local child_panel = PD.Panel("", parent_panel)
        child_panel:Dock(TOP)
        child_panel:SetTall(PD.H(35))

        if type(v2) == "table" then

            local btn = PD.Button("Show Subtable", child_panel, function()
                parent_panel:Clear()

                PD.DM.UI.CreatePanelContant(parent_panel, v2)
            end)
            btn:Dock(FILL)
        elseif type(v2) == "string" then
            local label = PD.Label(k2 .. ":", child_panel)
            label:Dock(LEFT)

            local te = PD.TextEntry(k2, child_panel, v2)
            te:Dock(FILL)

            elements[k2] = te
        elseif type(v2) == "number" then
            local ns = PD.NumSlider("nadnkjawdnk", child_panel, 0, 100, v2, function()

            end)

            elements[k2] = ns
        elseif type(v2) == "boolean" then

        end

        count = count + 1.4
    end

    return count, elements
end

function PD.DM.UI.SaveTable(tbl, val)
    main_tbl[val] = tbl

    net.Start("PD.DM.UI.SaveTable")
    net.WriteTable(main_tbl)
    net.SendToServer()
end
