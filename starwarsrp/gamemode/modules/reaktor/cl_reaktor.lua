PD.REAKTOR = PD.REAKTOR or {}

local fuel, hitze, cool = 0, 0, 0

-- Alle 10 Sekunden werden die Werte geupdatet
timer.Create("PD.REAKTOR:Tick",10,0,function()
    net.Start("PD.REAKTOR:GetInfo")
    net.SendToServer()
end)

net.Receive("PD.REAKTOR:GetInfo",function()
    fuel = net.ReadInt(32)
    hitze = net.ReadInt(32)
    cool = net.ReadInt(32)
end)

net.Receive("PD.REAKTOR:ExtensiveLights", function()
    local shouldrender = false
    render.RedownloadAllLightmaps(shouldrender, shouldrender)
end)

function PD.REAKTOR:Menu()
    if IsValid(base) then return end

    base = PG.Frame("Reaktor Menu", PG.W(1000), PG.H(700), true)


end

net.Receive("PD.REAKTOR:Open",function()
    PD.REAKTOR:Menu()
end)

hook.Add("Tick","PD.REAKTORMenu",function()
    -- PD.REAKTOR:Menu()
end)

if base then base:Remove() end

function PD.REAKTOR:GetFuel()
    return fuel
end

function PD.REAKTOR:GetHitze()
    return hitze
end

function PD.REAKTOR:GetCool()
    return cool
end

function PD.REAKTOR:SetFuel(was, f)
    net.Start("PD.REAKTOR:SetInfo")
        net.WriteString(was)
        net.WriteInt(f,32)
    net.SendToServer()
end 

function PD.REAKTOR:SetHitze(was, f)
    net.Start("PD.REAKTOR:SetInfo")
        net.WriteString(was)
        net.WriteInt(f,32)
    net.SendToServer()
end

function PD.REAKTOR:SetCool(was, f)
    net.Start("PD.REAKTOR:SetInfo")
        net.WriteString(was)
        net.WriteInt(f,32)
    net.SendToServer()
end

