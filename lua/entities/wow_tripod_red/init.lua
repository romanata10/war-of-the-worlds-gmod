AddCSLuaFile("shared.lua")
include("shared.lua")
function ENT:AttackTarget(target)
    WOWTripods.RedAttack(self, target)
end
