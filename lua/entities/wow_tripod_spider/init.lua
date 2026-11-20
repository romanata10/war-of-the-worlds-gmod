AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:AttackTarget(target)
    if not WOWTripods.IsHostile(target) then return end
    local origin = self:GetPos() + Vector(0, 0, 85)
    local hit = target:WorldSpaceCenter()
    local range = self:GetPos():Distance(target:GetPos())
    if range < 180 then
        if target.WOWCapturing or CurTime() < (self.WOWNextTentacle or 0) then return end
        local trace = util.TraceLine({start = origin, endpos = hit, filter = self, mask = MASK_SHOT})
        if trace.Entity ~= target then return end
        self.WOWNextTentacle = CurTime() + 2.5
        target.WOWCapturing = self
        if target:IsPlayer() then target:Freeze(true) end
        WOWTripods.Tentacles(origin, hit)
        self:EmitSound("NPC_Antlion.GuardGrowl", 90, 100)
        timer.Simple(0.8, function()
            if IsValid(target) and target.WOWCapturing == self then
                target.WOWCapturing = nil
                if target:IsPlayer() then target:Freeze(false) end
                if IsValid(self) and WOWTripods.IsHostile(target) and self:GetPos():DistToSqr(target:GetPos()) <= 210*210 then
                    local damage = DamageInfo()
                    damage:SetDamage(math.max(150, target:Health() + 1))
                    damage:SetDamageType(DMG_SLASH)
                    damage:SetAttacker(self)
                    damage:SetInflictor(self)
                    target:TakeDamageInfo(damage)
                end
            end
        end)
        return
    end
    local trace = util.TraceLine({start = origin, endpos = hit, filter = self, mask = MASK_SHOT})
    if trace.Entity ~= target then return end
    self:EmitSound("Weapon_SMG1.Single", 78, 105)
    self:FireBullets({Num = 1, Src = origin, Dir = (hit - origin):GetNormalized(), Spread = Vector(0.045, 0.045, 0), Tracer = 1, Damage = 9, Attacker = self})
end
