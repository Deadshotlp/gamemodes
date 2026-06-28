PD.Funk = PD.Funk or {}

local localChats = {
    dms = {},
    channels = {},
    recent = {}
}
local currentTarget = {
    type = "",
    id = ""
}

net.Receive("PD.Funk:ReceiveMsgCL", function()
    local ttype = net.ReadString()
    local tid = net.ReadString()
    local sender = net.ReadString()
    local msg = net.ReadString()
    local ts = net.ReadUInt(32)

    surface.PlaySound("mario/comlinksound.mp3")

    if ttype == "dm" then
        local key = tid
        localChats.dms[key] = localChats.dms[key] or {}
        table.insert(localChats.dms[key], {
            sender = sender,
            msg = msg,
            time = ts
        })
        localChats.recent["Direkt" .. ": " .. key] = true
    else
        local key = tid
        localChats.channels[key] = localChats.channels[key] or {}
        table.insert(localChats.channels[key], {
            sender = sender,
            msg = msg,
            time = ts
        })
        localChats.recent[LANG.CHAR_UI_UNIT .. ": " .. key] = true
    end

    if IsValid(mainFrame) and currentTarget.type == ttype and currentTarget.id == tid and IsValid(mainFrame.chatScroll) then
        local timeTable = os.date("*t", ts)
        local timeString = string.format("%02d:%02d", timeTable.hour, timeTable.min)
        local msgLabel = PD.Label("[" .. timeString .. "] " .. sender .. ": " .. msg, mainFrame.chatScroll)
        msgLabel:Dock(TOP)
        msgLabel:DockMargin(PD.W(5), PD.H(5), PD.W(5), PD.H(5))
        msgLabel:SetWrap(true)
        msgLabel:SetAutoStretchVertical(true)
    end
end)

net.Receive("PD.Funk:OpenFunkMenu", function()
    local payload = net.ReadTable()
    localChats = payload.chats or localChats

    PD.Funk:Menu(payload.choices or {
        units = {},
        players = {}
    })
end)

local function openConversation(ttype, tid)
    if not IsValid(mainFrame) then
        return
    end

    currentTarget.type = ttype
    currentTarget.id = tid
    mainFrame:Clear()

    local topBar = PD.Panel(mainFrame)
    topBar:Dock(TOP)
    topBar:SetTall(PD.H(40))

    local backBtn = PD.Button(LANG.GENERIC_BACK, topBar, function()
        local choices = mainFrame._choices
        mainFrame:Remove()
        PD.Funk:Menu(choices)
    end)
    backBtn:Dock(LEFT)
    backBtn:SetWide(PD.W(100))

    local title =
        PD.Label((ttype == "dm" and "Chat mit " or (LANG.CHAR_UI_UNIT .. " ")) .. tid, topBar)
    title:Dock(FILL)
    title:SetContentAlignment(5)

    local scrl = PD.Scroll(mainFrame)
    mainFrame.chatScroll = scrl

    local list = ttype == "dm" and (localChats.dms[tid] or {}) or (localChats.channels[tid] or {})

    for _, v in ipairs(list) do
        local tt = os.date("*t", v.time)
        local ts = string.format("%02d:%02d", tt.hour, tt.min)
        local lbl = PD.Label("[" .. ts .. "] " .. v.sender .. ": " .. v.msg, scrl)
        lbl:Dock(TOP)
        lbl:DockMargin(PD.W(5), PD.H(5), PD.W(5), PD.H(5))
        lbl:SetWrap(true)
        lbl:SetAutoStretchVertical(true)
    end

    local bottomPanel = PD.Panel(mainFrame)
    bottomPanel:Dock(BOTTOM)
    bottomPanel:SetTall(PD.H(70))

    local textEntry = PD.TextEntry(bottomPanel, "Gib deine Nachricht ein...")
    textEntry:SetMultiline(true)
    textEntry:Dock(FILL)

    local sendButton = PD.Button("Senden", bottomPanel, function()
        local msg = textEntry:GetValue()
        if msg == "" then
            return
        end
        net.Start("PD.Funk:SendMsgSV")
        net.WriteString(ttype)
        net.WriteString(tid)
        net.WriteString(msg)
        net.SendToServer()
        textEntry:SetValue("")
    end)
    sendButton:Dock(RIGHT)
    sendButton:SetWide(PD.W(100))
