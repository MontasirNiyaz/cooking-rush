--!strict
-- Chefs panel (M8 UI): recruit from crates (with published odds), browse the
-- collection, equip/unequip, and fuse duplicates. Fully data-driven from config.
--
-- The server is authoritative for every recruit/equip/fuse; this UI sends the
-- intent, then asks ProfileController to refresh and rebuilds from the cache.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes       = require(ReplicatedStorage.Shared.Remotes)
local Chefs         = require(ReplicatedStorage.Shared.Config.Chefs)
local RecruitCrates = require(ReplicatedStorage.Shared.Config.RecruitCrates)
local GameConfig    = require(ReplicatedStorage.Shared.Config.GameConfig)
local Prestige      = require(ReplicatedStorage.Shared.Config.Prestige)
local ChefMath      = require(ReplicatedStorage.Shared.Modules.ChefMath)
local GachaMath     = require(ReplicatedStorage.Shared.Modules.GachaMath)

local ChefUIController = {}

local _panel:  Frame
local _list:   ScrollingFrame
local _status: TextLabel
local _open = false

-- ── UI builders ──────────────────────────────────────────────────────────────

local function newCard(order: number, height: number): Frame
	local card = Instance.new("Frame")
	card.Size             = UDim2.new(1, -12, 0, height)
	card.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
	card.BorderSizePixel  = 0
	card.LayoutOrder      = order
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = card
	return card
end

local function newLabel(parent: Instance, text: string, posX: number, posY: number, sizeX: number, sizeY: number, align: Enum.TextXAlignment): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Position               = UDim2.new(0, posX, 0, posY)
	lbl.Size                   = UDim2.new(0, sizeX, 0, sizeY)
	lbl.TextColor3             = Color3.fromRGB(235, 235, 240)
	lbl.TextScaled             = true
	lbl.Font                   = Enum.Font.Gotham
	lbl.TextXAlignment         = align
	lbl.Text                   = text
	lbl.Parent                 = parent
	return lbl
end

local function newButton(parent: Instance, text: string, posY: number, enabled: boolean, color: Color3): TextButton
	local btn = Instance.new("TextButton")
	btn.AnchorPoint      = Vector2.new(1, 0)
	btn.Position         = UDim2.new(1, -8, 0, posY)
	btn.Size             = UDim2.new(0, 104, 0, 30)
	btn.BackgroundColor3 = enabled and color or Color3.fromRGB(70, 70, 78)
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

local function newHeader(text: string, order: number): TextLabel
	local h = Instance.new("TextLabel")
	h.Size                   = UDim2.new(1, -12, 0, 28)
	h.BackgroundTransparency = 1
	h.TextColor3             = Color3.fromRGB(255, 224, 130)
	h.TextScaled             = true
	h.Font                   = Enum.Font.GothamBold
	h.TextXAlignment         = Enum.TextXAlignment.Left
	h.Text                   = text
	h.LayoutOrder            = order
	return h
end

-- Published odds: aggregate drop weight by rarity → "Rare 18% · Epic 6% · ...".
local function oddsText(crate: any): string
	local total = GachaMath.totalWeight(crate.dropTable)
	local byRarity: { [string]: number } = {}
	for _, e in ipairs(crate.dropTable) do
		local chef = Chefs.list[e.chefId]
		if chef then byRarity[chef.rarity] = (byRarity[chef.rarity] or 0) + e.weight end
	end
	local parts: { string } = {}
	for _, rar in ipairs(Chefs.RARITY_ORDER) do
		if byRarity[rar] then
			table.insert(parts, string.format("%s %.1f%%", rar, byRarity[rar] / total * 100))
		end
	end
	return table.concat(parts, "  ·  ")
end

local function costText(cost: any): string
	if cost.coins and cost.gems then return string.format("%d coins + %d gems", cost.coins, cost.gems) end
	if cost.coins then return string.format("%d coins", cost.coins) end
	if cost.gems  then return string.format("%d gems", cost.gems) end
	return "free"
end

