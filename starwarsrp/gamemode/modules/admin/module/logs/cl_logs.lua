PD.LOGS = PD.LOGS or {}

local Logs = {}
net.Receive("PD.LOGS.Add", function()
    Logs = net.ReadTable()
end)

net.Start("PD.LOGS.Sync")
net.SendToServer()

function PD.LOGS:Menu()
    if IsValid(logFrame) then return end

    logFrame = PD.Frame("Logs", PD.W(1200), PD.H(700), true)

    logsPnl = PD.Panel("", logFrame)
    logsPnl:Dock(FILL)

    local pnl = PD.SideTab(logFrame, logsPnl)

    PD.AddSideItem("Aktuelle Logs", function()
        logsPnl:Clear()

        local search = PD.TextEntry("Suche...", pnl)
        search:Dock(BOTTOM)
        search.OnChange = function()
            logsPnl:Clear()

            for k,v in pairs(Logs) do
                if string.find(v.text:lower(), search:GetValue():lower()) then
                    local log = PD.Panel("", logsPnl)
                    log:Dock(TOP)
                    log:DockMargin(0,0,0,5)
                    log:SetTall(PD.H(30))
                    log.Paint = function(s,w,h)
                        draw.SimpleText(v.text, "MLIB.20", 5, h/2, v.color, 0, 1)
                        draw.SimpleText(v.date, "MLIB.20", w-5, h/2, Color(255,255,255), 2, 1)
                    end
                end
            end
        end
    

        for k,v in pairs(Logs) do
            local log = PD.Panel("", logsPnl)
            log:Dock(TOP)
            log:DockMargin(0,0,0,5)
            log:SetTall(PD.H(30))
            log.Paint = function(s,w,h)
                draw.SimpleText(v.text, "MLIB.20", 5, h/2, v.color, 0, 1)
                draw.SimpleText(v.date, "MLIB.20", w-5, h/2, Color(255,255,255), 2, 1)
            end
        end
    
    end)
end

hook.Add("Tick", "Tickfuerlogsyolo", function()
    -- if LocalPlayer():Nick() == "Progama057" then
        -- PD.LOGS:Menu()
    -- end
end)

-- if logFrame then logFrame:Remove() end

