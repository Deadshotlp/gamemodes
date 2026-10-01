PD.List = PD.List or {}

util.AddNetworkString("PD.List.Invite")
util.AddNetworkString("PD.List.InviteRequest")
util.AddNetworkString("PD.List.InviteAnswer")
util.AddNetworkString("PD.List.Kick")
util.AddNetworkString("PD.List.RankUp")
util.AddNetworkString("PD.List.RankDown")
util.AddNetworkString("PD.List.SendData")
util.AddNetworkString("PD.List.RequestData")
util.AddNetworkString("PD.List.AdminChange")

local function GetJobNode(unit, subunit, job)
    return PD.List.Tbl[unit]
        and PD.List.Tbl[unit].subunits
        and PD.List.Tbl[unit].subunits[subunit]
        and PD.List.Tbl[unit].subunits[subunit].jobs
        and PD.List.Tbl[unit].subunits[subunit].jobs[job]
end

local function GetDefaultJobForSubunit(unit, subunit)
    local unitNode = PD.JOBS and PD.JOBS.Jobs and PD.JOBS.Jobs[unit]
    local subNode = unitNode and unitNode.subunits and unitNode.subunits[subunit]
    if not subNode then return nil end

    for jobIndex, jobData in pairs(subNode.jobs or {}) do
        if jobData.default then
            return jobIndex
        end
    end

    return next(subNode.jobs or {})
end

local function FindTargetFromRankNet(len)
    if len <= 40 then
        net.ReadEntity() -- vom Client mitgesendeter Akteur wird verworfen; Berechtigung läuft über den echten net.Receive ply-Parameter
        return net.ReadEntity()
    end

    local charID = net.ReadString()
    return FindPlayerbyCharID(charID)
end

function PD.List:GetPlayerData(ply)
    if not IsValid(ply) then return end
    return PD.List:GetPlayerFaction(ply)
end

function PD.List:GetAllData()
    local allData = {}

    for _, v in pairs(player.GetAll()) do
        if not IsValid(v) then continue end

        local unit, subunit, job = PD.List:GetPlayerData(v)
        allData[v:SteamID64()] = {
            unit = unit,
            subunit = subunit,
            job = job
        }
    end

    return allData
end

function PD.List:SendDataToAllClient()
    net.Start("PD.List.SendData")
    net.WriteTable(PD.List:GetAllData())
    net.Broadcast()
end

function PD.List:SetPlayerData(ply, unit, sub, job)
    if not IsValid(ply) then return end
    PD.List:ChangeFaction(ply, unit, sub, job)
end

function PD.List:SetDefault(ply)
    if not IsValid(ply) then return end
    PD.List:SetPlayerDefaultFaction(ply)
end

function PD.List:SetFaction(ply, faction, sub, job)
    if not IsValid(ply) then return end
    PD.List:ChangeFaction(ply, faction, sub, job)
end

function PD.List:CheckPermission(ply)
    if not IsValid(ply) then return 0 end
    if ply:IsAdmin() then return 9999 end

    local unit, sub, job = PD.List:GetPlayerFaction(ply)
    local jobNode = GetJobNode(unit, sub, job)
    if not jobNode then return 0 end

    return tonumber(jobNode.rank or 0)
end

function PD.List:RankUP(officer, target)
    if not IsValid(officer) or not IsValid(target) then return end

    local unit, sub, job = PD.List:GetPlayerFaction(target)
    if not unit or not sub or not job then return end
    if not PD.List:CheckPermissionLevel(officer, unit, sub, job) then return end

    -- Befördert wird höchstens bis zwei Ränge unter den eigenen.
    if not officer:IsAdmin() then
        local _, _, officerJob = PD.List:GetPlayerFaction(officer)
        local officerNode = GetJobNode(unit, sub, officerJob)
        local targetNode = GetJobNode(unit, sub, job)

        if not officerNode or not targetNode then return end

        if (tonumber(targetNode.rank) or 0) + 1 > (tonumber(officerNode.rank) or 0) - 2 then
            PD.Notify("Du kannst höchstens bis zwei Ränge unter deinen eigenen befördern.", Color(200, 150, 40), false, officer)
            return
        end
    end

    PD.List:RankUp(target, unit, sub, job)

    if PD.LOGS and PD.LOGS.Add then
        local _, _, newJob = PD.List:GetPlayerFaction(target)
        PD.LOGS.Add("[Beförderung]", officer:Nick() .. " hat " .. target:Nick() .. " zu " .. tostring(newJob) .. " befördert.", Color(0, 255, 0))
    end
end

