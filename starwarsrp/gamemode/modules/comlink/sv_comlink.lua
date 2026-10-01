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
util.AddNetworkString("PD.Comlink.RequestDeleteCustomChannel")

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
        
        -- Tot ohne Leiche (z. B. Ragdoll entfernt): hoert niemanden in der Naehe.
        if not listener_pos then return false, false end

        local voiceMode = talker:GetNWInt("VoiceMode",2)
        local modeSettings = PD.VC.Config[voiceMode] or PD.VC.Config[2]
        if not modeSettings then return false, false end

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

--[[
    Feste Kanaele. Kommen aus der Datenbank (pd_comlink_channels, Web-Panel
    "Funk"); bis die geantwortet hat bzw. beim ersten Start gelten diese
    Startwerte - die bisher hier fest eingetragenen Kanaele.

    access: "all"   jeder
            "admin" nur Admins
            "units" nur die Einheiten/Untereinheiten in units (Namen)
]]
PD.Comlink.FixedChannels = PD.Comlink.FixedChannels or {
    {id = 1, name = "TeamChannel", color = {255, 0, 0}, access = "admin", units = {}},
    {id = 2, name = "Einsatzkoordinations Funk", color = {255, 255, 255}, access = "all", units = {}},
    {id = 3, name = "Medizinischer Notfall Funk", color = {255, 0, 0}, access = "all", units = {}},
    {id = 4, name = "Technischer Notfall Funk", color = {255, 125, 0}, access = "all", units = {}},
}

local function FixedAccessCheck(access, units)
    if access == "admin" then
        return function(ply)
            return IsValid(ply) and ply:IsAdmin()
        end
    end

    if access == "units" then
        return function(ply)
            if not IsValid(ply) then return false end

            for _, unit in ipairs(units or {}) do
                -- Ein Spieler ohne Job darf den Check nicht abstuerzen lassen.
                local okUnit, inUnit = pcall(PD.Comlink.CheckUnitAccess, ply, unit)
                if okUnit and inUnit then return true end

                local okSub, inSub = pcall(PD.Comlink.CheckSubUnitAccess, ply, unit)
                if okSub and inSub then return true end
            end

            return false
        end
    end

    return function()
        return true
    end
end

-- Baut die festen Kanaele neu auf. Ein Kanal behaelt seinen Index, solange es
-- ihn gibt (gleiche id) - Spieler-Slots zeigen weiter auf denselben Kanal.
function PD.Comlink.CreateDefaultChannel()
    local previous = {}

    for idx, ch in pairs(PD.Comlink.Table) do
        if ch.fixedChannel then
            previous[ch.fixedChannel] = idx
            PD.Comlink.Table[idx] = nil
        end
    end

    for _, def in ipairs(PD.Comlink.FixedChannels) do
        local key = "fixed:" .. tostring(def.id)
        local idx = previous[key]
        previous[key] = nil

        if not idx or PD.Comlink.Table[idx] then
            idx = PD.Comlink.FreeIndex()
        end

        if idx then
            local c = def.color or {}

            PD.Comlink.Table[idx] = {
                name = tostring(def.name),
                color = Color(tonumber(c[1]) or 255, tonumber(c[2]) or 255, tonumber(c[3]) or 255),
                mute = def.access ~= "all",
                encrypted = false,
                passkey = "",
                fixedChannel = key,
                check = FixedAccessCheck(def.access, def.units),
            }
        end
    end

    for _, idx in pairs(previous) do
        if PD.Comlink.Table[idx] == nil then
            PD.Comlink.DropIndex(idx)
        end
    end
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

-- Erster freier Kanalindex (StartVoice sendet ihn als Int(8): max. 127).
function PD.Comlink.FreeIndex()
    for i = 1, 127 do
        if PD.Comlink.Table[i] == nil then return i end
    end
end

-- Kanal-Index entfernen: wer darauf sendet oder mithoert, fliegt raus -
-- sonst haengt er am Index, den spaeter ein anderer Kanal bekommt.
function PD.Comlink.DropIndex(idx)
    PD.Comlink.Table[idx] = nil

    for p, data in pairs(playerTalkerTable) do
        if data.active == idx then
            data.active = nil

            if IsValid(p) then
                p:SetNW2Int("PD.Comlink.Active", 0)
                if PD.VoiceFX then PD.VoiceFX.Refresh(p) end
            end
        end

        if data.passive1 == idx then data.passive1 = nil end
        if data.passive2 == idx then data.passive2 = nil end
        if data.passive3 == idx then data.passive3 = nil end
    end
