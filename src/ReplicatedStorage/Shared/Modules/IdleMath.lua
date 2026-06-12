--!strict
-- Pure idle-income math (M9). No Roblox API, no os.time — elapsed and cap are
-- passed in so every branch is unit-testable and the server stays authoritative
-- over the clock (it clamps `elapsed` to real timestamp deltas before calling here).

local IdleMath = {}

-- The number of seconds that actually count toward earnings: the real elapsed
-- time, but never negative and never more than the offline cap.
function IdleMath.cappedElapsed(elapsed: number, capSeconds: number): number
	return math.clamp(elapsed, 0, math.max(capSeconds, 0))
end

-- Coins accrued over `elapsed` seconds at `ratePerSecond`, scaled by `multiplier`
-- (prestige × assigned-chef passives × mastery), clamped to the offline cap.
-- Floored to whole coins.
function IdleMath.accrue(
	ratePerSecond: number,
	multiplier: number,
	elapsed: number,
	capSeconds: number
): number
	local seconds = IdleMath.cappedElapsed(elapsed, capSeconds)
	return math.floor(ratePerSecond * multiplier * seconds)
end

-- True once the accrual has hit the offline cap (UI hint: "storage full").
function IdleMath.isCapped(elapsed: number, capSeconds: number): boolean
	return elapsed >= capSeconds
end

-- Fraction of the offline cap currently filled (0..1) — drives a progress bar.
function IdleMath.capFraction(elapsed: number, capSeconds: number): number
	if capSeconds <= 0 then return 1 end
	return math.clamp(elapsed / capSeconds, 0, 1)
end

return IdleMath
