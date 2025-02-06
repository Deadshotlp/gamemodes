PD.ESC = PD.ESC or {}

local buttons = {{
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
}}

hook.Add("PreRender", "PD.ESC.Toggle", function()
    if input.IsKeyDown(KEY_ESCAPE) and gui.IsGameUIVisible() then
        if ValidPanel(base) then
            gui.HideGameUI()
            base:Remove()
        else
            gui.HideGameUI()
            PD.ESC:Menu()
        end
    end
end)

function PD.ESC:Menu()
    if IsValid(base) then
        return
    end

    local screenWidth = ScrW()
    local screenHeight = ScrH()

    base = PD.Frame("", screenWidth, screenHeight, false)
    base:SetBarColor(Color(0, 0, 0, 0))
    base.Paint = function(self, w, h)
        Mario.DrawBlur(0, 0, w, h, 4, 7)
    end

    local panelWidth = PD.W(300)
    local panelHeight = PD.H(60) * (#buttons + 3)
    local panelY = ScrH() / 2 - panelHeight / 2

    panel = PD.Panel(LocalPlayer():Nick(), base)
    panel:SetSize(panelWidth, panelHeight + 40)
    panel:SetPos(10, panelY)
    panel:Dock(NODOCK)

    local weiter = PD.Button("Weiterspielen", panel, function()
        base:Remove()
    end)
    weiter:Dock(TOP)
    weiter:DockMargin(5, 5, 5, 5)
    weiter:SetTall(PD.H(50))

    local options = PD.Button("Spieleinstellungen", panel, function()
        base:Remove()
        gui.ActivateGameUI()
        RunConsoleCommand("gamemenucommand", "openoptionsdialog")
    end)
    options:Dock(TOP)
    options:DockMargin(5, 5, 5, 5)
    options:SetTall(PD.H(50))

    for k, v in ipairs(buttons) do
        local buttons = PD.Button(v.name, panel, function()
            v.func()
        end)
        buttons:Dock(TOP)
        buttons:DockMargin(5, 5, 5, 5)
        buttons:SetTall(PD.H(50))
    end

    local quit = PD.Button("Verlassen", panel, function()
        RunConsoleCommand("disconnect")
    end)
    quit:Dock(TOP)
    quit:DockMargin(5, 5, 5, 5)
    quit:SetTall(PD.H(50))
end

