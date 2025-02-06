PD.Entity = PD.Entity or {}
PD.Entity.Umkleide = PD.Entity.Umkleide or {}

function PD.Entity.Umkleide:Save()
    PrintTable(LocalPlayer():GetBodyGroups())

    local tbl = {
        model = LocalPlayer():GetModel(),
        bodygroups = {}
    }

    for _, i in pairs(LocalPlayer():GetBodyGroups()) do
        table.insert(tbl.bodygroups, LocalPlayer():GetBodygroup(_))
    end

    if not file.IsDir("deadshot/umkleide", "DATA") then
        file.CreateDir("deadshot/umkleide")
    end

    if file.Exists("deadshot/umkleide/" .. LocalPlayer():Nick() .. ".json", "DATA") then
        file.Delete("deadshot/umkleide/" .. LocalPlayer():Nick() .. ".json")
    end

    file.Write("deadshot/umkleide/" .. LocalPlayer():Nick() .. ".json", util.TableToJSON(tbl, true))
end

function PD.Entity.Umkleide:Load()
    local tbl = {}

    if file.Exists("deadshot/umkleide/" .. LocalPlayer():Nick() .. ".json", "DATA") then
        tbl = util.JSONToTable(file.Read("deadshot/umkleide/" .. LocalPlayer():Nick() .. ".json", "DATA"))
    end

    if tbl.model == LocalPlayer():GetModel() then
        for k, v in pairs(tbl.bodygroups) do
            net.Start("ChangeBodygroup")
            net.WriteInt(k, 32)
            net.WriteInt(v, 32)
            net.SendToServer()
        end
    end
end

net.Receive("PD.Entity.Umkleide.Load", function()
    timer.Simple(1, function()
        PD.Entity.Umkleide:Load()
    end)
end)

net.Receive("ShowBodygroups", function()
    PD.Entity.Umkleide:OpenFrame()
end)

concommand.Add("umkleide", function(player)
    PD.Entity.Umkleide:OpenFrame()
end)

function PD.Entity.Umkleide:OpenFrame()
    if IsValid(mainFrame) then return end

    mainFrame = PD.Frame("Umkleide", PD.W(1600), PD.H(900), true)
    local bodygroups = LocalPlayer():GetBodyGroups()

    local sub_panel = PD.Panel("Model", mainFrame)
    sub_panel:SetSize(mainFrame:GetWide() / 2, mainFrame:GetTall())
    sub_panel:Dock(LEFT)
    sub_panel:DockMargin(PD.W(0), PD.H(0), PD.W(0), PD.H(0))

    local pm = PD.Model(sub_panel, LocalPlayer():GetModel(), PD.W(0), PD.H(0), mainFrame:GetWide() / 2, mainFrame:GetTall())

    PD.Entity.Umkleide:ShowAttachments(mainFrame, bodygroups, pm)
end

-- PrintTable(LocalPlayer():GetBodyGroups())

function PD.Entity.Umkleide:ShowAttachments(mainFrame, bodygroups, pm)
    local sub_panel = PD.Panel("Attachments", mainFrame)
    sub_panel:Dock(FILL)
    sub_panel:DockMargin(PD.W(5), PD.H(0), PD.W(0), PD.H(0))

    local ScrollList = PD.Scroll(sub_panel)

    for k, v in pairs(bodygroups) do
        pm.Entity:SetBodygroup(k, LocalPlayer():GetBodygroup(k))

        if (bodygroups[k].id >= 0) and (bodygroups[k].num >= 0) then
            local bodygroupName = PD.Label(bodygroups[k].name .. " | ID: " .. bodygroups[k].id, ScrollList)
            bodygroupName:Dock(TOP)

            local y = (k - 1) * 75
            bodygroupName:SetPos(PD.W(5), PD.H(y - 60))
            bodygroupName:SetSize(PD.W(500), PD.H(25))

            local pnl = PD.Panel("", ScrollList)
            pnl:Dock(TOP)
            pnl:SetTall(PD.H(45))
            pnl:SetWidth(PD.W(360))

            for j, l in pairs(bodygroups[k].submodels) do
                j = j + 1
                local bodygroupButton = PD.Button(tostring(j), pnl, function()
                    local k = k - 1

                    net.Start("ChangeBodygroup")
                    net.WriteInt(k, 32)
                    net.WriteInt(j - 1, 32)
                    net.SendToServer()

                    pm.Entity:SetBodygroup(k, j - 1)
                end)

                local x = (j - 1) * 50

                y = 5

                if j > 10 then
                    pnl:SetTall(PD.H(85))
                    x = (j - 11) * 50

                    y = 45
                end

                bodygroupButton:SetPos(PD.W(5 + x), PD.H(y))
                bodygroupButton:SetSize(PD.W(35), PD.H(35))
            end
        end
    end

    local save = PD.Button("Save", sub_panel, function()
        PD.Entity.Umkleide:Save()
    end)
    save:Dock(BOTTOM)

    local load = PD.Button("Load", sub_panel, function()
        PD.Entity.Umkleide:Load()
    end)
    load:Dock(BOTTOM)
end