end

--[[
    Einheits- und Untereinheitskanaele aus dem Jobbaum.

    Lief frueher nur einmal beim Laden der Datei - zu dem Zeitpunkt sind die
    Jobs beim Serverstart noch nicht aus der Datenbank geladen, die Kanaele
    fehlten dann bis zum naechsten Lua-Refresh. Jetzt zusaetzlich bei jedem
    PD.JOBS.Loaded. Ein Kanal behaelt dabei seinen Index, solange es die
    Einheit gibt (Spieler-Slots zeigen weiter auf denselben Kanal).

    Serverseitig steht der Einheitsname im Schluessel, das Feld name fehlt
    oft - Kanaele ohne Namen liessen das Erstellen eigener Kanaele abstuerzen.
]]
function PD.Comlink.UnitDefaultChannel()
    local previous = {}

    for idx, ch in pairs(PD.Comlink.Table) do
        if ch.unitChannel then
            previous[ch.unitChannel] = idx
            PD.Comlink.Table[idx] = nil
        end
    end

    local function add(key, name, color, check)
        local idx = previous[key]
        previous[key] = nil

        if not idx or PD.Comlink.Table[idx] then
            idx = PD.Comlink.FreeIndex()
        end

        if not idx then return end

        PD.Comlink.Table[idx] = {
            name = name,
            color = istable(color) and Color(tonumber(color.r) or 255, tonumber(color.g) or 255, tonumber(color.b) or 255) or Color(255, 255, 255),
            mute = true,
            encrypted = false,
            passkey = "",
            unitChannel = key,
            check = check,
        }
    end

    for k, v in SortedPairs(PD.JOBS.GetUnit(false, true) or {}) do
        local unitName = tostring(v.name or k)

        add("unit:" .. unitName, unitName, v.color, function(ply, unit)
            return PD.Comlink.CheckUnitAccess(ply, unitName)
        end)
    end

    for k, v in SortedPairs(PD.JOBS.GetSubUnit(false, true) or {}) do
        local subName = tostring(v.name or k)

        add("sub:" .. subName, subName, v.color, function(ply, unit)
            return PD.Comlink.CheckSubUnitAccess(ply, subName)
        end)
    end

    -- Einheiten, die es nicht mehr gibt: Spieler von deren Index abmelden.
    for _, idx in pairs(previous) do
        if PD.Comlink.Table[idx] == nil then
            PD.Comlink.DropIndex(idx)
        end
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
    Eigene Kanaele.

    Jeder Spieler darf eine begrenzte Zahl anlegen. Ein verschluesselter Kanal
    ist fuer alle sichtbar, aber gesperrt: freigeschaltet wird er erst, wenn
    der Server den Schluessel geprueft hat. Der Schluessel verlaesst den Server
    nie. Kanaele verschwinden, wenn der Besitzer sie loescht oder den Server
    verlaesst.

    StartVoice spricht Kanaele ueber ihren Index an (net.WriteInt(…, 8)),
    deshalb belegen eigene Kanaele freie Plaetze bis 127 statt per
    table.insert ans Ende zu wandern.
]]
local CUSTOM_MAX_TOTAL = 20
local CUSTOM_MAX_PER_PLAYER = 2
local CUSTOM_NAME_MAX = 32
local CUSTOM_PASSKEY_MAX = 32
local CUSTOM_COOLDOWN = 5
local UNLOCK_COOLDOWN = 2

local ERROR_COLOR = Color(255, 60, 60)
local OK_COLOR = Color(60, 200, 90)

local freeIndex = PD.Comlink.FreeIndex

