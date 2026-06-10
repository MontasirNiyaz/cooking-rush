--!strict
-- Tracks the serve-streak combo and exposes the current multiplier.
-- Reset by: wrong serve, patience expiry, or level end.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local EconomyMath = require(ReplicatedStorage.Shared.Modules.EconomyMath)
local Signal     = require(ReplicatedStorage.Shared.Packages.Signal)

local ComboController = {}
ComboController.__index = ComboController

ComboController.streak      = 0
ComboController.multiplier  = 1.0
ComboController.StreakChanged = Signal.new()  -- fires(streak: number, multiplier: number)

function ComboController:increment()
	self.streak    += 1
	self.multiplier = EconomyMath.comboMultiplier(self.streak, GameConfig)
	self.StreakChanged:Fire(self.streak, self.multiplier)
end

function ComboController:reset()
	if self.streak == 0 then return end
	self.streak    = 0
	self.multiplier = 1.0
	self.StreakChanged:Fire(0, 1.0)
end

function ComboController:init()
	-- Reset on level state change back to Idle
	local LevelController = require(script.Parent.LevelController)
	LevelController.StateChanged:Connect(function(newState: string)
		if newState == "Idle" then
			ComboController:reset()
		end
	end)
end

return ComboController
