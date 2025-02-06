--

PD = PD or {}
CONFIG = CONFIG or {}

function GM:Initialize()
	-- Do stuff
end

CONFIG.BackModel = "models/player/skeleton.mdl"

PD.Developer = true

PD.Admin = PD.Admin or {}

PD.Admin.Ranks = {
    ["superadmin"] = 3,
    ["admin"] = 2,
    ["moderator"] = 1,
    ["user"] = 0
}

PD.Admin.Equip = {
    ["PhysGun"] = "weapon_physgun",
    ["ToolGun"] = "gmod_tool",
    ["Hands"] = "mhands"
}

PD.Admin.PayDayPercent = {
    ["superadmin"] = 5,
    ["admin"] = 2,
    ["moderator"] = 2,
    ["user"] = 1
}

PD.Admin.Slots = {
    ["superadmin"] = 5,
    ["admin"] = 4,
    ["moderator"] = 3,
    ["user"] = 2
}