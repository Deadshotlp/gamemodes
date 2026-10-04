include("shared.lua")

-- Konsolen ohne Beschriftung; bedient wird mit E. Der Hologramm-Projektor
-- ist nur ein Ortsmarker und wird nie gezeichnet.
function ENT:Draw()
    local def = self:StationDef()
    if def and def.marker then return end

    self:DrawModel()
end
