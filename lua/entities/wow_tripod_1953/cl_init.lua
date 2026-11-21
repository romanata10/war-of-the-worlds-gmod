include("shared.lua")
function ENT:Initialize()
    self:SetRenderBounds(Vector(-420,-420,-420), Vector(420,420,420))
end
function ENT:Draw()
    if self:GetModel() == self.ModelPath then
        self:DrawModel()
    elseif WOWTripodsRuntime then
        WOWTripodsRuntime.Draw(self, "1953")
    else
        self:DrawModel()
    end
    local position = self:GetPos()
    local camera = self:GetNWVector("WOTWCamera", position - Vector(0,0,90))
    render.SetMaterial(Material("cable/physbeam"))
    render.DrawBeam(position - Vector(0,0,32), camera, 3, 0, 1, Color(80,95,110))
    render.SetMaterial(Material("sprites/light_glow02_add"))
    render.DrawSprite(camera, 13, 13, Color(135,225,255))
    if self:GetNWInt("WOTWShield") > 0 then
        render.DrawWireframeSphere(position + Vector(0,0,70), 205, 18, 12, Color(35,120,255,160), true)
    end
end
