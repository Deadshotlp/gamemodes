PD.Comlink = PD.Comlink or {}

PD.Comlink.Table = {}
PD.Comlink.Table["Test"] = {
    color = Color(255, 255, 255),
    mute = false,
    check = function(ply)
        return true
    end,
}

for k, v in pairs(PD.JOBS.GetUnit(false, true)) do
    PD.Comlink.Table[k] = {
        color = v.color,
        mute = true,
        check = function(ply, unit)
            return PD.CheckUnitAccess(ply, unit)
        end,
    }
end

for k, v in pairs(PD.JOBS.GetSubUnit(false, true)) do
    PD.Comlink.Table[k] = {
        color = v.color,
        mute = true,
        check = function(ply, unit)
            return PD.CheckSubUnitAccess(ply, unit)
        end,
    }
end

for i = 1, 15 do 
    PD.Comlink.Table["Channel " .. i] = {
        color = Color(math.random(0, 255), math.random(0, 255), math.random(0, 255)),
        mute = false,
        check = function(ply)
            return true
        end,
    }
end

