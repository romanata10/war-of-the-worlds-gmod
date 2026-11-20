include("shared.lua")
function ENT:Initialize()
    self:SetRenderBounds(Vector(-165, -165, 0), Vector(165, 165, 410))
end
function ENT:Draw()
    if self:GetModel() == self.ModelPath then
        self:DrawModel()
    elseif WOWTripodsRuntime then
        WOWTripodsRuntime.Draw(self, "red")
    else
        self:DrawModel()
    end
end
