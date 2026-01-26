local promotionScrolls = {
	[43946] = { name = "abridged", points = 3, itemName = "abridged promotion scroll" },
	[43947] = { name = "basic", points = 5, itemName = "basic promotion scroll" },
	[43948] = { name = "revised", points = 9, itemName = "revised promotion scroll" },
	[43949] = { name = "extended", points = 13, itemName = "extended promotion scroll" },
	[43950] = { name = "advanced", points = 20, itemName = "advanced promotion scroll" },
}

local scroll = Action()

function scroll.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	if player:getLevel() < 51 then
		player:sendTextMessage(MESSAGE_LOOK, "Only a hero of level 51 or above can decipher this scroll.")
		return true
	end

	local scrollData = promotionScrolls[item:getId()]
	
	-- Check current usage count
	local scrollKv = player:kv():scoped("wheel-of-destiny"):scoped("scrolls")
	local currentCount = 0
	if scrollKv then
		local scrollValue = scrollKv:get(scrollData.name)
		if scrollValue then
			if type(scrollValue) == "number" then
				currentCount = scrollValue
			elseif scrollValue == true then
				currentCount = 1 -- Backward compatibility
			end
		end
	end
	
	-- Check if player has reached the limit (10 uses)
	if currentCount >= 10 then
		player:sendTextMessage(MESSAGE_LOOK, "You have already deciphered this scroll 10 times. You cannot use it anymore.")
		return true
	end
	
	if not player:wheelUnlockScroll(scrollData.name) then
		player:sendTextMessage(MESSAGE_LOOK, "You have already deciphered this scroll.")
		return true
	end

	local usesLeft = 10 - (currentCount + 1)
	local message = "You have gained " .. scrollData.points .. " promotion points for the Wheel of Destiny by deciphering the " .. scrollData.itemName .. "."
	if usesLeft > 0 then
		message = message .. " You can use this scroll type " .. usesLeft .. " more times."
	else
		message = message .. " You have reached the maximum usage limit for this scroll type."
	end
	
	player:sendTextMessage(MESSAGE_LOOK, message)
	item:remove(1)
	return true
end

for id in pairs(promotionScrolls) do
	scroll:id(id)
end

scroll:register()
