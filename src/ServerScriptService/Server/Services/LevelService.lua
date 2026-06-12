--!strict
-- Validates level-start requests and level results from clients.
-- Security boundary: all economy writes happen HERE, not on the client.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local DataService        = require(script.Parent.DataService)
local EconomyService     = require(script.Parent.EconomyService)
local ProgressionService = require(script.Parent.ProgressionService)
local RemoteGuard        = require(script.Parent.RemoteGuard)
local Remotes            = require(ReplicatedStorage.Shared.Remotes)
local Restaurants        = require(ReplicatedStorage.Shared.Config.Restaurants)
local Recipes            = require(ReplicatedStorage.Shared.Config.Recipes)
local Customers          = require(ReplicatedStorage.Shared.Config.Customers)
local GameConfig         = require(ReplicatedStorage.Shared.Config.GameConfig)
local LevelGenerator     = require(ReplicatedStorage.Shared.Modules.LevelGenerator)
local EconomyMath        = require(ReplicatedStorage.Shared.Modules.EconomyMath)

local LevelService = {}

-- An open level run, recorded at RequestLevelStart and consumed by the matching
-- SubmitLevelResult. Keyed by UserId so one start = at most one rewarded submit.
type ActiveSession = {
	restaurantId: string,
	levelIndex: number,
	startedClock: number,  -- os.clock() at start (server-monotonic; client never sees it)
}
local activeSessions: { [number]: ActiveSession } = {}

function LevelService:init()
	-- ── RequestLevelStart ──────────────────────────────────────────────────────
	Remotes.RequestLevelStart.OnServerInvoke = function(
		player: Player,
		restaurantId: string,
		levelIndex: number
	)
		if not RemoteGuard.allow(player, "RequestLevelStart") then return nil end

		local profile = DataService:getProfile(player)
		if not profile then return nil end

		local restaurant = Restaurants[restaurantId]
		if not restaurant then return nil end

		-- Player must have unlocked this restaurant
		if not profile.unlockedRestaurants[restaurantId] then return nil end

		-- Must be a valid level number
		if levelIndex < 1 or levelIndex > restaurant.levelCount then return nil end

		local level = LevelGenerator.generate(restaurant, levelIndex, GameConfig, Recipes)

		-- Open a session so the eventual result can be tied back to a real start.
		-- Starting a new level abandons any previous unfinished run.
		activeSessions[player.UserId] = {
			restaurantId = restaurantId,
			levelIndex   = levelIndex,
			startedClock = os.clock(),
		}

		return level
	end

	-- ── SubmitLevelResult ──────────────────────────────────────────────────────
	-- payload = { restaurantId, levelIndex, coinsEarned, stars, timeTaken }
	Remotes.SubmitLevelResult.OnServerInvoke = function(player: Player, payload: any)
		if not RemoteGuard.allow(player, "SubmitLevelResult") then return { ok = false, reason = "rate_limited" } end
		if type(payload) ~= "table" then return { ok = false, reason = "bad_payload" } end

		local restaurantId: string  = payload.restaurantId
		local levelIndex: number    = payload.levelIndex
		local coinsEarned: number   = payload.coinsEarned
		local claimedStars: number  = payload.stars  -- client claim; used only for mismatch logging

		-- Basic type checks
		if type(restaurantId) ~= "string"
			or type(levelIndex)   ~= "number"
			or type(coinsEarned)  ~= "number"
			or type(claimedStars) ~= "number"
		then
			return { ok = false, reason = "bad_types" }
		end
		if coinsEarned < 0 then return { ok = false, reason = "bad_types" } end

		local restaurant = Restaurants[restaurantId]
		if not restaurant then return { ok = false, reason = "unknown_restaurant" } end

		local profile = DataService:getProfile(player)
		if not profile then return { ok = false, reason = "no_profile" } end

		-- ── Session check: the result must belong to a level this player started ──
		local session = activeSessions[player.UserId]
		if not session then
			return { ok = false, reason = "no_active_session" }
		end
		if session.restaurantId ~= restaurantId or session.levelIndex ~= levelIndex then
			return { ok = false, reason = "session_mismatch" }
		end
		-- Consume the session up front: exactly one submit per start, whatever the
		-- outcome — a rejected result can't be replayed to farm.
		local startedClock = session.startedClock
		activeSessions[player.UserId] = nil

		-- Re-generate the level server-side to compute the theoretical max + goals.
		local level = LevelGenerator.generate(restaurant, levelIndex, GameConfig, Recipes)

		-- ── Elapsed-time plausibility (server clock only; client timeTaken ignored) ──
		local elapsed = os.clock() - startedClock
		local minSeconds = EconomyMath.minPlausibleSeconds(level, GameConfig.MIN_RESULT_TIME_FACTOR)
		if elapsed < minSeconds then
			warn(string.format("[LevelService] %s submitted after %.1fs (min %.1fs) — rejected",
				player.Name, elapsed, minSeconds))
			return { ok = false, reason = "too_fast" }
		end

		local theoreticalMax = EconomyMath.theoreticalMax(level.spawns, Recipes, Customers, GameConfig)
		if coinsEarned > theoreticalMax * GameConfig.COIN_OVERAGE_TOLERANCE then
			warn(string.format("[LevelService] %s submitted %d coins (max %d) — rejected",
				player.Name, coinsEarned, theoreticalMax))
			return { ok = false, reason = "implausible_coins" }
		end

		-- ── Stars are SERVER-computed from coins; the client's claim is never trusted ──
		local stars = EconomyMath.starsFor(coinsEarned, level.goals)
		if math.floor(claimedStars) ~= stars then
			warn(string.format("[LevelService] %s claimed %d stars, server computed %d (coins %d)",
				player.Name, math.floor(claimedStars), stars, coinsEarned))
		end

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
		if not RemoteGuard.allow(player, "GetProfile") then return nil end
		return DataService:getProfile(player)
	end

	-- Drop any open session when a player leaves so UserIds can't accumulate.
	Players.PlayerRemoving:Connect(function(player)
		activeSessions[player.UserId] = nil
	end)
end

return LevelService
