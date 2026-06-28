PD.VehicalInventory = PD.VehicalInventory or {}

PD.VehicalInventory.Interactions = {
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
            id = "open_inventory",
            name = "Öffne Fahrzeug Inventar",
            icon = nil,
            func = function(ply, ent, bone)
                net.Start("PD.VehicalInventory.StartRequestItems")
                net.WriteEntity(ent)
                net.SendToServer()

                PD.VehicalInventory.OpenInventory("Transporter")
            end,
            ad = {"static_prop"}
        },
    }
}

function PD.VehicalInventory.OpenInventory(name)
    if VehicalInventoryFrame then
        VehicalInventoryFrame:Remove()
    end

    VehicalInventoryFrame = PD.Frame(name .. " - Inventory", ScrW() / 1.25,ScrH() / 1.25, true)


    net.Receive("PD.VehicalInventory.UpdateRequestItems", function()
        local tbl = net.ReadTable()
    end)
end

hook.Add("PD.Interaction.Requested", "PD.VehicalInventory.Interaction.Answer", function(ent_class)
PD.IA.AddEntityActions(PD.VehicalInventory.Interactions[ent_class], "Fahrzeug Inventar")

end)