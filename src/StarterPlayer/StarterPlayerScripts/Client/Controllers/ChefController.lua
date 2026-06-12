--!strict
-- Applies equipped-chef passives to the live kitchen (M8.3).
--
-- At each level start it reads the player's equipped chefs from the shared profile
-- cache, aggregates their effect tags via the pure ChefMath, and:
--   • exposes the bundle via getPassives() — OrderController folds tipMult into the
--     serve value, StationController applies cookSpeedMult + burnImmuneChance to
--     cookers (both mirror what the server re-derives for the coin ceiling)
--   • drives the autoServe tag on a timer, delivering a ready dish periodically.
--
-- Resolution is purely a read of profile state; the server is authoritative for
-- the chef inventory and for validating any coins those passives produce.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Chefs      = require(ReplicatedStorage.Shared.Config.Chefs)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ChefMath   = require(ReplicatedStorage.Shared.Modules.ChefMath)
local Enums      = require(ReplicatedStorage.Shared.Modules.Enums)
local Trove      = require(ReplicatedStorage.Shared.Packages.Trove)

local ChefController = {}

local NEUTRAL = { cookSpeedMult = 1, tipMult = 1, burnImmuneChance = 0, autoServe = false }

local _passives = table.clone(NEUTRAL)
local _autoAccum = 0
local _trove = Trove.new()

-- The currently-active aggregated passive bundle. Always defined.
function ChefController:getPassives(): any
	return _passives
end

-- Recompute the aggregate from the shared profile cache. Cheap; called at Intro.
local function recompute()
	local ProfileController = require(script.Parent.ProfileController)
	local profile = ProfileController:get()
	if not profile or not profile.chefs then
		_passives = table.clone(NEUTRAL)
		return
	end
	_passives = ChefMath.aggregatePassives(
		profile.chefs, profile.equippedChefs or {}, Chefs.list, GameConfig
	)
end

function ChefController:refresh()
	recompute()
end

function ChefController:init()
	local LevelController = require(script.Parent.LevelController)

	LevelController.StateChanged:Connect(function(newState: string)
		if newState == Enums.LevelState.Intro then
			recompute()
			_autoAccum = 0
		elseif newState == Enums.LevelState.Idle then
			_passives = table.clone(NEUTRAL)
		end
	end)

	-- autoServe: deliver a ready dish every CHEF_AUTOSERVE_INTERVAL seconds.
	_trove:Connect(RunService.Heartbeat, function(dt: number)
		if LevelController.state ~= Enums.LevelState.Playing then return end
		if not _passives.autoServe then return end
		_autoAccum += dt
		if _autoAccum >= GameConfig.CHEF_AUTOSERVE_INTERVAL then
			_autoAccum -= GameConfig.CHEF_AUTOSERVE_INTERVAL
			local CustomerController = require(script.Parent.CustomerController)
			CustomerController:autoServeOne()
		end
	end)
end

return ChefController
