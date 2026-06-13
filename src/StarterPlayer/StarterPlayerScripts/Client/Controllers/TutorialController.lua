--!strict
-- Onboarding engine (P1.2). On a first session (profile.seenTutorial == false) it
-- places the player at the kitchen cook-spot, auto-starts the onboarding level, and
-- runs the data-driven steps from Config/TutorialSteps — a contextual highlight +
-- one-line hint per step. It is generic: it runs whatever sequence the config
-- defines and resolves targets/completion from existing gameplay signals.
--
-- Never blocks input: steps only add a Highlight + a non-interactive hint label, and
-- nothing gates on completion, so ignoring or skipping a prompt can't soft-lock.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums         = require(ReplicatedStorage.Shared.Modules.Enums)
local GameConfig    = require(ReplicatedStorage.Shared.Config.GameConfig)
local TutorialSteps = require(ReplicatedStorage.Shared.Config.TutorialSteps)
local Trove         = require(ReplicatedStorage.Shared.Packages.Trove)

local TutorialController = {}

local _hintGui:   ScreenGui
local _hintLabel: TextLabel

local _active   = false                         -- onboarding currently running
local _activated: { [string]: boolean } = {}    -- step id → activated
local _completed: { [string]: boolean } = {}    -- step id → completed
local _stepTroves: { [string]: any } = {}        -- step id → its watcher/highlight Trove
local _trove = Trove.new()

-- ── World lookups ────────────────────────────────────────────────────────────
local function stationPart(id: string): BasePart?
	for _, p in ipairs(CollectionService:GetTagged("Station")) do
		if p:IsA("BasePart") and p:GetAttribute("StationId") == id then
			return p
		end
	end
	return nil
end

local function occupiedSeat(): BasePart?
	-- A seat is occupied iff CustomerController has parented a PatienceBar to it.
	for _, s in ipairs(CollectionService:GetTagged("Seat")) do
		if s:IsA("BasePart") and s:FindFirstChild("PatienceBar") then
			return s
		end
	end
	return nil
end

local function makeHighlight(target: Instance): Highlight
	local h = Instance.new("Highlight")
	h.FillColor       = Color3.fromRGB(255, 215, 80)
	h.FillTransparency = 0.5
	h.OutlineColor    = Color3.fromRGB(255, 235, 150)
	h.DepthMode       = Enum.HighlightDepthMode.AlwaysOnTop
	h.Adornee         = target
	h.Parent          = target
	return h
end

-- ── Hint label ───────────────────────────────────────────────────────────────
local function buildHintUI()
	local gui = Instance.new("ScreenGui")
	gui.Name          = "TutorialHint"
	gui.ResetOnSpawn  = false
	gui.Enabled       = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent        = Players.LocalPlayer:WaitForChild("PlayerGui")

	local lbl = Instance.new("TextLabel")
	lbl.AnchorPoint            = Vector2.new(0.5, 1)
	lbl.Position               = UDim2.new(0.5, 0, 1, -110)  -- above the bottom HUD
	lbl.Size                   = UDim2.new(0.9, 0, 0, 56)
	lbl.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
	lbl.BackgroundTransparency = 0.3
	lbl.TextColor3             = Color3.fromRGB(255, 235, 150)
	lbl.TextScaled             = true
	lbl.Font                   = Enum.Font.GothamBold
	lbl.Active                 = false  -- never capture touch/click input
	lbl.Text                   = ""
	lbl.Parent                 = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent       = lbl
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft  = UDim.new(0, 14)
	pad.PaddingRight = UDim.new(0, 14)
	pad.Parent       = lbl

	_hintGui, _hintLabel = gui, lbl
end

local function setHint(text: string)
	_hintLabel.Text = text
	_hintGui.Enabled = true
end

local function endTutorial()
	if not _active then return end
	_active = false
	for id, t in pairs(_stepTroves) do
		t:Destroy()
		_stepTroves[id] = nil
	end
	_hintGui.Enabled = false
end

-- ── Step engine ──────────────────────────────────────────────────────────────
local activateStep  -- forward decl

