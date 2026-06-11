--!strict
-- Handles upgrade purchases and computes effective station stats after upgrades.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService    = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Remotes        = require(ReplicatedStorage.Shared.Remotes)
local Upgrades       = require(ReplicatedStorage.Shared.Config.Upgrades)
local Stations       = require(ReplicatedStorage.Shared.Config.Stations)
local UpgradeMath    = require(ReplicatedStorage.Shared.Modules.UpgradeMath)

local UpgradeService = {}

-- Returns a shallow-copy of the station config with upgrade modifiers applied.
-- Never mutates Stations.lua data. Delegates the modifier math to the shared
-- UpgradeMath module so client and server stay in lockstep.
function UpgradeService:effectiveStation(player: Player, stationId: string): any
	local base = Stations[stationId]
	if not base then return nil end
	local profile = DataService:getProfile(player)
	local level   = profile and profile.upgrades[stationId] or 0
	return UpgradeMath.effectiveStation(base, Upgrades[stationId], level)
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
