--!strict
-- Defines and creates all RemoteEvents / RemoteFunctions.
-- Server creates them; client waits for them. Single source of truth.

local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TIMEOUT = 10

local function makeRemote(className: string, name: string): any
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(name)
		if existing then return existing end
		local r = Instance.new(className)
		r.Name   = name
		r.Parent = ReplicatedStorage
		return r
	else
		return ReplicatedStorage:WaitForChild(name, TIMEOUT)
	end
end

-- RemoteFunctions (bidirectional, server replies)
local Remotes = {
	-- Client → Server: check unlock, return resolved Level table
	RequestLevelStart    = makeRemote("RemoteFunction", "RequestLevelStart"),
	-- Client → Server: submit result, server validates + rewards
	SubmitLevelResult    = makeRemote("RemoteFunction", "SubmitLevelResult"),
	-- Client → Server: buy a station/recipe upgrade
	PurchaseUpgrade      = makeRemote("RemoteFunction", "PurchaseUpgrade"),
	-- Client → Server: spend coins/gems to unlock a restaurant
	UnlockRestaurant     = makeRemote("RemoteFunction", "UnlockRestaurant"),
	-- Client → Server: claim daily reward
	ClaimDaily           = makeRemote("RemoteFunction", "ClaimDaily"),
	-- Client → Server: franchise (prestige) a fully 3-starred restaurant
	FranchiseRestaurant  = makeRemote("RemoteFunction", "FranchiseRestaurant"),
	-- Client → Server: recruit a chef from a crate (server rolls authoritatively)
	Recruit              = makeRemote("RemoteFunction", "Recruit"),
	-- Client → Server: equip / unequip a chef by uid
	EquipChef            = makeRemote("RemoteFunction", "EquipChef"),
	UnequipChef          = makeRemote("RemoteFunction", "UnequipChef"),
	-- Client → Server: fuse duplicate chefs to level up one
	FuseChef             = makeRemote("RemoteFunction", "FuseChef"),
	-- Client → Server: fetch own profile for UI
	GetProfile           = makeRemote("RemoteFunction", "GetProfile"),
}

return Remotes
