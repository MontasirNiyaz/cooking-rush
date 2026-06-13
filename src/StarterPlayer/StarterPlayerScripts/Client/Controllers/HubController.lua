--!strict
-- Hub plaza controller (P1.1).
--
-- * Binds restaurant doors (tag "RestaurantDoor", RestaurantId attribute) → a
--   ProximityPrompt that opens a diegetic level board for that restaurant. The
--   board replaces any standalone world-map / level-select screen.
-- * Binds building signage (tag "RestaurantSignage", RestaurantId attribute) and
--   tints it to the LOCAL player's visual tier (HubMath over the local profile),
--   updating whenever the profile changes.
-- * Surfaces OTHER players' tiers as a nameplate badge, read from the
--   server-published HubTier_* attributes — never recomputed on the client.
--
-- Streaming-safe via TagBinder (doors/signage stream in/out cleanly).

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TagBinder   = require(script.Parent.Parent.TagBinder)
local Enums       = require(ReplicatedStorage.Shared.Modules.Enums)
local HubMath     = require(ReplicatedStorage.Shared.Modules.HubMath)
local HubPlots    = require(ReplicatedStorage.Shared.Config.HubPlots)
local Restaurants = require(ReplicatedStorage.Shared.Config.Restaurants)
local Trove       = require(ReplicatedStorage.Shared.Packages.Trove)

local DOOR_TAG    = "RestaurantDoor"
local SIGNAGE_TAG = "RestaurantSignage"
local ATTR_PREFIX = "HubTier_"

local HubController = {}

local _signage: { [string]: { BasePart } } = {}  -- restaurantId → bound signage parts
local _trove = Trove.new()

-- ── Plot lookup ──────────────────────────────────────────────────────────────
local _plotById: { [string]: any } = {}
for _, plot in ipairs(HubPlots) do
	_plotById[plot.restaurantId] = plot
end

local function rgb(c: { number }): Color3
	return Color3.fromRGB(c[1], c[2], c[3])
end

-- ── Level board UI (diegetic, opened from a door) ────────────────────────────
local _boardGui:   ScreenGui
local _boardPanel: Frame
local _boardTitle: TextLabel
local _boardStatus: TextLabel
local _boardList:  ScrollingFrame

local function buildBoard()
	local gui = Instance.new("ScreenGui")
	gui.Name           = "LevelBoard"
	gui.ResetOnSpawn   = false
	gui.Enabled        = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent         = Players.LocalPlayer:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name             = "Panel"
	panel.AnchorPoint      = Vector2.new(0.5, 0.5)
	panel.Position         = UDim2.new(0.5, 0, 0.5, 0)
	panel.Size             = UDim2.new(0, 420, 0, 460)
	panel.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
	panel.Parent           = gui
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 12)
	pc.Parent       = panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position               = UDim2.new(0, 16, 0, 8)
	title.Size                   = UDim2.new(1, -64, 0, 36)
	title.TextColor3             = Color3.fromRGB(255, 255, 255)
	title.TextScaled             = true
	title.Font                   = Enum.Font.GothamBold
	title.TextXAlignment         = Enum.TextXAlignment.Left
	title.Text                   = "Select Level"
	title.Parent                 = panel

	local status = Instance.new("TextLabel")
	status.BackgroundTransparency = 1
	status.Position               = UDim2.new(0, 16, 0, 44)
	status.Size                   = UDim2.new(1, -32, 0, 22)
	status.TextColor3             = Color3.fromRGB(255, 224, 130)
	status.TextScaled             = true
	status.Font                   = Enum.Font.Gotham
	status.TextXAlignment         = Enum.TextXAlignment.Left
	status.Text                   = ""
	status.Parent                 = panel

	local close = Instance.new("TextButton")
	close.AnchorPoint      = Vector2.new(1, 0)
	close.Position         = UDim2.new(1, -8, 0, 8)
	close.Size             = UDim2.new(0, 36, 0, 36)
	close.BackgroundColor3 = Color3.fromRGB(190, 60, 60)
	close.TextColor3       = Color3.fromRGB(255, 255, 255)
	close.TextScaled       = true
	close.Font             = Enum.Font.GothamBold
	close.Text             = "✕"
	close.Parent           = panel
	local cc = Instance.new("UICorner")
	cc.CornerRadius = UDim.new(0, 6)
	cc.Parent       = close
	close.Activated:Connect(function() gui.Enabled = false end)

	local list = Instance.new("ScrollingFrame")
	list.Position               = UDim2.new(0, 8, 0, 76)
	list.Size                   = UDim2.new(1, -16, 1, -84)
	list.BackgroundTransparency = 1
	list.BorderSizePixel        = 0
	list.ScrollBarThickness     = 6
	list.CanvasSize             = UDim2.new(0, 0, 0, 0)
	list.Parent                 = panel
	local grid = Instance.new("UIGridLayout")
	grid.CellSize   = UDim2.new(0, 76, 0, 56)
	grid.CellPadding = UDim2.new(0, 8, 0, 8)
	grid.SortOrder  = Enum.SortOrder.LayoutOrder
	grid.Parent     = list

	_boardGui, _boardPanel, _boardTitle, _boardStatus, _boardList = gui, panel, title, status, list
