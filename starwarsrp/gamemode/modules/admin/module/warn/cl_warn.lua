PD.Warn = PD.Warn or {}

local warnTbl = {}

net.Receive("PD.Warn.SendWarnsToClient", function()
    warnTbl = net.ReadTable()
end)

concommand.Add("print_warn", function()
    PrintTable(warnTbl)
end)

net.Start("PD.Warn.GetWarns")
net.SendToServer()

local warns = {}

function PD.Warn:Menu()
    if IsValid(self.Frame) then return end
    if not LocalPlayer():IsAdmin() then return end

    self.Frame = PD.Frame("Warn-System", PD.W(800), PD.H(600), true)

    local scrl = PD.Scroll(self.Frame)

    for k, v in pairs(player.GetAll()) do

        if not warnTbl[v:SteamID()] then
            warnTbl[v:SteamID()] = {}
            warnTbl[v:SteamID()].Warns = 0
        end

        local plyBtn = PD.Button(v:Nick() .. "(" .. warnTbl[v:SteamID()].Warns .. ")", scrl, function()
            net.Start("PD.Warn.AddWarn")
                net.WriteEntity(v)
            net.SendToServer()

            chat.AddText(Color(0, 255, 0), "You have warned " .. v:Nick())

            self.Frame:Remove()
        end)

        plyBtn.DoRightClick = function()
            net.Start("PD.Warn.RemoveWarn")
                net.WriteEntity(v)
            net.SendToServer()

            chat.AddText(Color(255, 0, 0), "You have removed a warn from " .. v:Nick())

            self.Frame:Remove()
        end

        plyBtn:Dock(TOP)
        plyBtn:SetTall(PD.H(50))
        plyBtn:SetBackColor(Color(255, 255, 255))

        if plyBtn:GetBackColor() == Color(255, 255, 255) then
            plyBtn:SetTextColor(Color(0, 0, 0))
        end

        if warnTbl[v:SteamID64()] then
            if warnTbl[v:SteamID64()].Warns == 1 then
                plyBtn:SetBackColor(Color(0, 255, 0))
            elseif warnTbl[v:SteamID64()].Warns == 2 then
                plyBtn:SetBackColor(Color(255, 255, 0))
            elseif warnTbl[v:SteamID64()].Warns == 3 then
                plyBtn:SetBackColor(Color(255, 0, 0))
            end
        end

        local banBtn = PD.Button("Ban", plyBtn, function()
            net.Start("PD.Warn.BanPlayer")
                net.WriteEntity(v)
            net.SendToServer()
        end)
        banBtn:Dock(RIGHT)
        banBtn:SetWide(PD.W(100))
    end
end

