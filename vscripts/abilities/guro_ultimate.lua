LinkLuaModifier("modifier_guro_ultimate_slow", "modifiers/modifier_guro_ultimate_slow", LUA_MODIFIER_MOTION_NONE)

guro_ultimate = class({})

function guro_ultimate:GetAOERadius()
    return self:GetSpecialValueFor("cast_radius")
end

function guro_ultimate:OnSpellStart()
    local caster = self:GetCaster()
    local point  = self:GetCursorPosition()
    local cast_radius = self:GetSpecialValueFor("cast_radius")
    local total_bombs = self:GetSpecialValueFor("total_bombs")
    local interval    = self:GetSpecialValueFor("bomb_interval")

    EmitSoundOn("Hero_Gyrocopter.CallDown.Fire", caster)

    -- Запускаем бомбардировку
    for i = 1, total_bombs do
        local delay = i * interval
        Timers:CreateTimer(delay, function()
            if not caster or caster:IsNull() then return end
            
            -- Вычисляем случайную точку в радиусе cast_radius
            local dist = RandomFloat(0, cast_radius)
            local angle = RandomFloat(0, 360)
            
            local offset = Vector(
                math.cos(math.rad(angle)) * dist,
                math.sin(math.rad(angle)) * dist,
                0
            )
            local drop_point = point + offset
            
            -- Вызываем функцию подготовки и падения бомбы
            self:DropBomb(drop_point)
        end)
    end
end

-- Функция, которая имитирует оригинальный Call Down: сначала круг, потом взрыв
function guro_ultimate:DropBomb(drop_point)
    local caster = self:GetCaster()
    if not caster or caster:IsNull() then return end

    -- 1. Создаем стандартный маркер падения (красный кружок)
    -- В оригинальном Call Down используется gyro_calldown_marker.vpcf
    local marker_fx = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_gyrocopter/gyro_calldown_marker.vpcf",
        PATTACH_WORLDORIGIN, nil)
    
    if marker_fx then
        ParticleManager:SetParticleControl(marker_fx, 0, drop_point)
        -- Второй контрол задает радиус круга (200)
        ParticleManager:SetParticleControl(marker_fx, 1, Vector(self:GetSpecialValueFor("bomb_radius"), 0, 0))
    end

    -- 2. Ждем немного (например, 0.5 секунды), чтобы круг был виден, и бьем
    Timers:CreateTimer(0.5, function()
        if not caster or caster:IsNull() then return end
        
        -- Убираем маркер
        if marker_fx then
            ParticleManager:DestroyParticle(marker_fx, false)
            ParticleManager:ReleaseParticleIndex(marker_fx)
        end

        -- Наносим урон и показываем взрыв
        self:Strike(drop_point)
    end)
end

function guro_ultimate:Strike(drop_point)
    local caster = self:GetCaster()
    if not caster or caster:IsNull() then return end

    local radius  = self:GetSpecialValueFor("bomb_radius")
    local damage  = self:GetSpecialValueFor("bomb_damage")
    local slow    = self:GetSpecialValueFor("slow_pct")
    local slowDur = self:GetSpecialValueFor("slow_duration")

    -- Визуальный эффект взрыва (как у оригинальной бомбы)
    local fx = ParticleManager:CreateParticle(
        "particles/units/heroes/hero_gyrocopter/gyro_calldown_first.vpcf",
        PATTACH_WORLDORIGIN, nil)
    if fx then
        ParticleManager:SetParticleControl(fx, 0, drop_point)
        ParticleManager:ReleaseParticleIndex(fx)
    end

    EmitSoundOnLocationWithCaster(drop_point, "Hero_Gyrocopter.CallDown.Damage", caster)

    -- Ищем врагов
    local enemies = FindUnitsInRadius(
        caster:GetTeamNumber(), drop_point, nil, radius,
        DOTA_UNIT_TARGET_TEAM_ENEMY,
        DOTA_UNIT_TARGET_HERO + DOTA_UNIT_TARGET_BASIC,
        DOTA_UNIT_TARGET_FLAG_NONE,
        FIND_ANY_ORDER, false)

    for _, enemy in pairs(enemies) do
        ApplyDamage({
            victim = enemy,
            attacker = caster,
            damage = damage,
            damage_type = DAMAGE_TYPE_MAGICAL,
            ability = self,
        })

        enemy:AddNewModifier(caster, self, "modifier_guro_ultimate_slow", {
            duration = slowDur,
            slow = slow,
        })
    end
end