function PD.List:RankDown(officer, target)
    if not IsValid(officer) or not IsValid(target) then return end

    local unit, sub, job = PD.List:GetPlayerFaction(target)
    if not unit or not sub or not job then return end
    if not PD.List:CheckPermissionLevel(officer, unit, sub, job) then return end

    PD.List:RankDown(target, unit, sub, job)

    if PD.LOGS and PD.LOGS.Add then
        local _, _, newJob = PD.List:GetPlayerFaction(target)
        PD.LOGS.Add("[Degradierung]", officer:Nick() .. " hat " .. target:Nick() .. " zu " .. tostring(newJob) .. " degradiert.", Color(255, 165, 0))
    end
end

function PD.List:KickPlayer(officer, target)
    if not IsValid(officer) or not IsValid(target) then return end

    local unit, sub, job = PD.List:GetPlayerFaction(target)
    if not unit or not sub or not job then return end
    if not PD.List:CheckPermissionLevel(officer, unit, sub, job) then return end

    PD.List:RemoveFactionByCharID(target:GetCharacterID(), true, target)

    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("[Entfernung]", officer:Nick() .. " hat " .. target:Nick() .. " aus der Einheit entfernt.", Color(255, 0, 0))
    end
end

--[[
    Aufnahme in eine Einheit mit Zustimmung.

    Der Offizier schickt eine Einladung, der Eingeladene nimmt sie an oder
    lehnt ab. Erst beim Annehmen wird die Fraktion gesetzt - und vorher alles
    noch einmal geprüft, denn in der Zwischenzeit kann sich der Offizier
    selbst geändert oder den Server verlassen haben.
]]
local INVITE_TIMEOUT = 60
local INVITE_COOLDOWN = 3

local function CanInvite(officer)
    local unit, sub = PD.List:GetPlayerFaction(officer)
    if not unit or not sub then return false end

    local officerRank = PD.List:CheckPermission(officer)
    if officerRank < 1 and not officer:IsAdmin() then return false end

    return true, unit, sub
end

local function SubunitName(unit, sub)
    local node = PD.List.Tbl[unit] and PD.List.Tbl[unit].subunits and PD.List.Tbl[unit].subunits[sub]
    return node and node.name or tostring(sub)
end

function PD.List:InvitePlayer(officer, target)
    if not IsValid(officer) or not IsValid(target) or not target:IsPlayer() then return end
    if officer == target then return end

    local now = CurTime()
    if (officer.PD_InviteNext or 0) > now then return end
    officer.PD_InviteNext = now + INVITE_COOLDOWN

    local ok, unit, sub = CanInvite(officer)
    if not ok then return end

    if not GetDefaultJobForSubunit(unit, sub) then return end

    local targetUnit, targetSub = PD.List:GetPlayerFaction(target)
    if targetUnit == unit and targetSub == sub then
        PD.Notify(target:Nick() .. " ist bereits in deiner Einheit.", Color(200, 150, 40), false, officer)
        return
    end

    target.PD_FactionInvite = {
        officer = officer,
        unit = unit,
        sub = sub,
        expires = now + INVITE_TIMEOUT
    }

    net.Start("PD.List.InviteRequest")
        net.WriteString(officer:Nick())
        net.WriteString(SubunitName(unit, sub))
        net.WriteUInt(INVITE_TIMEOUT, 8)
    net.Send(target)

    PD.Notify("Einladung an " .. target:Nick() .. " gesendet.", Color(90, 200, 90), false, officer)
end

net.Receive("PD.List.InviteAnswer", function(_, ply)
    local accepted = net.ReadBool()

    local invite = ply.PD_FactionInvite
    ply.PD_FactionInvite = nil

    if not invite or invite.expires < CurTime() then return end

    local officer = invite.officer

    if not accepted then
        if IsValid(officer) then
            PD.Notify(ply:Nick() .. " hat die Einladung abgelehnt.", Color(200, 150, 40), false, officer)
        end
        return
    end

    if not IsValid(officer) then
        PD.Notify("Der einladende Offizier ist nicht mehr auf dem Server.", Color(255, 60, 60), false, ply)
        return
    end

    -- Offizier muss noch einladen dürfen, und zwar in dieselbe Einheit.
    local ok, unit, sub = CanInvite(officer)
    if not ok or unit ~= invite.unit or sub ~= invite.sub then
        PD.Notify("Die Einladung ist nicht mehr gültig.", Color(255, 60, 60), false, ply)
        return
    end

    local inviteJob = GetDefaultJobForSubunit(unit, sub)
    if not inviteJob then return end

    PD.List:SetPlayerFaction(ply, unit, sub, inviteJob)

    PD.Notify(ply:Nick() .. " hat die Einladung angenommen.", Color(90, 200, 90), false, officer)

    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("[Aufnahme]", officer:Nick() .. " hat " .. ply:Nick() .. " in die Einheit aufgenommen.", Color(0, 255, 0))
    end
end)

net.Receive("PD.List.Invite", function(_, ply)
    local officer = net.ReadEntity()
    local target = net.ReadEntity()

    if officer ~= ply then officer = ply end
    PD.List:InvitePlayer(officer, target)
end)

