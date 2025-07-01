PD.Char = PD.Char or {}
PD.Char.Data = PD.Char.Data or {}

local scrw, scrh = ScrW(), ScrH()
local txt = ""

PD.Char.Data = {}

net.Receive("PD.Char.Synccl", function()
    PD.Char.Data = net.ReadTable()
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

net.Receive("PD.Char.SetJobFunction", function()
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

        draw.DrawText(text, "MLIB.25", w / 2, h / 2 - 12.5, PD.UI.Colors["Text"], TEXT_ALIGN_CENTER)
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
        surface.SetMaterial(Material(PD.Char.Background))
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
        gui.OpenURL(PD.Char.Discord)
    end, function(self, w, h)
        PD.DrawImgur(0, 0, w, h, "HeQlEmy")
    end)
    infobuttondc:SetSize(PD.W(40), PD.H(40))
    infobuttondc:SetPos(CharBase:GetWide() - PD.W(170), CharBase:GetTall() - PD.H(50))
    infobuttondc:SetBackColor(Color(255, 255, 255, 0))
    infobuttondc:SetHoverColor(Color(255, 255, 255, 0))
    infobuttondc:SetBackgroundDisabled(true)

    local infobuttonkolli = PD.Button("", CharBase, function()
        gui.OpenURL(PD.Char.Kollektion)
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

    for i = 1, PD.Char.MaxChars do
        local data = PD.Char.Data[i]
        if not data then
            data = {
                name = "Frei",
                id = "",
                rank = "",
                job = {
                    name = "Rekrut",
                    model = CONFIG.BackModel,
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

        if PD.Char.UserGroupChar[LocalPlayer():GetUserGroup()] < i then
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
            if not string.find(data.job.model, ".mdl") then
                data.job.model = CONFIG.BackModel
            end

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
            if PD.Char.UserGroupChar[LocalPlayer():GetUserGroup()] < i then
                Error("Dieser Platz ist für dich gesperrt", CharBase, 5)
                return
            end

            if data.name == "Frei" then
                showInfo:Clear()

                local pnl, name = PD.TextEntryLabel("Gib hier dein Namen ein, ohne eine ID", showInfo, "Name")

                local create = PD.Button("Erstellen", showInfo, function()
                    local gn = name:GetValue()

                    if gn == "" then
                        Error("Du musst einen Namen eingeben!", CharBase, 5)
                        return
                    end
                    if #gn < PD.Char.MinName then
                        Error(
                            "Dein Name ist zu kurz du brauchst mindestens " .. PD.Char.MinName ..
                                " Buchstaben!", CharBase, 5)
                        return
                    end
                    if #gn > PD.Char.MaxName then
                        Error("Dein Name ist zu lang du darfst maximal " .. PD.Char.MaxName ..
                                  " Buchstaben haben!", CharBase, 5)
                        return
                    end
                    if PD.Char.NameBlacklist[gn] then
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

                local lbl = PD.Label("Rufname: " .. data.name .. "\n\nID: " .. data.id .. "\n\nCredits: " .. data.money ..
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
                        net.SendToServer()
                    end)
                    playbutton:Dock(BOTTOM)
                    playbutton:SetTall(PD.H(50))
                    playbutton:SetRadius(20)
                    playbutton:SetHoverColor(PD.UI.Colors["Green"])
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
                    deletebutton:SetHoverColor(PD.UI.Colors["SithRed"])
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
                    deletebutton:SetHoverColor(PD.UI.Colors["SithRed"])
                end
            end
        end, function(self, w, h)
            if data.name == "Frei" then
                draw.DrawText(data.name, "MLIB.25", w / 2, h / 2 - PD.H(12.5), PD.UI.Colors["Text"],
                    TEXT_ALIGN_CENTER)
            else
                draw.DrawText(data.name, "MLIB.25", w / 2, h / 2 - PD.H(12.5), PD.UI.Colors["Text"],
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

        if data.name == "GESPERRT" then
            buttonChar:SetDisabled(true)
        end

        if data.name ~= "Frei" then
            buttonChar:SetBackColor(Color(0, 0, 0, 0))
        end
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
    elseif (key == KEY_F7) then
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

