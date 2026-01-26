local weaponLevelingAdmin = TalkAction("/weaponlevel", "/wlevel")

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

-- Helper function to update weapon stats (same as in weapon_leveling.lua)
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

function weaponLevelingAdmin.onSay(player, words, param)
    -- Log command
    logCommand(player, words, param)
    
    if param == "" then
        player:sendCancelMessage("Usage:\n/weaponlevel create <itemid> <level> - Create item with specific level\n/weaponlevel setlevel <level> - Set level of weapon in left hand\n/weaponlevel info - Show detailed weapon info")
        return true
    end
    
    local params = param:split(",")
    local command = params[1]:lower():trim()
    
    if command == "create" then
        if not params[2] or not params[3] then
            player:sendCancelMessage("Usage: /weaponlevel create <itemid> <level>")
            return true
        end
        
        local itemId = tonumber(params[2]:trim())
        local level = tonumber(params[3]:trim())
        
        if not itemId or not level or level < 0 then
            player:sendCancelMessage("Invalid item ID or level.")
            return true
        end
        
        local item = player:addItem(itemId, 1)
        if not item then
            player:sendCancelMessage("Failed to create item.")
            return true
        end
        
        -- Set experience for the level
        local expForLevel = getExpRequiredForLevel(level + 1) - 1
        if level == 0 then
            expForLevel = 0
        end
        
        item:setCustomAttribute("weaponExp", expForLevel)
        item:setCustomAttribute("weaponLevel", level)
        
        if level > 0 then
            updateWeaponStats(item, level)
        end
        
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("Created %s with level %d.", item:getName(), level))
        return true
        
    elseif command == "setlevel" then
        if not params[2] then
            player:sendCancelMessage("Usage: /weaponlevel setlevel <level>")
            return true
        end
        
        local level = tonumber(params[2]:trim())
        
        if not level or level < 0 then
            player:sendCancelMessage("Invalid level.")
            return true
        end
        
        local weapon = player:getSlotItem(CONST_SLOT_LEFT)
        if not weapon then
            player:sendCancelMessage("You need to equip a weapon in your left hand.")
            return true
        end
        
        -- Set experience for the level
        local expForLevel = getExpRequiredForLevel(level + 1) - 1
        if level == 0 then
            expForLevel = 0
        end
        
        weapon:setCustomAttribute("weaponExp", expForLevel)
        weapon:setCustomAttribute("weaponLevel", level)
        
        if level > 0 then
            updateWeaponStats(weapon, level)
        else
            -- Reset to base stats
            local baseAttack = weapon:getCustomAttribute("baseAttack")
            if baseAttack then
                weapon:setAttribute(ITEM_ATTRIBUTE_ATTACK, baseAttack)
            end
            weapon:removeCustomAttribute("weaponElementalBonus")
            weapon:removeAttribute(ITEM_ATTRIBUTE_DESCRIPTION)
        end
        
        player:sendTextMessage(MESSAGE_STATUS_CONSOLE_BLUE, string.format("Set %s to level %d.", weapon:getName(), level))
        return true
        
    elseif command == "info" then
        local weapon = player:getSlotItem(CONST_SLOT_LEFT)
        if not weapon then
            player:sendCancelMessage("You need to equip a weapon in your left hand.")
            return true
        end
        
        local currentExp = weapon:getCustomAttribute("weaponExp") or 0
        local storedLevel = weapon:getCustomAttribute("weaponLevel") or 0
        local currentLevel = getLevelFromExp(currentExp)
        
        if storedLevel > currentLevel then
            currentLevel = storedLevel
        end
        
        local baseAttack = weapon:getCustomAttribute("baseAttack")
        local currentAttack = weapon:getAttribute(ITEM_ATTRIBUTE_ATTACK) or 0
        local elementalBonus = weapon:getCustomAttribute("weaponElementalBonus") or 0
        local hasElemental = hasElementalDamage(weapon)
        
        local expForNextLevel = getExpRequiredForLevel(currentLevel + 1)
        local expNeeded = expForNextLevel - currentExp
        
        local message = string.format("=== %s (Detailed Info) ===\n", weapon:getName())
        message = message .. string.format("Level: %d\n", currentLevel)
        message = message .. string.format("Experience: %d / %d\n", currentExp, expForNextLevel)
        message = message .. string.format("Exp to Next Level: %d\n", expNeeded)
        message = message .. string.format("Base Attack: %d\n", baseAttack or currentAttack)
        message = message .. string.format("Current Attack: %d", currentAttack)
        
        if baseAttack then
            local bonus = currentAttack - baseAttack
            if bonus > 0 then
                message = message .. string.format(" (+%d from leveling)", bonus)
            end
        end
        message = message .. "\n"
        
        if hasElemental then
            local itemType = weapon:getType()
            local baseElemental = itemType:getElementDamage() or 0
            local totalElemental = baseElemental + elementalBonus
            message = message .. string.format("Base Elemental: %d\n", baseElemental)
            message = message .. string.format("Elemental Bonus: %d\n", elementalBonus)
            message = message .. string.format("Total Elemental: %d\n", totalElemental)
        end
        
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, message)
        return true
        
    else
        player:sendCancelMessage("Unknown command. Use: create, setlevel, or info")
        return true
    end
end

weaponLevelingAdmin:separator(" ")
weaponLevelingAdmin:groupType("god")
weaponLevelingAdmin:register()
