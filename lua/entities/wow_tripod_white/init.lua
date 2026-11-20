AddCSLuaFile("shared.lua")
include("shared.lua")
function ENT:AttackTarget(target)
    WOWTripods.WhiteAttack(self, target)
end
