PD.Inventar_Alt = PD.Inventar_Alt or {}

PD.Inventar_Alt.Inventory = nil -- {
-- [ply:SteamID64()] = {
--     [ply:Nick()] = {
--         primaer_waffe = "DC-15s",
--         sekundaer_waffe = "DC-17",
--         spezial_waffe = "RPS-6",
--         uniform = {
--              max_weight = 1000 (in gram)
--              ["Item_Name"] = {amount = 1, weight = 10 (in gram)} 
--         },
--         rucksack = {
--              max_weight = 10000
--              ["Item_Name"] = {amount = 1, weight = 10} 
--         },
--     },
--     [ply:Nick()] = {

--     }
-- }
-- }

util.AddNetworkString("PD.Inventar_Alt.OpenInventory")

function PD.Inventar_Alt:UpdateTable(ply, key, value)
    PD.Inventar_Alt.Inventory[ply:SteamID64()][ply:Nick()][key] = value
end

function PD.Inventar_Alt:RequestTable(ply, key)
    return PD.DInventar_AltM.Inventory[ply:SteamID64()][ply:Nick()][key]
end

hook.Add("PlayerSetCharacter", "PD.Inventar_Alt.LoadingInventory", function(ply)
    if not PD.Inventar_Alt.Inventory[ply:SteamID64()] then
        PD.Inventar_Alt.Inventory[ply:SteamID64()] = {}
    end
    if not PD.Inventar_Alt.Inventory[ply:SteamID64()][ply:Nick()] then
        local bodyGroups = ply:GetBodyGroups()
        local bodyGroup = ply:FindBodygroupByName("Backpack") + 1

        PD.Inventar_Alt.Inventory[ply:SteamID64()][ply:Nick()] = {
            primaer_waffe = "masita_dc15s" or nil,
            sekundaer_waffe = "masita_dc17" or nil,
            spezial_waffe = "arccw_sw_rocket_rps6" or nil,
            uniform = {
                max_weight = 1000
            },
            rucksack = nil
        }

        if bodyGroup and bodyGroups[bodyGroup].submodels[ply:GetBodygroup(bodyGroup)] ~= "empty" then
            PD.Inventar_Alt.Inventory[ply:SteamID64()][ply:Nick()]["rucksack"] = {
                max_weight = 10000
            }
        end
    end
end)

hook.Add("PlayerDisconnected", "4684874181d64a4w1d684aw6d486aw41d6", function(ply)
    PD.Inventar_Alt.Inventory[ply:SteamID64()] = nil
end)

hook.Add("BodygroupChanged", "PD.Inventar_Alt.CheckForBackpack", function(ply, bodygroup, value)
    if not bodygroup == ply:FindBodygroupByName("Backpack") then
        return
    end

    if value == 0 then
        PD.Inventar_Alt:UpdateTable(ply, "rucksack", nil)
    else
        PD.Inventar_Alt:UpdateTable(ply, "rucksack", {
            max_weight = 10000
        })
    end
end)

hook.Add("PlayerButtonUp", "PD.Inventar_Alt.Open", function(ply, button)
    if not ply:IsAdmin() then
        return
    end

    if button == KEY_F11 then
        PD.Inventar_Alt.OpenInventory(ply)
        return
    end
end)

function PD.Inventar_Alt.OpenInventory(ply)
    local tbl = PD.Inventar_Alt.Inventory[ply:SteamID64()][ply:Nick()]
    net.Start("PD.Inventar_Alt.OpenInventory")
    net.WriteTable(tbl)
    net.Send(ply)
end

if PD.Inventar_Alt.Inventory == nil then
    PD.Inventar_Alt.Inventory = {}
    for _, ply in player.Iterator() do
        if not PD.Inventar_Alt.Inventory[ply:SteamID64()] then
            PD.Inventar_Alt.Inventory[ply:SteamID64()] = {}
        end
        if not PD.Inventar_Alt.Inventory[ply:SteamID64()][ply:Nick()] then
            local bodyGroups = ply:GetBodyGroups()
            local bodyGroup = ply:FindBodygroupByName("Backpack") + 1

            PD.Inventar_Alt.Inventory[ply:SteamID64()][ply:Nick()] = {
                primaer_waffe = "masita_dc15s" or nil,
                sekundaer_waffe = "masita_dc17" or nil,
                spezial_waffe = "arccw_sw_rocket_rps6" or nil,
                uniform = {
                    max_weight = 1000
                },
                rucksack = nil
            }

            -- if bodyGroup and bodyGroups[bodyGroup].submodels[ply:GetBodygroup(bodyGroup)] ~= "empty" then
            --     PD.Inventar_Alt.Inventory[ply:SteamID64()][ply:Nick()]["rucksack"] = {
            --         max_weight = 10000
            --     }
            -- end
        end
    end
end
