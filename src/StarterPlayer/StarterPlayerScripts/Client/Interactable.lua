--!strict
-- Generic interaction binding (P1.3). One input implementation for every
-- interactable (stations, seats) — no per-station input code. Switchable between
-- ProximityPrompt and direct tap/click via GameConfig.INTERACTION_MODE:
--   "prompt" → ProximityPrompt (HoldDuration 0).
--   "tap"    → ClickDetector on an oversized invisible hitbox so touch targets
--              stay thumb-friendly on phones; a floating label shows the action.
--
-- bind() returns a Handle: call :setActionText(text) to update the label and
-- :Destroy() to tear everything down (or add it to a Trove — it has :Destroy()).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Trove      = require(ReplicatedStorage.Shared.Packages.Trove)

local Interactable = {}

export type Options = {
	objectText: string,
	actionText: string,
	maxDistance: number?,
	onActivate: (Player) -> (),
}

local function bindPrompt(part: BasePart, opts: Options, trove: any)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText           = opts.actionText
	prompt.ObjectText           = opts.objectText
	prompt.MaxActivationDistance = opts.maxDistance or 8
	prompt.HoldDuration         = 0
	prompt.RequiresLineOfSight  = false
	prompt.Parent               = part
	trove:Add(prompt)
	trove:Connect(prompt.Triggered, function(plr: Player)
		opts.onActivate(plr)
	end)
	return function(text: string)
		prompt.ActionText = text
	end
end

local function bindTap(part: BasePart, opts: Options, trove: any)
	-- Oversized invisible hitbox = generous touch target.
	local pad  = GameConfig.TAP_HITBOX_PADDING
	local minE = GameConfig.TAP_HITBOX_MIN
	local s = part.Size + Vector3.new(pad, pad, pad) * 2
	s = Vector3.new(math.max(s.X, minE), math.max(s.Y, minE), math.max(s.Z, minE))

	local hit = Instance.new("Part")
	hit.Name         = "TapHitbox"
	hit.Size         = s
	hit.CFrame       = part.CFrame
	hit.Transparency = 1
	hit.CanCollide   = false
	hit.CanQuery     = true
	hit.Anchored     = true
	hit.Parent       = part
	trove:Add(hit)

	local cd = Instance.new("ClickDetector")
	cd.MaxActivationDistance = opts.maxDistance or 8
	cd.Parent = hit
	trove:Add(cd)

	-- Floating action label (tap mode has no built-in prompt text).
	local bb = Instance.new("BillboardGui")
	bb.Name        = "TapLabel"
	bb.Size        = UDim2.new(0, 150, 0, 30)
	bb.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 1.5, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = (opts.maxDistance or 8) + 4
	bb.Adornee     = part
	bb.Parent      = part
	trove:Add(bb)
	local lbl = Instance.new("TextLabel")
	lbl.Size                   = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundColor3       = Color3.fromRGB(0, 0, 0)
	lbl.BackgroundTransparency = 0.4
	lbl.TextColor3             = Color3.fromRGB(255, 255, 255)
	lbl.TextScaled             = true
	lbl.Font                   = Enum.Font.GothamBold
	lbl.Text                   = opts.actionText
	lbl.Parent                 = bb

	trove:Connect(cd.MouseClick, function(plr: Player)
		opts.onActivate(plr)
	end)
	return function(text: string)
		lbl.Text = text
	end
end

-- Returns a Handle = { setActionText, Destroy }.
function Interactable.bind(part: BasePart, opts: Options): any
	local trove = Trove.new()
	local setText = if GameConfig.INTERACTION_MODE == "tap"
		then bindTap(part, opts, trove)
		else bindPrompt(part, opts, trove)

	return {
		setActionText = function(_self: any, text: string)
			setText(text)
		end,
		Destroy = function(_self: any)
			trove:Destroy()
		end,
	}
end

return Interactable
