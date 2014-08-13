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
-- @function [parent=#adv_spawning] seed_step
-- @param self spawner entity
-- @param dtime time since last call
--------------------------------------------------------------------------------
function adv_spawning.seed_step(self,dtime)
	if not self.activated then
		adv_spawning.seed_activate(self)
		return
	end

	self.mydtime = self.mydtime + dtime

	if (self.mydtime < 1/adv_spawning.max_spawning_frequency_hz) then
		return
	end
	
	--check if we did finish initialization of our spawner list by now
	if not adv_spawning.seed_scan_for_applyable_spawners(self) then
		return
	end

	if adv_spawning.quota_enter() then
		self.pending_spawners = {}

		adv_spawning.seed_countdown_spawners(self,self.mydtime)
		self.mydtime = 0

		--check quota again
		adv_spawning.quota_leave()
		if not adv_spawning.quota_enter() then
			return
		end

		local per_step_count = 0
		local key = nil

		while #self.pending_spawners > 0 and
			per_step_count < adv_spawning.max_spawns_per_spawner and
			adv_spawning.time_over(10) do

			local rand_spawner = math.random(1,#self.pending_spawners)
			key = self.pending_spawners[rand_spawner]

			local tries = 1

			if adv_spawning.spawner_definitions[key].spawns_per_interval ~= nil then
				tries = adv_spawning.spawner_definitions[key].spawns_per_interval
			end

			while tries > 0 do

				if adv_spawning.handlespawner(key,self.object:getpos()) then
					self.spawning_data[key] =
						adv_spawning.spawner_definitions[key].spawn_interval
				else
					self.spawning_data[key] =
						adv_spawning.spawner_definitions[key].spawn_interval/4
				end

				--check quota again
				if not adv_spawning.quota_leave() then
					adv_spawning.dbg_log(2, "spawner " .. key .. " did use way too much time")
				end
				if not adv_spawning.quota_enter() then
					return
				end

				tries = tries -1
			end

			table.remove(self.pending_spawners,rand_spawner)
			per_step_count = per_step_count +1
		end

--		if (#self.pending_spawners > 0) then
--			adv_spawning.dbg_log(3, "Handled " .. per_step_count .. " spawners, spawners left: " .. #self.pending_spawners)
--		end
		if not adv_spawning.quota_leave() then
			adv_spawning.dbg_log(2, "spawner " .. key .. " did use way too much time")
		end
	end
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] seed_activate
-- @param self spawner entity
--------------------------------------------------------------------------------
function adv_spawning.seed_activate(self)
	if adv_spawning.quota_enter() then

		if adv_spawning.seed_check_for_collision(self) then
			adv_spawning.quota_leave()
			return
		end

		if self.serialized_data ~= nil then
			self.spawning_data = minetest.deserialize(self.serialized_data)
		end

		if self.spawning_data == nil then
			self.spawning_data = {}
		end

		adv_spawning.seed_validate_spawndata(self)
		
		self.pending_spawners = {}
		self.initialized_spawners = 0
		self.activated = true

		if not adv_spawning.quota_leave() then
			adv_spawning.dbg_log(2, "on activate  " .. self.name .. " did use way too much time")
		end
	end
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] on_rightclick
-- @param self spawner entity
-- @param clicker (unused)
--------------------------------------------------------------------------------
function adv_spawning.on_rightclick(self, clicker)
	if adv_spawning.debug then
		print("ADV_SPAWNING: Spawner may spawn following mobs:")
		local index = 1
		for key,value in pairs(self.spawning_data) do
			print(string.format("%3d:",index) .. string.format("%30s ",key) .. string.format("%3d s", value))
			index = index +1
		end
	end
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] seed_initialize
--------------------------------------------------------------------------------
function adv_spawning.seed_initialize()

	local spawner_texture = "adv_spawning_invisible.png^[makealpha:128,0,0^[makealpha:128,128,0"
	local spawner_collisionbox = { 0.0,0.0,0.0,0.0,0.0,0.0}

	if adv_spawning.debug then
		spawner_texture = "adv_spawning_spawner.png"
		spawner_collisionbox = { -0.5,-0.5,-0.5,0.5,0.5,0.5 }
	end

	minetest.register_entity("adv_spawning:spawn_seed",
		{
			collisionbox    = spawner_collisionbox,
			visual          = "sprite",
			textures        = { spawner_texture },
			physical        = false,
			groups          = { "immortal" },
			on_activate     = function(self,staticdata,dtime_s)
									self.activated = false
									self.mydtime = dtime_s
									self.serialized_data = staticdata
									adv_spawning.seed_activate(self)
								end,
			on_step         = adv_spawning.seed_step,
			get_staticdata  = function(self)
									return minetest.serialize(self.spawning_data)
								end,
			on_rightclick   = adv_spawning.on_rightclick
		}
	)
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] seed_validate_spawndata
-- @param self spawner entity
--------------------------------------------------------------------------------
function adv_spawning.seed_validate_spawndata(self)
	for key,value in pairs(self.spawning_data) do
		if adv_spawning.spawner_definitions[key] == nil then
			self.spawning_data[key] = nil
		end
	end
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] seed_countdown_spawners
-- @param self spawner entity
-- @param dtime time to decrement spawners
--------------------------------------------------------------------------------
function adv_spawning.seed_countdown_spawners(self,dtime)

	for key,value in pairs(self.spawning_data) do
		self.spawning_data[key] = self.spawning_data[key] - dtime

		if self.spawning_data[key] < 0 then
			table.insert(self.pending_spawners,key)
		end
	end
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] seed_check_for_collision
-- @param self spawner entity
-- @return true/false
--------------------------------------------------------------------------------
function adv_spawning.seed_check_for_collision(self)
	--TODO check if there already is another spawner at exactly this position
	return false
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] seed_scan_for_applyable_spawners
-- @param self spawner entity
-- @return true/false
--------------------------------------------------------------------------------
function adv_spawning.seed_scan_for_applyable_spawners(self)

	if self.initialized_spawners >= #adv_spawning.spawner_definitions then
		return true
	end

	local runindex = 0
	local pos = self.object:getpos()
	for key,value in pairs(adv_spawning.spawner_definitions) do
		if not adv_spawning.quota_enter() then
			return false
		end
		local starttime = adv_spawning.gettime()
		local continue = false
		
		if runindex >= self.initialized_spawners then
			self.initialized_spawners = self.initialized_spawners + 1
		else
			continue = true
		end
		
		runindex = runindex + 1

		--check if cyclic spawning is enabled
		if not continue and
			value.cyclic_spawning ~= nil and
			value.cyclic_spawning == false then
			continue = true
		end

		--if spawner is far away from spawn area don't even try to spawn
		if not continue and
			value.absolute_height ~= nil then
			if value.absolute_height.min ~= nil and
				value.absolute_height.min
				> pos.y + (adv_spawning.spawner_distance/2) then
				continue = true
			end

			if value.absolute_height.max ~= nil
				and value.absolute_height.max
				< pos.y - (adv_spawning.spawner_distance/2) then
				continue = true
			end
		end
		starttime = adv_spawning.check_time(starttime, key  .. " at spawn range check")

		--check for presence of environment
		if not continue then
			local radius =
				math.sqrt(adv_spawning.spawner_distance*
							adv_spawning.spawner_distance*2)/2

			if minetest.find_node_near(pos,radius,
							value.spawn_inside) == nil then
				continue = false
			end
		end
		starttime = adv_spawning.check_time(starttime, key .. " at environment check")

		if not continue then
			self.spawning_data[key] = value.spawn_interval * math.random()
		else
			self.spawning_data[key] = nil
		end
	end
	
	return self.initialized_spawners == #adv_spawning.spawner_definitions
end