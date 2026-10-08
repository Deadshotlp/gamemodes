--[[
    Naval - Netzwerk (Client).

    Haelt den Zustand, den die Darstellung braucht:
      Naval.C.static   Klassen, Fraktionen, Systeme, Routen
      Naval.C.system   Himmelskoerper des aktuellen Systems
      Naval.C.info     Schiffs-Infos (Name, Klasse, Fraktion) je id
      Snapshots im Puffer; Naval.C.View(t) liefert interpolierte Lage

    Interpolation 150 ms hinter dem Server (glatt trotz 10 Hz); fehlt ein
    Snapshot, wird die Drehung des eigenen Schiffs mit der Drehrate
    fortgeschrieben.
]]

-- cl_ laedt vor sh_ dieses Ordners, _core aber vorher - trotzdem absichern.
PD.Naval = PD.Naval or {}

local Naval = PD.Naval
local V3, Q = Naval.V3, Naval.Q

Naval.C = Naval.C or {static = nil, system = nil, info = {}, snaps = {}, events = {}}
local C = Naval.C

-- Zwei Snapshot-Abstaende Puffer: ein verlorenes Paket faellt nicht auf
local INTERP_DELAY = 0.2
local MAX_SNAPS = 30

local StateName = {"normal", "spooling", "jumping", "hyperspace", "exiting", "disabled", "destroyed"}

--------------------------------------------------------------------------------
-- Gestueckelte Daten
--------------------------------------------------------------------------------

local pending = {}

