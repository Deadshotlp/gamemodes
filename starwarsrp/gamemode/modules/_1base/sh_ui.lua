-- dd

function PD.Notify(msg, col, all, ply)
    if CLIENT then
        local pop = PD.Popup(msg, col)
    end

    if SERVER then 
        net.Start("PD.Notify")
        net.WriteString(msg)
        net.WriteColor(col)
        
        if all then
            net.Broadcast()
        else
            net.Send(ply)
        end
    end
end