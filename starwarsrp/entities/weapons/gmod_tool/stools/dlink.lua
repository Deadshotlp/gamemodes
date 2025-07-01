TOOL.Name = "#tool.linktool.name"
TOOL.Category = "P & D"
TOOL.Command = nil
TOOL.ConfigName = ""

if CLIENT then
    language.Add("tool.linktool.name", "DLink")
    language.Add("tool.linktool.desc", "Wähle zwei Entities aus und verlinke sie mit einem Beam")
    language.Add("tool.linktool.0",
        "Linksklick: Erstes Entity auswählen | Rechtsklick: Zweites Entity auswählen und verlinken | Reload: Auswahl zurücksetzen")

    -- Zeichnet Beam (nur clientseitig)
    hook.Add("PostDrawTranslucentRenderables", "LinkTool_BeamDraw", function()
        for _, ent in ipairs(ents.GetAll()) do
            if IsValid(ent.LinkedEnt) and ent:EntIndex() < ent.LinkedEnt:EntIndex() then
                render.SetMaterial(Material("cable/redlaser"))
                render.DrawBeam(ent:GetPos(), ent.LinkedEnt:GetPos(), 5, 0, 1, Color(255, 0, 0, 255))
            end
        end
    end)
end

-- Temporäre Auswahl auf Server-Seite speichern
function TOOL:LeftClick(trace)
    if not IsValid(trace.Entity) or trace.Entity:IsPlayer() then
        return false
    end

    self:SetStage(1)
    self.SelectedEnt = trace.Entity
    self:GetOwner():ChatPrint("Erstes Entity ausgewählt: " .. tostring(trace.Entity))
    return true
end

function TOOL:RightClick(trace)
    if self:GetStage() ~= 1 then
        return false
    end
    if not IsValid(trace.Entity) or trace.Entity:IsPlayer() then
        return false
    end

    local ent1 = self.SelectedEnt
    local ent2 = trace.Entity

    if not IsValid(ent1) or not IsValid(ent2) or ent1 == ent2 then
        self:GetOwner():ChatPrint("Ungültige Auswahl.")
        return false
    end

    -- Verlinkung herstellen
    ent1.LinkedEnt = ent2
    ent2.LinkedEnt = ent1

    -- Mach die Verlinkung duplizierbar (optional, basic version)
    ent1:CallOnRemove("ClearLinkedEnt", function(ent)
        if IsValid(ent.LinkedEnt) then
            ent.LinkedEnt.LinkedEnt = nil
        end
    end)

    ent2:CallOnRemove("ClearLinkedEnt", function(ent)
        if IsValid(ent.LinkedEnt) then
            ent.LinkedEnt.LinkedEnt = nil
        end
    end)

    self:GetOwner():ChatPrint("Entities erfolgreich verlinkt!")

    self:SetStage(0)
    self.SelectedEnt = nil
    return true
end

function TOOL:Reload(trace)
    self:SetStage(0)
    self.SelectedEnt = nil
    self:GetOwner():ChatPrint("Auswahl zurückgesetzt")
    return true
end
