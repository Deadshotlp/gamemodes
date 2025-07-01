PD.COBar = PD.COBar or {}

local co,xo,ao = "N/A","N/A","N/A"
LocalPlayer().COBar = true
local textLength = 0

hook.Add("InitPostEntity","Mario_Leiste_Gaga",function()
    net.Start("SyncBar")
    net.SendToServer()
end)

net.Receive("Update",function()
    name = net.ReadString()
    was = net.ReadString()

    if was == "co" then
        if co == name then
            chat.AddText("Der CO Posten ist nun frei!")
        else
            chat.AddText(name.." ist nun der CO!")
        end

        co = name
       
    elseif was == "xo" then
        if xo == name then
            chat.AddText("Der XO Posten ist nun frei!")
        else
            chat.AddText(name.." ist nun der XO!")
        end

        xo = name
    elseif was == "ao" then
        if ao == name then
            chat.AddText("Der AO Posten ist nun frei!")
        else
            chat.AddText(name.." ist nun der AO!")
        end
        
        ao = name
    end

    local text = "CO: "..co.." | XO: "..xo.." | AO: "..ao

    surface.SetFont("MLIB.20")
    local tw, th = surface.GetTextSize(text)

    textLength = tw + PD.W(20)
end)

net.Receive("SyncBar",function()
    co = net.ReadString()
    xo = net.ReadString()
    ao = net.ReadString()
end)

AddSmoothElement(PD.W(20), ScrH() - PD.H(22.5), textLength, PD.H(0), function(smoothX, smoothY)
    if co == "" then co = "N/A" end
    if xo == "" then xo = "N/A" end
    if ao == "" then ao = "N/A" end

    local text = "CO: "..co.." | XO: "..xo.." | AO: "..ao

    surface.SetFont("MLIB.20")
    local tw, th = surface.GetTextSize(text)

    draw.RoundedBox(0, smoothX, smoothY - PD.H(th - 3), tw + PD.W(20), PD.H(th), PD.UI.Colors["Background"])

    surface.SetDrawColor(DEFCON:GetColor())
    surface.DrawOutlinedRect(smoothX, smoothY - PD.H(th - 3), tw + PD.W(20), PD.H(th), 2)

    draw.SimpleText(text, "MLIB.20", smoothX + PD.W(10), smoothY, Color(255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

    PD.COBar.tbl = {
        co = co,
        xo = xo,
        ao = ao
    }
end)

function PD.COBar.GetName()
    return PD.COBar.tbl 
end

