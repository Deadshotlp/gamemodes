PD.Funk = PD.Funk or {}

util.AddNetworkString("PD.Funk:SendMsgSV")
util.AddNetworkString("PD.Funk:ReceiveMsgCL")
util.AddNetworkString("PD.Funk:OpenFunkMenu")
util.AddNetworkString("PD.Funk:RequestOpenMenu")

local ChatStore = {dms = {}, channels = {}}
local function dmKey(a,b)
    if a:lower() < b:lower() then return a.."|"..b end
    return b.."|"..a
end

net.Receive("PD.Funk:SendMsgSV", function(_, ply)
    local ttype = net.ReadString()
    local tid = net.ReadString()
    local msg = string.Trim(net.ReadString() or "")
    
    if msg == "" then return end
    
    local ts = os.time()
    
    if ttype == "dm" then
        local key = dmKey(ply:Nick(), tid)
        ChatStore.dms[key] = ChatStore.dms[key] or {}
        table.insert(ChatStore.dms[key], {sender = ply:Nick(), msg = msg, time = ts})
        for _, v in ipairs(player.GetAll()) do
            local n = v:Nick()
            if n == tid or n == ply:Nick() then
                net.Start("PD.Funk:ReceiveMsgCL")
                net.WriteString("dm")
                net.WriteString(n == ply:Nick() and tid or ply:Nick())
                net.WriteString(ply:Nick())
                net.WriteString(msg)
                net.WriteUInt(ts,32)
                net.Send(v)
            end
        end
    else
        local key = tid
        ChatStore.channels[key] = ChatStore.channels[key] or {}
        table.insert(ChatStore.channels[key], {sender = ply:Nick(), msg = msg, time = ts})
        --for _, v in ipairs(player.GetAll()) do
            net.Start("PD.Funk:ReceiveMsgCL")
            net.WriteString("unit")
            net.WriteString(key)
            net.WriteString(ply:Nick())
            net.WriteString(msg)
            net.WriteUInt(ts,32)
            net.Broadcast()
            --net.Send(v)
        --end
    end
end)

net.Receive("PD.Funk:RequestOpenMenu", function(_, ply)
    local payload = {chats = {dms = {}, channels = {}, recent = {}}, choices = {units = {}, players = {}}}
    local nick = ply:Nick()
    
    for key, list in pairs(ChatStore.dms) do
        local a,b = string.match(key, "^(.-)|(.+)$")
        if a == nick or b == nick then
            local peer = a == nick and b or a
            payload.chats.dms[peer] = {}
            for _, m in ipairs(list) do table.insert(payload.chats.dms[peer], m) end
            payload.chats.recent["dm:"..peer] = true
        end
    end
    
    for uname, list in pairs(ChatStore.channels) do
        payload.chats.channels[uname] = {}
        for _, m in ipairs(list) do table.insert(payload.chats.channels[uname], m) end
        for _, m in ipairs(list) do if m.sender == nick then payload.chats.recent["unit:"..uname] = true break end end
    end
    
    for k,_ in SortedPairs(PD.JOBS.GetUnit(false, true) or {}) do table.insert(payload.choices.units, k) end
    for _, v in ipairs(player.GetAll()) do table.insert(payload.choices.players, v:Nick()) end
    
    net.Start("PD.Funk:OpenFunkMenu")
    net.WriteTable(payload)
    net.Send(ply)
end)

concommand.Add("pd_funk_print", function()
    PrintTable(ChatStore)
end)

