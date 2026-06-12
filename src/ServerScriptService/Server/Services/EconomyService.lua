--!strict
-- Authoritative economy. The ONLY writer of coins/gems in the whole codebase.
-- All currency changes go through addCoins/addGems. Never trust the client for amounts.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local RemoteGuard = require(script.Parent.RemoteGuard)
local Remotes     = require(ReplicatedStorage.Shared.Remotes)
local GameConfig  = require(ReplicatedStorage.Shared.Config.GameConfig)
local EconomyMath = require(ReplicatedStorage.Shared.Modules.EconomyMath)

local EconomyService = {}

function EconomyService:addCoins(player: Player, amount: number): boolean
	local profile = DataService:getProfile(player)
	if not profile then return false end
	profile.coins = math.max(0, profile.coins + amount)
	return true
end

function EconomyService:addGems(player: Player, amount: number): boolean
	local profile = DataService:getProfile(player)
	if not profile then return false end
	profile.gems = math.max(0, profile.gems + amount)
	return true
end

function EconomyService:spendCoins(player: Player, amount: number): boolean
	local profile = DataService:getProfile(player)
	if not profile or profile.coins < amount then return false end
	profile.coins -= amount
	return true
end

function EconomyService:spendGems(player: Player, amount: number): boolean
	local profile = DataService:getProfile(player)
	if not profile or profile.gems < amount then return false end
	profile.gems -= amount
	return true
end

function EconomyService:claimDaily(player: Player): { coins: number, ok: boolean }
	local profile = DataService:getProfile(player)
	if not profile then return { coins = 0, ok = false } end
	local now = os.time()
	if not EconomyMath.canClaimDaily(profile.lastDailyClaim, now, GameConfig.DAILY_INTERVAL_SECONDS) then
		return { coins = 0, ok = false }
	end
	local amount = GameConfig.DAILY_COIN_BASE
	profile.lastDailyClaim = now
	EconomyService:addCoins(player, amount)
	return { coins = amount, ok = true }
end

function EconomyService:init()
	Remotes.ClaimDaily.OnServerInvoke = function(player: Player)
		if not RemoteGuard.allow(player, "ClaimDaily") then return { ok = false, reason = "rate_limited" } end
		return EconomyService:claimDaily(player)
	end
end

return EconomyService
