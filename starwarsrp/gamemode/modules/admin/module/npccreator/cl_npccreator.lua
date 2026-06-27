-- NPC Creator - eigene NPC-Vorlagen erstellen, bearbeiten und spawnen

PD.NPCCreator = PD.NPCCreator or {}

local Alignments = {
    { text = "Hostile", value = "hostile" },
    { text = "Neutral", value = "neutral" },
    { text = "Friendly", value = "friendly" },
}

local AttackTypes = {
    { text = "Nahkampf", value = "melee" },
    { text = "Fernkampf", value = "ranged" },
    { text = "Wurfwaffen", value = "thrown" },
}

local AimSkills = {
    { text = "Schlecht", value = "dumb" },
    { text = "Normal", value = "realistic" },
    { text = "Gut", value = "better" },
}

local function LabelFor(list, value, fallback)
    for _, opt in ipairs(list) do
        if opt.value == value then return opt.text end
    end
    return fallback
end

local function DefaultTemplate()
    return {
        name = "Neue NPC",
        base = "deadshot_npc_trooper",
        model = "models/Combine_Soldier.mdl",
        health = 150,
        alignment = "hostile",
        attackType = "ranged",
        damage = 14,
        sightRange = 1800,
        attackCooldown = 1.2,
        aimSkill = "realistic",
        canMove = true,
        canRotate = true,
        squadSize = 9,
    }
end

