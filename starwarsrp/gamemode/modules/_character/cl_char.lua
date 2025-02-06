PD.Char = PD.Char or {}
PD.Char.Data = PD.Char.Data or {}

local scrw, scrh = ScrW(), ScrH()
local txt = ""

PD.Char.AdminData = {}
PD.Char.Data = {}

net.Receive("PD.Char.Synccl", function()
    PD.Char.Data = net.ReadTable()
end)

net.Receive("PD.Char.AdminSync", function()
    PD.Char.AdminData = net.ReadTable()
end)

net.Receive("PD.Char.Open", function()
    PD.Char:Menu()
end)

net.Receive("PD.Char.JobChange", function()
    local ply = net.ReadEntity()
    local jobID = net.ReadString()
    local jobTbl = net.ReadTable()

    ply:SetJob(jobID, jobTbl)
end)

local function Error(text, panel, time)
    local barStatus = 0
    local speedBar = 1
    local error = PD.Panel("", panel, function(self, w, h)
        barStatus = math.Clamp(barStatus + (speedBar / time) * FrameTime(), 0, 1)
        draw.RoundedBox(0, 0, 0, ScrW(), ScrH(), Color(22, 22, 22, 255))
        draw.RoundedBox(0, 0, 0, w * barStatus, 5, Color(255, 0, 0))

        draw.DrawText(text, "MLIB.25", w / 2, h / 2 - 12.5, CONFIG:GetConfig("textcolor"), TEXT_ALIGN_CENTER)
    end)
    error:Dock(NODOCK)
    error:SetSize(PD.W(800), PD.H(100))
    error:SetPos(scrw / 2 - error:GetWide() / 2, PD.H(50))

    timer.Simple(time + 0.2, function()
        error:Remove()
    end)
end

