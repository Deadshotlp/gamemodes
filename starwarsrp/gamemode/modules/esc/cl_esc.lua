PD.ESC = PD.ESC or {}

local buttons = {
    {
        name = "Rejoin",
        func = function()
            RunConsoleCommand("retry")
        end
    }, {
        name = "Kollektion",
        func = function()
            gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails?id=3274579639")
        end
    }, {
        name = "Discord",
        func = function()
            gui.OpenURL("https://discord.gg/YEHfCffp4M")
            gui.HideGameUI()
        end
    }, {
        name = "Bind-Menu",
        func = function()
            PD.Binds:Menu()
        end
    }, {
        name = "FOV - Settings",
        func = function(base)
            if IsValid(base) then
                base:Remove()
            end

            ChangeFOVValues()
        end
    }, {
        name = "Admin - Settings",
        admin = true,
        func = function(base)
            if IsValid(base) then
                base:Remove()
            end

            
        end
    }
}

hook.Add("PreRender", "PD.ESC.Toggle", function()
    if input.IsKeyDown(KEY_ESCAPE) and gui.IsGameUIVisible() then
        if ValidPanel(mainFrameESC) then
            gui.HideGameUI()
            mainFrameESC:Remove()
        else
            gui.HideGameUI()
            PD.ESC:Menu()
        end
    end
end)

local radius = PD.H(15)
local buttonTall = PD.H(70)
local hoverColor = PD.UI.Colors["JediBlue"]

function PD.ESC:Menu()
    if IsValid(mainFrameESC) then return end

    mainFrameESC = PD.Frame("", ScrW(), ScrH(), true)
    mainFrameESC:SetBarColor(Color(0, 0, 0, 0))
    mainFrameESC.Paint = function(self, w, h)
        Mario.DrawBlur(0, 0, w, h, 4, 7)
    end

    local panelWidth = PD.W(500)
    local panelHeight = (buttonTall + PD.H(10)) * (#buttons + 3)
    local panelY = ScrH() / 2 - panelHeight / 2

    panel = PD.Panel(LocalPlayer():Nick(), mainFrameESC)
    panel:SetSize(panelWidth, panelHeight + 40)
    panel:SetPos(10, panelY)
    panel:Dock(NODOCK)
    panel:SetBackColor(PD.UI.Colors["Background"])

    local weiter = PD.Button("Weiterspielen", panel, function()
        mainFrameESC:Remove()
    end)
    weiter:Dock(TOP)
    weiter:DockMargin(5, 5, 5, 5)
    weiter:SetTall(buttonTall)
    weiter:SetRadius(radius)
    weiter:SetHoverColor(hoverColor)

    local options = PD.Button("Spieleinstellungen", panel, function()
        mainFrameESC:Remove()
        gui.ActivateGameUI()
        RunConsoleCommand("gamemenucommand", "openoptionsdialog")
    end)
    options:Dock(TOP)
    options:DockMargin(5, 5, 5, 5)
    options:SetTall(buttonTall)
    options:SetRadius(radius)
    options:SetHoverColor(hoverColor)

    for k, v in ipairs(buttons) do
        if v.admin and not LocalPlayer():IsAdmin() then
            continue
        end

        local buttons = PD.Button(v.name, panel, function()
            v.func(mainFrameESC)
        end)
        buttons:Dock(TOP)
        buttons:DockMargin(5, 5, 5, 5)
        buttons:SetTall(buttonTall)
        buttons:SetRadius(radius)
        buttons:SetHoverColor(hoverColor)
    end

    local quit = PD.Button("Verlassen", panel, function()
        RunConsoleCommand("disconnect")
    end)
    quit:Dock(TOP)
    quit:DockMargin(5, 5, 5, 5)
    quit:SetTall(buttonTall)
    quit:SetRadius(radius)
    quit:SetHoverColor(hoverColor)
end

-- if mainFrameESC then 
--     mainFrameESC:Remove()
-- end

-- PD.ESC:Menu()

