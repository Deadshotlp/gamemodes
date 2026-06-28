TOOL.Name = "#tool.doorlinktool.name"
TOOL.Category = "P & D"
TOOL.Command = nil
TOOL.ConfigName = ""

-- Sprachstrings
if CLIENT then
    language.Add("tool.doorlinktool.name", "Tür Linker (ID - Card)")
    language.Add("tool.doorlinktool.desc", "Wähle mehrere Türen aus und verknüpfe sie mit einem ID-Card-Linker.")
    language.Add("tool.doorlinktool.0", "Linksklick: Tür hinzufügen/entfernen | Rechtsklick: ID-Card-Linker spawnen | Reload: Auswahl zurücksetzen")
end

-- ConVar für Sicherheitslevel
TOOL.ClientConVar["level"] = "1"

-- Server-seitige Speicherung der Auswahl
TOOL.SelectedDoors = {}

-- Netzwerk zum Sync der Auswahl
if SERVER then
    util.AddNetworkString("doorlinktool_update")
end

-- Türen auswählen oder abwählen
function TOOL:LeftClick(trace)
    if CLIENT then return true end

    local ent = trace.Entity
    if not IsValid(ent) or ent:IsPlayer() then return false end

    local ply = self:GetOwner()
    self.SelectedDoors[ply] = self.SelectedDoors[ply] or {}
    local doors = self.SelectedDoors[ply]

    if table.HasValue(doors, ent) then
        table.RemoveByValue(doors, ent)
        ply:ChatPrint("Tür entfernt: " .. tostring(ent))
    else
        table.insert(doors, ent)
        ply:ChatPrint("Tür hinzugefügt: " .. tostring(ent))
    end

    -- Sync an Client
    net.Start("doorlinktool_update")
        net.WriteUInt(#doors, 8)
        for _, door in ipairs(doors) do
            net.WriteEntity(door)
        end
    net.Send(ply)

    return true
end

-- ID-Card-Linker spawnen
function TOOL:RightClick(trace)
    if CLIENT then return true end

    local ply = self:GetOwner()
    local doors = self.SelectedDoors[ply] or {}

    if #doors == 0 then
        ply:ChatPrint("Keine Türen ausgewählt!")
        return false
    end

    -- Position & Ausrichtung an Wand
    local pos = trace.HitPos + trace.HitNormal * 1
    local ang = trace.HitNormal:Angle()
    ang:RotateAroundAxis(ang:Right(), -90)

    local ent = ents.Create("idcardlinker")
    if not IsValid(ent) then return false end

    ent:SetPos(pos)
    ent:SetAngles(ang + Angle(-90, -90, 0))
    ent:Spawn()

    -- Physik deaktivieren
    local phys = ent:GetPhysicsObject()
    if IsValid(phys) then
        phys:EnableMotion(false)
    end

    -- Sicherheitslevel vom Toolpanel
    local level = self:GetClientNumber("level", 1)
    ent.SecurityLevel = level

    -- Verlinke Türen
    ent:AddDoors(doors, level)

    ply:ChatPrint("ID-Card-Linker gespawnt – " .. #doors .. " Tür(en), Level: " .. level)


    -- Auswahl zurücksetzen
    self.SelectedDoors[ply] = {}
    net.Start("doorlinktool_update")
        net.WriteUInt(0, 8)
    net.Send(ply)

    return true
end

-- Auswahl zurücksetzen
function TOOL:Reload(trace)
    if CLIENT then return true end

    local ply = self:GetOwner()
    self.SelectedDoors[ply] = {}

    -- Leeren Sync
    net.Start("doorlinktool_update")
        net.WriteUInt(0, 8)
    net.Send(ply)

    ply:ChatPrint("Türauswahl zurückgesetzt.")
    return true
end

-- Clientseitige Auswahl anzeigen
if CLIENT then
    ClientSelectedDoors = {}

    -- Netzwerkempfang
    net.Receive("doorlinktool_update", function()
        local count = net.ReadUInt(8)
        ClientSelectedDoors = {}

        for i = 1, count do
            local ent = net.ReadEntity()
            if IsValid(ent) then
                table.insert(ClientSelectedDoors, ent)
            end
        end
    end)

    -- Auswahlumrandung zeichnen
    function TOOL:DrawHUD()
        cam.Start3D(EyePos(), EyeAngles())
        for _, door in ipairs(ClientSelectedDoors or {}) do
            if IsValid(door) then
                render.SetColorMaterial()
                render.DrawWireframeBox(
                    door:GetPos(),
                    door:GetAngles(),
                    door:OBBMins(),
                    door:OBBMaxs(),
                    Color(255, 0, 0), -- rot
                    true
                )
            end
        end
        cam.End3D()
    end
end

-- Control Panel für Sicherheitslevel
function TOOL.BuildCPanel(CPanel)
    CPanel:Help("Wähle das Sicherheitslevel, das für die verknüpften Türen erforderlich ist.")
    CPanel:NumSlider("Sicherheitslevel", "doorlinktool_level", 1, 5, 0)
end
