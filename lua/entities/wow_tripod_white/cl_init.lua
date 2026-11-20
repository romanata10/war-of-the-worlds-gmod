include("shared.lua")
function ENT:Initialize()
    self:SetRenderBounds(Vector(-115, -115, 0), Vector(115, 115, 300))
end
function ENT:Draw()
    if self:GetModel() == self.ModelPath then
        self:DrawModel()
    elseif WOWTripodsRuntime then
        WOWTripodsRuntime.Draw(self, "white")
    else
        self:DrawModel()
    end
end
