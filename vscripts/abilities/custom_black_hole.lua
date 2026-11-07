LinkLuaModifier("modifier_custom_black_hole_thinker", "abilities/custom_black_hole", LUA_MODIFIER_MOTION_NONE)
LinkLuaModifier("modifier_custom_black_hole_aura",    "abilities/custom_black_hole", LUA_MODIFIER_MOTION_NONE)

custom_black_hole = class({})

--------------------------------------------------------------------------------
-- Ability
--------------------------------------------------------------------------------
function custom_black_hole:GetChannelTime()
    return self:GetSpecialValueFor("channel_time")
end

function custom_black_hole:GetAOERadius()
    return self:GetSpecialValueFor("start_radius")
end

function custom_black_hole:OnSpellStart()
    local caster = self:GetCaster()
    local point  = self:GetCursorPosition()

    local thinker = CreateModifierThinker(
        caster,
        self,
        "modifier_custom_black_hole_thinker",
        {
            duration      = self:GetChannelTime(),
            start_radius  = self:GetSpecialValueFor("start_radius"),
            radius_growth = self:GetSpecialValueFor("radius_growth"),
            pull_strength = self:GetSpecialValueFor("pull_strength"),
            damage        = self:GetSpecialValueFor("damage"),
            position      = point,
        },
        point,
        caster:GetTeamNumber(),
        false
    )

    self.thinker = thinker
end

function custom_black_hole:OnChannelFinish(bInterrupted)
    if self.thinker and not self.thinker:IsNull() then
        self.thinker:ForceKill(false)
    end
    self.thinker = nil
end

--------------------------------------------------------------------------------
-- Thinker
--------------------------------------------------------------------------------
modifier_custom_black_hole_thinker = class({})

function modifier_custom_black_hole_thinker:IsHidden()   return true  end
function modifier_custom_black_hole_thinker:IsPurgable() return false end

function modifier_custom_black_hole_thinker:OnCreated(params)
    if not IsServer() then return end

    self.duration      = params.duration      or 4.0
    self.start_radius  = params.start_radius  or 400
    self.radius_growth = params.radius_growth or 75
    self.pull_strength = params.pull_strength or 150
    self.damage        = params.damage        or 50

    self.current_radius = self.start_radius
    self.elapsed        = 0
    self.next_growth    = 1.0
    self.point          = params.position or self:GetParent():GetAbsOrigin()

    local thinker = self:GetParent()

    -- === ЧАСТИЦА ===
    self.particle = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_enigma/enigma_blackhole.vpcf",
        PATTACH_CUSTOMORIGIN,
        thinker)

    ParticleManager:SetParticleControl(self.particle, 0, self.point)
    ParticleManager:SetParticleControl(self.particle, 1, Vector(self.current_radius, 0, 0))

    self:AddParticle(self.particle, true, false, 0, false, false)

    -- === ЗВУК ===
    self.sound_event = StartSoundEvent("Hero_Enigma.Black_Hole", nil)

    -- Ломаем деревья в стартовом радиусе.
    GridNav:DestroyTreesAroundPoint(self.point, self.current_radius, false)

    self:StartIntervalThink(0.1)
end

