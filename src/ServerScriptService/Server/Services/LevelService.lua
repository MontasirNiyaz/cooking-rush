--!strict
-- Validates level-start requests and level results from clients.
-- Security boundary: all economy writes happen HERE, not on the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService        = require(script.Parent.DataService)
local EconomyService     = require(script.Parent.EconomyService)
local ProgressionService = require(script.Parent.ProgressionService)
local Remotes            = require(ReplicatedStorage.Shared.Remotes)
local Restaurants        = require(ReplicatedStorage.Shared.Config.Restaurants)
local Recipes            = require(ReplicatedStorage.Shared.Config.Recipes)
local Customers          = require(ReplicatedStorage.Shared.Config.Customers)
local GameConfig         = require(ReplicatedStorage.Shared.Config.GameConfig)
local LevelGenerator     = require(ReplicatedStorage.Shared.Modules.LevelGenerator)
local EconomyMath        = require(ReplicatedStorage.Shared.Modules.EconomyMath)

local LevelService = {}

function LevelService:init()
	-- ── RequestLevelStart ──────────────────────────────────────────────────────
	Remotes.RequestLevelStart.OnServerInvoke = function(
		player: Player,
		restaurantId: string,
		levelIndex: number
	)
		local profile = DataService:getProfile(player)
		if not profile then return nil end

		local restaurant = Restaurants[restaurantId]
		if not restaurant then return nil end

		-- Player must have unlocked this restaurant
		if not profile.unlockedRestaurants[restaurantId] then return nil end

		-- Must be a valid level number
		if levelIndex < 1 or levelIndex > restaurant.levelCount then return nil end

		local level = LevelGenerator.generate(restaurant, levelIndex, GameConfig, Recipes)
		return level
	end

	-- ── SubmitLevelResult ──────────────────────────────────────────────────────
	-- payload = { restaurantId, levelIndex, coinsEarned, stars, timeTaken }
	Remotes.SubmitLevelResult.OnServerInvoke = function(player: Player, payload: any)
		if type(payload) ~= "table" then return { ok = false, reason = "bad_payload" } end

		local restaurantId: string = payload.restaurantId
		local levelIndex: number   = payload.levelIndex
		local coinsEarned: number  = payload.coinsEarned
		local stars: number        = payload.stars

		-- Basic type checks
		if type(restaurantId) ~= "string"
			or type(levelIndex)   ~= "number"
			or type(coinsEarned)  ~= "number"
			or type(stars)        ~= "number"
		then
			return { ok = false, reason = "bad_types" }
		end

		local restaurant = Restaurants[restaurantId]
		if not restaurant then return { ok = false, reason = "unknown_restaurant" } end

		local profile = DataService:getProfile(player)
		if not profile then return { ok = false, reason = "no_profile" } end

		-- Re-generate the level server-side to compute the theoretical max.
		local level = LevelGenerator.generate(restaurant, levelIndex, GameConfig, Recipes)

		local theoreticalMax = EconomyMath.theoreticalMax(level.spawns, Recipes, Customers, GameConfig)
		if coinsEarned > theoreticalMax * GameConfig.COIN_OVERAGE_TOLERANCE then
			warn(string.format("[LevelService] %s submitted %d coins (max %d) — rejected",
				player.Name, coinsEarned, theoreticalMax))
			return { ok = false, reason = "implausible_coins" }
		end

		-- Stars sanity
		stars = math.clamp(math.floor(stars), 0, 3)

		local prevBest        = ProgressionService:bestStars(player, restaurantId, levelIndex)
		local isFirstClear    = prevBest == 0 and stars > 0
		local reward          = EconomyMath.levelReward(stars, coinsEarned, isFirstClear, prevBest, GameConfig)

		-- Apply rewards
		if reward.coins > 0 then EconomyService:addCoins(player, reward.coins) end
		if reward.gems  > 0 then EconomyService:addGems(player, reward.gems) end
		ProgressionService:addXP(player, reward.xp)
		ProgressionService:recordStars(player, restaurantId, levelIndex, stars)
		DataService:save(player)

		return { ok = true, reward = reward, newStars = stars }
	end

	-- ── GetProfile ─────────────────────────────────────────────────────────────
	Remotes.GetProfile.OnServerInvoke = function(player: Player)
		return DataService:getProfile(player)
	end
end

return LevelService
