local templeScroll = Action()

function templeScroll.onUse(player, item, fromPosition, target, toPosition, isHotkey)
	local inPz = player:getTile():hasFlag(TILESTATE_PROTECTIONZONE)
	local inFight = player:isPzLocked() or player:getCondition(CONDITION_INFIGHT, CONDITIONID_DEFAULT)
	if inPz or not inFight then
		fromPosition:sendMagicEffect(CONST_ME_TELEPORT)
		player:teleportTo(player:getTown():getTemplePosition())
		player:getPosition():sendMagicEffect(CONST_ME_TELEPORT)
		-- Handle stackable items: remove 1 instead of the whole stack
		if item:isStackable() and item:getCount() > 1 then
			item:setCount(item:getCount() - 1)
		else
			item:remove()
		end
	else
		player:sendCancelMessage("You can't use this when you're in a fight.")
		fromPosition:sendMagicEffect(CONST_ME_POFF)
	end
	return true
end

templeScroll:id(25718)
templeScroll:register()
