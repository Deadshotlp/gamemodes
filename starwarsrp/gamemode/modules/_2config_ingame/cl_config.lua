PD.Config = PD.Config or {}
PD.Config.tbl = PD.Config.tbl or {}

PD.Config.modules = {}

local function load()
    if not file.Exists("modules/config/config.json", "DATA") then
        PD.Config.tbl = {}
    else
        PD.Config.tbl = util.JSONToTable(file.Read("modules/config/config.json", "DATA"))
    end

    PD.Config.modules = {}

    hook.Run("PD.Config.LoadModule")
end

local function save()
    if not file.IsDir("modules/config", "DATA") then
        file.CreateDir("modules/config")
    end

    file.Write("modules/config/config.json", util.TableToJSON(PD.Config.tbl))

    load()
end

local function reset()
    PD.Config.tbl = {}

    hook.Run("PD.Config.LoadModule")

    save()
end

local function reopen()
    mainFrameESC:Remove()
    PD.ESC:Menu()
    PD.Config.base:Remove()
    PD.Config:Menu()
end

function PD.Config:AddModule(name, menuFunc)
    table.insert(PD.Config.modules, {
        name = name,
        menu = menuFunc
    })
end

-- function PD.Config:Menu()
--     if IsValid(PD.Config.base) then
--         return
--     end

--     PD.Config.base = PD.Frame(LANG.ESC_CONFIG_TITLE, PD.W(700), PD.H(800), true)

--     local panel = PD.Panel("", PD.Config.base)
--     panel:Dock(FILL)

--     local sideTab = PD.SideTab(PD.Config.base, panel)
--     sideTab:Dock(LEFT)

--     -- PrintTable(PD.Config.modules)

--     for k, v in pairs(PD.Config.modules) do
--         PD.AddSideItem(v.name, v.menu)
--     end

--     PD.AddSideItem(LANG.GENERIC_SAVE, function()
--         save()

--         reopen()
--     end)

--     PD.AddSideItem(LANG.GENERIC_RESET, function()
--         reset()

--         reopen()
--     end)
-- end

-- timer.Simple(0.0001, function()
--     load()
-- end)

load()

hook.Add("PlayerDisconnected", "PD.Config.SaveOnDisconnect", function(ply)
    if ply == LocalPlayer() then
        save()
    end
end)
