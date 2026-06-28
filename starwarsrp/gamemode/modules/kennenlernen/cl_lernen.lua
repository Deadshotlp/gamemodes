--
local knownPlayers = {}
local dataFile = "known_players.json"

local function LoadKnown()
    if file.Exists(dataFile, "DATA") then
        local json = file.Read(dataFile, "DATA")
        knownPlayers = util.JSONToTable(json) or {}
    end
end

local function SaveKnown()
    file.Write(dataFile, util.TableToJSON(knownPlayers, true))
end

function PD.HUD.GetKnownPlayers(plyID)
    if plyID == LocalPlayer():SteamID64() then
        return LocalPlayer():Nick()
    end

    return knownPlayers[plyID] or LANG.MEET_UNKNOWN
end

function PD.HUD.GetKnownPlayersAll()
    return knownPlayers
end

hook.Add("InitPostEntity", "LoadKnownPlayers", function()
    LoadKnown()
end)

hook.Add("KeyPress", "HandleMeetKeyPress_Client", function(ply, key)

end)

-- local function KnownMenu(name)
--     if IsValid(knownMenuFrame) then
--         return
--     end
--     if not name or name == "" then
--         name = LANG.MEET_UNKNOWN
--     end

--     knownMenuFrame = PD.Frame(LANG.MEET_WHATS_THIS, PD.W(400), PD.H(150), true, nil, true)
--     knownMenuFrame:SetPos(PD.W(200), PD.H(20))

--     local lbl = PD.Label(name .. LANG.MEET_WANTS_NAME, knownMenuFrame)

--     local bottomPanel = PD.Panel("", knownMenuFrame)
--     bottomPanel:Dock(BOTTOM)
--     bottomPanel:SetTall(PD.H(50))

--     local accept = PD.Button(LANG.GENERIC_OK, bottomPanel, function()
--         knownMenuFrame:Remove()

--         net.Start("ConfirmMeet")
--             net.WriteEntity(LocalPlayer())
--             net.WriteEntity(ply)
--         net.SendToServer()
--     end)
--     accept:Dock(LEFT)
--     accept:SetWide(bottomPanel:GetWide() / 2 - PD.W(40))
--     accept:SetHoverColor(getColor("Green"))

--     local decline = PD.Button(LANG.GENERIC_CANCEL, bottomPanel, function()
--         knownMenuFrame:Remove()
--     end)
--     decline:Dock(RIGHT)
--     decline:SetWide(bottomPanel:GetWide() / 2 - PD.W(40))
--     decline:SetHoverColor(getColor("SithRed"))
-- end

net.Receive("StartMeetRequest", function()
    local sender = net.ReadEntity()

    if sender == LocalPlayer() then return end

    -- KnownMenu(sender:Nick())
end)

net.Receive("ConfirmMeet", function()
    local p1 = net.ReadEntity()
    local p2 = net.ReadEntity()

    if p1 == LocalPlayer() then
        knownPlayers[p2:SteamID64()] = p2:Nick()
    elseif p2 == LocalPlayer() then
        knownPlayers[p1:SteamID64()] = p1:Nick()
    end
    SaveKnown()
    chat.AddText(Color(0, 255, 255), "Du hast jemanden kennengelernt!")
end)
