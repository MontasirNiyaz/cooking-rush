--!strict
-- Pure gacha math: weighted drop rolling + pity. No Roblox API, no global RNG —
-- a roll value (or an injected Random) is passed in so every branch is unit-testable
-- and the server stays the single source of truth for drops.

local GachaMath = {}

export type DropEntry = { chefId: string, weight: number }

-- Rank of a rarity in the ladder (1-based). 0 if unknown.
function GachaMath.rarityRank(rarity: string, rarityOrder: { string }): number
	for i, r in ipairs(rarityOrder) do
		if r == rarity then return i end
	end
	return 0
end

-- Sum of all weights in a drop table.
function GachaMath.totalWeight(dropTable: { DropEntry }): number
	local total = 0
	for _, e in ipairs(dropTable) do
		total += e.weight
	end
	return total
end

-- Pick a chefId from a drop table given roll ∈ [0, 1). Pure + deterministic:
-- the same roll always yields the same entry. Walks the cumulative weight band.
function GachaMath.pick(dropTable: { DropEntry }, roll: number): string?
	local total = GachaMath.totalWeight(dropTable)
	if total <= 0 then return nil end
	local target = math.clamp(roll, 0, 0.9999999) * total
	local acc = 0
	for _, e in ipairs(dropTable) do
		acc += e.weight
		if target < acc then
			return e.chefId
		end
	end
	return dropTable[#dropTable].chefId  -- float-safety fallback
end

-- Return only the entries whose chef is at least `minRarity`. Used to enforce a
-- pity floor by restricting the table before rolling.
function GachaMath.filterByMinRarity(
	dropTable: { DropEntry },
	minRarity: string,
	chefList: { [string]: any },
	rarityOrder: { string }
): { DropEntry }
	local floor = GachaMath.rarityRank(minRarity, rarityOrder)
	local out: { DropEntry } = {}
	for _, e in ipairs(dropTable) do
		local chef = chefList[e.chefId]
		if chef and GachaMath.rarityRank(chef.rarity, rarityOrder) >= floor then
			table.insert(out, e)
		end
	end
	return out
end

-- The pity counter AFTER a pull. Resets to 0 when the dropped chef meets the
-- floor rarity; otherwise increments.
function GachaMath.nextPity(
	pityCounter: number,
	droppedRarity: string,
	floorRarity: string,
	rarityOrder: { string }
): number
	if GachaMath.rarityRank(droppedRarity, rarityOrder) >= GachaMath.rarityRank(floorRarity, rarityOrder) then
		return 0
	end
	return pityCounter + 1
end

-- Resolve a single recruit. `pityCounter` is the count of consecutive sub-floor
-- pulls BEFORE this one. When the next pull would hit the pity threshold, the
-- drop table is restricted to chefs >= floor so the floor is guaranteed.
--   roll        — primary [0,1) for the chef pick
--   shinyRoll   — independent [0,1) for the shiny variant
-- Returns the resolved chefId, shiny flag, new pity counter, and whether pity fired.
function GachaMath.resolveRecruit(
	crate: any,
	pityCounter: number,
	roll: number,
	shinyRoll: number,
	chefList: { [string]: any },
	rarityOrder: { string }
): { chefId: string, shiny: boolean, pity: number, pityTriggered: boolean }?
	local pityHit = (pityCounter + 1) >= crate.pity.pulls
	local table_ = crate.dropTable
	if pityHit then
		local floored = GachaMath.filterByMinRarity(table_, crate.pity.floorRarity, chefList, rarityOrder)
		if #floored > 0 then table_ = floored end
	end

	local chefId = GachaMath.pick(table_, roll)
	if not chefId then return nil end

	local chef  = chefList[chefId]
	local shiny = chef ~= nil and shinyRoll < (chef.shinyChance or 0)
	local newPity = GachaMath.nextPity(pityCounter, chef and chef.rarity or "Common", crate.pity.floorRarity, rarityOrder)

	return { chefId = chefId, shiny = shiny, pity = newPity, pityTriggered = pityHit }
end

return GachaMath