local function OnData(kind, payload)
    if kind == "static" then
        -- Systeme kompakt -> Tabellen
        local systems, byId = {}, {}
        for _, row in ipairs(payload.systems or {}) do
            local s = {id = row[1], name = row[2], g = {x = row[3], y = row[4], z = row[5]}, region = row[6], routes = row[7], planets = row[8] or ""}
            s.search = string.lower(s.name .. " " .. s.planets)
            systems[#systems + 1] = s
            byId[s.id] = s
        end

        payload.systemList = systems
        payload.systemsById = byId
        C.static = payload
        hook.Run("PD.Naval.StaticReceived")
    elseif kind == "system" then
        local byId = {}
        for _, b in ipairs(payload.bodies or {}) do byId[b.id] = b end
        payload.bodiesById = byId
        C.system = payload
        hook.Run("PD.Naval.SystemReceived")
    elseif kind == "shipinfo" then
        local info = {}
        for _, row in ipairs(payload or {}) do
            info[row[1]] = {id = row[1], name = row[2], classId = row[3], factionId = row[4], mapShip = row[5] == true,
                ident = row[5] == true and 2 or (tonumber(row[6]) or 2)}
        end
        C.info = info
        hook.Run("PD.Naval.ShipInfoReceived")
    end
end

net.Receive("PD.Naval.Data", function()
    local kind = net.ReadString()
    local id = net.ReadUInt(16)
    local index = net.ReadUInt(8)
    local total = net.ReadUInt(8)
    local size = net.ReadUInt(16)
    local part = net.ReadData(size)

    local p = pending[kind]
    if not p or p.id ~= id then
        p = {id = id, total = total, parts = {}, count = 0}
        pending[kind] = p
    end

    if not p.parts[index] then
        p.parts[index] = part
        p.count = p.count + 1
    end

    if p.count < p.total then return end
    pending[kind] = nil

    local json = util.Decompress(table.concat(p.parts, "", 1, p.total))
    local payload = json and util.JSONToTable(json)

    if payload then
        OnData(kind, payload)
    else
        print("[Naval] Daten '" .. kind .. "' nicht lesbar")
    end
end)

--------------------------------------------------------------------------------
-- Snapshots
--------------------------------------------------------------------------------

local function ReadQuat()
    return {w = net.ReadFloat(), x = net.ReadFloat(), y = net.ReadFloat(), z = net.ReadFloat()}
end

-- Kompakte Drehung ("smallest three", sv_naval_net.lua)
local QMAX = 0.7072
local function ReadQuatSmall()
    local mi = net.ReadUInt(2) + 1
    local c, sum = {}, 0
    for i = 1, 4 do
        if i ~= mi then
            local v = net.ReadInt(16) / 32767 * QMAX
            c[i] = v
            sum = sum + v * v
        end
    end
    c[mi] = math.sqrt(math.max(0, 1 - sum))
    return {w = c[1], x = c[2], y = c[3], z = c[4]}
end

net.Receive("PD.Naval.Snap", function()
    local serverNow = net.ReadDouble()

    -- Uhr angleichen (geglaettet)
    local offset = serverNow - (Naval.TimeBase + (SysTime() - Naval.SysBase))
    if not C.clockSynced or math.abs(offset - Naval.ClockOffset) > 2 then
        Naval.ClockOffset = offset
        C.clockSynced = true
    else
        Naval.ClockOffset = Naval.ClockOffset + (offset - Naval.ClockOffset) * 0.05
    end

    local snap = {t = serverNow, ships = {}}
    snap.id = net.ReadUInt(16)
    snap.systemId = net.ReadString()
    snap.state = StateName[net.ReadUInt(4)] or "normal"
    snap.pos = {x = net.ReadDouble(), y = net.ReadDouble(), z = net.ReadDouble()}
    snap.rot = ReadQuat()
    snap.vel = {x = net.ReadFloat(), y = net.ReadFloat(), z = net.ReadFloat()}
    snap.angVel = {x = net.ReadFloat(), y = net.ReadFloat(), z = net.ReadFloat()}
    snap.throttle = net.ReadFloat()
    snap.hull = net.ReadUInt(7)

    local count = net.ReadUInt(12)
    for _ = 1, count do
        local id = net.ReadUInt(16)
        snap.ships[id] = {
            rel = {x = net.ReadFloat(), y = net.ReadFloat(), z = net.ReadFloat()},
            rot = ReadQuatSmall(),
            state = StateName[net.ReadUInt(4)] or "normal",
            hull = net.ReadUInt(7),
        }
    end

    -- Ferne Schiffe ohne neue Daten: letzte Lage uebernehmen (relativ zur
    -- neuen Position des Map-Schiffs umgerechnet)
    local prev = C.snaps[#C.snaps]
    local keepCount = net.ReadUInt(12)
    for _ = 1, keepCount do
        local id = net.ReadUInt(16)
        local old = prev and prev.systemId == snap.systemId and prev.ships[id]
        if old then
            local abs = {x = prev.pos.x + old.rel.x, y = prev.pos.y + old.rel.y, z = prev.pos.z + old.rel.z}
            snap.ships[id] = {rel = {x = abs.x - snap.pos.x, y = abs.y - snap.pos.y, z = abs.z - snap.pos.z},
                rot = old.rot, state = old.state, hull = old.hull}
        end
    end

    -- Systemwechsel: alter Puffer gilt nicht mehr
    if C.snaps[#C.snaps] and C.snaps[#C.snaps].systemId ~= snap.systemId then
        C.snaps = {}
    end

    local last = C.snaps[#C.snaps]
    if last and snap.t <= last.t then
        C.snaps[#C.snaps] = snap
    else
        table.insert(C.snaps, snap)
    end
    while #C.snaps > MAX_SNAPS do table.remove(C.snaps, 1) end

    C.last = snap
end)

-- Interpolierte Lage zum Zeitpunkt t (Standard: jetzt - Verzoegerung).
-- Liefert {pos, rot, vel, state, systemId, ships = {id -> {pos, rot, state}}}
-- Ohne Zeitangabe einmal pro Bild berechnen: Renderpass, Hologramm und
-- jede 3D-Konsole fragen die Lage mehrfach pro Bild ab (Ergebnis nicht aendern!)
local viewFrame, viewCache = -1, nil
local BuildView

function C.View(t)
    if t ~= nil then return BuildView(t) end
    local frame = FrameNumber()
    if frame ~= viewFrame then
        viewFrame = frame
        viewCache = BuildView()
    end
    return viewCache
end

BuildView = function(t)
    local snaps = C.snaps
    if #snaps == 0 then return nil end

    t = t or (Naval.Now() - INTERP_DELAY)

    local a, b, prev = snaps[1], nil, nil
    for i = 1, #snaps do
        if snaps[i].t <= t then
            a = snaps[i]
            b = snaps[i + 1]
            prev = snaps[i - 1]
        end
    end

    local view = {systemId = a.systemId, state = a.state, throttle = a.throttle, vel = a.vel, id = a.id, hull = a.hull, ships = {}}

    if b and b.systemId == a.systemId and b.t > a.t then
        local f = math.Clamp((t - a.t) / (b.t - a.t), 0, 1)
        view.pos = V3.Lerp(a.pos, b.pos, f)
        view.rot = Q.Slerp(a.rot, b.rot, f)

        for id, sa in pairs(a.ships) do
            local sb = b.ships[id]
            local relA = V3.Add(a.pos, sa.rel)

            if sb then
                view.ships[id] = {pos = V3.Lerp(relA, V3.Add(b.pos, sb.rel), f), rot = Q.Slerp(sa.rot, sb.rot, f), state = sb.state, hull = sb.hull}
            else
                view.ships[id] = {pos = relA, rot = sa.rot, state = sa.state, hull = sa.hull}
            end
        end
    else
        -- Kein neuerer Snapshot: fortschreiben
        local dt = math.Clamp(t - a.t, 0, 1)
        view.pos = V3.Add(a.pos, V3.Scale(a.vel, dt))
        view.rot = Q.Integrate(a.rot, a.angVel, dt)

        -- Andere Schiffe mit ihrer letzten Geschwindigkeit fortschreiben
        local span = prev and prev.systemId == a.systemId and (a.t - prev.t) or 0

        for id, sa in pairs(a.ships) do
            local pos = V3.Add(a.pos, sa.rel)
            local sp = span > 0 and prev.ships[id]

            if sp then
                local old = V3.Add(prev.pos, sp.rel)
                pos = V3.Add(pos, V3.Scale(V3.Sub(pos, old), dt / span))
            end

            view.ships[id] = {pos = pos, rot = sa.rot, state = sa.state, hull = sa.hull}
        end
    end

    return view
end

--------------------------------------------------------------------------------
-- Ereignisse
--------------------------------------------------------------------------------

net.Receive("PD.Naval.Event", function()
    local kind = net.ReadString()
    local data = util.JSONToTable(net.ReadString()) or {}
    local hyperJson = net.ReadString()
    local t = net.ReadDouble()

    -- Nur Sprung-Ereignisse tragen den Hyperraum-Zustand
    local hyper = C.hyper or {}
    if hyperJson ~= "" then
        hyper = util.JSONToTable(hyperJson) or {}
        C.hyper = hyper
    end
    C.lastEvent = {kind = kind, data = data, t = t}

    hook.Run("PD.Naval.ClientEvent", kind, data, hyper, t)
end)
