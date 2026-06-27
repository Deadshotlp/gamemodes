util.AddNetworkString("PD.PatrolRoutes.RequestRoutes")
util.AddNetworkString("PD.PatrolRoutes.Routes")
util.AddNetworkString("PD.PatrolRoutes.RoutePoints")

PD.JSON.Create("patrolroutes")

PD.PatrolRoutes = PD.PatrolRoutes or {}
PD.PatrolRoutes.Routes = {}

local function SerializeRoutes()
    local out = {}
    for name, points in pairs(PD.PatrolRoutes.Routes) do
        local list = {}
        for _, p in ipairs(points) do
            table.insert(list, {
                x = p.pos.x, y = p.pos.y, z = p.pos.z,
                ax = p.ang.p, ay = p.ang.y, az = p.ang.r,
            })
        end
        out[name] = list
    end
    return out
end

local function DeserializeRoutes(raw)
    local out = {}
    for name, list in pairs(raw or {}) do
        local points = {}
        for _, p in ipairs(list) do
            table.insert(points, {
                pos = Vector(p.x or 0, p.y or 0, p.z or 0),
                ang = Angle(p.ax or 0, p.ay or 0, p.az or 0),
            })
        end
        out[name] = points
    end
    return out
end

local function SaveRoutes()
    PD.JSON.Write("patrolroutes/routes.json", SerializeRoutes())
end

hook.Add("Initialize", "PD.PatrolRoutes.Load", function()
    PD.PatrolRoutes.Routes = DeserializeRoutes(PD.JSON.Read("patrolroutes/routes.json"))
end)

function PD.PatrolRoutes.AddPoint(name, pos, ang)
    if not isstring(name) or name == "" then return nil end

    PD.PatrolRoutes.Routes[name] = PD.PatrolRoutes.Routes[name] or {}
    table.insert(PD.PatrolRoutes.Routes[name], {pos = pos, ang = ang})
    SaveRoutes()

    return PD.PatrolRoutes.Routes[name]
end

function PD.PatrolRoutes.RemoveLastPoint(name)
    local route = PD.PatrolRoutes.Routes[name]
    if route and #route > 0 then
        table.remove(route)
        SaveRoutes()
    end
    return route
end

function PD.PatrolRoutes.ClearRoute(name)
    PD.PatrolRoutes.Routes[name] = {}
    SaveRoutes()
end

function PD.PatrolRoutes.SendPointsTo(ply, name)
    if not IsValid(ply) then return end

    local route = PD.PatrolRoutes.Routes[name] or {}

    net.Start("PD.PatrolRoutes.RoutePoints")
    net.WriteUInt(#route, 8)
    for _, p in ipairs(route) do
        net.WriteVector(p.pos)
    end
    net.Send(ply)
end

net.Receive("PD.PatrolRoutes.RequestRoutes", function(len, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local names = {}
    for name in pairs(PD.PatrolRoutes.Routes) do
        table.insert(names, name)
    end

    net.Start("PD.PatrolRoutes.Routes")
    net.WriteTable(names)
    net.Send(ply)
end)
