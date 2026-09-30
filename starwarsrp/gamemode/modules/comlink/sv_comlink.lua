PD.Comlink = PD.Comlink or {}
PD.Comlink.Table = {}
-- PD.Comlink.Table[1] = {
--     name = "TeamChannel",
--     color = Color(255, 0, 0),
--     mute = true,
--     encrypted = false,
--     passkey = "",
--     check = function(ply)
--         return ply:IsAdmin()
--     end,
-- }

util.AddNetworkString("PD.Comlink.StartVoice")
util.AddNetworkString("PD.Comlink.EndVoice")
util.AddNetworkString("PD.Comlink.SendTalkerInfo")
util.AddNetworkString("PD.Comlink.SendListenerInfo")

util.AddNetworkString("PD.Comlink.RequestComlinkChannel")
util.AddNetworkString("PD.Comlink.SendComlinkChannel")

util.AddNetworkString("PD.Comlink.RequestCreateCustomChannel")
util.AddNetworkString("PD.Comlink.SendNewCustomChannel")


util.AddNetworkString("PD.Comlink.RequestCustomChannel")
util.AddNetworkString("PD.Comlink.SendCustomChannel")

-- Schluessel ist der Spieler selbst, nicht sein Name: PLAYER:Nick() liefert den
-- RP-Namen und faellt auf "Unknown" zurueck, wodurch sich alle Spieler ohne
-- gesetzten Namen einen Eintrag geteilt haben - und ein Namenswechsel den
-- bestehenden Eintrag verwaist zuruecklaesst.
local playerTalkerTable = {}

-- Sendet der Spieler gerade aktiv auf einem Kanal? (fuer PD.VoiceFX)
function PD.Comlink.IsTransmitting(ply)
    if not IsValid(ply) then return false end

    local data = playerTalkerTable[ply]

    return data ~= nil and data.active ~= nil
end

net.Receive("PD.Comlink.StartVoice", function(len, ply)
    local channel = net.ReadInt(8)
    local id = net.ReadInt(4)

    if not PD.Comlink.Table[channel] or not PD.Comlink.Table[channel].check(ply) then return end

    local data = playerTalkerTable[ply]
    if not data then
        data = {}
        playerTalkerTable[ply] = data
    end

    if id == 1 then
        data.active = channel
        -- Fuer die Anzeige bei den Mithoerern: auf welchem Kanal wird gesendet.
        ply:SetNW2Int("PD.Comlink.Active", channel)
    elseif id == 2 then
        data.passive1 = channel
    elseif id == 3 then
        data.passive2 = channel
    elseif id == 4 then
        data.passive3 = channel
    end

    if id == 1 and PD.VoiceFX then PD.VoiceFX.Refresh(ply) end
end)

net.Receive("PD.Comlink.EndVoice", function(len, ply)
    local channel = net.ReadInt(8)
    local id = net.ReadInt(4)

    local data = playerTalkerTable[ply]
    if not data then return end

    if id == 1 then
        data.active = nil
        ply:SetNW2Int("PD.Comlink.Active", 0)
    elseif id == 2 then
        data.passive1 = nil
    elseif id == 3 then
        data.passive2 = nil
    elseif id == 4 then
        data.passive3 = nil
    end

    if id == 1 and PD.VoiceFX then PD.VoiceFX.Refresh(ply) end
end)

hook.Add("PlayerDisconnected", "PD.Comlink.Cleanup", function(ply)
    playerTalkerTable[ply] = nil
end)

concommand.Add("printcomlink", function(ply)
    -- Serverbefehle kann jeder Client ausfuehren: nur Konsole und Superadmins.
    if IsValid(ply) and not ply:IsSuperAdmin() then return end

    for k, v in pairs(playerTalkerTable) do
        print(IsValid(k) and k:Nick() or tostring(k))
        PrintTable(v)
    end
end)

