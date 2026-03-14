PD.DM = PD.DM or {}
PD.DM.UPDATE = PD.DM.UPDATE or {}

local time = os.time()
local delay = 1

local function createRagdoll(ply)
    local ragdoll = ents.Create("prop_ragdoll")
    ragdoll:SetModel(ply:GetModel() or "models/player/kleiner.mdl") -- Oder ein anderes Model
    ragdoll:SetPos(ply:GetPos() or Vector(0, 0, 100)) -- Position setzen
    ragdoll:SetAngles(ply:GetAngles() or Angle(0, 0, 0)) -- Rotation setzen
    ragdoll:Spawn()
    ragdoll:Activate()
    ragdoll.equip = {}

    for k, v in pairs(ply:GetWeapons()) do
        ragdoll.equip[k] = v:GetClass()
    end

    for k, v in pairs(ply:GetBodyGroups()) do
        ragdoll:SetBodygroup(k, ply:GetBodygroup(k))
    end

    local ragdoll_phys = ragdoll:GetPhysicsObject()
    local ply_phys = ply:GetPhysicsObject()
    if IsValid(ragdoll_phys) then
        -- ragdoll_phys:Wake()
    end

    ragdoll:SetNW2Entity("PD.DM.RagdollOwner", ply)
    ply:SetNW2Entity("PD.DM.Ragdoll", ragdoll)
    ply:SetViewEntity(ragdoll)

    return ragdoll
end

function PD.DM:Update()
    -- local time1 = os.time()

    -- print("Start Update Medical Data: " .. PD.DM:FormatTime())

    for _, ply_tbl in pairs(PD.DM.Main.tbl) do

        local ply = player.GetBySteamID64(_)

        if not IsValid(ply) then
            table.remove(PD.DM.Main.tbl, _)
            continue
        end

        if ply:HasGodMode() then continue end

        if ply_tbl.blood_to_add and ply_tbl.blood_to_add > 0 then
            local add_amount = math.min(ply_tbl.blood_to_add, 0.05)
            ply_tbl.blood_amount = ply_tbl.blood_amount + add_amount
            ply_tbl.blood_to_add = ply_tbl.blood_to_add - add_amount

            if ply_tbl.blood_amount >= 5.5 then
                ply_tbl.blood_amount = ply_tbl.blood_amount - 0.005
            end
        end

        for k, v in pairs(ply_tbl.activ_interaktion) do
            local ply2 = player.GetBySteamID64(v)
            PD.DM.UI.UpdateLiveInteraktion(ply2, ply, ply_tbl)
        end

        local i1, i2, i3 = PD.DM:CalculateInjuries(ply_tbl)
        local m1, m2, m3 = PD.DM:CalculateMedication(ply_tbl)
        PD.DM:CalculatePuls(ply_tbl, i1 + m1)
        PD.DM:CalculateBP(ply_tbl, i2 + m2)
        PD.DM:CalculateSPO2(ply_tbl, i3 + m3)

        ply:SetNW2Int("PD.DM.Puls", math.Round(ply_tbl.puls))
        ply:SetNW2Int("PD.DM.SPO2", math.Round(ply_tbl.spo2))

        if ply:Alive() then
            if not (ply_tbl.puls > 30 and PD.IsBetween(ply_tbl.bp[1], 40, 200) and
            PD.IsBetween(ply_tbl.bp[2], 20, 150) and ply_tbl.spo2 > 50 and ply_tbl.stunning_level ~= 1) then
                createRagdoll(ply)
                ply:KillSilent()
                PrintTable(ply_tbl)
                PD.Death.Kill(ply, ply:GetNW2String("PD.DM.LastHitBy") or "Unknown")
            end
        else
            if PD.IsBetween(ply_tbl.puls, 50, 120) and PD.IsBetween(ply_tbl.bp[1], 60, 200) and
            PD.IsBetween(ply_tbl.bp[2], 40, 150) and PD.IsBetween(ply_tbl.spo2, 85, 100) and ply_tbl.stunning_level == 0 then
                PD.DM.Revive(ply, ply_tbl)
            end
            
            local rand = math.random(1, 100)
            if rand <= 5 and not ply_tbl.recovery_position and not ply_tbl.respiratory_system.airway_clear then
                ply_tbl.respiratory_system.airway_clear = false
            end
        end

        if ply_tbl.stunning_level > 0 then
            ply_tbl.stunning_level = math.Clamp(ply_tbl.stunning_level - 0.0033, 0, 1)
        end

    end

    -- local time2 = os.time()

    -- if 

    -- print(time1)
    -- print(time2)
    -- print("Time: " .. time2 - time1)

    -- print("End Update Medical Data: " .. PD.DM:FormatTime())
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
