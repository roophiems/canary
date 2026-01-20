-- Weapon Leveling System
-- Uses EventCallback to trigger on player experience gain

local weaponLeveling = EventCallback("WeaponLeveling")

-- Configuration
local WEAPON_LEVELING_CONFIG = {
    -- Base experience for level 1
    baseExp = 1000,
    
    -- Experience multiplier per level (exponential: baseExp * (multiplier ^ (level - 1)))
    expMultiplier = 1.5,
    
    -- Weapon types that can level up (using numeric constants as keys)
    weaponTypes = {
        [WEAPON_SWORD] = true,
        [WEAPON_CLUB] = true,
        [WEAPON_AXE] = true,
        [WEAPON_DISTANCE] = true,
        [WEAPON_WAND] = true,
    },
}

-- Helper function to calculate experience required for a level
local function getExpRequiredForLevel(level)
    if level <= 1 then
        return 0
    end
    return math.floor(WEAPON_LEVELING_CONFIG.baseExp * (WEAPON_LEVELING_CONFIG.expMultiplier ^ (level - 1)))
end

-- Helper function to get weapon level from experience
local function getLevelFromExp(exp)
    if exp < WEAPON_LEVELING_CONFIG.baseExp then
        return 0
    end
    
    local level = 1
    while true do
        local expForNextLevel = getExpRequiredForLevel(level + 1)
        if exp >= expForNextLevel then
            level = level + 1
        else
            break
        end
    end
    
    return level
end

-- Helper function to check if item is a levelable weapon
local function isLevelableWeapon(item)
    if not item then
        logger.info("[WeaponLeveling] isLevelableWeapon: item is nil")
        return false
    end
    
    local itemType = item:getType()
    if not itemType then
        logger.info("[WeaponLeveling] isLevelableWeapon: itemType is nil for item {}", item:getName())
        return false
    end
    
    local weaponType = itemType:getWeaponType()
    local isLevelable = WEAPON_LEVELING_CONFIG.weaponTypes[weaponType] or false
    logger.info("[WeaponLeveling] isLevelableWeapon: item {} has weaponType {}, isLevelable: {}", 
        item:getName(), 
        weaponType, 
        isLevelable
    )
    return isLevelable
end

-- Helper function to check if weapon has elemental damage
local function hasElementalDamage(weapon)
    local itemType = weapon:getType()
    if not itemType then
        return false
    end
    
    local elementDamage = itemType:getElementDamage()
    return elementDamage and elementDamage > 0
end

-- Helper function to update weapon description with percentage
local function updateWeaponDescription(weapon)
    local currentExp = weapon:getCustomAttribute("weaponExp") or 0
    local currentLevel = getLevelFromExp(currentExp)
    local storedLevel = weapon:getCustomAttribute("weaponLevel") or 0
    
    -- Use stored level if it's higher (in case of manual level setting)
    if storedLevel > currentLevel then
        currentLevel = storedLevel
    end
    
    local expForCurrentLevel = getExpRequiredForLevel(currentLevel)
    local expForNextLevel = getExpRequiredForLevel(currentLevel + 1)
    local expNeeded = expForNextLevel - currentExp
    local expInCurrentLevel = currentExp - expForCurrentLevel
    local expNeededForNextLevel = expForNextLevel - expForCurrentLevel
    
    -- Calculate percentage
    local percentage = 0
    if expNeededForNextLevel > 0 then
        percentage = math.floor((expInCurrentLevel / expNeededForNextLevel) * 100)
    end
    
    local description = string.format("Weapon Level: %d\nExperience: %d / %d (%d%%)\nNext Level: %d exp needed", 
        currentLevel, 
        currentExp,
        expForNextLevel,
        percentage,
        expNeeded
    )
    
    weapon:setAttribute(ITEM_ATTRIBUTE_DESCRIPTION, description)
end

-- Helper function to update weapon stats on level up
local function updateWeaponStats(weapon, newLevel)
    -- Store base attack if not already stored
    local baseAttack = weapon:getCustomAttribute("baseAttack")
    if not baseAttack then
        baseAttack = weapon:getAttribute(ITEM_ATTRIBUTE_ATTACK) or 0
        weapon:setCustomAttribute("baseAttack", baseAttack)
    end
    
    local hasElemental = hasElementalDamage(weapon)
    
    -- Calculate bonuses based on level
    local physicalBonus = 0
    local elementalBonus = 0
    
    if hasElemental then
        -- Elemental weapons: odd levels = +1 physical, even levels = +1 elemental
        for level = 1, newLevel do
            if level % 2 == 1 then
                -- Odd level: +1 physical
                physicalBonus = physicalBonus + 1
            else
                -- Even level: +1 elemental
                elementalBonus = elementalBonus + 1
            end
        end
    else
        -- Physical-only weapons: +1 physical per level
        physicalBonus = newLevel
    end
    
    -- Apply physical attack bonus
    local newAttack = baseAttack + physicalBonus
    weapon:setAttribute(ITEM_ATTRIBUTE_ATTACK, newAttack)
    
    -- Apply elemental damage bonus (stored in custom attribute)
    if hasElemental and elementalBonus > 0 then
        weapon:setCustomAttribute("weaponElementalBonus", elementalBonus)
    end
    
    -- Update weapon description
    updateWeaponDescription(weapon)
