--===--===--===--===--===--===--===--===--
-- List / Faction System 
--===--===--===--===--===--===--===--===--
PD.List = PD.List or {}
PD.List.Factions = {}

PD.List.Factions = {}

timer.Simple(0.1,function()
    net.Start("PD.List.Sync")
    net.SendToServer()
end)

net.Receive("PD.List.Sync",function()
    PD.List.Factions = net.ReadTable()
end)

local function FindPlayerUnit(ply)
    for k,v in SortedPairs(PD.List.Factions) do
        for a,b in SortedPairs(v.subunits) do
            for c,d in SortedPairs(b.jobs) do
                for e,f in SortedPairs(d.players) do
                    if e == ply:GetCharacterID() then
                        return k, a, c
                    end
                end
            end
        end
    end
    return false, false, false
end

local function GetPlayerInfos(ply)
    local unit, subunit, job = FindPlayerUnit(ply)
    return PD.List.Factions[unit].subunits[subunit].jobs[job].players[ply:GetCharacterID()]
end

local function GetAllPlayers()
    local tbl = {}
    for k,v in SortedPairs(PD.List.Factions) do
        for a,b in SortedPairs(v.subunits) do
            for c,d in SortedPairs(b.jobs) do
                for e,f in SortedPairs(d.players) do
                    tbl[e] = f
                end
            end
        end
    end
    return tbl
end

local function GetPlayersByUnit(unit)
    local tbl = {}
    for k,v in pairs(PD.List.Factions[unit].subunits) do
        for a,b in pairs(v.jobs) do
            for c,d in pairs(b.players) do
                tbl[c] = d
            end
        end
    end
    return tbl
end

local function FindPlayerbyCharID(charID)
    for k,v in pairs(player.GetAll()) do
        if v:GetCharacterID() == charID then
            return v
        end
    end
    return false
end

