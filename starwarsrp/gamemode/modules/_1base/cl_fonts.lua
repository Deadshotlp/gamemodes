-- Fonts

local w = 1920
local h = 1080

function PD.W(sw)
    return ScrW() * ((sw or 0) / w)
end

function PD.H(sh)
    return ScrH() * ((sh or 0) / h)
end

for i = 0, 300 do
    surface.CreateFont("MLIB_ENTS." .. i, {
        font = "Arial",
        size = PD.H(i),
        weight = 300,
    })
end

for i = 0, 300 do
    surface.CreateFont("MLIB." .. i, {
        font = "Roboto Regular",
        size = PD.H(i),
        weight = 100,
    })
end