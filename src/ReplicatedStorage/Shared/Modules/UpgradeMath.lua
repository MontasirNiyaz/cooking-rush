--!strict
-- Pure upgrade-modifier math. Single source of truth shared by the client Station
-- entity (live cook/refill behaviour) and the server UpgradeService (authoritative
-- effective stats), so the two can never drift. No side effects, no Roblox calls.

local UpgradeMath = {}

-- Returns a shallow copy of `base` with `level` tiers of `tree` applied.
-- Never mutates `base`. Only numeric fields are modified; each tier applies its
-- `mult` then its `add`. Tiers are applied cumulatively 1..level.
function UpgradeMath.effectiveStation(base: any, tree: any?, level: number): any
	if not base or level <= 0 or not tree then return base end
	local eff = table.clone(base :: any)
	for tier = 1, level do
		local entry = tree.tiers[tier]
		if entry then
			local effect  = entry.effect
			local field   = effect.field
			local current = (eff :: any)[field]
			if type(current) == "number" then
				if effect.mult then (eff :: any)[field] = current * effect.mult end
				if effect.add  then (eff :: any)[field] = current + effect.add  end
			end
		end
	end
	return eff
end

-- Cost of buying the next tier for a station given its current level, or nil if
-- already at max. Pure helper used by the shop UI and purchase validation.
function UpgradeMath.nextTier(tree: any?, currentLevel: number): any?
	if not tree then return nil end
	return tree.tiers[currentLevel + 1]
end

return UpgradeMath
