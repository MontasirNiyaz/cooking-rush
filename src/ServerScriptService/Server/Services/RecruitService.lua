--!strict
-- Recruitment (gacha), server-authoritative (M8.2).
--
-- Clients send an intent ("recruit from crate X"); the SERVER rolls the drop with
-- its own RNG, applies the pity floor, mints the chef instance, and charges the
-- cost. Clients never compute or even see the roll until it's resolved. Every
-- grant is server-validated and idempotent per call.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService    = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local Remotes        = require(ReplicatedStorage.Shared.Remotes)
local Chefs          = require(ReplicatedStorage.Shared.Config.Chefs)
local RecruitCrates  = require(ReplicatedStorage.Shared.Config.RecruitCrates)
local GachaMath      = require(ReplicatedStorage.Shared.Modules.GachaMath)

local RecruitService = {}

-- One server RNG for all rolls. Random.new() is seeded from the OS so drops are
-- unpredictable; tests cover the deterministic GachaMath layer directly.
local rng = Random.new()

local function chargeCost(player: Player, cost: any): boolean
	-- Both currencies (if specified) must be affordable; charge atomically with refund.
	local coins = cost.coins or 0
	local gems  = cost.gems or 0
	if coins > 0 and not EconomyService:spendCoins(player, coins) then
		return false
	end
	if gems > 0 and not EconomyService:spendGems(player, gems) then
		if coins > 0 then EconomyService:addCoins(player, coins) end  -- refund
		return false
	end
	return true
end

function RecruitService:recruit(player: Player, crateId: string): any
	local profile = DataService:getProfile(player)
	if not profile then return { ok = false, reason = "no_profile" } end

	local crate = RecruitCrates[crateId]
	if not crate then return { ok = false, reason = "unknown_crate" } end

	if not chargeCost(player, crate.cost) then
		return { ok = false, reason = "insufficient_funds" }
	end

	local pityCounter = profile.pity[crateId] or 0
	local result = GachaMath.resolveRecruit(
		crate, pityCounter,
		rng:NextNumber(), rng:NextNumber(),
		Chefs.list, Chefs.RARITY_ORDER
	)
	if not result then
		-- Empty drop table should be impossible (Schema-validated); refund to be safe.
		if crate.cost.coins then EconomyService:addCoins(player, crate.cost.coins) end
		if crate.cost.gems  then EconomyService:addGems(player, crate.cost.gems) end
		return { ok = false, reason = "empty_drop_table" }
	end

	-- Mint the chef instance with a server-authoritative uid.
	local uid = profile.nextChefUid
	profile.nextChefUid += 1
	local chef = { uid = uid, chefId = result.chefId, shiny = result.shiny, level = 1 }
	table.insert(profile.chefs, chef)

	profile.pity[crateId] = result.pity
	DataService:save(player)

	return {
		ok = true,
		chef = chef,
		rarity = Chefs.list[result.chefId].rarity,
		pityTriggered = result.pityTriggered,
	}
end

function RecruitService:init()
	Remotes.Recruit.OnServerInvoke = function(player: Player, crateId: string)
		if type(crateId) ~= "string" then return { ok = false, reason = "bad_args" } end
		return RecruitService:recruit(player, crateId)
	end
end

return RecruitService
