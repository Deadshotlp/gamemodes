--[[
    Clientseite der Transportkisten: Eintraege im Interaktionsmenue und der
    Fortschrittsbalken. Ob gepackt werden darf, entscheidet der Server.
]]

local ACTION_PACK, ACTION_UNPACK = 1, 2

net.Receive("PD.Kiste.Config", function()
    PD.Kiste.Packables = net.ReadTable()
end)

local function StartJob(ent, action)
    if not IsValid(ent) then return end

    net.Start("PD.Kiste.Start")
    net.WriteEntity(ent)
    net.WriteUInt(action, 2)
    net.SendToServer()
end

-- Interaktionspunkt: der erste Bone des Modells (bei Props meist der
-- einzige). So braucht es keine Bone-Angabe in der Packliste.
local function RootBone(ent)
    local name = ent:GetBoneName(0)
    if not name or name == "" or name == "__INVALIDBONE__" then return nil end

    return name
end

hook.Add("PD.Interaction.Requested", "PD.Kiste.Interaction", function(entClass)
    local ent = PD.IA.LastEntity and PD.IA.LastEntity.ent
    if not IsValid(ent) then return end

    local bone = RootBone(ent)
    if not bone then return end

    if entClass == PD.Kiste.CrateClass then
        local name = ent:GetContentName()

        PD.IA.AddEntityActions({
            [1] = {
                id = "kiste_unpack",
                name = name ~= "" and (name .. " aufbauen") or "Auspacken",
                func = function(ply, target)
                    StartJob(target, ACTION_UNPACK)
                end,
                ad = {bone}
            }
        }, "Transportkiste")

        return
    end

    if not PD.Kiste.CanPackEntity(ent) then return end

    local packable = PD.Kiste.GetPackable(ent)

    PD.IA.AddEntityActions({
        [1] = {
            id = "kiste_pack",
            name = packable.name .. " zusammenpacken",
            func = function(ply, target)
                StartJob(target, ACTION_PACK)
            end,
            ad = {bone}
        }
    }, "Transportkiste")
end)

--------------------------------------------------------------------------------
-- Fortschrittsbalken
--------------------------------------------------------------------------------

local progress = nil -- {start, finish, label}

net.Receive("PD.Kiste.Progress", function()
    local duration = net.ReadFloat()
    local label = net.ReadString()

    if duration <= 0 then
        progress = nil
        return
    end

    progress = {start = CurTime(), finish = CurTime() + duration, label = label}
end)

hook.Add("HUDPaint", "PD.Kiste.Progress", function()
    if not progress then return end

    local now = CurTime()
    if now >= progress.finish + 0.5 then
        progress = nil
        return
    end

    local frac = math.Clamp((now - progress.start) / (progress.finish - progress.start), 0, 1)

    local w, h = PD.W(420), PD.H(26)
    local x, y = ScrW() / 2 - w / 2, ScrH() * 0.7

    draw.SimpleTextOutlined(progress.label, "MLIB.20", ScrW() / 2, y - PD.H(16), PD.Theme.Colors.Text, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 200))
    PD.DrawProgressBar(x, y, w, h, frac, PD.Theme.Colors.StatusActive, PD.Theme.Colors.BackgroundDark)

    local rest = math.max(0, progress.finish - now)
    draw.SimpleText(string.format("%.1f s  -  Bewegen bricht ab", rest), "MLIB.14", ScrW() / 2, y + h + PD.H(12), PD.Theme.Colors.TextDim, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
end)