end

local function openBoard(restaurantId: string)
	local LevelController = require(script.Parent.LevelController)
	if LevelController.state ~= Enums.LevelState.Idle then
		return  -- can't start a level while one is running
	end
	local restaurant = Restaurants[restaurantId]
	if not restaurant then return end

	local ProfileController = require(script.Parent.ProfileController)
	local profile = ProfileController:get()
	local unlocked = profile and profile.unlockedRestaurants
		and profile.unlockedRestaurants[restaurantId] == true

	_boardTitle.Text = restaurant.displayName
	_boardStatus.Text = unlocked and "Choose a level"
		or "Locked — unlock in the Shop first"

	-- Clear old level buttons.
	for _, child in ipairs(_boardList:GetChildren()) do
		if child:IsA("TextButton") then child:Destroy() end
	end

	for i = 1, restaurant.levelCount do
		local btn = Instance.new("TextButton")
		btn.LayoutOrder      = i
		btn.BackgroundColor3 = unlocked and Color3.fromRGB(46, 134, 222) or Color3.fromRGB(70, 70, 78)
		btn.AutoButtonColor  = unlocked
		btn.Active           = unlocked
		btn.TextColor3       = Color3.fromRGB(255, 255, 255)
		btn.TextScaled       = true
		btn.Font             = Enum.Font.GothamBold
		btn.Text             = tostring(i)
		btn.Parent           = _boardList
		local bc = Instance.new("UICorner")
		bc.CornerRadius = UDim.new(0, 8)
		bc.Parent       = btn
		local levelIndex = i
		btn.Activated:Connect(function()
			if not unlocked then return end
			_boardGui.Enabled = false
			LevelController:startLevel(restaurantId, levelIndex)
		end)
	end

	_boardList.CanvasSize = UDim2.new(0, 0, 0, math.ceil(restaurant.levelCount / 5) * 64 + 16)
	_boardGui.Enabled = true
end

-- ── Door binding ─────────────────────────────────────────────────────────────
local function bindDoor(part: Instance): any?
	if not part:IsA("BasePart") then return nil end
	local restaurantId: string? = part:GetAttribute("RestaurantId")
	if not restaurantId then
		warn("[HubController] Door-tagged part has no RestaurantId: " .. part:GetFullName())
		return nil
	end
	local restaurant = Restaurants[restaurantId]
	local trove = Trove.new()
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText  = "Enter"
	prompt.ObjectText  = restaurant and restaurant.displayName or restaurantId
	prompt.MaxActivationDistance = 10
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	trove:Add(prompt)
	trove:Connect(prompt.Triggered, function()
		openBoard(restaurantId)
	end)
	return trove
end

local function unbindDoor(_part: Instance, trove: any)
	if trove then trove:Destroy() end
end

