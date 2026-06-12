--!strict
-- Spawns and ticks customers from the level's spawn list.
-- Assigns each arriving customer to a seat Part in Workspace.Seats and
-- wires a ProximityPrompt so the player can serve them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local CustomerEntity = require(script.Parent.Parent.Entities.Customer)
local Enums          = require(ReplicatedStorage.Shared.Modules.Enums)
local Customers      = require(ReplicatedStorage.Shared.Config.Customers)
local Signal         = require(ReplicatedStorage.Shared.Packages.Signal)
local Trove          = require(ReplicatedStorage.Shared.Packages.Trove)

local CustomerController = {}
CustomerController.__index = CustomerController

CustomerController.CustomerArrived = Signal.new()  -- fires(customer)
CustomerController.CustomerLeft    = Signal.new()  -- fires(customer, wasServed: boolean)

local _active: { [string]: any }        = {}
local _nextSpawnIndex                    = 1
local _trove                             = Trove.new()

-- Seat management: Parts in Workspace.Seats, assigned round-robin.
local _seats: { BasePart }      = {}
local _seatFree: { boolean }    = {}
local _customerSeat: { [string]: number } = {}  -- customerId → seat index
local _seatPrompt: { [number]: ProximityPrompt } = {}
local _seatBar:    { [number]: BillboardGui } = {}   -- seat index → patience BillboardGui
local _seatBarFill: { [number]: Frame } = {}         -- seat index → fill bar Frame

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

local function freeSeat(): number?
	for i, free in ipairs(_seatFree) do
		if free then return i end
	end
	return nil
end

local function buildOrderText(customer: any): string
	if #customer.pendingOrders == 0 then return "(served)" end
	return "Serve: " .. table.concat(customer.pendingOrders, ", ")
end

local function releaseSeat(customerId: string)
	local idx = _customerSeat[customerId]
	if not idx then return end
	_customerSeat[customerId] = nil
	_seatFree[idx] = true

	local pr = _seatPrompt[idx]
	if pr then
		pr:Destroy()
		_seatPrompt[idx] = nil
	end

	local bar = _seatBar[idx]
	if bar then
		bar:Destroy()
		_seatBar[idx]     = nil
		_seatBarFill[idx] = nil
	end

	local seat = _seats[idx]
	if seat then
		seat.BrickColor = BrickColor.new("Medium stone grey")
	end
end

local function attachToSeat(customer: any, idx: number)
	_customerSeat[customer.id] = idx
	_seatFree[idx] = false

	local seat = _seats[idx]
	if not seat then return end
	seat.BrickColor = BrickColor.new("Bright green")

	-- ProximityPrompt for serving
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText  = buildOrderText(customer)
	prompt.ObjectText  = "Customer"
	prompt.MaxActivationDistance = 8
	prompt.HoldDuration = 0
	prompt.Parent = seat
	_seatPrompt[idx] = prompt

	-- Patience bar above the seat
	local bb, fill = makePatienceBar(seat)
	_seatBar[idx]     = bb
	_seatBarFill[idx] = fill

	prompt.Triggered:Connect(function(_player: Player)
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
			-- Update prompt with remaining orders
			prompt.ActionText = buildOrderText(customer)

			if #customer.pendingOrders == 0 then
				customer:serve()
			end
		else
			print("[CustomerController] Wrong item: " .. heldId)
		end
	end)
end

-- Auto-serve one pending order of one waiting customer, as if the player handed
-- over the finished dish (the autoServe chef passive). Reuses the normal serve
-- path so combo, mastery, and earnings multipliers all apply identically. Returns
-- true if a dish was delivered.
function CustomerController:autoServeOne(): boolean
	local OrderController = require(script.Parent.OrderController)
	for id, customer in pairs(_active) do
		if customer.state == Enums.CustomerState.Waiting and #customer.pendingOrders > 0 then
			-- Serving by the recipe id itself fulfils that order (recipe.id == dish item).
			local recipeId = customer.pendingOrders[1]
			if OrderController:tryServe(customer, recipeId) then
				local idx = _customerSeat[id]
				local pr  = idx and _seatPrompt[idx]
				if pr then pr.ActionText = buildOrderText(customer) end
				if #customer.pendingOrders == 0 then
					customer:serve()
				end
				return true
			end
		end
	end
	return false
end

function CustomerController:init()
	local LevelController = require(script.Parent.LevelController)

	-- Discover seat Parts once at init time
	local seatsFolder = workspace:WaitForChild("Seats", 15) :: Folder?
	if seatsFolder then
		for _, child in ipairs(seatsFolder:GetChildren()) do
			if child:IsA("BasePart") then
				table.insert(_seats, child)
				table.insert(_seatFree, true)
			end
		end
		print(string.format("[CustomerController] Found %d seats", #_seats))
	else
		warn("[CustomerController] Workspace.Seats not found")
	end

	LevelController.StateChanged:Connect(function(newState: string)
		if newState == Enums.LevelState.Playing then
			_active         = {}
			_nextSpawnIndex = 1
			_customerSeat   = {}
			-- Reset seat colours and tear down any leftover prompts/bars
			for i, seat in ipairs(_seats) do
				seat.BrickColor = BrickColor.new("Medium stone grey")
				_seatFree[i] = true
				if _seatPrompt[i] then
					_seatPrompt[i]:Destroy()
					_seatPrompt[i] = nil
				end
				if _seatBar[i] then
					_seatBar[i]:Destroy()
					_seatBar[i]     = nil
					_seatBarFill[i] = nil
				end
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
			local seatIdx = freeSeat()
			if not seatIdx then break end

			local archetype = Customers[entry.customerTypeId]
			if not archetype then
				warn("[CustomerController] Unknown customerTypeId: " .. tostring(entry.customerTypeId))
				_nextSpawnIndex += 1
				continue
			end

			local customer = CustomerEntity.new(tostring(_nextSpawnIndex), entry, archetype)
			_active[customer.id] = customer
			_nextSpawnIndex += 1

			attachToSeat(customer, seatIdx)

			CustomerController.CustomerArrived:Fire(customer)
			print(string.format("[CustomerController] Customer %s arrived (orders: %s)",
				customer.id, table.concat(customer.pendingOrders, ", ")))
		end

		-- Tick patience and handle departures
		for id, customer in pairs(_active) do
			customer:tick(dt)

			-- Drive the patience bar for this customer's seat
			local seatIdx = _customerSeat[id]
			if seatIdx then
				local fill = _seatBarFill[seatIdx]
				if fill then
					local frac = customer:getPatienceFraction()
					fill.Size = UDim2.new(frac, 0, 1, 0)
					fill.BackgroundColor3 = frac < 0.25
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
