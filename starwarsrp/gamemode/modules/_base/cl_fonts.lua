-- Fonts

for i = 0, 300 do
    surface.CreateFont("MLIB_ENTS." .. i, {
        font = "Arial",
        size = i,
        weight = 300,
    })
end