-- ── Signage binding + local tier tint ────────────────────────────────────────
local function applyLocalTier(restaurantId: string)
	local parts = _signage[restaurantId]
	local plot = _plotById[restaurantId]
	local restaurant = Restaurants[restaurantId]
	if not (parts and plot and restaurant) then return end

	local ProfileController = require(script.Parent.ProfileController)
	local profile = ProfileController:get()
	local upgrades = profile and profile.upgrades or {}
	local owned = HubMath.ownedUpgradeCount(upgrades, restaurant.stationIds)
	local tier  = HubMath.tierFor(owned, plot.tierThresholds)
	local colour = rgb(plot.signageTiers[tier] or plot.signageTiers[1])
	for _, p in ipairs(parts) do
		p.Color = colour
	end
end

local function bindSignage(part: Instance): any?
	if not part:IsA("BasePart") then return nil end
	local restaurantId: string? = part:GetAttribute("RestaurantId")
	if not restaurantId then
		warn("[HubController] Signage-tagged part has no RestaurantId: " .. part:GetFullName())
		return nil
	end
	local list = _signage[restaurantId]
	if not list then
		list = {}
		_signage[restaurantId] = list
	end
	table.insert(list, part)
	applyLocalTier(restaurantId)
	return restaurantId
end

local function unbindSignage(part: Instance, restaurantId: any)
	local list = restaurantId and _signage[restaurantId]
	if not list then return end
	local i = table.find(list, part)
	if i then table.remove(list, i) end
end

local function refreshAllSignage()
	for restaurantId in pairs(_signage) do
		applyLocalTier(restaurantId)
	end
end

-- ── Other players' tier badges ───────────────────────────────────────────────
local function badgeText(player: Player): string
	local parts = {}
	for _, plot in ipairs(HubPlots) do
		local tier = player:GetAttribute(ATTR_PREFIX .. plot.restaurantId)
		local restaurant = Restaurants[plot.restaurantId]
		if tier and restaurant then
			table.insert(parts, string.format("%s T%d", restaurant.displayName, tier))
		end
	end
	return table.concat(parts, "  ·  ")
end

local function attachBadge(player: Player, playerTrove: any)
	local function onCharacter(char: Model)
		local head = char:WaitForChild("Head", 10) :: BasePart?
		if not head then return end
		local bb = Instance.new("BillboardGui")
		bb.Name        = "HubBadge"
		bb.Size        = UDim2.new(0, 220, 0, 24)
		bb.StudsOffset = Vector3.new(0, 3, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 80
		bb.Adornee     = head
		bb.Parent      = head
		playerTrove:Add(bb)

		local lbl = Instance.new("TextLabel")
		lbl.Size                   = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 0.4
		lbl.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
		lbl.TextColor3             = Color3.fromRGB(255, 224, 130)
		lbl.TextScaled             = true
		lbl.Font                   = Enum.Font.GothamBold
		lbl.Text                   = badgeText(player)
		lbl.Parent                 = bb

		local function update() lbl.Text = badgeText(player) end
		for _, plot in ipairs(HubPlots) do
			playerTrove:Connect(player:GetAttributeChangedSignal(ATTR_PREFIX .. plot.restaurantId), update)
		end
	end

	if player.Character then onCharacter(player.Character) end
	playerTrove:Connect(player.CharacterAdded, onCharacter)
end

-- ── Init ─────────────────────────────────────────────────────────────────────
function HubController:init()
	buildBoard()

	_trove:Add(TagBinder.bind(DOOR_TAG, bindDoor, unbindDoor))
	_trove:Add(TagBinder.bind(SIGNAGE_TAG, bindSignage, unbindSignage))

	-- Re-tint local buildings whenever the profile changes (upgrade purchased).
	local ProfileController = require(script.Parent.ProfileController)
	ProfileController.Changed:Connect(refreshAllSignage)

	-- Badges for every other player, now and future.
	local function watch(player: Player)
		if player == Players.LocalPlayer then return end
		local pt = _trove:Add(Trove.new(), "Destroy")
		attachBadge(player, pt)
	end
	for _, p in ipairs(Players:GetPlayers()) do watch(p) end
	_trove:Connect(Players.PlayerAdded, watch)

	print("[HubController] Hub ready (doors + signage bound by tag)")
end

return HubController
