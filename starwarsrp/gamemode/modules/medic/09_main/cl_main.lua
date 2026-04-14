PD.DM = PD.DM or {}
PD.DM.Main = PD.DM.Main or {}

PD.DM.Interactions = {
    ["player"] = {
        -- [1] = {
        --     id = "tourniquet",
        --     name = LANG.DM_INTERACTION_APPLY_TOURNICATE,
        --     icon = nil,
        --     func = function(ply1, ply2, bone)
        --         net.Start("PD.DM.ChangeTourniquetStatus")
        --         net.WriteEntity(ply1)
        --         net.WriteEntity(ply2)
        --         net.WriteInt(bone, 16)
        --         net.SendToServer()
        --     end,
        --     ad = {"ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_L_Calf",
        --           "ValveBiped.Bip01_R_Calf"}
        -- },
        [1] = {
            id = "check_puls",
            name = LANG.DM_INTERACTION_CHECK_PULS,
            icon = nil,
            func = function(ply1, ply2, bone)
                net.Start("PD.DM.RequestValue")
                net.WriteEntity(ply1)
                net.WriteEntity(ply2)
                net.WriteInt(bone, 16)
                net.WriteString("puls")
                net.SendToServer()
            end,
            ad = {"ValveBiped.Bip01_Head1", "ValveBiped.Bip01_Spine", "ValveBiped.Bip01_L_Forearm",
                  "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_R_Calf", "self"}
        },
        [2] = {
            id = "check_bp",
            name = LANG.DM_INTERACTION_CHECK_BP,
            icon = nil,
            func = function(ply1, ply2, bone)
                net.Start("PD.DM.RequestValue")
                net.WriteEntity(ply1)
                net.WriteEntity(ply2)
                net.WriteInt(bone, 16)
                net.WriteString("bp")
                net.SendToServer()
            end,
            ad = {"ValveBiped.Bip01_Head1", "ValveBiped.Bip01_Spine", "ValveBiped.Bip01_L_Forearm",
                  "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_R_Calf", "self"}
        },
        [3] = {
            id = "check_fractured",
            name = LANG.DM_INTERACTION_CHECK_FRACTURED,
            icon = nil,
            func = function(ply1, ply2, bone)
                net.Start("PD.DM.RequestValue")
                net.WriteEntity(ply1)
                net.WriteEntity(ply2)
                net.WriteInt(bone, 16)
                net.WriteString("fractured")
                net.SendToServer()
            end,
            ad = {"ValveBiped.Bip01_Head1", "ValveBiped.Bip01_Spine", "ValveBiped.Bip01_L_Forearm",
                  "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_R_Calf"}
        },
        [4] = {
            id = "open_interface",
            name = LANG.DM_INTERACTION_OPEN_INTERFACE,
            icon = nil,
            func = function(ply1, ply2, bone)
                chat.AddText("Try to Open Medical Interface")

                net.Start("PD.DM.UI.RequestTreatmentInterface")
                net.WriteEntity(ply1)
                net.WriteEntity(ply2)
                net.SendToServer()
            end,
            ad = {"ValveBiped.Bip01_Spine", "self"}
        }
    },
    ["prop_ragdoll"] = {
        -- [1] = {
        --     id = "tourniquet",
        --     name = LANG.DM_INTERACTION_APPLY_TOURNICATE,
        --     icon = nil,
        --     func = function(ply1, ragdoll, bone)
        --         local ply2 = ragdoll:GetNW2Entity("PD.DM.RagdollOwner")
        --         net.Start("PD.DM.ChangeTourniquetStatus")
        --         net.WriteEntity(ply1)
        --         net.WriteEntity(ply2)
        --         net.WriteInt(bone, 16)
        --         net.SendToServer()
        --     end,
        --     ad = {"ValveBiped.Bip01_L_Forearm", "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_L_Calf",
        --           "ValveBiped.Bip01_R_Calf"}
        -- },
        [1] = {
            id = "check_puls",
            name = LANG.DM_INTERACTION_CHECK_PULS,
            icon = nil,
            func = function(ply1, ragdoll, bone)
                local ply2 = ragdoll:GetNW2Entity("PD.DM.RagdollOwner")
                net.Start("PD.DM.RequestValue")
                net.WriteEntity(ply1)
                net.WriteEntity(ply2)
                net.WriteInt(bone, 16)
                net.WriteString("puls")
                net.SendToServer()
            end,
            ad = {"ValveBiped.Bip01_Head1", "ValveBiped.Bip01_Spine", "ValveBiped.Bip01_L_Forearm",
                  "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_R_Calf", "self"}
        },
        [2] = {
            id = "check_bp",
            name = LANG.DM_INTERACTION_CHECK_BP,
            icon = nil,
            func = function(ply1, ragdoll, bone)
                local ply2 = ragdoll:GetNW2Entity("PD.DM.RagdollOwner")
                net.Start("PD.DM.RequestValue")
                net.WriteEntity(ply1)
                net.WriteEntity(ply2)
                net.WriteInt(bone, 16)
                net.WriteString("bp")
                net.SendToServer()
            end,
            ad = {"ValveBiped.Bip01_Head1", "ValveBiped.Bip01_Spine", "ValveBiped.Bip01_L_Forearm",
                  "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_R_Calf", "self"}
        },
        [3] = {
            id = "check_fractured",
            name = LANG.DM_INTERACTION_CHECK_FRACTURED,
            icon = nil,
            func = function(ply1, ragdoll, bone)
                local ply2 = ragdoll:GetNW2Entity("PD.DM.RagdollOwner")
                net.Start("PD.DM.RequestValue")
                net.WriteEntity(ply1)
                net.WriteEntity(ply2)
                net.WriteInt(bone, 16)
                net.WriteString("fractured")
                net.SendToServer()
            end,
            ad = {"ValveBiped.Bip01_Head1", "ValveBiped.Bip01_Spine", "ValveBiped.Bip01_L_Forearm",
                  "ValveBiped.Bip01_R_Forearm", "ValveBiped.Bip01_L_Calf", "ValveBiped.Bip01_R_Calf"}
        },
        [4] = {
            id = "open_interface",
            name = LANG.DM_INTERACTION_OPEN_INTERFACE,
            icon = nil,
            func = function(ply1, ragdoll, bone)
                local ply2 = ragdoll:GetNW2Entity("PD.DM.RagdollOwner")
                net.Start("PD.DM.UI.RequestTreatmentInterface")
                net.WriteEntity(ply1)
                net.WriteEntity(ply2)
                net.SendToServer()
            end,
            ad = {"ValveBiped.Bip01_Spine", "self"}
        },
    }
}

