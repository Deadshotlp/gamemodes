include("shared.lua")
local imgui = include("library/cl_imgui.lua")

local entDoors = {}
entDoors["Level"] = 1
entDoors["Doors"] = {}

net.Receive("DoorLinker", function()
    entDoors["Doors"] = net.ReadTable()
    entDoors["Level"] = net.ReadInt(8)
end)

function ENT:Draw()
    self:DrawModel()

    local ply = LocalPlayer()
    local dist = ply:EyePos():Distance(self:GetPos())

    if imgui.Entity3D2D(self, Vector(0, 0, 13), Angle(0, 180, 90), 0.1) then
        if dist > 200 then
            imgui.End3D2D()
            return 
        end

        -- Spieler zielt auf ein Entity
        local trace = ply:GetEyeTrace()
        if trace.Hit and IsValid(trace.Entity) then
            local ent = trace.Entity
            if ent:GetClass() == "doorlinker" then
                local door = ent.LinkedDoor

                if IsValid(door) then
                    -- Grüner Umriss um verlinkte Tür
                    render.SetColorMaterial()
                    render.DrawWireframeBox(
                        door:GetPos(),
                        door:GetAngles(),
                        door:OBBMins(),
                        door:OBBMaxs(),
                        Color(30, 255, 0),
                        true
                    )

                    -- Rote Linie von linker zu Tür
                    render.DrawLine(
                        ent:GetPos() + ent:OBBCenter(), -- Startpunkt in der Mitte des Linkers
                        door:GetPos() + door:OBBCenter(), -- Zielpunkt in der Mitte der Tür
                        Color(255, 0, 0),
                        true
                    )
                end
            end
        end

        draw.SimpleText("Scanner", "MLIB.20", 0, 0, Color(255, 255, 255), TEXT_ALIGN_CENTER)
        draw.SimpleText("Benutzten", "MLIB.20", 0, 20, Color(255, 255, 255), TEXT_ALIGN_CENTER)
        
        imgui.End3D2D()
    end
end
