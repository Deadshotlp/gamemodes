PD.Funk = PD.Funk or {}

local localTexttoPly = {}

net.Receive("PD.Funk:GetTextToPly", function()
    local msg = net.ReadString()

    table.insert(localTexttoPly, {
        text = msg,
        time = CurTime()
    })

    print("Received message: " .. msg)
end)


local MESSAGE_DURATION = 15 -- Sekunden

AddSmoothElement(PD.W(190), PD.H(20), PD.W(400), PD.H(150), function(smoothX, smoothY)
    -- draw.RoundedBox(0, smoothX, smoothY, PD.W(400), PD.H(150), PD.UI.Colors["Background"])

    local yOffset = 10
    local font = "DermaDefault"
    surface.SetFont(font)

    for i, msgData in ipairs(localTexttoPly) do
        local elapsed = CurTime() - msgData.time
        local alpha = 255

        if elapsed > MESSAGE_DURATION then
            alpha = 255 - ((elapsed - MESSAGE_DURATION) * 255)
            if alpha <= 0 then
                table.remove(localTexttoPly, i)
                continue
            end
        end

        draw.SimpleText(msgData.text, font, smoothX + 10, smoothY + yOffset, Color(255, 255, 255, alpha), 0, 0)
        yOffset = yOffset + 20
    end
end)

local localPlayerChats = {}
localPlayerChats["PlayerName"] = {
    alltext = {
        [1] = {
            text = "Hello, this is a test message!",
            time = CurTime()
        },
        [2] = {
            text = "Another message to display.",
            time = CurTime() + 5
        }
    },
    shownotification = true
}


function PD.Funk:Menu()
    if IsValid(mainFrame) then return end

    mainFrame = PD.Frame("Funks", PD.W(800), PD.H(600), true)

    local rightPanel = PD.Panel("", mainFrame)
    rightPanel:Dock(FILL)

    local leftPanel = PD.SideTab(mainFrame, rightPanel)

    PD.AddSideItem("Öffentlicher Funk", function(pnl)
    
    end)

    PD.AddSideItem("Privater Funk", function(pnl)
    
    end)

    PD.AddSideItem("Langstrecken Funk", function(pnl)
    
    end)

end

if mainFrame then 
    mainFrame:Remove()
end

-- PD.Funk:Menu()
