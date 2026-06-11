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

-- ── Recipe mastery (M7.1) ─────────────────────────────────────────────────────

-- The mastery level for a given amount of mastery XP.
-- thresholds[i] = cumulative XP required to REACH level i (thresholds[1] must be 0).
-- Returns at least 1 (everything starts mastered at level 1).
function EconomyMath.masteryLevel(xp: number, thresholds: { number }): number
	local level = 1
	for i = 1, #thresholds do
		if xp >= thresholds[i] then
			level = i
		else
			break
		end
	end
	return level
end

-- The multiplicative tip bonus from a mastery level. Level 1 = 1.0 (no bonus);
-- each level above 1 adds perLevelBonus.tipMult.
function EconomyMath.masteryTipMult(level: number, perLevelBonus: { tipMult: number? }?): number
	local per = (perLevelBonus and perLevelBonus.tipMult) or 0
	return 1 + per * (level - 1)
end

-- cookTime multiplier from mastery (<1 = faster). Floored at 0.5 so mastery can
-- never make a dish instant. Reserved for station wiring; pure + tested now.
function EconomyMath.masteryCookSpeedMult(level: number, perLevelBonus: { cookSpeed: number? }?): number
	local per = (perLevelBonus and perLevelBonus.cookSpeed) or 0
	return math.max(0.5, 1 - per * (level - 1))
end

-- Convenience: resolve XP straight to a serve-value multiplier given a resolved
-- mastery curve entry ({ thresholds, perLevelBonus }). Used by both the client
-- (live serve value) and the server (theoretical-max ceiling) so they can't drift.
function EconomyMath.masteryMult(xp: number, curve: { thresholds: { number }, perLevelBonus: any }): number
	local level = EconomyMath.masteryLevel(xp, curve.thresholds)
	return EconomyMath.masteryTipMult(level, curve.perLevelBonus)
end

-- ── Restaurant prestige (M7.2) ────────────────────────────────────────────────

-- Permanent earnings multiplier for a restaurant at a given prestige level.
-- Level 0 (never franchised) = 1.0.
function EconomyMath.prestigeMultiplier(prestigeLevel: number, prestigeConfig: any): number
	return 1 + prestigeConfig.coinMultPerLevel * prestigeLevel
end

-- Prestige Tokens granted when franchising UP TO `newLevel` (the level just reached).
function EconomyMath.prestigeTokenGrant(newLevel: number, prestigeConfig: any): number
	return prestigeConfig.tokensBase + prestigeConfig.tokensPerLevel * (newLevel - 1)
end

-- ── Serve value ──────────────────────────────────────────────────────────────

-- Returns the total coins earned for a single serve.
-- `earningsMult` folds in mastery + prestige (defaults to 1 when omitted so the
-- base economy and existing callers/tests are unaffected).
function EconomyMath.serveValue(
	basePrice: number,
	patienceFraction: number,
	tipCurve: { fast: number, ok: number, slow: number },
	comboStreak: number,
	gameConfig: any,
	earningsMult: number?
): number
	local tip   = EconomyMath.tipMultiplier(patienceFraction, tipCurve, gameConfig)
	local combo = EconomyMath.comboMultiplier(comboStreak, gameConfig)
	return math.floor(basePrice * tip * combo * (earningsMult or 1))
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
-- `masteryMultFn(recipeId) -> number` (optional) folds each recipe's mastery tip
-- bonus into the ceiling; `globalMult` (optional) folds in the restaurant's
-- prestige multiplier. Both default to no-boost so existing callers/tests are
-- unaffected — and because mastery/prestige only grow through server-validated
-- play, recomputing the ceiling with the player's real values can't be gamed.
function EconomyMath.theoreticalMax(
	spawns: { any },
	recipes: { [string]: any },
	customers: { [string]: any },
	gameConfig: any,
	masteryMultFn: ((recipeId: string) -> number)?,
	globalMult: number?
): number
	local maxCombo = gameConfig.COMBO_MULTIPLIERS[#gameConfig.COMBO_MULTIPLIERS]
	local g = globalMult or 1
	local total = 0
	for _, spawn in ipairs(spawns) do
		local customerType = customers[spawn.customerTypeId]
		local tipCurve = customerType and customerType.tipCurve
			or { fast = 1.5, ok = 1.0, slow = 0.5 }
		for _, recipeId in ipairs(spawn.orders) do
			local recipe = recipes[recipeId]
			if recipe then
				local m = masteryMultFn and masteryMultFn(recipeId) or 1
				total += math.floor(recipe.basePrice * tipCurve.fast * maxCombo * m * g)
			end
		end
	end
	return total
end

-- Counts how many of each recipe a generated roster contains. Used server-side
-- to clamp a client's claimed mastery serves to what the level could produce.
function EconomyMath.rosterRecipeCounts(spawns: { any }): { [string]: number }
	local counts: { [string]: number } = {}
	for _, spawn in ipairs(spawns) do
		for _, recipeId in ipairs(spawn.orders) do
			counts[recipeId] = (counts[recipeId] or 0) + 1
		end
	end
	return counts
end

return EconomyMath
