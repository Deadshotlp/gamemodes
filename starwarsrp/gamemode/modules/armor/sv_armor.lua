PD.Armor = PD.Armor or {}

util.AddNetworkString("PD.Armor:Respawn")
util.AddNetworkString("PD.Armor:PlayerArmor")
util.AddNetworkString("PD.Armor:UpdatePlayerArmor")

local playerArmorTable = {}

local function SetPlayerArmor(ply)
    local bodyGroups = ply:GetBodyGroups()

    local bodyIds = {
        [1] = 1, -- Panzer / models/fisher/parts/chestplate.mdl
        [2] = 1, -- Beine / models/fisher/parts/left_foot.mdl / models/fisher/parts/right_foot.mdl
        [3] = 2 -- Helm / models/fisher/parts/helmet.mdl
    }

    for k, v in pairs(bodyGroups) do 
        if bodyIds[v.id] then
            ply:SetBodygroup(v.id, bodyIds[v.id])
        else
            ply:SetBodygroup(v.id, 0)
        end
    end
end

hook.Add("PlayerChangedChar", "PD.Armor.PlayerChangedChar", function(ply)
    SetPlayerArmor(ply)
end)

hook.Add("PlayerSpawn", "PD.Armor.PlayerSpawn", function(ply)
    SetPlayerArmor(ply)
end)

-- Funktion, die prüft, ob der Treffer ein Kopftreffer ist
hook.Add("EntityTakeDamage", "CheckHeadshot", function(target, dmgInfo)
    if not target:IsPlayer() then return end

    local attacker = dmgInfo:GetAttacker()
    if not IsValid(attacker) then return end
    if not (dmgInfo:IsBulletDamage()) then return end

    local hitGroup = target:LastHitGroup()

    if hitGroup == HITGROUP_HEAD then
        print("Kopftreffer!")
        
        local damage = dmgInfo:GetDamage()

        if target:PDGetArmor().helm then
            local armor = target:PDGetArmor().helm

            if armor >= damage then
                target:PDSetArmor(3, armor - damage)
                return
            end

            target:PDRemoveArmor(3)
            damage = damage - armor
        end
    elseif hitGroup == HITGROUP_CHEST then
        print("Brusttreffer!")

        local damage = dmgInfo:GetDamage()

        if target:PDGetArmor().panzer then
            local armor = target:PDGetArmor().panzer

            if armor >= damage then
                target:PDSetArmor(1, armor - damage)
                return
            end

            target:PDRemoveArmor(1)
            damage = damage - armor
        end
    elseif hitGroup == HITGROUP_LEFTLEG or hitGroup == HITGROUP_RIGHTLEG then
        print("Beintreffer!")

        local damage = dmgInfo:GetDamage()

        if target:PDGetArmor().beine then
            local armor = target:PDGetArmor().beine

            if armor >= damage then
                target:PDSetArmor(2, armor - damage)
                return
            end

            target:PDRemoveArmor(2)
            damage = damage - armor
        end
    end
end)

net.Receive("PD.Armor:Respawn", function(len, ply)
    SetPlayerArmor(ply)
end)

net.Receive("PD.Armor:PlayerArmor", function(len, ply)
    local armor = net.ReadInt(8)

    if not playerArmorTable[ply] then
        playerArmorTable[ply] = {}
    end
    
    if armor == 1 then
        playerArmorTable[ply].panzer = true
    elseif armor == 2 then
        playerArmorTable[ply].beine = true
    elseif armor == 3 then
        playerArmorTable[ply].helm = true
    end


end)

PLAYER = FindMetaTable("Player")
function PLAYER:PDSetArmor(typ, armor)
    if not playerArmorTable[self] then
        playerArmorTable[self] = {}
    end

    if typ == 1 then
        playerArmorTable[self].panzer = armor
    elseif typ == 2 then
        playerArmorTable[self].beine = armor
    elseif typ == 3 then
        playerArmorTable[self].helm = armor
    end

    net.Start("PD.Armor:UpdatePlayerArmor")
        net.WriteInt(typ, 32)
        net.WriteInt(armor, 32)
    net.Send(self)
end

function PLAYER:PDGetArmor()
    return playerArmorTable[self]
end

function PLAYER:PDRemoveArmor(typ)
    if not playerArmorTable[self] then return end

    if typ == 1 then
        playerArmorTable[self].panzer = 0
    elseif typ == 2 then
        playerArmorTable[self].beine = 0
    elseif typ == 3 then
        playerArmorTable[self].helm = 0
    end
end