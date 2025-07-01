PD.Armor = PD.Armor or {}

local playerArmorTable = {
    [LocalPlayer()] = {
        panzer = 0,
        beine = 0,
        helm = 0
    }
}
net.Receive("PD.Armor:UpdatePlayerArmor", function()
    local typ = net.ReadInt(8)
    local armor = net.ReadInt(8)

    print(typ)
    print(armor)

    if not playerArmorTable[LocalPlayer()] then
        playerArmorTable[LocalPlayer()] = {}
    end

    if typ == 1 then
        playerArmorTable[LocalPlayer()].panzer = armor
    elseif typ == 2 then
        playerArmorTable[LocalPlayer()].beine = armor
    elseif typ == 3 then
        playerArmorTable[LocalPlayer()].helm = armor
    end
end)

net.Receive("PD.Armor:SyncArmor", function()
    local tbl = net.ReadTable()
    playerArmorTable[LocalPlayer()] = tbl
end)

local function returnColor(armor)
    if armor >= 60 then
        return Color(0, 255, 0)
    elseif armor >= 30 then
        return Color(255, 255, 0)
    else
        local a = math.abs(math.sin(CurTime() * 2) * 255)

        return Color(255, 0, 0, a)
    end
end

hook.Add("HUDPaint", "PD.Armor:DrawHUDArmor", function()

    local ply = LocalPlayer()
    local armor = ply:PDGetArmor()
    local x, y = PD.W(10), ScrH() - PD.H(130)

    if not armor then
        return
    end

    -- draw.SimpleText("Helm: ", "MLIB.20", x, y, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    -- if armor.helm then
    --     draw.SimpleText(armor.helm .. "%", "MLIB.20", x + PD.W(60), y, returnColor(armor.helm), TEXT_ALIGN_LEFT,
    --         TEXT_ALIGN_TOP)
    -- end

    -- draw.SimpleText("Panzer: ", "MLIB.20", x, y + PD.H(20), Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    -- if armor.panzer then
    --     draw.SimpleText(armor.panzer .. "%", "MLIB.20", x + PD.W(60), y + PD.H(20), returnColor(armor.panzer),
    --         TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    -- end

    -- draw.SimpleText("Beine: ", "MLIB.20", x, y + PD.H(40), Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    -- if armor.beine then
    --     draw.SimpleText(armor.beine .. "%", "MLIB.20", x + PD.W(60), y + PD.H(40), returnColor(armor.beine),
    --         TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
    -- end

end)

PLAYER = FindMetaTable("Player")

function PLAYER:PDGetArmor()
    if not playerArmorTable[self] then
        return {
            helm = 0,
            panzer = 0,
            beine = 0
        }
    end

    return playerArmorTable[self]
end

