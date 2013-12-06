-------------------------------------------------------------------------------
-- advanced spawning mod
--
--@license WTFP
--@copyright Sapier
--@author Sapier
--@date 2013-12-05
--
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
-- @function MAX
-- @param a first value to compare
-- @param b second value to compare
-- @return maximum of a and b
--------------------------------------------------------------------------------
function MAX(a,b)
	if a > b then
		return a
	else
		return b
	end
end

--------------------------------------------------------------------------------
-- @function MIN
-- @param a first value to compare
-- @param b second value to compare
-- @return minimum of a and b
--------------------------------------------------------------------------------
function MIN(a,b)
	if a > b then
		return b
	else
		return a
	end
end


--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] initialize
--------------------------------------------------------------------------------
function adv_spawning.initialize()

	--initialize data
	adv_spawning.quota_starttime = nil
	adv_spawning.quota_reload = 100
	adv_spawning.quota_left = adv_spawning.quota_reload
	adv_spawning.max_spawns_per_spawner = 2
	adv_spawning.spawner_distance = 100
	adv_spawning.max_spawning_frequency_hz = 5

	adv_spawning.spawner_definitions = {}
	adv_spawning.statistics =
	{
		session =
		{
			spawners_created = 0,
			entities_created = 0,
			steps = 0,
		},
		step =
		{
			min = 0,
			max = 0,
			last = 0,
		},
		load =
		{
			min = 0,
			max = 0,
			cur = 0,
			avg = 0
		}
	}

	adv_spawning.gettime = function() return os.clock() * 1000 end

	if type(minetest.get_us_time) == "function" then
		adv_spawning.gettime = function()
				return minetest.get_us_time() / 1000
			end
	else
		if socket == nil then
			local status, module = pcall(require, 'socket')

			if status and type(module.gettime) == "function" then
				adv_spawning.gettime = function()
						return socket.gettime()*1000
					end
			end
		end
	end

	--register global onstep
	minetest.register_globalstep(adv_spawning.global_onstep)

	--register seed spawner entity
	adv_spawning.seed_initialize()

	--register mapgen hook
	minetest.register_on_generated(adv_spawning.mapgen_hook)
end


