--[[
    Naval - Hyperraum-Routenplanung (Server).

    Sprungwege folgen den Hyperraumrouten: das Schiff springt zum guenstigsten
    Einstiegspunkt einer Route, folgt ihr (auch ueber Kreuzungen auf andere
    Routen) und verlaesst sie am guenstigsten Punkt Richtung Ziel. Abseits der
    Routen kostet jede Parsec voll, auf Routen nur route_speed_factor
    (Hauptrouten) bzw. route_minor_factor. Lohnt sich keine Route, wird
    direkt gesprungen.

    Graph: Stuetzpunkte der Routenlinien (galaxy x/y, Parsec), Kanten entlang
    der Linien, Umstiege zwischen Routen bis route_junction_dist Parsec.
    Wird neu gebaut, sobald Naval.Routes ersetzt wurde (Galaxie-Reload).

      Naval.PlanJump(from, to)  -> plan (gecacht)
        plan.points  {{x, y, z, f}}  f = Anteil der Reisezeit bis hier
        plan.legs    {routeId|false}  je Abschnitt
        plan.cost    effektive Parsec (fuer die Sprungdauer)
        plan.length  echte Strecke (Parsec)
        plan.routes  Namen der benutzten Routen in Reihenfolge
        plan.direct  true = ohne Route
      pd_naval_route <von> ; <nach>   Plan in der Konsole ausgeben
]]

PD.Naval = PD.Naval or {}

local Naval = PD.Naval

local graph, graphFor
local cache = {}

local function Dist(ax, ay, bx, by)
    local dx, dy = ax - bx, ay - by
    return math.sqrt(dx * dx + dy * dy)
end

local function Factor(route)
    local s = Naval.Settings or {}
    if route and route.major then return s.route_speed_factor or 0.5 end
    return s.route_minor_factor or 0.7
end

--------------------------------------------------------------------------------
-- Graph
--------------------------------------------------------------------------------