function PD.Char:Menu(close)
    if IsValid(CharBase) then
        return
    end

    if not close then
        close = false
    end

    CharBase = PD.Frame("", scrw, scrh, close, function(self, w, h)
        surface.SetDrawColor(255, 255, 255)
        surface.SetMaterial(Material(CONFIG:GetConfig("charakter_backgroundbild")))
        surface.DrawTexturedRect(0, 0, w, h)
    end)
    CharBase:SetBarColor(Color(0, 0, 0, 0))
    CharBase:SetTitleAlign("center")

    local centerpnl = PD.Panel("", CharBase)
    centerpnl:Dock(NODOCK)
    centerpnl:SetSize(PD.W(1730), PD.H(650))
    centerpnl:SetPos(scrw / 2 - centerpnl:GetWide() / 2, scrh / 2 - centerpnl:GetTall() / 2)
    centerpnl:SetBackColor(Color(0, 0, 0, 0))

    local infobuttondc = PD.Button("", CharBase, function()
        gui.OpenURL(CONFIG:GetConfig("charakter_discord"))
    end, function(self, w, h)
        PD.DrawImgur(0, 0, w, h, "HeQlEmy")
    end)
    infobuttondc:SetSize(PD.W(40), PD.H(40))
    infobuttondc:SetPos(CharBase:GetWide() - PD.W(170), CharBase:GetTall() - PD.H(50))
    infobuttondc:SetBackColor(Color(255, 255, 255, 0))
    infobuttondc:SetHoverColor(Color(255, 255, 255, 0))
    infobuttondc:SetBackgroundDisabled(true)

    local infobuttonkolli = PD.Button("", CharBase, function()
        gui.OpenURL(CONFIG:GetConfig("charakter_kolli"))
    end, function(self, w, h)
        PD.DrawImgur(0, 0, w, h, "lXVious")
    end)
    infobuttonkolli:SetSize(PD.W(40), PD.H(40))
    infobuttonkolli:SetPos(CharBase:GetWide() - PD.W(110), CharBase:GetTall() - PD.H(50))
    infobuttonkolli:SetBackColor(Color(255, 255, 255, 0))
    infobuttonkolli:SetHoverColor(Color(255, 255, 255, 0))
    infobuttonkolli:SetBackgroundDisabled(true)

    local infobuttonleave = PD.Button("", CharBase, function()
        RunConsoleCommand("disconnect")
    end, function(self, w, h)
        PD.DrawImgur(0, 0, w, h, "VEFb1Gi")
    end)
    infobuttonleave:SetSize(PD.W(40), PD.H(40))
    infobuttonleave:SetPos(CharBase:GetWide() - PD.W(50), CharBase:GetTall() - PD.H(50))
    infobuttonleave:SetBackColor(Color(255, 255, 255, 0))
    infobuttonleave:SetHoverColor(Color(255, 255, 255, 0))
    infobuttonleave:SetBackgroundDisabled(true)

    local selectList = PD.Panel("", centerpnl)
    selectList:Dock(LEFT)
    selectList:SetWide(PD.W(1300))
    -- selectList:SetBackColor(Color(0,0,0,0))

    local showInfo = PD.Panel("Wähle ein Charakter aus!", centerpnl)
    showInfo:Dock(FILL)
    showInfo:SetSize(PD.W(410), PD.H(600))
    showInfo:SetPos(PD.W(1310), PD.H(110))

    for i = 1, CONFIG:GetConfig("charakter_maxchars") do
        local data = PD.Char.Data[i]
        if not data then
            data = {
                name = "Frei",
                id = "",
                rank = "",
                job = {
                    name = "Rekrut",
                    model = "models/player/skeleton.mdl",
                    unit = "Rekruten",
                    id = "Rekrut"
                },
                faction = {
                    unit = "",
                    subunit = "",
                    job = ""
                },
                money = 0,
                cratedate = 0,
                lastplaytime = 0,
                playtime = 0
            }
        end

        if CONFIG:GetConfig("charakter_usergroupchar")[LocalPlayer():GetUserGroup()] < i then
            data.name = "GESPERRT"
        end

        local panelChar = PD.PanelButtonDesign("", selectList)
        panelChar:Dock(LEFT)
        panelChar:SetSize(PD.W(250), selectList:GetTall())
        panelChar:SetRadius(70)

        if data.name == "Frei" then
            panelChar:SetNoPaint()
        end

        if data.name ~= "Frei" then
            local modelChar = panelChar:Add("DModelPanel")
            modelChar:SetPos(0, 0)
            modelChar:SetSize(panelChar:GetWide(), PD.H(600))
            modelChar:SetModel(data.job.model)
            modelChar:SetFOV(35)
            function modelChar:LayoutEntity(Entity)
                return
            end
            function modelChar.Entity:GetPlayerColor()
                return Vector(1, 0, 0)
            end
        end

        local buttonChar = PD.Button("", panelChar, function()
            if CONFIG:GetConfig("charakter_usergroupchar")[LocalPlayer():GetUserGroup()] < i then
                Error("Dieser Platz ist für dich gesperrt", CharBase, 5)
                return
            end

            if data.name == "Frei" then
                showInfo:Clear()

                local pnl, name = PD.TextEntryLabel("Gib hier dein Namen ein ohne ID", showInfo, "Name")

                local create = PD.Button("Erstellen", showInfo, function()
                    local gn = name:GetValue()

                    if gn == "" then
                        Error("Du musst einen Namen eingeben!", CharBase, 5)
                        return
                    end
                    if #gn < CONFIG:GetConfig("charakter_minname") then
                        Error(
                            "Dein Name ist zu kurz du brauchst mindestens " .. CONFIG:GetConfig("charakter_minname") ..
                                " Buchstaben!", CharBase, 5)
                        return
                    end
                    if #gn > CONFIG:GetConfig("charakter_maxname") then
                        Error("Dein Name ist zu lang du darfst maximal " .. CONFIG:GetConfig("charakter_maxname") ..
                                  " Buchstaben haben!", CharBase, 5)
                        return
                    end
                    if CONFIG:GetConfig("charakter_nameblacklist")[gn] then
                        Error("Dein Name ist nicht erlaubt!", CharBase, 5)
                        return
                    end

                    net.Start("PD.Char.Create")
                    net.WriteEntity(LocalPlayer())
                    net.WriteString(gn)
                    net.SendToServer()

                    CharBase:Remove()
                end)
                create:Dock(BOTTOM)
                create:SetTall(PD.H(50))
                create:SetRadius(20)
            else
                showInfo:Clear()

                local lbl = PD.Label("Name: " .. data.name .. "\n\nID: " .. data.id .. "\n\nGeld: " .. data.money ..
                                         "\n\nErstellungsdatum: " .. data.cratedate .. "\n\nZuletzt gespielt: " ..
                                         data.lastplaytime .. "\n\nSpielzeit: " .. Mario.FormatTime(data.playtime) ..
                                         "\n\nEinheit: " .. data.faction.unit .. "\n\nUntereinheit: " ..
                                         data.faction.subunit .. "\n\nJob: " .. data.faction.job, showInfo)

                if LocalPlayer():GetNWString("rpname") ~= data.id .. " " .. data.name then
                    local playbutton = PD.Button("Spielen", showInfo, function()
                        CharBase:Remove()

                        net.Start("PD.Char.Play")
                        net.WriteEntity(LocalPlayer())
                        net.WriteUInt(i, 32)
                        -- net.WriteTable(data)
                        net.SendToServer()
                    end)
                    playbutton:Dock(BOTTOM)
                    playbutton:SetTall(PD.H(50))
                    playbutton:SetRadius(20)
                    if LocalPlayer():Nick() == data.id .. " " .. data.name then
                        playbutton:SetDisabled(true)
                    end

                    local deletebutton = PD.Button("Löschen", showInfo, function()
                        CharBase:Remove()

                        net.Start("PD.Char.Delete")
                        net.WriteEntity(LocalPlayer())
                        net.WriteUInt(i, 32)
                        net.WriteString(steamworks.GetPlayerName(LocalPlayer():SteamID64()))
                        net.SendToServer()
                    end)
                    deletebutton:Dock(BOTTOM)
                    deletebutton:SetTall(PD.H(50))
                    deletebutton:SetRadius(20)
                    deletebutton:SetHoverColor(Color(CONFIG:GetConfig("colorred").r, CONFIG:GetConfig("colorred").g,
                        CONFIG:GetConfig("colorred").b, 50))
                else
                    local lbl = PD.Label("Du spielst bereits mit diesem Charakter!", showInfo, Color(255, 0, 0))
                    lbl:Dock(BOTTOM)

                    local deletebutton = PD.Button("Löschen", showInfo, function()
                        CharBase:Remove()

                        net.Start("PD.Char.Delete")
                        net.WriteEntity(LocalPlayer())
                        net.WriteUInt(i, 32)
                        net.WriteString(steamworks.GetPlayerName(LocalPlayer():SteamID64()))
                        net.SendToServer()
                    end)
                    deletebutton:Dock(BOTTOM)
                    deletebutton:SetTall(PD.H(50))
                    deletebutton:SetRadius(20)
                    deletebutton:SetHoverColor(Color(CONFIG:GetConfig("colorred").r, CONFIG:GetConfig("colorred").g,
                        CONFIG:GetConfig("colorred").b, 50))
                end
            end
        end, function(self, w, h)
            if data.name == "Frei" then
                draw.DrawText(data.name, "MLIB.25", w / 2, h / 2 - PD.H(12.5), CONFIG:GetConfig("textcolor"),
                    TEXT_ALIGN_CENTER)
            else
                draw.DrawText(data.name, "MLIB.25", w / 2, h / 2 - PD.H(12.5), CONFIG:GetConfig("textcolor"),
                    TEXT_ALIGN_CENTER)
            end
        end)


        if data.name == "Frei" then
            buttonChar:Dock(FILL)
            buttonChar:SetRadius(70)
        else
            buttonChar:Dock(BOTTOM)
            buttonChar:DockMargin(PD.W(40), 0, PD.W(40), PD.H(10))
            buttonChar:SetTall(PD.H(50))
            buttonChar:SetRadius(20)
        end

        local name = {
            -- ["Frei"] = true,
            ["GESPERRT"] = true
        }

        if name[data.name] then
            buttonChar:SetDisabled(true)
        end

        if data.name ~= "Frei" then
            buttonChar:SetBackColor(Color(0, 0, 0, 0))
        end
    end
