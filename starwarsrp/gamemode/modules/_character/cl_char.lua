PD.Char = PD.Char or {}
PD.Char.Data = PD.Char.Data or {}

local txt = ""

net.Receive("PD.Char.Synccl", function()
    PD.Char.Data = net.ReadTable() or {}
end)

net.Receive("PD.Char.Open", function()
    PD.Char:Menu()
end)

net.Receive("PD.Char.JobChange", function()
    local ply = net.ReadEntity()
    local jobID = net.ReadString()
    local jobTbl = net.ReadTable()
    local allplayerjobs = net.ReadTable()

    if IsValid(ply) then
        ply:SetJob(jobID, jobTbl)
    end

    for k, v in SortedPairs(allplayerjobs or {}) do
        local target = player.GetBySteamID64(k)
        if IsValid(target) then
            target:SetJob(v.jobID, v.jobTable)
        end
    end

    print("Jobwechsel erhalten: " .. tostring(jobID))
end)

net.Receive("PD.Char.SetJobFunction", function()
    local ply = net.ReadEntity()
    local jobID = net.ReadString()
    local jobTbl = net.ReadTable()
    local allplayerjobs = net.ReadTable()

    if IsValid(ply) then
        ply:SetJob(jobID, jobTbl)
    end

    for k, v in SortedPairs(allplayerjobs or {}) do
        local target = player.GetBySteamID64(k)
        if IsValid(target) then
            target:SetJob(v.jobID, v.jobTable)
        end
    end
end)