-- Die Kanalliste, wie dieser Spieler sie sieht. Gesperrte verschluesselte
-- Kanaele stehen mit locked = true drin, damit man sie entschluesseln kann.
function PD.Comlink.SendChannelList(ply)
    if not IsValid(ply) then return end

    local sid = ply:SteamID64()
    local list = {}

    for idx, v in pairs(PD.Comlink.Table) do
        -- Ein Fehler im Check (z. B. Spieler noch ohne Job) darf nicht die
        -- ganze Liste abbrechen.
        local checked, result = pcall(v.check, ply)
        local allowed = checked and result == true

        -- Schluessel ist der Server-Index. Frueher per table.insert neu
        -- durchnummeriert: fehlte dem Spieler ein Kanal, verschoben sich die
        -- Nummern, und StartVoice landete auf einem anderen Kanal als gewaehlt.
        if allowed or (v.owner and v.encrypted) then
            list[idx] = {
                name = v.name,
                color = v.color,
                encrypted = v.encrypted,
                locked = not allowed,
                own = v.owner ~= nil and v.owner == sid,
            }
        end
    end

    net.Start("PD.Comlink.SendComlinkChannel")
    net.WriteTable(list)
    net.Send(ply)
end

-- Nur an Spieler, die das Comlink schon geoeffnet haben: die anderen fragen
-- beim Oeffnen selbst an (und haben evtl. noch keinen Job, an dem die
-- Einheitenkanaele haengen).
local function SendChannelListToAll()
    for _, p in ipairs(player.GetHumans()) do
        if p.PD_ComlinkKnown then
            PD.Comlink.SendChannelList(p)
        end
    end
end

function PD.Comlink.RemoveCustomChannel(idx)
    local ch = PD.Comlink.Table[idx]
    if not ch or not ch.owner then return false end

    PD.Comlink.DropIndex(idx)

    SendChannelListToAll()

    return true
end

net.Receive("PD.Comlink.RequestCreateCustomChannel", function(len, ply)
    if not IsValid(ply) then return end

    local now = CurTime()
    if (ply.PD_ComlinkCreateNext or 0) > now then return end
    ply.PD_ComlinkCreateNext = now + CUSTOM_COOLDOWN

    local tbl = net.ReadTable()
    if not istable(tbl) then return end

    local name = string.Trim(tostring(tbl.name or ""))
    if name == "" or #name > CUSTOM_NAME_MAX then
        PD.Notify("Kanalname muss 1 bis " .. CUSTOM_NAME_MAX .. " Zeichen lang sein.", ERROR_COLOR, false, ply)
        return
    end

    local encrypted = tbl.encrypted == true
    local passkey = ""

    if encrypted then
        passkey = string.Trim(tostring(tbl.passkey or ""))

        if passkey == "" or #passkey > CUSTOM_PASSKEY_MAX then
            PD.Notify("Schlüssel muss 1 bis " .. CUSTOM_PASSKEY_MAX .. " Zeichen lang sein.", ERROR_COLOR, false, ply)
            return
        end
    end

    local sid = ply:SteamID64()
    local total, own = 0, 0

    for _, v in pairs(PD.Comlink.Table) do
        if string.lower(tostring(v.name or "")) == string.lower(name) then
            PD.Notify("Einen Kanal mit diesem Namen gibt es schon.", ERROR_COLOR, false, ply)
            return
        end

        if v.owner then
            total = total + 1
            if v.owner == sid then own = own + 1 end
        end
    end

    local idx = freeIndex()

    if total >= CUSTOM_MAX_TOTAL or own >= CUSTOM_MAX_PER_PLAYER or not idx then
        PD.Notify("Es können keine weiteren Kanäle erstellt werden.", ERROR_COLOR, false, ply)
        return
    end

    local c = istable(tbl.color) and tbl.color or {}
    local color = Color(
        math.Clamp(tonumber(c.r) or 255, 0, 255),
        math.Clamp(tonumber(c.g) or 255, 0, 255),
        math.Clamp(tonumber(c.b) or 255, 0, 255)
    )

    local channel = {
        name = name,
        color = color,
        mute = false,
        encrypted = encrypted,
        passkey = passkey,
        owner = sid,
        members = {},
    }

    channel.check = function(p)
        if not channel.encrypted then return true end
        if not IsValid(p) then return false end

        return p:SteamID64() == channel.owner or channel.members[p] == true
    end

    PD.Comlink.Table[idx] = channel
    ply.PD_ComlinkKnown = true

    PD.Notify("Kanal \"" .. name .. "\" erstellt.", OK_COLOR, false, ply)
    SendChannelListToAll()
end)

