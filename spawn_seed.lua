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

		while #self.pending_spawners > 0 and
			per_step_count < adv_spawning.max_spawns_per_spawner do

			local rand_spawner = math.random(1,#self.pending_spawners)
			local key = self.pending_spawners[rand_spawner]


			if adv_spawning.handlespawner(key,self.object:getpos()) then
				self.spawning_data[key] =
					adv_spawning.spawner_definitions[key].spawn_interval
			else
				self.spawning_data[key] =
					adv_spawning.spawner_definitions[key].spawn_interval/4
			end

			--check quota again
			adv_spawning.quota_leave()
			if not adv_spawning.quota_enter() then
				return
			end

			table.remove(self.pending_spawners,rand_spawner)
			per_step_count = per_step_count +1
		end

		if (#self.pending_spawners > 0) then
			print("Handled " .. per_step_count .. " spawners, spawners left: " .. #self.pending_spawners)
		end
		adv_spawning.quota_leave()
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

		adv_spawning.seed_scan_for_applyable_spawners(self)

		self.pending_spawners = {}
		self.activated = true

		adv_spawning.quota_leave()
	end
end

--------------------------------------------------------------------------------
-- @function [parent=#adv_spawning] seed_initialize
--------------------------------------------------------------------------------
function adv_spawning.seed_initialize()

	local spawner_texture = "adv_spawning_invisible.png^[makealpha:128,0,0^[makealpha:128,128,0"
	local spawner_collisionbox = { 0.0,0.0,0.0,0.0,0.0,0.0}

	--if debug
		spawner_texture = "adv_spawning_spawner.png"
		spawner_collisionbox = { -0.5,-0.5,-0.5,0.5,0.5,0.5 }
	--end

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
								end
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
	local pos = self.object:getpos()
	for key,value in pairs(adv_spawning.spawner_definitions) do
		local continue = false

		--if spawner is far away from spawn area don't even try to spawn
		if not continue and
			value.absolute_height ~= nil then
			if value.absolute_height.min
				> pos.y + (adv_spawning.spawner_distance/2) then
				continue = true
			end

			if value.absolute_height.max
				< pos.y - (adv_spawning.spawner_distance/2) then
				continue = true
			end
		end

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

		if not continue then
			self.spawning_data[key] = value.spawn_interval
		else
			self.spawning_data[key] = nil
		end
	end
end