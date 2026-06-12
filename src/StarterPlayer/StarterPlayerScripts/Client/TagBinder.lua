--!strict
-- Streaming-safe CollectionService binding.
--
-- `bind(tag, onAdded, onRemoved)` invokes `onAdded(instance)` for every instance
-- carrying `tag` — both those present now and any that appear later (e.g. stream
-- in) — and `onRemoved(instance, state)` when the instance loses the tag or
-- streams out. `onAdded` may return a state value that is handed back to
-- `onRemoved` (the per-instance Trove, an entity, etc.).
--
-- Returns a Trove. Cleaning/destroying it disconnects the signals and runs
-- `onRemoved` for every still-bound instance, so a controller can tear down all
-- of its tagged bindings at once. This replaces the old `GetChildren()` snapshot
-- which silently saw nothing under StreamingEnabled and never noticed
-- stream-in/out (ISSUES #13).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Shared.Packages.Trove)

local TagBinder = {}

-- A sentinel so an onAdded that returns nil still registers as "bound".
local NO_STATE = {}

function TagBinder.bind(
	tag: string,
	onAdded: (Instance) -> any,
	onRemoved: ((Instance, any) -> ())?
): any
	local trove = Trove.new()
	local states: { [Instance]: any } = {}

	local function add(inst: Instance)
		if states[inst] ~= nil then return end -- already bound (GetTagged/Added race)
		local state = onAdded(inst)
		states[inst] = if state == nil then NO_STATE else state
	end

	local function remove(inst: Instance)
		local state = states[inst]
		if state == nil then return end
		states[inst] = nil
		if onRemoved then
			onRemoved(inst, if state == NO_STATE then nil else state)
		end
	end

	-- Connect the signals BEFORE the GetTagged sweep so nothing tagged between
	-- the two is missed; `add` guards against the resulting double-call.
	trove:Connect(CollectionService:GetInstanceAddedSignal(tag), add)
	trove:Connect(CollectionService:GetInstanceRemovedSignal(tag), remove)

	for _, inst in ipairs(CollectionService:GetTagged(tag)) do
		add(inst)
	end

	-- On teardown, run onRemoved for anything still bound.
	trove:Add(function()
		for inst in pairs(states) do
			local state = states[inst]
			if onRemoved then
				onRemoved(inst, if state == NO_STATE then nil else state)
			end
		end
		states = {}
	end)

	return trove
end

return TagBinder
