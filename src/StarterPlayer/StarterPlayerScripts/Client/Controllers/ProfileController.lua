--!strict
-- Client-side persistent profile display + daily reward claim.
--
-- Fetches the server profile via GetProfile and shows persistent coins/gems
-- (distinct from the per-level coins the CookingHUD shows). The Daily Reward
-- button invokes ClaimDaily — the server is authoritative for eligibility and
-- the amount; this UI just reflects the result. Re-fetches after a level so the
-- persisted balance updates once SubmitLevelResult has applied rewards.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local ProfileController = {}

local _profile: any = nil
local _balanceLabel:  TextLabel
local _dailyButton:   TextButton
local _feedbackLabel: TextLabel

local function refreshBalance()
	if not _profile then
		_balanceLabel.Text = "Loading…"
		return
	end
	_balanceLabel.Text = string.format("Coins  %d      Gems  %d",
		_profile.coins or 0, _profile.gems or 0)
end

local function fetchProfile()
	-- The server loads the profile on PlayerAdded, which can land just after the
	-- client boots — so retry briefly until GetProfile returns a profile.
	for _ = 1, 10 do
		local ok, profile = pcall(function()
			return Remotes.GetProfile:InvokeServer()
		end)
		if ok and type(profile) == "table" then
			_profile = profile
			refreshBalance()
			return
		end
		task.wait(0.5)
	end
	refreshBalance()
end

local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name          = "ProfileHUD"
	gui.ResetOnSpawn  = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent        = Players.LocalPlayer:WaitForChild("PlayerGui")

	_balanceLabel = Instance.new("TextLabel")
	_balanceLabel.Name                   = "Balance"
	_balanceLabel.AnchorPoint            = Vector2.new(0, 1)
	_balanceLabel.Position               = UDim2.new(0, 8, 1, -96)
	_balanceLabel.Size                   = UDim2.new(0, 260, 0, 32)
	_balanceLabel.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
	_balanceLabel.BackgroundTransparency = 0.45
	_balanceLabel.TextColor3             = Color3.fromRGB(255, 224, 130)
	_balanceLabel.TextScaled             = true
	_balanceLabel.Font                   = Enum.Font.GothamBold
	_balanceLabel.Text                   = "Loading…"
	_balanceLabel.Parent                 = gui

	_dailyButton = Instance.new("TextButton")
	_dailyButton.Name             = "DailyReward"
	_dailyButton.AnchorPoint      = Vector2.new(0, 1)
	_dailyButton.Position         = UDim2.new(0, 8, 1, -60)
	_dailyButton.Size             = UDim2.new(0, 160, 0, 32)
	_dailyButton.BackgroundColor3 = Color3.fromRGB(46, 134, 222)
	_dailyButton.TextColor3       = Color3.fromRGB(255, 255, 255)
	_dailyButton.TextScaled       = true
	_dailyButton.Font             = Enum.Font.GothamBold
	_dailyButton.Text             = "Daily Reward"
	_dailyButton.Parent           = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent       = _dailyButton

	_feedbackLabel = Instance.new("TextLabel")
	_feedbackLabel.Name                   = "DailyFeedback"
	_feedbackLabel.AnchorPoint            = Vector2.new(0, 1)
	_feedbackLabel.Position               = UDim2.new(0, 176, 1, -60)
	_feedbackLabel.Size                   = UDim2.new(0, 240, 0, 32)
	_feedbackLabel.BackgroundTransparency = 1
	_feedbackLabel.TextColor3             = Color3.fromRGB(200, 255, 200)
	_feedbackLabel.TextScaled             = true
	_feedbackLabel.Font                   = Enum.Font.Gotham
	_feedbackLabel.TextXAlignment         = Enum.TextXAlignment.Left
	_feedbackLabel.Text                   = ""
	_feedbackLabel.Parent                 = gui
end

function ProfileController:init()
	buildGui()
	task.spawn(fetchProfile)

	_dailyButton.Activated:Connect(function()
		local ok, result = pcall(function()
			return Remotes.ClaimDaily:InvokeServer()
		end)
		if ok and type(result) == "table" and result.ok then
			if _profile then
				_profile.coins = (_profile.coins or 0) + result.coins
			end
			refreshBalance()
			_feedbackLabel.TextColor3 = Color3.fromRGB(200, 255, 200)
			_feedbackLabel.Text       = string.format("+%d daily coins!", result.coins)
		else
			_feedbackLabel.TextColor3 = Color3.fromRGB(255, 200, 200)
			_feedbackLabel.Text       = "Already claimed — come back later"
		end
	end)

	-- Refresh the persisted balance after a level resolves (rewards applied server-side).
	local LevelController = require(script.Parent.LevelController)
	local Enums           = require(ReplicatedStorage.Shared.Modules.Enums)
	LevelController.StateChanged:Connect(function(newState: string)
		if newState == Enums.LevelState.Results then
			task.spawn(fetchProfile)
		end
	end)
end

return ProfileController
