-- HUD by Mario

hook.Add("EntityTakeDamage", "DamageHandler", function(target, dmginfo)

end)

util.AddNetworkString("PD.WeaponSelector:SelectWeapon")

net.Receive("PD.WeaponSelector:SelectWeapon", function(len, p)
    if not IsValid(p) then return end

    -- Die Klasse statt des Listenindex: GetWeapons() muss auf Client und
    -- Server nicht dieselbe Reihenfolge haben, ein Index traf hier also
    -- gelegentlich eine andere Waffe als die angeklickte.
    local class = net.ReadString()
    if class == "" then return end

    -- Nur was der Spieler auch wirklich traegt.
    if not IsValid(p:GetWeapon(class)) then return end

    p:SelectWeapon(class)
end)

function SpawnMultipleProps()
    local propModel = "models/props_c17/oildrum001.mdl" --"models/props_c17/oildrum001.mdl"
    local spawnPos = Entity(3):GetPos() + Vector(0, 0, 100) -- Spawn-Position über dem Spieler

    -- for i = 1, 1000 do
    --     -- local prop = ents.Create("prop_physics")
    --     -- prop:SetModel(propModel)
    --     -- prop:SetPos(spawnPos + Vector(math.random(-100, 100), math.random(-100, 100), 0))
    --     -- prop:Spawn()

    --     local prop = ents.Create("npc_breen")
    --     prop:SetPos(spawnPos + Vector(math.random(-500, 500), math.random(-500, 500), 0))
    --     prop:Spawn()
    -- end

    -- timer.Simple(10, function()
        for i = 1, 1 do
            local prop = ents.Create("prop_physics")
            prop:SetModel(propModel)
            prop:SetPos(spawnPos)
            prop:Spawn()
        end
    -- end)
end

-- Rufe die Funktion zum Spawnen der Props auf
-- timer.Create("Blafedkfgsfgg",1,20,function()
--     SpawnMultipleProps()
-- end)