end

-- Helper function to add experience to weapon
local function addWeaponExp(weapon, exp)
    logger.info("[WeaponLeveling] addWeaponExp: Adding {} exp to weapon {}", exp, weapon:getName())
    local currentExp = weapon:getCustomAttribute("weaponExp") or 0
    local currentLevel = getLevelFromExp(currentExp)
    logger.info("[WeaponLeveling] addWeaponExp: Current exp: {}, current level: {}", currentExp, currentLevel)
    
    local newExp = currentExp + exp
    weapon:setCustomAttribute("weaponExp", newExp)
    logger.info("[WeaponLeveling] addWeaponExp: Set new exp to {}", newExp)
    
    local newLevel = getLevelFromExp(newExp)
    logger.info("[WeaponLeveling] addWeaponExp: New level calculated: {}", newLevel)
    
    if newLevel > currentLevel then
        -- Level up!
        logger.info("[WeaponLeveling] addWeaponExp: Level up detected! {} -> {}", currentLevel, newLevel)
        weapon:setCustomAttribute("weaponLevel", newLevel)
        updateWeaponStats(weapon, newLevel)
        return true, newLevel
    else
        -- Update description even if no level up (to show new percentage)
        logger.info("[WeaponLeveling] addWeaponExp: No level up, updating description")
        updateWeaponDescription(weapon)
    end
    
    return false, currentLevel
end

-- Event callback: triggered when player gains experience
function weaponLeveling.playerOnGainExperience(player, target, exp, rawExp)
    logger.info("[WeaponLeveling] playerOnGainExperience called: player={}, target={}, exp={}, rawExp={}", 
        player and player:getName() or "nil",
        target and target:getName() or "nil",
        exp,
        rawExp
    )
    
    -- Only process if target is a monster
    if not target then
        logger.info("[WeaponLeveling] Early return: target is nil")
        return
    end
    
    if not target:isMonster() then
        logger.info("[WeaponLeveling] Early return: target {} is not a monster (type: {})", 
            target:getName(), 
            target:getType() and "creature" or "unknown"
        )
        return
    end
    
    logger.info("[WeaponLeveling] Target {} is a monster, continuing", target:getName())

    -- Check weapon in LEFT HAND ONLY
    local weapon = player:getSlotItem(CONST_SLOT_LEFT)
    
    if not weapon then
        logger.info("[WeaponLeveling] Early return: No weapon in left hand slot")
        return
    end
    
    logger.info("[WeaponLeveling] Found weapon in left hand: {}", weapon:getName())
    
    if not isLevelableWeapon(weapon) then
        logger.info("[WeaponLeveling] Early return: Weapon {} is not levelable", weapon:getName())
        return
    end
    
    logger.info("[WeaponLeveling] Weapon {} is levelable, proceeding", weapon:getName())
    
    -- Get monster experience value (90% of raw exp)
    local weaponExp = math.floor(rawExp * 0.9)
    logger.info("[WeaponLeveling] Calculated weapon exp: {} (from raw exp: {})", weaponExp, rawExp)
    
    if weaponExp <= 0 then
        logger.info("[WeaponLeveling] Early return: weaponExp is {} (too low)", weaponExp)
        return
    end
    
    -- Log experience award
    local currentExp = weapon:getCustomAttribute("weaponExp") or 0
    local currentLevel = getLevelFromExp(currentExp)
    logger.info("[WeaponLeveling] Player {} killed {} (raw exp: {}), awarded {} exp to weapon {} (current: {} exp, level {})", 
        player:getName(), 
        target:getName(), 
        rawExp, 
        weaponExp, 
        weapon:getName(), 
        currentExp, 
        currentLevel
    )
    
    -- Add experience to weapon
    local leveledUp, level = addWeaponExp(weapon, weaponExp)
    
    if leveledUp then
        local newExp = weapon:getCustomAttribute("weaponExp") or 0
        logger.info("[WeaponLeveling] Weapon {} leveled up to level {}! New exp: {}", 
            weapon:getName(), 
            level, 
            newExp
        )
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, 
            string.format("Your %s has reached level %d!", weapon:getName(), level))
        player:getPosition():sendMagicEffect(CONST_ME_LEVELUP)
    else
        logger.info("[WeaponLeveling] No level up, weapon {} remains at level {}", weapon:getName(), level)
    end
end

weaponLeveling:register()
logger.info("[WeaponLeveling] Script registered successfully")
