PD.Chat = PD.Chat or {}
PD.Chat.MSG = PD.Chat.MSG or {}

PD.Chat.Config = PD.Chat.Config or {
    MaxMessages = 50,
    y = ScrH() - PD.H(350),
    x = PD.W(50),
    w = PD.W(250),
    h = PD.H(300),
    showTimestamps = false
}

PD.Chat.ConfigFile = "pd_chat_config"

local function load_chat_config()
    if not file.IsDir("modules/" .. PD.Chat.ConfigFile, "DATA") then
        file.CreateDir("modules/" .. PD.Chat.ConfigFile)
    end

    if file.Exists("modules/" .. PD.Chat.ConfigFile .. "/" .. LocalPlayer():Nick() .. ".json", "DATA") then
        PD.Chat.Config = util.JSONToTable(file.Read("modules/" .. PD.Chat.ConfigFile .. "/" .. LocalPlayer():Nick() .. ".json", "DATA"))
    end
end

local function save_chat_config()
    if not file.IsDir("modules/" .. PD.Chat.ConfigFile, "DATA") then
        file.CreateDir("modules/" .. PD.Chat.ConfigFile)
    end

    file.Write("modules/" .. PD.Chat.ConfigFile .. "/" .. LocalPlayer():Nick() .. ".json", util.TableToJSON(PD.Chat.Config, true))
end

local function populateChat(scrollPanel)
    scrollPanel:Clear()

    for _, msg in pairs(PD.Chat.MSG) do
        if PD.Chat.Config.showTimestamps then
            local time = os.date("%H:%M:%S", msg.time)
            msg.text = string.format("[%s] %s", time, msg.text)
        end
        local lines = PD.WrapText(msg.text, scrollPanel:GetWide())

        for _, line in pairs(lines) do
            local label = PD.Label(line, scrollPanel, {color = PD.Chat.Command.List[msg.key] and PD.Chat.Command.List[msg.key].color or Color(255, 255, 255)})
            label:Dock(TOP)
            label:SetAutoStretchVertical(true)
        end
    end
    
end

function PD.Chat:Open()
    if IsValid(ChatMainFrame) then
        ChatMainFrame:Remove()
    end

    ChatMainFrame = PD.Frame("Chat", PD.Chat.Config.w, PD.Chat.Config.h, true, {onClose = function()
        local x, y = ChatMainFrame:GetPos()
        local w, h = ChatMainFrame:GetSize()

        PD.Chat.Config.x = x
        PD.Chat.Config.y = y
        PD.Chat.Config.w = w
        PD.Chat.Config.h = h

        save_chat_config()
    end})
    ChatMainFrame:SetDraggable(true)
    ChatMainFrame:SetSizable(true)
    ChatMainFrame:SetPos(PD.Chat.Config.x, PD.Chat.Config.y)
    ChatMainFrame.OnSizeChanged = function( newWidth, newHeight )
        local x, y = ChatMainFrame:GetPos()
        local w, h = ChatMainFrame:GetSize()

        PD.Chat.Config.x = x
        PD.Chat.Config.y = y
        PD.Chat.Config.w = w
        PD.Chat.Config.h = h

        ChatMainFrame:GetContentPanel():Clear()
        ChatMainFrame.CloseButton:SetPos( ChatMainFrame:GetWide() - PD.W(40), PD.H(8))
        drawChatComponens()
        save_chat_config()
    end

    function drawChatComponens()
        local textEntry = PD.TextEntry(ChatMainFrame:GetContentPanel(), "Write your message...", "", function() end, {dock = BOTTOM})
        textEntry.OnEnter = function(self)
            local text = string.Trim(self:GetValue() or "")
            if text == "" then
                self:SetText("")
                return
            end

            self:SetText("")
            PD.Chat.HandleMessage(text)
            hook.Run("OnPlayerChat", LocalPlayer(), text, false, not LocalPlayer():Alive())
        end
        textEntry:RequestFocus()

        local scrollPanel = PD.Scroll(ChatMainFrame:GetContentPanel())
        scrollPanel:Dock(FILL)
        scrollPanel:SetSize( ChatMainFrame:GetWide(), ChatMainFrame:GetTall() - textEntry:GetTall() )

        ChatMainFrame.scrollPanel = scrollPanel
        populateChat(scrollPanel)
    end

    drawChatComponens()
end

function PD.Chat:AddMSG(text, key)
    table.insert(self.MSG, {time = os.time(), text = text, key = key})

    if #self.MSG > 50 then
        table.remove(self.MSG, 1)
    end
end

function PD.Chat.HandleMessage(text)
    net.Start("PD.Chat.SendMSG")
        net.WriteString(text)
    net.SendToServer()
end

net.Receive("PD.Chat.SendMSG", function()
    local text = net.ReadString()
    local key = net.ReadString()

    PD.Chat:AddMSG(text, key)
    if IsValid(ChatMainFrame) and IsValid(ChatMainFrame.scrollPanel) then
        populateChat(ChatMainFrame.scrollPanel)
    end
end)

local messageBinds = {
    ["messagemode"] = true,
    ["messagemode2"] = true,
    ["say"] = true,
    ["say_team"] = true
}

hook.Add("ChatText", "PD.Chat.HandleChatText", function(index, name, text, type)
    if type == "joinleave" then
        return
    end

    PD.Chat:AddMSG(text)

    return true
end)

hook.Add("PlayerBindPress", "PD.Chat.DisableBind", function(ply, bind, pressed)
    if not pressed or not messageBinds[bind] then return end

    PD.Chat:Open()

    return true
end)

hook.Add("HUDShouldDraw", "PD.Chat.HideNormalChat", function(name)
    if name == "CHudChat" then return false end
end)

hook.Add("OnPauseMenuShow", "PD.Chat.CloseOnPauseMenuShow", function()
    if IsValid(ChatMainFrame) then
        ChatMainFrame:Remove()
    end
end)

load_chat_config()