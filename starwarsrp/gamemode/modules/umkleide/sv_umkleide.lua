PD.Entity = PD.Entity or {}
PD.Entity.Umkleide = PD.Entity.Umkleide or {}

util.AddNetworkString("PD.Entity.Umkleide.Load")
util.AddNetworkString("ChangeBodygroup")
util.AddNetworkString("ChangeModel")

function PD.Entity.Umkleide:ChangeBodygroup(ply, bodygroup, value)
    ply:SetBodygroup(bodygroup, value)

    hook.Run("BodygroupChanged", ply, bodygroup, value)
end

net.Receive("ChangeBodygroup", function(len, ply)
    local bodygroup = net.ReadInt(32)
    local value = net.ReadInt(32)

    PD.Entity.Umkleide:ChangeBodygroup(ply, bodygroup, value)
end)

net.Receive("ChangeModel", function(len, ply)
    local model = net.ReadString()
    local jobID, jobTable = ply:GetJob()
    local models = jobTable.model

    for k, v in SortedPairs(PD.JOBS.GetUnit(false, true)) do
        if v.name == jobTable.unit then
            for _, v in pairs(v.model) do
                table.insert(models, v)
            end
            continue
        end
    end

    for _,v in pairs(models) do
        if string.lower(model) == string.lower(v) then
            ply:SetModel(model)

            hook.Run("ModelChanged", ply, model)
            return
        end
    end
end)

hook.Add("PlayerSetCharacter", "PD.Entity.Umkleide.Load.fromCharSelect", function(ply)
    net.Start("PD.Entity.Umkleide.Load")
    net.Send(ply)
end)
