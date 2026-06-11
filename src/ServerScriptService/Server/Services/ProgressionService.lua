--!strict
-- Manages XP, player level, and restaurant unlock state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService    = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Remotes        = require(ReplicatedStorage.Shared.Remotes)
local Restaurants    = require(ReplicatedStorage.Shared.Config.Restaurants)
local Prestige       = require(ReplicatedStorage.Shared.Config.Prestige)
local EconomyMath    = require(ReplicatedStorage.Shared.Modules.EconomyMath)

local ProgressionService = {}

-- XP thresholds: playerLevel i requires XP_TABLE[i] total XP to have reached it.
-- Simple linear: each level needs 100 more XP than the last.
local function xpForLevel(level: number): number
	return (level - 1) * 100
end

local function recalcPlayerLevel(profile: any)
	local level = 1
	while xpForLevel(level + 1) <= profile.xp do
		level += 1
	end
	profile.playerLevel = level
end

function ProgressionService:addXP(player: Player, amount: number)
	local profile = DataService:getProfile(player)
	if not profile then return end
	profile.xp += amount
	recalcPlayerLevel(profile)
end

function ProgressionService:recordStars(player: Player, restaurantId: string, levelIndex: number, stars: number)
	local profile = DataService:getProfile(player)
	if not profile then return end
	local key = restaurantId .. ":" .. levelIndex
	local prev = profile.levelStars[key] or 0
	if stars > prev then
		profile.levelStars[key] = stars
	end
end

function ProgressionService:bestStars(player: Player, restaurantId: string, levelIndex: number): number
	local profile = DataService:getProfile(player)
	if not profile then return 0 end
	return profile.levelStars[restaurantId .. ":" .. levelIndex] or 0
end

function ProgressionService:canUnlockRestaurant(player: Player, restaurantId: string): (boolean, string)
	local profile = DataService:getProfile(player)
	if not profile then return false, "no_profile" end
	if profile.unlockedRestaurants[restaurantId] then return false, "already_unlocked" end
	local config = Restaurants[restaurantId]
	if not config then return false, "unknown_restaurant" end
	local unlock = config.unlock
	if profile.playerLevel < unlock.level then return false, "level_required" end
	if profile.coins < unlock.coins       then return false, "insufficient_coins" end
	if profile.gems  < unlock.gems        then return false, "insufficient_gems" end
	return true, "ok"
end

-- ── Prestige / Franchise (M7.2) ───────────────────────────────────────────────

-- True only when EVERY level of the restaurant has been 3-starred.
function ProgressionService:isFullyCompleted(player: Player, restaurantId: string): boolean
	local profile = DataService:getProfile(player)
	if not profile then return false end
	local config = Restaurants[restaurantId]
	if not config then return false end
	for i = 1, config.levelCount do
		if (profile.levelStars[restaurantId .. ":" .. i] or 0) < 3 then
			return false
		end
	end
	return true
end

function ProgressionService:canFranchise(player: Player, restaurantId: string): (boolean, string)
	local profile = DataService:getProfile(player)
	if not profile then return false, "no_profile" end
	local config = Restaurants[restaurantId]
	if not config then return false, "unknown_restaurant" end
	if not profile.unlockedRestaurants[restaurantId] then return false, "not_unlocked" end
	if (profile.prestige[restaurantId] or 0) >= Prestige.maxLevel then
		return false, "max_prestige"
	end
	if not ProgressionService:isFullyCompleted(player, restaurantId) then
		return false, "not_completed"
	end
	return true, "ok"
end

-- The franchise transaction: bump prestige, RESET this restaurant's level stars
-- and its stations' upgrades, and grant Prestige Tokens. Per-restaurant scope, so
-- other restaurants are untouched.
function ProgressionService:franchise(player: Player, restaurantId: string): { ok: boolean, reason: string?, prestigeLevel: number?, tokens: number? }
	local ok, reason = ProgressionService:canFranchise(player, restaurantId)
	if not ok then return { ok = false, reason = reason } end

	local profile = DataService:getProfile(player)
	if not profile then return { ok = false, reason = "no_profile" } end
	local config = Restaurants[restaurantId]

	local newLevel = (profile.prestige[restaurantId] or 0) + 1
	profile.prestige[restaurantId] = newLevel

	-- Reset level stars for this restaurant only.
	for i = 1, config.levelCount do
		profile.levelStars[restaurantId .. ":" .. i] = nil
	end
	-- Reset upgrades for this restaurant's stations only.
	for _, stationId in ipairs(config.stationIds) do
		profile.upgrades[stationId] = nil
	end

	local tokens = EconomyMath.prestigeTokenGrant(newLevel, Prestige)
	profile.prestigeTokens = (profile.prestigeTokens or 0) + tokens

	DataService:save(player)
	return { ok = true, prestigeLevel = newLevel, tokens = tokens }
end

function ProgressionService:init()
	Remotes.FranchiseRestaurant.OnServerInvoke = function(player: Player, restaurantId: string)
		if type(restaurantId) ~= "string" then return { ok = false, reason = "bad_args" } end
		return ProgressionService:franchise(player, restaurantId)
	end

	Remotes.UnlockRestaurant.OnServerInvoke = function(player: Player, restaurantId: string)
		local ok, reason = ProgressionService:canUnlockRestaurant(player, restaurantId)
		if not ok then return { ok = false, reason = reason } end
		local config  = Restaurants[restaurantId]
		local unlock  = config.unlock
		if not EconomyService:spendCoins(player, unlock.coins) then
			return { ok = false, reason = "insufficient_coins" }
		end
		if not EconomyService:spendGems(player, unlock.gems) then
			EconomyService:addCoins(player, unlock.coins) -- refund
			return { ok = false, reason = "insufficient_gems" }
		end
		local profile = DataService:getProfile(player)
		if profile then profile.unlockedRestaurants[restaurantId] = true end
		return { ok = true }
	end
end

return ProgressionService
