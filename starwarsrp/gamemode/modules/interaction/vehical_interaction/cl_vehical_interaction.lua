PD.IA = PD.IA or {}
PD.IA.VI = PD.IA.VI or {}

PD.IA.VI.Interactions = {
    ["lvs_sw_transport"] = {
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
            id = "tourniquet",
            name = "Test",
            icon = nil,
            func = function(ply1, ply2, bone)
                print("test")
            end,
            ad = {"static_prop"}
        },
    }
}

hook.Add("PD.Interaction.Requested", "PD.IA.VI.Interaction.Answer", function(ent_class)
    PD.IA.AddEntityActions(PD.IA.VI.Interactions[ent_class], "")
end)