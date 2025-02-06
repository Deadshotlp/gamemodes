-- 

local history = {}

function ChatMenu()
    if IsValid(chatMenu) then return end

    chatMenu = PD.Frame("ChatMenu", PD.W(600), PD.H(300), true, nil, true)
    chatMenu:MakePopup()
    chatMenu:SetPos(PD.W(10), ScrH() - PD.H(600))

    local chatBox = PD.TextEntry("", chatMenu)
    chatBox:SetTall(PD.H(30))
    chatBox:Dock(BOTTOM)
    chatBox.OnEnter = function(self)
        local text = self:GetText()
        if (text == "") then return end

        table.insert(history, text)
        if (#history > 10) then
            table.remove(history, 1)
        end

        net.Start("PD_AddChat")
            net.WriteString(text)
        net.SendToServer()

        chatMenu:Remove()
    end

    local chatHistory = PD.Scroll(chatMenu)

    for k, v in pairs(history) do
        local label = PD.Label(v, chatHistory)
        label:Dock(TOP)
        label:SetTall(PD.H(20))
    end
end

hook.Add("PlayerBindPress", "OpenChatPD", function(player, bind, pressed)
	if ((bind == "messagemode" or bind == "say") and pressed) then
        -- ChatMenu()		
	end

	if (bind == "messagemode2" and pressed) then
		-- Admin chat

	end
end)    

hook.Add("ChatText", "ChatTextPD", function(index, name, text, filter)
	if (tonumber(index) == 0) then
		if (filter == "joinleave") then
			return ""
		elseif (filter == "none") then
			if (name == "Console") then
			end
		elseif (filter == "chat") then
			if (name and name != "") then
				chat.AddText(color_grey, name, color_white, text)
			else
				timer.Simple(0, function() chat.AddText(color_white, text) end)
			end
		end
	end
end)

