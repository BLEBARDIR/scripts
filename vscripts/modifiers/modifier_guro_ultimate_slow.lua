modifier_guro_ultimate_slow = class({})

function modifier_guro_ultimate_slow:IsDebuff()   return true  end
function modifier_guro_ultimate_slow:IsHidden()   return false end
function modifier_guro_ultimate_slow:IsPurgable() return true  end

function modifier_guro_ultimate_slow:OnCreated(params)
    -- Убрали проверку IsServer, чтобы значения работали и на клиенте
    if params and params.slow then
        self.slow = params.slow
    else
        self.slow = 30 -- значение по умолчанию
    end
end

function modifier_guro_ultimate_slow:DeclareFunctions()
    return { MODIFIER_PROPERTY_MOVESPEED_BONUS_PERCENTAGE }
end

function modifier_guro_ultimate_slow:GetModifierMoveSpeedBonus_Percentage()
    -- Добавили страховку or 30, чтобы никогда не было ошибки, если slow вдруг пустой
    return -(self.slow or 30)
end