--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] mapgen_hook
-- @param minp minimal position of block
-- @param maxp maximal position of block
-- @param blockseed seed for this block
--------------------------------------------------------------------------------
function adv_spawning.mapgen_hook(minp,maxp,blockseed)

	--find positions within current block to place a spawner seed
	local start_x =
		math.floor(minp.x/adv_spawning.spawner_distance)
		* adv_spawning.spawner_distance
	local start_y =
		(math.floor(minp.y/adv_spawning.spawner_distance)
			* adv_spawning.spawner_distance) +20
	local start_z =
		math.floor(minp.z/adv_spawning.spawner_distance)
		* adv_spawning.spawner_distance

	for x=start_x,maxp.x,adv_spawning.spawner_distance do
	for y=start_y,maxp.y,adv_spawning.spawner_distance do
	for z=start_z,maxp.z,adv_spawning.spawner_distance do

		if x > minp.x and
			y > minp.y and
			z > minp.z then
			minetest.add_entity({x=x,y=y,z=z},"adv_spawning:spawn_seed")
			--adv_spawning.log("info", "adv_spawning: adding spawner entity at "
			--	.. minetest.pos_to_string({x=x,y=y,z=z}))
			adv_spawning.statistics.session.spawners_created =
				adv_spawning.statistics.session.spawners_created +1
		end
	end
	end
	end
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] global_onstep
-- @param dtime time since last call
--------------------------------------------------------------------------------
function adv_spawning.global_onstep(dtime)

	adv_spawning.statistics.step.last =
		adv_spawning.quota_reload - adv_spawning.quota_left

	adv_spawning.statistics.step.max = MAX(adv_spawning.statistics.step.last,
											adv_spawning.statistics.step.max)

	adv_spawning.statistics.step.min = MIN(adv_spawning.statistics.step.last,
											adv_spawning.statistics.step.min)

	adv_spawning.statistics.session.steps =
		adv_spawning.statistics.session.steps + 1

	adv_spawning.statistics.load.cur =
		adv_spawning.statistics.step.last/(dtime*1000)

	adv_spawning.statistics.load.max = MAX(adv_spawning.statistics.load.cur,
											adv_spawning.statistics.load.max)

	adv_spawning.statistics.load.min = MIN(adv_spawning.statistics.load.cur,
											adv_spawning.statistics.load.min)

	adv_spawning.statistics.load.avg =
		(	(adv_spawning.statistics.load.avg *
			(adv_spawning.statistics.session.steps-1)) +
			adv_spawning.statistics.load.cur) /
			adv_spawning.statistics.session.steps

	adv_spawning.quota_left = adv_spawning.quota_reload
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] quota_enter
-- @return true/false
--------------------------------------------------------------------------------
function adv_spawning.quota_enter()
	--ONLY enable this one if you're quite sure there aren't bugs in
	--assert(adv_spawning.quota_starttime == nil)

	if adv_spawning.quota_left <= 0 then
		print("Quota: no time left: " .. adv_spawning.quota_left)
		return false
	end
	--print("+++++++++++++++++Quota enter+++++++++++++++++++++")
	--print(debug.traceback())
	--print("+++++++++++++++++++++++++++++++++++++++++++++++++")
	adv_spawning.quota_starttime = adv_spawning.gettime()
	return true
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] quota_left
-- @return true/false
--------------------------------------------------------------------------------
function adv_spawning.time_over()
	assert(adv_spawning.quota_starttime ~= nil)

	local now = adv_spawning.gettime()

	local time_passed = now - adv_spawning.quota_starttime

	assert(time_passed >= 0)

	return (adv_spawning.quota_left - time_passed) < 0
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] quota_leave
--------------------------------------------------------------------------------
function adv_spawning.quota_leave()
	assert(adv_spawning.quota_starttime ~= nil)

	local now = adv_spawning.gettime()

	local time_passed = now - adv_spawning.quota_starttime

	assert(time_passed >= 0)

	adv_spawning.quota_left = adv_spawning.quota_left - time_passed
	adv_spawning.quota_starttime = nil
	--print("-----------------Quota leave----------------------")
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] handlespawner
-- @param spawnername unique name of spawner
-- @param spawnerpos position of spawner
-- @return true/false
--------------------------------------------------------------------------------
function adv_spawning.handlespawner(spawnername,spawnerpos)

	local spawndef = adv_spawning.spawner_definitions[spawnername]

	--get random pos
	local new_pos = {}
	new_pos.x = math.random(spawnerpos.x - adv_spawning.spawner_distance/2,
							spawnerpos.x + adv_spawning.spawner_distance/2)

	new_pos.z = math.random(spawnerpos.z - adv_spawning.spawner_distance/2,
							spawnerpos.z + adv_spawning.spawner_distance/2)

	local upper_y = spawnerpos.y + adv_spawning.spawner_distance/2
	local lower_y = spawnerpos.y - adv_spawning.spawner_distance/2


	local continue = false

	--check if entity is configured to spawn at surface
	if spawndef.relative_height == nil or
		(spawndef.relative_height.max ~= nil and
			spawndef.relative_height.max <= 1) then
		new_pos.y = adv_spawning.get_surface(lower_y,upper_y,new_pos,
							spawndef.spawn_inside)
	else
		new_pos.y = adv_spawning.get_relative_pos(lower_y,upper_y,new_pos,
							spawndef.spawn_inside,spawndef.relative_height)
	end

	--check if we did found a position within relative range
	if new_pos.y == nil then
		new_pos.y="?"
		adv_spawning.log("info",
			minetest.pos_to_string(new_pos) .. " didn't find a suitable y pos "
			.. lower_y .. "<-->" .. upper_y )
		continue = true
	end

	--check absolute height
	if not continue and
		not adv_spawning.check_absolute_height(new_pos,spawndef.absolute_height) then
		adv_spawning.log("info",
			minetest.pos_to_string(new_pos) .. " didn't meet absolute height check")
		continue = true
	end

	--check collisionbox
	if not continue then
		local checkresult,y_pos =
			adv_spawning.check_collisionbox(new_pos,
							spawndef.collisionbox,spawndef.spawn_inside)

		if checkresult and y_pos ~= nil then
			new_pos.y = y_pos
		end

		if not checkresult then
			continue = true
		end
	end

	--check surface
	if not continue and
		not adv_spawning.check_surface(new_pos,
										spawndef.surfaces,
										spawndef.relative_height,
										spawndef.spawn_inside) then
		adv_spawning.log("info",
			minetest.pos_to_string(new_pos) .. " didn't meet surface check")
		continue = true
	end

	--check entities around
	if not continue and
		not adv_spawning.check_entities_around(new_pos,spawndef.entities_around) then
		adv_spawning.log("info",
			minetest.pos_to_string(new_pos) .. " didn't meet entities check")
		continue = true
	end

	--check nodes around
	if not continue and
		not adv_spawning.check_nodes_around(new_pos,spawndef.nodes_around) then
		adv_spawning.log("info",
			minetest.pos_to_string(new_pos) .. " didn't meet nodes check")
		continue = true
	end

	--check light around
	if not continue and
		not adv_spawning.check_light_around(new_pos,spawndef.light_around) then
		adv_spawning.log("info",
			minetest.pos_to_string(new_pos) .. " didn't meet light  check")
		continue = true
	end

	--check humidity
	if not continue and
		not adv_spawning.check_humidity_around(new_pos,spawndef.humidity_around) then
		adv_spawning.log("info",
			minetest.pos_to_string(new_pos) .. " didn't meet humidity check")
		continue = true
	end

	--check temperature
	if not continue and
		not adv_spawning.check_temperature_around(new_pos,spawndef.temperature_around) then
		adv_spawning.log("info",
			minetest.pos_to_string(new_pos) .. " didn't meet temperature check")
		continue = true
	end

	--custom check
	if not continue and
		(spawndef.custom_check ~= nil and
		type(spawndef.custom_check) == "function") then

		if not spawndef.custom_check(new_pos) then
			adv_spawning.log("info",
				minetest.pos_to_string(new_pos) .. " didn't meet custom check")
			continue = true
		end
	end

	--do spawn
	if not continue then
		print("Now spawning: " .. spawndef.spawnee .. " at " ..
			minetest.pos_to_string(new_pos))

		if type(spawndef.spawnee) == "function" then
			spawndef.spawnee(new_pos)
		else
			minetest.add_entity(new_pos,spawndef.spawnee)
		end

		adv_spawning.statistics.session.entities_created =
				adv_spawning.statistics.session.entities_created +1
		return true
	end

	return false
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] get_surface
-- @param y_min minumum relevant y pos
-- @param y_max maximum relevant y pos
-- @param new_pos position to spawn at
-- @param spawn_inside nodes to spawn at
-- @return y-value of last spawnable node
--------------------------------------------------------------------------------
function adv_spawning.get_surface(y_min,y_max,new_pos,spawn_inside)

	local top_pos = { x=new_pos.x, z=new_pos.z, y=y_max}
	local bottom_pos = { x=new_pos.x, z=new_pos.z, y=y_min}

	local spawnable_nodes =
		minetest.find_nodes_in_area(bottom_pos, top_pos, spawn_inside)

	for i=y_max, y_min, -1 do
		local pos = { x=new_pos.x,z=new_pos.z,y=i}
		if not adv_spawning.contains_pos(spawnable_nodes,pos) then
			local node = minetest.get_node(pos)

			if node.name ~= "ignore" then
				return i+1
			end
		end
	end

	return nil
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] get_relative_pos
-- @param y_min minumum relevant y pos
-- @param y_max maximum relevant y pos
-- @param new_pos position to spawn at
-- @param spawn_inside nodes to spawn at
-- @param relative_height
-- @return y-value of last spawnable node
--------------------------------------------------------------------------------
function adv_spawning.get_relative_pos(y_min,y_max,new_pos,spawn_inside,relative_height)
	local y_val = adv_spawning.get_surface(y_min,y_max,new_pos,spawn_inside)

	if y_val == nil then
		return nil
	end

	local top_pos = { x=new_pos.x, z=new_pos.z, y=y_max}
	local bottom_pos = { x=new_pos.x, z=new_pos.z, y=y_val}

	if relative_height ~= nil then
		if relative_height.min ~= nil then
			bottom_pos.y = y_val + relative_height.min
		end

		if relative_height.max ~= nil then
			top_pos.y = y_val + relative_height.max
		end
	end

	local spawnable_nodes =
		minetest.find_nodes_in_area(bottom_pos, top_pos, spawn_inside)

	if #spawnable_nodes > 0 then
		return spawnable_nodes[math.random(1,#spawnable_nodes)].y
	else
		return nil
	end
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] contains_pos
-- @param pos_list table containing positions
-- @param pos a position to search
-- @param remove if this is set to true a position is removed on match
-- @return true/false
--------------------------------------------------------------------------------
function adv_spawning.contains_pos(pos_list,pos,remove)

	for i=1,#pos_list,1 do
		if pos_list[i].x == pos.x and
			pos_list[i].z == pos.z and
			pos_list[i].y == pos.y then

			if remove then
				table.erase(i)
			end
			return true
	end
	end
	return false
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] check_absolute_height
-- @param pos to verify
-- @param absolute_height configuration for absolute height check
-- @return true/false
--------------------------------------------------------------------------------
function adv_spawning.check_absolute_height(pos,absolute_height)
	if absolute_height == nil then
		return true
	end

	if absolute_height.min ~= nil and
		pos.y < absolute_height.min then
		return false
	end

	if absolute_height.max ~= nil and
		pos.y > absolute_height.max then
		return false
	end

	return true
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] check_surface
-- @param pos to verify
-- @param surface configuration
-- @param relative_height required to check for non ground bound spawning
-- @param spawn_inside nodes to spawn inside
-- @return true/false
--------------------------------------------------------------------------------
function adv_spawning.check_surface(pos,surfaces,relative_height,spawn_inside)

	if surfaces == nil then
		return true
	end

	if relative_height == nil or (
		relative_height.min <= 1 and
		relative_height.max <= 1) then

		local lower_pos = {x=pos.x, y= pos.y-1, z=pos.z}

		local node_below = minetest.get_node(lower_pos)

		return adv_spawning.contains(surfaces,node_below.name)
	else
		local ymin = pos.y-relative_height.max-1
		local ymax = pos.y+relative_height.max
		local surface = adv_spawning.get_surface(ymin, ymax, pos, spawn_inside)
		if surface == nil then
			return false
		else
			local lower_pos = {x=pos.x, y= surface-1, z=pos.z}

			local node_below = minetest.get_node(lower_pos)

			return adv_spawning.contains(surfaces,node_below.name)
		end
	end
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] contains
-- @param table_to_check
-- @param value
-- @return true/false
--------------------------------------------------------------------------------
function adv_spawning.contains(table_to_check,value)
	for i=1,#table_to_check,1 do
		if table_to_check[i] == value then
			return true
		end
	end
	return false
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] check_nodes_around
-- @param pos position to validate
-- @param nodes_around node around definitions
-- @return true/false
--------------------------------------------------------------------------------
function adv_spawning.check_nodes_around(pos,nodes_around)

	if nodes_around == nil then
		return true
	end

	for i=1,#nodes_around,1 do
		--first handle special cases 0 and 1 in a quick way
		if  (nodes_around[i].threshold == 1 and nodes_around[i].type == "MIN") or
			(nodes_around[i].threshold == 0 and nodes_around[i].type == "MAX")then

			local found =
				minetest.find_node_near(pos,nodes_around[i].distance,
										nodes_around[i].name)

			if nodes_around[i].type == "MIN" then
				if found == nil then
					return false
				end
			else
				if found ~= nil then
					return false
				end
			end
		else
			--need to do the full blown check
			local found_nodes = minetest.find_nodes_in_area(
										{   x=pos.x-nodes_around[i].distance,
											y=pos.y-nodes_around[i].distance,
											z=pos.z-nodes_around[i].distance},
										{   x=pos.x+nodes_around[i].distance,
											y=pos.y+nodes_around[i].distance,
											z=pos.z+nodes_around[i].distance},
										nodes_around[i].name)

			if nodes_around[i].type == "MIN" and
				#found_nodes < nodes_around[i].threshold then
				return false
			end

			if nodes_around[i].type == "MAX" and
				#found_nodes > nodes_around[i].threshold then
				return false
			end
		end
	end
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] check_entities_around
-- @param pos position to validate
-- @param entities_around entity around definitions
-- @return true/false
--------------------------------------------------------------------------------
function adv_spawning.check_entities_around(pos,entities_around)
	if entities_around == nil then
		return true
	end

	for i=1,#entities_around,1 do
		local entity_in_range =
			minetest.get_objects_inside_radius(pos, entities_around[i].distance)


		if entities_around[i].entityname == nil then
			if entities_around[i].type == "MIN" and
				#entity_in_range < entities_around[i].threshold then
				return false
			end

			if entities_around[i].type == "MAX" and
				#entity_in_range > entities_around[i].threshold then
				return false
			end
		end

		local count = 0

		for j=1,#entity_in_range,1 do
			local entity = entity_in_range[j]:get_luaentity()

			if entity ~= nil then
				if entity.name == entities_around[i].entityname then
					count = count +1
				end

				if count > entities_around[i].threshold then
					break
				end
			end
		end

		if entities_around[i].type == "MIN" and
			count < entities_around[i].threshold then
			return false
		end

		if entities_around[i].type == "MAX" and
			count > entities_around[i].threshold then
			return false
		end
	end

	return true
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] check_light_around
-- @param pos position to validate
-- @param light_around light around definitions
-- @return true/false
--------------------------------------------------------------------------------
function adv_spawning.check_light_around(pos,light_around)
	if light_around == nil then
		return true
	end

	for i=1,#light_around,1 do

		for x=pos.x-light_around[i].distance,pos.x+light_around[i].distance,1 do
		for y=pos.y-light_around[i].distance,pos.y+light_around[i].distance,1 do
		for x=pos.z-light_around[i].distance,pos.z+light_around[i].distance,1 do
			local checkpos = { x=x,y=y,z=z}
			local time = minetest.get_timeofday()
			if light_around[i].type == "TIMED_MIN" or
				light_around[i].type == "TIMED_MAX" then
				time = light_around[i].time
			end

			if light_around[i].type == "OVERALL_MIN" or
				light_around[i].type == "OVERALL_MAX" then

				for i=0,24000,1000 do
					local light_level = minetest.get_node_light(checkpos, i)

					if light_level ~= nil then
						if light_around[i].type == "OVERALL_MAX" and
							light_level > light_around[i].threshold then
							return false
						end

						if light_around[i].type == "OVERALL_MIN" and
							light_level < light_around[i].threshold then
							return false
						end
					end
				end

			else
				local light_level = minetest.get_node_light(checkpos, time)

				if light_level ~= nil then
					if (light_around[i].type == "TIMED_MIN" or
						light_around[i].type == "CURRENT_MIN") and
						light_level < light_around[i].threshold then
							return false
					end

					if (light_around[i].type == "TIMED_MAX" or
						light_around[i].type == "CURRENT_MAX") and
						light_level > light_around[i].threshold then
							return false
					end
				end
			end
		end
		end
		end
	end

	return true
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] check_temperature_around
-- @param pos position to validate
-- @param temperature_around temperature around definitions
-- @return true/false
--------------------------------------------------------------------------------
function adv_spawning.check_temperature_around(pos,temperature_around)
	if temperature_around == nil then
		return true
	end

	--TODO
	return true
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] check_humidity_around
-- @param pos position to validate
-- @param humidity_around humidity around definitions
-- @return true/false
--------------------------------------------------------------------------------
function adv_spawning.check_humidity_around(pos,humidity_around)
	if humidity_around == nil then
		return true
	end
	--TODO
	return true
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] log
-- @param level
-- @param text
--------------------------------------------------------------------------------
function adv_spawning.log(level,text)

	local is_debug = false

	if not is_debug then
		return
	end

	minetest.log(level,text)
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] check_collisionbox
-- @param pos position to check
-- @param collisionbox collisionbox to use
-- @param spawn_inside nodes to spawn inside
--------------------------------------------------------------------------------
function adv_spawning.check_collisionbox(pos,collisionbox,spawn_inside)
	if collisionbox == nil then
		return true,nil
	end

	--skip for collisionboxes smaller then a single node
	if collisionbox[0] >= -0.5 and collisionbox[1] >= -0.5 and collisionbox[2] >= -0.5 and
		collisionbox[3] <= 0.5 and collisionbox[4] <= 0.5 and collisionbox[5] <= 0.5 then
		return true,nil
	end

	--lets do the more complex checks
	--first check if we need to move up
	if collisionbox[1] < -0.5 then
		pos.y = pos.y + (collisionbox[1]*-1) - 0.5
	end

	local corners = {}

	--centerpos
	table.insert(corners, pos)

	--top_right_back
	table.insert(corners,	{x=pos.x+collisionbox[3],
							y=pos.y+collisionbox[4],
							z=pos.z+collisionbox[2]})

	--top_right_front
	table.insert(corners,	{x=pos.x+collisionbox[3],
							y=pos.y+collisionbox[4],
							z=pos.z+collisionbox[5]})

	--bottom_right_front
	table.insert(corners,	{x=pos.x+collisionbox[3],
							y=pos.y+collisionbox[1],
							z=pos.z+collisionbox[5]})

	--bottom_right_back
	table.insert(corners,	{x=pos.x+collisionbox[3],
							y=pos.y+collisionbox[1],
							z=pos.z+collisionbox[2]})

	--top_left_back
	table.insert(corners,	{x=pos.x+collisionbox[0],
							y=pos.y+collisionbox[4],
							z=pos.z+collisionbox[2]})

	--top_left_front
	table.insert(corners,	{x=pos.x+collisionbox[0],
							y=pos.y+collisionbox[4],
							z=pos.z+collisionbox[5]})

	--bottom_left_front
	table.insert(corners,	{x=pos.x+collisionbox[0],
							y=pos.y+collisionbox[1],
							z=pos.z+collisionbox[5]})

	--bottom_left_back
	table.insert(corners,	{x=pos.x+collisionbox[0],
							y=pos.y+collisionbox[1],
							z=pos.z+collisionbox[2]})

	local last_checked = nil
	for i=0,#corners,1 do
		if not adv_spawning.is_same_pos(#corners[i],last_checked) then
			local node = minetest.get_node(#corners[i])

			if not adv_spawning.contains(spawn_inside,node.name) then
				return false,nil
			end
			last_checked = #corners[i]
		end
	end
	return true,pos.y
end