-- Commands by Progama057

CONFIG:AddConfig("commands_adminteam", {
    type = "team",
    default = {["superadmin"] = true},
    category = "Commands",
    desc = "Admin Commands (/rok, /verlosung, /announce, /ankündigungen)"
})

CONFIG:AddConfig("commands_adminjobs", {
    type = "jobs",
    default = {},
    category = "Commands",
    desc = "Admin Commands (/rok, /verlosung, /announce, /ankündigungen)"
})

PD.Commands = PD.Commands or {}

PD.Commands.Table = {}
PD.Commands.Table["warn"] = {
    command = "warn",
    desc = "Warn a player",
    func = function()
        PD.Warn:Menu()
    end
}

