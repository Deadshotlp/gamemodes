PD.VehicalInventory = PD.VehicalInventory or {}
PD.VehicalInventory.vehicals = {
    -- [ent] = {
    --     cargo_slots = 1,
    --     cargo_space = {
    --         [1] = {
    --             ent_class = "",
    --             owner = "",
    --             amount = 1
    --         }
    --     },
    --     players_looking = {steamid64, }
    -- }
}


util.AddNetworkString("PD.VehicalInventory.ChangeState")
util.AddNetworkString("PD.VehicalInventory.StartRequestItems")
util.AddNetworkString("PD.VehicalInventory.UpdateRequestItems")
util.AddNetworkString("PD.VehicalInventory.EndRequestItems")

net.Receive("PD.VehicalInventory.StartRequestItems", function(ply)
    local ent = net.ReadEntity()

    if ply:GetPos():Distance(ent:GetPos()) >= 100 then return end

    local tbl

    if IsValid(PD.VehicalInventory.vehicals.ent) then
        table.insert(PD.VehicalInventory.vehicals.ent.players_looking, ply:SteamID64())

        tbl = PD.VehicalInventory.vehicals.ent
    else
        PD.VehicalInventory.vehicals.ent = {
            cargo_slots = 1,
            cargo_space = {
                [1] = {
                    ent_class = "",
                    owner = "",
                    amount = 1
                }
            },
        players_looking = {ply:SteamID64()}
        }

        tbl = PD.VehicalInventory.vehicals.ent
    end

    net.Start("PD.VehicalInventory.UpdateRequestItems")
    net.WriteTable(PD.VehicalInventory.vehicals.ent)
    net.Send(ply)
end)