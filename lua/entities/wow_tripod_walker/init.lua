AddCSLuaFile("shared.lua")
include("shared.lua")

function ENT:AttackTarget(target)
    WOWTripods.HeatRay(self, target, self:GetPos()+Vector(0,0,155)+self:GetForward()*67, 33, "green")
end

-- Limited climbing: probes for wall/ledge contact, then steps upward to the lip.
-- Navigation still requires navmesh, and this isn't arbitrary vertical pathfinding.
function ENT:Think()
    if CurTime() < (self.WOTWNextWall or 0) then return end
    self.WOTWNextWall = CurTime() + 0.12
    local target = self:FindEnemy()
    if not IsValid(target) then return end
    local pos = self:GetPos()
    local direction = target:GetPos() - pos
    direction.z = 0
    if direction:LengthSqr() < 1 or direction:LengthSqr() > 1100*1100 then return end
    direction:Normalize()
    local wall = util.TraceHull({start = pos+Vector(0,0,85),
        endpos = pos+Vector(0,0,85)+direction*85,
        mins = Vector(-13,-13,-13), maxs = Vector(13,13,13), filter = self, mask = MASK_SOLID})
    if not wall.Hit or wall.HitNormal.z > 0.45 then return end
    local destination = pos+Vector(0,0,17)-direction*6
    local clear = util.TraceHull({start = pos, endpos = destination,
        mins = Vector(-28,-28,0), maxs = Vector(28,28,155), filter = self, mask = MASK_SOLID})
    if not clear.Hit and util.IsInWorld(destination) then
        self:SetPos(destination)
        self:SetNWFloat("WOTWClimbUntil", CurTime()+0.2)
    end
end
