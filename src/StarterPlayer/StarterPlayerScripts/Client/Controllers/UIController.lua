--!strict
-- Minimal HUD for M1: coins, combo streak, held item, level state.
-- All display is done with ScreenGui TextLabels — no assets required.

local Players    = game:GetService("Players")
local RunService = game:GetService("RunService")

local UIController = {}

local _coinsLabel:  TextLabel
local _comboLabel:  TextLabel
local _heldLabel:   TextLabel
local _statusLabel: TextLabel

local function makeLabel(parent: Instance, name: string, text: string,
	pos: UDim2, size: UDim2, xAlign: Enum.TextXAlignment?): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.Name               = name
	lbl.Text               = text
	lbl.Position           = pos
	lbl.Size               = size
	lbl.BackgroundColor3   = Color3.fromRGB(0, 0, 0)
	lbl.BackgroundTransparency = 0.45
	lbl.TextColor3         = Color3.fromRGB(255, 255, 255)
	lbl.TextScaled         = true
	lbl.Font               = Enum.Font.GothamBold
	lbl.TextXAlignment     = xAlign or Enum.TextXAlignment.Center
	lbl.Parent             = parent
	return lbl
end

local function buildGui()
	local player = Players.LocalPlayer
	local gui    = Instance.new("ScreenGui")
	gui.Name          = "CookingHUD"
	gui.ResetOnSpawn  = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent        = player.PlayerGui

	_statusLabel = makeLabel(gui, "Status", "Waiting…",
		UDim2.new(0, 8, 0, 8), UDim2.new(0.22, 0, 0, 36),
		Enum.TextXAlignment.Left)

	_coinsLabel = makeLabel(gui, "Coins", "Coins: 0",
		UDim2.new(0.39, 0, 0, 8), UDim2.new(0.22, 0, 0, 36))

	_comboLabel = makeLabel(gui, "Combo", "x1.0",
		UDim2.new(1, -180, 0, 8), UDim2.new(0.17, 0, 0, 36),
		Enum.TextXAlignment.Right)

	_heldLabel = makeLabel(gui, "HeldItem", "Holding: nothing",
		UDim2.new(0.35, 0, 1, -52), UDim2.new(0.3, 0, 0, 44))
end

function UIController:init()
	buildGui()

	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local Enums             = require(ReplicatedStorage.Shared.Modules.Enums)
	local LevelController   = require(script.Parent.LevelController)
	local ComboController   = require(script.Parent.ComboController)
	local StationController = require(script.Parent.StationController)

	LevelController.CoinsChanged:Connect(function(total: number)
		_coinsLabel.Text = string.format("Coins: %d", total)
	end)

	ComboController.StreakChanged:Connect(function(streak: number, mult: number)
		_comboLabel.Text = streak > 1
			and string.format("x%.2f  x%d", mult, streak)
			or  "x1.0"
	end)

	LevelController.StateChanged:Connect(function(newState: string)
		if newState == Enums.LevelState.Idle then
			_statusLabel.Text = "Waiting…"
			_coinsLabel.Text  = "Coins: 0"
			_comboLabel.Text  = "x1.0"
		elseif newState == Enums.LevelState.Intro then
			_statusLabel.Text = "Get ready!"
		elseif newState == Enums.LevelState.Playing then
			_statusLabel.Text = "Cooking!"
		elseif newState == Enums.LevelState.Results then
			_statusLabel.Text = string.format("Done!  %d coins", LevelController.coinsEarned)
		end
	end)

	-- Poll held item every frame (lightweight string compare)
	local lastHeld = ""
	RunService.Heartbeat:Connect(function()
		local id = StationController.heldItem.itemId or ""
		if id ~= lastHeld then
			lastHeld        = id
			_heldLabel.Text = id ~= "" and ("Holding: " .. id) or "Holding: nothing"
		end
	end)
end

return UIController
