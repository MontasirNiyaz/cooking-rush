--!strict
-- Generates a Level table from restaurant config + index.
-- PURE: no Roblox APIs, no `require(script...)`. All dependencies injected.
-- This makes it unit-testable and keeps it honest about what it actually needs.

local LevelGenerator = {}

export type SpawnEntry = {
	atSecond: number,
	customerTypeId: string,
	orders: { string },
	patienceScale: number,
}

export type Level = {
	restaurantId: string,
	index: number,
	duration: number,
	spawns: { SpawnEntry },
	goals: { oneStar: number, twoStar: number, threeStar: number },
}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * math.clamp(t, 0, 1)
end

local function easeInOut(t: number): number
	-- Smoothstep: slow start and end, fast middle
	return t * t * (3 - 2 * t)
end

-- Deterministic hash so each (restaurantId, index) pair seeds a unique RNG.
local function hashSeed(restaurantId: string, index: number): number
	local h = 0
	for i = 1, #restaurantId do
		h = (h * 31 + string.byte(restaurantId, i)) % 2 ^ 31
	end
	return (h + index * 2654435761) % 2 ^ 31
end

-- Estimates total achievable coins for a spawn list (used to set star thresholds).
local function estimateCoins(
	spawns: { SpawnEntry },
	recipes: { [string]: any }
): number
	local total = 0
	for _, spawn in ipairs(spawns) do
		for _, recipeId in ipairs(spawn.orders) do
			local recipe = recipes[recipeId]
			if recipe then
				-- Assume "ok" speed × 1.1 average combo — conservative middle estimate
				total += math.floor(recipe.basePrice * 1.0 * 1.1)
			end
		end
	end
	return total
end

--[[
	restaurant  — a RestaurantConfig table from Restaurants/
	index       — 1-based level number
	gameConfig  — GameConfig table
	recipes     — Recipes table (for coin estimation only)
	Returns a fully-resolved Level table.
]]
function LevelGenerator.generate(
	restaurant: any,
	index: number,
	gameConfig: any,
	recipes: { [string]: any }
): Level
	local levelCount = restaurant.levelCount or 40
	local t          = easeInOut(math.clamp((index - 1) / math.max(levelCount - 1, 1), 0, 1))

	local customerCount  = math.floor(lerp(gameConfig.MIN_CUSTOMERS, gameConfig.MAX_CUSTOMERS, t) + 0.5)
	local spawnGap       = lerp(gameConfig.MAX_SPAWN_GAP, gameConfig.MIN_SPAWN_GAP, t)
	local maxOrders      = 1 + math.floor(t * 2)
	local patienceScale  = lerp(gameConfig.MAX_PATIENCE_SCALE, gameConfig.MIN_PATIENCE_SCALE, t)

	local menu: { string }          = restaurant.menu
	local customerTypes: { string } = restaurant.customerTypeIds

	local rng        = Random.new(hashSeed(restaurant.id, index))
	local spawns: { SpawnEntry } = {}
	local clock      = 2.0  -- first customer arrives 2 s after level start

	for i = 1, customerCount do
		local orderCount = rng:NextInteger(1, maxOrders)
		local orders: { string } = {}
		for _ = 1, orderCount do
			orders[#orders + 1] = menu[rng:NextInteger(1, #menu)]
		end
		spawns[i] = {
			atSecond       = clock,
			customerTypeId = customerTypes[rng:NextInteger(1, #customerTypes)],
			orders         = orders,
			patienceScale  = patienceScale,
		}
		clock += spawnGap * (1 + rng:NextNumber() * gameConfig.SPAWN_GAP_JITTER)
	end

	-- Compute star thresholds from estimated achievable coins
	local estimated = estimateCoins(spawns, recipes)

	local level: Level = {
		restaurantId = restaurant.id,
		index        = index,
		duration     = 0,  -- roster-exhausted mode
		spawns       = spawns,
		goals = {
			oneStar   = math.max(1, math.floor(estimated * 0.40)),
			twoStar   = math.max(2, math.floor(estimated * 0.65)),
			threeStar = math.max(3, math.floor(estimated * 0.88)),
		},
	}

	-- ── Apply authored overrides (last-write-wins per field) ──────────────────
	local overrides = restaurant.levelOverrides
	if overrides and overrides[index] then
		local ov = overrides[index]

		if ov.customerCount then
			-- Rebuild spawns with a fixed count, but keep the same menu pool
			local pool: { string } = ov.menuPool or menu
			local rng2 = Random.new(hashSeed(restaurant.id, index + 10000))
			local newSpawns: { SpawnEntry } = {}
			local clock2 = 2.0
			for i = 1, ov.customerCount do
				local oCount = if ov.tutorial then 1 else rng2:NextInteger(1, maxOrders)
				local oList: { string } = {}
				for _ = 1, oCount do oList[#oList + 1] = pool[rng2:NextInteger(1, #pool)] end
				newSpawns[i] = {
					atSecond       = clock2,
					customerTypeId = customerTypes[rng2:NextInteger(1, #customerTypes)],
					orders         = oList,
					patienceScale  = if ov.tutorial then patienceScale * 1.4 else patienceScale,
				}
				clock2 += spawnGap * 1.5
			end
			level.spawns = newSpawns
			-- Recalculate goals for the new roster
			local est2 = estimateCoins(newSpawns, recipes)
			level.goals = {
				oneStar   = math.max(1, math.floor(est2 * (if ov.tutorial then 0.20 else 0.40))),
				twoStar   = math.max(2, math.floor(est2 * (if ov.tutorial then 0.50 else 0.65))),
				threeStar = math.max(3, math.floor(est2 * (if ov.tutorial then 0.80 else 0.88))),
			}
		end

		if ov.durationScale and ov.durationScale ~= 1 then
			level.duration = clock * ov.durationScale
		end
	end

	return level
end

return LevelGenerator