function modifier_custom_black_hole_thinker:OnIntervalThink()
    if not IsServer() then return end

    local caster  = self:GetCaster()
    local ability = self:GetAbility()
    if not caster or caster:IsNull() or not ability then return end

    self.elapsed = self.elapsed + 0.1

    ---------------------------------------------------------------------------
    -- РАЗ В СЕКУНДУ: рост радиуса + ломание деревьев + урон
    ---------------------------------------------------------------------------
    if self.elapsed >= self.next_growth then
        self.next_growth    = self.next_growth + 1.0
        self.current_radius = self.current_radius + self.radius_growth

        if self.particle then
            ParticleManager:SetParticleControl(self.particle, 1, Vector(self.current_radius, 0, 0))
        end

        GridNav:DestroyTreesAroundPoint(self.point, self.current_radius, false)

        local enemies = self:GetEnemiesInRadius(ability, caster, self.current_radius)
        for _, enemy in pairs(enemies) do
            ApplyDamage({
                victim      = enemy,
                attacker    = caster,
                ability     = ability,
                damage      = self.damage,
                damage_type = DAMAGE_TYPE_MAGICAL,
            })
        end
    end

    ---------------------------------------------------------------------------
    -- СТАН как в ваниле: накладываем ОДИН РАЗ на оставшееся время канала
    ---------------------------------------------------------------------------
    local remaining = self.duration - self.elapsed
    if remaining > 0.1 then
        local enemies = self:GetEnemiesInRadius(ability, caster, self.current_radius)
        for _, enemy in pairs(enemies) do
            if not enemy:HasModifier("modifier_custom_black_hole_aura") then
                enemy:AddNewModifier(
                    caster,
                    ability,
                    "modifier_custom_black_hole_aura",
                    {
                        duration      = remaining,
                        pull_strength = self.pull_strength,
                        center        = self.point,
                    }
                )
            end
        end
    end
end

function modifier_custom_black_hole_thinker:OnDestroy()
    if not IsServer() then return end

    -- Снимаем ауру со всех, кого зацепило — чтобы прерывание канала не оставляло висящий стан.
    local caster = self:GetCaster()
    if caster and not caster:IsNull() and self.point then
        local enemies = FindUnitsInRadius(
            caster:GetTeamNumber(),
            self.point,
            nil,
            self.current_radius + 500,
            DOTA_UNIT_TARGET_TEAM_ENEMY,
            DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
            DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
            FIND_ANY_ORDER,
            false
        )
        for _, enemy in pairs(enemies) do
            enemy:RemoveModifierByName("modifier_custom_black_hole_aura")
        end
    end

    -- Звук
    if self.sound_event then
        StopSoundEvent(self.sound_event, nil)
        self.sound_event = nil
    end

    -- Частица
    if self.particle then
        ParticleManager:DestroyParticle(self.particle, true)
        ParticleManager:ReleaseParticleIndex(self.particle)
        self.particle = nil
    end
end

function modifier_custom_black_hole_thinker:GetEnemiesInRadius(ability, caster, radius)
    return FindUnitsInRadius(
        caster:GetTeamNumber(),
        self.point,
        nil,
        radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_MAGIC_IMMUNE_ENEMIES,
        FIND_ANY_ORDER,
        false
    )
end

--------------------------------------------------------------------------------
-- Aura (стан + притягивание)
--------------------------------------------------------------------------------
modifier_custom_black_hole_aura = class({})

function modifier_custom_black_hole_aura:IsDebuff()     return true  end
function modifier_custom_black_hole_aura:IsHidden()     return false end
function modifier_custom_black_hole_aura:IsPurgable()   return false end
function modifier_custom_black_hole_aura:IsStunDebuff() return true  end

function modifier_custom_black_hole_aura:GetEffectName()
    return "particles/generic_gameplay/generic_stunned.vpcf"
end

function modifier_custom_black_hole_aura:GetEffectAttachType()
    return PATTACH_OVERHEAD_FOLLOW
end

function modifier_custom_black_hole_aura:CheckState()
    return { [MODIFIER_STATE_STUNNED] = true }
end

function modifier_custom_black_hole_aura:OnCreated(params)
    if not IsServer() then return end
    self.center        = params.center
    self.pull_strength = params.pull_strength or 150
    self:StartIntervalThink(0.03)
end

function modifier_custom_black_hole_aura:OnIntervalThink()
    if not IsServer() then return end
    local parent = self:GetParent()
    if not parent or parent:IsNull() or not self.center then return end

    local pos = parent:GetAbsOrigin()
    local dir = self.center - pos
    dir.z = 0
    local dist = dir:Length2D()
    if dist < 20 then return end

    dir = dir:Normalized()
    local new_pos = pos + dir * self.pull_strength * 0.03
    new_pos.z = pos.z
    parent:SetAbsOrigin(new_pos)
end