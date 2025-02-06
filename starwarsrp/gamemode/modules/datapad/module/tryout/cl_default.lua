PD.DataPad = PD.DataPad or {}

PD.DataPad.AddCategory("Tryouts")

PD.DataPad.AllTryouts = {}

PD.DataPad.AddEntry("Tryouts", "Ansehen", function(pnl)
    for k, v in SortedPairs(PD.DataPad.AllTryouts) do
        local btn = PD.Button(v.Name, pnl, function()
            PD.DataPad.GetEntry("Tryouts", "Ansehen", v)(pnl)
        end)
        btn:Dock(TOP)
        btn:SetTall(PD.H(50))
        btn:SetRadius(20)
    end

    local btn = PD.Button("Zurück", pnl, function()
        pnl:Clear()
        

    end)    
    btn:Dock(BOTTOM)
    btn:SetTall(PD.H(50))
    btn:SetRadius(20)
end)

PD.DataPad.AddEntry("Tryouts", "Erstellen", function(pnl)
    
end)