end

local name = ""
function PD.Char:AdminMenu()
    if IsValid(AdminBase) then
        return
    end

    AdminBase = PD.Frame("Charakter Admin Menu", PD.W(600), PD.H(800), true)

    local scrl = PD.Scroll(AdminBase)

    for k, v in SortedPairs(PD.Char.AdminData) do
        if FindPlayerbyID(k) then
            name = FindPlayerbyID(k):Nick()
        else
            name = "Offline"
        end

        local pnl = PD.Button(steamworks.GetPlayerName(k), scrl, function()
            -- if name == "Offline" then chat.AddText(CONFIG:GetConfig("colorred"),"Der Spieler ist Offline!") return end
            scrl:Clear()

            for a, b in ipairs(v) do
                local pnl = PD.Button("", scrl, function()
                    scrl:Clear()

                    local pnl, id = PD.TextEntryLabel("Spieler ID", scrl, "", b.id)
                    local pnl, name = PD.TextEntryLabel("Spieler Name", scrl, "", b.name)
                    local pnl, money = PD.TextEntryLabel("Spieler Credits", scrl, "", b.money)
                    local job = PD.ComboBox(b.job.name, scrl)

                    for k, v in ipairs(PD.JOBS.GetJob(false, true)) do
                        job:AddChoice(k)
                    end

                    local info = PD.Label("Erstellungsdatum: " .. b.cratedate .. "\n\nZuletzt gespielt: " ..
                                              b.lastplaytime .. "\n\nSpielzeit: " .. Mario.FormatTime(b.playtime), scrl)

                    local setPlayer = PD.Button("Löschen", AdminBase, function()
                        net.Start("PD.Char.AdminDelete")
                        net.WriteString(k)
                        net.WriteUInt(a, 32)
                        net.SendToServer()

                        AdminBase:Remove()
                    end)
                    setPlayer:Dock(BOTTOM)
                    setPlayer:SetTall(PD.H(50))

                    local setPlayer = PD.Button("Setzen", AdminBase, function()
                        net.Start("PD.Char.Play")
                        net.WriteEntity(FindPlayerbyID(k))
                        net.WriteUInt(a, 32)
                        net.SendToServer()

                        AdminBase:Remove()
                    end)
                    setPlayer:Dock(BOTTOM)
                    setPlayer:SetTall(PD.H(50))

                    local save = PD.Button("Speichern", AdminBase, function()
                        net.Start("PD.Char.AdminSave")
                        net.WriteString(k)
                        net.WriteUInt(a, 32)
                        net.WriteString(id:GetValue())
                        net.WriteString(name:GetValue())
                        net.WriteString(job:GetSelectedID())
                        net.WriteUInt(money:GetValue(), 32)
                        net.SendToServer()

                        AdminBase:Remove()
                    end)
                    save:Dock(BOTTOM)
                    save:SetTall(PD.H(50))
                end, function(self, w, h)
                    draw.DrawText("Char: " .. a, "MLIB.25", PD.W(10), h / 2 - PD.H(12.5), CONFIG:GetConfig("textcolor"),
                        TEXT_ALIGN_LEFT)
                    draw.DrawText(b.id .. " " .. b.name, "MLIB.25", w / 2, h / 2 - PD.H(12.5),
                        CONFIG:GetConfig("textcolor"), TEXT_ALIGN_CENTER)
                end)
                pnl:Dock(TOP)
                pnl:SetTall(PD.H(50))
            end
        end)
        pnl:Dock(TOP)
        pnl:SetTall(PD.H(50))
    end