hook.Add("PlayerCanHearPlayersVoice", "PD.Comlink.Voice", function(listener, talker)
    if talker == listener then return true end
    if talker.UsingIntercom then return true end

    local talkerData = playerTalkerTable[talker]
    local listenerData = playerTalkerTable[listener]

    --Wenn einer von beiden nicht im Comlink ist, dann normale Voice durch Nähe
    if not talkerData or not listenerData then
        -- Local Talk

        local talker_pos = talker:GetPos()
        local listener_pos

        if listener:Alive() then
            listener_pos = listener:GetPos()
        elseif listener:GetNW2Entity("PD.DM.Ragdoll"):IsValid() then
            listener_pos = listener:GetNW2Entity("PD.DM.Ragdoll"):GetPos()
        end
        
        local voiceMode = talker:GetNWInt("VoiceMode",2)
        local modeSettings = PD.VC.Config[voiceMode]
        local distance = listener_pos:Distance(talker_pos)

        if distance <= modeSettings.range and talker:Alive() then
            return true, true
        else
            return false, false
        end
    end

    local talkerChannel = talkerData.active
    local listenerChannel = listenerData

    if not talkerChannel then
        return listener:GetPos():DistToSqr(talker:GetPos()) <= 250000, true
    end

    local talkerJobID, talkerJobTable = talker:GetJob()
    local listenerJobID, listenerJobTable = listener:GetJob()
    local unit = talkerJobTable.unit

    -- Channel existiert nicht oder Check schlägt fehl
    local channelConfig = PD.Comlink.Table[talkerChannel]
    if not channelConfig or not channelConfig.check(talker, unit) then
        return false
    end

    -- Hört der Listener den Talker-Channel überhaupt (aktiv oder passiv)?
    local listenerOnChannel = listenerChannel.active == talkerChannel
        or listenerChannel.passive1 == talkerChannel
        or listenerChannel.passive2 == talkerChannel
        or listenerChannel.passive3 == talkerChannel

    if not listenerOnChannel then
        return listener:GetPos():DistToSqr(talker:GetPos()) <= 250000, true
    end

    -- Check auch für Listener auf dem Talker-Channel
    if not channelConfig.check(listener, unit) then
        return false
    end

    return true, false
end)

function PD.Comlink.CreateDefaultChannel()
    PD.Comlink.Table[1] = {
        name = "TeamChannel",
        color = Color(255, 0, 0),
        mute = true,
        encrypted = false,
        passkey = "",
        check = function(ply)
            return ply:IsAdmin()
        end,
    }

    PD.Comlink.Table[2] = {
        name = "Einsatzkoordinations Funk",
        color = Color(255, 255, 255),
        mute = false,
        encrypted = false,
        passkey = "",
        check = function(ply)
            return true
        end,
    } 

    PD.Comlink.Table[3] = {
        name = "Medizinischer Notfall Funk",
        color = Color(255, 0, 0),
        mute = false,
        encrypted = false,
        passkey = "",
        check = function(ply)
            return true
        end,
    }

    PD.Comlink.Table[4] = {
        name = "Technischer Notfall Funk",
        color = Color(255, 125, 0),
        mute = false,
        encrypted = false,
        passkey = "",
        check = function(ply)
            return true
        end,
    }
end

function PD.Comlink.CheckUnitAccess(ply, unit)
    if not IsValid(ply) then return false end
    if not unit then return false end

    local jobName, jobTable = ply:GetJob()
    local subunitName, subunitTable = PD.JOBS.GetSubUnit(jobTable.unit, false)

    if subunitTable.unit and subunitTable.unit ~= unit then
        return false
    end

    return true
end

function PD.Comlink.CheckSubUnitAccess(ply, unit)
    if not IsValid(ply) then return false end
    if not unit then return false end

    local jobName, jobTable = ply:GetJob()
    if jobTable.unit and jobTable.unit ~= unit then
        return false
    end

    return true
end

function PD.Comlink.UnitDefaultChannel()
    for k, v in pairs(PD.JOBS.GetUnit(false, true)) do
        table.insert(PD.Comlink.Table, {
            name = v.name,
            color = v.color,
            mute = true,
            encrypted = false,
            passkey = "",
            check = function(ply, unit)
                return PD.Comlink.CheckUnitAccess(ply, v.name)
            end,
        })
    end

    for k, v in pairs(PD.JOBS.GetSubUnit(false, true)) do
        table.insert(PD.Comlink.Table, {
            name = v.name,
            color = v.color,
            mute = true,
            encrypted = false,
            passkey = "",
            check = function(ply, unit)
                return PD.Comlink.CheckSubUnitAccess(ply, v.name)
            end,
        })
    end
