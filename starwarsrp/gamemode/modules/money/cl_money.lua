PD.Money = PD.Money or {}
PD.Money.Tbl = PD.Money.Tbl or {}

net.Receive("PD.Money:Update", function()
    PD.Money.Tbl = net.ReadTable()
end)

local PLAYER = FindMetaTable("Player")
function PLAYER:PDGetMoney()
    if not PD.Money.Tbl[self:SteamID()] then
        PD.Money.Tbl[self:SteamID()] = 0
    end

    return PD.Money.Tbl[self:SteamID()]
end

function PLAYER:PDCanAfford(amount)
    if not PD.Money.Tbl[self:SteamID()] then
        PD.Money.Tbl[self:SteamID()] = 0
    end

    return PD.Money.Tbl[self:SteamID()] >= amount
end