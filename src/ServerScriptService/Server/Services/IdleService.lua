--!strict
-- Idle / passive empire, server-authoritative (M9).
--
-- Each unlocked restaurant accrues coins over real time, even while the player is
-- offline. Output = base rate (derived from the restaurant's `dailyIncome`) ×
-- prestige × assigned-chef passives × average recipe mastery, capped by an offline
-- cap that gem upgrades extend.
--
-- Anti-exploit: the SERVER owns the clock. `elapsed` is always os.time() minus the
-- stored per-restaurant last-collect timestamp; the client never supplies a delta.
-- All grants go through EconomyService and reset the timestamp to os.time().

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService    = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local MasteryService = require(script.Parent.MasteryService)
local Remotes        = require(ReplicatedStorage.Shared.Remotes)
local Restaurants    = require(ReplicatedStorage.Shared.Config.Restaurants)
local Chefs          = require(ReplicatedStorage.Shared.Config.Chefs)
local GameConfig     = require(ReplicatedStorage.Shared.Config.GameConfig)
local Prestige       = require(ReplicatedStorage.Shared.Config.Prestige)
local EconomyMath    = require(ReplicatedStorage.Shared.Modules.EconomyMath)
local ChefMath       = require(ReplicatedStorage.Shared.Modules.ChefMath)
local IdleMath       = require(ReplicatedStorage.Shared.Modules.IdleMath)

local IdleService = {}

-- ── Derived quantities ─────────────────────────────────────────────────────────

local function capSeconds(profile: any): number
	return (GameConfig.IDLE_BASE_CAP_HOURS + (profile.idleCapBonusHours or 0)) * 3600
end

local function baseRatePerSecond(restaurant: any): number
	return (restaurant.dailyIncome or 0) / 86400 * GameConfig.IDLE_RATE_MULT
end

-- Average mastery multiplier across a restaurant's menu (so idle output rewards
-- the dishes the player has ground up).
local function avgMasteryMult(profile: any, restaurant: any): number
	local menu = restaurant.menu
	if not menu or #menu == 0 then return 1 end
	local sum = 0
	for _, recipeId in ipairs(menu) do
		sum += MasteryService:multFor(profile, recipeId)
	end
	return sum / #menu
end

-- Full idle multiplier for a restaurant: prestige × assigned-chef idle × mastery.
local function restaurantMultiplier(profile: any, restaurantId: string, restaurant: any): number
	local prestigeMult = EconomyMath.prestigeMultiplier(profile.prestige[restaurantId] or 0, Prestige)
	local assigned     = profile.idleAssignments[restaurantId] or {}
	local chefPassives = ChefMath.aggregatePassives(profile.chefs, assigned, Chefs.list, GameConfig)
	local chefMult     = ChefMath.idleMultiplier(chefPassives)
	return prestigeMult * chefMult * avgMasteryMult(profile, restaurant)
end

-- A restaurant starts accruing from the moment it's first seen (or unlocked), not
-- from epoch — otherwise a fresh restaurant would read as instantly capped.
local function ensureTimestamp(profile: any, restaurantId: string, now: number)
	if profile.lastIncomeClaim[restaurantId] == nil then
		profile.lastIncomeClaim[restaurantId] = now
	end
end

-- ── Core ──────────────────────────────────────────────────────────────────────

-- Pending coins (and the inputs that produced them) for one restaurant right now.
function IdleService:_pending(profile: any, restaurantId: string, restaurant: any, now: number): any
	ensureTimestamp(profile, restaurantId, now)
	local elapsed = now - profile.lastIncomeClaim[restaurantId]
	local rate    = baseRatePerSecond(restaurant)
	local mult    = restaurantMultiplier(profile, restaurantId, restaurant)
	local cap     = capSeconds(profile)
	return {
		coins       = IdleMath.accrue(rate, mult, elapsed, cap),
		ratePerSec  = rate * mult,
		elapsed     = elapsed,
		capSeconds  = cap,
		capFraction = IdleMath.capFraction(elapsed, cap),
	}
end

-- UI snapshot: per-restaurant accrual + cap-upgrade info. Read-only (no grant).
function IdleService:getState(player: Player): any
	local profile = DataService:getProfile(player)
	if not profile then return { ok = false, reason = "no_profile" } end
	local now = os.time()

	local restaurantsOut: { any } = {}
	local totalPending = 0
	for restaurantId in pairs(profile.unlockedRestaurants) do
		local restaurant = Restaurants[restaurantId]
		if restaurant then
			local p = IdleService:_pending(profile, restaurantId, restaurant, now)
			totalPending += p.coins
			table.insert(restaurantsOut, {
				restaurantId = restaurantId,
				displayName  = restaurant.displayName,
				pending      = p.coins,
				ratePerSec   = p.ratePerSec,
				capFraction  = p.capFraction,
				assigned     = profile.idleAssignments[restaurantId] or {},
				slots        = GameConfig.IDLE_CHEF_SLOTS,
			})
		end
	end

	local atCapMax = (profile.idleCapBonusHours or 0) >= GameConfig.IDLE_CAP_MAX_BONUS_HOURS
	return {
		ok            = true,
		restaurants   = restaurantsOut,
		totalPending  = totalPending,
		capHours      = GameConfig.IDLE_BASE_CAP_HOURS + (profile.idleCapBonusHours or 0),
		capUpgradeGems = atCapMax and nil or GameConfig.IDLE_CAP_UPGRADE_GEM_COST,
		capUpgradeHours = GameConfig.IDLE_CAP_UPGRADE_HOURS,
	}
