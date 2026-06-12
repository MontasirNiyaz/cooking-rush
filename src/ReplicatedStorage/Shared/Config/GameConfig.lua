--!strict
-- Global tuning constants. No magic numbers anywhere else in the codebase.

return {
	-- Combo streak tiers: index = tier (1-based), value = multiplier
	COMBO_MULTIPLIERS       = { 1.0, 1.1, 1.25, 1.5 },
	-- Minimum consecutive serves to reach each tier
	COMBO_TIER_THRESHOLDS   = { 0, 2, 4, 7 },

	-- Level difficulty curve
	MIN_CUSTOMERS           = 4,
	MAX_CUSTOMERS           = 18,
	MAX_PATIENCE_SCALE      = 1.3,   -- easy levels: more patient
	MIN_PATIENCE_SCALE      = 0.8,   -- hard levels: less patient
	MAX_SPAWN_GAP           = 12,    -- seconds between arrivals at min difficulty
	MIN_SPAWN_GAP           = 3,     -- seconds between arrivals at max difficulty
	SPAWN_GAP_JITTER        = 0.3,   -- fraction of gap added as random noise
	-- Order complexity: max simultaneous orders per customer. Ramps on linear
	-- level progress so 2-item orders appear mid-game and 3-item orders late.
	MIN_MAX_ORDERS          = 1,     -- early levels: single-item orders
	MAX_MAX_ORDERS          = 3,     -- final levels: up to 3-item orders

	-- Economy
	DEFAULT_LEVEL_DURATION  = 0,     -- 0 = roster-exhausted mode
	GEM_FIRST_THREE_STAR    = 3,     -- gems awarded on first-time 3-star
	XP_PER_STAR             = 10,    -- XP per star earned (cumulative per level)

	-- Tips: multipliers applied to basePrice based on serve speed
	TIP_FAST                = 1.5,
	TIP_OK                  = 1.0,
	TIP_SLOW                = 0.5,

	-- Fast/slow serve thresholds (fraction of patience consumed when served)
	TIP_FAST_THRESHOLD      = 0.35,  -- served before 35% patience drained
	TIP_SLOW_THRESHOLD      = 0.75,  -- served after 75% patience drained

	-- DataStore
	DATASTORE_NAME          = "CookingRushV1",
	AUTOSAVE_INTERVAL       = 60,    -- seconds

	-- Server validation
	COIN_OVERAGE_TOLERANCE  = 1.15,  -- allow 15% over theoretical max (rounding, combo variance)

	-- Daily reward
	DAILY_COIN_BASE         = 50,
	DAILY_INTERVAL_SECONDS  = 86400,

	-- Chefs (M8)
	CHEF_BASE_EQUIP_SLOTS   = 3,     -- equip slots before any prestige
	CHEF_LEVEL_BONUS        = 0.15,  -- each fusion level adds 15% of a chef's base bonus
	CHEF_SHINY_BONUS_MULT   = 2.0,   -- a shiny doubles its bonus portion
	CHEF_FUSION_DUPES       = 3,     -- duplicate chefs consumed per fusion level-up
	CHEF_MAX_LEVEL          = 10,    -- fusion level cap
	CHEF_AUTOSERVE_INTERVAL = 6,     -- seconds between autoServe deliveries
}
