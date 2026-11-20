-- Draw the original GLB geometry even when no Source model compiler is available.
-- Only the client builds meshes; server-side physics/AI remains a normal NextBot.
local data = include("wow_tripods_geometry.lua")
local material = Material("models/wow_tripods/runtime")
local built = {red = {}, white = {}}
local function signed16(a, b)
    local n = a + b*256
    return n >= 32768 and n - 65536 or n
end
local function signed8(n)
    return n >= 128 and n - 256 or n
end
local function build(kind, index, chunk)
    local raw = util.Base64Decode(chunk[3])
    if not raw or #raw ~= chunk[2]*30 then return end
    local object = Mesh()
    mesh.Begin(object, MATERIAL_TRIANGLES, chunk[2])
    local cursor = 1
    for _ = 1, chunk[2] do
        local r, g, b = string.byte(raw, cursor, cursor + 2)
        cursor = cursor + 3
        for _ = 1, 3 do
            local x1, x2, y1, y2, z1, z2, nx, ny, nz = string.byte(raw, cursor, cursor + 8)
            cursor = cursor + 9
            mesh.Position(Vector(signed16(x1,x2)/100, signed16(y1,y2)/100, signed16(z1,z2)/100))
            mesh.Normal(Vector(signed8(nx)/127, signed8(ny)/127, signed8(nz)/127))
            mesh.Color(r, g, b, 255)
            mesh.TexCoord(0, 0, 0)
            mesh.AdvanceVertex()
        end
    end
    mesh.End()
    built[kind][index] = object
end

WOWTripodsRuntime = {}
function WOWTripodsRuntime.Draw(ent, kind)
    local chunks = data[kind]
    if not chunks then return end
    render.SetMaterial(material)
    for i, chunk in ipairs(chunks) do
        if not built[kind][i] then
            build(kind, i, chunk)
            -- Stagger the GPU upload over frames to avoid a long first-frame stall.
            break
        end
    end
    for i, chunk in ipairs(chunks) do
        local object = built[kind][i]
        if object then
            local transform = Matrix()
            transform:SetTranslation(ent:GetPos())
            transform:SetAngles(ent:GetAngles())
            if chunk[1] ~= 0 then
                transform:Translate(Vector(0, 0, 175))
                local phase = (chunk[1] - 1)*math.pi*2/3
                local rate = ent:GetVelocity():Length2D() > 12 and 0.13 or 0
                transform:Rotate(Angle(math.sin(CurTime()*6 + phase)*rate*180/math.pi, 0, 0))
            end
            cam.PushModelMatrix(transform)
            object:Draw()
            cam.PopModelMatrix()
        end
    end
end

hook.Add("ShutDown", "WOWTripods_FreeMeshes", function()
    for _, group in pairs(built) do
        for _, object in pairs(group) do object:Destroy() end
    end
end)
