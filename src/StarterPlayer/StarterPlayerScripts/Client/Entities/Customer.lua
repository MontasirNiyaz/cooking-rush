--!strict
-- Runtime customer entity. Ticks patience and exposes state for controllers.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Enums = require(ReplicatedStorage.Shared.Modules.Enums)

export type Customer = {
	id: string,
	archetype: any,
	pendingOrders: { string },
	tipCurve: any,
	state: string,

	getPatienceFraction: (self: Customer) -> number,
	tick:   (self: Customer, dt: number) -> (),
	serve:  (self: Customer) -> (),
	destroy: (self: Customer) -> (),
}

local Customer = {}
Customer.__index = Customer

function Customer.new(id: string, spawnEntry: any, archetype: any): Customer
	local maxPatience = archetype.basePatience * spawnEntry.patienceScale
	return setmetatable({
		id             = id,
		archetype      = archetype,
		pendingOrders  = table.clone(spawnEntry.orders),
		tipCurve       = archetype.tipCurve,
		state          = Enums.CustomerState.Arriving,
		_maxPatience   = maxPatience,
		_patience      = maxPatience,
		_arriveTimer   = 0.5,   -- brief arrival animation
	}, Customer) :: any
end

function Customer:getPatienceFraction(): number
	return math.clamp(self._patience / self._maxPatience, 0, 1)
end

function Customer:tick(dt: number)
	if self.state == Enums.CustomerState.Arriving then
		self._arriveTimer -= dt
		if self._arriveTimer <= 0 then
			self.state = Enums.CustomerState.Waiting
		end
		return
	end

	if self.state ~= Enums.CustomerState.Waiting then return end

	self._patience -= dt
	if self._patience <= 0 then
		self._patience = 0
		self.state     = Enums.CustomerState.Angry
	end
end

function Customer:serve()
	self.state = Enums.CustomerState.Served
	task.delay(0.8, function()
		self.state = Enums.CustomerState.Leaving
	end)
end

function Customer:destroy()
	-- cleanup hook for future model/UI teardown
end

return Customer
