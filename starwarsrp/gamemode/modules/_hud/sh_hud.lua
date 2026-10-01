-- HUD by Mario

function PD.PlayerSichtbar(ply)
    if ply:GetRenderMode() == RENDERMODE_TRANSALPHA or ply:GetColor().a == 0 then
        return true
    end
    return false
end