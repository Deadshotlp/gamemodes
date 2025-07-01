PD.Char.AdminData = {}

net.Receive("PD.Char.AdminSync", function()
    PD.Char.AdminData = net.ReadTable()
end)

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
            -- if name == "Offline" then chat.AddText(PD.UI.Colors["SithRed"],"Der Spieler ist Offline!") return end
            scrl:Clear()

            for a, b in ipairs(v) do
                local pnl = PD.Button("", scrl, function()
                    scrl:Clear()

                    local pnl, id = PD.TextEntryLabel("Spieler ID", scrl, "", b.id)
                    local pnl, name = PD.TextEntryLabel("Spieler Name", scrl, "", b.name)
                    local pnl, money = PD.TextEntryLabel("Spieler Credits", scrl, "", b.money)
                    local jobBox = PD.ComboBox(b.job.name, scrl)
                    jobBox:SetSearch(true)

                    for k, v in SortedPairs(PD.JOBS.GetJob(false, true)) do
                        jobBox:AddChoice(v.unit .. " - " .. k, k)
                    end

                    local info = PD.Label("Erstellungsdatum: " .. b.cratedate .. "\n\nZuletzt gespielt: " .. b.lastplaytime .. "\n\nSpielzeit: " .. Mario.FormatTime(b.playtime), scrl)

                    local setPlayer = PD.Button("Löschen", scrl, function()
                        net.Start("PD.Char.AdminDelete")
                        net.WriteString(k)
                        net.WriteUInt(a, 32)
                        net.SendToServer()

                        AdminBase:Remove()
                    end)
                    setPlayer:Dock(TOP)
                    setPlayer:SetTall(PD.H(50))

                    local setPlayer = PD.Button("Setzen", scrl, function()
                        net.Start("PD.Char.Play")
                        net.WriteEntity(FindPlayerbyID(k))
                        net.WriteUInt(a, 32)
                        net.SendToServer()

                        AdminBase:Remove()
                    end)
                    setPlayer:Dock(TOP)
                    setPlayer:SetTall(PD.H(50))

                    local setPlayer = PD.Button("Default Fraktion setzten", scrl, function()
                        net.Start("PD.Char.DefaultFaction")
                        net.WriteEntity(FindPlayerbyID(k))
                        net.WriteUInt(a, 32)
                        net.SendToServer()

                        AdminBase:Remove()
                    end)
                    setPlayer:Dock(TOP)
                    setPlayer:SetTall(PD.H(50))

                    local save = PD.Button("Speichern", scrl, function()
                        local streing, data = jobBox:GetSelected()

                        net.Start("PD.Char.AdminSave")
                        net.WriteString(k)
                        net.WriteUInt(a, 32)
                        net.WriteString(id:GetValue())
                        net.WriteString(name:GetValue())
                        net.WriteString(data)
                        net.WriteUInt(money:GetValue(), 32)
                        net.SendToServer()

                        AdminBase:Remove()
                    end)
                    save:Dock(TOP)
                    save:SetTall(PD.H(50))
                end, function(self, w, h)
                    draw.DrawText("Char: " .. a, "MLIB.25", PD.W(10), h / 2 - PD.H(12.5), PD.UI.Colors["Text"],
                        TEXT_ALIGN_LEFT)
                    draw.DrawText(b.id .. " " .. b.name, "MLIB.25", w / 2, h / 2 - PD.H(12.5),
                        PD.UI.Colors["Text"], TEXT_ALIGN_CENTER)
                end)
                pnl:Dock(TOP)
                pnl:SetTall(PD.H(50))
            end
        end)
        pnl:Dock(TOP)
        pnl:SetTall(PD.H(50))
    end
end

hook.Add("InitPostEntity", "SyncCharMenuCharsProgama057Admin", function()
    net.Start("PD.Char.AdminSync")
    net.SendToServer()
end)

