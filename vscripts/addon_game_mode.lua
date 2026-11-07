require("libraries/timers")
require("BelkaMode")
if BelkaMode == nil then
	 BelkaMode = class({})
end
    print('ВСЁ РАБОТАЕТ')
HeroExpTable = {0, 400, 500, 650, 850, 1100, 1400, 1750, 2150, 3150, 3650, 4250, 4950, 5750, 7750, 8750, 9950, 11350, 12950, 16950, 18950, 21750, 24950, 28550, 36550, 52550, 84550, 148550, 276550, 532550, 1044550}
--              1  2    3    4    5    6     7     8     9     10    11    12    13    14    15    16    17    18     19     20     21     22     23     24     25     26     27     28      29      30      31 32 33 34 35 36 37 38 39 40 41 42 43 44 45 46 47 48 49 50
--              0  400  100  150  200  250   300   350   400   1000  500   600   700   800   2000  1000  1200  1400   1600   4000   2000   2800   3200   3600   8000   16000  32000  64000   12800   25600   512000
--              0, 240, 640, 1160, 1760, 2440, 3200, 4000, 4900, 5900, 7000, 8200, 9500, 10900, 12400, 14000, 15700, 17500, 19400, 21400, 23600, 26000, 28600, 31400, 34400, 38400, 43400, 49400, 56400, 63400, 70400, 77400, 84400, 91400, 98400, 105400, 112400, 119400, 126400, 133400 
--              0  240  400  520   600   680   760   800   900   1000  1100  1200  1300  1400   1500   1600   1700   1800   1900   2000
SetStartingGold = (math.random(1, 10)) * 100
function Activate()
	print (SetStartingGold * 1)
	BelkaMode:InitGameMode()
end

function BelkaMode:InitGameMode()
	GameRules:SetTreeRegrowTime(360)
	GameRules:SetGoldTickTime(0.1)
	GameRules:SetStartingGold(1000)
	GameRules:SetUseUniversalShopMode(true)
	GameRules:SetHeroSelectionTime(121)
	GameRules:SetPreGameTime(31)
	GameRules:SetStrategyTime(10)
	GameRules:SetShowcaseTime(1)
    GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_GOODGUYS, 5 )
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_BADGUYS, 5 )
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_CUSTOM_1, 5 )
	GameRules:SetCustomGameTeamMaxPlayers( DOTA_TEAM_CUSTOM_2, 5 )

	GameRules:GetGameModeEntity():SetUseCustomHeroLevels( true )
    GameRules:GetGameModeEntity():SetCustomXPRequiredToReachNextLevel( HeroExpTable )

	ListenToGameEvent('entity_killed' , Dynamic_Wrap(self , 'TreantKilled'), self)
	ListenToGameEvent('game_rules_state_change' , Dynamic_Wrap(self , 'BelkaStateChange') , self)
	ListenToGameEvent('dota_player_gained_level', Dynamic_Wrap(BelkaMode, 'OnPlayerGainedLevel'), self)
    --ListenToGameEvent('npc_spawned', Dynamic_Wrap(BelkaMode, 'OnNPCSpawned'), self)
end

function BelkaMode:BelkaStateChange(data)
	local newState = GameRules:State_Get()
	if newState == DOTA_GAMERULES_STATE_GAME_IN_PROGRESS then
		self:BelkaModeStart()
	end
end

--function BelkaMode:OnNPCSpawned(keys)
    --local unit = EntIndexToHScript(keys.entindex)
    
    -- Проверяем, что это настоящий герой (не иллюзия, не крип)
    --if unit and unit:IsRealHero() and not unit:IsIllusion() then
        
        -- Проверяем, нет ли уже этой способности (чтобы не выдать дважды при респавне)
        --if not unit:FindAbilityByName("guro_ultimate") then
            
            -- ВРЕМЕННО: удаляем старую ульту Гирокоптера, чтобы освободить слот
            --unit:RemoveAbility("gyrocopter_call_down")

            --local ability = unit:AddAbility("guro_ultimate")
            --if ability then
            --    ability:SetLevel(1)
            --    print("guro_ultimate выдан СРАЗУ при спавне герою " .. unit:GetUnitName())
            --else
            --    print("ОШИБКА: AddAbility вернул nil для guro_ultimate")
            --end
        --end
    --end
