--!strict
-- Idle empire panel (M9 UI): per-restaurant passive income with a live-ticking
-- pending counter, Collect, chef assignment, and an offline-cap upgrade.
--
-- The server is authoritative for every grant and for the clock; this panel reads
-- a snapshot via GetIdleState and projects the pending number forward between
-- fetches purely for the satisfying tick. Collect always reconciles to the server.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Chefs   = require(ReplicatedStorage.Shared.Config.Chefs)

local IdleUIController = {}

local _panel:  Frame
local _list:   ScrollingFrame
local _status: TextLabel
local _gui:    ScreenGui
local _open = false

-- Live-projection state, captured at each fetch.
local _state: any = nil
local _fetchClock = 0
-- restaurantId → pending TextLabel, plus the base/rate to project from.
local _pendingLabels: { [string]: { label: TextLabel, base: number, rate: number } } = {}
local _totalLabel: TextLabel?

-- ── builders ─────────────────────────────────────────────────────────────────

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

local function newLabel(parent: Instance, text: string, x: number, y: number, w: number, h: number, align: Enum.TextXAlignment, scaled: boolean, size: number?): TextLabel
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Position               = UDim2.new(0, x, 0, y)
	lbl.Size                   = UDim2.new(0, w, 0, h)
	lbl.TextColor3             = Color3.fromRGB(235, 235, 240)
	lbl.TextXAlignment         = align
	lbl.Font                   = Enum.Font.Gotham
	lbl.Text                   = text
	if scaled then lbl.TextScaled = true else lbl.TextSize = size or 14 end
	lbl.Parent = parent
	return lbl
end

local function newButton(parent: Instance, text: string, x: number, y: number, w: number, enabled: boolean, color: Color3, anchorRight: boolean): TextButton
	local btn = Instance.new("TextButton")
	if anchorRight then
		btn.AnchorPoint = Vector2.new(1, 0)
		btn.Position    = UDim2.new(1, x, 0, y)
	else
		btn.Position    = UDim2.new(0, x, 0, y)
	end
	btn.Size             = UDim2.new(0, w, 0, 30)
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

-- A "+N coins" label that floats up and fades, for collect feedback.
local function numberPop(amount: number)
	if amount <= 0 then return end
	local pop = Instance.new("TextLabel")
	pop.AnchorPoint            = Vector2.new(0.5, 0.5)
	pop.Position               = UDim2.new(0.5, 0, 0.4, 0)
	pop.Size                   = UDim2.new(0, 260, 0, 60)
	pop.BackgroundTransparency = 1
	pop.TextColor3             = Color3.fromRGB(120, 255, 140)
	pop.TextStrokeTransparency = 0.4
	pop.TextScaled             = true
	pop.Font                   = Enum.Font.GothamBlack
	pop.Text                   = string.format("+%d 🪙", amount)
	pop.Parent                 = _gui
	task.spawn(function()
		for i = 1, 30 do
			pop.Position = pop.Position + UDim2.new(0, 0, -0.006, 0)
			pop.TextTransparency = i / 30
			pop.TextStrokeTransparency = 0.4 + i / 30 * 0.6
			task.wait(0.02)
		end
		pop:Destroy()
	end)
end

local function fmtRate(r: number): string
	if r >= 1 then return string.format("%.1f/s", r) end
	return string.format("%.0f/min", r * 60)
end

-- ── data ─────────────────────────────────────────────────────────────────────

local function fetchState()
	local ok, state = pcall(function() return Remotes.GetIdleState:InvokeServer() end)
	if ok and type(state) == "table" and state.ok then
		_state = state
		_fetchClock = os.clock()
	end
end

local function collect(restaurantId: string?)
	local ok, res = pcall(function() return Remotes.CollectIdle:InvokeServer(restaurantId) end)
	if ok and type(res) == "table" and res.ok then
		numberPop(res.collected or 0)
		local ProfileController = require(script.Parent.ProfileController)
		ProfileController:refresh()
		fetchState()
		IdleUIController._rebuild()
	end
end

-- ── rebuild ──────────────────────────────────────────────────────────────────