function PD.NPCCreator.Menu(base)
    if not IsValid(base) then return end
    base:Clear()

    local templates = {}
    local currentName = nil
    local RefreshList, RenderEditor

    -- Header
    local header = vgui.Create("DPanel", base)
    header:Dock(TOP)
    header:SetTall(PD.H(50))
    header:DockMargin(0, 0, 0, PD.H(10))
    header.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
        surface.SetDrawColor(PD.Theme.Colors.AccentRed)
        surface.DrawRect(0, 0, PD.W(4), h)
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(PD.W(4), 0, w - PD.W(4), 1)
        surface.DrawRect(PD.W(4), h - 1, w - PD.W(4), 1)
        draw.DrawText("NPC CREATOR", "MLIB.18", PD.W(20), h / 2 - PD.H(9), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
    end

    local body = vgui.Create("DPanel", base)
    body:Dock(FILL)
    body.Paint = function() end

    -- Linke Liste: gespeicherte Vorlagen
    local listPanel = vgui.Create("DPanel", body)
    listPanel:Dock(LEFT)
    listPanel:SetWide(PD.W(220))
    listPanel:DockMargin(0, 0, PD.W(10), 0)
    listPanel.Paint = function(s, w, h)
        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
    end

    local newBtn = PD.Button("+ Neue NPC", listPanel, function()
        currentName = nil
        RenderEditor(DefaultTemplate())
    end)
    newBtn:Dock(TOP)
    newBtn:SetTall(PD.H(40))
    newBtn:DockMargin(PD.W(5), PD.H(5), PD.W(5), PD.H(5))
    newBtn:SetAccentColor(PD.Theme.Colors.AccentBlue)

    local listScroll = PD.Scroll(listPanel)

    -- Rechts: Editor
    local editorPanel = vgui.Create("DPanel", body)
    editorPanel:Dock(FILL)
    editorPanel.Paint = function() end

    RefreshList = function()
        listScroll:GetCanvas():Clear()

        for name in SortedPairs(templates) do
            local btn = PD.Button(name, listScroll, function()
                currentName = name
                RenderEditor(table.Copy(templates[name]))
            end)
            btn:Dock(TOP)
            btn:SetTall(PD.H(36))
        end
    end

    RenderEditor = function(data)
        editorPanel:Clear()

        local widgets = {}
        local scroll = PD.Scroll(editorPanel)

        widgets.name = PD.TextEntry(scroll, "Name", data.name)

        widgets.base = PD.Dropdown(scroll, data.base == "deadshot_npc_squad_leader" and "Squad Leader" or "Trooper", function(text, value)
            widgets.base._pdValue = value
            if IsValid(widgets.squadSize) then
                widgets.squadSize:SetVisible(value == "deadshot_npc_squad_leader")
            end
        end)
        widgets.base._pdValue = data.base
        widgets.base:AddOption("Trooper", "deadshot_npc_trooper")
        widgets.base:AddOption("Squad Leader", "deadshot_npc_squad_leader")

        widgets.model = PD.TextEntry(scroll, "Modellpfad", data.model)

        widgets.health = PD.Slider(scroll, "HP", 1, 1000, data.health, function() end)

        widgets.alignment = PD.Dropdown(scroll, LabelFor(Alignments, data.alignment, "Hostile"), function(text, value)
            widgets.alignment._pdValue = value
        end)
        widgets.alignment._pdValue = data.alignment
        for _, opt in ipairs(Alignments) do widgets.alignment:AddOption(opt.text, opt.value) end

        widgets.attackType = PD.Dropdown(scroll, LabelFor(AttackTypes, data.attackType, "Fernkampf"), function(text, value)
            widgets.attackType._pdValue = value
        end)
        widgets.attackType._pdValue = data.attackType
        for _, opt in ipairs(AttackTypes) do widgets.attackType:AddOption(opt.text, opt.value) end

        widgets.damage = PD.Slider(scroll, "Schaden", 1, 200, data.damage, function() end)
        widgets.sightRange = PD.Slider(scroll, "Sichtweite", 200, 5000, data.sightRange, function() end)
        widgets.attackCooldown = PD.Slider(scroll, "Angriffstempo (Cooldown Sek.)", 0.1, 5, data.attackCooldown, function() end)

        widgets.aimSkill = PD.Dropdown(scroll, LabelFor(AimSkills, data.aimSkill, "Normal"), function(text, value)
            widgets.aimSkill._pdValue = value
        end)
        widgets.aimSkill._pdValue = data.aimSkill
        for _, opt in ipairs(AimSkills) do widgets.aimSkill:AddOption(opt.text, opt.value) end

        widgets.canMove = PD.Dropdown(scroll, data.canMove and "Beweglich" or "Statisch", function(text, value)
            widgets.canMove._pdValue = value
        end)
        widgets.canMove._pdValue = data.canMove
        widgets.canMove:AddOption("Beweglich", true)
        widgets.canMove:AddOption("Statisch", false)

        widgets.canRotate = PD.Dropdown(scroll, data.canRotate and "Drehend" or "Fest ausgerichtet", function(text, value)
            widgets.canRotate._pdValue = value
        end)
        widgets.canRotate._pdValue = data.canRotate
        widgets.canRotate:AddOption("Drehend", true)
        widgets.canRotate:AddOption("Fest ausgerichtet", false)

        widgets.squadSize = PD.Slider(scroll, "Squad-Größe (nur Squad Leader)", 1, 9, data.squadSize, function() end)
        widgets.squadSize:SetVisible(data.base == "deadshot_npc_squad_leader")

        local function CollectFormData()
            return {
                name = widgets.name:GetValue(),
                base = widgets.base._pdValue,
                model = widgets.model:GetValue(),
                health = widgets.health:GetValue(),
                alignment = widgets.alignment._pdValue,
                attackType = widgets.attackType._pdValue,
                damage = widgets.damage:GetValue(),
                sightRange = widgets.sightRange:GetValue(),
                attackCooldown = widgets.attackCooldown:GetValue(),
                aimSkill = widgets.aimSkill._pdValue,
                canMove = widgets.canMove._pdValue,
                canRotate = widgets.canRotate._pdValue,
                squadSize = widgets.squadSize:GetValue(),
            }
        end

        -- Buttons
        local buttonContainer = vgui.Create("DPanel", editorPanel)
        buttonContainer:Dock(BOTTOM)
        buttonContainer:SetTall(PD.H(50))
        buttonContainer.Paint = function() end

        local saveBtn = PD.Button("Speichern", buttonContainer, function()
            net.Start("PD.NPCCreator.Save")
            net.WriteString(currentName or "")
            net.WriteTable(CollectFormData())
            net.SendToServer()
            surface.PlaySound("buttons/button14.wav")
        end)
        saveBtn:Dock(LEFT)
        saveBtn:SetWide(PD.W(140))
        saveBtn:SetAccentColor(PD.Theme.Colors.StatusActive)

        local spawnBtn = PD.Button("Spawnen", buttonContainer, function()
            net.Start("PD.NPCCreator.Spawn")
            net.WriteTable(CollectFormData())
            net.SendToServer()
            PD.Popup("NPC wird gespawnt...", PD.Theme.Colors.StatusActive)
            surface.PlaySound("buttons/button14.wav")
        end)
        spawnBtn:Dock(LEFT)
        spawnBtn:SetWide(PD.W(140))
        spawnBtn:DockMargin(PD.W(10), 0, 0, 0)
        spawnBtn:SetAccentColor(PD.Theme.Colors.AccentBlue)

        if currentName then
            local deleteBtn = PD.Button("Löschen", buttonContainer, function()
                net.Start("PD.NPCCreator.Delete")
                net.WriteString(currentName)
                net.SendToServer()
                currentName = nil
                RenderEditor(DefaultTemplate())
            end)
            deleteBtn:Dock(RIGHT)
            deleteBtn:SetWide(PD.W(120))
            deleteBtn:SetAccentColor(PD.Theme.Colors.StatusCritical)
        end
    end

    net.Receive("PD.NPCCreator.Templates", function()
        templates = net.ReadTable()
        RefreshList()
    end)

    RenderEditor(DefaultTemplate())

    net.Start("PD.NPCCreator.RequestTemplates")
    net.SendToServer()
end

-- Namensschild über NPCs, die über den Creator einen Namen bekommen haben
hook.Add("HUDPaint", "PD.NPCCreator.NameTags", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not PD.Theme then return end

    for _, npc in ipairs(ents.FindByClass("deadshot_npc_*")) do
        if not IsValid(npc) then continue end

        local name = npc:GetNWString("PD_NPCName", "")
        if name == "" then continue end
        if ply:GetPos():DistToSqr(npc:GetPos()) > 1500 * 1500 then continue end

        local screenPos = (npc:GetPos() + Vector(0, 0, 80)):ToScreen()
        if not screenPos.visible then continue end

        draw.DrawText(name, "MLIB.14", screenPos.x, screenPos.y, PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
    end
end)
