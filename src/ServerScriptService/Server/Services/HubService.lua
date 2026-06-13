--!strict
-- Hub building state (P1.1). The plaza is shared and assignment-free: every
-- player sees the same buildings, but each building shows the LOCAL player's tier
-- on their own client (HubController). For OTHER players, their tier surfaces as a
-- nameplate badge — so this service's job is to broadcast each player's
-- per-restaurant tier as a server-authoritative Player attribute that any client
-- can read. Clients never compute another player's tier themselves.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local HubMath     = require(ReplicatedStorage.Shared.Modules.HubMath)
local HubPlots    = require(ReplicatedStorage.Shared.Config.HubPlots)
local Restaurants = require(ReplicatedStorage.Shared.Config.Restaurants)

local ATTR_PREFIX = "HubTier_"

local HubService = {}

-- Recompute and publish this player's per-restaurant building tier.
function HubService:recompute(player: Player)
	local profile = DataService:getProfile(player)
	if not profile then return end
	for _, plot in ipairs(HubPlots) do
		local restaurant = Restaurants[plot.restaurantId]
		if restaurant then
			local owned = HubMath.ownedUpgradeCount(profile.upgrades, restaurant.stationIds)
			local tier  = HubMath.tierFor(owned, plot.tierThresholds)
			player:SetAttribute(ATTR_PREFIX .. plot.restaurantId, tier)
		end
	end
end

function HubService:init()
	-- Publish for anyone already present (e.g. service hot-reload).
	for _, p in ipairs(Players:GetPlayers()) do
		task.spawn(function() self:recompute(p) end)
	end

	Players.PlayerAdded:Connect(function(p: Player)
		-- The profile loads on PlayerAdded too; retry briefly until it's present.
		task.spawn(function()
			for _ = 1, 20 do
				if DataService:getProfile(p) then
					self:recompute(p)
					return
				end
				task.wait(0.5)
			end
		end)
	end)
end

return HubService
