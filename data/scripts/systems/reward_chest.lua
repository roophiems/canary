local bossDeath = CreatureEvent("BossDeath")

-- Configuration
local PROMOTION_SCROLL_CONFIG = {
	-- Enable/disable logging
	enableLogging = true,
}

-- Helper function to conditionally log info
local function logInfo(message, ...)
	if PROMOTION_SCROLL_CONFIG.enableLogging then
		logger.info(message, ...)
	end
end

-- Helper function to conditionally log warnings
local function logWarn(message, ...)
	if PROMOTION_SCROLL_CONFIG.enableLogging then
		logger.warn(message, ...)
	end
end

-- Promotion scroll configuration
local promotionScrolls = {
	[43946] = { name = "abridged", points = 3, itemName = "abridged promotion scroll", chance = 15 }, -- 1.5%
	[43947] = { name = "basic", points = 5, itemName = "basic promotion scroll", chance = 12 }, -- 1.2%
	[43948] = { name = "revised", points = 9, itemName = "revised promotion scroll", chance = 10 }, -- 1%
	[43949] = { name = "extended", points = 13, itemName = "extended promotion scroll", chance = 8 }, -- 0.8%
	[43950] = { name = "advanced", points = 20, itemName = "advanced promotion scroll", chance = 5 }, -- 0.5%
}

-- Boss categories based on health, complexity, and damage potential
-- Organized into 5 tiers: Abridged (lowest) -> Basic -> Revised -> Extended -> Advanced (highest, exclusive)
local bossCategories = {
	-- Tier 1: Abridged (8,500 - 30,000 HP) - Very easy bosses, low complexity
	abridged = {
		scrollId = 43946,
		minHealth = 8500,
		maxHealth = 30000,
		bosses = {
			"Ancient Lion Knight", "Ancient Lion Warlock", "Ancient Lion Archer", "Fallen Challenger",
			"Zorvorax", "Tazhadur", "Kalyassa", "Preceptor Lazare",
			"Brokul", "Kesar", "The Sandking Fake", "Wine Cask"
		}
	},
	
	-- Tier 2: Basic (30,000 - 80,000 HP) - Easy-medium bosses, moderate complexity
	basic = {
		scrollId = 43947,
		minHealth = 30000,
		maxHealth = 80000,
		bosses = {
			"Gelidrazah the Frozen", "Grand Canon Dominus", "Grand Chaplain Gaunder", 
			"Grand Commander Soeren", "Thawing Dragon Lord", "Faceless Bane", 
			"Grand Master Oberon", "The Sandking", "Last Planegazer", "Eliz the Unyielding",
			"Malkhar Deathbringer", "Mezlon the Defiler", "The Sinister Hermit Dirty", 
			"The Sinister Hermit Clean", "The Armored Voidborn"
		}
	},
	
	-- Tier 3: Revised (80,000 - 200,000 HP) - Medium-hard bosses, higher complexity
	revised = {
		scrollId = 43948,
		minHealth = 80000,
		maxHealth = 200000,
		bosses = {
			"Drume", "Ravenous Hunger", "Essence of Malice", "Gnomevil", "The Unarmored Voidborn",
			"The Corruptor of Souls", "The Souldespoiler", "The Remorseless Corruptor", "The False God",
			"Gorzindel", "Ghulosh", "Lokathmor", "Mazzinor", "Alptramun", "Malofur Mangrinder",
			"Izcandar the Banished", "Plagueroot", "Maxxenius"
		}
	},
	
	-- Tier 4: Extended (200,000 - 500,000 HP) - Hard bosses, high complexity and damage
	extended = {
		scrollId = 43949,
		minHealth = 200000,
		maxHealth = 500000,
		bosses = {
			"The Source of Corruption", "The Scourge of Oblivion", "The Nightmare Beast"
		}
	},
	
	-- Tier 5: Advanced (exclusive to Soul War and Rotten Blood) - Highest tier, unique quest lines
	soulwar = {
		scrollId = 43950,
		bosses = {
			"Goshnar's Malice", "Goshnar's Hatred", "Goshnar's Spite", "Goshnar's Cruelty", 
			"Goshnar's Greed", "Goshnar's Megalomania"
		}
	},
	
	rottenblood = {
		scrollId = 43950,
		bosses = {
			"Murcion", "Chagorz", "Ichgahal", "Vemiath", "Bakragore"
		}
	}
}

