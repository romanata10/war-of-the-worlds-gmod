AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:AttackTarget(target)
    if not WOWTripods.IsHostile(target) then return end
    if self:GetPos():DistToSqr(target:GetPos()) < 440*440 and CurTime() >= (self.WOTWNextPulse or 0) then
        self.WOTWNextPulse = CurTime()+12
        self:SetNWFloat("WOTWPulseUntil", CurTime()+0.65)
        self:EmitSound("NPC_Strider.Charge", 90, 110)
        util.ScreenShake(self:GetPos(), 6, 4, 0.5, 450)
        for _, victim in ipairs(ents.FindInSphere(self:GetPos(), 440)) do
            if WOWTripods.IsHostile(victim) then
                local trace = util.TraceLine({start = self:GetPos()+Vector(0,0,230),
                    endpos = victim:WorldSpaceCenter(), filter = self, mask = MASK_SHOT})
                if trace.Entity == victim then
                    local damage = DamageInfo()
                    damage:SetDamage(18)
                    damage:SetDamageType(DMG_SHOCK)
                    damage:SetAttacker(self)
                    damage:SetInflictor(self)
                    victim:TakeDamageInfo(damage)
                    if victim:IsPlayer() then
                        local before = victim:GetLaggedMovementValue()
                        victim:SetLaggedMovementValue(0.55)
                        timer.Simple(1.5, function()
                            if IsValid(victim) then victim:SetLaggedMovementValue(before) end
                        end)
                    end
                end
            end
        end
    end
    WOWTripods.HeatRay(self, target, self:GetPos()+Vector(0,0,265), 43)
end
