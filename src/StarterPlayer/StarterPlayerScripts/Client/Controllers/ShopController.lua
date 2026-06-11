--!strict
-- Shop / Upgrade UI.
--
-- Two data-driven panels, both built entirely from config:
--   • Upgrades   — one row per station upgrade tree (Config/Upgrades). Shows the
--                  current level and the next tier's name + cost; Buy invokes
--                  PurchaseUpgrade. Applied cook/refill effects take hold on the
--                  next level start via StationController:applyUpgradeLevels.
--   • Restaurants — one row per restaurant (Config/Restaurants). Shows unlocked
--                  state or the unlock requirement; Unlock invokes UnlockRestaurant.
--
-- The server is authoritative for every purchase and unlock. This UI only reflects
-- the result: after an invoke it asks ProfileController to refresh, and rebuilds
-- itself when the shared profile Changed signal fires.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes     = require(ReplicatedStorage.Shared.Remotes)
local Upgrades    = require(ReplicatedStorage.Shared.Config.Upgrades)
local Stations    = require(ReplicatedStorage.Shared.Config.Stations)
local Restaurants = require(ReplicatedStorage.Shared.Config.Restaurants)
local Recipes     = require(ReplicatedStorage.Shared.Config.Recipes)
local Mastery     = require(ReplicatedStorage.Shared.Config.Mastery)
local Prestige    = require(ReplicatedStorage.Shared.Config.Prestige)
local UpgradeMath = require(ReplicatedStorage.Shared.Modules.UpgradeMath)
local EconomyMath = require(ReplicatedStorage.Shared.Modules.EconomyMath)

local ShopController = {}

local _panel:   Frame
local _list:    ScrollingFrame
local _status:  TextLabel
local _open = false

-- ── Small UI builders ────────────────────────────────────────────────────────

local function newCard(order: number): Frame
	local card = Instance.new("Frame")
	card.Size                   = UDim2.new(1, -12, 0, 56)
	card.BackgroundColor3       = Color3.fromRGB(38, 38, 46)
	card.BorderSizePixel        = 0
	card.LayoutOrder            = order
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card
	return card
end

local function newLabel(parent: Instance, text: string, posX: number, sizeX: number, align: Enum.TextXAlignment): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Position               = UDim2.new(0, posX, 0, 6)
	lbl.Size                   = UDim2.new(0, sizeX, 1, -12)
	lbl.TextColor3             = Color3.fromRGB(235, 235, 240)
	lbl.TextScaled             = true
	lbl.Font                   = Enum.Font.Gotham
	lbl.TextXAlignment         = align
	lbl.Text                   = text
	lbl.Parent                 = parent
	return lbl
end

local function newButton(parent: Instance, text: string, enabled: boolean): TextButton
	local btn = Instance.new("TextButton")
	btn.AnchorPoint      = Vector2.new(1, 0.5)
	btn.Position         = UDim2.new(1, -8, 0.5, 0)
	btn.Size             = UDim2.new(0, 110, 0, 36)
	btn.BackgroundColor3 = enabled and Color3.fromRGB(46, 160, 90) or Color3.fromRGB(70, 70, 78)
	btn.AutoButtonColor  = enabled
	btn.Active           = enabled
	btn.TextColor3       = Color3.fromRGB(255, 255, 255)
	btn.TextScaled       = true
	btn.Font             = Enum.Font.GothamBold
	btn.Text             = text
	btn.Parent           = parent
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = btn
	return btn
end

