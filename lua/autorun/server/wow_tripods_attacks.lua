-- Shared by vanilla NextBots and the optional DrGBase versions.
WOWTripods = WOWTripods or {}

local function hostile(target)
    if not IsValid(target) or target.WOWMartian then return false end
    if target:IsPlayer() then
        return target:Alive() and not target:GetNWBool("WOWAssimilated")
    end
    return target:IsNPC() and target:Health() > 0
end
WOWTripods.IsHostile = hostile

local function clearShot(bot, target, source)
    local endpos = target:WorldSpaceCenter()
    local trace = util.TraceLine({start = source, endpos = endpos, filter = bot, mask = MASK_SHOT})
    return trace.Entity == target, endpos
end

function WOWTripods.RedAttack(bot, target)
    if not hostile(target) then return end
    local start = bot:GetPos() + Vector(0, 0, 200)
    local clear, finish = clearShot(bot, target, start)
    if not clear then return end
    WOWTripods.Beam(start, finish, true)
    bot:EmitSound("NPC_Strider.FireMinigun", 95, 85)
    local damage = DamageInfo()
    damage:SetDamage(42)
    damage:SetDamageType(DMG_ENERGYBEAM)
    damage:SetAttacker(bot)
    damage:SetInflictor(bot)
    damage:SetDamagePosition(finish)
    target:TakeDamageInfo(damage)
end

function WOWTripods.Stomp(bot)
    local pos = bot:GetPos()
    bot:EmitSound("NPC_Strider.StriderFootstep", 95, 75)
    util.ScreenShake(pos, 8, 5, 0.4, 300)
    for _, victim in ipairs(ents.FindInSphere(pos, 125)) do
        if hostile(victim) and victim:GetPos():DistToSqr(pos) <= 125*125 then
            local trace = util.TraceLine({start = pos + Vector(0, 0, 50), endpos = victim:WorldSpaceCenter(), filter = bot})
            if trace.Entity == victim then
                local damage = DamageInfo()
                damage:SetDamage(35)
                damage:SetDamageType(DMG_CRUSH)
                damage:SetAttacker(bot)
                damage:SetInflictor(bot)
                victim:TakeDamageInfo(damage)
                if victim:IsPlayer() then
                    local direction = victim:GetPos() - pos
                    direction.z = 0
                    if direction:LengthSqr() > 1 then
                        victim:SetVelocity(direction:GetNormalized()*230 + Vector(0, 0, 150))
                    end
                end
            end
        end
    end
end

local function capturePlayer(bot, target)
    if target.WOWCapturing then return end
    target.WOWCapturing = bot
    target:Freeze(true)
    local id = "WOWTripods_Claw_"..target:EntIndex()
    local ticks = 0
    timer.Create(id, 0.05, 25, function()
        local valid = IsValid(target) and target:Alive() and IsValid(bot)
        if valid then valid = target.WOWCapturing == bot and bot:GetPos():DistToSqr(target:GetPos()) < 420*420 end
        if not valid then
            timer.Remove(id)
            if IsValid(target) and target.WOWCapturing == bot then
                target:Freeze(false)
                target.WOWCapturing = nil
            end
            return
        end
        ticks = ticks + 1
        local start = bot:GetPos() + Vector(0, 0, 175)
        local hold = bot:GetPos() + bot:GetForward()*65 + Vector(0, 0, 95)
        WOWTripods.Beam(start, target:WorldSpaceCenter(), false)
        target:SetPos(LerpVector(0.16, target:GetPos(), hold))
        if ticks >= 25 then
            timer.Remove(id)
            target:Freeze(false)
            target.WOWCapturing = nil
            WOWTripods.Assimilate(target)
        end
    end)
end

function WOWTripods.WhiteAttack(bot, target)
    if not hostile(target) then return end
    local dist = bot:GetPos():Distance(target:GetPos())
    -- The claw only reaches 360 units. The feet can stomp at close range.
    if dist <= 115 and math.random(2) == 1 then
        WOWTripods.Stomp(bot)
        return
    end
    if dist > 360 then return end
    local start = bot:GetPos() + Vector(0, 0, 175)
    local clear, finish = clearShot(bot, target, start)
    if not clear then return end
    WOWTripods.Beam(start, finish, false)
    bot:EmitSound("NPC_Strider.Charge", 90, 95)
    if target:IsPlayer() then
        capturePlayer(bot, target)
    elseif target:IsNPC() then
        local location = target:GetPos()
        local damage = DamageInfo()
        damage:SetDamage(math.max(1, target:Health() + 1))
        damage:SetDamageType(DMG_DISSOLVE)
        damage:SetAttacker(bot)
        damage:SetInflictor(bot)
        target:TakeDamageInfo(damage)
        timer.Simple(0, function()
            if not IsValid(bot) or not util.IsInWorld(location) then return end
            local soldier = ents.Create("wow_martian_soldier")
            if not IsValid(soldier) then return end
            soldier:SetPos(location + Vector(0, 0, 10))
            soldier:Spawn()
        end)
    end
end
