PD.IDCards = PD.IDCards or {}

local dragging = false
local lastX, lastY = 0, 0
local offsetX, offsetY = 0, 0
local zoom = 1
local cardStartX = 0
local hasMovedRight = false
local showEntity = nil

function PD.IDCards:CheckID()
    if IsValid(self.Menu) then
        return
    end

    self.Menu = PD.Frame("ID Card", PD.W(1000), PD.H(800), true)

    local checkZone = PD.Panel("", self.Menu)
    checkZone:SetSize(PD.W(300), PD.H(150))
    checkZone:SetPos(PD.W(350), PD.H(300))
    checkZone.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(255, 0, 0))
    end

    local card

    local function dropCard()
        card = PD.Button("", PD.IDCards.Menu, function(self)
        end, function(self, w, h)
            -- Derselbe Ausweis wie im HUD, gezeichnet in entities/weapons/idcard.lua.
            PD.IDCards.DrawCard(0, 0, w, h, LocalPlayer())
        end)

        card:SetSize(PD.W(300), PD.H(150))
        local startX = PD.IDCards.Menu:GetWide() / 2 - card:GetWide() / 2
        local startY = PD.IDCards.Menu:GetTall() / 2 - card:GetTall() / 2
        card:SetPos(startX, startY)
        cardStartX = startX
        hasMovedRight = false

        card:SetBackgroundDisabled(true)
        card:SetHoverColor(Color(0, 0, 0, 0))

        card.OnMousePressed = function(self, keyCode)
            if keyCode == MOUSE_LEFT then
                dragging = true
                offsetX = gui.MouseX() - self:GetX()
                offsetY = gui.MouseY() - self:GetY()
            end
        end

        card.OnMouseReleased = function(self, keyCode)
            if keyCode == MOUSE_LEFT then
                dragging = false
            end
        end

        card.Think = function(self)
            if dragging then
                self:SetPos(gui.MouseX() - offsetX, gui.MouseY() - offsetY)
            end

            if self:GetX() > cardStartX + 50 then
                hasMovedRight = true
            end

            local x, y = self:GetPos()
            local cx, cy = checkZone:GetPos()
            if hasMovedRight and x + self:GetWide() / 2 > cx and x < cx + checkZone:GetWide() and y + self:GetTall() / 2 >
                cy and y < cy + checkZone:GetTall() then
                checkZone.Paint = function(self, w, h)
                    draw.RoundedBox(10, 0, 0, w, h, Color(0, 255, 0))
                end

                timer.Simple(1, function()
                    PD.IDCards.Menu:Remove()
                end)

                PD.Notify("ID Karte erfolgreich überprüft!", Color(0, 255, 0))
            else
                checkZone.Paint = function(self, w, h)
                    draw.RoundedBox(10, 0, 0, w, h, Color(255, 0, 0))
                end
            end
        end
    end

    local createCard = PD.Button("ID Card raus holen", self.Menu, function(self)
        self:Remove()
        dropCard()
    end)
    createCard:SetSize(PD.W(230), PD.H(50))
    createCard:SetPos(PD.IDCards.Menu:GetWide() / 2 - createCard:GetWide() / 2,
        PD.IDCards.Menu:GetTall() - createCard:GetTall() - PD.H(10))

    local refresh = PD.Button("", self.Menu, function(self)
        if IsValid(card) then
            card:Remove()
        end
        dropCard()
    end, function(self, w, h)
        -- War ein Imgur-Bild. Jetzt gezeichnet, damit nichts mehr fehlen kann.
        surface.SetDrawColor(PD.Theme.Colors.AccentGray)
        surface.DrawOutlinedRect(0, 0, w, h, 1)
        draw.SimpleText("NEU", "MLIB.14", w / 2, h / 2, PD.Theme.Colors.Text,
            TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
    end)
    refresh:SetSize(PD.W(50), PD.H(50))
    refresh:SetPos(PD.W(10), PD.IDCards.Menu:GetTall() - createCard:GetTall() - PD.H(10))
    refresh:SetBackgroundDisabled(true)
    refresh:SetHoverColor(Color(0, 0, 0, 0))
end

net.Receive("PD.IDCards:CheckID", function()
    local target = net.ReadEntity()
    if not IsValid(target) then
        return
    end

    showEntity = target

    -- Auf genau diesen Ausweis pruefen: sonst raeumt der alte Timer einen
    -- inzwischen neu vorgezeigten gleich mit weg.
    timer.Simple(3, function()
        if showEntity == target then
            showEntity = nil
        end
    end)
end)

-- Der vorgezeigte Ausweis sitzt hoeher als der eigene aus dem SWEP, damit sich
-- beide nicht ueberdecken.
local FOREIGN_ANCHOR = 0.48

hook.Add("HUDPaint", "IDCard", function()
    if not IsValid(showEntity) then return end

    -- Die Zeichenfunktion kommt aus entities/weapons/idcard.lua. Frueher stand
    -- hier PD.DrawImgur und getColor - beides gibt es im Gamemode nicht, das
    -- Einblenden endete also jedes Mal im Fehler.
    if not isfunction(PD.IDCards.DrawCard) then return end

    local w, h = PD.W(300), PD.H(170)

    PD.IDCards.DrawCard(ScrW() - w - PD.W(20), ScrH() * FOREIGN_ANCHOR - h / 2, w, h, showEntity)
end)

