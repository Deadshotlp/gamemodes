TOOL.Name = "#tool.npcpatroltool.name"
TOOL.Category = "Gamemode - NPC"
TOOL.Command = nil
TOOL.ConfigName = ""

if CLIENT then
    language.Add("tool.npcpatroltool.name", "NPC Patrol-Route")
    language.Add("tool.npcpatroltool.desc", "Platziert und verbindet Wegpunkte fuer NPC-Patrol-Routen.")
    language.Add("tool.npcpatroltool.0", "Linksklick: Punkt hinzufügen | Rechtsklick: letzten Punkt entfernen | Reload: Route leeren")
end

TOOL.ClientConVar["route"] = ""

function TOOL:LeftClick(trace)
    if CLIENT then return true end
    if not trace.Hit then return false end

    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsAdmin() then return false end

    local name = self:GetClientInfo("route")
    if not name or name == "" then
        ply:ChatPrint("Bitte zuerst einen Routennamen im Werkzeugmenü (Q) eingeben.")
        return false
    end

    local ang = Angle(0, ply:EyeAngles().y, 0)
    local route = PD.PatrolRoutes.AddPoint(name, trace.HitPos, ang)
    PD.PatrolRoutes.SendPointsTo(ply, name)

    ply:ChatPrint("Wegpunkt " .. #route .. " zu Route '" .. name .. "' hinzugefügt.")
    return true
end

function TOOL:RightClick(trace)
    if CLIENT then return true end

    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsAdmin() then return false end

    local name = self:GetClientInfo("route")
    if not name or name == "" then return false end

    PD.PatrolRoutes.RemoveLastPoint(name)
    PD.PatrolRoutes.SendPointsTo(ply, name)

    ply:ChatPrint("Letzten Wegpunkt von Route '" .. name .. "' entfernt.")
    return true
end

function TOOL:Reload(trace)
    if CLIENT then return true end

    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsAdmin() then return false end

    local name = self:GetClientInfo("route")
    if not name or name == "" then return false end

    PD.PatrolRoutes.ClearRoute(name)
    PD.PatrolRoutes.SendPointsTo(ply, name)

    ply:ChatPrint("Route '" .. name .. "' geleert.")
    return true
end

if CLIENT then
    function TOOL:DrawHUD()
        local points = PD.PatrolRoutes.ClientPoints
        if not points or #points == 0 then return end

        cam.Start3D(EyePos(), EyeAngles())
            for i, pos in ipairs(points) do
                render.SetColorMaterial()
                render.DrawSphere(pos, 6, 10, 10, Color(0, 200, 255))

                local nextPos = points[i + 1]
                if nextPos then
                    render.DrawLine(pos, nextPos, Color(0, 200, 255), true)
                end
            end
        cam.End3D()
    end
end

function TOOL.BuildCPanel(CPanel)
    CPanel:Help("Trage einen Routennamen ein (neu oder bestehend), dann Linksklick zum Anlegen von Wegpunkten in der Welt. Eine NPC mit dieser Route als 'PatrolRoute' läuft sie der Reihe nach ab.")
    CPanel:TextEntry("Routenname", "npcpatrol_route")

    if not PD.PatrolRoutes then return end

    PD.PatrolRoutes.RequestRoutes(function(names)
        if #names == 0 then return end
        CPanel:Help("Bestehende Routen: " .. table.concat(names, ", "))
    end)
end
