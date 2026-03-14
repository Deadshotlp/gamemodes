PD.Binds = PD.Binds or {}
PD.Binds.List = {}

PD.Binds = PD.Binds or {}

PD.Binds.btn = {}
PD.Binds.btn["ansicht"] = {
    name = "Ansicht",
    desc = "Wechselt die Spieler Ansicht.",
    category = "Allgemein",
    defaultkey = KEY_T,
    downFunc = function()
        PD.FOV.thirdPerson = not PD.FOV.thirdPerson
    end,
    upFunc = function()
    end,
    holdFunc = function()
    end
}

PD.Binds.btn["mouse"] = {
    name = "Maus anzeigen",
    desc = "Zeigt oder versteckt die Maus im Spiel.",
    category = "Allgemein",
    defaultkey = KEY_NONE,
    downFunc = function()
        if not IsFirstTimePredicted() then
            return
        end

        if vgui.CursorVisible() then
            gui.EnableScreenClicker(false)
        else
            gui.EnableScreenClicker(true)
        end
    end,
    upFunc = function()
    end,
    holdFunc = function()
    end
}

PD.Binds.btn["arccw_fire"] = {
    name = "Feuermodus wechseln",
    desc = "Wechselt den Feuermodus der Waffe.",
    category = "Waffen",
    defaultkey = KEY_G,
    downFunc = function()
        RunConsoleCommand("arccw_firemode", nil)
    end,
    upFunc = function()
    end
}

PD.Binds.btn["arccw_toggle"] = {
    name = "Waffenanpassung öffnen",
    desc = "Öffnet das Waffenanpassungsmenü.",
    category = "Waffen",
    defaultkey = KEY_C,
    downFunc = function()
        RunConsoleCommand("arccw_toggle_inv", nil)
    end,
    upFunc = function()
    end
}

PD.Binds.btn["self_interaction"] = {
    name = "Selbstinteraktion",
    desc = "Interagiert mit sich selbst.",
    category = "Interaktionen",
    defaultkey = KEY_NONE,
    downFunc = function()
    end,
    upFunc = function()
    end,
    holdFunc = function()
        -- PD.IA.SelfInteraction()
    end
}

PD.Binds.btn["other_interaction"] = {
    name = "Andere Interaktion",
    desc = "Interagiert mit anderen Spielern oder Objekten.",
    category = "Interaktionen",
    defaultkey = KEY_NONE,
    downFunc = function()
    end,
    upFunc = function()
    end,
    holdFunc = function()
        -- PD.IA.OtherInteraction()
    end
}

PD.Binds.btn["character"] = {
    name = "Charaktermenü",
    desc = "Öffnet das Charaktermenü.",
    defaultkey = KEY_F6,
    downFunc = function()
        net.Start("PD.Char.Syncsv")
        net.SendToServer()

        timer.Simple(0.5, function()
            PD.Char:Menu(true)
        end)
    end,
    upFunc = function()
    end
}

PD.Binds.btn["comlink_open"] = {
    name = "Comlink öffnen",
    desc = "Öffnet das Comlink-Menü.",
    category = "Comlink",
    defaultkey = KEY_H,
    downFunc = function()
        PD.Comlink:Menu()
    end,
    upFunc = function()
    end
}

PD.Binds.btn["chat_open"] = {
    name = "Funk öffnen",
    desc = "Öffnet das Funk-Menü.",
    category = "Chat",
    defaultkey = KEY_NONE,
    downFunc = function()
        RunConsoleCommand("pd_funk_open")
    end,
    upFunc = function()
    end
}

PD.Binds.btn["comlink_extra1"] = {
    name = "Funk Kanal 1",
    desc = "Wechselt zu Funk Kanal 1.",
    category = "Comlink",
    defaultkey = KEY_NONE,
    downFunc = function()
    end,
    upFunc = function()
    end
}

