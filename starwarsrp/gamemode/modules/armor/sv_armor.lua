PD.Armor = PD.Armor or {}

util.AddNetworkString("PD.Armor:Respawn")
util.AddNetworkString("PD.Armor:PlayerArmor")
util.AddNetworkString("PD.Armor:UpdatePlayerArmor")
util.AddNetworkString("PD.Armor:SyncArmor")

local playerArmorTable = {}
local num = 0

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

-- hook.Add("EntityTakeDamage", "CheckHeadshot", function(target, dmgInfo)
--     if not target:IsPlayer() then return end

--     local attacker = dmgInfo:GetAttacker()
--     if not IsValid(attacker) then return end
--     if not (dmgInfo:IsBulletDamage()) then return end

--     local hitGroup = target:LastHitGroup()
--     -- print(hitGroup)

--     if hitGroup == 1 then
--         print("Kopftreffer!")

--         local damage = dmgInfo:GetDamage()

--         if target:PDGetArmor().helm then
--             local armor = target:PDGetArmor().helm

--             if armor >= damage then
--                 target:PDSetArmor(3, armor - damage)
--                 return
--             end

--             target:PDRemoveArmor(3)
--             damage = damage - armor
--         end
--     elseif hitGroup == 2 then
--         print("Brusttreffer!")

--         local damage = dmgInfo:GetDamage()

--         if target:PDGetArmor().panzer then
--             local armor = target:PDGetArmor().panzer

--             if armor >= damage then
--                 target:PDSetArmor(1, armor - damage)
--                 return
--             end

--             target:PDRemoveArmor(1)
--             damage = damage - armor
--         end
--     elseif hitGroup == 6 or hitGroup == 7 then
--         print("Beintreffer!")

--         local damage = dmgInfo:GetDamage()

--         if target:PDGetArmor().beine then
--             local armor = target:PDGetArmor().beine

--             if armor >= damage then
--                 target:PDSetArmor(2, armor - damage)
--                 return
--             end

--             target:PDRemoveArmor(2)
--             damage = damage - armor
--         end
--     elseif hitGroup == 0 then
--         print("Körpertreffer!")

--         local damage = dmgInfo:GetDamage()
--         local num = math.random(1, 3) or 0

--         if num == 0 then
--             print("Armor NUM 0")
--         end

--         if target:PDGetArmor().panzer and num == 1 then
--             local armor = target:PDGetArmor().panzer

--             if armor >= damage then
--                 target:PDSetArmor(1, armor - damage)
--                 return
--             end

--             target:PDRemoveArmor(1)
--             damage = damage - armor
--         end

--         if target:PDGetArmor().beine and num == 2 then
--             local armor = target:PDGetArmor().beine

--             if armor >= damage then
--                 target:PDSetArmor(2, armor - damage)
--                 return
--             end

--             target:PDRemoveArmor(2)
--             damage = damage - armor
--         end

--         if target:PDGetArmor().helm and num == 3 then
--             local armor = target:PDGetArmor().helm

--             if armor >= damage then
--                 target:PDSetArmor(3, armor - damage)
--                 return
--             end

--             target:PDRemoveArmor(3)
--             damage = damage - armor
--         end
--     end
-- end)

function PD.Armor:CalculateArmor(ply, dmg, typ)

    local armor = ply:PDGetArmor()[typ]
    local damage = dmg:GetDamage()

    if armor >= damage then
        ply:PDSetArmor(typ, armor - damage)
        return
    end

    ply:PDRemoveArmor(typ)
    damage = damage - armor
end

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
    elseif armor == 4 then
        if playerArmorTable[ply].panzer and playerArmorTable[ply].panzer >= 1 then
            playerArmorTable[ply].panzer = 100
            print("Panzer aufgeladen!")
        else
            ply:ChatPrint("Du hast keinen Panzer angezogen!")
        end

        if playerArmorTable[ply].beine and playerArmorTable[ply].beine >= 1 then
            playerArmorTable[ply].beine = 100
            print("Beine aufgeladen!")
        else
            ply:ChatPrint("Du hast keine Beine angezogen!")
        end

        if playerArmorTable[ply].helm and playerArmorTable[ply].helm >= 1 then
            playerArmorTable[ply].helm = 100
            print("Helm aufgeladen!")
        else
            ply:ChatPrint("Du hast keinen Helm angezogen!")
        end
    end

    net.Start("PD.Armor:SyncArmor")
    net.WriteTable(playerArmorTable[ply])
    net.Send(ply)
end)

PLAYER = FindMetaTable("Player")
function PLAYER:PDSetArmor(typ, armor)

    if not playerArmorTable[self] then
        playerArmorTable[self] = {}
    end

    playerArmorTable[self][typ] = armor

    local num = 0

    if typ == "helm" then
        num = 3
    elseif typ == "panzer" then
        num = 1
    elseif typ == "beine" then
        num = 2
    end

    -- if typ == 1 then
    --     playerArmorTable[self].panzer = armor
    -- elseif typ == 2 then
    --     playerArmorTable[self].beine = armor
    -- elseif typ == 3 then
    --     playerArmorTable[self].helm = armor
    -- end

    net.Start("PD.Armor:UpdatePlayerArmor")
    net.WriteInt(num, 8)
    net.WriteInt(armor, 8)
    net.Send(self)
end

function PLAYER:PDGetArmor()
    if not playerArmorTable[self] then
        playerArmorTable[self] = {}
        playerArmorTable[self].panzer = 0
        playerArmorTable[self].beine = 0
        playerArmorTable[self].helm = 0
    end

    return playerArmorTable[self]
end

function PLAYER:PDRemoveArmor(typ)
    if not playerArmorTable[self] then
        return
    end

    playerArmorTable[self][typ] = 0

    local num = 0

    if typ == "helm" then
        num = 3
    elseif typ == "panzer" then
        num = 1
    elseif typ == "beine" then
        num = 2
    end

    -- if typ == 1 then
    --     playerArmorTable[self].panzer = 0
    -- elseif typ == 2 then
    --     playerArmorTable[self].beine = 0
    -- elseif typ == 3 then
    --     playerArmorTable[self].helm = 0
    -- end

    net.Start("PD.Armor:UpdatePlayerArmor")
    net.WriteInt(num, 8) --------- num stat typ
    net.WriteInt(0, 8)
    net.Send(self)
end
