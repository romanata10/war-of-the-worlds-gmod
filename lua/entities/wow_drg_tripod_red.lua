-- Optional DrGBase edition. The independent wow_tripod_red NPC also works without DrGBase.
if not DrGBase then return end
ENT.Base = "drgbase_nextbot"
ENT.PrintName = "Красная тренога · DrGBase"
ENT.Category = "wotw mod"
ENT.Models = {"models/props_combine/combine_mine01.mdl"}
ENT.SpawnHealth = 1400
ENT.RagdollOnDeath = false
ENT.CollisionBounds = Vector(65, 65, 310)
ENT.ModelScale = 1.35
ENT.StepHeight = 60
ENT.JumpHeight = 0
ENT.RunSpeed = 125
ENT.WalkSpeed = 125
ENT.RangeAttackRange = 1150
ENT.MeleeAttackRange = 0
ENT.ReachEnemyRange = 1000
ENT.AvoidEnemyRange = 0
ENT.DefaultRelationship = D_HT
ENT.Factions = {"WOW_MARTIANS"}
ENT.EyeOffset = Vector(0, 0, 175)
ENT.IdleAnimation = ACT_IDLE
ENT.WalkAnimation = ACT_WALK
ENT.RunAnimation = ACT_WALK
ENT.PossessionEnabled = false

function ENT:CustomRelationship(ent)
    if ent.WOWMartian or (ent:IsPlayer() and ent:GetNWBool("WOWAssimilated")) then
        return D_LI, 100
    end
end

if SERVER then
    function ENT:CustomInitialize()
        self.WOWMartian = true
        if util.IsValidModel("models/wow_tripods/tripod_red.mdl") then
            self:SetModel("models/wow_tripods/tripod_red.mdl")
            self.IdleAnimation = "idle"
            self.WalkAnimation = "walk"
            self.RunAnimation = "walk"
        end
        self:SetColor(Color(255, 105, 105))
        self:SetNWBool("WOWRuntimeModel", self:GetModel() ~= "models/wow_tripods/tripod_red.mdl")
    end
    function ENT:OnRangeAttack(enemy)
        if CurTime() < (self.WOWNextAttack or 0) then return end
        self.WOWNextAttack = CurTime() + 2.5
        WOWTripods.RedAttack(self, enemy)
    end
    function ENT:OnTakeDamage(dmg)
        local attacker = dmg:GetAttacker()
        if IsValid(attacker) and (attacker.WOWMartian or
            (attacker:IsPlayer() and attacker:GetNWBool("WOWAssimilated"))) then
            dmg:SetDamage(0)
        end
    end
else
    function ENT:CustomInitialize()
        self:SetRenderBounds(Vector(-165,-165,0), Vector(165,165,410))
    end
    function ENT:Draw()
        if self:GetNWBool("WOWRuntimeModel") and WOWTripodsRuntime then
            WOWTripodsRuntime.Draw(self, "red")
        else
            self:DrawModel()
        end
    end
end

AddCSLuaFile()
DrGBase.AddNextbot(ENT)