-- Verschluesselten Kanal mit Schluessel freischalten.
net.Receive("PD.Comlink.RequestCustomChannel", function(len, ply)
    if not IsValid(ply) then return end

    local now = CurTime()
    if (ply.PD_ComlinkUnlockNext or 0) > now then
        PD.Notify("Bitte kurz warten.", ERROR_COLOR, false, ply)
        return
    end
    ply.PD_ComlinkUnlockNext = now + UNLOCK_COOLDOWN

    local tbl = net.ReadTable()
    if not istable(tbl) then return end

    local idx = tonumber(tbl.index)
    local ch = idx and PD.Comlink.Table[idx]
    if not ch or not ch.owner or not ch.encrypted then return end

    if ch.check(ply) then
        PD.Comlink.SendChannelList(ply)
        return
    end

    if tostring(tbl.passkey or "") ~= ch.passkey then
        PD.Notify("Falscher Schlüssel.", ERROR_COLOR, false, ply)
        return
    end

    ch.members[ply] = true

    PD.Notify("Kanal \"" .. ch.name .. "\" entschlüsselt.", OK_COLOR, false, ply)
    PD.Comlink.SendChannelList(ply)
end)

-- Eigenen Kanal loeschen (Admins duerfen jeden eigenen Kanal loeschen).
net.Receive("PD.Comlink.RequestDeleteCustomChannel", function(len, ply)
    if not IsValid(ply) then return end

    local idx = net.ReadUInt(8)
    local ch = PD.Comlink.Table[idx]
    if not ch or not ch.owner then return end

    if ch.owner ~= ply:SteamID64() and not ply:IsAdmin() then return end

    local name = ch.name

    if PD.Comlink.RemoveCustomChannel(idx) then
        PD.Notify("Kanal \"" .. name .. "\" gelöscht.", OK_COLOR, false, ply)
    end
end)