--end

function BelkaMode:TreantKilled(data)
    local killed_unit = EntIndexToHScript(data.entindex_killed)
    
    if killed_unit:GetUnitName() == 'npc_dota_radiant_forest_2' then
        local origin = killed_unit:GetAbsOrigin()
        
        -- Задержка 5 секунд перед выпадением
        Timers:CreateTimer(5.0, function()
            -- Проверяем, что позиция еще валидна (вдруг карта/юнит уже не существует)
            if not origin then return end
            
            -- Случайный угол и дистанция
            local angle = RandomFloat(0, 360)
            local distance = RandomFloat(80, 150) -- небольшая дистанция разброса
            
            local offset = Vector(
                math.cos(math.rad(angle)) * distance,
                math.sin(math.rad(angle)) * distance,
                0
            )
            
            local drop_pos = origin + offset
            
            -- Создаём Aegis
            local aegis = CreateItem("item_aegis", nil, nil)
            if aegis then
                aegis:SetPurchaseTime(0)
                
                -- Создаём на земле и анимируем "подлёт"
                local item_ent = CreateItemOnPositionSync(drop_pos, aegis)
                
                -- Если хочешь, чтобы предмет красиво "выпрыгнул" из точки смерти:
                if item_ent then
                    -- Начальная позиция - точка смерти
                    item_ent:SetAbsOrigin(origin)
                    
                    -- Плавно двигаем к целевой позиции (своеобразная "дуга" выпадения)
                    local start_pos = origin
                    local end_pos = drop_pos
                    local duration = 0.6
                    local elapsed = 0
                    
                    Timers:CreateTimer(0.03, function()
                        elapsed = elapsed + 0.03
                        local t = math.min(elapsed / duration, 1.0)
                        
                        -- Ease-out для более естественного движения
                        local eased = 1 - (1 - t) * (1 - t)
                        
                        local current = start_pos + (end_pos - start_pos) * eased
                        -- Небольшая "подброска" по высоте (парабола)
                        current.z = current.z + math.sin(t * math.pi) * 60
                        
                        if item_ent and not item_ent:IsNull() then
                            item_ent:SetAbsOrigin(current)
                        end
                        
                        if t >= 1.0 then
                            return nil -- остановить таймер
                        end
                        return 0.03
                    end)
                end
            end
        end)
    end
end

function BelkaMode:OnPlayerGainedLevel(keys)
    -- keys.player содержит индекс игрока, keys.level — новый уровень
    local player = EntIndexToHScript(keys.player)
    local level = keys.level
end

function GiveGoldPlayers(gold)
	for index = 0 , PlayerResourse:GetPlayerCount() do
		if PlayerResource:HasSelectedHero(index) then
			local player = PlayerResourse:GetPlayer(index)
			local hero = PlayerResource:GetSelectedHeroEntity(index)
			hero:ModifyGold(gold , false , 0)
			SendOverheadEventMessage(player , OVERHEAD_ALERT_GOLD , hero , gold , nil)
		end
	end
end		

function CreateDrop(itemName , pos)
	local newitem = CreateItem(itemName , nil , nil)
--	newitem:SetPurChaseTime(0)
	CreateItemOnPositionSync(pos , newItem)
--	newItem:LaunchLoot(false , 300 , 0.75 , pos + RandomVector(RandomFloat(50 , 350)))
    print('ВСЁ РАБОТАЕТ')
end

function BelkaMode:BelkaModeStart()
    print('игра началась')
end

function Precache( context )
    -- Частицы
    PrecacheResource( "particle", "particles/units/heroes/hero_gyrocopter/gyro_calldown_first.vpcf", context )
    PrecacheResource( "particle", "particles/units/heroes/hero_enigma/enigma_blackhole.vpcf", context )
    
    -- 🔊 Принудительно загружаем звуки Энигмы
    PrecacheResource( "soundfile", "soundevents/game_sounds_heroes/game_sounds_enigma.vsndevts", context )
end