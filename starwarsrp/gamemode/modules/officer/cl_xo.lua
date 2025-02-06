PG.COBar = PG.COBar or {}

local co,xo,ao = "N/A","N/A","N/A"
local x,y = PG.W(10),ScrH()-PG.H(10)
LocalPlayer().COBar = true

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
end)

net.Receive("SyncBar",function()
    co = net.ReadString()
    xo = net.ReadString()
    ao = net.ReadString()
end)

hook.Add("HUDPaint","Mario_Leiste_Gaga0",function()
    if not LocalPlayer():Alive() then return end
    
    if co == "" then co = "N/A" end
    if xo == "" then xo = "N/A" end
    if ao == "" then ao = "N/A" end

    local text = "CO: "..co.." | XO: "..xo.." | AO: "..ao
    local algn = TEXT_ALIGN_LEFT

    surface.SetFont("MLIB.20")
    local tw, th = surface.GetTextSize(text)

    surface.SetDrawColor(255,255,255)
    surface.DrawOutlinedRect(x, y - th - PD.H(5), tw + PG.W(20), th + PG.H(10), 2)

    draw.SimpleText(text, "MLIB.20", x + PD.W(10), y, Color(255,255,255), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)
  
    PG.COBar.tbl = {
        co = co,
        xo = xo,
        ao = ao
    }
end)

function PG.COBar.GetName()
    return PG.COBar.tbl 
end