end

local function New_Conversation()

    local scrl = PD.Scroll(mainFrame)
    scrl:Dock(FILL)

    local function populateScrl(data)
        scrl:Clear()
        if data.type == "player" then
            for _, p in ipairs(mainFrame._choices.players or {}) do
                if p ~= LocalPlayer():Nick() then
                    local btn = PD.Button(p, scrl, function()
                        openConversation("dm", p)
                    end)
                    btn:Dock(TOP)
                    btn:SetTall(PD.H(36))
                    btn:DockMargin(PD.W(5), PD.H(5), PD.W(5), 0)
                end
            end
        elseif data.type == "unit" then
            for _, u in ipairs(mainFrame._choices.units or {}) do
                local btn = PD.Button(u, scrl, function()
                    openConversation("unit", u)
                end)
                btn:Dock(TOP)
                btn:SetTall(PD.H(36))
                btn:DockMargin(PD.W(5), PD.H(5), PD.W(5), 0)
            end
        end
    end

    local targetSelect = PD.Dropdown(mainFrame, "Empfänger auswählen", function(value, data)
        if not data then
            print("dadadfff")
            return
        end
        populateScrl(data)
        --openConversation(data.type, data.id)
    end)
    targetSelect:SetTall(PD.H(40))

    targetSelect:AddOption("Spieler", {
        type = "player",
        id = ""
    })
    targetSelect:AddOption("Einheit", {
        type = "unit",
        id = ""
    })

    -- if mainFrame._choices and mainFrame._choices.units then
    --     for _, u in ipairs(mainFrame._choices.units) do
    --         targetSelect:AddOption("[" .. LANG.CHAR_UI_UNIT .. "] " .. u, {
    --             type = "unit",
    --             id = u
    --         })
    --     end
    -- end

    -- if mainFrame._choices and mainFrame._choices.players then
    --     for _, p in ipairs(mainFrame._choices.players) do
    --         if p ~= LocalPlayer():Nick() then
    --             targetSelect:AddOption("[" .. "Direkt" .. "] " .. p, {
    --                 type = "dm",
    --                 id = p
    --             })
    --         end
    --     end
    -- end


    local newConversation = PD.Button("Zurück", mainFrame, function()
        local choices = mainFrame._choices
        mainFrame:Remove()
        PD.Funk:Menu(choices)
    end)
    newConversation:Dock(BOTTOM)
    newConversation:SetTall(PD.H(36))
    newConversation:DockMargin(PD.W(5), PD.H(5), PD.W(5), 0)
end

function PD.Funk:Menu(choices)
    if IsValid(mainFrame) then
        return
    end

    mainFrame = PD.Frame("Funk", PD.W(500), PD.H(600), true, nil, true)
    mainFrame:SetPos(ScrW() - mainFrame:GetWide() - PD.W(10), ScrH() / 2 - mainFrame:GetTall() / 2)
    mainFrame:MakePopup()
    mainFrame._choices = choices

    local newConversation = PD.Button("Neue Unterhaltung", mainFrame, function()
        mainFrame:Clear()
        New_Conversation()
    end)
    newConversation:Dock(TOP)
    newConversation:SetTall(PD.H(36))
    newConversation:DockMargin(PD.W(5), PD.H(5), PD.W(5), 0)

    local recentLabel = PD.Label("Letzte Unterhaltungen", mainFrame)
    recentLabel:Dock(TOP)
    recentLabel:SetTall(PD.H(30))
    recentLabel:SetContentAlignment(5)

    local recScroll = PD.Scroll(mainFrame)

    for key, _ in pairs(localChats.recent or {}) do
        local ttype, tid = string.match(key, "^(%w+):(.+)$")
        if ttype and tid then
            local btn = PD.Button(
                (ttype == "dm" and "[Direkt] " or "[" .. LANG.CHAR_UI_UNIT .. "] ") .. tid,
                recScroll, function()
                    openConversation(ttype, tid)
                end)
            btn:Dock(TOP)
            btn:SetTall(PD.H(36))
            btn:DockMargin(PD.W(5), PD.H(5), PD.W(5), 0)
        end
    end
end

concommand.Add("pd_funk_open", function()
    if IsValid(mainFrame) then
        return
    end

    net.Start("PD.Funk:RequestOpenMenu")
    net.SendToServer()
end)

