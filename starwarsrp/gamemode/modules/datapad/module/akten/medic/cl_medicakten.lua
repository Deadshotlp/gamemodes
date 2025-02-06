-- 

local paragraf = ""
local sachlage = ""
local aktetext = ""
local strafe = ""

local function createAkte(pnl)
    pnl1, paragrafText = PD.TextEntryLabel("Paragraf verstoß", pnl, paragraf)
    paragrafText:SetMultiline(true)
    paragrafText:SetTall(200)
    paragrafText.OnChange = function(self)
        paragraf = self:GetValue()
    end

    pnl2, sachlageText = PD.TextEntryLabel("Sachlage / Geschehen", pnl, sachlage)
    sachlageText:SetMultiline(true)
    sachlageText:SetTall(200)
    sachlageText.OnChange = function(self)
        sachlage = self:GetValue()
    end

    pnl3, aktetextText = PD.TextEntryLabel("Datenrelevat", pnl, aktetext)
    aktetextText:SetMultiline(true)
    aktetextText:SetTall(200)
    aktetextText.OnChange = function(self)
        aktetext = self:GetValue()
    end

    pnl4, strafeText = PD.TextEntryLabel("Erhaltenestrafe", pnl, strafe)
    strafeText:SetMultiline(true)
    strafeText:SetTall(200)
    strafeText.OnChange = function(self)
        strafe = self:GetValue()
    end

    local btn = PD.Button("Akte Erstellen ", pnl, function()
        local data = {
            ply = LocalPlayer():SteamID64(),
            paragraf = paragraf,
            sachlage = sachlage,
            aktetext = aktetext,
            strafe = strafe
        }

        PD.DataPad.SendDataToServer("Medizinische Akten", data)

        mainFrame:Remove()
    end)
    btn:Dock(TOP)
    btn:SetTall(PD.H(50))
    btn:SetRadius(20)

    local btn = PD.Button("Zurück", pnl, function()
        mainFrame:Remove()

        PD.DataPad:Menu({"Akten", "Medizinische Akten"})
    end)
    btn:Dock(TOP)
    btn:SetTall(PD.H(50))
    btn:SetRadius(20)
end

local function MedicMenu(pnl)
    pnl:Clear()

    local scrl = PD.Scroll(pnl)

    for k, v in SortedPairs(PD.DataPad.GetData("Medizinische Akten")) do
        local btn = PD.Button("Akte von " .. v.ply, scrl, function()
            pnl:Clear()

            local scrl = PD.Scroll(pnl)

            local paragraf = PD.Label("Paragraf: " .. v.paragraf, scrl)
            local sachlage = PD.Label("Sachlage: " .. v.sachlage, scrl)
            local aktetext = PD.Label("Datenrelevat: " .. v.aktetext, scrl)
            local strafe = PD.Label("Erhaltenestrafe: " .. v.strafe, scrl)

            local back = PD.Button("Zurück", pnl, function()
                scrl:Clear()

                STMenu(pnl)
            end)
            back:Dock(BOTTOM)
            back:SetTall(PD.H(50))
            back:SetRadius(20)
        end)
        btn:Dock(TOP)
        btn:SetTall(PD.H(50))
        btn:SetRadius(20)
    end

    -- local back = PD.Button("Zurück", pnl, function()
    --     pnl:Clear()

    --     PD.DataPad:Menu({"Akten"})
    -- end)

    local btn = PD.Button("Akte Erstellen", pnl, function()
        scrl:Clear()

        createAkte(scrl)
    end)
    btn:Dock(BOTTOM)
    btn:SetTall(PD.H(50))
    btn:SetRadius(20)
end

PD.DataPad.AddEntry("Akten", "Medizinische Akten", function(pnl)
    MedicMenu(pnl)
end)