--!strict
-- Spawns and ticks customers from the level's spawn list.
-- Assigns each arriving customer to a Part tagged "Seat" and wires a
-- ProximityPrompt so the player can serve them. Seats bind by CollectionService
-- tag (streaming-safe) rather than a Workspace.Seats snapshot (#13).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local CustomerEntity = require(script.Parent.Parent.Entities.Customer)
local TagBinder      = require(script.Parent.Parent.TagBinder)
local Interactable   = require(script.Parent.Parent.Interactable)
local Enums          = require(ReplicatedStorage.Shared.Modules.Enums)
local Customers      = require(ReplicatedStorage.Shared.Config.Customers)
local Signal         = require(ReplicatedStorage.Shared.Packages.Signal)
local Trove          = require(ReplicatedStorage.Shared.Packages.Trove)

local SEAT_TAG = "Seat"

local CustomerController = {}
CustomerController.__index = CustomerController

CustomerController.CustomerArrived = Signal.new()  -- fires(customer)
CustomerController.CustomerLeft    = Signal.new()  -- fires(customer, wasServed: boolean)

local _active: { [string]: any } = {}
local _nextSpawnIndex            = 1
local _trove                     = Trove.new()

-- Seat state keyed by the seat Part so seats can stream in/out individually.
type SeatState = {
	free: boolean,
	handle: any,          -- Interactable handle for serving (or nil)
	bar: BillboardGui?,
	fill: Frame?,
}
local _seatState: { [BasePart]: SeatState } = {}
local _seatOrder: { BasePart }              = {}  -- insertion order → stable round-robin
local _customerSeat: { [string]: BasePart } = {}  -- customerId → seat Part

local NEUTRAL = BrickColor.new("Medium stone grey")
local TAKEN   = BrickColor.new("Bright green")

-- Builds a floating patience bar above a seat. Returns the fill Frame to drive.
local function makePatienceBar(seat: BasePart): (BillboardGui, Frame)
	local bb = Instance.new("BillboardGui")
	bb.Name          = "PatienceBar"
	bb.Size          = UDim2.new(0, 120, 0, 16)
	bb.StudsOffset   = Vector3.new(0, 3.5, 0)
	bb.AlwaysOnTop   = true
	bb.MaxDistance   = 60
	bb.Parent        = seat

	local bg = Instance.new("Frame")
	bg.Name                 = "Bg"
	bg.Size                 = UDim2.new(1, 0, 1, 0)
	bg.BackgroundColor3     = Color3.fromRGB(20, 20, 20)
	bg.BackgroundTransparency = 0.3
	bg.BorderSizePixel      = 0
	bg.Parent               = bb

	local fill = Instance.new("Frame")
	fill.Name             = "Fill"
	fill.Size             = UDim2.new(1, 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(80, 220, 90)
	fill.BorderSizePixel  = 0
	fill.Parent           = bg

	return bb, fill
end

local function allDone(level: any): boolean
	return _nextSpawnIndex > #level.spawns and next(_active) == nil
end

local function freeSeat(): BasePart?
	for _, seat in ipairs(_seatOrder) do
		local st = _seatState[seat]
		if st and st.free then return seat end
	end
	return nil
end

local function buildOrderText(customer: any): string
	if #customer.pendingOrders == 0 then return "(served)" end
	return "Serve: " .. table.concat(customer.pendingOrders, ", ")
end

-- Tear down the visible prompt/bar on a seat and mark it free again.
local function clearSeatVisuals(seat: BasePart)
	local st = _seatState[seat]
	if not st then return end
	if st.handle then st.handle:Destroy(); st.handle = nil end
	if st.bar then st.bar:Destroy(); st.bar = nil; st.fill = nil end
	st.free = true
	seat.BrickColor = NEUTRAL
end

local function releaseSeat(customerId: string)
	local seat = _customerSeat[customerId]
	if not seat then return end
	_customerSeat[customerId] = nil
	clearSeatVisuals(seat)
end

local function attachToSeat(customer: any, seat: BasePart)
	local st = _seatState[seat]
	if not st then return end
	_customerSeat[customer.id] = seat
	st.free = false
	seat.BrickColor = TAKEN

	-- Patience bar above the seat
	local bb, fill = makePatienceBar(seat)
	st.bar  = bb
	st.fill = fill

	-- Serving interaction (ProximityPrompt or tap, per GameConfig.INTERACTION_MODE).
	local handle
	handle = Interactable.bind(seat, {
		objectText  = "Customer",
		actionText  = buildOrderText(customer),
		maxDistance = 8,
		onActivate  = function(_player: Player)
			if customer.state ~= Enums.CustomerState.Waiting then return end
			local StationController = require(script.Parent.StationController)
			local OrderController   = require(script.Parent.OrderController)

			local heldId = StationController.heldItem.itemId
			if not heldId then
				print("[CustomerController] Nothing in hand to serve")
				return
			end

			local ok = OrderController:tryServe(customer, heldId)
			if ok then
				StationController.heldItem.itemId = nil
				handle:setActionText(buildOrderText(customer))

				if #customer.pendingOrders == 0 then
					customer:serve()
				end
			else
				print("[CustomerController] Wrong item: " .. heldId)
			end
		end,
	})
	st.handle = handle
end

-- Bind one tagged seat Part.
local function bindSeat(part: Instance): any?
	if not part:IsA("BasePart") then return nil end
	if _seatState[part] then return nil end
	_seatState[part] = { free = true }
	table.insert(_seatOrder, part)
	part.BrickColor = NEUTRAL
	return part
end

local function unbindSeat(part: Instance, _state: any)
	local seat = part :: BasePart
	-- If a customer occupied this seat, drop the mapping so they don't reference
	-- a torn-down seat (they keep ticking and leave on patience expiry).
	for cid, s in pairs(_customerSeat) do
		if s == seat then _customerSeat[cid] = nil end
	end
	clearSeatVisuals(seat)
	_seatState[seat] = nil
	local i = table.find(_seatOrder, seat)
	if i then table.remove(_seatOrder, i) end
end

function CustomerController:init()
	local LevelController = require(script.Parent.LevelController)

	-- Bind seats by tag — streaming-safe and decoupled from the folder name.
	_trove:Add(TagBinder.bind(SEAT_TAG, bindSeat, unbindSeat))

	LevelController.StateChanged:Connect(function(newState: string)
		if newState == Enums.LevelState.Playing then
			_active         = {}
			_nextSpawnIndex = 1
			_customerSeat   = {}
			-- Reset every bound seat: free it and tear down leftover prompts/bars.
			for seat in pairs(_seatState) do
				clearSeatVisuals(seat)
			end
		elseif newState == Enums.LevelState.Idle then
			for id, c in pairs(_active) do
				c:destroy()
				releaseSeat(id)
			end
			_active         = {}
			_nextSpawnIndex = 1
		end
	end)

	-- Heartbeat: spawn + tick patience
	_trove:Connect(RunService.Heartbeat, function(dt: number)
		if LevelController.state ~= Enums.LevelState.Playing then return end
		local level = LevelController.currentLevel
		if not level then return end

		-- Spawn pending customers. A customer is admitted only when a seat is
		-- free, so arrivals queue by time instead of being orphaned without a
		-- seat (and therefore unservable + with no visible patience bar).
		while _nextSpawnIndex <= #level.spawns do
			local entry = level.spawns[_nextSpawnIndex]
			if LevelController.elapsed < entry.atSecond then break end

			-- Hold the next arrival until a seat opens up.
			local seat = freeSeat()
			if not seat then break end

			local archetype = Customers[entry.customerTypeId]
			if not archetype then
				warn("[CustomerController] Unknown customerTypeId: " .. tostring(entry.customerTypeId))
				_nextSpawnIndex += 1
				continue
			end

			local customer = CustomerEntity.new(tostring(_nextSpawnIndex), entry, archetype)
			_active[customer.id] = customer
			_nextSpawnIndex += 1

			attachToSeat(customer, seat)

			CustomerController.CustomerArrived:Fire(customer)
			print(string.format("[CustomerController] Customer %s arrived (orders: %s)",
				customer.id, table.concat(customer.pendingOrders, ", ")))
		end

		-- Tick patience and handle departures
		for id, customer in pairs(_active) do
			customer:tick(dt)

			-- Drive the patience bar for this customer's seat
			local seat = _customerSeat[id]
			if seat then
				local st = _seatState[seat]
				if st and st.fill then
					local frac = customer:getPatienceFraction()
					st.fill.Size = UDim2.new(frac, 0, 1, 0)
					st.fill.BackgroundColor3 = frac < 0.25
						and Color3.fromRGB(220, 60, 60)
						or  Color3.fromRGB(80, 220, 90)
				end
			end

			local leaving = customer.state == Enums.CustomerState.Angry
				or customer.state == Enums.CustomerState.Leaving

			if leaving then
				local wasServed = #customer.pendingOrders == 0
				_active[id] = nil
				releaseSeat(id)
				customer:destroy()
				CustomerController.CustomerLeft:Fire(customer, wasServed)

				if not wasServed then
					local ComboController = require(script.Parent.ComboController)
					ComboController:reset()
					print(string.format("[CustomerController] Customer %s left angry!", id))
				else
					print(string.format("[CustomerController] Customer %s served and left.", id))
				end

				if allDone(level) then
					LevelController:endLevel()
				end
			end
		end
	end)
end

return CustomerController
