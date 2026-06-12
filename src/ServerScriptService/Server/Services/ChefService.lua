--!strict
-- Chef inventory: equip / unequip / fuse, server-authoritative (M8.3).
--
-- The equip-slot cap grows with total prestige (the M7 → M8 tie). Fusion is the
-- duplicate sink: consume N dupes of a chef to raise its level, so the gacha keeps
-- meaning something once the roster is filled. Every mutation is validated against
-- the profile and idempotent per call.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DataService = require(script.Parent.DataService)
local Remotes     = require(ReplicatedStorage.Shared.Remotes)
local Chefs       = require(ReplicatedStorage.Shared.Config.Chefs)
local GameConfig  = require(ReplicatedStorage.Shared.Config.GameConfig)
local Prestige    = require(ReplicatedStorage.Shared.Config.Prestige)
local ChefMath    = require(ReplicatedStorage.Shared.Modules.ChefMath)

local ChefService = {}

local function findChef(profile: any, uid: number): any?
	for _, c in ipairs(profile.chefs) do
		if c.uid == uid then return c end
	end
	return nil
end

local function isEquipped(profile: any, uid: number): (boolean, number?)
	for i, u in ipairs(profile.equippedChefs) do
		if u == uid then return true, i end
	end
	return false, nil
end

-- Current equip-slot cap for a player (base + total prestige growth).
function ChefService:equipSlots(profile: any): number
	return ChefMath.equipSlots(ChefMath.totalPrestige(profile.prestige), GameConfig, Prestige)
end

function ChefService:equip(player: Player, uid: number): any
	local profile = DataService:getProfile(player)
	if not profile then return { ok = false, reason = "no_profile" } end
	if not findChef(profile, uid) then return { ok = false, reason = "not_owned" } end
	if isEquipped(profile, uid) then return { ok = false, reason = "already_equipped" } end
	if #profile.equippedChefs >= ChefService:equipSlots(profile) then
		return { ok = false, reason = "no_free_slots" }
	end
	table.insert(profile.equippedChefs, uid)
	DataService:save(player)
	return { ok = true }
end

function ChefService:unequip(player: Player, uid: number): any
	local profile = DataService:getProfile(player)
	if not profile then return { ok = false, reason = "no_profile" } end
	local equipped, idx = isEquipped(profile, uid)
	if not equipped then return { ok = false, reason = "not_equipped" } end
	table.remove(profile.equippedChefs, idx :: number)
	DataService:save(player)
	return { ok = true }
end

-- Fuse: consume `fusionCost` OTHER duplicates of the same chef to raise `uid` one
-- level. Dupes are picked to preserve player value: never the target, prefer
-- unequipped and non-shiny copies first.
function ChefService:fuse(player: Player, uid: number): any
	local profile = DataService:getProfile(player)
	if not profile then return { ok = false, reason = "no_profile" } end

	local target = findChef(profile, uid)
	if not target then return { ok = false, reason = "not_owned" } end
	if target.level >= GameConfig.CHEF_MAX_LEVEL then return { ok = false, reason = "max_level" } end

	local cost = ChefMath.fusionCost(target.level, GameConfig)

	-- Gather candidate dupes (same chefId, different uid).
	local candidates: { any } = {}
	for _, c in ipairs(profile.chefs) do
		if c.uid ~= uid and c.chefId == target.chefId then
			table.insert(candidates, c)
		end
	end
	if #candidates < cost then
		return { ok = false, reason = "not_enough_dupes", have = #candidates, need = cost }
	end

	-- Sort so we burn the least valuable first: unequipped before equipped,
	-- non-shiny before shiny, lower level before higher.
	table.sort(candidates, function(a, b)
		local ae = isEquipped(profile, a.uid) and 1 or 0
		local be = isEquipped(profile, b.uid) and 1 or 0
		if ae ~= be then return ae < be end
		local as = a.shiny and 1 or 0
		local bs = b.shiny and 1 or 0
		if as ~= bs then return as < bs end
		return a.level < b.level
	end)

	-- Mark the chosen uids for removal.
	local consume: { [number]: boolean } = {}
	for i = 1, cost do consume[candidates[i].uid] = true end

	-- Rebuild the chefs list without the consumed dupes; also drop any from equipped.
	local kept: { any } = {}
	for _, c in ipairs(profile.chefs) do
		if not consume[c.uid] then table.insert(kept, c) end
	end
	profile.chefs = kept
	local keptEquipped: { number } = {}
	for _, u in ipairs(profile.equippedChefs) do
		if not consume[u] then table.insert(keptEquipped, u) end
	end
	profile.equippedChefs = keptEquipped
	-- Also drop consumed chefs from any idle assignment (M9).
	if profile.idleAssignments then
		for _, list in pairs(profile.idleAssignments) do
			for i = #list, 1, -1 do
				if consume[list[i]] then table.remove(list, i) end
			end
		end
	end

	target.level += 1
	DataService:save(player)
	return { ok = true, newLevel = target.level, consumed = cost }
end

function ChefService:init()
	Remotes.EquipChef.OnServerInvoke = function(player: Player, uid: number)
		if type(uid) ~= "number" then return { ok = false, reason = "bad_args" } end
		return ChefService:equip(player, uid)
	end
	Remotes.UnequipChef.OnServerInvoke = function(player: Player, uid: number)
		if type(uid) ~= "number" then return { ok = false, reason = "bad_args" } end
		return ChefService:unequip(player, uid)
	end
	Remotes.FuseChef.OnServerInvoke = function(player: Player, uid: number)
		if type(uid) ~= "number" then return { ok = false, reason = "bad_args" } end
		return ChefService:fuse(player, uid)
	end
end

return ChefService