PD.Binds.btn["comlink_extra2"] = {
    name = "Funk Kanal 2",
    desc = "Wechselt zu Funk Kanal 2.",
    category = "Comlink",
    defaultkey = KEY_NONE,
    downFunc = function()
    end,
    upFunc = function()
    end
}

PD.Binds.btn["comlink_extra3"] = {
    name = "Funk Kanal 3",
    desc = "Wechselt zu Funk Kanal 3.",
    category = "Comlink",
    defaultkey = KEY_NONE,
    downFunc = function()
    end,
    upFunc = function()
    end,
    holdFunc = function()
    end
}

PD.Binds.btn["open_medical_interface"] = {
    name = "Medizinische Schnittstelle öffnen",
    desc = "Öffnet die medizinische Schnittstelle.",
    category = "Medizin",
    defaultkey = KEY_NONE,
    admin = false,
    downFunc = function()
        PD.DM:OpenInterface()
    end,
    upFunc = function()
    end,
    holdFunc = function()
    end
}

PD.Binds.btn["open_squad_management"] = {
    name = "Squad Verwaltung öffnen",
    desc = "Öffnet die Squad Verwaltungsoberfläche.",
    category = "Squad",
    defaultkey = KEY_NONE,
    admin = false,
    downFunc = function()
        PD.SQUAD:OpenInterface()
    end,
    upFunc = function()
    end,
    holdFunc = function()
    end
}

PD.Binds.btn["change_voice_range"] = {
    name = "Stimmreichweite ändern",
    desc = "Ändert die Reichweite der Stimme.",
    category = "Allgemein",
    defaultkey = KEY_NONE,
    admin = false,
    downFunc = function()
        PD.VC:Change()
    end,
    upFunc = function()
    end,
    holdFunc = function()
    end
}
PD.Binds.btn["change_voice_range_indicator"] = {
    name = "Stimmreichweite Anzeigen",
    desc = "Zeigt die Reichweite der Stimme an.",
    category = "Allgemein",
    defaultkey = KEY_NONE,
    admin = false,
    downFunc = function()
        PD.VC:Start_ShowIndicator()
    end,
    upFunc = function()
        PD.VC:Stop_ShowIndicator()
    end,
    holdFunc = function()
    end
}

PD.Binds.btn["adminmenu"] = {
    name = "Admin Menü öffnen",
    desc = "Öffnet das Admin Menü.",
    category = "Admin",
    defaultkey = KEY_NONE,
    admin = true,
    downFunc = function()
        PD.Admin:Menu()
    end,
    upFunc = function()
    end,
    holdFunc = function()
    end
}

function PD.Binds:AddBind(id, name, help, category, default, admin, func, func2, func3)
    if not admin then
        admin = false
    end

    local newBind = {}
    newBind.Name = name
    newBind.Help = help
    newBind.Category = category
    newBind.DefaultKey = default
    newBind.Admin = admin
    newBind.Function = func
    newBind.Key = default
    newBind.FunctionUp = func2 or function()
    end
    newBind.FunctionHold = func3 or function()
    end

    self.List[id] = newBind
end

function PD.Binds:FindBindToKey(key)
    for k, v in pairs(self.List) do
        if input.GetKeyName(v.Key) == input.GetKeyName(key) then
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
    local json = util.TableToJSON(savetable, true)
    file.Write("progama057_binds.json", json)
end

