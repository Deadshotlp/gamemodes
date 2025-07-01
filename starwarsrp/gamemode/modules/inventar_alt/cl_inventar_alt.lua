PD.Inventar_Alt = PD.Inventar_Alt or {}
local Inventory = {}

local function DrawWeapons()
    local WeaponsFrame = PD.Panel("Weapons", PD.Inventar_Alt.MainFrame)
    WeaponsFrame:Dock(LEFT)
    WeaponsFrame:SetSize(PD.Inventar_Alt.MainFrame:GetWide() / 3, PD.Inventar_Alt.MainFrame:GetTall() / 2)
    WeaponsFrame:DockMargin(PD.H(5), PD.Inventar_Alt.MainFrame:GetTall() / 3, PD.H(5), PD.H(5))
    WeaponsFrame:SetBackColor(Color(0, 0, 0, 0))

    local tbl = {
        primaer = {
            name = LocalPlayer():GetActiveWeapon():GetClass()
        },
        sekundaer = {
            name = LocalPlayer():GetActiveWeapon():GetClass()
        },
        spezial = {
            name = LocalPlayer():GetActiveWeapon():GetClass()
        }
    }

    for k, v in pairs(tbl) do
        local weaponSlot = PD.Panel(v.name, WeaponsFrame, function()
            surface.SetDrawColor(255, 255, 255, 255)
        end)
        weaponSlot:SetSize(WeaponsFrame:GetWide(), WeaponsFrame:GetTall() / 3)
        -- weaponSlot:Dock(TOP)

    end

    -- local PriWeaponSlot = PD.Panel("PriWeaponSlot", WeaponsFrame, false)
    -- PriWeaponSlot:Dock(NODOCK)
    -- PriWeaponSlot:SetSize(PD.Inventar_Alt.MainFrame:GetWide() / 3, PD.Inventar_Alt.MainFrame:GetTall() / 6)
    -- PriWeaponSlot:SetPos(PD.W(5), PD.Inventar_Alt.MainFrame:GetTall() / 2 - PD.Inventar_Alt.MainFrame:GetTall() / 6)

    -- local SecWeaponSlot = PD.Panel("SecWeaponSlot", WeaponsFrame, false)
    -- SecWeaponSlot:Dock(NODOCK)
    -- SecWeaponSlot:SetSize(PD.Inventar_Alt.MainFrame:GetWide() / 3, PD.Inventar_Alt.MainFrame:GetTall() / 6)
    -- SecWeaponSlot:SetPos(PD.W(5), PD.Inventar_Alt.MainFrame:GetTall() / 2 + PD.H(50))

    -- local SpeWeaponSlot = PD.Panel("SpeWeaponSlot", WeaponsFrame, false)
    -- SpeWeaponSlot:Dock(NODOCK)
    -- SpeWeaponSlot:SetSize(PD.Inventar_Alt.MainFrame:GetWide() / 3, PD.Inventar_Alt.MainFrame:GetTall() / 6)
    -- SpeWeaponSlot:SetPos(PD.W(5),
    --     PD.Inventar_Alt.MainFrame:GetTall() / 2 + PD.Inventar_Alt.MainFrame:GetTall() / 6 + PD.H(100))
end

local function OpenInventory()
    if PD.Inventar_Alt.MainFrame then
        PD.Inventar_Alt.MainFrame = nil
    end

    PD.Inventar_Alt.MainFrame = PD.Frame(LocalPlayer():Nick(), ScrW() / 1.5, ScrH() / 1.5, true)
    PD.Inventar_Alt.MainFrame:SetBackColor(Color(3, 16, 16, 250))

    DrawWeapons()
end

net.Receive("PD.Inventar_Alt.OpenInventory", function()
    Inventory = net.ReadTable()

    OpenInventory()
end)
