--!strict
-- Pure chef math: passive aggregation, level/shiny scaling, equip-slot count, and
-- fusion cost. No Roblox API — gameConfig is injected so it's unit-testable and the
-- client (live passive application) and server (earnings ceiling) can't drift.

local ChefMath = {}

export type OwnedChef = { uid: number, chefId: string, shiny: boolean, level: number }

export type Passives = {
	cookSpeedMult: number,
	tipMult: number,
	burnImmuneChance: number,
	autoServe: boolean,
}

-- The multiplier applied to a chef's *bonus* portion from its level and shiny
-- state. Level 1 non-shiny = 1.0; each level adds CHEF_LEVEL_BONUS of the base
-- bonus, and a shiny multiplies the whole bonus by CHEF_SHINY_BONUS_MULT.
function ChefMath.bonusScale(level: number, shiny: boolean, gameConfig: any): number
	local scale = 1 + (level - 1) * gameConfig.CHEF_LEVEL_BONUS
	if shiny then scale *= gameConfig.CHEF_SHINY_BONUS_MULT end
	return scale
end

-- Combine the passives of all equipped chefs into one effect-tag bundle.
--   mult tags (cookSpeedMult, tipMult) stack multiplicatively on their bonus
--   burnImmuneChance combines as independent probabilities (1 - ∏(1-c))
--   autoServe is an OR across the equipped set
function ChefMath.aggregatePassives(
	ownedChefs: { OwnedChef },
	equippedUids: { number },
	chefList: { [string]: any },
	gameConfig: any
): Passives
	local byUid: { [number]: OwnedChef } = {}
	for _, c in ipairs(ownedChefs) do
		byUid[c.uid] = c
	end

	local result: Passives = { cookSpeedMult = 1, tipMult = 1, burnImmuneChance = 0, autoServe = false }

	for _, uid in ipairs(equippedUids) do
		local owned = byUid[uid]
		local chef  = owned and chefList[owned.chefId]
		if chef then
			local scale = ChefMath.bonusScale(owned.level, owned.shiny, gameConfig)
			local p = chef.passives
			if p.cookSpeedMult then
				result.cookSpeedMult *= 1 + (p.cookSpeedMult - 1) * scale
			end
			if p.tipMult then
				result.tipMult *= 1 + (p.tipMult - 1) * scale
			end
			if p.burnImmuneChance then
				local c = math.clamp(p.burnImmuneChance * scale, 0, 0.95)
				result.burnImmuneChance = 1 - (1 - result.burnImmuneChance) * (1 - c)
			end
			if p.autoServe then
				result.autoServe = true
			end
		end
	end

	return result
end

-- Total prestige across all restaurants (sum of the per-restaurant prestige map).
function ChefMath.totalPrestige(prestigeMap: { [string]: number }): number
	local total = 0
	for _, lvl in pairs(prestigeMap) do
		total += lvl
	end
	return total
end

-- Equip-slot cap: a base count that grows with total prestige (the M7 → M8 tie).
function ChefMath.equipSlots(totalPrestige: number, gameConfig: any, prestigeConfig: any): number
	return gameConfig.CHEF_BASE_EQUIP_SLOTS + prestigeConfig.equipSlotsPerLevel * totalPrestige
end

-- Number of duplicate chefs consumed to raise a chef from `currentLevel` to the
-- next level. Flat per level (config-tunable).
function ChefMath.fusionCost(currentLevel: number, gameConfig: any): number
	return gameConfig.CHEF_FUSION_DUPES
end

-- Count how many owned chefs share a chefId (the dupe pool for fusion).
function ChefMath.countOfChef(ownedChefs: { OwnedChef }, chefId: string): number
	local n = 0
	for _, c in ipairs(ownedChefs) do
		if c.chefId == chefId then n += 1 end
	end
	return n
end

return ChefMath
