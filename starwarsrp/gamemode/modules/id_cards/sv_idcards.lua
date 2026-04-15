PD.IDCards = PD.IDCards or {}

util.AddNetworkString("PD.IDCards:CheckID")

net.Receive("PD.IDCards:CheckID", function(len, ply)
    local target = net.ReadEntity()
    if not IsValid(target) then return end

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