end

-- Collect one restaurant (or all unlocked when restaurantId is nil). Grants coins
-- and resets each collected restaurant's timestamp to now.
function IdleService:collect(player: Player, restaurantId: string?): any
	local profile = DataService:getProfile(player)
	if not profile then return { ok = false, reason = "no_profile" } end
	local now = os.time()

	local targets: { string } = {}
	if restaurantId then
		if not profile.unlockedRestaurants[restaurantId] then return { ok = false, reason = "not_unlocked" } end
		targets = { restaurantId }
	else
		for rid in pairs(profile.unlockedRestaurants) do table.insert(targets, rid) end
	end

	local total = 0
	for _, rid in ipairs(targets) do
		local restaurant = Restaurants[rid]
		if restaurant then
			local p = IdleService:_pending(profile, rid, restaurant, now)
			if p.coins > 0 then
				EconomyService:addCoins(player, p.coins)
				total += p.coins
			end
			profile.lastIncomeClaim[rid] = now
		end
	end

	if total > 0 then DataService:save(player) end
	return { ok = true, collected = total }
end

-- ── Chef assignment ─────────────────────────────────────────────────────────

local function assignedAnywhere(profile: any): { [number]: boolean }
	local set: { [number]: boolean } = {}
	for _, uids in pairs(profile.idleAssignments) do
		for _, uid in ipairs(uids) do set[uid] = true end
	end
	return set
end

-- Fill a restaurant's free idle slots with the best unassigned owned chefs.
function IdleService:autoAssign(player: Player, restaurantId: string): any
	local profile = DataService:getProfile(player)
	if not profile then return { ok = false, reason = "no_profile" } end
	if not profile.unlockedRestaurants[restaurantId] then return { ok = false, reason = "not_unlocked" } end

	local current = profile.idleAssignments[restaurantId] or {}
	profile.idleAssignments[restaurantId] = current
	local free = GameConfig.IDLE_CHEF_SLOTS - #current
	if free <= 0 then return { ok = false, reason = "slots_full" } end

	local taken = assignedAnywhere(profile)
	local candidates: { any } = {}
	for _, c in ipairs(profile.chefs) do
		if not taken[c.uid] then table.insert(candidates, c) end
	end
	if #candidates == 0 then return { ok = false, reason = "no_free_chefs" } end

	table.sort(candidates, function(a, b)
		return ChefMath.chefIdleValue(a, Chefs.list, GameConfig) > ChefMath.chefIdleValue(b, Chefs.list, GameConfig)
	end)

	local added = 0
	for i = 1, math.min(free, #candidates) do
		table.insert(current, candidates[i].uid)
		added += 1
	end
	DataService:save(player)
	return { ok = true, assigned = added }
end

function IdleService:unassign(player: Player, restaurantId: string, uid: number): any
	local profile = DataService:getProfile(player)
	if not profile then return { ok = false, reason = "no_profile" } end
	local list = profile.idleAssignments[restaurantId]
	if not list then return { ok = false, reason = "not_assigned" } end
	for i, u in ipairs(list) do
		if u == uid then
			table.remove(list, i)
			DataService:save(player)
			return { ok = true }
		end
	end
	return { ok = false, reason = "not_assigned" }
end

-- Remove a chef from every idle assignment (called when a chef is consumed, e.g. fusion).
function IdleService:removeChef(profile: any, uid: number)
	for _, list in pairs(profile.idleAssignments) do
		for i = #list, 1, -1 do
			if list[i] == uid then table.remove(list, i) end
		end
	end
end

-- ── Offline-cap upgrade (gem sink) ────────────────────────────────────────────

function IdleService:purchaseCap(player: Player): any
	local profile = DataService:getProfile(player)
	if not profile then return { ok = false, reason = "no_profile" } end
	if (profile.idleCapBonusHours or 0) >= GameConfig.IDLE_CAP_MAX_BONUS_HOURS then
		return { ok = false, reason = "max_cap" }
	end
	if not EconomyService:spendGems(player, GameConfig.IDLE_CAP_UPGRADE_GEM_COST) then
		return { ok = false, reason = "insufficient_gems" }
	end
	profile.idleCapBonusHours = (profile.idleCapBonusHours or 0) + GameConfig.IDLE_CAP_UPGRADE_HOURS
	DataService:save(player)
	return { ok = true, capHours = GameConfig.IDLE_BASE_CAP_HOURS + profile.idleCapBonusHours }
end

function IdleService:init()
	Remotes.GetIdleState.OnServerInvoke = function(player: Player)
		return IdleService:getState(player)
	end
	Remotes.CollectIdle.OnServerInvoke = function(player: Player, restaurantId: any)
		local rid = type(restaurantId) == "string" and restaurantId or nil
		return IdleService:collect(player, rid)
	end
	Remotes.AutoAssignIdle.OnServerInvoke = function(player: Player, restaurantId: string)
		if type(restaurantId) ~= "string" then return { ok = false, reason = "bad_args" } end
		return IdleService:autoAssign(player, restaurantId)
	end
	Remotes.UnassignChefIdle.OnServerInvoke = function(player: Player, restaurantId: string, uid: number)
		if type(restaurantId) ~= "string" or type(uid) ~= "number" then return { ok = false, reason = "bad_args" } end
		return IdleService:unassign(player, restaurantId, uid)
	end
	Remotes.PurchaseIdleCap.OnServerInvoke = function(player: Player)
		return IdleService:purchaseCap(player)
	end
end

return IdleService