net.Receive("PD.List.Kick", function(_, ply)
    local officer = net.ReadEntity()
    local target = net.ReadEntity()

    if officer ~= ply then officer = ply end
    PD.List:KickPlayer(officer, target)
end)

net.Receive("PD.List.RankUp", function(len, ply)
    local target = FindTargetFromRankNet(len)
    PD.List:RankUP(ply, target)
end)

net.Receive("PD.List.RankDown", function(len, ply)
    local target = FindTargetFromRankNet(len)
    PD.List:RankDown(ply, target)
end)

net.Receive("PD.List.RequestData", function(_, ply)
    if not IsValid(ply) then return end

    net.Start("PD.List.SendData")
    net.WriteTable(PD.List:GetAllData())
    net.Send(ply)
end)

net.Receive("PD.List.AdminChange", function(_, ply)
    if not IsValid(ply) or not ply:IsAdmin() then return end

    local steamid = net.ReadString()
    local charID = net.ReadString()
    local unit = net.ReadString()
    local subunit = net.ReadString()
    local job = net.ReadString()

    if not steamid or steamid == "" then return end
    if not charID or charID == "" then return end

    local ok = PD.Char and PD.Char.UpdateStoredCharJobData and PD.Char:UpdateStoredCharJobData(steamid, charID, unit, subunit, job)
    if not ok then return end

    local target = FindPlayerbyID(steamid)

    if IsValid(target) and target:GetCharacterID() == charID then
        PD.List:SetPlayerFaction(target, unit, subunit, job)
    else
        local oldFactionUnit, oldFactionSub, oldFactionJob = PD.List:GetPlayerFactionByCharID(charID)

        if oldFactionUnit and oldFactionSub and oldFactionJob then
            local jobNode = PD.List.Tbl[oldFactionUnit]
                and PD.List.Tbl[oldFactionUnit].subunits
                and PD.List.Tbl[oldFactionUnit].subunits[oldFactionSub]
                and PD.List.Tbl[oldFactionUnit].subunits[oldFactionSub].jobs
                and PD.List.Tbl[oldFactionUnit].subunits[oldFactionSub].jobs[oldFactionJob]

            if jobNode and jobNode.players then
                jobNode.players[charID] = nil
            end
        end

        local resolvedUnit = nil
        local resolvedSub = nil
        local resolvedJob = nil

        for unitIndex, unitData in pairs(PD.JOBS.Jobs or {}) do
            local unitMatch = unitIndex == unit or unitData.name == unit

            if not unitMatch then
                continue
            end

            for subIndex, subData in pairs(unitData.subunits or {}) do
                local subMatch = subIndex == subunit or subData.name == subunit

                if not subMatch then
                    continue
                end

                for jobIndex, jobData in pairs(subData.jobs or {}) do
                    local jobMatch = jobIndex == job or jobData.name == job

                    if jobMatch then
                        resolvedUnit = unitIndex
                        resolvedSub = subIndex
                        resolvedJob = jobIndex
                        break
                    end
                end

                if resolvedUnit then break end
            end

            if resolvedUnit then break end
        end

        if resolvedUnit and resolvedSub and resolvedJob then
            local targetJobNode = PD.List.Tbl[resolvedUnit]
                and PD.List.Tbl[resolvedUnit].subunits
                and PD.List.Tbl[resolvedUnit].subunits[resolvedSub]
                and PD.List.Tbl[resolvedUnit].subunits[resolvedSub].jobs
                and PD.List.Tbl[resolvedUnit].subunits[resolvedSub].jobs[resolvedJob]

            if targetJobNode and targetJobNode.players then
                targetJobNode.players[charID] = {
                    name = charID,
                    steamid = steamid,
                    unit = resolvedUnit,
                    subunit = resolvedSub,
                    job = resolvedJob,
                    join = os.date("%d.%m.%Y %H:%M:%S", os.time()),
                    lastplay = os.date("%d.%m.%Y %H:%M:%S", os.time()),
                    playtime = 0
                }

                PD.List.Save()
                PD.List:SyncAll()
            end
        end
    end

    PD.List:SendDataToAllClient()

    if PD.LOGS and PD.LOGS.Add then
        PD.LOGS.Add("[Fraktionsänderung]", ply:Nick() .. " hat die Fraktion von " .. steamid .. " geändert.", Color(0, 255, 0))
    end
end)

hook.Add("PD_Faction_Change", "PD.List.SendDataOnFactionChange.Admin", function()
    PD.List:SendDataToAllClient()
end)

hook.Add("PlayerInitialSpawn", "PD.List.SendAdminFactionData.OnSpawn", function(ply)
    timer.Simple(0.4, function()
        if not IsValid(ply) then return end

        net.Start("PD.List.SendData")
        net.WriteTable(PD.List:GetAllData())
        net.Send(ply)
    end)
end)

timer.Simple(1, function()
    PD.List:SendDataToAllClient()
end)