function PD.Binds:LoadBindsFromData()
    if file.Exists("progama057_binds.json", "DATA") then
        local json = file.Read("progama057_binds.json", "DATA")
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
        if not v.category then
            v.category = "Allgemein"
        end

        PD.Binds:AddBind(k, v.name, v.desc, v.category, v.defaultkey, v.admin, v.downFunc, v.upFunc, v.holdFunc)
    end

    timer.Simple(1, function()
        if not file.Exists("progama057_binds.json", "DATA") then
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

local radius = PD.H(15)

local function getCategoryBinds(category)
    local tbl = {}
    for k, v in pairs(PD.Binds.List) do
        if v.Category == category then
            tbl[k] = v
        end
    end
    return tbl
end

function PD.Binds:Menu()
    if IsValid(self.base) then
        return
    end

    self.base = PD.Frame("Tastenbelegung", PD.W(600), PD.H(800), true)

    local save = PD.Button("Speichern", self.base, function()
        PD.Binds:SaveBinds()

        self.base:Remove()
    end)
    save:Dock(BOTTOM)
    save:SetTall(PD.H(50))
    -- save:SetRadius(radius)

    local reset = PD.Button("Zurücksetzen", self.base, function()
        for k, v in pairs(PD.Binds.List) do
            v.Key = v.DefaultKey
        end

        self.base:Remove()
        PD.Binds:Menu()
    end)
    reset:Dock(BOTTOM)
    reset:SetTall(PD.H(50))
    -- reset:SetRadius(radius)

    scrl = PD.Scroll(self.base)

    local categories = {}
    for k, v in pairs(self.List) do
        categories[v.Category] = true
    end

    for category, _ in pairs(categories) do
        local catLabel = PD.Label(category, scrl)
        catLabel:Dock(TOP)
        catLabel:SetTall(PD.H(30))
        catLabel:DockMargin(PD.W(5), PD.H(10), PD.W(5), PD.H(5))
        catLabel:SetFont("MLIB.30")
        catLabel:SetColor(Color(255, 255, 255))

        local binds = getCategoryBinds(category)
        for k, v in SortedPairs(binds) do
            local pnl = PD.Panel(scrl, {}--{title = v.Name}--)
            , function(self, w, h)
                draw.DrawText(v.Name, "MLIB.25", PD.W(10), PD.H(5), Color(255, 255, 255), TEXT_ALIGN_LEFT)

                local text = markup.Parse("<font=MLIB.20>" .. v.Help .. "</font>", PD.W(350))
                text:Draw(PD.W(10), PD.H(35), TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
            end)
            pnl:SetTall(PD.H(70))

            local pnlreset = PD.Button("Zurücksetzen", pnl, function()
                v.Key = v.DefaultKey
                self.base:Remove()
                PD.Binds:Menu()
            end)
            pnlreset:Dock(RIGHT)
            pnlreset:SetWide(PD.W(100))
            -- pnlreset:SetRadius(radius)

            local bpnl, binder = PD.Binder(pnl, "", v.Key, function(self, key)
                v.Key = key
            end)
            bpnl:Dock(RIGHT)
            bpnl:SetWide(PD.W(100))
        end
    end
end

local toggle = false
function PD.Binds:DeactivateBinds()
    toggle = true
end

function PD.Binds:ActivateBinds()
    toggle = false
end

hook.Add("PlayerButtonDown", "BindMenuPlayerButtonDown", function(ply, button)
    if toggle then return end

    if not (IsFirstTimePredicted()) then
        return
    end

    local bind = PD.Binds:FindBindToKey(button)
    if bind then
        if bind.Admin and not ply:IsAdmin() then
            return
        end

        bind.Function()
    end

    if button == KEY_F3 then
        gui.EnableScreenClicker(false)
    end
end)

hook.Add("PlayerButtonUp", "BindMenuPlayerButtonDownUP", function(ply, button)
    if toggle then return end
   
    if (IsFirstTimePredicted()) then
        return
    end
    local bind = PD.Binds:FindBindToKey(button)
    if bind then
        bind.FunctionUp()
    end

    if button == KEY_F3 then
        gui.EnableScreenClicker(false)
    end
end)

hook.Add("Think", "BindMenuPlayerButtonHold", function()
    local ply = LocalPlayer()
    for k, v in pairs(PD.Binds.List) do
        if input.IsKeyDown(v.Key) then
            v.FunctionHold()
        end
    end
end)

concommand.Add("pd_binds_prints", function()
    for k, v in pairs(PD.Binds.List) do
        print(k .. " : " .. v.Key)
    end
end)