-- Helper function to determine which scroll to roll for
local function getPromotionScrollForBoss(creature, monsterType)
	local bossName = creature:getName()
	local bossHealth = creature:getMaxHealth()
	local scrollToAdd = nil
	local matchedCategory = nil
	
	logInfo("[BossDeath] Determining promotion scroll for boss: {} (HP: {})", bossName, bossHealth)
	
	-- Check specific boss categories first (Soul War and Rotten Blood)
	for categoryName, category in pairs(bossCategories) do
		if category.bosses then
			for _, boss in ipairs(category.bosses) do
				if boss == bossName then
					scrollToAdd = category.scrollId
					matchedCategory = categoryName
					logInfo("[BossDeath] Boss {} matched specific category '{}', selected scroll: {} (chance: {}/1000)", 
						bossName, categoryName, promotionScrolls[scrollToAdd].name, promotionScrolls[scrollToAdd].chance)
					break
				end
			end
		end
		if scrollToAdd then
			break
		end
	end
	
	-- If not found in specific categories, check by health range
	if not scrollToAdd then
		for categoryName, category in pairs(bossCategories) do
			if category.minHealth and category.maxHealth then
				if bossHealth >= category.minHealth and bossHealth <= category.maxHealth then
					scrollToAdd = category.scrollId
					matchedCategory = categoryName
					logInfo("[BossDeath] Boss {} matched health range category '{}' (HP: {}), selected scroll: {} (chance: {}/1000)", 
						bossName, categoryName, bossHealth, promotionScrolls[scrollToAdd].name, promotionScrolls[scrollToAdd].chance)
					break
				end
			end
		end
	end
	
	-- If still no scroll determined, default based on health ranges
	if not scrollToAdd then
		if bossHealth >= 8500 and bossHealth <= 30000 then
			scrollToAdd = 43946 -- abridged
			matchedCategory = "default-abridged"
		elseif bossHealth > 30000 and bossHealth <= 80000 then
			scrollToAdd = 43947 -- basic
			matchedCategory = "default-basic"
		elseif bossHealth > 80000 and bossHealth <= 200000 then
			scrollToAdd = 43948 -- revised
			matchedCategory = "default-revised"
		elseif bossHealth > 200000 and bossHealth <= 500000 then
			scrollToAdd = 43949 -- extended
			matchedCategory = "default-extended"
		elseif bossHealth > 500000 then
			-- Very high HP bosses default to extended (advanced is exclusive to Soul War/Rotten Blood)
			scrollToAdd = 43949 -- extended
			matchedCategory = "default-extended-high"
		else
			-- Fallback for bosses below 8500 HP (shouldn't happen for reward bosses)
			scrollToAdd = 43946 -- abridged
			matchedCategory = "default-abridged-fallback"
		end
		logInfo("[BossDeath] Boss {} using default category '{}' (HP: {}), selected scroll: {} (chance: {}/1000)", 
			bossName, matchedCategory, bossHealth, promotionScrolls[scrollToAdd].name, promotionScrolls[scrollToAdd].chance)
	end
	
	return scrollToAdd
end

function bossDeath.onDeath(creature, corpse, killer, mostDamageKiller, lastHitUnjustified, mostDamageUnjustified)
	-- Deny summons and players
	if not creature or creature:isPlayer() or creature:getMaster() then
		return true
	end

	-- Boss function
	local monsterType = creature:getType()
	-- Make sure it is a boss
	if monsterType and monsterType:isRewardBoss() then
		if not corpse or not corpse.isContainer or not corpse:isContainer() then
			if corpse.getId then
				logger.debug("[bossDeath.onDeath] Boss {} has a corpse (id: {}, name: {}), but it is not a container.", creature:getName(), corpse:getId(), corpse:getName())
			else
				logger.debug("[bossDeath.onDeath] Boss {} does not have a corpse or corpse not found at position {}", creature:getName(), creature:getPosition())
			end
			corpse = Game.createItem(ITEM_BAG, 1)
		end
		corpse:registerReward()
		local bossId = creature:getId()
		local rewardId = corpse:getAttribute(ITEM_ATTRIBUTE_DATE)

		ResetAndSetTargetList(creature)

		-- Avoid dividing by zero
		local totalDamageOut, totalDamageIn, totalHealing = 0.1, 0.1, 0.1

		local scores = {}
		local info = _G.GlobalBosses[bossId]
		local damageMap = creature:getDamageMap()

		for guid, stats in pairs(info) do
			local player = Player(stats.playerId)
			local part = damageMap[stats.playerId]
			local damageOut, damageIn, healing = (stats.damageOut or 0) + (part and part.total or 0), stats.damageIn or 0, stats.healing or 0

			totalDamageOut = totalDamageOut + damageOut
			totalDamageIn = totalDamageIn + damageIn
			totalHealing = totalHealing + healing

			table.insert(scores, {
				player = player,
				guid = guid,
				damageOut = damageOut,
				damageIn = damageIn,
				healing = healing,
			})
		end

		local participants = 0
		for _, con in ipairs(scores) do
			local score = (con.damageOut / totalDamageOut) + (con.damageIn / totalDamageIn) + (con.healing / totalHealing)
			-- Normalize to 0-1
			con.score = score / 3
			if score ~= 0 then
				participants = participants + 1
			end
		end
		table.sort(scores, function(a, b)
			return a.score > b.score
		end)

		local expectedScore = 1 / participants
		
		-- Roll for promotion scroll once per boss (before processing players)
		local scrollRolled = false
		local scrollToAddToLoot = nil
		local scrollToAdd = getPromotionScrollForBoss(creature, monsterType)
		if scrollToAdd then
			local chance = promotionScrolls[scrollToAdd].chance
			local roll = math.random(1000)
			logInfo("[BossDeath] Rolling for {} scroll drop on {}: rolled {} (needed <= {})", 
				promotionScrolls[scrollToAdd].name, creature:getName(), roll, chance)
			
			if roll <= chance then
				scrollToAddToLoot = scrollToAdd
				scrollRolled = true
				logInfo("[BossDeath] Roll SUCCESS! Promotion scroll {} dropped for boss {}", 
					promotionScrolls[scrollToAdd].name, creature:getName())
			else
				logInfo("[BossDeath] Roll FAILED. No promotion scroll dropped for {}", creature:getName())
			end
		else
			logWarn("[BossDeath] Could not determine promotion scroll for boss {}", creature:getName())
		end

		for idx, con in ipairs(scores) do
			-- Ignoring stamina for now because I heard you get receive rewards even when it's depleted
			if con.score ~= 0 then
				local reward, stamina, player
				if con.player then
					player = con.player
				else
					player = Game.getOfflinePlayer(con.guid)
				end
				reward = player:getReward(rewardId, true)
				stamina = player:getStamina()

				local lootFactor = 1
				-- Tone down the loot a notch if there are many participants
				lootFactor = lootFactor / participants ^ (1 / 3)
				-- Increase the loot multiplicatively by how many times the player surpassed the expected score
				lootFactor = lootFactor * (1 + lootFactor) ^ (con.score / expectedScore)
				-- Bosstiary Loot Bonus
				local rolls = 1
				local isBoostedBoss = creature:getName():lower() == (Game.getBoostedBoss()):lower()
				local bossRaceIds = { player:getSlotBossId(1), player:getSlotBossId(2) }
				local isBoss = table.contains(bossRaceIds, monsterType:raceId()) or isBoostedBoss
				if isBoss and monsterType:raceId() ~= 0 then
					if monsterType:raceId() == player:getSlotBossId(1) then
						rolls = rolls + player:getBossBonus(1) / 100.0
					elseif monsterType:raceId() == player:getSlotBossId(2) then
						rolls = rolls + player:getBossBonus(2) / 100.0
					else
						rolls = rolls + configManager.getNumber(configKeys.BOOSTED_BOSS_LOOT_BONUS) / 100
					end
				end
				-- decide if we get an extra roll
				if math.random(0, 100) < (rolls % 1) * 100 then
					rolls = math.ceil(rolls)
				else
					rolls = math.floor(rolls)
				end

				local playerLoot = creature:generateGemAtelierLoot()
				playerLoot = monsterType:getBossReward(lootFactor, idx == 1, false, playerLoot, player)
				for _ = 2, rolls do
					playerLoot = monsterType:getBossReward(lootFactor, false, true, playerLoot, player)
				end
				
				-- Add promotion scroll to this player's loot if it was rolled
				if scrollRolled and scrollToAddToLoot then
					if not playerLoot[scrollToAddToLoot] then
						playerLoot[scrollToAddToLoot] = { count = 0 }
					end
					playerLoot[scrollToAddToLoot].count = playerLoot[scrollToAddToLoot].count + 1
					logInfo("[BossDeath] Added {} scroll (ID: {}) to {} loot", 
						promotionScrolls[scrollToAddToLoot].itemName, scrollToAddToLoot, player:getName())
				end

				-- Add droped items to reward container
				reward:addRewardBossItems(playerLoot)

				if con.player then
					local collorMessage = player:getClient().version > 1200
					local lootMessage = ("The following items dropped by %s are available in your reward chest: %s"):format(creature:getName(), reward:getContentDescription(collorMessage))
					if rolls > 1 then
						lootMessage = lootMessage .. " (boss bonus)"
					end
					if stamina > 840 then
						reward:getContentDescription(lootMessage)
					end
					player:sendTextMessage(MESSAGE_LOOT, lootMessage)
				else
					player:save()
				end
			end
		end
		_G.GlobalBosses[bossId] = nil
	end
	return true
end

bossDeath:register()

local bossParticipation = CreatureEvent("BossParticipation")

function bossParticipation.onHealthChange(creature, attacker, primaryDamage, primaryType, secondaryDamage, secondaryType, origin)
	if not next(_G.GlobalBosses) then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end

	if not creature or not attacker then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end

	local stats = creature:inBossFight()
	if not stats then
		return primaryDamage, primaryType, secondaryDamage, secondaryType
	end

	local creatureId, attackerId = creature:getId(), attacker:getId()
	-- Update player id
	stats.playerId = creatureId

	-- Account for healing of others active in the boss fight
	if primaryType == COMBAT_HEALING and attacker:isPlayer() and attackerId ~= creatureId then
		local healerStats = GetPlayerStats(stats.bossId, attacker:getGuid(), true)
		healerStats.active = true
		-- Update player id
		healerStats.playerId = attackerId
		healerStats.healing = healerStats.healing + primaryDamage
	elseif stats.bossId == attackerId then
		-- Account for damage taken from the boss
		stats.damageIn = stats.damageIn + primaryDamage
	end
	return primaryDamage, primaryType, secondaryDamage, secondaryType
end

bossParticipation:register()

local loginBossPlayer = CreatureEvent("LoginBossPlayer")

function loginBossPlayer.onLogin(player)
	player:registerEvent("BossDeath")
	return true
end

loginBossPlayer:register()

local bossThink = CreatureEvent("BossThink")

function bossThink.onThink(creature, interval)
	if not creature then
		return true
	end

	ResetAndSetTargetList(creature)
end

bossThink:register()
