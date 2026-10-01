--    Advanced Draw:
--    - IMGUI Source Code: https://github.com/wyozi-gmod/imgui
--    - Draw Precache Arc
--    - Draw Line with thickness

local adraw = {}

adraw.skin = {
    background = Color(0, 0, 0, 0),
    backgroundHover = Color(0, 0, 0, 0),
    border = Color(255, 255, 255),
    borderHover = Color(255, 127, 0),
    borderPress = Color(255, 80, 0),
    foreground = Color(255, 255, 255),
    foregroundHover = Color(255, 127, 0),
    foregroundPress = Color(255, 80, 0),
}

local devCvar = GetConVar("developer")

function adraw.IsDeveloperMode()
    return not adraw.DisableDeveloperMode and devCvar:GetInt() > 0
end

local _devMode = false -- cached local variable updated once in a while

function adraw.Hook(name, id, callback)
    local hookUniqifier = debug.getinfo(4).short_src
    hook.Add(name, "adraw / " .. id .. " / " .. hookUniqifier, callback)
end

local local_player
local gState = {}

local function shouldAcceptInput()
    -- don't process input during non-main renderpass
    if render.GetRenderTarget() ~= nil then return false end
    -- don't process input if we're doing VGUI stuff (and not in context menu)
    if vgui.CursorVisible() and vgui.GetHoveredPanel() ~= g_ContextMenu then return false end

    return true
end

adraw.Hook("PreRender", "adraw / Input", function()
    -- calculate mouse state
    if shouldAcceptInput() then
        local useBind = input.LookupBinding("+use", true)
        local attackBind = input.LookupBinding("+attack", true)
        local USE = useBind and input.GetKeyCode(useBind)
        local ATTACK = attackBind and input.GetKeyCode(attackBind)
        local wasPressing = gState.pressing
        gState.pressing = (USE and input.IsButtonDown(USE)) or (ATTACK and input.IsButtonDown(ATTACK))
        gState.pressed = not wasPressing and gState.pressing
    end
end)

hook.Add("NotifyShouldTransmit", "adraw / ClearRenderBounds", function(ent, shouldTransmit)
    if not shouldTransmit then return end
    local tb = ent:GetTable()
    if not tb._adrawRBExpansion then return end
    tb._adrawRBExpansion = nil
end)

local traceResultTable = {}

local traceQueryTable = {
    output = traceResultTable,
    filter = {}
}

local function isObstructed(eyePos, hitPos, ignoredEntity)
    local q = traceQueryTable
    q.start = eyePos
    q.endpos = hitPos
    q.filter[1] = local_player
    q.filter[2] = ignoredEntity
    local tr = util.TraceLine(q)

    if tr.Hit then
        return true, tr.Entity
    else
        return false
    end
end

function adraw.Start3D2D(pos, angles, scale, distanceHide, distanceFadeStart)
    local_player = local_player or LocalPlayer()

    if gState.shutdown == true then return end

    if gState.rendering == true then
        print("[AdvancedDraw] Starting a new adraw context when previous one is still rendering" .. "Shutting down rendering pipeline to prevent crashes..")
        gState.shutdown = true

        return false
    end

    _devMode = adraw.IsDeveloperMode()
    local eyePos = local_player:EyePos()
    local eyePosToPos = pos - eyePos

    -- OPTIMIZATION: Test that we are in front of the UI
    do
        local normal = angles:Up()
        local dot = eyePosToPos:Dot(normal)

        if _devMode then
            gState._devDot = dot
        end

        -- since normal is pointing away from surface towards viewer, dot<0 is visible
        if dot >= 0 then return false end
    end

    -- OPTIMIZATION: Distance based fade/hide
    if distanceHide then
        local distance = eyePosToPos:Length()
        if distance > distanceHide then return false end

        if _devMode then
            gState._devDist = distance
            gState._devHideDist = distanceHide
        end

        if distanceHide and distanceFadeStart and distance > distanceFadeStart then
            local blend = math.min(math.Remap(distance, distanceFadeStart, distanceHide, 1, 0), 1)
            render.SetBlend(blend)
            surface.SetAlphaMultiplier(blend)
        end
    end

    gState.rendering = true
    gState.pos = pos
    gState.angles = angles
    gState.scale = scale
    cam.Start3D2D(pos, angles, scale)

    -- calculate mousepos
    if not vgui.CursorVisible() or vgui.IsHoveringWorld() then
        local tr = local_player:GetEyeTrace()
        local eyepos = tr.StartPos
        local eyenormal

        if vgui.CursorVisible() and vgui.IsHoveringWorld() then
            eyenormal = gui.ScreenToVector(gui.MousePos())
        else
            eyenormal = tr.Normal
        end

        local planeNormal = angles:Up()
        local hitPos = util.IntersectRayWithPlane(eyepos, eyenormal, pos, planeNormal)

        if hitPos then
            local obstructed, obstructer = isObstructed(eyepos, hitPos, gState.entity)

            if obstructed then
                gState.mx = nil
                gState.my = nil

                if _devMode then
                    gState._devInputBlocker = "collision " .. obstructer:GetClass() .. "/" .. obstructer:EntIndex()
                end
            else
                local diff = pos - hitPos
                -- This cool code is from Willox's keypad CalculateCursorPos
                local x = diff:Dot(-angles:Forward()) / scale
                local y = diff:Dot(-angles:Right()) / scale
                gState.mx = x
                gState.my = y
            end
        else
            gState.mx = nil
            gState.my = nil

            if _devMode then
                gState._devInputBlocker = "not looking at plane"
            end
        end
    else
        gState.mx = nil
        gState.my = nil

        if _devMode then
            gState._devInputBlocker = "not hovering world"
        end
    end

    if _devMode then
        gState._renderStarted = SysTime()
    end

    return true
