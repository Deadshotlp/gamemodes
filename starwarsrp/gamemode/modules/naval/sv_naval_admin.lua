--[[
    Naval - Admin-Befehle (Server).

    Fuer Admins im Spiel (Konsole) und die Serverkonsole/das Web-Panel. Das
    grafische Admin-Werkzeug nutzt dieselben Funktionen.

      pd_naval_spawn <klasse> [fraktion] [abstand_km] [name...]
            Schiff vor dem Map-Schiff erzeugen
      pd_naval_list                       Schiffe im aktuellen System
      pd_naval_delete <id>
      pd_naval_order <id> hold
      pd_naval_order <id> move <x_km> <y_km> <z_km>    relativ zum Map-Schiff
      pd_naval_order <id> orbit <koerpername> [radius_km]
      pd_naval_order <id> approach <koerpername>
      pd_naval_order <id> jump <systemname>
      pd_naval_helm <schub -0.25..1> [nicken gieren rollen -1..1]
            Map-Schiff direkt steuern (bis die Steuerkonsole fertig ist)
      pd_naval_jump <systemname>          Map-Schiff ausrichten und springen
      pd_naval_abort                      Sprung waehrend des Hochfahrens abbrechen
      pd_naval_pause                      Simulation an/aus
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3, Q = Naval.V3, Naval.Q

local function Allowed(ply)
    return not IsValid(ply) or ply:IsAdmin()
end

local function Reply(ply, text)
    if IsValid(ply) then
        ply:PrintMessage(HUD_PRINTCONSOLE, "[Naval] " .. text)
        ply:ChatPrint("[Naval] " .. text)
    else
        PD.RemoteLog("[Naval] " .. text)
    end
end

local function Log(ply, text)
    local who = IsValid(ply) and (ply:Nick() .. " (" .. ply:SteamID64() .. ")") or "Konsole"
    if PD.LOGS and PD.LOGS.Add then PD.LOGS.Add("Naval", who .. ": " .. text, Color(120, 170, 255)) end
end

function Naval.FindSystem(name)
    name = string.lower(string.Trim(name or ""))
    if name == "" then return nil end

    for id, s in pairs(Naval.Systems) do
        if id == name or string.lower(s.name) == name then return s end
    end

    -- Planet/Mond/Stern dieses Namens -> sein System ("Tatooine" -> Tatoo)
    for _, b in pairs(Naval.Bodies) do
        if string.lower(b.name) == name and Naval.Systems[b.systemId] then return Naval.Systems[b.systemId] end
    end

    for _, s in pairs(Naval.Systems) do
        if string.find(string.lower(s.name), name, 1, true) then return s end
    end
end

function Naval.FindBody(systemId, name)
    name = string.lower(string.Trim(name or ""))

    for _, b in ipairs(Naval.BodiesBySystem[systemId] or {}) do
        if string.lower(b.name) == name or b.id == name then return b end
    end

    for _, b in ipairs(Naval.BodiesBySystem[systemId] or {}) do
        if string.find(string.lower(b.name), name, 1, true) then return b end
    end
end

local function NeedSim(ply)
    if not Naval.SimRunning then
        Reply(ply, "Simulation laeuft nicht (pd_naval_active 1 und Naval-Map noetig)")
        return false
    end
    return true
end

concommand.Add("pd_naval_spawn", function(ply, _, args)
    if not Allowed(ply) or not NeedSim(ply) then return end

    local classId = args[1]
    local class = Naval.Classes[classId or ""]
    if not class then
        local list = {}
        for id in SortedPairs(Naval.Classes) do list[#list + 1] = id end
        Reply(ply, "Klasse fehlt/unbekannt. Moeglich: " .. table.concat(list, ", "))
        return
    end

    local mapShip = Naval.GetMapShip()
    if not mapShip then Reply(ply, "Kein Map-Schiff") return end

    local factionId = args[2] and Naval.Factions[args[2]] and args[2] or class.faction
    local distance = (tonumber(args[3]) or 5) * 1000
    local name = table.concat(args, " ", 4)

    -- Vor dem Map-Schiff, leicht seitlich versetzt, Bug zum Map-Schiff
    local fwd = Q.Forward(mapShip.rot)
    local left = Q.Left(mapShip.rot)
    local side = (math.random() - 0.5) * distance * 0.6
    local pos = V3.Add(mapShip.pos, V3.Add(V3.Scale(fwd, distance), V3.Scale(left, side)))
    local toMap = V3.Sub(mapShip.pos, pos)
    local yaw = math.deg(math.atan2(toMap.y, toMap.x))

    local ship = Naval.CreateShip({
        classId = class.id,
        factionId = factionId,
        name = name ~= "" and name or nil,
        systemId = mapShip.systemId,
        pos = pos,
        rot = Q.FromAngle(0, yaw, 0),
    })

    Naval.SaveShip(ship)
    Reply(ply, ("#%d %s (%s, %s) erzeugt, %.1f km voraus"):format(ship.id, ship.name, class.id, factionId, distance / 1000))
    Log(ply, "Schiff #" .. ship.id .. " " .. ship.name .. " erzeugt")
end)

concommand.Add("pd_naval_list", function(ply)
    if not Allowed(ply) or not NeedSim(ply) then return end

    local mapShip = Naval.GetMapShip()

    for id, ship in SortedPairs(Naval.Ships) do
        if not mapShip or ship.systemId == mapShip.systemId or ship == mapShip then
            local dist = mapShip and V3.Dist(ship.pos, mapShip.pos) / 1000 or 0
            local order = ship.orders.queue[1]
            Reply(ply, ("#%d %s [%s/%s] %s %.1f km, %.0f m/s, Befehl: %s"):format(id, ship.name, ship.classId, ship.factionId,
                ship.state, dist, ship:Speed(), order and order.type or "-"))
        end
    end
end)

concommand.Add("pd_naval_delete", function(ply, _, args)
    if not Allowed(ply) or not NeedSim(ply) then return end

    local id = tonumber(args[1])
    local ship = id and Naval.Ships[id]
    if not ship then Reply(ply, "Schiff nicht gefunden") return end
    if ship:IsPlayerShip() then Reply(ply, "Das Map-Schiff kann nicht geloescht werden") return end

    Naval.RemoveShip(id)
    Reply(ply, "#" .. id .. " geloescht")
    Log(ply, "Schiff #" .. id .. " " .. ship.name .. " geloescht")
end)

concommand.Add("pd_naval_order", function(ply, _, args)
    if not Allowed(ply) or not NeedSim(ply) then return end

    local ship = Naval.Ships[tonumber(args[1]) or -1]
    if not ship then Reply(ply, "Schiff nicht gefunden") return end
    if ship:IsPlayerShip() then Reply(ply, "Das Map-Schiff steuern die Konsolen") return end

    local kind = args[2]
    local who = IsValid(ply) and ply:Nick() or "Konsole"
    local order

    if kind == "hold" then
        order = {type = "hold"}
    elseif kind == "move" then
        local mapShip = Naval.GetMapShip()
        local offset = {x = (tonumber(args[3]) or 0) * 1000, y = (tonumber(args[4]) or 0) * 1000, z = (tonumber(args[5]) or 0) * 1000}
        order = {type = "move", pos = V3.Add(mapShip and mapShip.pos or ship.pos, offset)}
    elseif kind == "orbit" or kind == "approach" then
        local body = Naval.FindBody(ship.systemId, args[3])
        if not body then Reply(ply, "Koerper nicht gefunden") return end

        if kind == "orbit" then
            order = {type = "orbit", bodyId = body.id, radius = tonumber(args[4]) and tonumber(args[4]) * 1000 or nil}
        else
            order = {type = "move", bodyId = body.id}
        end
    elseif kind == "jump" then
        local system = Naval.FindSystem(table.concat(args, " ", 3))
        if not system then Reply(ply, "System nicht gefunden") return end
        order = {type = "jump", systemId = system.id}
    elseif kind == "attack" then
        local target = Naval.Ships[tonumber(args[3]) or -1]
        if not target or target.systemId ~= ship.systemId then Reply(ply, "Ziel nicht im selben System") return end
        order = {type = "attack", targetId = target.id}
    elseif kind == "jumpnear" then
        -- Zum Map-Schiff springen und dort ankommen
        local mapShip = Naval.GetMapShip()
        if not mapShip then Reply(ply, "Kein Map-Schiff") return end
        order = {type = "jump", systemId = mapShip.systemId, arriveNear = mapShip.id}
    else
        Reply(ply, "Befehl: hold | move x y z (km) | orbit <koerper> [km] | approach <koerper> | jump <system> | jumpnear | attack <ziel-id>")
        return
    end

    Naval.SetOrders(ship, {order}, who)
    Reply(ply, "#" .. ship.id .. " " .. ship.name .. ": " .. kind)
    Log(ply, "Befehl an #" .. ship.id .. " " .. ship.name .. ": " .. kind)
end)

-- pd_naval_edit <id> name <text...> | faction <fraktion>
concommand.Add("pd_naval_edit", function(ply, _, args)
    if not Allowed(ply) or not NeedSim(ply) then return end

    local ship = Naval.Ships[tonumber(args[1]) or -1]
    if not ship then Reply(ply, "Schiff nicht gefunden") return end

    if args[2] == "name" then
        local name = string.sub(string.Trim(table.concat(args, " ", 3)), 1, 64)
        if name == "" then return end
        ship.name = name
    elseif args[2] == "faction" and Naval.Factions[args[3] or ""] and not ship:IsPlayerShip() then
        ship.factionId = args[3]
    else
        Reply(ply, "pd_naval_edit <id> name <text> | faction <fraktion>")
        return
    end

    ship.dirty = true
    Naval.SaveShip(ship)
    Reply(ply, "#" .. ship.id .. " -> " .. ship.name .. " / " .. ship.factionId)
    Log(ply, "Schiff #" .. ship.id .. " bearbeitet: " .. ship.name .. " / " .. ship.factionId)
end)

-- pd_naval_roe <id> hold|return|free
concommand.Add("pd_naval_roe", function(ply, _, args)
    if not Allowed(ply) or not NeedSim(ply) or not Naval.Combat then return end

    local ship = Naval.Ships[tonumber(args[1]) or -1]
    local roe = args[2]
    if not ship or ship:IsPlayerShip() or (roe ~= "hold" and roe ~= "return" and roe ~= "free") then
        Reply(ply, "pd_naval_roe <id> hold|return|free")
        return
    end

    Naval.Combat(ship).roe = roe
    ship.dirty = true
    Reply(ply, "#" .. ship.id .. " Feuerverhalten " .. roe)
    Log(ply, "Feuerverhalten #" .. ship.id .. ": " .. roe)
end)

-- pd_naval_repair <id>   (auch das Map-Schiff)
concommand.Add("pd_naval_repair", function(ply, _, args)
    if not Allowed(ply) or not NeedSim(ply) or not Naval.Repair then return end

    local ship = Naval.Ships[tonumber(args[1]) or -1]
    if not ship then Reply(ply, "Schiff nicht gefunden") return end

    Naval.Repair(ship)
    Reply(ply, "#" .. ship.id .. " repariert")
    Log(ply, "Schiff #" .. ship.id .. " " .. ship.name .. " repariert")
end)

-- Alles sofort speichern (Web-Panel liest danach die Datenbank)
concommand.Add("pd_naval_save", function(ply)
    if not Allowed(ply) or not Naval.SimRunning then return end
    Reply(ply, Naval.SaveDirty(true) .. " Schiffe gespeichert")
end)

concommand.Add("pd_naval_helm", function(ply, _, args)
    if not Allowed(ply) or not NeedSim(ply) then return end

    local ship = Naval.GetMapShip()
    if not ship then return end

    ship.ctrl.throttle = math.Clamp(tonumber(args[1]) or 0, -0.25, 1)
    ship.ctrl.rate = {
        p = math.Clamp(tonumber(args[2]) or 0, -1, 1),
        y = math.Clamp(tonumber(args[3]) or 0, -1, 1),
        r = math.Clamp(tonumber(args[4]) or 0, -1, 1),
    }
    ship.ctrl.autopilot = nil

    Reply(ply, ("Schub %.2f, Drehung %.1f/%.1f/%.1f"):format(ship.ctrl.throttle, ship.ctrl.rate.p, ship.ctrl.rate.y, ship.ctrl.rate.r))
end)

-- Map-Schiff: ausrichten, dann springen (Testweg bis zu den Konsolen)
concommand.Add("pd_naval_jump", function(ply, _, args)
    if not Allowed(ply) or not NeedSim(ply) then return end

    local ship = Naval.GetMapShip()
    local system = Naval.FindSystem(table.concat(args, " "))
    if not ship or not system then Reply(ply, "System nicht gefunden") return end

    local from = Naval.Systems[ship.systemId]
    ship.ctrl.autopilot = {dir = Naval.JumpVector(from, system)}
    ship.ctrl.throttle = 0.2
    Naval.PendingMapJump = {systemId = system.id, by = IsValid(ply) and ply:Nick() or "Konsole", ply = ply, until_ = CurTime() + 180}

    Reply(ply, "Richte auf " .. system.name .. " aus (" .. math.Round(Naval.SystemDistance(from, system)) .. " pc)...")
    Log(ply, "Sprung des Map-Schiffs nach " .. system.name .. " angeordnet")
end)

concommand.Add("pd_naval_abort", function(ply)
    if not Allowed(ply) or not NeedSim(ply) then return end

    local ship = Naval.GetMapShip()
    Naval.PendingMapJump = nil

    local ok, reason = Naval.AbortJump(ship, IsValid(ply) and ply:Nick() or "Konsole")
    Reply(ply, ok and "Sprung abgebrochen" or reason)
end)

concommand.Add("pd_naval_pause", function(ply)
    if not Allowed(ply) then return end

    Naval.Paused = not Naval.Paused
    Reply(ply, "Simulation " .. (Naval.Paused and "pausiert" or "laeuft"))
    Log(ply, "Simulation " .. (Naval.Paused and "pausiert" or "fortgesetzt"))
end)

-- Ausstehenden Sprung des Map-Schiffs ausloesen, sobald ausgerichtet
timer.Create("PD.Naval.PendingJump", 0.5, 0, function()
    local pending = Naval.PendingMapJump
    if not pending then return end

    local ship = Naval.GetMapShip()
    if not ship or CurTime() > pending.until_ then
        Naval.PendingMapJump = nil
        return
    end

    -- Aus dem Massenschatten heraus fliegen
    local body = Naval.MassShadow(ship)
    if body then
        ship.ctrl.throttle = 1
        return
    end

    ship.ctrl.throttle = 0.2

    if Naval.AlignmentError(ship, pending.systemId) <= (Naval.Settings.jump_align_tolerance or 2) * 0.8 then
        local ok, result = Naval.StartJump(ship, pending.systemId, pending.by)
        Naval.PendingMapJump = nil
        Reply(pending.ply, ok and ("Sprung eingeleitet, Dauer " .. math.Round(result) .. " s") or ("Sprung nicht moeglich: " .. tostring(result)))
    end
end)
