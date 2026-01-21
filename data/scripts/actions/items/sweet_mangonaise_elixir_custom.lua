-- Custom Sweet Mangonaise Elixir: Restores stamina to maximum
-- Cooldown: 4 hours

local sweetMangonaiseElixirCustom = Action()

function sweetMangonaiseElixirCustom.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	-- Check if player has cooldown
	if player:hasExhaustion("sweet-mangonaise-stamina-cooldown") then
		local remainingTime = player:getExhaustion("sweet-mangonaise-stamina-cooldown")
		local hours = math.floor(remainingTime / 3600)
		local minutes = math.floor((remainingTime % 3600) / 60)
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("You need to wait %dh %dm before using it again.", hours, minutes))
		player:getPosition():sendMagicEffect(CONST_ME_POFF)
		return true
	end

	-- Get current stamina
	local currentStamina = player:getStamina()
	local maxStamina = 2520 -- 42 hours in minutes
	
	if currentStamina >= maxStamina then
		player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Your stamina is already at maximum.")
		player:getPosition():sendMagicEffect(CONST_ME_POFF)
		return true
	end

	-- Restore stamina to maximum
	player:setStamina(maxStamina)
	
	-- Send success messages
	player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "Your stamina has been fully restored!")
	player:say("Slurp.", TALKTYPE_MONSTER_SAY)
	player:getPosition():sendMagicEffect(CONST_ME_MAGIC_GREEN)
	
	-- Set 4-hour cooldown (14400 seconds)
	player:setExhaustion("sweet-mangonaise-stamina-cooldown", 4 * 60 * 60)
	
	-- Remove the item
	item:remove(1)
	
	return true
end

sweetMangonaiseElixirCustom:id(11588)
sweetMangonaiseElixirCustom:register()