end

function adraw.Entity3D2D(ent, lpos, lang, scale, ...)
    gState.entity = ent
    local ret = adraw.Start3D2D(ent:LocalToWorld(lpos), ent:LocalToWorldAngles(lang), scale, ...)

    if not ret then
        gState.entity = nil
    end

    return ret
end

local function calculateRenderBounds(x, y, w, h)
    local pos = gState.pos
    local fwd, right = gState.angles:Forward(), gState.angles:Right()
    local scale = gState.scale
    local firstCorner, secondCorner = pos + fwd * x * scale + right * y * scale, pos + fwd * (x + w) * scale + right * (y + h) * scale
    local minrb, maxrb = Vector(math.huge, math.huge, math.huge), Vector(-math.huge, -math.huge, -math.huge)
    minrb.x = math.min(minrb.x, firstCorner.x, secondCorner.x)
    minrb.y = math.min(minrb.y, firstCorner.y, secondCorner.y)
    minrb.z = math.min(minrb.z, firstCorner.z, secondCorner.z)
    maxrb.x = math.max(maxrb.x, firstCorner.x, secondCorner.x)
    maxrb.y = math.max(maxrb.y, firstCorner.y, secondCorner.y)
    maxrb.z = math.max(maxrb.z, firstCorner.z, secondCorner.z)

    return minrb, maxrb
end

function adraw.ExpandRenderBoundsFromRect(x, y, w, h)
    local ent = gState.entity

    if IsValid(ent) then
        local tb = ent:GetTable()
        -- make sure we're not applying same expansion twice
        local expansion = tb._adrawRBExpansion

        if expansion then
            local ex, ey, ew, eh = unpack(expansion)
            if ex == x and ey == y and ew == w and eh == h then return end
        end

        local minrb, maxrb = calculateRenderBounds(x, y, w, h)
        ent:SetRenderBoundsWS(minrb, maxrb)

        if _devMode then
            print("[adraw] Updated renderbounds of ", ent, " to ", minrb, "x", maxrb)
        end

        tb._adrawRBExpansion = {x, y, w, h}
    else
        if _devMode then
            print("[adraw] Attempted to update renderbounds when entity is not valid!! ", debug.traceback())
        end
    end
end

local devOffset = Vector(0, 0, 30)

local devColours = {
    background = Color(0, 0, 0, 200),
    title = Color(78, 205, 196),
    mouseHovered = Color(0, 255, 0),
    mouseUnhovered = Color(255, 0, 0),
    pos = Color(255, 255, 255),
    distance = Color(200, 200, 200, 200),
    ang = Color(255, 255, 255),
    dot = Color(200, 200, 200, 200),
    angleToEye = Color(200, 200, 200, 200),
    renderTime = Color(255, 255, 255),
    renderBounds = Color(0, 0, 255)
}

local function developerText(str, x, y, clr)
    draw.SimpleText(str, "DefaultFixedDropShadow", x, y, clr, TEXT_ALIGN_CENTER, nil)
end

