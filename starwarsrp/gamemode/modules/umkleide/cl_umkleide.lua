PD.Entity = PD.Entity or {}
PD.Entity.Umkleide = PD.Entity.Umkleide or {}
PD.Entity.Umkleide.Config = {
    rot = 110,
    fov = 20,
    xmod = 0,
    ymod = 0
}

function PD.Entity.Umkleide:Save()
    local tbl = {
        model = LocalPlayer():GetModel(),
        bodygroups = {}
    }

    for _, i in pairs(LocalPlayer():GetBodyGroups()) do
        table.insert(tbl.bodygroups, LocalPlayer():GetBodygroup(_))
    end

    if not file.IsDir("modules/umkleide", "DATA") then
        file.CreateDir("modules/umkleide")
    end

    if file.Exists("modules/umkleide/" .. LocalPlayer():Nick() .. ".json", "DATA") then
        file.Delete("modules/umkleide/" .. LocalPlayer():Nick() .. ".json")
    end

    file.Write("modules/umkleide/" .. LocalPlayer():Nick() .. ".json", util.TableToJSON(tbl, true))
end

function PD.Entity.Umkleide:Load()
    local tbl = {}

    if file.Exists("modules/umkleide/" .. LocalPlayer():Nick() .. ".json", "DATA") then
        tbl = util.JSONToTable(file.Read("modules/umkleide/" .. LocalPlayer():Nick() .. ".json", "DATA"))
    end

    if tbl.model == LocalPlayer():GetModel() then
        for k, v in pairs(tbl.bodygroups) do
            net.Start("ChangeBodygroup")
            net.WriteInt(k, 32)
            net.WriteInt(v, 32)
            net.SendToServer()
        end
    end

    if not IsValid(mainFrame) then return end

    timer.Simple(0.2, function()
        mainFrame:GetContentPanel():Clear()
        PD.Entity.Umkleide:ShowAttachments(mainFrame, LocalPlayer())
    end)
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

    local ply = LocalPlayer()

    PD.Entity.Umkleide:ShowAttachments(mainFrame, ply)
end

function PD.Entity.Umkleide:ShowAttachments(mainFrame, ply)
    local bodygroups = ply:GetBodyGroups()
    --local activeArmor = ply:PDGetArmor()

    local sub_panel = PD.Panel(mainFrame:GetContentPanel(), {title = "Model"})
    sub_panel:SetSize(mainFrame:GetWide() / 2, mainFrame:GetTall())
    sub_panel:Dock(LEFT)
    sub_panel:DockMargin(PD.W(0), PD.H(0), PD.W(0), PD.H(0))

    local pm = PD.Model(sub_panel, ply:GetModel(), PD.W(0), PD.H(0), mainFrame:GetWide() / 2, mainFrame:GetTall(), {})
    pm.rot = PD.Entity.Umkleide.Config.rot
    pm.fov = PD.Entity.Umkleide.Config.fov
    pm.xmod = PD.Entity.Umkleide.Config.xmod
    pm.ymod = PD.Entity.Umkleide.Config.ymod

    function pm:OnCursorExited( )
        PD.Entity.Umkleide.Config = {
            rot = self.rot,
            fov = self.fov,
            xmod = self.xmod,
            ymod = self.ymod
        }
    end

    local sub_panel = PD.Panel(mainFrame:GetContentPanel(), {text = "Attachments"})
    sub_panel:Dock(FILL)
    sub_panel:DockMargin(PD.W(5), PD.H(0), PD.W(0), PD.H(0))

    local modelSelect = PD.Dropdown(sub_panel, player_manager.TranslateToPlayerModelName(ply:GetModel()) or "Model nicht Abrufbar", function(text, value)
        pm:SetModel(value)
        net.Start("ChangeModel")
        net.WriteString(value)
        net.SendToServer()
    end, {})

    local name, tbl = ply:GetJob()
    for k, v in pairs(tbl.model) do
        if string.lower(modelSelect:GetValue()) == string.lower(v) then continue end
        modelSelect:AddOption(player_manager.TranslateToPlayerModelName(v), v)
    end

    for k, v in SortedPairs(PD.JOBS.GetUnit(false, true)) do
        if v.name == tbl.unit then
            for _, v in pairs(v.model) do
                if string.lower(modelSelect:GetValue()) == string.lower(v) then continue end
                modelSelect:AddOption(player_manager.TranslateToPlayerModelName(v), v)
            end
            continue
        end
    end

    local ScrollList = PD.Scroll(sub_panel)

    -- Check ob etwas entfernt wurde
    -- if table.Count(bodygroups) ~= table.Count(LocalPlayer():GetBodyGroups()) then
    --     local lbl = PD.Label("Zieh deine Rüstung an um weitere Attachments zu bekommen!", ScrollList, Color(255, 0, 0))
    -- end

    for k, v in pairs(bodygroups) do
        pm.Entity:SetBodygroup(k, ply:GetBodygroup(k))

        if not bodygroups[k].submodels[1] then continue end

        if (bodygroups[k].id >= 0) and (bodygroups[k].num >= 0) then
            local bodygroupName = PD.Label(bodygroups[k].name .. " | ID: " .. bodygroups[k].id .. " k:" .. k, ScrollList)
            bodygroupName:Dock(TOP)

            local y = (k - 1) * 75
            bodygroupName:SetPos(PD.W(5), PD.H(y - 60))
            bodygroupName:SetSize(PD.W(500), PD.H(25))

            local pnl = PD.Panel(ScrollList)
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

