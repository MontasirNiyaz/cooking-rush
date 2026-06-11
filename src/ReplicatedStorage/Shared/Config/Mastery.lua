--!strict
-- Recipe Mastery curve (M7.1).
--
-- Cooking a dish accrues mastery XP for THAT dish; mastery levels grant small
-- permanent buffs to it (more tip value, faster cook). This is a grind ladder
-- that multiplies the value of every recipe the menu already contains — no new
-- content is authored.
--
-- Scalability: one global default curve covers every recipe in the game. A recipe
-- only needs an entry in `overrides` if a designer wants it to master differently.
-- Adding a recipe = zero mastery config.

export type MasteryBonus = {
	tipMult: number?,   -- +fraction of serve value per level above 1 (0.02 = +2%/level)
	cookSpeed: number?, -- cookTime reduction per level above 1 (0.01 = -1%/level), reserved for station wiring
}

export type MasteryCurve = {
	thresholds: { number },   -- cumulative XP to REACH level i (index = level; [1] must be 0)
	perLevelBonus: MasteryBonus,
}

local Mastery = {
	-- XP granted per successful serve of a dish (before any modifiers).
	xpPerServe = 1,

	-- Default curve, applied to every recipe unless overridden below.
	-- 10 levels; thresholds are cumulative XP. Early levels come fast for the
	-- dopamine hit, later levels stretch out.
	defaultThresholds   = { 0, 5, 15, 30, 50, 80, 120, 170, 230, 300 },
	defaultPerLevelBonus = { tipMult = 0.02, cookSpeed = 0.01 } :: MasteryBonus,

	-- Sparse per-recipe overrides. Each may override `thresholds`, `perLevelBonus`,
	-- or both. Anything omitted falls back to the default.
	overrides = {} :: { [string]: { thresholds: { number }?, perLevelBonus: MasteryBonus? } },
}

-- Resolve the effective curve for a recipe (default merged with any override).
-- Pure: only reads this module's own data, no external requires.
function Mastery.resolve(recipeId: string): MasteryCurve
	local ov = Mastery.overrides[recipeId]
	return {
		thresholds    = (ov and ov.thresholds)    or Mastery.defaultThresholds,
		perLevelBonus = (ov and ov.perLevelBonus) or Mastery.defaultPerLevelBonus,
	}
end

return Mastery