local function drawDeveloperInfo()
    local camAng = local_player:EyeAngles()
    camAng:RotateAroundAxis(camAng:Right(), 90)
    camAng:RotateAroundAxis(camAng:Up(), -90)
    cam.IgnoreZ(true)
    cam.Start3D2D(gState.pos + devOffset, camAng, 0.15)
        local bgCol = devColours["background"]
        surface.SetDrawColor(bgCol.r, bgCol.g, bgCol.b, bgCol.a)
        surface.DrawRect(-100, 0, 200, 140)
        local titleCol = devColours["title"]
        developerText("adraw developer", 0, 5, titleCol)
        surface.SetDrawColor(titleCol.r, titleCol.g, titleCol.b)
        surface.DrawLine(-50, 16, 50, 16)
        local mx, my = gState.mx, gState.my
    
        if mx and my then
            developerText(string.format("mouse: hovering %d x %d", mx, my), 0, 20, devColours["mouseHovered"])
        else
            developerText(string.format("mouse: %s", gState._devInputBlocker or ""), 0, 20, devColours["mouseUnhovered"])
        end
    
        local pos = gState.pos
        developerText(string.format("pos: %.2f %.2f %.2f", pos.x, pos.y, pos.z), 0, 40, devColours["pos"])
        developerText(string.format("distance %.2f / %.2f", gState._devDist or 0, gState._devHideDist or 0), 0, 53, devColours["distance"])
        local ang = gState.angles
        developerText(string.format("ang: %.2f %.2f %.2f", ang.p, ang.y, ang.r), 0, 75, devColours["ang"])
        developerText(string.format("dot %d", gState._devDot or 0), 0, 88, devColours["dot"])
        local angToEye = (pos - local_player:EyePos()):Angle()
        angToEye:RotateAroundAxis(ang:Up(), -90)
        angToEye:RotateAroundAxis(ang:Right(), 90)
        developerText(string.format("angle to eye (%d,%d,%d)", angToEye.p, angToEye.y, angToEye.r), 0, 100, devColours["angleToEye"])
        developerText(string.format("rendertime avg: %.2fms", (gState._devBenchAveraged or 0) * 1000), 0, 120, devColours["renderTime"])
    cam.End3D2D()
    cam.IgnoreZ(false)
    local ent = gState.entity

    if not IsValid(ent) then return end
    local tb = ent:GetTable()
    if not tb._adrawRBExpansion then return end
    local ex, ey, ew, eh = unpack(tb._adrawRBExpansion)
    local minrb, maxrb = calculateRenderBounds(ex, ey, ew, eh)
    render.DrawWireframeBox(vector_origin, angle_zero, minrb, maxrb, devColours["renderBounds"])
end

function adraw.End3D2D()
    if gState then
        if _devMode then
            local renderTook = SysTime() - gState._renderStarted
            gState._devBenchTests = (gState._devBenchTests or 0) + 1
            gState._devBenchTaken = (gState._devBenchTaken or 0) + renderTook

            if gState._devBenchTests == 100 then
                gState._devBenchAveraged = gState._devBenchTaken / 100
                gState._devBenchTests = 0
                gState._devBenchTaken = 0
            end
        end

        gState.rendering = false
        cam.End3D2D()
        render.SetBlend(1)
        surface.SetAlphaMultiplier(1)

        if _devMode then
            drawDeveloperInfo()
        end

        gState.entity = nil
    end
end

function adraw.CursorPos()
    local mx, my = gState.mx, gState.my

    return mx, my
end

function adraw.IsHovering(x, y, w, h)
    local mx, my = gState.mx, gState.my

    return mx and my and mx >= x and mx <= (x + w) and my >= y and my <= (y + h)
end

function adraw.IsPressing()
    return shouldAcceptInput() and gState.pressing
end

function adraw.IsPressed()
    return shouldAcceptInput() and gState.pressed
end

local _createdFonts = {}
local _adrawFontToGmodFont = {}
local EXCLAMATION_BYTE = string.byte("!")

function adraw.xFont(font, defaultSize)
    -- special font
    if string.byte(font, 1) == EXCLAMATION_BYTE then
        local existingGFont = _adrawFontToGmodFont[font]
        if existingGFont then return existingGFont end
        -- Font not cached; parse the font
        local name, size = font:match("!([^@]+)@(.+)")

        if size then
            size = tonumber(size)
        end

        if not size and defaultSize then
            name = font:match("^!([^@]+)$")
            size = defaultSize
        end

        local fontName = string.format("adraw_%s_%d", name, size)
        _adrawFontToGmodFont[font] = fontName

        if not _createdFonts[fontName] then
            surface.CreateFont(fontName, {
                font = name,
                size = size
            })

            _createdFonts[fontName] = true
        end

        return fontName
    end

    return font