local function completeStep(step: any)
	if not _active or _completed[step.id] then return end
	_completed[step.id] = true
	local t = _stepTroves[step.id]
	if t then t:Destroy(); _stepTroves[step.id] = nil end

	-- Activate any step gated on this one finishing.
	for _, s in ipairs(TutorialSteps) do
		if s.trigger.kind == "afterStep" and s.trigger.step == step.id then
			activateStep(s)
		end
	end

	-- Last step done → onboarding complete.
	if step.id == TutorialSteps[#TutorialSteps].id then
		endTutorial()
	end
end

function activateStep(step: any)
	if _activated[step.id] or _completed[step.id] then return end
	_activated[step.id] = true

	local stepTrove = Trove.new()
	_stepTroves[step.id] = stepTrove
	setHint(step.promptText)

	-- Highlight (retried until the target exists, e.g. a customer not yet seated).
	local hi = step.highlight
	local function applyHighlight(): boolean
		if hi.kind == "station" then
			local p = stationPart(hi.id)
			if p then stepTrove:Add(makeHighlight(p)); return true end
			return false
		elseif hi.kind == "occupiedSeat" then
			local s = occupiedSeat()
			if s then stepTrove:Add(makeHighlight(s)); return true end
			return false
		end
		return true  -- "none"
	end
	if not applyHighlight() then
		stepTrove:Connect(RunService.Heartbeat, function()
			applyHighlight()
		end)
	end

	-- Completion watcher.
	local StationController  = require(script.Parent.StationController)
	local CustomerController = require(script.Parent.CustomerController)
	local co = step.completeOn
	if co.kind == "hold" then
		stepTrove:Connect(RunService.Heartbeat, function()
			if StationController.heldItem.itemId == co.item then completeStep(step) end
		end)
	elseif co.kind == "interactAny" then
		local last = StationController.heldItem.itemId
		stepTrove:Connect(RunService.Heartbeat, function()
			if StationController.heldItem.itemId ~= last then completeStep(step) end
		end)
	elseif co.kind == "produce" then
		stepTrove:Connect(StationController.ItemProduced, function(stationId: string)
			if stationId == co.station then completeStep(step) end
		end)
	elseif co.kind == "serve" then
		stepTrove:Connect(CustomerController.CustomerLeft, function(_c: any, wasServed: boolean)
			if wasServed then completeStep(step) end
		end)
	elseif co.kind == "timer" then
		task.delay(co.seconds, function() completeStep(step) end)
	end
end

-- ── First-session bootstrap ──────────────────────────────────────────────────
local function teleportToCookSpot()
	local cs = GameConfig.ONBOARDING.cookSpot
	local player = Players.LocalPlayer
	local function place(char: Model)
		local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			hrp = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
		end
		if hrp then
			hrp.CFrame = CFrame.new(cs.x, cs.y, cs.z) * CFrame.Angles(0, math.rad(cs.yaw), 0)
		end
	end
	if player.Character then place(player.Character) end
end

local function runOnboarding()
	local LevelController = require(script.Parent.LevelController)
	_active = true

	-- Activate the level-start steps once gameplay begins.
	_trove:Connect(LevelController.StateChanged, function(newState: string)
		if newState == Enums.LevelState.Playing then
			for _, step in ipairs(TutorialSteps) do
				if step.trigger.kind == "levelStart" then
					activateStep(step)
				end
			end
		elseif newState == Enums.LevelState.Results or newState == Enums.LevelState.Idle then
			endTutorial()
		end
	end)

	-- Ensure the character is loaded, drop the player at the cook-spot, then start.
	task.spawn(function()
		local player = Players.LocalPlayer
		local char = player.Character or player.CharacterAdded:Wait()
		char:WaitForChild("HumanoidRootPart", 10)
		teleportToCookSpot()
		task.wait(0.3)  -- settle at the cook-spot before the first customer arrives
		if LevelController.state == Enums.LevelState.Idle then
			LevelController:startLevel(GameConfig.ONBOARDING.restaurantId, GameConfig.ONBOARDING.levelIndex)
		end
	end)
end

function TutorialController:init()
	buildHintUI()

	local ProfileController = require(script.Parent.ProfileController)
	-- Decide once the profile is known; a returning player (seenTutorial) is skipped.
	local function decide(profile: any)
		if not profile or _active or _completed["__decided"] then return end
		if profile.seenTutorial == true then
			_completed["__decided"] = true  -- never onboard again this session
			return
		end
		_completed["__decided"] = true
		runOnboarding()
	end

	local existing = ProfileController:get()
	if existing then
		decide(existing)
	else
		-- Wait for the first profile fetch.
		local conn
		conn = ProfileController.Changed:Connect(function(profile)
			if profile then
				conn:Disconnect()
				decide(profile)
			end
		end)
		_trove:Add(conn)
	end

	print("[TutorialController] ready")
end

return TutorialController
