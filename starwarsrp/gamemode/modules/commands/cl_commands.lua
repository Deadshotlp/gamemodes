-- Commands by Progama057

local times = 5
local red = Color(255,0,0)
local green = Color(0,255,0)
local blue = Color(89,172,255)
local white = CONFIG:GetConfig("textcolor")

net.Receive("CMD_Verlosung",function()
    gewinner = net.ReadEntity()
    sender = net.ReadEntity()
    text = net.ReadString()

    chat.AddText(red, "[Verlosung] ",white, "Es wurde eine Verlosung von ", green, sender:Nick(), white, " gestartet.")
    chat.AddText(red, "[Verlosung] ", white, "Preis: ", green, text)

    timer.Create("Verlosung",1,times,function()
        chat.AddText(red, "[Verlosung] ", white, "Die Verlosung endet in ", green, 1 + timer.RepsLeft("Verlosung"), white, " Sekunden!")
    end)

    timer.Simple(times+2,function()
        chat.AddText(red, "[Verlosung] ", white,"HGW, ", green, gewinner:Nick(), white, " hat die Verlosung von ", blue, sender:Nick(), white, " gewonnen.")
    end)
end)

net.Receive("CommandsSend",function()
    local tbl = net.ReadTable()
    local range = 200 

    for k, v in SortedPairs(PD.Commands.Table) do
        if tbl.typ == v.command then
            v.func()
            return
        end
    end

    if tbl.typ == "git" then
        chat.AddText(red,"*** ",white, tbl.text)
    elseif tbl.typ == "akt" then
        chat.AddText(red,"[AKTION] ", green, tbl.ply:Nick(), white, ": " .. tbl.text)
    elseif tbl.typ == "eakt" then
        chat.AddText(red,"[EVENT-AKT] ", green, tbl.ply:Nick(), white, ": " .. tbl.text)
    elseif tbl.typ == "me" then
        if tbl.ply:GetPos():Distance(LocalPlayer():GetPos()) < range then
            chat.AddText(red,"[ME] ", green, tbl.ply:Nick(), white, ": " .. tbl.text)
        end
    elseif tbl.typ == "it" then
        if tbl.ply:GetPos():Distance(LocalPlayer():GetPos()) < range then
            chat.AddText(red,"*** ",white, tbl.text)
        end
    elseif tbl.typ == "id" then
        if tbl.ply:GetPos():Distance(LocalPlayer():GetPos()) < range then
            chat.AddText(red,"[ID] ", white, tbl.ply:Nick())
        end
    elseif tbl.typ == "makt" then
        chat.AddText(red,"[MEDIC-AKT] ", green, tbl.ply:Nick(), white, ": " .. tbl.text)
    elseif tbl.typ == "takt" then
        chat.AddText(red,"[TECHNIKER-AKT] ", green, tbl.ply:Nick(), white, ": " .. tbl.text)
    elseif tbl.typ == "rok" then
        chat.AddText(red,"[ROK] ", white, tbl.text)
    elseif tbl.typ == "funk" then
        if not tbl.ply2 and tbl.ply == LocalPlayer() then chat.AddText("Fehler: Kein Empfänger angegeben!") chat.AddText("/funk NAME TEXT") return end

        chat.AddText(red,"[FUNK] ", green, tbl.ply:Nick(), white, " an ", blue, tbl.ply2:Nick(), white, ": " .. tbl.text)
    elseif tbl.typ == "vfunk" then
        if not tbl.ply2 and tbl.ply == LocalPlayer() then chat.AddText("Fehler: Kein Empfänger angegeben!") chat.AddText("/vfunk NAME TEXT") return end

        if tbl.ply == LocalPlayer() or tbl.ply2 == LocalPlayer() then
            chat.AddText(red,"[VFUNK] ", green, tbl.ply:Nick(), white, " an ", blue, tbl.ply2:Nick(), white, ": " .. tbl.text)
        else
            chat.AddText(red,"[VFUNK] ", white, tbl.vtext)
        end
    elseif tbl.typ == "efunk" then
        if not tbl.category and tbl.ply == LocalPlayer() then chat.AddText("Fehler: Keine Kategorie angegeben!") chat.AddText("/efunk NAME TEXT") return end
        
        chat.AddText(red,"[EINHEITS-FUNK] ", green, tbl.ply:Nick(), white, " an ", blue, tbl.category, white, ": " .. tbl.text)
    elseif tbl.typ == "decode" then
        if tbl.ply == LocalPlayer() then
            Decode_Menu(tbl.text)
        end
    elseif tbl.typ == "hacken" then
        local status = 0
        
        chat.AddText(red,"[HACKEN] ", green, tbl.ply:Nick(), white, " Startet ein Häck...")

        timer.Create("hacken_"..tbl.ply:EntIndex(), 2, 0, function()
            status = status + math.random(0,15)

            if status >= 100 then
                status = 100
            end

            chat.AddText(red,"[HACKEN] ", green, tbl.ply:Nick(), white, " Häckt..." .. status .. "%")

            if status >= 100 then
                chat.AddText(red,"[HACKEN] ", green, tbl.ply:Nick(), white, " Häck abgeschlossen!")
                timer.Remove("hacken_"..tbl.ply:EntIndex())
            end
        end)
    elseif tbl.typ == "forschen" then
        local status = 0
        
        chat.AddText(red,"[FORSCHEN] ", green, tbl.ply:Nick(), white, " Fängt mit einer Forschung an...")

        timer.Create("forschen_"..tbl.ply:EntIndex(), 2, 0, function()
            status = status + math.random(0,15)
            
            if status >= 100 then
                status = 100
            end

            chat.AddText(red,"[FORSCHEN] ", green, tbl.ply:Nick(), white, " Forscht..." .. status .. "%")

            if status >= 100 then
                chat.AddText(red,"[FORSCHEN] ", green, tbl.ply:Nick(), white, " Forschung abgeschlossen!")
                timer.Remove("forschen_"..tbl.ply:EntIndex())
            end
        end)
    elseif tbl.typ == "scan" then
        local status = 0
        
        chat.AddText(red,"[SCAN] ", green, tbl.ply:Nick(), white, " Startet ein Scan...")

        timer.Create("scan_"..tbl.ply:EntIndex(), 2, 0, function()
            status = status + math.random(0,15)

            if status >= 100 then
                status = 100
            end

            chat.AddText(red,"[SCAN] ", green, tbl.ply:Nick(), white, " scannt..." .. status .. "%")

            if status >= 100 then
                chat.AddText(red,"[SCAN] ", green, tbl.ply:Nick(), white, " Scan abgeschlossen!")
                timer.Remove("scan_"..tbl.ply:EntIndex())
            end
        end)
    elseif tbl.typ == "looc" then
        if tbl.ply:GetPos():Distance(LocalPlayer():GetPos()) < range then
            chat.AddText(red,"[LOOC] ", green, tbl.ply:Nick(), white, ": " .. tbl.text)
        end
    elseif tbl.typ == "roll" then
        chat.AddText(red,"[ROLL] ", green, tbl.ply:Nick(), white, " hat eine ", green, tbl.roll, white, " gewürfelt.")
    elseif tbl.typ == "flip" then
        if tbl.flip == 1 then
            chat.AddText(red,"[FLIP] ", green, tbl.ply:Nick(), white, " hat Kopf gewählt.")
        else
            chat.AddText(red,"[FLIP] ", green, tbl.ply:Nick(), white, " hat Zahl gewählt.")
        end
    else
        chat.AddText(red, "*** ", white, "Fehler: Unbekannter Befehl")
    end
end)

