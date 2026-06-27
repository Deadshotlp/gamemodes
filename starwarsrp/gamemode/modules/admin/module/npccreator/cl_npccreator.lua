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

local SurrenderBehaviors = {
    { text = "Fliehen", value = "flee" },
    { text = "Ergeben (stehenbleiben)", value = "surrender" },
}

local function LabelFor(list, value, fallback)
    for _, opt in ipairs(list) do
        if opt.value == value then return opt.text end
    end
    return fallback
end

local function FactionSetToString(set)
    local names = {}
    for name in pairs(set or {}) do
        table.insert(names, name)
    end
    table.sort(names)
    return table.concat(names, ", ")
end

local function DefaultTemplate()
    return {
        name = "Neue NPC",
        model = "models/Combine_Soldier.mdl",
        weapon = "weapon_pistol",
        health = 150,
        alignment = "hostile",
        attackType = "ranged",
        sightRange = 1800,
        aimSkill = "realistic",
        canMove = true,
        canRotate = true,
        seeksCover = true,
        faction = "",
        hostileFactions = "",
        canSurrender = false,
        surrenderHealthRatio = 0.25,
        surrenderBehavior = "flee",
        patrolRoute = "",
        spawnsTroop = false,
        troopSize = 9,
        childTemplate = "",
        isSquadLeader = false,
        maxSquadSize = 9,
        commandClaimRadius = 1000,
        usageCount = 0,
        lastUsedBy = "",
        lastUsedAt = "",
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

    local espBtn = PD.Button(PD.NPCCreator.ESPEnabled and "ESP: AN" or "ESP: AUS", header, function()
        PD.NPCCreator.ESPEnabled = not PD.NPCCreator.ESPEnabled
    end)
    espBtn:SetSize(PD.W(110), PD.H(30))
    espBtn:SetPos(header:GetWide() - PD.W(120), PD.H(10))
    espBtn.Think = function(s)
        s:SetText(PD.NPCCreator.ESPEnabled and "ESP: AN" or "ESP: AUS")
        s:SetPos(header:GetWide() - PD.W(120), PD.H(10))
    end

    local body = vgui.Create("DPanel", base)
    body:Dock(FILL)
    body.Paint = function() end

    -- Linke Liste: gespeicherte Vorlagen
    local listPanel = vgui.Create("DPanel", body)
    listPanel:Dock(LEFT)
    listPanel:SetWide(PD.W(240))
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
            local tpl = templates[name]

            local btn = PD.Button(name, listScroll, function()
                currentName = name
                RenderEditor(table.Copy(templates[name]))
            end)
            btn:Dock(TOP)
            btn:SetTall(PD.H(46))

            local subtitle = "Benutzt: " .. (tpl.usageCount or 0)
            if tpl.lastUsedBy and tpl.lastUsedBy ~= "" then
                subtitle = subtitle .. " | zuletzt: " .. tpl.lastUsedBy .. " (" .. tpl.lastUsedAt .. ")"
            end

            local oldPaint = btn.Paint
            btn.Paint = function(s, w, h)
                oldPaint(s, w, h)
                draw.DrawText(subtitle, "MLIB.12", PD.W(15), h - PD.H(16), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
            end
        end
    end

    RenderEditor = function(data)
        if not IsValid(editorPanel) then return end
        editorPanel:Clear()

        local widgets = {}
        local scroll = PD.Scroll(editorPanel)

        widgets.name = PD.TextEntry(scroll, "Name", data.name)
        widgets.model = PD.TextEntry(scroll, "Modellpfad", data.model)
        widgets.weapon = PD.TextEntry(scroll, "Waffenklasse (z.B. weapon_pistol, leer = keine) - regelt auch Schaden/Feuerrate", data.weapon)

        widgets.health = PD.Slider(scroll, "HP", 1, 1000, data.health, function() end)
        widgets.sightRange = PD.Slider(scroll, "Sichtweite", 200, 5000, data.sightRange, function() end)

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

        widgets.seeksCover = PD.Checkbox(scroll, "Sucht Deckung", data.seeksCover, function(value)
            widgets.seeksCover._pdValue = value
        end)
        widgets.seeksCover._pdValue = data.seeksCover

        -- Fraktionen
        widgets.faction = PD.TextEntry(scroll, "Eigene Fraktion (leer = keine)", data.faction)
        widgets.hostileFactions = PD.TextEntry(scroll, "Feindliche Fraktionen (kommagetrennt)",
            istable(data.hostileFactions) and FactionSetToString(data.hostileFactions) or (data.hostileFactions or ""))

        -- Ergeben/Fliehen
        local surrenderSection
        widgets.canSurrender = PD.Checkbox(scroll, "Darf sich ergeben/fliehen bei wenig HP", data.canSurrender, function(value)
            widgets.canSurrender._pdValue = value
            if IsValid(surrenderSection) then surrenderSection:SetVisible(value) end
        end)
        widgets.canSurrender._pdValue = data.canSurrender

        surrenderSection = vgui.Create("DPanel", scroll)
        surrenderSection:Dock(TOP)
        surrenderSection:SetTall(PD.H(130))
        surrenderSection:SetVisible(data.canSurrender)
        surrenderSection.Paint = function() end

        widgets.surrenderHealthRatio = PD.Slider(surrenderSection, "HP-Schwelle (%)", 1, 100, (data.surrenderHealthRatio or 0.25) * 100, function() end)

        widgets.surrenderBehavior = PD.Dropdown(surrenderSection, LabelFor(SurrenderBehaviors, data.surrenderBehavior, "Fliehen"), function(text, value)
            widgets.surrenderBehavior._pdValue = value
        end)
        widgets.surrenderBehavior._pdValue = data.surrenderBehavior
        for _, opt in ipairs(SurrenderBehaviors) do widgets.surrenderBehavior:AddOption(opt.text, opt.value) end

        -- Patrol-Route
        widgets.patrolRoute = PD.Dropdown(scroll, data.patrolRoute ~= "" and data.patrolRoute or "- Keine -", function(text, value)
            widgets.patrolRoute._pdValue = value
        end)
        widgets.patrolRoute._pdValue = data.patrolRoute
        widgets.patrolRoute:AddOption("- Keine -", "")
        if PD.PatrolRoutes then
            PD.PatrolRoutes.RequestRoutes(function(names)
                if not IsValid(widgets.patrolRoute) then return end
                for _, routeName in ipairs(names) do
                    widgets.patrolRoute:AddOption(routeName, routeName)
                end
            end)
        end

        -- Spawnt Trupp
        local troopSection
        widgets.spawnsTroop = PD.Checkbox(scroll, "Spawnt Trupp (eigene NPCs beim Spawnen)", data.spawnsTroop, function(value)
            widgets.spawnsTroop._pdValue = value
            if IsValid(troopSection) then troopSection:SetVisible(value) end
        end)
        widgets.spawnsTroop._pdValue = data.spawnsTroop

        troopSection = vgui.Create("DPanel", scroll)
        troopSection:Dock(TOP)
        troopSection:SetTall(PD.H(160))
        troopSection:SetVisible(data.spawnsTroop)
        troopSection.Paint = function() end

        widgets.troopSize = PD.Slider(troopSection, "Trupp-Größe", 1, 9, data.troopSize, function() end)

        widgets.childTemplate = PD.Dropdown(troopSection, data.childTemplate ~= "" and data.childTemplate or "- Standard -", function(text, value)
            widgets.childTemplate._pdValue = value
        end)
        widgets.childTemplate._pdValue = data.childTemplate
        widgets.childTemplate:AddOption("- Standard -", "")
        for name in SortedPairs(templates) do
            if name ~= currentName then
                widgets.childTemplate:AddOption(name, name)
            end
        end

        -- Squad Leader
        local leaderSection
        widgets.isSquadLeader = PD.Checkbox(scroll, "Ist Squad Leader (übernimmt Kommando über unkommandierte NPCs)", data.isSquadLeader, function(value)
            widgets.isSquadLeader._pdValue = value
            if IsValid(leaderSection) then leaderSection:SetVisible(value) end
        end)
        widgets.isSquadLeader._pdValue = data.isSquadLeader

        leaderSection = vgui.Create("DPanel", scroll)
        leaderSection:Dock(TOP)
        leaderSection:SetTall(PD.H(160))
        leaderSection:SetVisible(data.isSquadLeader)
        leaderSection.Paint = function() end

        widgets.maxSquadSize = PD.Slider(leaderSection, "Max. Squad-Größe", 1, 20, data.maxSquadSize, function() end)
        widgets.commandClaimRadius = PD.Slider(leaderSection, "Kommando-Radius", 100, 4000, data.commandClaimRadius, function() end)

        local function CollectFormData()
            return {
                name = widgets.name:GetValue(),
                model = widgets.model:GetValue(),
                weapon = widgets.weapon:GetValue(),
                health = widgets.health:GetValue(),
                sightRange = widgets.sightRange:GetValue(),
                alignment = widgets.alignment._pdValue,
                attackType = widgets.attackType._pdValue,
                aimSkill = widgets.aimSkill._pdValue,
                canMove = widgets.canMove._pdValue,
                canRotate = widgets.canRotate._pdValue,
                seeksCover = widgets.seeksCover._pdValue,
                faction = widgets.faction:GetValue(),
                hostileFactions = widgets.hostileFactions:GetValue(),
                canSurrender = widgets.canSurrender._pdValue,
                surrenderHealthRatio = widgets.surrenderHealthRatio:GetValue() / 100,
                surrenderBehavior = widgets.surrenderBehavior._pdValue,
                patrolRoute = widgets.patrolRoute._pdValue,
                spawnsTroop = widgets.spawnsTroop._pdValue,
                troopSize = widgets.troopSize:GetValue(),
                childTemplate = widgets.childTemplate._pdValue,
                isSquadLeader = widgets.isSquadLeader._pdValue,
                maxSquadSize = widgets.maxSquadSize:GetValue(),
                commandClaimRadius = widgets.commandClaimRadius:GetValue(),
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

----------------------------------------------------------------
-- Namensschild + Admin-Debug-Overlay (ESP)
----------------------------------------------------------------

local StateColors = {
    advance = Color(255, 80, 80),
    hold = Color(255, 200, 0),
    retreat = Color(0, 150, 255),
}

hook.Add("HUDPaint", "PD.NPCCreator.NameTags", function()
    local ply = LocalPlayer()
    if not IsValid(ply) or not PD.Theme then return end

    local espOn = PD.NPCCreator.ESPEnabled and ply:IsAdmin()

    for _, npc in ipairs(ents.FindByClass("deadshot_npc")) do
        if not IsValid(npc) then continue end

        local distSqr = ply:GetPos():DistToSqr(npc:GetPos())
        local name = npc:GetNWString("PD_NPCName", "")

        if name ~= "" and distSqr <= 1500 * 1500 then
            local screenPos = (npc:GetPos() + Vector(0, 0, 80)):ToScreen()
            if screenPos.visible then
                draw.DrawText(name, "MLIB.14", screenPos.x, screenPos.y, PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
            end
        end

        if espOn and distSqr <= 3000 * 3000 then
            local screenPos = (npc:GetPos() + Vector(0, 0, 60)):ToScreen()
            if screenPos.visible then
                local state = npc.IsSquadLeader and (npc.SquadState or "hold") or (IsValid(npc.SquadLeader) and "member" or "solo")
                local lines = {
                    (npc.Faction ~= "" and npc.Faction or "keine Fraktion") .. " | " .. (npc.Alignment or "?"),
                    "Status: " .. tostring(state),
                    "Sicht: " .. tostring(npc.SightRange),
                }

                for i, line in ipairs(lines) do
                    draw.DrawText(line, "MLIB.12", screenPos.x, screenPos.y + (i - 1) * 14, Color(0, 255, 120), TEXT_ALIGN_CENTER)
                end
            end
        end
    end
end)
