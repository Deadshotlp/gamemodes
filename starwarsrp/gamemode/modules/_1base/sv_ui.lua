-- SV UI

-- util.AddNetworkString("PD.CameraView.Request")
-- util.AddNetworkString("PD.CameraViewUpdate")

-- net.Receive("PD.CameraView.Request", function(_, ply)
--     -- if not IsValid(ply) then return end

--     local target = Entity(2)
--     if not IsValid(target) then return end

--     net.Start("PD.CameraViewUpdate")
--         net.WriteVector(target:EyePos())
--         net.WriteAngle(target:EyeAngles())
--     net.Send(ply)
-- end)

-- util.AddNetworkString("PD.CameraView")

-- hook.Add("Think", "PD.CameraView.Update", function()
--     for _, viewer in ipairs(player.GetAll()) do
--         -- if not IsValid(viewer.PDCameraTarget) then 
--         --     if viewer:Name() == "" then
--         --         viewer.PDCameraTarget = viewer
--         --     end
--         -- end

--         local target = Entity(2)

--         if not IsValid(target) then continue end

--         net.Start("PD.CameraViewUpdate")
--             net.WriteVector(target:EyePos())
--             net.WriteAngle(target:EyeAngles())
--         net.Send(viewer)
--     end
-- end)