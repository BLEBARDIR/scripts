modifier_custom_black_hole_pull = class({})

function modifier_custom_black_hole_pull:IsDebuff()     return true  end
function modifier_custom_black_hole_pull:IsHidden()     return false end
function modifier_custom_black_hole_pull:IsPurgable()   return false end
function modifier_custom_black_hole_pull:IsStunDebuff() return true  end

function modifier_custom_black_hole_pull:OnCreated(params)
    if not IsServer() then return end
    self.ability      = self:GetAbility()
    self.caster       = self:GetCaster()
    self.damage_timer = 0

    -- 🌀 Запускаем «тик» каждые 0.03 сек. Этого достаточно для плавного движения.
    self:StartIntervalThink(0.03)
end

-- Больше не нужен OnDestroy с RemoveHorizontalMotionController

function modifier_custom_black_hole_pull:OnIntervalThink()
    if not IsServer() then return end

    local parent  = self:GetParent()
    local caster  = self.caster
    local ability = self.ability

    if not parent or parent:IsNull() then self:Destroy(); return end
    if not caster or caster:IsNull() or not caster:IsChanneling() then self:Destroy(); return end
    if not ability or ability:IsNull() then self:Destroy(); return end

    -- === ПРИТЯЖЕНИЕ ===
    local center      = ability.cast_point
    local current_pos = parent:GetAbsOrigin()
    local direction   = center - current_pos
    local distance    = direction:Length()

    if distance > 5 then
        local pull_speed = ability.pull_speed or 30
        -- Шаг за один тик (0.03 сек)
        local step = pull_speed * 0.03

        -- Не проскакиваем центр
        if step > distance then step = distance end

        local new_pos = current_pos + direction:Normalized() * step
        parent:SetAbsOrigin(new_pos)
    end

    -- === УРОН (раз в damage_interval) ===
    self.damage_timer = self.damage_timer + 0.03
    if self.damage_timer >= ability.damage_interval then
        self.damage_timer = 0
        self:DealDamage()
    end
end

function modifier_custom_black_hole_pull:DealDamage()
    local parent  = self:GetParent()
    local caster  = self.caster
    local ability = self.ability

    if not parent or parent:IsNull() or not caster or caster:IsNull() then return end

    local damage = ability:GetSpecialValueFor("damage_per_second")
    if parent:IsCreep() then
        damage = damage * ability.creep_damage_multiplier
    end

    ApplyDamage({
        victim      = parent,
        attacker    = caster,
        damage      = damage,
        damage_type = DAMAGE_TYPE_MAGICAL,
        ability     = ability,
    })
end

function modifier_custom_black_hole_pull:CheckState()
    return {
        [MODIFIER_STATE_STUNNED]       = true,
        [MODIFIER_STATE_ROOTED]        = true,
        [MODIFIER_STATE_DISARMED]      = true,
        [MODIFIER_STATE_SILENCED]      = true,
        [MODIFIER_STATE_ATTACK_IMMUNE] = false,
    }
end

function modifier_custom_black_hole_pull:GetEffectName()
    return "particles/generic_gameplay/generic_stunned.vpcf"
end

function modifier_custom_black_hole_pull:GetEffectAttachType()
    return PATTACH_OVERHEAD_FOLLOW
end