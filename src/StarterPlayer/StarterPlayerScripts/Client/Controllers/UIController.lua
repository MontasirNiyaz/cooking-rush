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

-- Results overlay
local _resultsFrame: Frame
local _resultsStars: TextLabel
local _resultsCoins: TextLabel

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

local buildResults  -- forward declaration; defined after buildGui

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

	buildResults(gui)
end

-- Full-screen results overlay, hidden until the level reaches the Results state.
function buildResults(gui: ScreenGui)
	local frame = Instance.new("Frame")
	frame.Name                   = "Results"
	frame.Size                   = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
	frame.BackgroundTransparency = 0.35
	frame.Visible                = false
	frame.ZIndex                 = 10
	frame.Parent                 = gui

	local panel = Instance.new("Frame")
	panel.Name                 = "Panel"
	panel.AnchorPoint          = Vector2.new(0.5, 0.5)
	panel.Position             = UDim2.new(0.5, 0, 0.5, 0)
	panel.Size                 = UDim2.new(0, 420, 0, 280)
	panel.BackgroundColor3     = Color3.fromRGB(28, 28, 34)
	panel.BorderSizePixel      = 0
	panel.ZIndex               = 11
	panel.Parent               = frame

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 16)
	corner.Parent       = panel

	local title = makeLabel(panel, "Title", "Level Complete!",
		UDim2.new(0.1, 0, 0.06, 0), UDim2.new(0.8, 0, 0, 48))
	title.BackgroundTransparency = 1
	title.ZIndex                 = 12

	_resultsStars = makeLabel(panel, "Stars", "☆ ☆ ☆",
		UDim2.new(0.1, 0, 0.36, 0), UDim2.new(0.8, 0, 0, 72))
	_resultsStars.BackgroundTransparency = 1
	_resultsStars.TextColor3             = Color3.fromRGB(255, 209, 64)
	_resultsStars.ZIndex                 = 12

	_resultsCoins = makeLabel(panel, "Coins", "Coins: 0",
		UDim2.new(0.1, 0, 0.6, 0), UDim2.new(0.8, 0, 0, 40))
	_resultsCoins.BackgroundTransparency = 1
	_resultsCoins.ZIndex                 = 12

	-- Continue → returns to the hub (dismisses results, resets to Idle).
	local continueBtn = Instance.new("TextButton")
	continueBtn.Name             = "Continue"
	continueBtn.AnchorPoint      = Vector2.new(0.5, 1)
	continueBtn.Position         = UDim2.new(0.5, 0, 0.94, 0)
	continueBtn.Size             = UDim2.new(0.7, 0, 0, 48)
	continueBtn.BackgroundColor3 = Color3.fromRGB(46, 160, 90)
	continueBtn.TextColor3       = Color3.fromRGB(255, 255, 255)
	continueBtn.TextScaled       = true
	continueBtn.Font             = Enum.Font.GothamBold
	continueBtn.Text             = "Return to Hub"
	continueBtn.ZIndex           = 12
	continueBtn.Parent           = panel
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 10)
	cc.Parent       = continueBtn
	continueBtn.Activated:Connect(function()
		local LevelController = require(script.Parent.LevelController)
		LevelController:returnToIdle()
	end)

	_resultsFrame = frame
end

local STAR_FILLED = "★"
local STAR_EMPTY  = "☆"

local function showResults(stars: number, coins: number)
	local filled = math.clamp(stars, 0, 3)
	local parts = {}
	for i = 1, 3 do
		parts[i] = i <= filled and STAR_FILLED or STAR_EMPTY
	end
	_resultsStars.Text = table.concat(parts, " ")
	_resultsCoins.Text = string.format("Coins: %d", coins)
	_resultsFrame.Visible = true
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
			_resultsFrame.Visible = false
		elseif newState == Enums.LevelState.Intro then
			_statusLabel.Text = "Get ready!"
			_resultsFrame.Visible = false
		elseif newState == Enums.LevelState.Playing then
			_statusLabel.Text = "Cooking!"
			_resultsFrame.Visible = false
		elseif newState == Enums.LevelState.Results then
			_statusLabel.Text = string.format("Done!  %d coins", LevelController.coinsEarned)
			showResults(LevelController.stars, LevelController.coinsEarned)
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
