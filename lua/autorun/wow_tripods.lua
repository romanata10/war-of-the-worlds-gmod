if SERVER then
    AddCSLuaFile()
    AddCSLuaFile("wow_tripods_geometry.lua")
    AddCSLuaFile("wotw_new_geometry.lua")
    for _, name in ipairs(file.Find("lua/wow_tripods_mesh/*.lua", "GAME")) do
        AddCSLuaFile("wow_tripods_mesh/"..name)
    end
    util.AddNetworkString("WOWTripods_Beam")
    util.AddNetworkString("WOWTripods_Tentacles")
    WOWTripods = WOWTripods or {}

    function WOWTripods.Tentacles(from, to)
        net.Start("WOWTripods_Tentacles")
        net.WriteVector(from)
        net.WriteVector(to)
        net.SendPVS(from)
    end

    function WOWTripods.Beam(from, to, red)
        net.Start("WOWTripods_Beam")
        net.WriteVector(from)
        net.WriteVector(to)
        net.WriteBool(red)
        net.SendPVS(from)
    end

    function WOWTripods.Restore(ply)
        if not IsValid(ply) then return end
        ply:SetNWBool("WOWAssimilated", false)
        ply.WOWCapturing = nil
        timer.Remove("WOWTripods_Claw_"..ply:EntIndex())
        ply:Freeze(false)
        if ply.WOWOriginalModel then
            ply:SetModel(ply.WOWOriginalModel)
            ply.WOWOriginalModel = nil
        end
        ply:SetColor(color_white)
    end

    function WOWTripods.Assimilate(ply)
        if not IsValid(ply) or not ply:Alive() or ply:GetNWBool("WOWAssimilated") then return end
        ply.WOWOriginalModel = ply:GetModel()
        ply:SetNWBool("WOWAssimilated", true)
        ply:SetModel("models/combine_soldier.mdl")
        ply:SetColor(Color(210, 235, 255))
        ply:StripWeapons()
        ply:Give("weapon_ar2")
        ply:GiveAmmo(120, "AR2", true)
        ply:Give("weapon_stunstick")
        ply:ChatPrint("You have been assimilated. You are a Martian soldier until death.")
    end

    hook.Add("PlayerDeath", "WOWTripods_RestoreDeath", function(ply)
        if ply:GetNWBool("WOWAssimilated") or ply.WOWCapturing then WOWTripods.Restore(ply) end
    end)
    hook.Add("PlayerSpawn", "WOWTripods_RestoreSpawn", function(ply)
        if ply:GetNWBool("WOWAssimilated") or ply.WOWCapturing then WOWTripods.Restore(ply) end
    end)
    hook.Add("PlayerDisconnected", "WOWTripods_Release", function(ply)
        if ply.WOWCapturing then ply:Freeze(false) end
    end)
    hook.Add("EntityTakeDamage", "WOWTripods_NoFriendlyFire", function(victim, dmg)
        if not victim:IsPlayer() or not victim:GetNWBool("WOWAssimilated") then return end
        local attacker = dmg:GetAttacker()
        if IsValid(attacker) and attacker.WOWMartian then dmg:SetDamage(0) end
    end)
end

if CLIENT then
    local beams = {}
    local tentacles = {}
    net.Receive("WOWTripods_Tentacles", function()
        tentacles[#tentacles + 1] = {from = net.ReadVector(), to = net.ReadVector(), expires = CurTime() + 0.8}
    end)
    local material = Material("sprites/laserbeam")
    net.Receive("WOWTripods_Beam", function()
        beams[#beams + 1] = {
            from = net.ReadVector(), to = net.ReadVector(), red = net.ReadBool(),
            expires = CurTime() + 0.25
        }
    end)
    hook.Add("PostDrawTranslucentRenderables", "WOWTripods_DrawBeams", function(depth, skybox)
        if skybox then return end
        render.SetMaterial(material)
        for i = #tentacles, 1, -1 do
            local t = tentacles[i]
            if CurTime() > t.expires then
                table.remove(tentacles, i)
            else
                local side = (t.to - t.from):Cross(Vector(0,0,1)):GetNormalized()*19
                for j = 1, 4 do
                    local angle = (j - 1)*math.pi*0.5
                    local offset = side*math.cos(angle) + Vector(0,0,math.sin(angle)*19)
                    render.DrawBeam(t.from + offset, t.to + offset*0.45, 6, 0, 1, Color(90, 20, 15))
                end
            end
        end
        for i = #beams, 1, -1 do
            local beam = beams[i]
            if beam.expires < CurTime() then
                table.remove(beams, i)
            else
                local color = beam.red and Color(255, 35, 25, 255) or Color(180, 230, 255, 255)
                render.DrawBeam(beam.from, beam.to, beam.red and 14 or 8, 0, 1, color)
                if not beam.red then
                    local side = (beam.to - beam.from):Cross(Vector(0, 0, 1)):GetNormalized()*15
                    render.DrawBeam(beam.to - side*2, beam.to + side, 5, 0, 1, color)
                    render.DrawBeam(beam.to + side*2, beam.to - side, 5, 0, 1, color)
                end
            end
        end
    end)
end
