-- Fix für sicheres GetJob() im clientseitigen Scoreboard

PD.Scoreboard = PD.Scoreboard or {}

hook.Add("Initialize", "RemoveGamemodeFunctions", function()
    GAMEMODE.ScoreboardShow = nil
    GAMEMODE.ScoreboardHide = nil
end)

hook.Add("ScoreboardShow", "Lukas_TAB_ScoreboardShow", function()
    PD.Scoreboard:Draw()
    return false
end)

hook.Add("ScoreboardHide", "Lukas_TAB_ScoreboardHide", function()
    if IsValid(mainFrameScore) then
        mainFrameScore:Remove()
    end
end)

local function LoadUnits()
    local tbl = {}

    for k, v in SortedPairs(PD.JOBS.GetUnit(false, true)) do
        if not tbl[k] then
            tbl[k] = v
        end
    end

    tbl["Betritt die Galaxy"] = {
        color = Color(255, 255, 255),
        unit = "Betritt die Galaxy"
    }

    tbl["FEHLERHAFTE DATEN"] = {
        color = Color(255, 0, 0),
        unit = "FEHLERHAFTE DATEN"
    }

    return tbl
end

local function CheckPlayerUnit(ply, unit)
    if not IsValid(ply) or not ply:IsPlayer() then return false end
    if ply:Nick() == "00-0000 Unknown" then return unit == "Betritt die Galaxy" end

    local jobID, jobTable = "", nil

    local success, err = pcall(function()
        jobID, jobTable = ply:GetJob()
    end)

    if not success or not jobTable then
        return unit == "FEHLERHAFTE DATEN"
    end

    if jobTable.unit == unit then
        return true
    end

    for k, v in SortedPairs(PD.JOBS.GetSubUnit(false, true)) do
        if v.unit == unit and jobTable.unit == k then
            return true
        end
    end

    return false
end

local function HasUnitPlayers(unit)
    for _, ply in ipairs(player.GetAll()) do
        if CheckPlayerUnit(ply, unit) then
            return true
        end
    end
    return false
end

function PD.Scoreboard:Draw()
    if IsValid(mainFrameScore) then return end

    mainFrameScore = PD.Frame("", ScrW(), ScrH(), false, false)
    mainFrameScore:SetBarColor(Color(0, 0, 0, 0))
    mainFrameScore:SetBlur(true)

    local mainFrameScoreTitle = PD.Panel("", mainFrameScore, function(self, w, h)
        draw.SimpleText(GetHostName(), "MLIB.60", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)
    mainFrameScoreTitle:Dock(TOP)
    mainFrameScoreTitle:SetTall(PD.H(100))
    mainFrameScoreTitle:SetBackColor(Color(0, 0, 0, 0))

    local mainPanel = PD.Panel("", mainFrameScore)
    mainPanel:Dock(FILL)
    mainPanel:SetBackColor(Color(0, 0, 0, 0))

    local leftPanel = PD.Panel("", mainFrameScore)
    leftPanel:Dock(LEFT)
    leftPanel:SetWide(PD.W(400))
    leftPanel:SetBackColor(Color(0, 0, 0, 0))

    local rightPanel = PD.Panel("", mainFrameScore)
    rightPanel:Dock(RIGHT)
    rightPanel:SetWide(PD.W(400))
    rightPanel:SetBackColor(Color(0, 0, 0, 0))

    local scrl = PD.Scroll(mainPanel)

    for k, v in SortedPairs(LoadUnits()) do
        if not HasUnitPlayers(k) then continue end

        local panel = PD.Panel("", scrl)
        panel:Dock(TOP)
        panel:SetTall(PD.H(50))
        panel.Paint = function(s, w, h)
            draw.SimpleText(k, "MLIB.30", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end

        for _, ply in pairs(player.GetAll()) do
            if not IsValid(ply) or not ply:IsPlayer() then continue end

            local jobID, jobTable = "FEHLER", {
                color = Color(255, 0, 0),
                unit = "FEHLERHAFTE DATEN"
            }
            local name = "UNBEKANNT"
            local color = Color(255, 255, 255)

            if ply:Nick() == "00-0000 Unknown" then
                jobID, jobTable = "Betritt die Galaxy", {
                    color = Color(255, 255, 255),
                    unit = "Betritt die Galaxy"
                }
                name = ply:Name()
            else
                local success, result1, result2 = pcall(function()
                    return ply:GetJob()
                end)
                if success and result1 and result2 then
                    jobID, jobTable = result1, result2
                    name = PD.HUD.GetKnownPlayers(ply) or ply:Name()
                end
            end

            if not CheckPlayerUnit(ply, k) then continue end

            local plyPanel = PD.Button("", scrl, function()
                local miniFrame = PD.Frame(ply:Nick(), PD.W(400), PD.H(200), true)
                local scrl = PD.Scroll(miniFrame)

                for k, v in pairs(PD.Scoreboard.Buttons) do
                    local btn = PD.Button(v.name, scrl, function()
                        v.func(LocalPlayer(), ply)
                    end)
                    btn:Dock(TOP)
                    btn:SetTall(PD.H(50))
                end
            end)
            plyPanel:Dock(TOP)
            plyPanel:SetTall(PD.H(50))
            plyPanel:DockMargin(0, 0, 0, PD.H(5))
            plyPanel.Paint = function(s, w, h)
                draw.RoundedBox(0, 0, 0, w, h, Color(0, 0, 0, 200))
                draw.RoundedBox(0, 0, h - PD.H(2), w, PD.H(2), jobTable.color or Color(255, 255, 255))

                if ply:Ping() > 100 then
                    color = Color(255, 0, 0)
                elseif ply:Ping() > 50 then
                    color = Color(255, 255, 0)
                end

                draw.SimpleText(name, "MLIB.20", PD.W(5), h / 2, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
                draw.SimpleText(ply:Ping(), "MLIB.20", w - PD.W(5), h / 2, color, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
                draw.SimpleText(jobID, "MLIB.20", w / 2, h / 2, Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            end
        end
    end
end

hook.Add("Tick", "Lukas_TAB_ScoreboardTick", function()
    -- PD.Scoreboard:Draw()
end)

if mainFrameScore then
    mainFrameScore:Remove()
end
