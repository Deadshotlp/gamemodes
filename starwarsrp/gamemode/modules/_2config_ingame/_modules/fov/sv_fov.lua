-- 

hook.Add("PlayerShouldTaunt", "SV_FOV_PlayerShouldTaunt", function(ply, act)
    ply:DoAnimationEvent( act )

    return false
end)