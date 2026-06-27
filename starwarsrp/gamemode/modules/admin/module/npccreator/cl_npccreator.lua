-- NPC Creator - eigene NPC-Vorlagen erstellen, bearbeiten und spawnen

PD.NPCCreator = PD.NPCCreator or {}
PD.NPCCreator.Listeners = PD.NPCCreator.Listeners or {}

-- One-shot request/response: queues callback(s), fires + clears them on the next reply.
function PD.NPCCreator.RequestTemplates(callback)
    if isfunction(callback) then
        table.insert(PD.NPCCreator.Listeners, callback)
    end

    net.Start("PD.NPCCreator.RequestTemplates")
    net.SendToServer()
end

net.Receive("PD.NPCCreator.Templates", function()
    local templates = net.ReadTable()
    local listeners = PD.NPCCreator.Listeners
    PD.NPCCreator.Listeners = {}

    for _, cb in ipairs(listeners) do
        cb(templates)
    end
end)

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
        model = "models/Combine_Soldier.mdl",
        weapon = "weapon_pistol",
        health = 150,
        alignment = "hostile",
        attackType = "ranged",
        damage = 14,
        sightRange = 1800,
        attackCooldown = 1.2,
        aimSkill = "realistic",
        canMove = true,
        canRotate = true,
        isSquadLeader = false,
        childTemplate = "",
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
        if not IsValid(listScroll) then return end
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
        if not IsValid(editorPanel) then return end
        editorPanel:Clear()

        local widgets = {}
        local scroll = PD.Scroll(editorPanel)

        widgets.name = PD.TextEntry(scroll, "Name", data.name)
        widgets.model = PD.TextEntry(scroll, "Modellpfad", data.model)
        widgets.weapon = PD.TextEntry(scroll, "Waffenklasse (z.B. weapon_pistol, leer = keine)", data.weapon)

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

        -- Squad Leader Sektion
        local squadSection
        widgets.isSquadLeader = PD.Checkbox(scroll, "Ist Squad Leader (spawnt eigene Truppe)", data.isSquadLeader, function(value)
            widgets.isSquadLeader._pdValue = value
            if IsValid(squadSection) then
                squadSection:SetVisible(value)
            end
        end)
        widgets.isSquadLeader._pdValue = data.isSquadLeader

        squadSection = vgui.Create("DPanel", scroll)
        squadSection:Dock(TOP)
        squadSection:SetTall(PD.H(110))
        squadSection:SetVisible(data.isSquadLeader)
        squadSection.Paint = function() end

        widgets.squadSize = PD.Slider(squadSection, "Squad-Größe", 1, 9, data.squadSize, function() end)

        widgets.childTemplate = PD.Dropdown(squadSection, data.childTemplate ~= "" and data.childTemplate or "- Standard -", function(text, value)
            widgets.childTemplate._pdValue = value
        end)
        widgets.childTemplate._pdValue = data.childTemplate
        widgets.childTemplate:AddOption("- Standard -", "")
        for name in SortedPairs(templates) do
            if name ~= currentName then
                widgets.childTemplate:AddOption(name, name)
            end
        end

        local function CollectFormData()
            return {
                name = widgets.name:GetValue(),
                model = widgets.model:GetValue(),
                weapon = widgets.weapon:GetValue(),
                health = widgets.health:GetValue(),
                alignment = widgets.alignment._pdValue,
                attackType = widgets.attackType._pdValue,
                damage = widgets.damage:GetValue(),
                sightRange = widgets.sightRange:GetValue(),
                attackCooldown = widgets.attackCooldown:GetValue(),
                aimSkill = widgets.aimSkill._pdValue,
                canMove = widgets.canMove._pdValue,
                canRotate = widgets.canRotate._pdValue,
                isSquadLeader = widgets.isSquadLeader._pdValue,
                childTemplate = widgets.childTemplate._pdValue,
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

    RenderEditor(DefaultTemplate())

    PD.NPCCreator.RequestTemplates(function(list)
        if not IsValid(base) then return end
        templates = list
        RefreshList()
    end)
end

-- Namensschild über NPCs, die über den Creator einen Namen bekommen haben
hook.Add("HUDPaint", "PD.NPCCreator.NameTags", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not PD.Theme then return end

    for _, npc in ipairs(ents.FindByClass("deadshot_npc")) do
        if not IsValid(npc) then continue end

        local name = npc:GetNWString("PD_NPCName", "")
        if name == "" then continue end
        if ply:GetPos():DistToSqr(npc:GetPos()) > 1500 * 1500 then continue end

        local screenPos = (npc:GetPos() + Vector(0, 0, 80)):ToScreen()
        if not screenPos.visible then continue end

        draw.DrawText(name, "MLIB.14", screenPos.x, screenPos.y, PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
    end
end)
