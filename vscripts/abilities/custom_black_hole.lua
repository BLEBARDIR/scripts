LinkLuaModifier("modifier_custom_black_hole_pull", "abilities/modifier_custom_black_hole_pull", LUA_MODIFIER_MOTION_NONE)

custom_black_hole = class({})

function custom_black_hole:GetAOERadius()
    return self:GetSpecialValueFor("base_radius")
end

function custom_black_hole:OnSpellStart()
    local caster = self:GetCaster()
    local point  = self:GetCursorPosition()

    self.cast_point           = point
    self.channel_start_time   = GameRules:GetGameTime()
    self.current_radius       = self:GetSpecialValueFor("base_radius")
    self.max_radius           = self:GetSpecialValueFor("max_radius")
    self.radius_grow_interval = self:GetSpecialValueFor("radius_grow_interval")
    self.radius_grow_amount   = self:GetSpecialValueFor("radius_grow_amount")
    self.damage_interval      = self:GetSpecialValueFor("damage_interval")
    self.creep_damage_multiplier = self:GetSpecialValueFor("creep_damage_multiplier")
    self.pull_speed           = self:GetSpecialValueFor("pull_speed")

    self.affected_units = {}

    GridNav:DestroyTreesAroundPoint(point, self.current_radius, false)

    self:StartRadiusGrowth()
    self:StartAuraTimer()
    self:PlayEffects(point)
end

function custom_black_hole:GetRemainingChannelTime()
    local total   = self:GetChannelTime() or 0
    local elapsed = GameRules:GetGameTime() - self.channel_start_time
    return math.max(0.05, total - elapsed)
end

function custom_black_hole:StartRadiusGrowth()
    local ability = self
    local point   = self.cast_point

    Timers:CreateTimer(self.radius_grow_interval, function()
        local caster = ability:GetCaster()
        if not caster or caster:IsNull() or not caster:IsChanneling() then return nil end

        if ability.current_radius < ability.max_radius then
            ability.current_radius = math.min(
                ability.current_radius + ability.radius_grow_amount,
                ability.max_radius
            )
            GridNav:DestroyTreesAroundPoint(point, ability.current_radius, false)
        end

        ability:UpdateParticleRadius()
        return ability.radius_grow_interval
    end)
end

function custom_black_hole:StartAuraTimer()
    local ability = self
    local caster  = self:GetCaster()
    local point   = self.cast_point

    Timers:CreateTimer(0.1, function()
        if not caster or caster:IsNull() or not caster:IsChanneling() then return nil end

        local enemies = FindUnitsInRadius(
            caster:GetTeamNumber(),
            point,
            nil,
            ability.current_radius,
            DOTA_UNIT_TARGET_TEAM_ENEMY,
            DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
            DOTA_UNIT_TARGET_FLAG_NONE,
            FIND_ANY_ORDER,
            false
        )

        local remaining = ability:GetRemainingChannelTime()

        for _, enemy in pairs(enemies) do
            if not enemy:HasModifier("modifier_custom_black_hole_pull") then
                enemy:AddNewModifier(caster, ability, "modifier_custom_black_hole_pull", {
                    duration = remaining,
                })
                ability.affected_units[enemy:GetEntityIndex()] = enemy
            end
        end

        for idx, unit in pairs(ability.affected_units) do
            if not unit or unit:IsNull() or not unit:IsAlive() then
                ability.affected_units[idx] = nil
            elseif not unit:HasModifier("modifier_custom_black_hole_pull") then
                ability.affected_units[idx] = nil
            elseif (unit:GetAbsOrigin() - point):Length() > ability.current_radius * 1.15 then
                unit:RemoveModifierByName("modifier_custom_black_hole_pull")
                ability.affected_units[idx] = nil
            end
        end

        return 0.1
    end)
end

function custom_black_hole:PlayEffects(point)
    local caster = self:GetCaster()

    local fx = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_enigma/enigma_blackhole.vpcf",
        PATTACH_WORLDORIGIN,
        nil
    )
    ParticleManager:SetParticleControl(fx, 0, point)
    ParticleManager:SetParticleControl(fx, 1, Vector(self.current_radius, 1, 1))
    self.black_hole_fx = fx

    EmitSoundOn("Hero_Enigma.BlackHole", caster)
end

-- ✅ Вот этой функции не хватало!
function custom_black_hole:UpdateParticleRadius()
    if self.black_hole_fx then
        ParticleManager:SetParticleControl(
            self.black_hole_fx, 1,
            Vector(self.current_radius, 1, 1)
        )
    end
end

-- ✅ Чистим частицу и модификаторы при завершении/прерывании канала
function custom_black_hole:OnChannelFinish(bInterrupted)
    if self.black_hole_fx then
        ParticleManager:DestroyParticle(self.black_hole_fx, false)
        ParticleManager:ReleaseParticleIndex(self.black_hole_fx)
        self.black_hole_fx = nil
    end

    if self.affected_units then
        for _, unit in pairs(self.affected_units) do
            if unit and not unit:IsNull() then
                unit:RemoveModifierByName("modifier_custom_black_hole_pull")
            end
        end
        self.affected_units = {}
    end
end