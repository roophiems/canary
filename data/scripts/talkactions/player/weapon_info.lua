local weaponInfo = TalkAction("!weapon", "!weaponinfo")

-- Configuration (must match weapon_leveling.lua)
local BASE_EXP = 1000
local EXP_MULTIPLIER = 1.5

-- Helper function to calculate experience required for a level
local function getExpRequiredForLevel(level)
    if level <= 1 then
        return 0
    end
    return math.floor(BASE_EXP * (EXP_MULTIPLIER ^ (level - 1)))
end

-- Helper function to get weapon level from experience
local function getLevelFromExp(exp)
    if exp < BASE_EXP then
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

-- Helper function to check if weapon has elemental damage
local function hasElementalDamage(weapon)
    local itemType = weapon:getType()
    if not itemType then
        return false
    end
    
    local elementDamage = itemType:getElementDamage()
    return elementDamage and elementDamage > 0
end

function weaponInfo.onSay(player, words, param)
    local weapon = player:getSlotItem(CONST_SLOT_LEFT)
    
    if not weapon then
        player:sendCancelMessage("You need to equip a weapon in your left hand.")
        return true
    end
    
    local itemType = weapon:getType()
    if not itemType then
        player:sendCancelMessage("Unable to get weapon type.")
        return true
    end
    
    local weaponType = itemType:getWeaponType()
    local levelableTypes = {
        [WEAPON_SWORD] = true,
        [WEAPON_CLUB] = true,
        [WEAPON_AXE] = true,
        [WEAPON_DISTANCE] = true,
        [WEAPON_WAND] = true,
    }
    
    if not levelableTypes[weaponType] then
        player:sendCancelMessage("This weapon cannot be leveled.")
        return true
    end
    
    -- Get weapon leveling data
    local currentExp = weapon:getCustomAttribute("weaponExp") or 0
    local storedLevel = weapon:getCustomAttribute("weaponLevel") or 0
    local currentLevel = getLevelFromExp(currentExp)
    
    -- Use stored level if it's higher (in case of manual level setting)
    if storedLevel > currentLevel then
        currentLevel = storedLevel
    end
    
    local baseAttack = weapon:getCustomAttribute("baseAttack")
    local currentAttack = weapon:getAttribute(ITEM_ATTRIBUTE_ATTACK) or 0
    local elementalBonus = weapon:getCustomAttribute("weaponElementalBonus") or 0
    local hasElemental = hasElementalDamage(weapon)
    
    -- Calculate next level requirements
    local expForNextLevel = getExpRequiredForLevel(currentLevel + 1)
    local expNeeded = expForNextLevel - currentExp
    
    -- Build info message
    local message = string.format("=== %s ===\n", weapon:getName())
    message = message .. string.format("Level: %d\n", currentLevel)
    message = message .. string.format("Experience: %d / %d\n", currentExp, expForNextLevel)
    message = message .. string.format("Exp to Next Level: %d\n", expNeeded)
    message = message .. string.format("Physical Attack: %d", currentAttack)
    
    if baseAttack then
        local bonus = currentAttack - baseAttack
        if bonus > 0 then
            message = message .. string.format(" (+%d)", bonus)
        end
    end
    message = message .. "\n"
    
    if hasElemental then
        local itemType = weapon:getType()
        local baseElemental = itemType:getElementDamage() or 0
        local totalElemental = baseElemental + elementalBonus
        message = message .. string.format("Elemental Damage: %d", totalElemental)
        if elementalBonus > 0 then
            message = message .. string.format(" (+%d from leveling)", elementalBonus)
        end
        message = message .. "\n"
    end
    
    player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, message)
    return true
end

weaponInfo:groupType("normal")
weaponInfo:register()
