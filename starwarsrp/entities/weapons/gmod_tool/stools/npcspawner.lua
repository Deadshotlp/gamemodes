TOOL.Name = "#tool.npcspawnertool.name"
TOOL.Category = "Gamemode - NPC"
TOOL.Command = nil
TOOL.ConfigName = ""

if CLIENT then
    language.Add("tool.npcspawnertool.name", "NPC Spawner")
    language.Add("tool.npcspawnertool.desc", "Spawnt eine im NPC Creator gespeicherte NPC-Vorlage.")
    language.Add("tool.npcspawnertool.0", "Linksklick: NPC spawnen | Rechtsklick: zuletzt gespawnte NPC entfernen")
end

TOOL.ClientConVar["template"] = ""

function TOOL:LeftClick(trace)
    if CLIENT then return true end
    if not trace.Hit or IsValid(trace.Entity) and trace.Entity:IsPlayer() then return false end

    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsAdmin() then return false end

    local templateName = self:GetClientInfo("template")
    if not templateName or templateName == "" then
        ply:ChatPrint("Keine NPC-Vorlage ausgewählt. Öffne das Werkzeugmenü (Q) und wähle eine Vorlage.")
        return false
    end

    local data = PD.NPCCreator and PD.NPCCreator.Templates[templateName]
    if not data then
        ply:ChatPrint("Vorlage nicht gefunden: " .. templateName)
        return false
    end

    local npc = PD.NPCCreator.SpawnFromTemplate(ply, data, trace)
    if not IsValid(npc) then return false end

    self.LastSpawned = self.LastSpawned or {}
    table.insert(self.LastSpawned, npc)

    ply:ChatPrint("NPC gespawnt: " .. data.name)
    return true
end

function TOOL:RightClick(trace)
    if CLIENT then return true end

    local ply = self:GetOwner()
    if not IsValid(ply) or not ply:IsAdmin() then return false end

    local list = self.LastSpawned or {}
    local last = table.remove(list)

    if IsValid(last) then
        last:Remove()
        ply:ChatPrint("Letzte gespawnte NPC entfernt.")
    else
        ply:ChatPrint("Keine NPC zum Entfernen.")
    end

    return true
end

function TOOL.BuildCPanel(CPanel)
    CPanel:Help("Wähle eine im NPC Creator gespeicherte Vorlage. Linksklick spawnt sie, Rechtsklick entfernt die zuletzt gespawnte NPC wieder.")

    local combo = CPanel:ComboBox("NPC-Vorlage", "npcspawner_template")
    combo:AddChoice("- Keine Vorlage gewählt -", "")

    if not PD.NPCCreator then return end

    PD.NPCCreator.RequestTemplates(function(templates)
        if not IsValid(combo) then return end

        for name in SortedPairs(templates) do
            combo:AddChoice(name, name)
        end
    end)
end
