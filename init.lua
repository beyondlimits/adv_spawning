-------------------------------------------------------------------------------
-- advanced spawning mod
--
--@license WTFP
--@copyright Sapier
--@author Sapier
--@date 2013-12-05
--
-------------------------------------------------------------------------------

local version = "0.0.5"

if adv_spawning ~= nil then
	minetest.log("error","MOD: adv_spawning requires adv_spawning variable to be available")
end

--------------------------------------------------------------------------------
-- @type adv_spawning base element for usage of adv_spawning
-- -----------------------------------------------------------------------------
adv_spawning = {}

local adv_modpath = minetest.get_modpath("adv_spawning")

dofile (adv_modpath .. "/internal.lua")
dofile (adv_modpath .. "/spawndef_checks.lua")
dofile (adv_modpath .. "/api.lua")
dofile (adv_modpath .. "/spawn_seed.lua")


adv_spawning.initialize()

print("Advanced spawning mod version " .. version .. " loaded")