end

function adraw.DrawBox(x,y,w,h,borderWidth, borderColor)
    if borderWidth > 0 then
        surface.SetDrawColor(borderColor)
        surface.DrawRect(x, y, w, borderWidth)
        surface.DrawRect(x, y + borderWidth, borderWidth, h - borderWidth * 2)
        surface.DrawRect(x, y + h - borderWidth, w, borderWidth)
        surface.DrawRect(x + w - borderWidth + 1, y, borderWidth, h)
    end
end

function adraw.xButton(x, y, w, h, borderWidth, borderClr, hoverClr, pressColor)
    local bw = borderWidth or 1
    local bgColor = adraw.IsHovering(x, y, w, h) and adraw.skin.backgroundHover or adraw.skin.background
    local borderColor = ((adraw.IsPressing() and adraw.IsHovering(x, y, w, h)) and (pressColor or adraw.skin.borderPress)) or (adraw.IsHovering(x, y, w, h) and (hoverClr or adraw.skin.borderHover)) or (borderClr or adraw.skin.border)
    surface.SetDrawColor(bgColor)
    surface.DrawRect(x, y, w, h)

    adraw.DrawBox(x,y,w,h,bw,borderColor)

    local isHovering = adraw.IsHovering(x, y, w, h)
    return shouldAcceptInput() and isHovering and gState.pressed, isHovering
end

function adraw.xOneColorButton(x, y, w, h, borderWidth, clr)
    local bw = borderWidth or 1
    surface.SetDrawColor(clr)
    surface.DrawRect(x, y, w, h)

    if bw > 0 then
        surface.SetDrawColor(clr)
        surface.DrawRect(x, y, w, bw)
        surface.DrawRect(x, y + bw, bw, h - bw * 2)
        surface.DrawRect(x, y + h - bw, w, bw)
        surface.DrawRect(x + w - bw + 1, y, bw, h)
    end

    return shouldAcceptInput() and adraw.IsHovering(x, y, w, h) and gState.pressed
end

function adraw.xCursor(x, y, w, h)
    local fgColor = adraw.IsPressing() and adraw.skin.foregroundPress or adraw.skin.foreground
    local mx, my = gState.mx, gState.my
    if not mx or not my then return end
    if x and w and (mx < x or mx > x + w) then return end
    if y and h and (my < y or my > y + h) then return end
    local cursorSize = math.ceil(0.3 / gState.scale)
    surface.SetDrawColor(fgColor)
    surface.DrawLine(mx - cursorSize, my, mx + cursorSize, my)
    surface.DrawLine(mx, my - cursorSize, mx, my + cursorSize)
end

