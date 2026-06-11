--!strict
-- Restaurant Prestige / Franchise curve (M7.2).
--
-- Once every level of a restaurant is 3-starred, the player can FRANCHISE it:
-- reset that restaurant's level stars + station upgrades in exchange for a
-- permanent earnings multiplier on that restaurant, plus a grant of Prestige
-- Tokens (a soft-premium currency that sits between coins and gems).
--
-- Scope: PER-RESTAURANT (not a whole-account rebirth). More forgiving, and it
-- layers cleanly with the chef equip-slot growth in M8 (slots scale on total
-- prestige across restaurants).
--
-- Formula params only — no per-restaurant code. EconomyMath consumes these.

export type PrestigeConfig = {
	maxLevel: number,
	coinMultPerLevel: number,  -- earnings multiplier = 1 + coinMultPerLevel * prestigeLevel
	tokensBase: number,        -- tokens granted on the first franchise (reaching level 1)
	tokensPerLevel: number,    -- additional tokens per franchise level reached
	equipSlotsPerLevel: number, -- M8 hook: equip-slot growth per total prestige level
}

local Prestige: PrestigeConfig = {
	maxLevel            = 10,
	coinMultPerLevel    = 0.25,  -- +25% earnings from this restaurant per prestige level
	tokensBase          = 10,
	tokensPerLevel      = 5,     -- franchising to level N grants tokensBase + tokensPerLevel*(N-1)
	equipSlotsPerLevel  = 1,     -- reserved for M8 chef equip slots
}

return Prestige
