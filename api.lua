-------------------------------------------------------------------------------
-- advanced spawning mod
--
--@license WTFP
--@copyright Sapier
--@author Sapier
--@date 2013-12-05
--
-------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] register
-- @param spawn_definition a definition to use for spawning
--------------------------------------------------------------------------------
function adv_spawning.register(spawner_name,spawning_def)
	if adv_spawning.spawner_definitions[spawner_name] == nil then

		--TODO validate spawning definition

		adv_spawning.spawner_definitions[spawner_name] = spawning_def
		return true
	else
		return false
	end
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] get_statistics
-- @return get snapshot of statistics
--------------------------------------------------------------------------------
function adv_spawning.get_statistics()
	return minetest.deserialize(minetest.serialize(adv_spawning.statistics))
end