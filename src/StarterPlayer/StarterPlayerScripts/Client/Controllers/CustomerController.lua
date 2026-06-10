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
			-- Reset seat colours
			for i, seat in ipairs(_seats) do
				seat.BrickColor = BrickColor.new("Medium stone grey")
				_seatFree[i] = true
				_customerSeat = {}
				if _seatPrompt[i] then
					_seatPrompt[i]:Destroy()
					_seatPrompt[i] = nil
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

		-- Spawn pending customers
		while _nextSpawnIndex <= #level.spawns do
			local entry = level.spawns[_nextSpawnIndex]
			if LevelController.elapsed < entry.atSecond then break end

			local archetype = Customers[entry.customerTypeId]
			if not archetype then
				warn("[CustomerController] Unknown customerTypeId: " .. tostring(entry.customerTypeId))
				_nextSpawnIndex += 1
				continue
			end

			local customer = CustomerEntity.new(tostring(_nextSpawnIndex), entry, archetype)
			_active[customer.id] = customer
			_nextSpawnIndex += 1

			-- Assign a seat
			local seatIdx = freeSeat()
			if seatIdx then
				attachToSeat(customer, seatIdx)
			else
				warn("[CustomerController] No free seats for customer " .. customer.id)
			end

			CustomerController.CustomerArrived:Fire(customer)
			print(string.format("[CustomerController] Customer %s arrived (orders: %s)",
				customer.id, table.concat(customer.pendingOrders, ", ")))
		end

		-- Tick patience and handle departures
		for id, customer in pairs(_active) do
			customer:tick(dt)

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
