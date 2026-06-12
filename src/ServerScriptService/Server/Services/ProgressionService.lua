--!strict
-- Manages XP, player level, and restaurant unlock state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService    = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local RemoteGuard    = require(script.Parent.RemoteGuard)
local Remotes        = require(ReplicatedStorage.Shared.Remotes)
local Restaurants    = require(ReplicatedStorage.Shared.Config.Restaurants)

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

function ProgressionService:init()
	Remotes.UnlockRestaurant.OnServerInvoke = function(player: Player, restaurantId: string)
		if not RemoteGuard.allow(player, "UnlockRestaurant") then return { ok = false, reason = "rate_limited" } end
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