end

net.Receive("OpenCharbyDelete", function()
    PD.Char:Menu()
end)

hook.Add("PlayerButtonDown", "PD.Char:MenuKeyBind", function(ply, key)
    if (key == KEY_F6) then
        net.Start("PD.Char.Syncsv")
        net.SendToServer()
        timer.Simple(0.5, function()
            PD.Char:Menu(true)
        end)
    elseif (key == KEY_F7) then -- PD.Char.OpenAdminMenu
        if not ply:IsAdmin() then
            return
        end
        net.Start("PD.Char.AdminSync")
        net.SendToServer()
        timer.Simple(0.5, function()
            PD.Char:AdminMenu()
        end)
    elseif (key == PD.List.OpenKey) then
        PD.List:Menu()
    end
end)

hook.Add("InitPostEntity", "SyncCharMenuCharsProgama057", function()
    net.Start("PD.Char.Syncsv")
    net.WriteBool(true)
    net.SendToServer()
    net.Start("PD.Char.AdminSync")
    net.SendToServer()
end)

concommand.Add("pd_char_print", function()
    print("PD.Char.Data")
    PrintTable(PD.Char.Data)
    print("PD.Char.AdminData")
    PrintTable(PD.Char.AdminData)
    print("Get Job Data")
    local id, tbl = LocalPlayer():GetJob()
    print(id)
    PrintTable(tbl)
end)

local PLAYER = FindMetaTable("Player")
function PLAYER:SetJob(jobID, jobTbl)
    self.JobID = jobID
    self.JobTbl = jobTbl

    print("SetJob: " .. jobID)
end

function PLAYER:GetJob()
    return self.JobID, self.JobTbl
end
