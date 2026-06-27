PD.PatrolRoutes = PD.PatrolRoutes or {}
PD.PatrolRoutes.Listeners = PD.PatrolRoutes.Listeners or {}
PD.PatrolRoutes.ClientPoints = PD.PatrolRoutes.ClientPoints or {}

-- One-shot request/response, mirrors PD.NPCCreator.RequestTemplates
function PD.PatrolRoutes.RequestRoutes(callback)
    if isfunction(callback) then
        table.insert(PD.PatrolRoutes.Listeners, callback)
    end

    net.Start("PD.PatrolRoutes.RequestRoutes")
    net.SendToServer()
end

net.Receive("PD.PatrolRoutes.Routes", function()
    local names = net.ReadTable()
    local listeners = PD.PatrolRoutes.Listeners
    PD.PatrolRoutes.Listeners = {}

    for _, cb in ipairs(listeners) do
        cb(names)
    end
end)

net.Receive("PD.PatrolRoutes.RoutePoints", function()
    local count = net.ReadUInt(8)
    local points = {}

    for i = 1, count do
        table.insert(points, net.ReadVector())
    end

    PD.PatrolRoutes.ClientPoints = points
end)
