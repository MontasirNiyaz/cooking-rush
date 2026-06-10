--!strict
-- Handles upgrade purchases and computes effective station stats after upgrades.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService    = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Remotes        = require(ReplicatedStorage.Shared.Remotes)
local Upgrades       = require(ReplicatedStorage.Shared.Config.Upgrades)
local Stations       = require(ReplicatedStorage.Shared.Config.Stations)

local UpgradeService = {}

-- Returns a shallow-copy of the station config with upgrade modifiers applied.
-- Never mutates Stations.lua data.
function UpgradeService:effectiveStation(player: Player, stationId: string): any
	local base    = Stations[stationId]
	if not base then return nil end
	local profile = DataService:getProfile(player)
	local level   = profile and profile.upgrades[stationId] or 0
	if level == 0 then return base end

	local tree = Upgrades[stationId]
	if not tree then return base end

	local effective = table.clone(base :: any)
	for tier = 1, level do
		local entry = tree.tiers[tier]
		if entry then
			local effect = entry.effect
			local field  = effect.field
			local current = (effective :: any)[field]
			if type(current) == "number" then
				if effect.mult then (effective :: any)[field] = current * effect.mult end
				if effect.add  then (effective :: any)[field] = current + effect.add  end
			end
		end
	end
	return effective
end

function UpgradeService:purchaseUpgrade(player: Player, stationId: string): { ok: boolean, reason: string? }
	local profile = DataService:getProfile(player)
	if not profile then return { ok = false, reason = "no_profile" } end

	local tree = Upgrades[stationId]
	if not tree then return { ok = false, reason = "no_tree" } end

	local currentLevel = profile.upgrades[stationId] or 0
	local nextTier     = tree.tiers[currentLevel + 1]
	if not nextTier then return { ok = false, reason = "max_level" } end

	if not EconomyService:spendCoins(player, nextTier.cost) then
		return { ok = false, reason = "insufficient_coins" }
	end

	profile.upgrades[stationId] = currentLevel + 1
	return { ok = true }
end

function UpgradeService:init()
	Remotes.PurchaseUpgrade.OnServerInvoke = function(player: Player, stationId: string)
		return UpgradeService:purchaseUpgrade(player, stationId)
	end
end

return UpgradeService
