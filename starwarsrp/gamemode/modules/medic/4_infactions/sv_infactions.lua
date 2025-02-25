PD.DM = PD.DM or {}
PD.DM.Infactions = PD.DM.Infactions or {}

PD.DM.Infactions.tbl = {
    [1] = {
        puls = function(ply, puls)
            -- Mainly for Infections
        end,
        spo2 = function(ply, spo2)
            -- Mainly for Infections
        end,
        bp = function(ply, bp)
            -- Mainly for Infections
        end
    }
}

function PD.DM:AddInfactions(tbl)
    local rand = math.random(1, 1000)

    if not rand <= 10 then
        return
    end

    print("player got infection")
end