local function BuildGraph()
    local nodes, byKey = {}, {}

    local function Node(x, y, routeId)
        local key = math.Round(x * 10) .. ":" .. math.Round(y * 10)
        local n = byKey[key]
        if not n then
            n = {i = #nodes + 1, x = x, y = y, edges = {}, routes = {}}
            nodes[n.i] = n
            byKey[key] = n
        end
        n.routes[routeId] = true
        return n
    end

    local function Link(a, b, cost, routeId)
        if a == b then return end
        a.edges[#a.edges + 1] = {to = b, cost = cost, route = routeId}
        b.edges[#b.edges + 1] = {to = a, cost = cost, route = routeId}
    end

    for id, route in pairs(Naval.Routes or {}) do
        local factor = Factor(route)

        for _, line in ipairs(route.lines or {}) do
            local prev
            for _, p in ipairs(line) do
                local n = Node(tonumber(p[1]) or 0, tonumber(p[2]) or 0, id)
                if prev then Link(prev, n, Dist(prev.x, prev.y, n.x, n.y) * factor, id) end
                prev = n
            end
        end
    end

    -- Umstiege: Punkte verschiedener Routen nahe beieinander
    local jd = (Naval.Settings and Naval.Settings.route_junction_dist) or 25
    local cells = {}
    local function Cell(cx, cy) return cx .. ":" .. cy end

    for _, n in ipairs(nodes) do
        local key = Cell(math.floor(n.x / jd), math.floor(n.y / jd))
        cells[key] = cells[key] or {}
        table.insert(cells[key], n)
    end

    local junctions = 0
    for _, n in ipairs(nodes) do
        local cx, cy = math.floor(n.x / jd), math.floor(n.y / jd)
        for dx = -1, 1 do
            for dy = -1, 1 do
                for _, m in ipairs(cells[Cell(cx + dx, cy + dy)] or {}) do
                    if m.i > n.i then
                        local shared = false
                        for r in pairs(n.routes) do
                            if m.routes[r] then shared = true break end
                        end

                        local d = Dist(n.x, n.y, m.x, m.y)
                        if not shared and d <= jd then
                            Link(n, m, d, false)
                            junctions = junctions + 1
                        end
                    end
                end
            end
        end
    end

    Naval.Log(("Routengraph: %d Punkte, %d Umstiege"):format(#nodes, junctions))
    return nodes
end

local function Graph()
    if graphFor ~= Naval.Routes then
        graph = BuildGraph()
        graphFor = Naval.Routes
        cache = {}
    end
    return graph
end

--------------------------------------------------------------------------------
-- Kuerzester Weg (Dijkstra mit Binaer-Heap)
--------------------------------------------------------------------------------

local function HeapPush(heap, n, d)
    heap[#heap + 1] = {n, d}
    local i = #heap
    while i > 1 do
        local p = math.floor(i / 2)
        if heap[p][2] <= heap[i][2] then break end
        heap[p], heap[i] = heap[i], heap[p]
        i = p
    end
end

local function HeapPop(heap)
    local top = heap[1]
    local last = table.remove(heap)
    if #heap > 0 then
        heap[1] = last
        local i, size = 1, #heap
        while true do
            local l, r, s = i * 2, i * 2 + 1, i
            if l <= size and heap[l][2] < heap[s][2] then s = l end
            if r <= size and heap[r][2] < heap[s][2] then s = r end
            if s == i then break end
            heap[s], heap[i] = heap[i], heap[s]
            i = s
        end
    end
    return top
end

local function Solve(from, to)
    local nodes = Graph()
    local sx, sy, ex, ey = from.g.x, from.g.y, to.g.x, to.g.y
    local direct = Dist(sx, sy, ex, ey)

    local dist, prev, prevEdge, done = {}, {}, {}, {}
    local heap = {}

    -- Einstieg: von der Startposition zu jedem Routenpunkt (abseits = voll)
    for _, n in ipairs(nodes) do
        dist[n.i] = Dist(sx, sy, n.x, n.y)
        HeapPush(heap, n, dist[n.i])
    end

    while #heap > 0 do
        local item = HeapPop(heap)
        local n, d = item[1], item[2]

        if not done[n.i] and d <= dist[n.i] then
            done[n.i] = true
            for _, e in ipairs(n.edges) do
                local nd = d + e.cost
                if nd < dist[e.to.i] then
                    dist[e.to.i] = nd
                    prev[e.to.i] = n
                    prevEdge[e.to.i] = e
                    HeapPush(heap, e.to, nd)
                end
            end
        end
    end

    -- Ausstieg: guenstigster Punkt Richtung Ziel
    local best, bestCost = nil, direct
    for _, n in ipairs(nodes) do
        local c = dist[n.i] + Dist(n.x, n.y, ex, ey)
        if c < bestCost then best, bestCost = n, c end
    end

    -- Kleiner Vorteil lohnt den Umweg nicht
    if not best or bestCost > direct * 0.97 then
        return {{x = sx, y = sy}, {x = ex, y = ey}}, {false}, direct
    end

    local chain, legs = {}, {}
    local n = best
    while n do
        table.insert(chain, 1, n)
        local e = prevEdge[n.i]
        table.insert(legs, 1, e and e.route or false)
        n = prev[n.i]
    end
    -- legs[1] gehoert zum Einstieg (abseits), danach je Kante; Ausstieg abseits
    legs[#legs + 1] = false

    local points = {{x = sx, y = sy}}
    for _, c in ipairs(chain) do points[#points + 1] = {x = c.x, y = c.y} end
    points[#points + 1] = {x = ex, y = ey}

    return points, legs, bestCost
end

--------------------------------------------------------------------------------
-- Plan
--------------------------------------------------------------------------------

function Naval.PlanJump(from, to)
    if not from or not to then return nil end
    Graph()

    local key = from.id .. ">" .. to.id
    if cache[key] then return cache[key] end

    local points, legs = Solve(from, to)

    -- Doppelte Punkte (Start liegt auf einer Route) entfernen
    local cleanP, cleanL = {points[1]}, {}
    for i = 2, #points do
        local p, q = cleanP[#cleanP], points[i]
        if Dist(p.x, p.y, q.x, q.y) > 0.05 then
            cleanP[#cleanP + 1] = q
            cleanL[#cleanL + 1] = legs[i - 1]
        end
    end
    if #cleanP == 1 then cleanP[2] = points[#points] cleanL[1] = false end

    -- Laenge, Zeitanteile, Hoehe (z linear ueber die Strecke)
    local length, costs = 0, {0}
    for i = 2, #cleanP do
        local a, b = cleanP[i - 1], cleanP[i]
        local d = Dist(a.x, a.y, b.x, b.y)
        local route = cleanL[i - 1] and Naval.Routes[cleanL[i - 1]]
        length = length + d
        costs[i] = costs[i - 1] + d * (route and Factor(route) or 1)
    end

    local walked = 0
    for i, p in ipairs(cleanP) do
        if i > 1 then walked = walked + Dist(cleanP[i - 1].x, cleanP[i - 1].y, p.x, p.y) end
        local t = length > 0 and walked / length or 0
        p.z = from.g.z + (to.g.z - from.g.z) * t
        p.f = costs[#costs] > 0 and costs[i] / costs[#costs] or 0
    end
    cleanP[1].z, cleanP[#cleanP].z = from.g.z, to.g.z

    local names, seen = {}, {}
    for _, r in ipairs(cleanL) do
        if r and not seen[r] then
            seen[r] = true
            names[#names + 1] = Naval.Routes[r] and Naval.Routes[r].name or r
        end
    end

    local plan = {
        key = key,
        points = cleanP,
        legs = cleanL,
        cost = costs[#costs],
        length = length,
        routes = names,
        direct = #names == 0,
    }

    cache[key] = plan
    return plan
end

-- Erste Sprungrichtung (zum Einstiegspunkt bzw. direkt zum Ziel)
function Naval.JumpVector(fromSystem, toSystem)
    local plan = Naval.PlanJump(fromSystem, toSystem)
    local p = plan and plan.points[2] or toSystem.g
    local dir = Naval.V3.Sub({x = p.x, y = p.y, z = p.z or toSystem.g.z}, fromSystem.g)

    if Naval.V3.Len(dir) < 0.001 then dir = Naval.V3.Sub(toSystem.g, fromSystem.g) end
    return Naval.V3.Normalize(dir)
end

--------------------------------------------------------------------------------
-- An Clients: Weg zum Zeichnen auf der Karte
--------------------------------------------------------------------------------

util.AddNetworkString("PD.Naval.Path")

function Naval.PathKey(ship)
    if ship.hyper and ship.hyper.from and ship.hyper.to then return ship.hyper.from .. ">" .. ship.hyper.to end
    if ship.nav and ship.nav.system and ship.nav.target then return ship.nav.system .. ">" .. ship.nav.target end
end

net.Receive("PD.Naval.Path", function(_, ply)
    if (ply.PD_NavalPathNext or 0) > CurTime() then return end
    ply.PD_NavalPathNext = CurTime() + 1

    local key = net.ReadString()
    local fromId, toId = string.match(key, "^(.-)>(.+)$")
    local plan = fromId and Naval.PlanJump(Naval.Systems[fromId], Naval.Systems[toId])
    if not plan then return end

    local pts = {}
    for i, p in ipairs(plan.points) do
        pts[i] = {math.Round(p.x, 1), math.Round(p.y, 1), math.Round(p.f, 4), plan.legs[i] and true or false}
    end

    net.Start("PD.Naval.Path")
    net.WriteString(key)
    net.WriteString(util.TableToJSON({points = pts, routes = plan.routes}) or "{}")
    net.Send(ply)
end)

--------------------------------------------------------------------------------
-- Konsole
--------------------------------------------------------------------------------

concommand.Add("pd_naval_route", function(ply, _, _, argStr)
    if IsValid(ply) and not ply:IsAdmin() then return end

    local a, b = string.match(argStr or "", "^(.-);(.+)$")
    local from = a and Naval.FindSystem(a)
    local to = b and Naval.FindSystem(b)

    local function Out(text)
        if IsValid(ply) then ply:PrintMessage(HUD_PRINTCONSOLE, "[Naval] " .. text) else PD.RemoteLog("[Naval] " .. text) end
    end

    if not from or not to then Out("pd_naval_route <von> ; <nach>") return end

    local t0 = SysTime()
    cache[from.id .. ">" .. to.id] = nil
    local plan = Naval.PlanJump(from, to)
    local ms = (SysTime() - t0) * 1000

    Out(("%s -> %s: direkt %.0f pc, Weg %.0f pc, effektiv %.0f pc, %d Punkte, %.1f ms"):format(from.name, to.name,
        Naval.SystemDistance(from, to), plan.length, plan.cost, #plan.points, ms))
    Out(plan.direct and "Direktsprung (keine Route lohnt sich)" or ("Ueber: " .. table.concat(plan.routes, " -> ")))
    Out(("Sprungdauer %.0f s"):format(Naval.JumpDuration(from, to, 1)))
end)

-- Kontrolle beim Start: Beispielweg ins Log
hook.Add("PD.Naval.Ready", "PD.Naval.Routing", function()
    local from, to = Naval.FindSystem("Coruscant"), Naval.FindSystem("Tatooine")
    if not from or not to then return end

    local t0 = SysTime()
    local plan = Naval.PlanJump(from, to)
    Naval.Log(("Beispielweg %s -> %s: %.0f pc statt %.0f pc direkt, %.0f s Sprung, %.0f ms, ueber %s"):format(from.name, to.name,
        plan.length, Naval.SystemDistance(from, to), Naval.JumpDuration(from, to, 1), (SysTime() - t0) * 1000,
        plan.direct and "keine Route" or table.concat(plan.routes, " -> ")))
end)
