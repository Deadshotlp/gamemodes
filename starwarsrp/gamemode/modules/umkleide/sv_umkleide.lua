PD.Entity = PD.Entity or {}
PD.Entity.Umkleide = PD.Entity.Umkleide or {}

util.AddNetworkString("PD.Entity.Umkleide.Load")

hook.Add("PlayerSetCharacter", "PD.Entity.Umkleide.Load.fromCharSelect", function(ply)
    net.Start("PD.Entity.Umkleide.Load")
    net.Send(ply)
end)