PD.Admin = PD.Admin or {}

function PD.Admin:Menu()
    if IsValid(mainFrame) then return end

    mainFrame = PD.Frame("Admin Menu", PD.W(800), PD.H(600), true)

end

if mainFrame then mainFrame:Remove() end

PD.Admin:Menu()

