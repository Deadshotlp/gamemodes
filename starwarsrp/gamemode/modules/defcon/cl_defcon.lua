-- Client
DEFCON = DEFCON or {}

local Deftext = ""

net.Receive("ChangeDefcon",function()
    id = net.ReadInt(4)
    text = net.ReadString()
    name = net.ReadString()

    -- if not DEFCON:GetID(id) then return then
        
    DEFCON.Active = DEFCON.ID[id]
    surface.PlaySound(DEFCON.Active.sound)
    
    chat.AddText(CONFIG:GetConfig("textcolor"),"Das Defcon wurde von "..name.." auf ",DEFCON.Active.col,DEFCON.Active.nr,CONFIG:GetConfig("textcolor")," gesetzt!")
    if text != "" then Deftext = text chat.AddText(Color(255,0,0),"Befehle: ",CONFIG:GetConfig("textcolor"),text) end
end)

net.Receive("SyncDefcon",function()
    id = net.ReadInt(4)
    text = net.ReadString()
    
    DEFCON.Active = DEFCON.ID[id]
    if text != "" then Deftext = text end
end)

local blur = Material("pp/blurscreen")
local function DrawBlur( x, y, w, h, layers, density, alpha )
	surface.SetDrawColor( 255, 255, 255, alpha )
	surface.SetMaterial( blur )

	for i = 1, layers do
		blur:SetFloat( "$blur", ( i / layers ) * density )
		blur:Recompute()

		render.UpdateScreenEffectTexture()
		render.SetScissorRect( x, y, x + w, y + h, true )
			surface.DrawTexturedRect( 0, 0, ScrW(), ScrH() )
		render.SetScissorRect( 0, 0, 0, 0, false )
	end
end

AddSmoothElement(PD.W(20), PD.H(20), function(smoothX, smoothY)
    if not DEFCON.Enabled then return end
    
    -- if DEFCON.Picture then
    --     surface.SetDrawColor(255,255,255,255)
    --     surface.SetMaterial(Material(DEFCON.Active.bild))
    --     surface.DrawTexturedRect(PD.W(DEFCON.XPostion) - PD.W(DEFCON.PictureSize)/2,PD.H(DEFCON.YPostion) - PD.H(DEFCON.PictureSize)/2,PD.W(DEFCON.PictureSize),PD.H(DEFCON.PictureSize))
    -- else
    --     -- draw.DrawText("Defcon: "..DEFCON.Active.nr,"MLIB.25",PD.W(DEFCON.XPostion),PD.H(DEFCON.YPostion) + PD.H(5),DEFCON.Active.col,TEXT_ALIGN_CENTER)
    --     -- draw.RoundedBox(10,PD.W(DEFCON.XPostion) - PD.W(100),PD.H(DEFCON.YPostion) + PD.H(30),PD.W(200),PD.H(3),CONFIG:GetConfig("secondarycolor"))
    --     -- draw.DrawText(DEFCON.Active.txt,"MLIB.20",PD.W(DEFCON.XPostion) ,PD.H(DEFCON.YPostion) + PD.H(35),Color(255, 255, 255),TEXT_ALIGN_CENTER)
        
    --     surface.SetFont("MLIB.25")
    --     local tw, th = surface.GetTextSize("Defcon: "..DEFCON.Active.nr)

    --     surface.SetDrawColor(DEFCON.Active.col)
    --     surface.DrawOutlinedRect(smoothX - PD.W(10), smoothY,tw + PD.W(20),PD.H(37), 3)
    --     DrawBlur(smoothX - PD.W(9.5), smoothY + PD.H(1),tw + PD.W(18),PD.H(35), 4, 4, 255)

    --     draw.DrawText("Defcon: "..DEFCON.Active.nr,"MLIB.25",smoothX, smoothY + PD.H(5),Color(255,255,255),TEXT_ALIGN_LEFT)
    --     -- draw.DrawText(DEFCON.Active.txt,"MLIB.20",PD.W(DEFCON.XPostion) ,PD.H(DEFCON.YPostion) + PD.H(35),Color(255, 255, 255),TEXT_ALIGN_LEFT)

    -- end
end)

function DEFCON:GetDefcon()
    return DEFCON.Active
end

function DEFCON:GetColor()
    return DEFCON.Active.col
end

function DEFCON:GetText()
    return Deftext
end

concommand.Add("syncdefcon",function()
    net.Start("SyncDefcon")
    net.SendToServer()

    chat.AddText(CONFIG:GetConfig("textcolor"),"Das Defcon wurde synchronisiert!")
end)

hook.Add("PlayerInitialSpawn","SyncDefcon",function()
    net.Start("SyncDefcon")
    net.SendToServer()
end)