end

-- function PD.Comlink.CreateTemporaryChannel(name, color, encrypted, passkey)
--     -- for x, v in pairs()

--     table.insert(PD.Comlink.Table, {
--         name = tostring(name),
--         color = color,
--         mute = false,
--         encrypted = tobool(encrypted),
--         passkey = tostring(passkey),
--         check = function(ply)
--             return true
--         end,
--     })

--     net.Start
-- end

--[[
    Eigene Kanaele. Frueher ohne Absender und ohne Grenze: jeder Client konnte
    beliebig viele Kanaele mit beliebigen Werten anlegen, und alle gingen an
    alle Spieler. Kanaele werden nie entfernt, weil StartVoice sie ueber ihren
    Listenindex anspricht - deshalb die festen Obergrenzen.
]]
local CUSTOM_MAX_TOTAL = 20
local CUSTOM_MAX_PER_PLAYER = 2
local CUSTOM_NAME_MAX = 32
local CUSTOM_COOLDOWN = 5

net.Receive("PD.Comlink.RequestCreateCustomChannel", function(len, ply)
    if not IsValid(ply) then return end

    local now = CurTime()
    if (ply.PD_ComlinkCreateNext or 0) > now then return end
    ply.PD_ComlinkCreateNext = now + CUSTOM_COOLDOWN

    local tbl = net.ReadTable()
    if not istable(tbl) then return end

    local name = string.Trim(tostring(tbl.name or ""))
    if name == "" or #name > CUSTOM_NAME_MAX then
        PD.Notify("Kanalname muss 1 bis " .. CUSTOM_NAME_MAX .. " Zeichen lang sein.", Color(255, 60, 60), false, ply)
        return
    end

    local sid = ply:SteamID64()
    local total, own = 0, 0

    for _, v in pairs(PD.Comlink.Table) do
        if v.name == name then
            return
        end

        if v.owner then
            total = total + 1
            if v.owner == sid then own = own + 1 end
        end
    end

    if total >= CUSTOM_MAX_TOTAL or own >= CUSTOM_MAX_PER_PLAYER then
        PD.Notify("Es können keine weiteren Kanäle erstellt werden.", Color(255, 60, 60), false, ply)
        return
    end

    local c = istable(tbl.color) and tbl.color or {}
    local color = Color(
        math.Clamp(tonumber(c.r) or 255, 0, 255),
        math.Clamp(tonumber(c.g) or 255, 0, 255),
        math.Clamp(tonumber(c.b) or 255, 0, 255)
    )

    local encrypted = tobool(tbl.encrypted)

    table.insert(PD.Comlink.Table, {
        name = name,
        color = color,
        mute = false,
        encrypted = encrypted,
        passkey = string.sub(tostring(tbl.passkey or ""), 1, 64),
        owner = sid,
        check = function()
            return true
        end,
    })

    net.Start("PD.Comlink.SendNewCustomChannel")
    net.WriteTable({name = name, color = color, encrypted = encrypted, index = #PD.Comlink.Table})
    net.Broadcast()
end)

local function LoadComlinkChannel()
    PD.Comlink.CreateDefaultChannel()
    PD.Comlink.UnitDefaultChannel()
end

LoadComlinkChannel()

net.Receive("PD.Comlink.RequestComlinkChannel", function(len, ply)
    local comprest_table = {}

    for x, v in pairs(PD.Comlink.Table) do 
        if not v.check(ply) then continue end

        -- Schluessel ist der Server-Index. Frueher per table.insert neu
        -- durchnummeriert: fehlte dem Spieler ein Kanal, verschoben sich die
        -- Nummern, und StartVoice landete auf einem anderen Kanal als gewaehlt.
        comprest_table[x] = {
            name = v.name,
            color = v.color,
            encrypted = v.encrypted,
        }
    end

    net.Start("PD.Comlink.SendComlinkChannel")
    net.WriteTable(comprest_table)
    net.Send(ply)
end)