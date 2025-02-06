PD.Binds = PD.Binds or {}
PD.Binds.List = {}

PD.Binds = PD.Binds or {}

PD.Binds.btn = {}
PD.Binds.btn["ansicht"] = {
    name = "Ansicht",
    desc = "Wechselt die Spieler Ansicht",
    defaultkey = KEY_T,
    downFunc = function() RunConsoleCommand("stp") end,
    upFunc = function() end
}

PD.Binds.btn["mouse"] = {
    name = "Mauszeiger",
    desc = "Aktiert den Mauszeiger",
    defaultkey = KEY_NONE,
    downFunc = function() if vgui.CursorVisible() then gui.EnableScreenClicker(false) else gui.EnableScreenClicker(true) end end,
    upFunc = function() end
}

PD.Binds.btn["arccw_fire"] = {
    name = "Feuermodus",
    desc = "Wechselt den Feuermodus",
    defaultkey = KEY_G,
    downFunc = function() RunConsoleCommand("arccw_firemode", nil) end,
    upFunc = function() end
}


PD.Binds.btn["arccw_toggle"] = {
    name = "Waffenmenü",
    desc = "Öffnet das Waffenmenü",
    defaultkey = KEY_C,
    downFunc = function() RunConsoleCommand("arccw_toggle_inv", nil) end,
    upFunc = function() end
}


-- PD.Binds.btn["handsanima"] = {
--     name = "",
--     desc = "",
--     defaultkey = KEY_,
--     downFunc = function() end,
--     upFunc = function() end
-- }

-- PD.Binds.btn["character"] = {
--     name = "",
--     desc = "",
--     defaultkey = KEY_,
--     downFunc = function() end,
--     upFunc = function() end
-- }

-- PD.Binds.btn["characteradmin"] = {
--     name = "",
--     desc = "",
--     defaultkey = KEY_,
--     downFunc = function() end,
--     upFunc = function() end
-- }

-- PD.Binds.btn["factions"] = {
--     name = "",
--     desc = "",
--     defaultkey = KEY_,
--     downFunc = function() end,
--     upFunc = function() end
-- }

-- PD.Binds.btn["jobs"] = {
--     name = "",
--     desc = "",
--     defaultkey = KEY_,
--     downFunc = function() end,
--     upFunc = function() end
-- }

-- PD.Binds.btn["logs"] = {
--     name = "",
--     desc = "",
--     defaultkey = KEY_,
--     downFunc = function() end,
--     upFunc = function() end
-- }

-- PD.Binds.btn["waffenkiste"] = {
--     name = "",
--     desc = "",
--     defaultkey = KEY_,
--     downFunc = function() end,
--     upFunc = function() end
-- }

-- PD.Binds.btn["warn"] = {
--     name = "",
--     desc = "",
--     defaultkey = KEY_,
--     downFunc = function() end,
--     upFunc = function() end
-- }

PD.Binds.btn["comlink"] = {
    name = "Comlink",
    desc = "Öffnet das Comlink Menü",
    defaultkey = KEY_H,
    downFunc = function() PD.Comlink:Menu() end,
    upFunc = function() end
}


function PD.Binds:AddBind(id, name, help, default, func, func2)
    local newBind = {}
    newBind.Name = name
    newBind.Help = help
    newBind.DefaultKey = default
    newBind.Function = func
    newBind.Key = default
    newBind.FunctionUp = func2 or function() end
    self.List[id] = newBind
end

function PD.Binds:FindBindToKey(key)
    for k, v in pairs(self.List) do
        if v.Key == key then
            return v
        end
    end
    return false
end

function PD.Binds:FindBindByID(id)
    return self.List[id].Key 
end

function PD.Binds:SaveBinds()
    local savetable = {}
    for k, v in pairs(self.List) do
        savetable[k] = v.Key
    end
    local json = util.TableToJSON(savetable,true)
    file.Write( "progama057_binds.json", json) 
end

function PD.Binds:LoadBindsFromData()
    if file.Exists( "progama057_binds.json", "DATA" ) then
        local json = file.Read( "progama057_binds.json", "DATA" )
        local bindtable = util.JSONToTable(json)
        for k, v in pairs(bindtable) do
            if PD.Binds.List[k] then
                PD.Binds.List[k].Key = v
            end
        end
    end
end

local function load()
    for k, v in SortedPairs(PD.Binds.btn) do
        PD.Binds:AddBind(k, v.name, v.desc, v.defaultkey, v.downFunc, v.upFunc)
    end

    timer.Simple(1, function() 
        if !file.Exists( "progama057_binds.json", "DATA" ) then
            PD.Binds:SaveBinds()
        else   
            PD.Binds:LoadBindsFromData()
        end
    end)
end

hook.Add("InitPostEntity", "bindsload", function()
    load()
end)
load()

function PD.Binds:Menu()
    if IsValid(self.base) then return end

    self.base = PG.Frame("Bind-Menu",PG.W(600),PG.H(800),true)

    local save = PG.Button("Speichern",self.base,function()
        PD.Binds:SaveBinds()

        self.base:Remove()
    end)
    save:Dock(BOTTOM)

    local reset = PG.Button("Reset",self.base,function()
        for k, v in pairs(PD.Binds.List) do
            v.Key = v.DefaultKey
        end

        self.base:Remove()
        PD.Binds:Menu()
    end)
    reset:Dock(BOTTOM)

    scrl = PG.Scroll(self.base)

    for k,v in SortedPairs(self.List) do
        local pnl = PG.Panel("",scrl,function(self,w,h)
            draw.DrawText(v.Name,"MLIB.25",10,5,Color(255,255,255),TEXT_ALIGN_LEFT)

            local text = markup.Parse("<font=MLIB.20>"..v.Help.."</font>",PG.W(350))
            text:Draw(10,35,TEXT_ALIGN_LEFT,TEXT_ALIGN_TOP)
        end)
        --local h = PG.H(35) + markup.Parse("<font=MLIB.20>"..v.Help.."</font>",PG.W(350)):GetHeight()
        pnl:SetTall(PG.H(70))

        local pnlreset = PG.Button("Reset",pnl,function()
            v.Key = v.DefaultKey
            self.base:Remove()
            PD.Binds:Menu()
        end)
        pnlreset:Dock(RIGHT)

        local bpnl, binder = PG.Binder(pnl,"",v.Key,function(self, key)
            v.Key = key
        end)
        bpnl:Dock(RIGHT)
        bpnl:SetWide(PG.W(100))
        

    end
end

hook.Add( "PlayerButtonDown", "BindMenuPlayerButtonDown", function( ply, button )
    if ( !IsFirstTimePredicted() ) then return end
    local bind = PD.Binds:FindBindToKey(button)
    if bind then
        bind.Function()
    end

    if button == KEY_F3 then
        gui.EnableScreenClicker(false)
    end
end)

hook.Add( "PlayerButtonUp", "BindMenuPlayerButtonDownUP", function( ply, button )
    if ( !IsFirstTimePredicted() ) then return end
    local bind = PD.Binds:FindBindToKey(button)
    if bind then
        bind.FunctionUp()
    end

    if button == KEY_F3 then
        gui.EnableScreenClicker(false)
    end
end)



