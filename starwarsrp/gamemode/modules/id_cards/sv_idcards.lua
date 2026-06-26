PD.IDCards = PD.IDCards or {}

util.AddNetworkString("PD.IDCards:CheckID")

local checkIDCooldown = {}

net.Receive("PD.IDCards:CheckID", function(len, ply)
    if not IsValid(ply) then return end

    local target = net.ReadEntity()
    if not IsValid(target) or not target:IsPlayer() then return end

    local steamid = ply:SteamID64()
    if checkIDCooldown[steamid] and CurTime() - checkIDCooldown[steamid] < 1 then return end
    checkIDCooldown[steamid] = CurTime()

    net.Start("PD.IDCards:CheckID")
    net.WriteEntity(ply)
    net.Send(target)
end)

local LevelTable = {
    [99] = {
        ""
    },
    [1] = {
        "Private",
        "Private First Class",
        "Specialist",
        "Lance Corporal",
        "Corporal"
    },
    [2] = {
        "Sergeant",
        "Staff Sergeant",
        "Master Sergeant"
    },
    [3] = {
        "Second Lieutenant",
        "First Lieutenant"
    },
    [4] = {
        "Captain",
        "Major"
    },
    [5] = {}
}