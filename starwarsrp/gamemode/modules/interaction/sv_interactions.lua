PD.IA = PD.IA or {}
PD.IA.Models = {
    ["player"] = {
        bones = {
            [1] = {
                name = "ValveBiped.Bip01_Head1",
                interactions = {
                    groups = "general,medic",
                    additional = {
                        -- [1] = {
                        --     id = "test",
                        --     name = "test",
                        --     icon = nil,
                        --     func = nil
                        -- }
                    }
                }
            },
            [2] = {
                name = "ValveBiped.Bip01_Spine",
                interactions = {
                    groups = "general,medic",
                    additional = {
                        -- [1] = {
                        --     id = "medical_interface",
                        --     name = "Open Medical Interface",
                        --     icon = "symbol4", -- Material("icons/symbol4.png"),
                        --     func = nil
                        -- }
                    }
                }
            },
            [3] = {
                name = "ValveBiped.Bip01_L_Forearm",
                interactions = {
                    groups = "general,medic",
                    additional = {}
                }
            },
            [4] = {
                name = "ValveBiped.Bip01_R_Forearm",
                interactions = {
                    groups = "general,medic",
                    additional = {}
                }
            },
            [5] = {
                name = "ValveBiped.Bip01_L_Calf",
                interactions = {
                    groups = "general,medic",
                    additional = {}
                }
            },
            [6] = {
                name = "ValveBiped.Bip01_R_Calf",
                interactions = {
                    groups = "general,medic",
                    additional = {}
                }
            }
        }
    }
}

util.AddNetworkString("PD.IA.RequestEntityInformation")
util.AddNetworkString("PD.IA.SendEntityInformation")
util.AddNetworkString("PD.IA.RequestStartInteraction")
util.AddNetworkString("PD.IA.SendStartInteraction")

local function search_entity(ent1)
    local tbl = {
        ent = ent1,
        model = ent1:GetModel(),
        bones = nil
    }

    for k, v in pairs(PD.IA.Models[ent1:GetClass()]) do
        if v.model and v.model == tbl.model then
            tbl.bones = v.bones
        elseif k == "bones" then
            tbl.bones = v
        end
    end

    return tbl
end

net.Receive("PD.IA.RequestEntityInformation", function()
    local ply = net.ReadEntity()
    local ent_request = net.ReadEntity()

    local ent_send = search_entity(ent_request)

    net.Start("PD.IA.SendEntityInformation")
    net.WriteTable(ent_send)
    net.Send(ply)
end)

net.Receive("PD.IA.RequestStartInteraction", function()
    local ply = net.ReadEntity()
    local ent_request = net.ReadEntity()

    net.Start("PD.IA.SendStartInteraction")
    net.Send(ply)
end)
