PD.Entity = PD.Entity or {}
PD.Entity.Umkleide = PD.Entity.Umkleide or {}

util.AddNetworkString("PD.Entity.Umkleide.Load")
util.AddNetworkString("ChangeBodygroup")

function PD.Entity.Umkleide:ChangeBodygroup(ply, bodygroup, value)
    ply:SetBodygroup(bodygroup, value)

    hook.Run("BodygroupChanged", ply, bodygroup, value)
end

net.Receive("ChangeBodygroup", function(len, ply)
    local bodygroup = net.ReadInt(32)
    local value = net.ReadInt(32)

    PD.Entity.Umkleide:ChangeBodygroup(ply, bodygroup, value)
end)

hook.Add("PlayerSetCharacter", "PD.Entity.Umkleide.Load.fromCharSelect", function(ply)
    net.Start("PD.Entity.Umkleide.Load")
    net.Send(ply)
end)
