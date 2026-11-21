AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

function ENT:Initialize()
    self.WOWMartian = true
    self:SetModel(util.IsValidModel(self.ModelPath) and self.ModelPath or "models/props_combine/combine_mine01.mdl")
    self:SetMoveType(MOVETYPE_NONE)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionGroup(COLLISION_GROUP_NPC)
    self:SetCollisionBounds(Vector(-40, -40, -35), Vector(40, 40, 55))
    self:SetHealth(4)
    self:SetNWInt("WOTWShield", 3)
    self:SetNWInt("WOTWHull", 4)
    self:SetNWVector("WOTWCamera", self:GetPos())
    self:SetPos(self:GetPos() + Vector(0, 0, 125))
    self.NextFire = 0
    self.NextThinkAI = 0
end

local function isRPG(dmg)
    local source = dmg:GetInflictor()
    if IsValid(source) and (source:GetClass() == "rpg_missile" or source:GetClass() == "weapon_rpg") then return true end
    local attacker = dmg:GetAttacker()
    if IsValid(attacker) and attacker:IsPlayer() and dmg:IsDamageType(DMG_BLAST) then
        local weapon = attacker:GetActiveWeapon()
        return IsValid(weapon) and weapon:GetClass() == "weapon_rpg"
    end
    return false
end

function ENT:OnTakeDamage(dmg)
    local attacker = dmg:GetAttacker()
    if IsValid(attacker) and (attacker.WOWMartian or (attacker:IsPlayer() and attacker:GetNWBool("WOWAssimilated"))) then return end
    if not isRPG(dmg) or CurTime() < (self.WOTWNextRPG or 0) then return end
    self.WOTWNextRPG = CurTime() + 0.25
    if self:GetNWInt("WOTWShield") > 0 then
        self:SetNWInt("WOTWShield", self:GetNWInt("WOTWShield") - 1)
        self:EmitSound("NPC_CombineMine.TurnOff", 85, 90)
    else
        local left = self:GetNWInt("WOTWHull") - 1
        self:SetNWInt("WOTWHull", left)
        self:EmitSound("NPC_Strider.Pain", 85, 80)
        if left <= 0 then
            local effect = EffectData()
            effect:SetOrigin(self:GetPos())
            util.Effect("Explosion", effect, true, true)
            self:Remove()
        end
    end
end

function ENT:Think()
    local now = CurTime()
    if now < self.NextThinkAI then
        self:NextThink(now + 0.05)
        return true
    end
    self.NextThinkAI = now + 0.05
    local pos = self:GetPos()
    local enemy, nearest = nil, 3000*3000
    for _, candidate in ipairs(ents.FindInSphere(pos, 3000)) do
        if WOWTripods.IsHostile(candidate) then
            local distance = pos:DistToSqr(candidate:GetPos())
            if distance < nearest then nearest, enemy = distance, candidate end
        end
    end
    if IsValid(enemy) then
        local goal = enemy:GetPos() + Vector(0, 0, 160)
        local direction = goal - pos
        if direction:Length() > 300 then
            local wanted = pos + direction:GetNormalized()*14
            local trace = util.TraceHull({start = pos, endpos = wanted,
                mins = Vector(-35,-35,-30), maxs = Vector(35,35,40), filter = self, mask = MASK_SOLID})
            if trace.Hit then
                wanted = pos + Vector(0, 0, 14)
                trace = util.TraceHull({start = pos, endpos = wanted,
                    mins = Vector(-35,-35,-30), maxs = Vector(35,35,40), filter = self, mask = MASK_SOLID})
            end
            if not trace.Hit and util.IsInWorld(wanted) then self:SetPos(wanted) end
        end
        local facing = (enemy:GetPos() - pos):Angle().y
        self:SetAngles(Angle(0, math.ApproachAngle(self:GetAngles().y, facing, 5), 0))
        local mount = self:GetPos() + Vector(0, 0, 65)
        local hit = enemy:WorldSpaceCenter()
        local trace = util.TraceLine({start = mount, endpos = hit, filter = self, mask = MASK_SHOT})
        if now >= self.NextFire and trace.Entity == enemy then
            self.NextFire = now + 2.5
            WOWTripods.HeatRay(self, enemy, mount, math.max(200, enemy:Health()+1))
        end
        -- Tethered scout camera probes up to 350 units away from the belly.
        local anchor = self:GetPos() - Vector(0, 0, 32)
        local desired = hit
        local delta = desired - anchor
        if delta:Length() > 350 then desired = anchor + delta:GetNormalized()*350 end
        local scan = util.TraceHull({start = anchor, endpos = desired, mins = Vector(-5,-5,-5),
            maxs = Vector(5,5,5), filter = {self, enemy}, mask = MASK_SOLID})
        self:SetNWVector("WOTWCamera", scan.HitPos)
    else
        self:SetNWVector("WOTWCamera", pos - Vector(0, 0, 90))
    end
    self:NextThink(now + 0.05)
    return true
end
