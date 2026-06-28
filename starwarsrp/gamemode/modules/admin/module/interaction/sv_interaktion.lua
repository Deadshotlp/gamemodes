PD.IA = PD.IA or {}

net.Receive("PD.IA.RequestInteractionTbl", function(len, ply)

    if not IsValid(ply) or not ply:IsAdmin() then
        return
    end

    local tbl = PD.IA.Objects

    net.Start("PD.IA.SendInteractionTbl")
    net.WriteTable(tbl)
    net.Send(ply)
end)
