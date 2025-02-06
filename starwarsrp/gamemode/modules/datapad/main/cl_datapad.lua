PD.DataPad = PD.DataPad or {}

function PD.DataPad:Menu(wo)
    if IsValid(mainFrame) then return end

    mainFrame = PD.Frame("Datapad - " .. os.date("%H:%M | %d.%m.%Y", os.time()), PD.W(700), PD.H(900), true)
 
    local pnl = PD.Panel("", mainFrame)
    pnl:Dock(FILL)

    local scrl = PD.Scroll(pnl)

    if wo then
        -- PD.DataPad.GetCategory()[wo[1]](pnl)
    
        return
    end

    for name, data in SortedPairs(PD.DataPad.GetCategory()) do
        local catBtn = PD.Button(name, scrl, function()
            scrl:Clear()

            for n, d in SortedPairs(PD.DataPad.GetEntry(name)) do
                local btn = PD.Button(n, scrl, function()
                    pnl:Clear()
                    PD.DataPad.GetEntry(name, n)(pnl)
                end)
                btn:Dock(TOP)
                btn:SetTall(PD.H(50))
                btn:SetRadius(20)
            end
        end)
        catBtn:Dock(TOP)
        catBtn:SetTall(PD.H(50))
        catBtn:SetRadius(20)
    end
end

hook.Add("Tick", "PD.DataPad:Menu", function()
    -- PD.DataPad:Menu()
end)

if mainFrame then
    mainFrame:Remove()
end