hook.Add("PlayerDisconnected", "PD.Comlink.CustomChannels", function(ply)
    local sid = ply:SteamID64()

    for idx, ch in pairs(PD.Comlink.Table) do
        if ch.members then ch.members[ply] = nil end
    end

    -- Erst sammeln, dann loeschen: RemoveCustomChannel aendert die Tabelle.
    local owned = {}

    for idx, ch in pairs(PD.Comlink.Table) do
        if ch.owner and ch.owner == sid then
            owned[#owned + 1] = idx
        end
    end

    for _, idx in ipairs(owned) do
        PD.Comlink.RemoveCustomChannel(idx)
    end
end)

local function LoadComlinkChannel()
    PD.Comlink.CreateDefaultChannel()
    PD.Comlink.UnitDefaultChannel()
end

LoadComlinkChannel()

--[[
    Feste Kanaele und Sprachreichweiten aus der Datenbank (Web-Panel "Funk").
    Neu laden: pd_reload funk. Beim ersten Start mit den bisherigen Werten
    befuellt.
]]
local TBL_CHANNELS = "pd_comlink_channels"
local TBL_RANGES = "pd_voice_ranges"

util.AddNetworkString("PD.VC.Config")

local function SplitList(text)
    local out = {}

    for _, part in ipairs(string.Explode(",", tostring(text or ""))) do
        part = string.Trim(part)
        if part ~= "" then out[#out + 1] = part end
    end

    return out
end

function PD.Comlink.SendVoiceConfig(target)
    net.Start("PD.VC.Config")
    net.WriteTable(PD.VC.Config)

    if target then net.Send(target) else net.Broadcast() end
end

local function SeedFunk(callback)
    PD.SQL.FetchOne("SELECT (SELECT COUNT(*) FROM `" .. TBL_CHANNELS .. "`) AS c, (SELECT COUNT(*) FROM `" .. TBL_RANGES .. "`) AS r", function(row)
        local pending = 1
        local function finish()
            pending = pending - 1
            if pending <= 0 then callback() end
        end

        if row and tonumber(row.c) == 0 then
            for index, def in ipairs(PD.Comlink.FixedChannels) do
                pending = pending + 1
                PD.SQL.Query("INSERT INTO `" .. TBL_CHANNELS .. "` (`name`, `color`, `access`, `units`, `position`) VALUES ("
                    .. PD.SQL.EscapeString(def.name) .. ", "
                    .. PD.SQL.EscapeString(table.concat(def.color, ",")) .. ", "
                    .. PD.SQL.EscapeString(def.access) .. ", '', " .. index .. ")", finish)
            end
        end

        if row and tonumber(row.r) == 0 then
            for mode, cfg in ipairs(PD.VC.Config or {}) do
                pending = pending + 1
                PD.SQL.Query("INSERT INTO `" .. TBL_RANGES .. "` (`mode`, `name`, `range_units`) VALUES ("
                    .. mode .. ", " .. PD.SQL.EscapeString(cfg.name) .. ", " .. (tonumber(cfg.range) or 350) .. ")", finish)
            end
        end

        finish()
    end)
end

function PD.Comlink.LoadConfig(callback)
    local createChannels = "CREATE TABLE IF NOT EXISTS `" .. TBL_CHANNELS .. "` ("
        .. "`id` INT UNSIGNED NOT NULL AUTO_INCREMENT,"
        .. "`name` VARCHAR(64) NOT NULL,"
        .. "`color` VARCHAR(16) NOT NULL DEFAULT '255,255,255',"
        .. "`access` VARCHAR(16) NOT NULL DEFAULT 'all',"
        .. "`units` VARCHAR(1024) NOT NULL DEFAULT '',"
        .. "`position` INT NOT NULL DEFAULT 0,"
        .. "PRIMARY KEY (`id`)"
        .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

    local createRanges = "CREATE TABLE IF NOT EXISTS `" .. TBL_RANGES .. "` ("
        .. "`mode` INT NOT NULL,"
        .. "`name` VARCHAR(32) NOT NULL,"
        .. "`range_units` INT NOT NULL,"
        .. "PRIMARY KEY (`mode`)"
        .. ") ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

    PD.SQL.Query(createChannels, function()
        PD.SQL.Query(createRanges, function()
            SeedFunk(function()
                PD.SQL.FetchAll("SELECT * FROM `" .. TBL_CHANNELS .. "` ORDER BY `position`, `id`", function(channels)
                    PD.SQL.FetchAll("SELECT * FROM `" .. TBL_RANGES .. "` ORDER BY `mode`", function(ranges)
                        local fixed = {}

                        for _, row in ipairs(channels or {}) do
                            local access = row.access
                            if access ~= "admin" and access ~= "units" then access = "all" end

                            local rgb = SplitList(row.color)

                            fixed[#fixed + 1] = {
                                id = tonumber(row.id),
                                name = row.name,
                                color = {tonumber(rgb[1]) or 255, tonumber(rgb[2]) or 255, tonumber(rgb[3]) or 255},
                                access = access,
                                units = SplitList(row.units),
                            }
                        end

                        PD.Comlink.FixedChannels = fixed
                        PD.Comlink.CreateDefaultChannel()

                        -- Sprachreichweiten: genau die Stufen 1-4 (die Taste
                        -- schaltet reihum durch vier Stufen).
                        local vc = table.Copy(PD.VC.Config or {})
                        for _, row in ipairs(ranges or {}) do
                            local mode = tonumber(row.mode)
                            if mode and mode >= 1 and mode <= 4 then
                                vc[mode] = {
                                    name = row.name,
                                    range = math.Clamp(tonumber(row.range_units) or 350, 10, 5000),
                                }
                            end
                        end

                        PD.VC.Config = vc
                        PD.Comlink.SendVoiceConfig()

                        SendChannelListToAll()

                        if callback then callback(#fixed, table.Count(vc)) end
                    end)
                end)
            end)
        end)
    end)
end

hook.Add("PlayerInitialSpawn", "PD.VC.Config", function(ply)
    timer.Simple(5, function()
        if IsValid(ply) then PD.Comlink.SendVoiceConfig(ply) end
    end)
end)

timer.Simple(3, function()
    PD.Comlink.LoadConfig(function(channels, ranges)
        print("[Funk] " .. tostring(channels) .. " feste Kanaele, " .. tostring(ranges) .. " Sprachreichweiten geladen")
    end)
end)

-- Jobs sind (neu) aus der Datenbank geladen: Einheitskanaele nachziehen.
hook.Add("PD.JOBS.Loaded", "PD.Comlink.UnitChannels", function()
    PD.Comlink.UnitDefaultChannel()
    SendChannelListToAll()
end)

net.Receive("PD.Comlink.RequestComlinkChannel", function(len, ply)
    if not IsValid(ply) then return end

    ply.PD_ComlinkKnown = true
    PD.Comlink.SendChannelList(ply)
end)