-- A thin progress bar (0..1) anchored to the right of a card.
local function newBar(parent: Instance, fraction: number)
	local bg = Instance.new("Frame")
	bg.AnchorPoint      = Vector2.new(1, 0.5)
	bg.Position         = UDim2.new(1, -8, 0.5, 0)
	bg.Size             = UDim2.new(0, 150, 0, 14)
	bg.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
	bg.BorderSizePixel  = 0
	bg.Parent           = parent
	local bgc = Instance.new("UICorner")
	bgc.CornerRadius = UDim.new(0, 7)
	bgc.Parent = bg

	local fill = Instance.new("Frame")
	fill.Size             = UDim2.new(math.clamp(fraction, 0, 1), 0, 1, 0)
	fill.BackgroundColor3 = Color3.fromRGB(255, 196, 60)
	fill.BorderSizePixel  = 0
	fill.Parent           = bg
	local fc = Instance.new("UICorner")
	fc.CornerRadius = UDim.new(0, 7)
	fc.Parent = fill
end

local function newHeader(text: string, order: number): TextLabel
	local h = Instance.new("TextLabel")
	h.Size                   = UDim2.new(1, -12, 0, 30)
	h.BackgroundTransparency = 1
	h.TextColor3             = Color3.fromRGB(255, 224, 130)
	h.TextScaled             = true
	h.Font                   = Enum.Font.GothamBold
	h.TextXAlignment         = Enum.TextXAlignment.Left
	h.Text                   = text
	h.LayoutOrder            = order
	return h
end

-- ── Rebuild from the current cached profile ──────────────────────────────────

