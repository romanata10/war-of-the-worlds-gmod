AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:AttackTarget(target)
    WOWTripods.HeatRay(self, target, self:GetPos()+Vector(0,0,195), 38)
end

local function stopGlide(self)
    self.WOTWGliding = false
    self:SetNWBool("WOTWFolded", false)
    self.loco:SetGravity(self.WOTWOldGravity or 600)
    self.loco:SetDesiredSpeed(self.MoveSpeed)
    self.WOTWNextGlide = CurTime()+14
end

function ENT:Think()
    local now = CurTime()
    if now < (self.WOTWThinkAt or 0) then return end
    self.WOTWThinkAt = now+0.06
    local pos = self:GetPos()
    local ground = util.TraceLine({start = pos, endpos = pos-Vector(0,0,390), filter = self, mask = MASK_SOLID})
    local altitude = ground.Hit and pos:Distance(ground.HitPos) or 400
    if self.WOTWGliding then
        if now >= self.WOTWGlideEnd or altitude < 85 then
            stopGlide(self)
            return
        end
        local enemy = self:FindEnemy()
        local forward = IsValid(enemy) and (enemy:GetPos()-pos):GetNormalized() or self:GetForward()
        forward.z = 0
        forward:Normalize()
        local wanted = pos + forward*17 - Vector(0,0,2.8)
        local path = util.TraceHull({start = pos, endpos = wanted,
            mins = Vector(-35,-35,0), maxs = Vector(35,35,85), filter = self, mask = MASK_SOLID})
        if path.Hit then stopGlide(self)
        elseif util.IsInWorld(wanted) then self:SetPos(wanted) end
        return
    end
    if now < (self.WOTWNextGlide or 0) then return end
    local target = self:FindEnemy()
    local escapingFall = self:GetVelocity().z < -180 and altitude > 160
    local attackFlight = IsValid(target) and self:GetPos():DistToSqr(target:GetPos()) > 550*550
    if not escapingFall and not attackFlight then return end
    self.WOTWGliding = true
    self.WOTWGlideEnd = now+1.7
    self.WOTWOldGravity = self.loco:GetGravity()
    self.loco:SetGravity(0)
    self.loco:SetDesiredSpeed(0)
    self:SetNWBool("WOTWFolded", true)
    if attackFlight and not escapingFall then
        local up = pos+Vector(0,0,120)
        local trace = util.TraceHull({start = pos, endpos = up,
            mins = Vector(-35,-35,0), maxs = Vector(35,35,85), filter = self, mask = MASK_SOLID})
        if not trace.Hit and util.IsInWorld(up) then self:SetPos(up)
        else stopGlide(self) end
    end
end

function ENT:OnRemove()
    if self.WOTWGliding then self.loco:SetGravity(self.WOTWOldGravity or 600) end
end
