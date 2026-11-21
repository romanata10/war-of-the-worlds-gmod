AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:AttackTarget(target)
    if not WOWTripods.IsHostile(target) then return end
    local offset = target:GetPos() - self:GetPos()
    if offset:Length() < 260 and offset:GetNormalized():Dot(self:GetForward()) < -0.25 and not target.WOWCapturing then
        local rear = self:GetPos() - self:GetForward()*47 + Vector(0,0,250)
        local targetPos = target:WorldSpaceCenter()
        local trace = util.TraceLine({start = rear, endpos = targetPos, filter = self, mask = MASK_SHOT})
        if trace.Entity == target then
            target.WOWCapturing = self
            if target:IsPlayer() then target:Freeze(true) end
            WOWTripods.Tentacles(rear, targetPos)
            self:EmitSound("NPC_Strider.Charge", 88, 80)
            timer.Simple(0.8, function()
                if not IsValid(target) or target.WOWCapturing ~= self then return end
                target.WOWCapturing = nil
                if target:IsPlayer() then target:Freeze(false) end
                if not IsValid(self) or not WOWTripods.IsHostile(target) then return end
                if self:GetPos():DistToSqr(target:GetPos()) > 300*300 then return end
                local damage = DamageInfo()
                damage:SetDamage(math.max(100, target:Health()+1))
                damage:SetDamageType(DMG_SLASH)
                damage:SetAttacker(self)
                damage:SetInflictor(self)
                target:TakeDamageInfo(damage)
            end)
            return
        end
    end
    WOWTripods.HeatRay(self, target, self:GetPos()+Vector(0,0,265), 50)
end
