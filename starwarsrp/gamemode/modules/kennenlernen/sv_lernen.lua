--

util.AddNetworkString("StartMeetRequest")
util.AddNetworkString("ConfirmMeet")
util.AddNetworkString("SendMeetData")

local pendingRequests = {}

hook.Add("KeyPress", "HandleMeetKeyPress_Server", function(ply, key)
    if key ~= IN_USE then return end
    if not IsValid(ply) or not ply:Alive() then print("Invalid player for meeting") return end

    local tr = ply:GetEyeTrace()
    if not IsValid(tr.Entity) or not tr.Entity:IsPlayer() then return end
    local target = tr.Entity
    if ply:GetPos():DistToSqr(target:GetPos()) > 10000 then return end

    -- print("Fehler erkannt SV kennenlernen")

    if pendingRequests[target] == ply then
        net.Start("ConfirmMeet")
            net.WriteEntity(ply)
            net.WriteEntity(target)
        net.Broadcast()
        pendingRequests[target] = nil
    else
        pendingRequests[ply] = target
        PD.Notify(ply:Nick() .. " möchte dich Kennenlernen", Color(255, 255, 255), false, target)
        net.Start("StartMeetRequest")
            net.WriteEntity(ply)
        net.Send(target)
    end
end)