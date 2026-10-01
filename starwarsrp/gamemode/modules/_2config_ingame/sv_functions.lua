PD.Config = PD.Config or {}
-- PD.Config.Table = {}


function PD.Config:Load()
    PD.JSON.Create("modules/config")

    PD.Config.Table = PD.JSON.Read("modules/config/settings.json")
end

function PD.Config:Save()
    PD.JSON.Write("modules/config/settings.json", PD.Config.Table)
end

hook.Add("Initialize", "PD.Config.Load", function()
    PD.Config:Load()
end)

hook.Add("ShutDown", "PD.Config.Save", function()
    PD.Config:Save()
end)