function PD.DM.IsMedic(ply)
    local job_id, job_tbl = ply:GetJob()
    local subunit_id, subunit_tbl = PD.JOBS.GetSubUnit(job_tbl.unit, false)
    if subunit_tbl.ismedic or job_tbl.ismedic then
        return true
    end

    return false
end

net.Receive("PD.DM.RecieveValue", function()
    local str = net.ReadString()

    if str == "injuries" then
        local val = net.ReadTable()

        for k, v in ipairs(val) do
            LocalPlayer():ChatPrint(v.name)
        end
    elseif str == "puls" then
        local val = net.ReadInt(16)

        LocalPlayer():ChatPrint("Puls: " .. val)
    elseif str == "bp" then
        local val = net.ReadTable()

        LocalPlayer():ChatPrint("BP: " .. val[1] .. "/" .. val[2])
    end
end)

function PD.DM:OpenInterface()
    local ply1 = LocalPlayer()
    local ply2 = LocalPlayer()
    local trace = ply1:GetEyeTrace()
    local ent = trace.Entity

    if IsValid(ent) and ent:IsPlayer() and ply1:GetPos():Distance(ent:GetPos()) < 150 then
        ply2 = ent
    elseif ent:GetClass() == "prop_ragdoll" then
        ply2 = ent:GetNW2Entity("PD.DM.RagdollOwner")
    elseif ent:GetClass() == "prop_vehicle_prisoner_pod" and IsValid(ent:GetDriver()) then
        ply2 = ent:GetDriver()
    end

    net.Start("PD.DM.UI.RequestTreatmentInterface")
    net.WriteEntity(ply1)
    net.WriteEntity(ply2)
    net.SendToServer()
end

function PD.DM.Main.Interact(task_class, task_name, patient, body_part_index)
    net.Start("PD.DM.Interact")
    net.WriteEntity(LocalPlayer())
    net.WriteEntity(patient)
    net.WriteInt(task_class, 4)
    net.WriteInt(task_name, 11)
    net.WriteInt(body_part_index or 0, 4)
    net.SendToServer()

end

function PD.DM.Main.EndInteraction(patient)
    net.Start("PD.DM.UI.CloseTreatmentInterface")
    net.WriteEntity(LocalPlayer())
    net.WriteEntity(patient)
    net.SendToServer()
end

hook.Add("PD.Interaction.Requested", "PD.DM.Interaction.Answer", function(ent_class)
    PD.IA.AddEntityActions(PD.DM.Interactions[ent_class], LANG.DM_INTERACTION_MEDIC_OPTIONS)
end)