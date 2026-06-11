--!strict
-- Pure economy math. No Roblox API; inject GameConfig for unit-test isolation.

local EconomyMath = {}

-- ── Tip calculation ───────────────────────────────────────────────────────────

-- patienceFraction: fraction of patience REMAINING when the dish was served (0=none left, 1=full).
-- tipCurve: { fast, ok, slow } multipliers from the customer archetype.
-- gameConfig: the GameConfig table (passed in so tests can use a mock).
function EconomyMath.tipMultiplier(
	patienceFraction: number,
	tipCurve: { fast: number, ok: number, slow: number },
	gameConfig: any
): number
	-- patience remaining > (1 - FAST_THRESHOLD) means it was served fast
	if patienceFraction > (1 - gameConfig.TIP_FAST_THRESHOLD) then
		return tipCurve.fast
	elseif patienceFraction < (1 - gameConfig.TIP_SLOW_THRESHOLD) then
		return tipCurve.slow
	else
		return tipCurve.ok
	end
end

-- ── Combo multiplier ─────────────────────────────────────────────────────────

-- streak: consecutive successful serves without a miss or wrong dish.
-- gameConfig: must have COMBO_MULTIPLIERS and COMBO_TIER_THRESHOLDS arrays.
function EconomyMath.comboMultiplier(streak: number, gameConfig: any): number
	local tiers       = gameConfig.COMBO_MULTIPLIERS
	local thresholds  = gameConfig.COMBO_TIER_THRESHOLDS
	local current     = tiers[1]
	for i, threshold in ipairs(thresholds) do
		if streak >= threshold then
			current = tiers[i]
		else
			break
		end
	end
	return current
end

-- ── Serve value ──────────────────────────────────────────────────────────────

-- Returns the total coins earned for a single serve.
function EconomyMath.serveValue(
	basePrice: number,
	patienceFraction: number,
	tipCurve: { fast: number, ok: number, slow: number },
	comboStreak: number,
	gameConfig: any
): number
	local tip   = EconomyMath.tipMultiplier(patienceFraction, tipCurve, gameConfig)
	local combo = EconomyMath.comboMultiplier(comboStreak, gameConfig)
	return math.floor(basePrice * tip * combo)
end

-- ── Stars ────────────────────────────────────────────────────────────────────

function EconomyMath.starsFor(
	coinsEarned: number,
	goals: { oneStar: number, twoStar: number, threeStar: number }
): number
	if coinsEarned >= goals.threeStar then return 3
	elseif coinsEarned >= goals.twoStar then return 2
	elseif coinsEarned >= goals.oneStar then return 1
	else return 0
	end
end

-- ── Level reward ─────────────────────────────────────────────────────────────

-- isFirstTimeClear: true if the player has never earned ≥1 star on this level before.
-- previousBestStars: the player's prior best (0 if never cleared).
function EconomyMath.levelReward(
	stars: number,
	coinsEarned: number,
	isFirstTimeClear: boolean,
	previousBestStars: number,
	gameConfig: any
): { coins: number, gems: number, xp: number }
	local gems = 0
	-- Gems only on first-ever 3-star clear
	if stars == 3 and previousBestStars < 3 then
		gems = gameConfig.GEM_FIRST_THREE_STAR
	end
	local xp = stars * gameConfig.XP_PER_STAR
	-- Award coins only if this run improved the star count (prevents farming easy levels)
	local coins = if stars > previousBestStars then coinsEarned else 0
	return { coins = coins, gems = gems, xp = xp }
end

-- ── Daily reward ──────────────────────────────────────────────────────────────

-- True when enough time has elapsed since the last claim to claim again.
-- Pure so the eligibility rule can be unit-tested without os.time / a profile.
function EconomyMath.canClaimDaily(lastClaim: number, now: number, intervalSeconds: number): boolean
	return (now - lastClaim) >= intervalSeconds
end

-- ── Theoretical max coins (server validation) ─────────────────────────────────

-- Upper-bound estimate: every customer served instantly at max combo.
function EconomyMath.theoreticalMax(
	spawns: { any },
	recipes: { [string]: any },
	customers: { [string]: any },
	gameConfig: any
): number
	local maxCombo = gameConfig.COMBO_MULTIPLIERS[#gameConfig.COMBO_MULTIPLIERS]
	local total = 0
	for _, spawn in ipairs(spawns) do
		local customerType = customers[spawn.customerTypeId]
		local tipCurve = customerType and customerType.tipCurve
			or { fast = 1.5, ok = 1.0, slow = 0.5 }
		for _, recipeId in ipairs(spawn.orders) do
			local recipe = recipes[recipeId]
			if recipe then
				total += math.floor(recipe.basePrice * tipCurve.fast * maxCombo)
			end
		end
	end
	return total
end

return EconomyMath
