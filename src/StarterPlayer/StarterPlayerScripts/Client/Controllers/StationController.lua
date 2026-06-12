--!strict
-- Scans Workspace.Stations for Parts with a StationId attribute and wires
-- a ProximityPrompt → Station entity for each one.
-- Owns the player's held-item state for the session.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local StationEntity   = require(script.Parent.Parent.Entities.Station)
local ItemStackEntity = require(script.Parent.Parent.Entities.ItemStack)
local Signal          = require(ReplicatedStorage.Shared.Packages.Signal)
local Trove           = require(ReplicatedStorage.Shared.Packages.Trove)
local Stations        = require(ReplicatedStorage.Shared.Config.Stations)

local StationController = {}
StationController.__index = StationController

StationController.ItemProduced = Signal.new()  -- fires(stationId, itemId)

-- The item the local player is currently carrying (one item at a time).
StationController.heldItem = ItemStackEntity.new()

local _stations: { [string]: any }      = {}
local _prompts:  { [string]: ProximityPrompt } = {}
local _trove = Trove.new()

-- Prompt label shown on a station Part.
local function promptLabel(stationId: string, heldId: string?): string
	local cfg = Stations[stationId]
	if not cfg then return stationId end
	if cfg.archetype == "Cooker" then
		return heldId and ("Place " .. heldId) or ("Pick up · " .. cfg.displayName)
	elseif cfg.archetype == "Dispenser" then
		return "Take " .. (cfg.produces or "item")
	else
		return heldId and ("Add " .. heldId) or "Pick up · Assembly"
	end
end

local function setupPart(stationId: string, part: BasePart)
	local cfg = Stations[stationId]
	if not cfg then
		warn("[StationController] Unknown station id: " .. stationId)
		return
	end

	-- Start at upgrade level 0; the player's real levels are applied at level start
	-- (see applyUpgradeLevels), once the profile has loaded.
	local station = StationEntity.new(cfg, 0)
	_stations[stationId] = station

	-- Cooker heartbeat tick
	if cfg.archetype == "Cooker" then
		_trove:Connect(RunService.Heartbeat, function(dt: number)
			station:tick(dt)
		end)
		station.ItemReady:Connect(function(itemId: string)
			print(string.format("[%s] Ready: %s", stationId, itemId))
			StationController.ItemProduced:Fire(stationId, itemId)
		end)
		station.ItemBurnt:Connect(function()
			warn(string.format("[%s] Item burnt!", stationId))
		end)
	end

	-- Dispenser heartbeat tick (refill)
	if cfg.archetype == "Dispenser" and cfg.refillTime then
		_trove:Connect(RunService.Heartbeat, function(dt: number)
			station:tick(dt)
		end)
	end

	-- ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText  = promptLabel(stationId, nil)
	prompt.ObjectText  = cfg.displayName
	prompt.MaxActivationDistance = 8
	prompt.HoldDuration = 0
	prompt.Parent = part
	_prompts[stationId] = prompt
	_trove:Add(prompt)

	_trove:Connect(prompt.Triggered, function(_player: Player)
		local held = StationController.heldItem
		local result, consumed = station:interact(held.itemId)

		if result ~= nil then
			held.itemId = result
			print(string.format("[StationController] Now holding: %s", result))
		elseif consumed then
			print(string.format("[StationController] Placed %s into %s", tostring(held.itemId), stationId))
			held.itemId = nil
		else
			print(string.format("[StationController] %s: nothing happened (hands %s)",
				stationId, held.itemId or "empty"))
		end

		-- Refresh all prompt labels
		for sid, pr in pairs(_prompts) do
			pr.ActionText = promptLabel(sid, StationController.heldItem.itemId)
		end
	end)
end

-- Apply the player's current per-station upgrade levels to the live station
-- entities. Read from the shared profile cache so cook/refill behaviour reflects
-- purchases made in the shop. Called at the start of each level.
local function applyUpgradeLevels()
	local ProfileController = require(script.Parent.ProfileController)
	local profile = ProfileController:get()
	local upgrades = profile and profile.upgrades or {}
	for sid, station in pairs(_stations) do
		station:setUpgradeLevel(upgrades[sid] or 0)
	end
end

-- Apply equipped-chef cook passives to every cooker. cookSpeedMult speeds cooking;
-- burnImmuneChance gives finished dishes a chance to survive a burn. Read from the
-- ChefController aggregate (computed at Intro from the player's equipped chefs).
local function applyChefModifiers()
	local ChefController = require(script.Parent.ChefController)
	ChefController:refresh()  -- ensure the aggregate reflects the latest profile, order-independent
	local p = ChefController:getPassives()
	for _, station in pairs(_stations) do
		if station.archetype == "Cooker" then
			station:setChefModifiers(p.cookSpeedMult, p.burnImmuneChance)
		end
	end
end

function StationController:init()
	local LevelController = require(script.Parent.LevelController)

	LevelController.StateChanged:Connect(function(newState: string)
		if newState == "Idle" then
			StationController.heldItem:clear()
			-- Reset station internal state
			for _, s in pairs(_stations) do
				s._slots = {}
				s._base  = nil
				s._added = {}
			end
			-- Refresh prompt labels
			for sid, pr in pairs(_prompts) do
				pr.ActionText = promptLabel(sid, nil)
			end
		elseif newState == "Intro" then
			-- Level beginning: apply the player's upgrades + equipped-chef passives
			-- to live station behaviour.
			applyUpgradeLevels()
			applyChefModifiers()
		end
	end)

	-- Discover station Parts in the world (placed by the level map or test setup)
	local stationsFolder = workspace:WaitForChild("Stations", 15) :: Folder?
	if not stationsFolder then
		warn("[StationController] Workspace.Stations not found — no stations wired")
		return
	end

	for _, child in ipairs(stationsFolder:GetChildren()) do
		if child:IsA("BasePart") then
			local stationId: string? = child:GetAttribute("StationId")
			if stationId then
				setupPart(stationId, child)
			end
		end
	end

	print(string.format("[StationController] Wired %d stations", #(function()
		local t = {} :: {string}
		for k in pairs(_stations) do table.insert(t, k) end
		return t
	end)()))
end

return StationController
