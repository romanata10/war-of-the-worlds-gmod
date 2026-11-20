AddCSLuaFile("shared.lua")
include("shared.lua")
function ENT:AttackTarget(target)
    if not IsValid(target) then return end
    self:EmitSound("Weapon_AR2.Single", 80, 95)
    self:FireBullets({Num = 1, Src = self:WorldSpaceCenter(), Dir = (target:WorldSpaceCenter() - self:WorldSpaceCenter()):GetNormalized(), Spread = Vector(0.04, 0.04, 0), Tracer = 1, Damage = 8, Attacker = self})
end
