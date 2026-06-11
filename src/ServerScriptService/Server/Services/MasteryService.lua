--!strict
-- Recipe Mastery, server-authoritative (M7.1).
--
-- The server is the ONLY writer of mastery state. Clients report how many of each
-- dish they served during a level (in the SubmitLevelResult payload); LevelService
-- validates those counts against the generated roster, then hands the validated
-- tally here to apply XP. Mastery only ever grows through play the server can
-- verify, which is what lets the level-result validator safely fold each recipe's
-- mastery bonus into the legitimate coin ceiling.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local Mastery     = require(ReplicatedStorage.Shared.Config.Mastery)
local EconomyMath = require(ReplicatedStorage.Shared.Modules.EconomyMath)

local MasteryService = {}

-- Effective mastery state for a recipe: { level, xp }. Never nil — an unseen
-- recipe is level 1 / 0 xp.
function MasteryService:getEntry(profile: any, recipeId: string): { level: number, xp: number }
	return profile.mastery[recipeId] or { level = 1, xp = 0 }
end

-- The serve-value multiplier a player currently earns on a recipe (mastery tip
-- bonus). Pure read; used to build the server's coin ceiling and to answer the
-- client's display query.
function MasteryService:multFor(profile: any, recipeId: string): number
	local entry = profile.mastery[recipeId]
	local xp    = entry and entry.xp or 0
	return EconomyMath.masteryMult(xp, Mastery.resolve(recipeId))
end

-- Apply a validated serve tally ({ [recipeId] = count }). Increments XP, recomputes
-- the cached level, and returns the set of recipes whose level changed (for logging).
function MasteryService:applyServes(player: Player, serves: { [string]: number }): { [string]: number }
	local profile = DataService:getProfile(player)
	if not profile then return {} end

	local leveledUp: { [string]: number } = {}
	for recipeId, count in pairs(serves) do
		if count > 0 then
			local entry = profile.mastery[recipeId]
			if not entry then
				entry = { level = 1, xp = 0 }
				profile.mastery[recipeId] = entry
			end
			entry.xp += count * Mastery.xpPerServe

			local curve    = Mastery.resolve(recipeId)
			local newLevel = EconomyMath.masteryLevel(entry.xp, curve.thresholds)
			if newLevel > entry.level then
				leveledUp[recipeId] = newLevel
			end
			entry.level = newLevel
		end
	end
	return leveledUp
end

function MasteryService:init()
	-- No remotes of its own; driven by LevelService via the level-result flow.
end

return MasteryService