local function ShowError(text, panel, time)
    if not PD.Theme then return end

    local scrw, scrh = ScrW(), ScrH()

    local errorPanel = vgui.Create("DPanel", panel)
    errorPanel:SetSize(PD.W(600), PD.H(80))
    errorPanel:SetPos(scrw / 2 - PD.W(300), PD.H(80))
    errorPanel:SetZPos(999)

    local barStatus = 0
    local startTime = SysTime()

    errorPanel.Paint = function(s, w, h)
        barStatus = math.Clamp((SysTime() - startTime) / time, 0, 1)

        draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)

        surface.SetDrawColor(PD.Theme.Colors.StatusCritical)
        surface.DrawRect(0, 0, w, PD.H(3))

        draw.RoundedBox(0, 0, h - PD.H(4), w * (1 - barStatus), PD.H(4), PD.Theme.Colors.StatusCritical)

        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        draw.DrawText("⚠", "MLIB.30", PD.W(25), h / 2 - PD.H(15), PD.Theme.Colors.StatusCritical, TEXT_ALIGN_CENTER)
        draw.DrawText(text, "MLIB.18", PD.W(60), h / 2 - PD.H(9), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
    end

    surface.PlaySound("buttons/button10.wav")

    timer.Simple(time + 0.2, function()
        if IsValid(errorPanel) then
            errorPanel:Remove()
        end
    end)
end

local page = 1

function PD.Char:Menu(close)
    local scrw, scrh = ScrW(), ScrH()

    if IsValid(PD.Char.CharBase) then
        PD.Char.CharBase:Remove()
    end

    PD.Char.CharBase = vgui.Create("DFrame")
    local CharBase = PD.Char.CharBase

    CharBase:SetSize(scrw, scrh)
    CharBase:Center()
    CharBase:SetTitle("")
    CharBase:ShowCloseButton(false)
    CharBase:SetDraggable(false)
    CharBase:MakePopup()

    CharBase.Paint = function(s, w, h)
        surface.SetDrawColor(255, 255, 255, 255)
        local bgMat = Material(PD.Char.Background or "")
        if bgMat and not bgMat:IsError() then
            surface.SetMaterial(bgMat)
            surface.DrawTexturedRect(0, 0, w, h)
        else
            draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
        end

        draw.RoundedBox(0, 0, 0, w, h, Color(10, 12, 15, 200))
        PD.DrawGridPattern(0, 0, w, h, PD.W(50), PD.ColorAlpha(PD.Theme.Colors.BackgroundLight, 0.05))

        draw.RoundedBox(0, 0, 0, w, PD.H(80), PD.Theme.Colors.BackgroundDark)
        surface.SetDrawColor(PD.Theme.Colors.AccentRed)
        surface.DrawRect(0, PD.H(77), w, PD.H(3))

        draw.DrawText("IMPERIAL PERSONNEL SYSTEM", "MLIB.28", w / 2, PD.H(25), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
        draw.DrawText("CHARACTER SELECTION", "MLIB.14", w / 2, PD.H(55), PD.Theme.Colors.AccentGray, TEXT_ALIGN_CENTER)

        draw.RoundedBox(0, 0, h - PD.H(100), w, PD.H(100), PD.Theme.Colors.BackgroundDark)
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawRect(0, h - PD.H(100), w, 1)
    end

    local charPanels = {}

    local function ClampPage()
        if page < 1 then page = PD.Char.MaxChars end
        if page > PD.Char.MaxChars then page = 1 end
    end

    local function neighborLeft(i)
        return (i - 1 >= 1) and (i - 1) or PD.Char.MaxChars
    end

    local function neighborRight(i)
        return (i + 1 <= PD.Char.MaxChars) and (i + 1) or 1
    end

    local function GetFactionTables(data)
        local jobs = PD.JOBS and PD.JOBS.Jobs or {}
        local faction = data and data.faction or {}
        local unitTable = jobs[faction.unit] or {}
        local subUnitTable = unitTable.subunits and unitTable.subunits[faction.subunit] or {}
        local jobTable = subUnitTable.jobs and subUnitTable.jobs[faction.job] or {}
        return unitTable, subUnitTable, jobTable
    end

    local centerW, centerH = PD.W(400), PD.H(550)
    local sideScale = 0.85
    local sideW, sideH = math.floor(centerW * sideScale), math.floor(centerH * sideScale)
    local gap = PD.W(40)

    local charIDLabel = vgui.Create("DPanel", CharBase)
    charIDLabel:SetSize(PD.W(500), PD.H(60))
    charIDLabel.labelText = ""
    charIDLabel.Paint = function(s, w, h)
        if s.labelText and s.labelText ~= "" then
            draw.DrawText(s.labelText, "MLIB.28", w / 2, PD.H(10), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
        end
    end

    local infoPanel = vgui.Create("DPanel", CharBase)
    infoPanel:SetSize(PD.W(400), PD.H(120))
    infoPanel:SetVisible(false)
    infoPanel.Paint = function(s, w, h)
        local id = page
        if not PD.Char.Data[id] then return end

        local data = PD.Char.Data[id]
        local unitTable, subUnitTable, jobTable = GetFactionTables(data)

        draw.RoundedBox(0, 0, 0, w, h, PD.ColorAlpha(PD.Theme.Colors.BackgroundDark, 0.9))

        surface.SetDrawColor(PD.Theme.Colors.AccentBlue)
        surface.DrawRect(0, 0, PD.W(3), h)

        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawOutlinedRect(0, 0, w, h, 1)

        draw.DrawText("CHARACTER INFO", "MLIB.12", PD.W(15), PD.H(8), PD.Theme.Colors.AccentGray, TEXT_ALIGN_LEFT)

        local yPos = PD.H(30)
        local lineHeight = PD.H(25)

        draw.DrawText((LANG.CHAR_UI_UNIT or "Unit") .. ":", "MLIB.12", PD.W(15), yPos, PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
        draw.DrawText(unitTable.name or "N/A", "MLIB.14", PD.W(100), yPos - PD.H(2), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)

        draw.DrawText((LANG.CHAR_UI_SUBUNIT or "SubUnit") .. ":", "MLIB.12", PD.W(15), yPos + lineHeight, PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
        draw.DrawText(subUnitTable.name or "N/A", "MLIB.14", PD.W(100), yPos + lineHeight - PD.H(2), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)

        draw.DrawText((LANG.CHAR_UI_JOB or "Job") .. ":", "MLIB.12", PD.W(15), yPos + lineHeight * 2, PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
        draw.DrawText(jobTable.name or "N/A", "MLIB.14", PD.W(100), yPos + lineHeight * 2 - PD.H(2), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
    end

    local actionButton = PD.Button("", CharBase, function() end)
    actionButton:SetSize(PD.W(240), PD.H(55))
    actionButton:SetAccentColor(PD.Theme.Colors.StatusActive)

    local deleteButton = PD.Button(LANG.CHAR_UI_DELETE_CHAR or "LÖSCHEN", CharBase, function()
        local id = page
        if not PD.Char.Data[id] then
            ShowError("Kein Charakter zum Löschen vorhanden!", CharBase, 2)
            return
        end

        local confirmFrame = PD.Frame("CHARAKTER LÖSCHEN?", PD.W(400), PD.H(200), true)
        local content = confirmFrame:GetContentPanel()

        local warning = vgui.Create("DPanel", content)
        warning:Dock(TOP)
        warning:SetTall(PD.H(60))
        warning.Paint = function(s, w, h)
            draw.DrawText("Bist du sicher, dass du diesen", "MLIB.16", w / 2, PD.H(10), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
            draw.DrawText("Charakter löschen möchtest?", "MLIB.16", w / 2, PD.H(32), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
        end

        local btnPanel = vgui.Create("DPanel", content)
        btnPanel:Dock(BOTTOM)
        btnPanel:SetTall(PD.H(50))
        btnPanel.Paint = function() end

        local cancelBtn = PD.Button("ABBRECHEN", btnPanel, function()
            confirmFrame:Remove()
        end)
        cancelBtn:Dock(LEFT)
        cancelBtn:SetWide(PD.W(170))

        local confirmBtn = PD.Button("LÖSCHEN", btnPanel, function()
            net.Start("PD.Char.Delete")
            net.WriteEntity(LocalPlayer())
            net.WriteInt(id, 32)
            net.WriteString(PD.Char.Data[id].name)
            net.SendToServer()

            confirmFrame:Remove()

            if IsValid(CharBase) then
                CharBase:Remove()
            end

            surface.PlaySound("buttons/button14.wav")
        end)
        confirmBtn:Dock(RIGHT)
        confirmBtn:SetWide(PD.W(170))
        confirmBtn:SetAccentColor(PD.Theme.Colors.StatusCritical)
    end)
    deleteButton:SetSize(PD.W(180), PD.H(45))
    deleteButton:SetPos(PD.W(30), scrh - PD.H(75))
    deleteButton:SetAccentColor(PD.Theme.Colors.StatusCritical)

    local function OpenCreateUI(slot)
        CharBase:Clear()

        local panel = vgui.Create("DPanel", CharBase)
        panel:SetSize(PD.W(600), PD.H(450))
        panel:SetPos((scrw - PD.W(600)) / 2, (scrh - PD.H(450)) / 2)
        panel.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)

            surface.SetDrawColor(PD.Theme.Colors.AccentRed)
            surface.DrawRect(0, 0, w, PD.H(3))

            surface.SetDrawColor(PD.Theme.Colors.AccentGray)
            surface.DrawOutlinedRect(0, 0, w, h, 1)

            PD.DrawGridPattern(0, 0, w, h, PD.W(30), PD.ColorAlpha(PD.Theme.Colors.BackgroundLight, 0.08))
        end

        local header = vgui.Create("DPanel", panel)
        header:Dock(TOP)
        header:SetTall(PD.H(70))
        header.Paint = function(s, w, h)
            draw.DrawText(LANG.CHAR_UI_CREATE_CHAR or "CREATE CHARACTER", "MLIB.28", w / 2, PD.H(15), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
            draw.DrawText("SLOT " .. slot, "MLIB.14", w / 2, PD.H(45), PD.Theme.Colors.AccentGray, TEXT_ALIGN_CENTER)
        end

        local content = vgui.Create("DPanel", panel)
        content:Dock(FILL)
        content:DockMargin(PD.W(30), PD.H(20), PD.W(30), PD.H(20))
        content.Paint = function() end

        local nameLabel = vgui.Create("DLabel", content)
        nameLabel:Dock(TOP)
        nameLabel:SetText("CHARACTER NAME")
        nameLabel:SetFont("MLIB.14")
        nameLabel:SetTextColor(PD.Theme.Colors.AccentGray)
        nameLabel:DockMargin(0, 0, 0, PD.H(5))

        local nameEntry = PD.TextEntry(content, "Enter character name...", "")
        nameEntry:Dock(TOP)
        nameEntry:SetTall(PD.H(50))
        nameEntry:DockMargin(0, 0, 0, PD.H(20))

        local infoText = vgui.Create("DPanel", content)
        infoText:Dock(TOP)
        infoText:SetTall(PD.H(80))
        infoText.Paint = function(s, w, h)
            draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundLight)
            surface.SetDrawColor(PD.Theme.Colors.AccentBlue)
            surface.DrawRect(0, 0, PD.W(3), h)

            draw.DrawText("HINWEIS", "MLIB.12", PD.W(15), PD.H(10), PD.Theme.Colors.AccentBlue, TEXT_ALIGN_LEFT)
            draw.DrawText("Gib nur deinen Vornamen ein (ohne Nummer).", "MLIB.14", PD.W(15), PD.H(35), PD.Theme.Colors.Text, TEXT_ALIGN_LEFT)
            draw.DrawText("Deine ID wird automatisch zugewiesen.", "MLIB.12", PD.W(15), PD.H(55), PD.Theme.Colors.TextDim, TEXT_ALIGN_LEFT)
        end

        local btnContainer = vgui.Create("DPanel", panel)
        btnContainer:Dock(BOTTOM)
        btnContainer:SetTall(PD.H(70))
        btnContainer:DockMargin(PD.W(30), 0, PD.W(30), PD.H(20))
        btnContainer.Paint = function() end

        local backBtn = PD.Button("‹ " .. (LANG.GENERIC_BACK or "ZURÜCK"), btnContainer, function()
            if IsValid(CharBase) then
                CharBase:Remove()
            end
            PD.Char:Menu(close or false)
        end)
        backBtn:Dock(LEFT)
        backBtn:SetWide(PD.W(180))

        local createBtn = PD.Button((LANG.CHAR_UI_CREATE_CHAR or "ERSTELLEN") .. " ›", btnContainer, function()
            local name = nameEntry:GetValue()

            if not name or name == "" then
                ShowError("Bitte gib einen Namen ein!", CharBase, 2)
                return
            end

            if #name < (PD.Char.MinName or 3) then
                ShowError("Name zu kurz! (Min. " .. (PD.Char.MinName or 3) .. " Zeichen)", CharBase, 2)
                return
            end

            net.Start("PD.Char.Create")
            net.WriteEntity(LocalPlayer())
            net.WriteString(name)
            net.SendToServer()

            if IsValid(CharBase) then
                CharBase:Remove()
            end

            surface.PlaySound("buttons/button14.wav")
        end)
        createBtn:Dock(RIGHT)
        createBtn:SetWide(PD.W(180))
        createBtn:SetAccentColor(PD.Theme.Colors.StatusActive)
    end

    local function UpdatePage()
        ClampPage()

        local cx = (scrw - centerW) / 2
        local cy = (scrh - centerH) / 2 - PD.H(30)
        local leftIdx = neighborLeft(page)
        local rightIdx = neighborRight(page)

        for idx, pnl in pairs(charPanels) do
            if not IsValid(pnl) then continue end

            if idx ~= page and idx ~= leftIdx and idx ~= rightIdx then
                pnl:SetAlpha(0)
                pnl:SetSize(0, 0)
                pnl:SetPos(cx, cy)
                pnl:SetMouseInputEnabled(false)
            elseif idx == leftIdx then
                pnl:SetSize(sideW, sideH)
                pnl:SetPos(cx - sideW - gap, (scrh - sideH) / 2 - PD.H(30))
                pnl:SetAlpha(80)
                pnl:SetMouseInputEnabled(false)
            elseif idx == rightIdx then
                pnl:SetSize(sideW, sideH)
                pnl:SetPos(cx + centerW + gap, (scrh - sideH) / 2 - PD.H(30))
                pnl:SetAlpha(80)
                pnl:SetMouseInputEnabled(false)
            elseif idx == page then
                pnl:SetSize(centerW, centerH)
                pnl:SetPos(cx, cy)
                pnl:SetAlpha(255)
                pnl:SetMouseInputEnabled(true)
            end
        end

        local id = page
        local nameText = LANG.CHAR_UI_AVAILABLE_CHAR_SLOT or "VERFÜGBARER SLOT"
        if PD.Char.Data[id] then
            nameText = (PD.Char.Data[id].id or "") .. " " .. (PD.Char.Data[id].name or "")
        end
        charIDLabel.labelText = nameText
        charIDLabel:SetPos(scrw / 2 - PD.W(250), PD.H(110))

        local btnText = LANG.CHAR_UI_CREATE_CHAR or "ERSTELLEN"
        if PD.Char.Data[id] then
            local currentName = LocalPlayer():GetNWString("rpname", "")
            local charName = (PD.Char.Data[id].id or "") .. " " .. (PD.Char.Data[id].name or "")
            btnText = (currentName == charName) and (LANG.CHAR_UI_CONTINUE or "FORTSETZEN") or (LANG.CHAR_UI_PLAY or "SPIELEN")
        end
        actionButton:SetText(btnText)
        actionButton:SetPos(scrw / 2 - PD.W(120), scrh - PD.H(75))

        actionButton.DoClick = function()
            local maxSlots = PD.Char.UserGroupChar[LocalPlayer():GetUserGroup()] or 2

            if id > maxSlots then
                ShowError("Dieser Charakterplatz ist gesperrt!", CharBase, 2)
                return
            end

            if not PD.Char.Data[id] then
                OpenCreateUI(id)
                surface.PlaySound("buttons/button14.wav")
                return
            end

            net.Start("PD.Char.Play")
            net.WriteEntity(LocalPlayer())
            net.WriteUInt(id, 32)
            net.SendToServer()

            if IsValid(CharBase) then
                CharBase:Remove()
            end

            surface.PlaySound("buttons/button14.wav")
        end

        infoPanel:SetPos(PD.W(30), scrh - PD.H(230))

        if PD.Char.Data[id] then
            infoPanel:SetVisible(true)
            deleteButton:SetVisible(true)
        else
            infoPanel:SetVisible(false)
            deleteButton:SetVisible(false)
        end
    end

    local leftBtn = PD.Button("‹", CharBase, function()
        page = page - 1
        UpdatePage()
        surface.PlaySound("UI/buttonclick.wav")
    end)
    leftBtn:SetSize(PD.W(50), PD.H(50))
    leftBtn:SetPos(scrw / 2 - PD.W(200), scrh - PD.H(75))

    local rightBtn = PD.Button("›", CharBase, function()
        page = page + 1
        UpdatePage()
        surface.PlaySound("UI/buttonclick.wav")
    end)
    rightBtn:SetSize(PD.W(50), PD.H(50))
    rightBtn:SetPos(scrw / 2 + PD.W(150), scrh - PD.H(75))

    local pageIndicator = vgui.Create("DPanel", CharBase)
    pageIndicator:SetSize(PD.W(200), PD.H(30))
    pageIndicator:SetPos(scrw / 2 - PD.W(100), scrh - PD.H(40))
    pageIndicator.Paint = function(s, w, h)
        local dotSize = PD.W(8)
        local spacing = PD.W(20)
        local totalWidth = (PD.Char.MaxChars * dotSize) + ((PD.Char.MaxChars - 1) * spacing)
        local startX = (w - totalWidth) / 2

        for i = 1, PD.Char.MaxChars do
            local x = startX + (i - 1) * (dotSize + spacing)
            local color = (i == page) and PD.Theme.Colors.AccentRed or PD.Theme.Colors.AccentGray
            draw.RoundedBox(dotSize / 2, x, h / 2 - dotSize / 2, dotSize, dotSize, color)
        end
    end

    for i = 1, PD.Char.MaxChars do
        local data = PD.Char.Data[i]
        local maxSlots = PD.Char.UserGroupChar[LocalPlayer():GetUserGroup()] or 2

        if not data then
            data = {
                name = "Frei",
                id = "",
                rank = "",
                job = { name = "Rekrut", model = CONFIG.BackModel or "", unit = "Rekruten", id = "Rekrut" },
                faction = { unit = "", subunit = "", job = "" },
                money = 0,
                cratedate = 0,
                lastplaytime = 0,
                playtime = 0
            }
        end

        if maxSlots < i then
            data.name = "GESPERRT"
        end

        if data.name == "Frei" then
            local createPanel = vgui.Create("DPanel", CharBase)
            createPanel:SetSize(centerW, centerH)
            createPanel:SetPos((scrw - centerW) / 2, (scrh - centerH) / 2 - PD.H(30))
            createPanel:SetCursor("hand")

            local isHovered = false

            createPanel.Paint = function(s, w, h)
                local bgColor = isHovered and PD.Theme.Colors.BackgroundHover or PD.Theme.Colors.BackgroundDark
                draw.RoundedBox(0, 0, 0, w, h, bgColor)

                local borderColor = isHovered and PD.Theme.Colors.AccentRed or PD.Theme.Colors.AccentGray
                surface.SetDrawColor(borderColor)
                surface.DrawOutlinedRect(0, 0, w, h, 2)

                surface.SetDrawColor(PD.Theme.Colors.AccentRed)
                surface.DrawRect(0, 0, w, PD.H(3))

                draw.DrawText("+", "MLIB.80", w / 2, h / 2 - PD.H(80), isHovered and PD.Theme.Colors.AccentRed or PD.Theme.Colors.AccentGray, TEXT_ALIGN_CENTER)
                draw.DrawText((LANG.CHAR_UI_CREATE_CHAR or "CHARAKTER ERSTELLEN"), "MLIB.20", w / 2, h / 2 + PD.H(20), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
                draw.DrawText("SLOT " .. i, "MLIB.14", w / 2, h / 2 + PD.H(50), PD.Theme.Colors.AccentGray, TEXT_ALIGN_CENTER)
            end

            createPanel.OnCursorEntered = function()
                isHovered = true
                surface.PlaySound("UI/buttonrollover.wav")
            end

            createPanel.OnCursorExited = function()
                isHovered = false
            end

            createPanel.OnMousePressed = function()
                OpenCreateUI(i)
                surface.PlaySound("UI/buttonclick.wav")
            end

            charPanels[i] = createPanel
        elseif data.name == "GESPERRT" then
            local lockedPanel = vgui.Create("DPanel", CharBase)
            lockedPanel:SetSize(centerW, centerH)
            lockedPanel:SetPos((scrw - centerW) / 2, (scrh - centerH) / 2 - PD.H(30))

            lockedPanel.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)
                draw.RoundedBox(0, 0, 0, w, h, Color(80, 0, 0, 100))

                surface.SetDrawColor(PD.Theme.Colors.StatusCritical)
                surface.DrawOutlinedRect(0, 0, w, h, 2)

                surface.SetDrawColor(PD.Theme.Colors.StatusCritical)
                surface.DrawRect(0, 0, w, PD.H(3))

                draw.DrawText("🔒", "MLIB.60", w / 2, h / 2 - PD.H(60), PD.Theme.Colors.StatusCritical, TEXT_ALIGN_CENTER)
                draw.DrawText("GESPERRT", "MLIB.24", w / 2, h / 2 + PD.H(10), PD.Theme.Colors.StatusCritical, TEXT_ALIGN_CENTER)
                draw.DrawText("Höherer Rang erforderlich", "MLIB.14", w / 2, h / 2 + PD.H(45), PD.Theme.Colors.TextDim, TEXT_ALIGN_CENTER)
            end

            charPanels[i] = lockedPanel
        else
            if not data.job.model or not string.find(data.job.model, ".mdl", 1, true) then
                data.job.model = CONFIG.BackModel or "models/player/stormtrooper.mdl"
            end

            local charPanel = vgui.Create("DPanel", CharBase)
            charPanel:SetSize(centerW, centerH)
            charPanel:SetPos((scrw - centerW) / 2, (scrh - centerH) / 2 - PD.H(30))

            charPanel.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, PD.Theme.Colors.BackgroundDark)

                surface.SetDrawColor(PD.Theme.Colors.AccentGray)
                surface.DrawOutlinedRect(0, 0, w, h, 1)

                surface.SetDrawColor(PD.Theme.Colors.AccentRed)
                surface.DrawRect(0, 0, w, PD.H(3))

                draw.RoundedBox(0, 0, h - PD.H(80), w, PD.H(80), PD.ColorAlpha(PD.Theme.Colors.BackgroundDark, 0.95))
                surface.SetDrawColor(PD.Theme.Colors.AccentGray)
                surface.DrawRect(0, h - PD.H(80), w, 1)

                local _, _, jobTable = GetFactionTables(data)

                local displayName = (data.id or "") .. " " .. (data.name or "")
                draw.DrawText(displayName, "MLIB.18", w / 2, h - PD.H(70), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
                draw.DrawText(jobTable.name or "FEHLER", "MLIB.14", w / 2, h - PD.H(45), PD.Theme.Colors.AccentGray, TEXT_ALIGN_CENTER)

                local currentName = LocalPlayer():GetNWString("rpname", "")
                local charName = (data.id or "") .. " " .. (data.name or "")
                if currentName == charName then
                    draw.RoundedBox(PD.H(5), w / 2 - PD.W(40), h - PD.H(25), PD.W(80), PD.H(18), PD.Theme.Colors.StatusActive)
                    draw.DrawText("AKTIV", "MLIB.15", w / 2, h - PD.H(24), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER)
                end
            end

            local modelPanel = vgui.Create("DModelPanel", charPanel)
            modelPanel:Dock(FILL)
            modelPanel:DockMargin(PD.W(20), PD.H(20), PD.W(20), PD.H(100))
            modelPanel:SetModel(data.job.model)
            modelPanel:SetFOV(35)
            modelPanel:SetCamPos(Vector(60, 0, 55))
            modelPanel:SetLookAt(Vector(0, 0, 50))
            modelPanel.LayoutEntity = function(ent) return end

            if modelPanel.Entity then
                modelPanel.Entity.GetPlayerColor = function()
                    return Vector(1, 0, 0)
                end
            end

            charPanels[i] = charPanel
        end
    end

    UpdatePage()

    local socialContainer = vgui.Create("DPanel", CharBase)
    socialContainer:SetSize(PD.W(180), PD.H(50))
    socialContainer:SetPos(scrw - PD.W(210), scrh - PD.H(75))
    socialContainer.Paint = function() end

    local discordBtn = PD.Button("DISCORD", socialContainer, function()
        gui.OpenURL(PD.Char.Discord or "")
    end)
    discordBtn:Dock(LEFT)
    discordBtn:SetWide(PD.W(85))
    discordBtn:SetAccentColor(Color(88, 101, 242))

    local collectionBtn = PD.Button("WORKSHOP", socialContainer, function()
        gui.OpenURL(PD.Char.Kollektion or "")
    end)
    collectionBtn:Dock(RIGHT)
    collectionBtn:SetWide(PD.W(85))
    collectionBtn:SetAccentColor(PD.Theme.Colors.AccentBlue)

    local leaveBtn = PD.Button("✕", CharBase, function()
        RunConsoleCommand("disconnect")
    end)
    leaveBtn:SetSize(PD.W(45), PD.H(45))
    leaveBtn:SetPos(scrw - PD.W(55), scrh - PD.H(75))
    leaveBtn:SetAccentColor(PD.Theme.Colors.StatusCritical)

    if close then
        local closeBtn = PD.Button("✕", CharBase, function()
            CharBase:Remove()
        end)
        closeBtn:SetSize(PD.W(40), PD.H(40))
        closeBtn:SetPos(scrw - PD.W(55), PD.H(20))
        closeBtn:SetAccentColor(PD.Theme.Colors.StatusCritical)
    end
end

net.Receive("OpenCharbyDelete", function()
    PD.Char:Menu()
end)

hook.Add("InitPostEntity", "SyncCharMenuCharsProgama057", function()
    net.Start("PD.Char.Syncsv")
    net.WriteBool(true)
    net.SendToServer()
end)

concommand.Add("pd_char_print", function()
    print("PD.Char.Data")
    PrintTable(PD.Char.Data)
    print("PD.Char.AdminData")
    PrintTable(PD.Char.AdminData or {})
    print("Get Job Data")
    local id, tbl = LocalPlayer():GetJob()
    print(id)
    PrintTable(tbl or {})
    PD.LOGS.Add("[Info]", "Charakter Daten von " .. LocalPlayer():Nick() .. " aufgerufen.", Color(100, 255, 100))
end)

local PLAYER = FindMetaTable("Player")

function PLAYER:SetJob(jobID, jobTbl)
    self.JobID = jobID
    self.JobTbl = jobTbl
end

function PLAYER:GetJob()
    return self.JobID or "", self.JobTbl or {}
end