local function rebuild()
	local ProfileController = require(script.Parent.ProfileController)
	local profile = ProfileController:get()

	for _, child in ipairs(_list:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then
			child:Destroy()
		end
	end

	if not profile then
		_status.Text = "Loading profile…"
		return
	end
	_status.Text = string.format("Coins  %d      Gems  %d      Prestige Tokens  %d",
		profile.coins or 0, profile.gems or 0, profile.prestigeTokens or 0)

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- ── Station upgrades ──
	newHeader("Station Upgrades", nextOrder()).Parent = _list
	for stationId, tree in pairs(Upgrades) do
		local station = Stations[stationId]
		local displayName = (station and station.displayName) or stationId
		local level   = profile.upgrades[stationId] or 0
		local nextTier = UpgradeMath.nextTier(tree, level)

		local card = newCard(nextOrder())
		newLabel(card, string.format("%s   (Lv %d)", displayName, level), 8, 200, Enum.TextXAlignment.Left)

		if nextTier then
			newLabel(card, string.format("%s — %d coins", nextTier.displayName, nextTier.cost),
				214, 220, Enum.TextXAlignment.Left)
			local affordable = (profile.coins or 0) >= nextTier.cost
			local btn = newButton(card, "Buy", affordable)
			btn.Activated:Connect(function()
				local ok, result = pcall(function()
					return Remotes.PurchaseUpgrade:InvokeServer(stationId)
				end)
				if ok and type(result) == "table" and result.ok then
					_status.Text = string.format("Upgraded %s!", displayName)
					ProfileController:refresh()
				else
					local reason = (type(result) == "table" and result.reason) or "error"
					_status.Text = "Could not buy: " .. tostring(reason)
				end
			end)
		else
			newLabel(card, "MAX LEVEL", 214, 220, Enum.TextXAlignment.Left)
		end
		card.Parent = _list
	end

	-- ── Recipe Mastery (M7.1) ──
	-- One row per recipe on an unlocked restaurant's menu (deduped). Shows mastery
	-- level + progress toward the next level.
	newHeader("Recipe Mastery", nextOrder()).Parent = _list
	local seen: { [string]: boolean } = {}
	for restaurantId, config in pairs(Restaurants) do
		if profile.unlockedRestaurants[restaurantId] then
			for _, recipeId in ipairs(config.menu) do
				if not seen[recipeId] then
					seen[recipeId] = true
					local recipe = Recipes[recipeId]
					local entry  = (profile.mastery and profile.mastery[recipeId]) or { level = 1, xp = 0 }
					local curve  = Mastery.resolve(recipeId)
					local level  = EconomyMath.masteryLevel(entry.xp, curve.thresholds)
					local maxLvl = #curve.thresholds

					-- Fraction toward the next level (1 when maxed).
					local frac = 1
					if level < maxLvl then
						local base = curve.thresholds[level]
						local nxt  = curve.thresholds[level + 1]
						frac = (entry.xp - base) / math.max(nxt - base, 1)
					end

					local card = newCard(nextOrder())
					newLabel(card, string.format("%s   (Mastery %d/%d)",
						(recipe and recipe.displayName) or recipeId, level, maxLvl),
						8, 240, Enum.TextXAlignment.Left)
					newBar(card, frac)
				end
			end
		end
	end

	-- ── Restaurants ──
	newHeader("Restaurants & Franchise", nextOrder()).Parent = _list
	for restaurantId, config in pairs(Restaurants) do
		local card = newCard(nextOrder())
		newLabel(card, config.displayName, 8, 200, Enum.TextXAlignment.Left)

		local unlocked = profile.unlockedRestaurants[restaurantId] == true
		local prestigeLevel = (profile.prestige and profile.prestige[restaurantId]) or 0
		if unlocked then
			-- Eligible to franchise only when every level is 3-starred.
			local allThree = true
			for i = 1, config.levelCount do
				if (profile.levelStars[restaurantId .. ":" .. i] or 0) < 3 then
					allThree = false
					break
				end
			end
			local maxed = prestigeLevel >= Prestige.maxLevel
			local statusText = string.format("Unlocked · Prestige %d (x%.2f earnings)",
				prestigeLevel, EconomyMath.prestigeMultiplier(prestigeLevel, Prestige))
			local lbl = newLabel(card, statusText, 214, 200, Enum.TextXAlignment.Left)
			lbl.TextColor3 = Color3.fromRGB(150, 230, 150)

			if not maxed then
				local btn = newButton(card, "Franchise", allThree)
				btn.Activated:Connect(function()
					local ok, result = pcall(function()
						return Remotes.FranchiseRestaurant:InvokeServer(restaurantId)
					end)
					if ok and type(result) == "table" and result.ok then
						_status.Text = string.format("Franchised %s → Prestige %d (+%d tokens)!",
							config.displayName, result.prestigeLevel, result.tokens)
						ProfileController:refresh()
					else
						local reason = (type(result) == "table" and result.reason) or "error"
						_status.Text = "Cannot franchise: " .. tostring(reason)
					end
				end)
			end
		else
			local u = config.unlock
			newLabel(card, string.format("Lv %d · %d coins · %d gems", u.level, u.coins, u.gems),
				214, 220, Enum.TextXAlignment.Left)
			local meets = (profile.playerLevel or 1) >= u.level
				and (profile.coins or 0) >= u.coins
				and (profile.gems or 0) >= u.gems
			local btn = newButton(card, "Unlock", meets)
			btn.Activated:Connect(function()
				local ok, result = pcall(function()
					return Remotes.UnlockRestaurant:InvokeServer(restaurantId)
				end)
				if ok and type(result) == "table" and result.ok then
					_status.Text = string.format("Unlocked %s!", config.displayName)
					ProfileController:refresh()
				else
					local reason = (type(result) == "table" and result.reason) or "error"
					_status.Text = "Could not unlock: " .. tostring(reason)
				end
			end)
		end
		card.Parent = _list
	end

	-- Size the scrolling canvas to fit.
	_list.CanvasSize = UDim2.new(0, 0, 0, order * 64 + 16)
end

-- ── GUI scaffold ─────────────────────────────────────────────────────────────

local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name           = "ShopGui"
	gui.ResetOnSpawn   = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent         = Players.LocalPlayer:WaitForChild("PlayerGui")

	-- Open/close toggle (top-right).
	local toggle = Instance.new("TextButton")
	toggle.Name             = "ShopToggle"
	toggle.AnchorPoint      = Vector2.new(1, 0)
	toggle.Position         = UDim2.new(1, -8, 0, 8)
	toggle.Size             = UDim2.new(0, 120, 0, 40)
	toggle.BackgroundColor3 = Color3.fromRGB(150, 80, 200)
	toggle.TextColor3       = Color3.fromRGB(255, 255, 255)
	toggle.TextScaled       = true
	toggle.Font             = Enum.Font.GothamBold
	toggle.Text             = "🛒 Shop"
	toggle.Parent           = gui
	local tcorner = Instance.new("UICorner")
	tcorner.CornerRadius = UDim.new(0, 8)
	tcorner.Parent = toggle

	-- Panel.
	_panel = Instance.new("Frame")
	_panel.Name             = "ShopPanel"
	_panel.AnchorPoint      = Vector2.new(0.5, 0.5)
	_panel.Position         = UDim2.new(0.5, 0, 0.5, 0)
	_panel.Size             = UDim2.new(0, 560, 0, 440)
	_panel.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
	_panel.Visible          = false
	_panel.Parent           = gui
	local pcorner = Instance.new("UICorner")
	pcorner.CornerRadius = UDim.new(0, 12)
	pcorner.Parent = _panel

	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Position               = UDim2.new(0, 16, 0, 8)
	title.Size                   = UDim2.new(1, -120, 0, 36)
	title.TextColor3             = Color3.fromRGB(255, 255, 255)
	title.TextScaled             = true
	title.Font                   = Enum.Font.GothamBold
	title.TextXAlignment         = Enum.TextXAlignment.Left
	title.Text                   = "Shop"
	title.Parent                 = _panel

	_status = Instance.new("TextLabel")
	_status.BackgroundTransparency = 1
	_status.Position               = UDim2.new(0, 16, 0, 44)
	_status.Size                   = UDim2.new(1, -32, 0, 24)
	_status.TextColor3             = Color3.fromRGB(255, 224, 130)
	_status.TextScaled             = true
	_status.Font                   = Enum.Font.Gotham
	_status.TextXAlignment         = Enum.TextXAlignment.Left
	_status.Text                   = "Loading profile…"
	_status.Parent                 = _panel

	local close = Instance.new("TextButton")
	close.AnchorPoint      = Vector2.new(1, 0)
	close.Position         = UDim2.new(1, -8, 0, 8)
	close.Size             = UDim2.new(0, 36, 0, 36)
	close.BackgroundColor3 = Color3.fromRGB(190, 60, 60)
	close.TextColor3       = Color3.fromRGB(255, 255, 255)
	close.TextScaled       = true
	close.Font             = Enum.Font.GothamBold
	close.Text             = "✕"
	close.Parent           = _panel
	local ccorner = Instance.new("UICorner")
	ccorner.CornerRadius = UDim.new(0, 6)
	ccorner.Parent = close

	_list = Instance.new("ScrollingFrame")
	_list.Position               = UDim2.new(0, 8, 0, 76)
	_list.Size                   = UDim2.new(1, -16, 1, -84)
	_list.BackgroundTransparency = 1
	_list.BorderSizePixel        = 0
	_list.ScrollBarThickness     = 6
	_list.CanvasSize             = UDim2.new(0, 0, 0, 0)
	_list.Parent                 = _panel
	local layout = Instance.new("UIListLayout")
	layout.Padding       = UDim.new(0, 8)
	layout.SortOrder     = Enum.SortOrder.LayoutOrder
	layout.Parent        = _list

	toggle.Activated:Connect(function()
		_open = not _open
		_panel.Visible = _open
		if _open then rebuild() end
	end)
	close.Activated:Connect(function()
		_open = false
		_panel.Visible = false
	end)
end

function ShopController:init()
	buildGui()

	-- Rebuild whenever the shared profile changes (purchase, unlock, daily, level result).
	local ProfileController = require(script.Parent.ProfileController)
	ProfileController.Changed:Connect(function()
		if _open then rebuild() end
	end)
end

return ShopController