function PD.List:Menu(wo)
    if IsValid(ListBase) then return end

    ListBase = PD.Frame("Einheiten-Verwaltung",PD.W(1400),PD.H(700),true)

    local rightPnl = PD.Panel("",ListBase)
    rightPnl:Dock(FILL)

    PD.SideTab(ListBase, rightPnl)
    
    PD.AddSideItem("Fraktionen", function(pnl)
        pnl:Clear()

        local scrl = PD.Scroll(pnl)
        for k,v in SortedPairs(PD.List.Factions) do
            local infoFaction = PD.Button(k,scrl,function()
                scrl:Clear()

                local playerTbl = GetPlayersByUnit(k)

                if table.Count(playerTbl) == 0 then 
                    local lbl = PD.Label("Scheint wohl das niemand im Dienst ist.", scrl)   
        
                    return 
                end

                for a,b in SortedPairs(playerTbl) do
                    local ply = FindPlayerbyCharID(a)

                    if not IsValid(ply) then continue end
        
                    local infoPlayer = PD.Panel("",scrl,function(self,w,h)
                        -- draw.DrawText("Player: ","MLIB.25",10,h/2-PD.H(12.5),PD.UI.Colors["Text"],TEXT_ALIGN_LEFT)
                        draw.DrawText(ply:Nick(),"MLIB.25",PD.W(10),h/2-PD.H(12.5),PD.UI.Colors["Text"],TEXT_ALIGN_LEFT)
                        draw.DrawText(b.subunit,"MLIB.25",w / 2,h/2-PD.H(12.5),PD.UI.Colors["Text"],TEXT_ALIGN_CENTER)
                        draw.DrawText(b.job,"MLIB.25",w - PD.W(10),h/2-PD.H(12.5),PD.UI.Colors["Text"],TEXT_ALIGN_RIGHT)
                    end)
                    infoPlayer:SetTall(PD.H(50))
                    infoPlayer:SetBackColor(PD.UI.Colors["Green"])
                end
            end,function(self,w,h)
                -- surface.SetDrawColor(v.color)
                -- surface.DrawOutlinedRect(0, 0, w, h, PD.H(2))
            end)
            infoFaction:SetTall(PD.H(50))
            infoFaction:Dock(TOP)
            infoFaction:SetOutlineColor(v.color)
            -- infoFaction:SetHoverColor(v.color)
        end
    end)

    PD.AddSideItem("Einheit", function(pnl)
        pnl:Clear()

        local scrl = PD.Scroll(pnl)
        local unit, subunit, job = FindPlayerUnit(LocalPlayer())

        if not unit then
            local lbl = PD.Label("Du bist in keiner Einheit",scrl)
            return
        end

        local tbl = PD.List.Factions[unit].subunits[subunit].jobs[job].players

        if not tbl then print("Zeile: 122 | Table Kaputt") return end

        for charID, v in SortedPairs(tbl) do
            local mainPlayerPanel = PD.Panel("", scrl, function(self,w,h)

            end)
            mainPlayerPanel:SetTall(PD.H(150))

            local playerpnl = PD.Panel("", mainPlayerPanel, function(self,w,h)
                draw.DrawText(v.job .. " | " .. v.name,"MLIB.25",10,h/2-PD.H(12.5),PD.UI.Colors["Text"],TEXT_ALIGN_LEFT)
            end)

            if IsValid(FindPlayerbyCharID(charID)) then
                playerpnl:SetBackColor(PD.UI.Colors["Green"])
            else
                playerpnl:SetBackColor(PD.UI.Colors["SithRed"])
            end

            local online = "Offline" .. " | " .. v.lastplay

            if IsValid(FindPlayerbyCharID(charID)) then
                online = "Online"
            end

            local lbl = PD.Label("Spielzeit: " .. v.playtime, mainPlayerPanel)
            local lbl = PD.Label("Zuletzt gesehen: " .. online, mainPlayerPanel)
            local lbl = PD.Label("Einheit beigetreten: " .. v.join, mainPlayerPanel)

            if LocalPlayer():IsAdmin() or table.HasValue(PD.List.Permission, v.job) then
                if FindPlayerbyCharID(charID) == LocalPlayer() then continue end

                local rankUp = PD.Button("Befördern",playerpnl,function()
                    net.Start("PD.List.RankUp")
                        net.WriteString(charID)
                    net.SendToServer()
                end)
                rankUp:Dock(RIGHT)
                rankUp:SetWide(PD.W(200))

                local rankDown = PD.Button("Degradieren",playerpnl,function()
                    net.Start("PD.List.RankDown")
                        net.WriteString(charID)
                    net.SendToServer()
                end)
                rankDown:Dock(RIGHT)
                rankDown:SetWide(PD.W(200))

                local kick = PD.Button("Einheit verweisen",playerpnl,function()
                    net.Start("PD.List.kick")
                        net.WriteString(charID)
                    net.SendToServer()
                end)
                kick:Dock(RIGHT)
                kick:SetWide(PD.W(200))
            end
        end
    end)

    if LocalPlayer():IsAdmin() then
        PD.AddSideItem("Admin",function(pnl)
            pnl:Clear()

            local playerBtn = PD.Button("Spieler", pnl, function()
                pnl:Clear()
                local scrl = PD.Scroll(pnl)
                local spieler = GetAllPlayers()

                for k, v in SortedPairs(spieler) do
                    local steamName = steamworks.GetPlayerName(v.steamid)
                    local playerBtn = PD.Button(v.name .. " | (" .. steamName .. ")", scrl, function()
                        scrl:Clear()

                        local charID = string.sub(v.name, 0, 7)
                        local vp = FindPlayerbyCharID(charID)
                        local unit, subunit, job = FindPlayerUnit(vp)
                        local ply = GetPlayerInfos(vp)
                        local online = "Offline" .. " | " .. ply.lastplay

                        if IsValid(vp) then
                            online = "Online"
                        end

                        local lbl = PD.Label("Name: " .. v.name .. " | (" .. steamName .. ")", scrl)
                        local lbl = PD.Label("Einheit: " .. unit, scrl)
                        local lbl = PD.Label("Untereinheit: " .. subunit, scrl)
                        local lbl = PD.Label("Job: " .. job, scrl)
                        local lbl = PD.Label("Zuletzt gesehen: " .. online, scrl)
                        local lbl = PD.Label("Einheit beigetreten: " .. ply.join, scrl)
                        local lbl = PD.Label("Spielzeit: " .. ply.playtime, scrl)

                        local ComboBoxJob = PD.ComboBox("Neuer Job hier wählen", scrl, function(val)
                            val = string.Explode(" | ",val)

                            newJob = val[1]
                        end)
                        ComboBoxJob:SetSearch(true)

                        for k,v in SortedPairs(PD.List.Factions) do
                            for a,b in SortedPairs(v.subunits) do
                                for c,d in SortedPairs(b.jobs) do
                                    ComboBoxJob:AddChoice(c  .. " | " .. a .. " | " .. k)
                                end
                            end
                        end

                        local changeUnit = PD.Button("Unit Chnage",scrl,function()
                            net.Start("PD.List.ChangeUnit")
                                net.WriteString(vp:GetCharacterID())
                                net.WriteString(newJob)
                            net.SendToServer()
                        end)
                        changeUnit:Dock(TOP)

                        local rankUp = PD.Button("Befördern",scrl,function()
                            net.Start("PD.List.RankUp")
                                net.WriteString(vp:GetCharacterID())
                            net.SendToServer()
                        end)
                        rankUp:Dock(TOP)

                        local rankDown = PD.Button("Degradieren",scrl,function()
                            net.Start("PD.List.RankDown")
                                net.WriteString(vp:GetCharacterID())
                            net.SendToServer()
                        end)
                        rankDown:Dock(TOP)

                        local kick = PD.Button("Einheit verweisen",scrl,function()
                            net.Start("PD.List.kick")
                                net.WriteString(vp:GetCharacterID())
                            net.SendToServer()
                        end)
                        kick:Dock(TOP)

 
                        local defaultFaction = PD.Button("Default Faction",scrl,function()
                            net.Start("PD.List.SetPlayerFaction")
                                net.WriteEntity(vp)
                                net.WriteString("Ausbildung")
                                net.WriteString("Rekruten")
                                net.WriteString("Rekrut")
                            net.SendToServer()
                        end)
                        defaultFaction:Dock(TOP)
                    end)
                    playerBtn:Dock(TOP)
                end
            end)
            playerBtn:Dock(TOP)
            playerBtn:SetTall(PD.H(50))

            local adminUnit = PD.Button("Alle Einheiten", pnl, function()
                pnl:Clear()
                local scrl = PD.Scroll(pnl)

                for k,v in SortedPairs(PD.List.Factions) do
                    local unitBtn = PD.Button(k,scrl,function()
                        scrl:Clear()

                        for a,b in SortedPairs(v.subunits) do
                            local subunitBtn = PD.Button(a,scrl,function()
                                scrl:Clear()

                                for c,d in SortedPairs(b.jobs) do
                                    local jobBtn = PD.Button(c,scrl,function()
                                        scrl:Clear()

                                        for e,f in SortedPairs(d.players) do
                                            local playerBtn = PD.Button(f.name,scrl,function()
                                                net.Start("PD.List.SetPlayerFaction")
                                                    net.WriteEntity(FindPlayerbyCharID(e))
                                                    net.WriteString(k)
                                                    net.WriteString(a)
                                                    net.WriteString(c)
                                                net.SendToServer()
                                            end)
                                            playerBtn:Dock(TOP)
                                        end
                                    end)
                                    jobBtn:Dock(TOP)
                                end
                            end)
                            subunitBtn:Dock(TOP)
                        end
                    end)
                    unitBtn:Dock(TOP)
                    unitBtn:SetTall(PD.H(50))
                end

            end)
            adminUnit:Dock(TOP)
            adminUnit:SetTall(PD.H(50))

        end)
    end
            
    PD.SelectItem(wo or "Einheit")
end

concommand.Add("pd_list_print",function()
    PrintTable(PD.List.Factions)
end)

concommand.Add("pd_list_id",function(ply)
    print(ply:GetCharacterID())
    print(ply:GetNWString("character_id","9999"))
    print(FindPlayerUnit(ply))
end)

local PLAYER = FindMetaTable("Player")
function PLAYER:GetCharacterID()
    return self:GetNWString("character_id","9999")
end

