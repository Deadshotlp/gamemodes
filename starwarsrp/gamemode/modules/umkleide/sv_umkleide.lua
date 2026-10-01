PD.Entity = PD.Entity or {}
PD.Entity.Umkleide = PD.Entity.Umkleide or {}

util.AddNetworkString("PD.Entity.Umkleide.Load")
util.AddNetworkString("ChangeBodygroup")
util.AddNetworkString("ChangeModel")

function PD.Entity.Umkleide:ChangeBodygroup(ply, bodygroup, value)
    ply:SetBodygroup(bodygroup, value)

    -- Merken, sonst ist die Auswahl beim nächsten Spawn weg. SetPlayerPhaseModel
    -- liest PD_Bodygroups aus, geschrieben hat sie bisher niemand.
    ply.PD_Bodygroups = ply.PD_Bodygroups or {}
    ply.PD_Bodygroups[bodygroup] = value

    hook.Run("BodygroupChanged", ply, bodygroup, value)
end

net.Receive("ChangeBodygroup", function(len, ply)
    local bodygroup = net.ReadInt(32)
    local value = net.ReadInt(32)

    if bodygroup < 0 or bodygroup >= ply:GetNumBodyGroups() then return end
    if value < 0 or value >= ply:GetBodygroupCount(bodygroup) then return end

    -- Bodygroups, die ein Fortbildungs-Abzeichen belegt, dürfen nicht selbst
    -- verstellt werden - sonst schaltet man sein Abzeichen einfach weg.
    if PD.FB and PD.FB.IsBadgeBodygroup and PD.FB.IsBadgeBodygroup(ply, bodygroup) then
        PD.Notify("Diese Bodygroup gehört zu einem Abzeichen und ist gesperrt.", Color(200, 150, 40), false, ply)
        return
    end

    PD.Entity.Umkleide:ChangeBodygroup(ply, bodygroup, value)
end)

-- Modelle aus Job und Unit. Greift nur, wenn das Fortbildungsmodul fehlt - sonst
-- liefert PD.FB.GetAllowedModelList dieselben Werte plus die freigeschalteten.
-- Baut bewusst eine neue Tabelle: der alte Code schrieb die Unit-Models per
-- table.insert in jobTable.model und veränderte damit die geteilte PD.JOBS-Tabelle.
local function getJobModels(ply)
    local _, jobTable = ply:GetJob()
    local models = {}

    if not istable(jobTable) then return models end

    for _, model in pairs(jobTable.model or {}) do
        table.insert(models, model)
    end

    for _, unitData in SortedPairs(PD.JOBS.GetUnit(false, true)) do
        if unitData.name == jobTable.unit then
            for _, model in pairs(unitData.model or {}) do
                table.insert(models, model)
            end
        end
    end

    return models
end

net.Receive("ChangeModel", function(len, ply)
    local model = net.ReadString()
    local models

    if PD.FB and PD.FB.GetAllowedModelList then
        models = PD.FB.GetAllowedModelList(ply)
    else
        models = getJobModels(ply)
    end

    for _, allowed in pairs(models) do
        if string.lower(model) == string.lower(allowed) then
            ply:SetModel(model)

            -- Auswahl merken, damit sie den nächsten Spawn übersteht. Die alten
            -- Bodygroups fallen dabei weg: ihre Indizes bedeuten bei einem
            -- anderen Model etwas anderes.
            ply.PD_Model = model
            ply.PD_Bodygroups = nil

            hook.Run("ModelChanged", ply, model)

            -- Abzeichen sitzen modellabhängig, nach dem Wechsel neu setzen.
            if PD.FB and PD.FB.ApplyBadges then
                PD.FB.ApplyBadges(ply)
            end

            return
        end
    end
end)

hook.Add("PlayerSetCharacter", "PD.Entity.Umkleide.Load.fromCharSelect", function(ply)
    net.Start("PD.Entity.Umkleide.Load")
    net.Send(ply)
end)
