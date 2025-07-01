PD.Money = PD.Money or {}
PD.Money.Tbl = PD.Money.Tbl or {}

timer.Create("PD.Money:GiveTimer", 600, 0, function()
    for k, v in pairs(player.GetAll()) do
        local jobID, jobTable = v:GetJob()
        local salary = jobTable.salary

        -- if not PD.Config.PayDayEnabled then
        --     return
        -- end

        if v:Nick() == "Unknown" then
            return
        end

        if PD.Admin.PayDayPercent[v:GetUserGroup()] then
            salary = salary * PD.Admin.PayDayPercent[v:GetUserGroup()]
        end

        v:PDAddMoney(salary)
        print("Gave " .. v:Nick() .. " " .. salary .. "€")
        PD.Notify(salary .. "€ Erhalten", Color(255,255,255), false, v)

        hook.Run("PD_Money_AddMoney", v, salary)
    end
end)

timer.Simple(1, function()
    PD.JSON.Create("money")
end)

gameevent.Listen("player_disconnect")
hook.Add("player_disconnect", "PD.Money:Save", function(data)
    PD.JSON.Write("money/all.json", PD.Money.Tbl)
end)

hook.Add("ShutDown", "PD.Money:Save", function()
    PD.JSON.Write("money/all.json", PD.Money.Tbl)
end)

util.AddNetworkString("PD.Money:Update")
hook.Add("PD_Money_AddMoney", "PD.Money:Save", function()
    net.Start("PD.Money:Update")
    net.WriteTable(PD.Money.Tbl)
    net.Broadcast()
end)

timer.Simple(1, function()
    PD.Money.Tbl = PD.JSON.Read("money/all.json")

    net.Start("PD.Money:Update")
    net.WriteTable(PD.Money.Tbl)
    net.Broadcast()
end)

local PLAYER = FindMetaTable("Player")
function PLAYER:PDGetMoney()
    if not PD.Money.Tbl[self:SteamID()] then
        PD.Money.Tbl[self:SteamID()] = 0
    end

    return PD.Money.Tbl[self:SteamID()]
end

function PLAYER:PDSetMoney(amount)
    if not PD.Money.Tbl[self:SteamID()] then
        PD.Money.Tbl[self:SteamID()] = 0
    end

    PD.Money.Tbl[self:SteamID()] = amount
end

function PLAYER:PDAddMoney(amount)
    if not PD.Money.Tbl[self:SteamID()] then
        PD.Money.Tbl[self:SteamID()] = 0
    end

    PD.Money.Tbl[self:SteamID()] = PD.Money.Tbl[self:SteamID()] + amount
end

function PLAYER:PDTakeMoney(amount)
    if not PD.Money.Tbl[self:SteamID()] then
        PD.Money.Tbl[self:SteamID()] = 0
    end

    PD.Money.Tbl[self:SteamID()] = PD.Money.Tbl[self:SteamID()] - amount
end

function PLAYER:PDCanAfford(amount)
    if not PD.Money.Tbl[self:SteamID()] then
        PD.Money.Tbl[self:SteamID()] = 0
    end

    return PD.Money.Tbl[self:SteamID()] >= amount
end

