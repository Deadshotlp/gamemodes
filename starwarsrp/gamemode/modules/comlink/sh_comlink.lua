PD.Comlink = PD.Comlink or {}

PD.Comlink.Table = {}
-- PD.Comlink.Table["Test"] = {
--     color = Color(255, 255, 255),
--     mute = false,
--     check = function(ply)
--         return true
--     end,
-- }

PD.Comlink.Table[1] = {
    name = "TeamChannel",
    color = Color(255, 0, 0),
    mute = true,
    check = function(ply)
        return ply:IsAdmin()
    end,
}

PD.Comlink.Table[2] = {
    name = "Einsatzkoordinations Funk",
    color = Color(255, 255, 255),
    mute = false,
    check = function(ply)
        return true
    end,
}

PD.Comlink.Table[3] = {
    name = "Medizinischer Notfall Funk",
    color = Color(255, 0, 0),
    mute = false,
    check = function(ply)
        return true
    end,
}

PD.Comlink.Table[4] = {
    name = "Technischer Notfall Funk",
    color = Color(255, 125, 0),
    mute = false,
    check = function(ply)
        return true
    end,
}

PD.Comlink.Table[5] = {
    name = "Straftaten Notfall Funk",
    color = Color(0, 125, 255),
    mute = false,
    check = function(ply)
        return true
    end,
}

for k, v in pairs(PD.JOBS.GetUnit(false, true)) do
    --PrintTable(v)
    table.insert(PD.Comlink.Table, {
        name = k,
        color = v.color,
        mute = true,
        check = function(ply, unit)
            return PD.CheckUnitAccess(ply, k)
        end,
    })
end

for k, v in pairs(PD.JOBS.GetSubUnit(false, true)) do
    --PrintTable(v)
    table.insert(PD.Comlink.Table, {
        name = v.name,
        color = v.color,
        mute = true,
        check = function(ply, unit)
            return PD.CheckSubUnitAccess(ply, k)
        end,
    })
end

for i = 1, 10 do 
    table.insert(PD.Comlink.Table, {
        name = "Einheit " .. i,
        color = Color(255, 255, 255),
        mute = false,
        check = function(ply)
            return true
        end,
    })
end