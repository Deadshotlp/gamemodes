PD.VD = PD.VD or {}

PD.VD.Vehicle = {
    {
        name = "ARC-170 Starfighter",
        vehicle = "lvs_starfighter_arc170",
        check = function(ply)
            return true -- PD.CheckUnitAccess(ply, "Stoßtruppen")
        end,
    },

}