function adraw.xTextButton(text, font, x, y, w, h, borderWidth, color, hoverClr, pressColor)
    local fgColor = ((adraw.IsPressing() and adraw.IsHovering(x, y, w, h)) and (pressColor or adraw.skin.foregroundPress)) or (adraw.IsHovering(x, y, w, h) and (hoverClr or adraw.skin.foregroundHover)) or (color or adraw.skin.foreground)
    local clicked = adraw.xButton(x, y, w, h, borderWidth, color, hoverClr, pressColor)
    font = adraw.xFont(font, math.floor(h * 0.618))
    draw.SimpleText(text, font, x + w / 2, y + h / 2, fgColor, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

    return clicked
end

function adraw.xConButton(x, y, w, h, borderWidth, color, hoverClr, pressColor, conColor, condition)
    local fgColor
    local clicked
    if condition then
        fgColor = conColor
        clicked = adraw.xOneColorButton(x, y, w, h, borderWidth, conColor)
    else
        fgColor = ((adraw.IsPressing() and adraw.IsHovering(x, y, w, h)) and (pressColor or adraw.skin.foregroundPress)) or (adraw.IsHovering(x, y, w, h) and (hoverClr or adraw.skin.foregroundHover)) or (color or adraw.skin.foreground)
        clicked = adraw.xButton(x, y, w, h, borderWidth, color, hoverClr, pressColor)
    end

    return clicked
end

function adraw.xSymbolButton(symbol, x, y, w, h, borderWidth, color, hoverClr, pressColor)
    local fgColor = ((adraw.IsPressing() and adraw.IsHovering(x, y, w, h)) and (pressColor or adraw.skin.foregroundPress)) or (adraw.IsHovering(x, y, w, h) and (hoverClr or adraw.skin.foregroundHover)) or (color or adraw.skin.foreground)
    local clicked = adraw.xButton(x, y, w, h, borderWidth, color, hoverClr, pressColor)
    surface.SetMaterial(symbol)
    surface.SetDrawColor(fgColor)
    surface.DrawTexturedRect(x, y, w, h)

    return clicked
end

function adraw.xDrawLine(x, y, x2, y2, sz)
    local midX = (x + x2) / 2
    local midY = (y + y2) / 2

    local dx = x2 - x
    local dy = y2 - y
    local ang = -math.deg(math.atan2(dy, dx))

    local len = math.sqrt((x2 - x) ^ 2 + (y2 - y) ^ 2)
    draw.NoTexture()
    surface.DrawTexturedRectRotated(midX, midY, len, sz, ang)
end

local cached = {}

function adraw.Arc(cx, cy, radius, thickness, startang, endang, roughness, color)
    local arc = tostring(cx) .. tostring(cy) .. tostring(radius) .. tostring(thickness) .. tostring(startang) .. tostring(endang) .. tostring(roughness)
    surface.SetDrawColor(color)
    draw.NoTexture()

    if (cached[arc] == nil) then
        cached[arc] = adraw.PrecacheArc(cx, cy, radius, thickness, startang, endang, roughness)
    end

    adraw.DrawArc(cached[arc])
end

function adraw.PrecacheArc(cx, cy, radius, thickness, startang, endang, roughness)
    local triarc = {}
    local roughness = math.max(roughness or 1, 1)
    local step = roughness
    local startang, endang = startang or 0, endang or 0

    if startang > endang then
        step = math.abs(step) * -1
    end

    local inner = {}
    local r = radius - thickness

    for deg = startang, endang, step do
        local rad = math.rad(deg)
        local ox, oy = cx + (math.cos(rad) * r), cy + (-math.sin(rad) * r)

        table.insert(inner, {
            x = ox,
            y = oy,
            u = (ox - cx) / radius + .5,
            v = (oy - cy) / radius + .5,
        })
    end

    local outer = {}

    for deg = startang, endang, step do
        local rad = math.rad(deg)
        local ox, oy = cx + (math.cos(rad) * radius), cy + (-math.sin(rad) * radius)

        table.insert(outer, {
            x = ox,
            y = oy,
            u = (ox - cx) / radius + .5,
            v = (oy - cy) / radius + .5,
        })
    end

    for tri = 1, #inner * 2 do
        local p1, p2, p3
        p1 = outer[math.floor(tri / 2) + 1]
        p3 = inner[math.floor((tri + 1) / 2) + 1]

        if tri % 2 == 0 then
            p2 = outer[math.floor((tri + 1) / 2)]
        else
            p2 = inner[math.floor((tri + 1) / 2)]
        end

        table.insert(triarc, {p1, p2, p3})
    end

    return triarc
end

function adraw.DrawArc(arc)
    for _, v in ipairs(arc) do
        surface.DrawPoly(v)
    end
end

function adraw.DrawTexturedRectRotatedPoint( x, y, w, h, rot, x0, y0 )
    local c = math.cos( math.rad( rot ) )
    local s = math.sin( math.rad( rot ) )

    local newx = y0 * s - x0 * c
    local newy = y0 * c + x0 * s

    surface.DrawTexturedRectRotated( x + newx, y + newy, w, h, rot )
end

local matBlurScreen = Material("pp/blurscreen")
function adraw.Derma_DrawPanelBlur(panel, color)
    color = color or Color(10,10,10,100)
    local x, y = panel:LocalToScreen( 0, 0 )

    -- Menu cannot do blur
    if ( not MENU_DLL ) then
        surface.SetMaterial( matBlurScreen )
        surface.SetDrawColor( 255, 255, 255, 255 )

        for i = 0.33, 1, 0.33 do
            matBlurScreen:SetFloat( "$blur", 5 * i )
            matBlurScreen:Recompute()
            if ( render ) then
                render.UpdateScreenEffectTexture()
            end
            surface.DrawTexturedRect( x * -1, y * -1, ScrW(), ScrH() )
        end
    end

    surface.SetDrawColor(color)
    surface.DrawRect( x * -1, y * -1, ScrW(), ScrH() )
end

return adraw
