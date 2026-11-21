include("shared.lua")
function ENT:Initialize()
    self:SetRenderBounds(Vector(-210,-210,0), Vector(210,210,340))
end
function ENT:Draw()
    if WOTWGenerated then WOTWGenerated.Draw(self, "walker") end
end
