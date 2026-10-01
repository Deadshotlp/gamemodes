-- ===--===--===--===--===--===--===--===--
-- List / Faction System 
-- ===--===--===--===--===--===--===--===--
PD.List = PD.List or {}
local factionTable = {}

net.Start("PD.List.RequestData")
net.SendToServer()

PD.List.Interactions = {
    ["player"] = {
        [1] = {
            id = "invate",
            name = "In Einheit aufnehmen",
            icon = nil,
            func = function(ply1, ply2, bone)
                net.Start("PD.List.Invite")
                net.WriteEntity(ply1)
                net.WriteEntity(ply2)
                net.SendToServer()
            end,
            ad = {"ValveBiped.Bip01_Spine"}
        },
        [2] = {
            id = "kick",
            name = "Aus der Einheit verweisen",
            icon = nil,
            func = function(ply1, ply2, bone)
                net.Start("PD.List.Kick")
                net.WriteEntity(ply1)
                net.WriteEntity(ply2)
                net.SendToServer()
            end,
            ad = {"ValveBiped.Bip01_Spine"}
        },
        [3] = {
            id = "rankup",
            name = "Befördern",
            icon = nil,
            func = function(ply1, ply2, bone)
                net.Start("PD.List.RankUp")
                net.WriteEntity(ply1)
                net.WriteEntity(ply2)
                net.SendToServer()
            end,
            ad = {"ValveBiped.Bip01_Spine"}
        },
        [4] = {
            id = "rankdown",
            name = "Degradieren",
            icon = nil,
            func = function(ply1, ply2, bone)
                net.Start("PD.List.RankDown")
                net.WriteEntity(ply1)
                net.WriteEntity(ply2)
                net.SendToServer()
            end,
            ad = {"ValveBiped.Bip01_Spine"}
        }
    }
}

-- Einladung in eine Einheit: annehmen oder ablehnen.
local inviteFrame

local function AnswerInvite(accepted)
    net.Start("PD.List.InviteAnswer")
        net.WriteBool(accepted)
    net.SendToServer()

    if IsValid(inviteFrame) then
        inviteFrame:Remove()
    end
end

net.Receive("PD.List.InviteRequest", function()
    local officerName = net.ReadString()
    local unitName = net.ReadString()
    local timeout = net.ReadUInt(8)

    if IsValid(inviteFrame) then
        inviteFrame:Remove()
    end

    inviteFrame = PD.Frame("EINLADUNG", PD.W(420), PD.H(210), false, {
        accent = PD.Theme.Colors.AccentBlue
    })

    local content = inviteFrame:GetContentPanel()

    PD.Label(officerName .. " lädt dich in die Einheit", content, {font = "MLIB.16"})
    PD.Label(unitName .. " ein.", content, {font = "MLIB.20", height = PD.H(22)})

    local buttons = vgui.Create("DPanel", content)
    buttons:Dock(BOTTOM)
    buttons:SetTall(PD.H(50))
    buttons.Paint = function() end

    local accept = PD.Button("ANNEHMEN", buttons, function() AnswerInvite(true) end, {accent = PD.Theme.Colors.StatusActive})
    accept:Dock(LEFT)
    accept:SetWide(PD.W(185))

    local decline = PD.Button("ABLEHNEN", buttons, function() AnswerInvite(false) end)
    decline:Dock(RIGHT)
    decline:SetWide(PD.W(185))

    -- Läuft die Einladung ab, verschwindet das Fenster ohne Antwort.
    local frame = inviteFrame
    timer.Simple(timeout, function()
        if IsValid(frame) then frame:Remove() end
    end)
end)

hook.Add("PD.Interaction.Requested", "PD.List.Interaction.Answer", function(ent_class)
    PD.IA.AddEntityActions(PD.List.Interactions[ent_class], "Faction")
end)

net.Receive("PD.List.SendData", function()
    local tbl = net.ReadTable()

    factionTable = tbl
end)

function PD.List:GetPlayerData(ply)
    if not IsValid(ply) then
        return
    end

    local tbl = factionTable[ply:SteamID64()]
    if not istable(tbl) then
        return
    end

    return tbl.unit, tbl.subunit, tbl.job
end

function PD.List:GetAllData()
    return factionTable
end

concommand.Add("pd_list", function(ply)
    PrintTable(PD.List:GetAllData())

    PD.LOGS.Add("[PD.List]", "List Data concommand wurde aufgerufen von " .. ply:Nick(), Color(255, 255, 255))
end)

