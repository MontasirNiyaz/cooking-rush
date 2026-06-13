--!strict
-- Pure hub-visual math: how a player's owned upgrades map to a building's visual
-- tier. No Roblox APIs — fully unit-tested. Both the client (local building
-- visual) and the server (broadcast tier for other players' badges) use these so
-- they never disagree.

local HubMath = {}

-- Total upgrades a player owns across a restaurant's stations (sum of levels).
-- `upgrades` is profile.upgrades (stationId → level); `stationIds` is the
-- restaurant's station list.
function HubMath.ownedUpgradeCount(upgrades: { [string]: number }?, stationIds: { string }): number
	local n = 0
	for _, sid in ipairs(stationIds) do
		n += (upgrades and upgrades[sid]) or 0
	end
	return n
end

-- Visual tier (1-based) for an owned-upgrade count given ascending thresholds.
-- `thresholds[i]` is the minimum owned count for tier i; thresholds[1] must be 0
-- so every player is at least tier 1. Returns the highest tier whose threshold
-- is met.
function HubMath.tierFor(owned: number, thresholds: { number }): number
	local tier = 1
	for i, thr in ipairs(thresholds) do
		if owned >= thr then
			tier = i
		else
			break
		end
	end
	return tier
end

return HubMath
