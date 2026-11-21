-- Lightweight, original approximations based on supplied stills. No copied 3D assets.
-- Real 3D boxes and spheres have depth; foot targets trace the map each frame.
local metal = Material("models/debug/debugwhite")
local glow = Material("sprites/light_glow02_add")
local cache = setmetatable({}, {__mode = "k"})
local styles = {
    pendragon = {height = 285, radius = 138, legs = 3, head = Vector(37, 26, 30),
        shell = Color(77, 83, 67), limb = Color(64, 71, 62), eye = Color(205, 230, 160), width = 7, speed = 4},
    walker = {height = 155, radius = 145, legs = 4, head = Vector(75, 60, 19),
        shell = Color(34, 32, 25), limb = Color(53, 49, 36), eye = Color(95, 255, 65), width = 8, speed = 5},
    bbc2019 = {height = 285, radius = 137, legs = 3, head = Vector(76, 58, 29),
        shell = Color(16, 28, 41), limb = Color(31, 47, 58), eye = Color(50, 158, 255), width = 12, speed = 3},
    asylum2 = {height = 200, radius = 136, legs = 4, head = Vector(58, 49, 39),
        shell = Color(62, 38, 37), limb = Color(82, 52, 46), eye = Color(243, 84, 54), width = 10, speed = 5}
}

local function ellipsoid(pos, angles, size, color)
    local matrix = Matrix()
    matrix:SetTranslation(pos)
    matrix:SetAngles(angles)
    matrix:Scale(size)
    cam.PushModelMatrix(matrix)
    render.DrawSphere(Vector(0, 0, 0), 1, 14, 9, color)
    cam.PopModelMatrix()
end

local function beamBox(a, b, radius, color)
    local direction = b - a
    local length = direction:Length()
    if length < 1 then return end
    render.DrawBox(a, direction:Angle(), Vector(0, -radius, -radius),
        Vector(length, radius, radius), color)
end

WOTWGenerated = {}
function WOTWGenerated.Draw(ent, name)
    local s = styles[name]
    if not s then return end
    local pos, ang = ent:GetPos(), ent:GetAngles()
    local forward, right = ang:Forward(), ang:Right()
    local hovering = name == "walker" and math.sin(CurTime()*1.6)*4 or 0
    local body = pos + Vector(0, 0, s.height + hovering)
    if name == "walker" and ent:GetNWFloat("WOTWClimbUntil", 0) > CurTime() then
        body = body + Vector(0,0,math.sin(CurTime()*12)*4)
    end
    local moving = ent:GetVelocity():Length2D() > 12
    local state = cache[ent]
    if not state then state = {}; cache[ent] = state end
    render.SetMaterial(metal)
    for i = 1, s.legs do
        local theta = 2*math.pi*(i-1)/s.legs + math.pi/5
        local outward = forward*math.cos(theta) + right*math.sin(theta)
        local shoulder = body + outward*(s.head.x*0.76) - Vector(0,0,s.head.z*0.6)
        local folded = name == "asylum2" and ent:GetNWBool("WOTWFolded", false)
        local stride = moving and math.sin(CurTime()*s.speed + i*2*math.pi/s.legs)*26 or 0
        local desired = pos + outward*(folded and 35 or s.radius) + forward*stride
        local foot
        if folded then
            foot = desired + Vector(0,0,s.height*0.5)
        else
            local hit = util.TraceLine({start = desired + Vector(0,0,80),
                endpos = desired - Vector(0,0,350), filter = ent, mask = MASK_SOLID})
            foot = hit.Hit and hit.HitPos + hit.HitNormal*5 or desired
            if name == "walker" then
                -- Climbing contact: probe sideways as well as downwards.
                local wall = util.TraceLine({start = desired + Vector(0,0,95),
                    endpos = desired + outward*55 + Vector(0,0,95), filter = ent, mask = MASK_SOLID})
                if wall.Hit and wall.HitNormal.z < 0.6 then
                    foot = wall.HitPos + wall.HitNormal*5
                end
            end
            if moving then foot = foot + Vector(0,0,math.max(0,math.sin(CurTime()*s.speed+i*2*math.pi/s.legs))*28) end
        end
        state[i] = state[i] and LerpVector(math.min(1,FrameTime()*13),state[i],foot) or foot
        local tip = state[i]
        local knee = shoulder*0.48 + tip*0.52 + outward*(name == "pendragon" and 43 or 32)
        knee.z = math.max(knee.z, tip.z + (folded and 12 or 49))
        beamBox(shoulder, knee, s.width*1.3, s.limb)
        beamBox(knee, tip, s.width*(name == "pendragon" and 0.7 or 0.85), s.limb)
        ellipsoid(knee, Angle(0,0,0), Vector(s.width*1.4,s.width*1.4,s.width*1.4), s.shell)
        if name ~= "walker" then
            beamBox(tip + outward*8, tip-outward*12, s.width*1.2, s.shell)
        end
    end
    -- The silhouettes have independently shaded hull, cockpit, and weapon mount.
    ellipsoid(body, ang, s.head, s.shell)
    if name == "pendragon" then
        ellipsoid(body + forward*23 + Vector(0,0,13), ang, Vector(22,19,21), Color(100,110,87))
        beamBox(body + right*32, body+right*54-Vector(0,0,32), 4, s.limb)
        beamBox(body - right*32, body-right*54-Vector(0,0,32), 4, s.limb)
    elseif name == "walker" then
        ellipsoid(body-Vector(0,0,16), ang, Vector(67,61,9), s.limb)
    elseif name == "bbc2019" then
        ellipsoid(body-Vector(0,0,17), ang, Vector(58,51,13), Color(30,42,57))
    else
        for i = 1, 5 do
            local tip = body + Vector(0,0,38+i*7) + right*(i-3)*14
            beamBox(body+right*(i-3)*11, tip, 3, s.limb)
        end
    end
    local eye = body + forward*(s.head.x*0.87) + Vector(0,0, name == "walker" and 0 or 7)
    render.SetMaterial(glow)
    render.DrawSprite(eye, name == "bbc2019" and 31 or 19,
        name == "bbc2019" and 31 or 19, s.eye)
    if name == "bbc2019" and ent:GetNWFloat("WOTWPulseUntil", 0) > CurTime() then
        render.DrawWireframeSphere(body, 170, 20, 13, Color(35,170,255,180), true)
    end
end
