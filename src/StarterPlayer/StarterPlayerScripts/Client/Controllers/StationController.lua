--!strict
-- Binds a Station entity + ProximityPrompt to every Part tagged "Station"
-- (carrying a StationId attribute), now and as they stream in/out. Streaming-safe
-- via CollectionService instead of a one-shot Workspace.Stations snapshot (#13).
-- Owns the player's held-item state for the session.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local StationEntity   = require(script.Parent.Parent.Entities.Station)
local ItemStackEntity = require(script.Parent.Parent.Entities.ItemStack)
local TagBinder       = require(script.Parent.Parent.TagBinder)
local Interactable    = require(script.Parent.Parent.Interactable)
local Signal          = require(ReplicatedStorage.Shared.Packages.Signal)
local Trove           = require(ReplicatedStorage.Shared.Packages.Trove)
local Stations        = require(ReplicatedStorage.Shared.Config.Stations)

local STATION_TAG = "Station"

local StationController = {}
StationController.__index = StationController

StationController.ItemProduced = Signal.new()  -- fires(stationId, itemId)

-- The item the local player is currently carrying (one item at a time).
StationController.heldItem = ItemStackEntity.new()

local _stations: { [string]: any } = {}  -- stationId → Station entity
local _handles:  { [string]: any } = {}  -- stationId → Interactable handle
local _trove = Trove.new()               -- owns the tag binding

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

local function refreshAllLabels()
	for sid, handle in pairs(_handles) do
		handle:setActionText(promptLabel(sid, StationController.heldItem.itemId))
	end
end

-- Bind one tagged Part. Returns a Trove holding everything created for it so the
-- binding tears down cleanly when the Part streams out.
local function bindStation(part: Instance): any?
	if not part:IsA("BasePart") then return nil end
	local stationId: string? = part:GetAttribute("StationId")
	if not stationId then
		warn("[StationController] Station-tagged part has no StationId attribute: " .. part:GetFullName())
		return nil
	end
	local cfg = Stations[stationId]
	if not cfg then
		warn("[StationController] Unknown station id: " .. stationId)
		return nil
	end
	if _stations[stationId] then
		-- Same logical station already bound (duplicate tag / re-stream of a twin).
		return nil
	end

	local trove = Trove.new()

	-- Start at upgrade level 0; the player's real levels are applied at level start
	-- (see applyUpgradeLevels), once the profile has loaded.
	local station = StationEntity.new(cfg, 0)
	_stations[stationId] = station

	-- Cooker heartbeat tick
	if cfg.archetype == "Cooker" then
		trove:Connect(RunService.Heartbeat, function(dt: number)
			station:tick(dt)
		end)
		trove:Connect(station.ItemReady, function(itemId: string)
			print(string.format("[%s] Ready: %s", stationId, itemId))
			StationController.ItemProduced:Fire(stationId, itemId)
		end)
		trove:Connect(station.ItemBurnt, function()
			warn(string.format("[%s] Item burnt!", stationId))
		end)
	end

	-- Dispenser heartbeat tick (refill)
	if cfg.archetype == "Dispenser" and cfg.refillTime then
		trove:Connect(RunService.Heartbeat, function(dt: number)
			station:tick(dt)
		end)
	end

	-- Interaction (ProximityPrompt or tap, per GameConfig.INTERACTION_MODE).
	local function onActivate(_player: Player)
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

		refreshAllLabels()
	end

	local handle = Interactable.bind(part, {
		objectText  = cfg.displayName,
		actionText  = promptLabel(stationId, StationController.heldItem.itemId),
		maxDistance = 8,
		onActivate  = onActivate,
	})
	_handles[stationId] = handle
	trove:Add(handle)

	return { trove = trove, stationId = stationId }
end

local function unbindStation(_part: Instance, state: any)
	if not state then return end
	_stations[state.stationId] = nil
	_handles[state.stationId] = nil
	state.trove:Destroy()
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
			refreshAllLabels()
		elseif newState == "Intro" then
			-- Level beginning: apply the player's upgrades to live station behaviour.
			applyUpgradeLevels()
		end
	end)

	-- Bind stations by tag — streaming-safe, no fixed folder name, and stations
	-- that stream in/out during play bind and tear down cleanly.
	_trove:Add(TagBinder.bind(STATION_TAG, bindStation, unbindStation))

	print(string.format("[StationController] Bound %d stations via '%s' tag", #(function()
		local t = {} :: {string}
		for k in pairs(_stations) do table.insert(t, k) end
		return t
	end)(), STATION_TAG))
end

return StationController
