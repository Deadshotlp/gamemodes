PD.IDCards = PD.IDCards or {}
 
local dragging = false
local lastX, lastY = 0, 0
local offsetX, offsetY = 0, 0
local zoom = 1
local cardStartX = 0
local hasMovedRight = false
local showEntity = nil

function PD.IDCards:CheckID()
    if IsValid(self.Menu) then return end
    
    self.Menu = PD.Frame("ID Card", PD.W(1000), PD.H(800), true)
    
    local checkZone = PD.Panel("", self.Menu)
    checkZone:SetSize(PD.W(300), PD.H(150))
    checkZone:SetPos(PD.W(350), PD.H(300))
    checkZone.Paint = function(self, w, h)
        draw.RoundedBox(10, 0, 0, w, h, Color(255, 0, 0))
    end
    
    local function dropCard()
        card = PD.Button("", PD.IDCards.Menu, function(self) end, function(self, w, h)
            PD.DrawImgur(0, 0, w, h, "N9FDPCL")

            local jobID, jobName = LocalPlayer():GetJob()
            draw.SimpleText(LocalPlayer():Nick(), "MLIB.15", w/2 - PD.W(30), h/2 - PD.H(5), Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
            draw.SimpleText(jobName.unit .. " | " .. jobID, "MLIB.15", w/2 - PD.W(30), h/2 + PD.H(50), Color(255, 255, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        end)
        
        card:SetSize(PD.W(300), PD.H(150))
        local startX = PD.IDCards.Menu:GetWide()/2 - card:GetWide()/2
        local startY = PD.IDCards.Menu:GetTall()/2 - card:GetTall()/2
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
            if hasMovedRight and x + self:GetWide() / 2 > cx and x < cx + checkZone:GetWide() and y + self:GetTall() / 2 > cy and y < cy + checkZone:GetTall() then
                checkZone.Paint = function(self, w, h)
                    draw.RoundedBox(10, 0, 0, w, h, Color(0, 255, 0))
                end

                timer.Simple(1, function()
                    PD.IDCards.Menu:Remove()
                end)
                
                PD.Notify("ID Card erfolgreich überprüft!", Color(0, 255, 0))
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
    createCard:SetPos(PD.IDCards.Menu:GetWide()/2 - createCard:GetWide()/2, PD.IDCards.Menu:GetTall() - createCard:GetTall() - PD.H(10))

    local refresh = PD.Button("", self.Menu, function(self)
        if IsValid(card) then
            card:Remove()
        end
        dropCard()
    end, function(self, w, h)
        PD.DrawImgur(0, 0, w, h, "gLHfh59")
    end)
    refresh:SetSize(PD.W(50), PD.H(50))
    refresh:SetPos(PD.W(10), PD.IDCards.Menu:GetTall() - createCard:GetTall() - PD.H(10))
    refresh:SetBackgroundDisabled(true)
    refresh:SetHoverColor(Color(0, 0, 0, 0))
end

net.Receive("PD.IDCards:CheckID", function()
    local target = net.ReadEntity()
    if not IsValid(target) then return end

    showEntity = target

    timer.Simple(3, function()
        if IsValid(showEntity) then
            showEntity = nil
        end
    end)
end)

hook.Add("HUDPaint", "IDCard", function()
    if IsValid(showEntity) then
        PD.DrawImgur(ScrW() - PD.W(310), ScrH() / 2 - PD.H(75), PD.W(300), PD.H(150), "N9FDPCL")

        local jobName, jobTable = showEntity:GetJob()
        draw.SimpleText(showEntity:Nick(), "MLIB.17", ScrW() - PD.W(190), ScrH() / 2 - PG.H(5), PD.UI.Colors["Text"], TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
        draw.SimpleText(jobTable.unit .. " | " .. jobName, "MLIB.17", ScrW() - PD.W(190), ScrH() / 2 + PG.H(50), PD.UI.Colors["Text"], TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)


    end
end)