local tbl = {
    "A5", "F12", "D7", "G2", "H15", "J3", "K9", "L1", "M14", "N4",
    "B6", "C11", "E8", "F13", "G10", "H16", "I3", "J7", "K2", "L18",
    "M5", "N12", "O6", "P9", "Q11", "R14", "S8", "T4", "U15", "V1",
    "W13", "X2", "Y17", "Z6", "A10", "B3"
}

local function shuffleTable(t)
    local shuffled = {}
    for i = #t, 1, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

local function randomCode()
    local code = ""
    local stbl = shuffleTable(tbl)
    for i = 1, 10 do
        code = code .. stbl[i]
    end
    return code
end

function Decode_Menu(vfunkstr)
    if IsValid(mainFrameDecode) then return end
    local rCode = randomCode()
    local selfCode = ""

    if vfunkstr == nil then
        vfunkstr = "N/A"
    end

    mainFrameDecode = PD.Frame("Decode", PD.W(1000), PD.H(650), true)

    local mainPanel = PD.Panel("", mainFrameDecode)
    mainPanel:Dock(FILL)
    mainPanel:SetWide(PD.W(610))

    local panelRight = PD.Panel("", mainFrameDecode)
    panelRight:Dock(RIGHT)
    panelRight:SetWide(PD.W(360))

    local lbl = PD.Label("Verschlüsselter Funk: \n" .. vfunkstr, panelRight)

    local DeCodelbl = PD.Label("Gesuchter Code: \n" .. rCode, panelRight)

    local times = 45
    local time = PD.Label("Zeit: " .. times, panelRight)
    time:SetFont("MLIB.40")
    time:SetTall(PD.H(50))

    timer.Create("DecodeTimer", 1, 45, function()
        times = times - 1
        time:SetText("Zeit: " .. times)

        if times == 0 then
            timer.Remove("DecodeTimer")
            chat.AddText(red, "[DECODE] ", white, "Der Code wurde nicht erfolgreich entschlüsselt!")
            mainFrameDecode:Remove()
        end
    end)

    local name = "N/A"
    local x, y = PD.W(10), PD.H(10)
    local sort = 1
    local tbl = shuffleTable(tbl)
    for i = 1, 36 do
        name = tbl[i]
        local panel = PD.Button(name, mainPanel, function(self)
            if self:GetBackColor() == CONFIG:GetConfig("hovercolor") then
                self:SetBackColor(CONFIG:GetConfig("thirdcolor"))
                selfCode = selfCode:gsub(self:GetText(), "")
            else
                self:SetBackColor(CONFIG:GetConfig("hovercolor"))
                selfCode = selfCode .. self:GetText()

                -- if times == 30 then
                --     timer.Create("DecodeTimer", 1, 30, function()
                --         times = times - 1
                --         time:SetText("Zeit: " .. times)

                --         if times == 0 then
                --             timer.Remove("DecodeTimer")
                --             chat.AddText(red, "[DECODE] ", white, "Der Code wurde nicht erfolgreich entschlüsselt!")
                --             mainFrameDecode:Remove()
                --         end
                --     end)
                -- end
            end
            
            UpdateCode()
        end)
        panel:Dock(NODOCK)
        panel:SetSize(PD.W(90), PD.H(90))
        panel:SetPos(x, y)
        panel:SetBackColor(CONFIG:GetConfig("thirdcolor"))

        if sort == 6 then
            y = y + PD.H(100)
            x = PD.W(10)
            sort = 1
        else
            x = x + PD.W(100)
            sort = sort + 1
        end
    end

    function UpdateCode()
        if IsValid(Codelbl) then
            Codelbl:Remove()
        end

        Codelbl = PD.Label("Dein Code: \n" .. selfCode, panelRight)
        Codelbl:Dock(BOTTOM)
    end

    local btn = PD.Button("Entschlüsseln", panelRight, function()
        if rCode == selfCode then
            timer.Remove("DecodeTimer")

            chat.AddText(red, "[DECODE] ", white, "Der Code wurde erfolgreich entschlüsselt!")
            net.Start("CMD_Decode")
                net.WriteString(vfunkstr)
            net.SendToServer()
            mainFrameDecode:Remove()
        else
            chat.AddText(red, "[DECODE] ", white, "Der Code wurde nicht erfolgreich entschlüsselt!")
        end
    end)
    btn:Dock(BOTTOM)
    btn:SetTall(PD.H(50))
end