local function canAfford(profile: any, cost: any): boolean
	return (profile.coins or 0) >= (cost.coins or 0) and (profile.gems or 0) >= (cost.gems or 0)
end

-- ── Rebuild from the cached profile ──────────────────────────────────────────

local function rebuild()
	local ProfileController = require(script.Parent.ProfileController)
	local profile = ProfileController:get()

	for _, child in ipairs(_list:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
	end
	if not profile then
		_status.Text = "Loading profile…"
		return
	end

	local owned     = profile.chefs or {}
	local equipped  = profile.equippedChefs or {}
	local slots     = ChefMath.equipSlots(ChefMath.totalPrestige(profile.prestige or {}), GameConfig, Prestige)
	_status.Text = string.format("Slots %d/%d   ·   Coins %d   ·   Gems %d",
		#equipped, slots, profile.coins or 0, profile.gems or 0)

	local equippedSet: { [number]: boolean } = {}
	for _, uid in ipairs(equipped) do equippedSet[uid] = true end

	local order = 0
	local function nextOrder(): number order += 1 return order end
	local canvasH = 0

	-- ── Recruit ──
	newHeader("Recruit", nextOrder()).Parent = _list
	canvasH += 36
	for _, crate in pairs(RecruitCrates) do
		local card = newCard(nextOrder(), 84)
		newLabel(card, crate.displayName, 8, 6, 220, 24, Enum.TextXAlignment.Left)
		newLabel(card, costText(crate.cost), 8, 30, 240, 20, Enum.TextXAlignment.Left).TextColor3 = Color3.fromRGB(255, 224, 130)
		local odds = newLabel(card, oddsText(crate), 8, 52, 460, 24, Enum.TextXAlignment.Left)
		odds.TextColor3 = Color3.fromRGB(170, 170, 180)
		odds.TextScaled = false
		odds.TextSize   = 12

		local afford = canAfford(profile, crate.cost)
		local btn = newButton(card, "Recruit", 8, afford, Color3.fromRGB(150, 80, 200))
		btn.Activated:Connect(function()
			local ok, res = pcall(function() return Remotes.Recruit:InvokeServer(crate.id) end)
			if ok and type(res) == "table" and res.ok then
				local chef = Chefs.list[res.chef.chefId]
				_status.Text = string.format("Recruited %s%s (%s)%s!",
					res.chef.shiny and "✨ " or "", chef.displayName, res.rarity,
					res.pityTriggered and " — pity!" or "")
				ProfileController:refresh()
			else
				local reason = (type(res) == "table" and res.reason) or "error"
				_status.Text = "Recruit failed: " .. tostring(reason)
			end
		end)
		card.Parent = _list
		canvasH += 92
	end

	-- ── Collection ──
	newHeader(string.format("Collection (%d)", #owned), nextOrder()).Parent = _list
	canvasH += 36
	if #owned == 0 then
		newLabel(_list, "No chefs yet — recruit one above!", 8, 0, 400, 24, Enum.TextXAlignment.Left).LayoutOrder = nextOrder()
		canvasH += 28
	end
	for _, c in ipairs(owned) do
		local chef = Chefs.list[c.chefId]
		if chef then
			local card = newCard(nextOrder(), 56)
			local nameLbl = newLabel(card,
				string.format("%s%s  ·  Lv %d", c.shiny and "✨ " or "", chef.displayName, c.level),
				8, 6, 240, 22, Enum.TextXAlignment.Left)
			local rarLbl = newLabel(card, chef.rarity, 8, 30, 200, 18, Enum.TextXAlignment.Left)
			rarLbl.TextColor3 = Chefs.RARITY_COLOR[chef.rarity] or Color3.fromRGB(200, 200, 200)
			rarLbl.TextScaled = false
			rarLbl.TextSize   = 13

			-- Equip / Unequip
			local isEq = equippedSet[c.uid] == true
			local eqBtn = newButton(card, isEq and "Unequip" or "Equip", 4, isEq or (#equipped < slots),
				isEq and Color3.fromRGB(180, 100, 60) or Color3.fromRGB(46, 160, 90))
			eqBtn.Activated:Connect(function()
				local remote = isEq and Remotes.UnequipChef or Remotes.EquipChef
				local ok, res = pcall(function() return remote:InvokeServer(c.uid) end)
				if ok and type(res) == "table" and res.ok then
					ProfileController:refresh()
				else
					_status.Text = "Failed: " .. tostring(type(res) == "table" and res.reason or "error")
				end
			end)

			-- Fuse (needs fusionCost dupes BESIDES this one)
			local dupes = ChefMath.countOfChef(owned, c.chefId)
			local cost  = ChefMath.fusionCost(c.level, GameConfig)
			local canFuse = c.level < GameConfig.CHEF_MAX_LEVEL and (dupes - 1) >= cost
			if c.level < GameConfig.CHEF_MAX_LEVEL then
				local fuseBtn = newButton(card, string.format("Fuse %d", cost), 4, canFuse, Color3.fromRGB(90, 110, 200))
				fuseBtn.Position = UDim2.new(1, -120, 0, 4)
				fuseBtn.AnchorPoint = Vector2.new(1, 0)
				fuseBtn.Activated:Connect(function()
					local ok, res = pcall(function() return Remotes.FuseChef:InvokeServer(c.uid) end)
					if ok and type(res) == "table" and res.ok then
						_status.Text = string.format("Fused %s → Lv %d", chef.displayName, res.newLevel)
						ProfileController:refresh()
					else
						_status.Text = "Fuse failed: " .. tostring(type(res) == "table" and res.reason or "error")
					end
				end)
			end
			card.Parent = _list
			canvasH += 64
		end
	end

	_list.CanvasSize = UDim2.new(0, 0, 0, canvasH + 16)
end

-- ── GUI scaffold ─────────────────────────────────────────────────────────────

local function buildGui()
	local gui = Instance.new("ScreenGui")
	gui.Name           = "ChefGui"
	gui.ResetOnSpawn   = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent         = Players.LocalPlayer:WaitForChild("PlayerGui")

	local toggle = Instance.new("TextButton")
	toggle.Name             = "ChefToggle"
	toggle.AnchorPoint      = Vector2.new(1, 0)
	toggle.Position         = UDim2.new(1, -8, 0, 56)
	toggle.Size             = UDim2.new(0, 120, 0, 40)
	toggle.BackgroundColor3 = Color3.fromRGB(200, 120, 60)
	toggle.TextColor3       = Color3.fromRGB(255, 255, 255)
	toggle.TextScaled       = true
	toggle.Font             = Enum.Font.GothamBold
	toggle.Text             = "👨‍🍳 Chefs"
	toggle.Parent           = gui
	local tcorner = Instance.new("UICorner")
	tcorner.CornerRadius = UDim.new(0, 8)
	tcorner.Parent = toggle

	_panel = Instance.new("Frame")
	_panel.Name             = "ChefPanel"
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
	title.Text                   = "Chefs"
	title.Parent                 = _panel

	_status = Instance.new("TextLabel")
	_status.BackgroundTransparency = 1
	_status.Position               = UDim2.new(0, 16, 0, 44)
	_status.Size                   = UDim2.new(1, -32, 0, 22)
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
	_list.Position               = UDim2.new(0, 8, 0, 72)
	_list.Size                   = UDim2.new(1, -16, 1, -80)
	_list.BackgroundTransparency = 1
	_list.BorderSizePixel        = 0
	_list.ScrollBarThickness     = 6
	_list.CanvasSize             = UDim2.new(0, 0, 0, 0)
	_list.Parent                 = _panel
	local layout = Instance.new("UIListLayout")
	layout.Padding   = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent    = _list

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

function ChefUIController:init()
	buildGui()
	local ProfileController = require(script.Parent.ProfileController)
	ProfileController.Changed:Connect(function()
		if _open then rebuild() end
	end)
end

return ChefUIController
