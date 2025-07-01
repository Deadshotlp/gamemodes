--
PD.DataPad.AddCategory("Stosstruppen")
PD.DataPad.AddSubCategory("Stosstruppen", "Haftprotokoll")

PD.DataPad.AddEntry("Stosstruppen", "Haftprotokoll", "Erstellen", function(pnl)
    local plyH = nil

    
    local playerHaft = PD.ComboBox("Häftling:", pnl, function(val)
        plyH = val
    end)

    for k, v in pairs(player.GetAll()) do
        if v:IsPlayer() and v:Alive() then
            playerHaft:AddChoice(v:Nick(), v)
        end
    end

    local tpnl, timeText = PD.TextEntryLabel("Dauer:", pnl)
    local tpnl, ortText = PD.TextEntryLabel("Ort:", pnl)

    local tpnl, reasonText = PD.TextEntryLabel("Grund:", pnl)
    tpnl:SetTall(PD.H(250))
    reasonText:SetMultiline(true)

    local submitBtn = PD.Button("Erstellen", pnl, function()
        if not plyH then
            PD.Notify("Bitte wähle einen Häftling aus.", "error")
            return
        end

        local table = {
            plyst = LocalPlayer(),
            plyhaft = plyH,
            time = timeText:GetValue(),
            ort = ortText:GetValue(),
            reason = reasonText:GetValue()
        }

        pnl:Clear()
        PD.DataPad.GetEntry("Haftprotokoll", "Anzeigen")(pnl) -- Zurück zur Anzeige
    end)
    submitBtn:Dock(BOTTOM)
    submitBtn:SetTall(PD.H(50))
end)