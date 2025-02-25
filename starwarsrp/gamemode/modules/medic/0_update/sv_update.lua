PD.DM = PD.DM or {}
PD.DM.UPDATE = PD.DM.UPDATE or {}

local time = os.time()
local delay = 1

function PD.DM:Update()
    local time1 = os.time()
    print("Start Update Medical Data: " .. PD.DM:FormatTime())

    for _, ply in pairs(player.GetAll()) do
        if not PD.DM.Main.tbl[ply:SteamID64()] then
            PD.DM.AddPlayerEntry(ply)
        end
    end

    for k, v in pairs(PD.DM.Main.tbl) do
        PD.DM:CalculateInjuries(v)
        local m1, m2, m3 = PD.DM:CalculateMedication(v)
        PD.DM:CalculatePuls(v, m1)
        PD.DM:CalculateBP(v, m2)
        PD.DM:CalculateSPO2(v, m3)
    end

    local time2 = os.time()

    print(time1)
    print(time2)
    print("Time: " .. time2 - time1)

    print("End Update Medical Data: " .. PD.DM:FormatTime())
end

hook.Add("Think", "PD.DM.Update", function()
    if os.time() - time >= delay and player.GetCount() ~= 0 then
        PD.DM:Update()
        time = os.time()
    end
end)

function PD.DM:FormatTime()
    return string.FormattedTime(os.time(), "%02i:%02i:%02i")
end
