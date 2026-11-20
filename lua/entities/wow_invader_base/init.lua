AddCSLuaFile("shared.lua")
AddCSLuaFile("cl_init.lua")
include("shared.lua")

local function enemy(candidate)
    return WOWTripods.IsHostile(candidate)
end

function ENT:Initialize()
    local model = self.ModelPath
    if not util.IsValidModel(model) then
        model = "models/props_combine/combine_mine01.mdl"
        if not self.WOWModelWarning then
            print("[Tripods] No compiled " .. self.ModelPath .. "; rendering original GLB on clients with the runtime mesh.")
            self.WOWModelWarning = true
        end
    end
    self:SetModel(model)
    if self.ModelTint then self:SetColor(self.ModelTint) end
    self:SetHealth(self.HealthAmount)
    self:SetMaxHealth(self.HealthAmount)
    self:SetSolid(SOLID_BBOX)
    self:SetCollisionGroup(COLLISION_GROUP_NPC)
    if self.IsTripod then
        self:SetCollisionBounds(Vector(-45, -45, 0), Vector(45, 45, 220))
    else
        self:SetCollisionBounds(Vector(-18, -18, 0), Vector(18, 18, 74))
    end
    self.loco:SetStepHeight(self.IsTripod and 60 or 18)
    self.loco:SetJumpHeight(0)
    self.loco:SetDesiredSpeed(self.MoveSpeed)
    self.loco:SetAcceleration(self.MoveSpeed * 3)
    self.loco:SetDeceleration(self.MoveSpeed * 3)
    self.WOWMartian = true
end

function ENT:FindEnemy()
    local nearest, distance = nil, self.SearchRadius * self.SearchRadius
    for _, ent in ipairs(ents.FindInSphere(self:GetPos(), self.SearchRadius)) do
        if enemy(ent) then
            local d = self:GetPos():DistToSqr(ent:GetPos())
            if d < distance then
                nearest, distance = ent, d
            end
        end
    end
    return nearest
end

function ENT:BodyUpdate()
    local walking = self:GetVelocity():Length2D() > 12
    local sequence = walking and "walk" or "idle"
    if self.WOWSequence ~= sequence then
        self:ResetSequence(sequence)
        self.WOWSequence = sequence
    end
    self:FrameAdvance()
end

function ENT:RunBehaviour()
    while true do
        local target = self:FindEnemy()
        if IsValid(target) then
            local path = Path("Follow")
            path:SetMinLookAheadDistance(150)
            path:SetGoalTolerance(self.AttackRange * 0.7)
            path:Compute(self, target:GetPos())
            local repath = 0
            while IsValid(self) and enemy(target) do
                local range = self:GetPos():Distance(target:GetPos())
                if range <= self.AttackRange and self:Visible(target) then
                    self.loco:FaceTowards(target:GetPos())
                    if CurTime() >= (self.WOWNextAttack or 0) then
                        self.WOWNextAttack = CurTime() + self.AttackDelay
                        self:AttackTarget(target)
                    end
                elseif path:IsValid() then
                    if CurTime() >= repath then
                        path:Compute(self, target:GetPos())
                        repath = CurTime() + 1
                    end
                    path:Update(self)
                else
                    break
                end
                if range > self.SearchRadius * 1.5 then break end
                coroutine.yield()
            end
        else
            coroutine.wait(0.5)
        end
        coroutine.yield()
    end
end

function ENT:AttackTarget(target) end

function ENT:OnInjured(dmg)
    local attacker = dmg:GetAttacker()
    if IsValid(attacker) and (attacker.WOWMartian or (attacker:IsPlayer() and attacker:GetNWBool("WOWAssimilated"))) then
        dmg:SetDamage(0)
    end
end

function ENT:OnKilled(dmg)
    self:BecomeRagdoll(dmg)
end

function ENT:OnStuck()
    self.loco:ClearStuck()
end
