include("shared.lua")
function ENT:Initialize()
    self:SetRenderBounds(Vector(-125,-125,0), Vector(125,125,220))
end
function ENT:Draw()
    if self:GetModel() == self.ModelPath then
        self:DrawModel()
    elseif WOWTripodsRuntime then
        WOWTripodsRuntime.Draw(self, "spider")
    else
        self:DrawModel()
    end
end
