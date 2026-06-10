--!strict
-- Owns the active-level state machine.
-- States: Idle → Intro → Playing → Results
-- All other controllers read LevelController state; this is the clock.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Remotes    = require(ReplicatedStorage.Shared.Remotes)
local Enums      = require(ReplicatedStorage.Shared.Modules.Enums)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Signal     = require(ReplicatedStorage.Shared.Packages.Signal)
local Trove      = require(ReplicatedStorage.Shared.Packages.Trove)

export type LevelController = typeof({} :: {
	state: string,
	currentLevel: any,
	elapsed: number,
	coinsEarned: number,

	StateChanged: any,
	CoinsChanged: any,

	init:        (self: any) -> (),
	startLevel:  (self: any, restaurantId: string, levelIndex: number) -> (),
	addCoins:    (self: any, amount: number) -> (),
	endLevel:    (self: any) -> (),
})

local LevelController = {}
LevelController.__index = LevelController

-- Signals
LevelController.StateChanged = Signal.new()  -- fires(newState: LevelState, oldState: LevelState)
LevelController.CoinsChanged = Signal.new()  -- fires(total: number, delta: number)

-- Runtime state
LevelController.state        = Enums.LevelState.Idle
LevelController.currentLevel = nil
LevelController.elapsed      = 0
LevelController.coinsEarned  = 0

local _trove = Trove.new()

function LevelController:_setState(newState: string)
	local old = self.state
	self.state = newState
	self.StateChanged:Fire(newState, old)
end

function LevelController:startLevel(restaurantId: string, levelIndex: number)
	if self.state ~= Enums.LevelState.Idle then return end

	local level = Remotes.RequestLevelStart:InvokeServer(restaurantId, levelIndex)
	if not level then
		warn("[LevelController] Server rejected level start")
		return
	end

	self.currentLevel = level
	self.elapsed      = 0
	self.coinsEarned  = 0
	self:_setState(Enums.LevelState.Intro)

	-- Brief intro delay before gameplay begins
	task.delay(2, function()
		if self.state == Enums.LevelState.Intro then
			self:_setState(Enums.LevelState.Playing)
		end
	end)
end

function LevelController:addCoins(amount: number)
	self.coinsEarned += amount
	self.CoinsChanged:Fire(self.coinsEarned, amount)
end

function LevelController:endLevel()
	if self.state ~= Enums.LevelState.Playing then return end
	self:_setState(Enums.LevelState.Results)

	-- Submit result to server for validation and rewards
	local level = self.currentLevel
	if level then
		local EconomyMath = require(ReplicatedStorage.Shared.Modules.EconomyMath)
		local stars = EconomyMath.starsFor(self.coinsEarned, level.goals)
		task.spawn(function()
			Remotes.SubmitLevelResult:InvokeServer({
				restaurantId = level.restaurantId,
				levelIndex   = level.index,
				coinsEarned  = self.coinsEarned,
				stars        = stars,
			})
		end)
	end
end

function LevelController:init()
	-- Heartbeat tick: advance elapsed time and check roster completion
	_trove:Connect(RunService.Heartbeat, function(dt: number)
		if LevelController.state ~= Enums.LevelState.Playing then return end
		LevelController.elapsed += dt

		local level = LevelController.currentLevel
		if not level then return end

		-- Timer mode: end when duration exceeded
		if level.duration > 0 and LevelController.elapsed >= level.duration then
			LevelController:endLevel()
		end
		-- Roster-exhausted mode handled by CustomerController calling endLevel()
	end)
end

return LevelController
