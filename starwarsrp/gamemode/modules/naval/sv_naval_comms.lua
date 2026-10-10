--[[
    Naval - Kommunikation (Server, Stufe 3).

    Konsole Kommunikation (Station comms) auf dem Map-Schiff:
      hail {id}        Kontakt rufen (Neutrale/Verbuendete identifizieren sich)
      demand {id}      Kapitulation fordern (KI nimmt an, wenn die Moral niedrig ist)
      accept {id}      Kapitulation eines Schiffs annehmen (gefangen genommen)
      offer {}         eigene Kapitulation anbieten (Feinde stellen das Feuer
                       ein, solange das Map-Schiff nicht schiesst)
      distress {}      Notruf: verbuendete KI-Schiffe in Reichweite springen her
      say {id, text}   freie Nachricht (id 0 = an alle)

    Antworten: automatisch durch die KI (comms_auto_reply) oder, wenn ein
    Admin im Flottenkommando "Funk selbst beantworten" an hat, durch die
    Spielleitung (Admin-Aktion comms_reply).

    Funkprotokoll im Speicher (letzte 60 Eintraege), an die Konsolen ueber den
    Status, an alle Spieler auf der Map als Bordmeldung (Ereignis comms).
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3 = Naval.V3
local S = Naval.State

Naval.CommsLog = Naval.CommsLog or {}

local function Setting(key, default)
    return tonumber(Naval.Settings and Naval.Settings[key]) or default
end

local function Name(ship, viewer)
    if not ship then return "?" end
    if viewer and Naval.IdentLevel and Naval.IdentLevel(viewer, ship) < 1 then return "Unbekanntes Schiff" end
    return ship.name
end

-- Eintrag ins Funkprotokoll; from = Schiff oder Text
function Naval.CommsMessage(from, text, kind, to)
    local mapShip = Naval.GetMapShip()
    local fromName = istable(from) and Name(from, mapShip) or tostring(from or "?")
    local toName = istable(to) and Name(to, mapShip) or to

    local entry = {t = os.time(), from = fromName, to = toName, text = string.sub(tostring(text or ""), 1, 300), kind = kind or "msg",
        own = istable(from) and from == mapShip or nil}
    table.insert(Naval.CommsLog, entry)
    while #Naval.CommsLog > 60 do table.remove(Naval.CommsLog, 1) end

    if mapShip then
        Naval.Event(mapShip, "comms", {from = entry.from, to = entry.to, text = entry.text, own = entry.own})
        if kind ~= "msg" or not entry.own then mapShip:Log("comms", entry.from, entry.text) end
    end
    return entry
end

local function NotifyAdmins(text)
    for _, ply in ipairs(player.GetHumans()) do
        if ply:IsAdmin() then PD.Notify("[Funk] " .. text, Color(120, 200, 255), false, ply) end
    end
end

-- Antwortet die Spielleitung selbst?
local function Live()
    return Naval.CommsLive == true or (tonumber(Naval.Settings.comms_auto_reply) or 1) == 0
end

local function Later(fn)
    timer.Simple(math.Rand(2, 4), function()
        if Naval.SimRunning then fn() end
    end)
end

local function Relation(a, b)
    return Naval.GetRelation(a.factionId, b.factionId)
end

local function Morale(ship)
    return ship.subs and ship.subs.morale or 75
end

local function HullPct(ship)
    return math.Round((ship.hull or 0) / math.max((ship:Class() or {}).hull or 1, 1) * 100)
end

local HOSTILE_HAIL = {
    "Keine Antwort.",
    "Wir haben Ihnen nichts zu sagen.",
    "Ergeben Sie sich, oder Sie werden vernichtet.",
    "Ihre Republik wird fallen.",
}

--------------------------------------------------------------------------------
-- Aktionen
--------------------------------------------------------------------------------

local function Contact(ship, id)
    local other = Naval.Ships[tonumber(id) or -1]
    if not other or other == ship or other.systemId ~= ship.systemId or other.state == S.HYPERSPACE then return nil end
    if V3.Dist(other.pos, ship.pos) > ship:Stat("sensorRange") then return nil end
    return other
end

local C = {}

C.hail = function(ply, ship, args)
    local other = Contact(ship, args.id)
    if not other then return end

    Naval.CommsMessage(ship, "Hier " .. ship.name .. ". Wir rufen " .. Name(other, ship) .. ", bitte melden.", "msg", other)
    if Live() then NotifyAdmins(ship.name .. " ruft " .. other.name .. " (Antwort im Flottenkommando)") return end

    Later(function()
        if not Naval.Ships[other.id] then return end
        local rel = Relation(other, ship)

        if other.flags and other.flags.surrendered then
            Naval.CommsMessage(other, "Wir haben kapituliert. Bitte stellen Sie das Feuer ein.", "reply")
        elseif rel == Naval.Relation.HOSTILE then
            Naval.CommsMessage(other, HOSTILE_HAIL[math.random(#HOSTILE_HAIL)], "reply")
        else
            -- Neutrale und Verbuendete identifizieren sich
            if Naval.SetIdentLevel and Naval.IdentLevel(ship, other) < 1 then Naval.SetIdentLevel(ship, other.id, 1) end
            local class = (other:Class() or {}).name or other.classId
            if rel == Naval.Relation.ALLY then
                Naval.CommsMessage(other, ("Hier %s, %s. Wir hören Sie, %s. Hülle bei %d %%, warten auf Befehle.")
                    :format(other.name, class, ship.name, HullPct(other)), "reply")
            else
                Naval.CommsMessage(other, ("Hier %s, %s. Wir sind in friedlicher Absicht unterwegs."):format(other.name, class), "reply")
            end
        end
    end)
end

C.demand = function(ply, ship, args)
    local other = Contact(ship, args.id)
    if not other then return end

    Naval.CommsMessage(ship, Name(other, ship) .. ", hier spricht " .. ship.name .. ". Kapitulieren Sie und senken Sie Ihre Schilde.", "msg", other)
    ship:Log("comms", ply:Nick(), "Kapitulation gefordert von " .. other.name)
    if Live() then NotifyAdmins(ship.name .. " fordert die Kapitulation von " .. other.name) return end

    Later(function()
        if not Naval.Ships[other.id] or (other.flags and other.flags.surrendered) then return end
        if Relation(other, ship) ~= Naval.Relation.HOSTILE then
            Naval.CommsMessage(other, "Wir sind nicht Ihre Feinde.", "reply")
        elseif Morale(other) < Setting("morale_flee", 30) + 5 or other.state == S.DISABLED then
            Naval.Surrender(other, ship.name)
        else
            Naval.CommsMessage(other, math.random() < 0.5 and "Niemals!" or "Kommen Sie und holen Sie uns.", "reply")
        end
    end)
end

C.accept = function(ply, ship, args)
    local other = Contact(ship, args.id)
    if not other or not (other.flags and other.flags.surrendered) then return end

    other.flags.prisoner = true
    other.dirty = true
    Naval.CommsMessage(ship, Name(other, ship) .. ", Ihre Kapitulation ist angenommen. Halten Sie Position und erwarten Sie unsere Leute.", "msg", other)
    ship:Log("comms", ply:Nick(), "Kapitulation von " .. other.name .. " angenommen")
    if not Live() then
        Later(function() Naval.CommsMessage(other, "Verstanden. Wir leisten keinen Widerstand.", "reply") end)
    end
end

C.offer = function(ply, ship)
    Naval.CommsMessage(ship, "Hier " .. ship.name .. ". Wir bieten unsere Kapitulation an. Stellen Sie das Feuer ein.", "msg")
    ship:Log("comms", ply:Nick(), "Kapitulation angeboten")
    NotifyAdmins(ship.name .. " bietet die Kapitulation an")
    if PD.LOGS and PD.LOGS.Add then PD.LOGS.Add("Naval", ply:Nick() .. ": Kapitulation angeboten", Color(255, 200, 80)) end
    if Live() then return end

    Later(function()
        local accepted = false
        for _, other in pairs(Naval.Ships) do
            if other.systemId == ship.systemId and other ~= ship and Relation(other, ship) == Naval.Relation.HOSTILE
                and other.state == S.NORMAL and not (other.flags and other.flags.surrendered) and Naval.Combat then
                local subs = Naval.Combat(other)
                subs.roe = "hold"
                subs.target = nil
                subs.ceasefire = true
                Naval.SetOrders(other, {{type = "hold"}}, "Waffenruhe")
                accepted = true
            end
        end

        if accepted then
            Naval.CommsMessage("Feindliche Schiffe", "Kapitulation angenommen. Schalten Sie Ihre Waffen ab und halten Sie Position.", "reply")
        else
            Naval.CommsMessage("Funk", "Keine Antwort.", "reply")
        end
    end)
end

C.distress = function(ply, ship)
    local now = CurTime()
    if (Naval.DistressReady or 0) > now then
        Naval.Feedback(ply, ("Notruf erst wieder in %d s"):format(Naval.DistressReady - now))
        return
    end
    Naval.DistressReady = now + Setting("comms_distress_cooldown", 300)

    local here = Naval.Systems[ship.systemId]
    Naval.CommsMessage(ship, "Notruf! Hier " .. ship.name .. " im System " .. (here and here.name or "?") .. ". Wir benötigen sofort Unterstützung!", "distress")
    ship:Log("comms", ply:Nick(), "Notruf gesendet")
    NotifyAdmins("Notruf von " .. ship.name .. " aus " .. (here and here.name or "?"))
    if PD.LOGS and PD.LOGS.Add then PD.LOGS.Add("Naval", ply:Nick() .. ": Notruf aus " .. (here and here.name or "?"), Color(255, 120, 80)) end

    -- Verbuendete KI-Schiffe in Reichweite (naechste zuerst)
    local range = Setting("comms_distress_range", 3000)
    local candidates = {}
    for _, other in pairs(Naval.Ships) do
        local sys = Naval.Systems[other.systemId]
        if other ~= ship and not other:IsPlayerShip() and other.state == S.NORMAL and sys and here
            and Relation(other, ship) == Naval.Relation.ALLY and not (other.flags and (other.flags.surrendered or other.flags.noDistress))
            and other.systemId ~= ship.systemId and (other.fleetId or 0) == 0 then
            local d = Naval.SystemDistance(here, sys)
            if d <= range then candidates[#candidates + 1] = {ship = other, d = d} end
        end
    end
    table.sort(candidates, function(a, b) return a.d < b.d end)

    local count = math.min(#candidates, math.floor(Setting("comms_distress_ships", 3)))
    for i = 1, count do
        local other = candidates[i].ship
        Naval.SetOrders(other, {{type = "jump", systemId = ship.systemId, arriveNear = ship.id}}, "Notruf")
        timer.Simple(3 + i, function()
            if Naval.Ships[other.id] then Naval.CommsMessage(other, "Notruf empfangen. " .. other.name .. " ist unterwegs.", "reply") end
        end)
    end

    if count == 0 then
        timer.Simple(5, function() Naval.CommsMessage("Funk", "Keine Antwort auf den Notruf.", "reply") end)
    end
end

C.say = function(ply, ship, args)
    local text = string.Trim(string.sub(tostring(args.text or ""), 1, 300))
    if text == "" then return end
    local other = tonumber(args.id) and tonumber(args.id) > 0 and Contact(ship, args.id) or nil
    Naval.CommsMessage(ship, text, "msg", other or "alle")
    NotifyAdmins(ship.name .. (other and (" an " .. other.name) or " an alle") .. ": " .. text)
end

Naval.CombatCommands = Naval.CombatCommands or {}
Naval.CombatCommands.comms = C

--------------------------------------------------------------------------------
-- Status
--------------------------------------------------------------------------------

Naval.StatusExtras = Naval.StatusExtras or {}
Naval.StatusExtras.comms = function()
    local log = {}
    for i = math.max(1, #Naval.CommsLog - 14), #Naval.CommsLog do log[#log + 1] = Naval.CommsLog[i] end
    return {log = log, distressIn = math.max(0, math.Round((Naval.DistressReady or 0) - CurTime()))}
end