function IdleUIController._rebuild()
	_pendingLabels = {}
	_totalLabel = nil
	for _, child in ipairs(_list:GetChildren()) do
		if child:IsA("Frame") or child:IsA("TextLabel") then child:Destroy() end
	end
	if not _state then
		_status.Text = "Loading…"
		return
	end
	_status.Text = string.format("Offline cap: %dh", _state.capHours or 8)

	local order = 0
	local function nextOrder(): number order += 1 return order end
	local canvasH = 0

	-- Collect-all + cap upgrade header card
	local top = newCard(nextOrder(), 44)
	_totalLabel = newLabel(top, "", 8, 6, 240, 32, Enum.TextXAlignment.Left, true)
	local collectAll = newButton(top, "Collect All", -8, 7, 120, true, Color3.fromRGB(46, 160, 90), true)
	collectAll.Activated:Connect(function() collect(nil) end)
	if _state.capUpgradeGems then
		local capBtn = newButton(top, string.format("+%dh · %d💎", _state.capUpgradeHours, _state.capUpgradeGems),
			-136, 7, 150, true, Color3.fromRGB(46, 134, 222), true)
		capBtn.Activated:Connect(function()
			local ok, res = pcall(function() return Remotes.PurchaseIdleCap:InvokeServer() end)
			if ok and type(res) == "table" and res.ok then
				local ProfileController = require(script.Parent.ProfileController)
				ProfileController:refresh()
				fetchState()
				IdleUIController._rebuild()
			end
		end)
	end
	top.Parent = _list
	canvasH += 52

	-- Per-restaurant cards
	for _, r in ipairs(_state.restaurants) do
		local card = newCard(nextOrder(), 92)
		newLabel(card, r.displayName, 8, 6, 220, 22, Enum.TextXAlignment.Left, true)
		newLabel(card, fmtRate(r.ratePerSec), 8, 30, 160, 18, Enum.TextXAlignment.Left, false, 13).TextColor3 = Color3.fromRGB(170, 200, 170)

		local pendingLbl = newLabel(card, "", 8, 50, 200, 26, Enum.TextXAlignment.Left, false, 18)
		pendingLbl.TextColor3 = Color3.fromRGB(255, 224, 130)
		pendingLbl.Font       = Enum.Font.GothamBold
		_pendingLabels[r.restaurantId] = { label = pendingLbl, base = r.pending, rate = r.ratePerSec }

		local collectBtn = newButton(card, "Collect", -8, 6, 104, true, Color3.fromRGB(46, 160, 90), true)
		collectBtn.Activated:Connect(function() collect(r.restaurantId) end)

		-- Chef assignment: Auto-assign + assigned chips (✕ to unassign)
		local autoBtn = newButton(card, string.format("Auto-assign (%d/%d)", #r.assigned, r.slots),
			-8, 44, 160, #r.assigned < r.slots, Color3.fromRGB(90, 110, 200), true)
		autoBtn.Activated:Connect(function()
			local ok, res = pcall(function() return Remotes.AutoAssignIdle:InvokeServer(r.restaurantId) end)
			if ok and type(res) == "table" and res.ok then
				fetchState(); IdleUIController._rebuild()
			else
				_status.Text = "Assign: " .. tostring(type(res) == "table" and res.reason or "error")
			end
		end)

		local chipX = 180
		for _, uid in ipairs(r.assigned) do
			-- Find the chef instance to name the chip.
			local profile = require(script.Parent.ProfileController):get()
			local name = "Chef"
			if profile and profile.chefs then
				for _, c in ipairs(profile.chefs) do
					if c.uid == uid then
						local cfg = Chefs.list[c.chefId]
						name = (cfg and cfg.displayName or c.chefId) .. (c.shiny and " ✨" or "")
						break
					end
				end
			end
			local chip = Instance.new("TextButton")
			chip.Position         = UDim2.new(0, chipX, 0, 50)
			chip.Size             = UDim2.new(0, 96, 0, 22)
			chip.BackgroundColor3 = Color3.fromRGB(60, 60, 72)
			chip.TextColor3       = Color3.fromRGB(235, 235, 240)
			chip.TextScaled       = true
			chip.Font             = Enum.Font.Gotham
			chip.Text             = name .. " ✕"
			chip.Parent           = card
			local cc = Instance.new("UICorner"); cc.CornerRadius = UDim.new(0, 6); cc.Parent = chip
			chip.Activated:Connect(function()
				local ok, res = pcall(function() return Remotes.UnassignChefIdle:InvokeServer(r.restaurantId, uid) end)
				if ok and type(res) == "table" and res.ok then fetchState(); IdleUIController._rebuild() end
			end)
			chipX += 102
		end

		card.Parent = _list
		canvasH += 100
	end

	_list.CanvasSize = UDim2.new(0, 0, 0, canvasH + 16)
end

-- ── live tick ────────────────────────────────────────────────────────────────

local function tick()
	if not _open or not _state then return end
	local dt = os.clock() - _fetchClock
	local total = 0
	for _, entry in pairs(_pendingLabels) do
		local projected = entry.base + entry.rate * dt
		entry.label.Text = string.format("%d 🪙", math.floor(projected))
	end
	for _, r in ipairs(_state.restaurants) do
		total += r.pending + r.ratePerSec * dt
	end
	if _totalLabel then _totalLabel.Text = string.format("Pending: %d 🪙", math.floor(total)) end
end

-- ── scaffold ─────────────────────────────────────────────────────────────────

local function buildGui()
	_gui = Instance.new("ScreenGui")
	_gui.Name           = "IdleGui"
	_gui.ResetOnSpawn   = false
	_gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	_gui.Parent         = Players.LocalPlayer:WaitForChild("PlayerGui")

	local toggle = Instance.new("TextButton")
	toggle.Name             = "IdleToggle"
	toggle.AnchorPoint      = Vector2.new(1, 0)
	toggle.Position         = UDim2.new(1, -8, 0, 104)
	toggle.Size             = UDim2.new(0, 120, 0, 40)
	toggle.BackgroundColor3 = Color3.fromRGB(60, 170, 120)
	toggle.TextColor3       = Color3.fromRGB(255, 255, 255)
	toggle.TextScaled       = true
	toggle.Font             = Enum.Font.GothamBold
	toggle.Text             = "💰 Idle"
	toggle.Parent           = _gui
	local tcorner = Instance.new("UICorner"); tcorner.CornerRadius = UDim.new(0, 8); tcorner.Parent = toggle

	_panel = Instance.new("Frame")
	_panel.Name             = "IdlePanel"
	_panel.AnchorPoint      = Vector2.new(0.5, 0.5)
	_panel.Position         = UDim2.new(0.5, 0, 0.5, 0)
	_panel.Size             = UDim2.new(0, 580, 0, 440)
	_panel.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
	_panel.Visible          = false
	_panel.Parent           = _gui
	local pcorner = Instance.new("UICorner"); pcorner.CornerRadius = UDim.new(0, 12); pcorner.Parent = _panel

	local title = newLabel(_panel, "Idle Empire", 16, 8, 300, 36, Enum.TextXAlignment.Left, true)
	title.Font = Enum.Font.GothamBold

	_status = newLabel(_panel, "Loading…", 16, 44, 400, 22, Enum.TextXAlignment.Left, true)
	_status.TextColor3 = Color3.fromRGB(255, 224, 130)

	local close = newButton(_panel, "✕", -8, 8, 36, true, Color3.fromRGB(190, 60, 60), true)
	close.Activated:Connect(function() _open = false; _panel.Visible = false end)

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
		if _open then
			fetchState()
			IdleUIController._rebuild()
		end
	end)
end

function IdleUIController:init()
	buildGui()
	RunService.Heartbeat:Connect(tick)
	-- Periodically re-sync with the server while open so the projection can't drift
	-- past the real offline cap.
	task.spawn(function()
		while true do
			task.wait(10)
			if _open then
				fetchState()
				IdleUIController._rebuild()
			end
		end
	end)
end

return IdleUIController
