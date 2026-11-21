-- Draw the original GLB geometry even when no Source model compiler is available.
-- Only the client builds meshes; server-side physics/AI remains a normal NextBot.
local data = include("wow_tripods_geometry.lua")
local newModels = include("wotw_new_geometry.lua")
for kind, entry in pairs(newModels) do data[kind] = entry.chunks end
local material = Material("models/wow_tripods/runtime")
local built = {red = {}, white = {}, ["1953"] = {}, spider = {}}
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
    local order = {3, 2, 1} -- Source front-face winding is opposite to the GLB export.
    for _ = 1, chunk[2] do
        local r, g, b = string.byte(raw, cursor, cursor + 2)
        cursor = cursor + 3
        for j = 1, 3 do
            local offset = cursor + (order[j] - 1)*9
            local x1, x2, y1, y2, z1, z2, nx, ny, nz = string.byte(raw, offset, offset + 8)
            mesh.Position(Vector(signed16(x1,x2)/100, signed16(y1,y2)/100, signed16(z1,z2)/100))
            mesh.Normal(Vector(signed8(nx)/127, signed8(ny)/127, signed8(nz)/127))
            mesh.Color(r, g, b, 255)
            mesh.TexCoord(0, 0, 0)
            mesh.AdvanceVertex()
        end
        cursor = cursor + 27
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
            local position = ent:GetPos()
            if kind == "1953" then
                position = position + Vector(0, 0, math.sin(CurTime()*1.7)*6)
            end
            transform:SetTranslation(position)
            transform:SetAngles(ent:GetAngles())
            if kind == "red" or kind == "white" then
                -- Source NPCs face +X; the imported SketchUp machines face -Y.
                transform:Rotate(Angle(0, 90, 0))
                transform:Scale(Vector(1.35, 1.35, 1.35))
            elseif kind == "1953" then
                transform:Rotate(Angle(0, 90, 0))
            elseif kind == "spider" then
                transform:Rotate(Angle(0, -90, 0))
            end
            if chunk[1] ~= 0 then
                local phase, pitch, roll, pivot
                if kind == "red" or kind == "white" then
                    phase = (chunk[1]-1)*math.pi*2/3
                    pivot = 175
                    pitch = math.sin(CurTime()*6+phase)*(ent:GetVelocity():Length2D() > 12 and 7.5 or 0)
                    roll = 0
                else
                    local new = newModels[kind]
                    pivot = new.pivot
                    phase = (chunk[1]-1)*math.pi*2/(kind == "spider" and 4 or 3)
                    if kind == "spider" then
                        local attacking = ent:GetNWFloat("WOTWAttackUntil", 0) > CurTime()
                        local moving = ent:GetVelocity():Length2D() > 12
                        pitch = math.sin(CurTime()*8+phase)*(attacking and 18 or moving and 11 or 2)
                        roll = math.cos(CurTime()*8+phase)*(attacking and 9 or moving and 5 or 1)
                    else
                        pitch = math.sin(CurTime()*2+phase)*4
                        roll = math.cos(CurTime()*2+phase)*2
                    end
                end
                transform:Translate(Vector(0, 0, pivot))
                transform:Rotate(Angle(pitch, 0, roll))
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
