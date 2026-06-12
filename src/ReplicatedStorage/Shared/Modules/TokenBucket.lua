--!strict
-- Pure token-bucket rate-limit math. No Roblox API; `now` is injected so the
-- refill rule is unit-testable without a clock. A bucket holds up to `capacity`
-- tokens and refills at `refillPerSecond`; each allowed request spends `cost`.

local TokenBucket = {}

export type State = {
	tokens: number,    -- tokens present as of `lastTime`
	lastTime: number,  -- timestamp the token count was last computed
}

-- A fresh, full bucket. `lastTime = 0` so the first real request refills to full.
function TokenBucket.new(capacity: number): State
	return { tokens = capacity, lastTime = 0 }
end

-- Tokens available at `now`: prior tokens plus refill since `lastTime`, capped.
function TokenBucket.available(
	state: State,
	now: number,
	capacity: number,
	refillPerSecond: number
): number
	local elapsed = math.max(0, now - state.lastTime)
	return math.min(capacity, state.tokens + elapsed * refillPerSecond)
end

-- Try to spend `cost` tokens. Returns (allowed, newState). On denial the bucket
-- is not charged, but its timestamp/refill still advances.
function TokenBucket.consume(
	state: State,
	now: number,
	capacity: number,
	refillPerSecond: number,
	cost: number
): (boolean, State)
	local tokens = TokenBucket.available(state, now, capacity, refillPerSecond)
	if tokens >= cost then
		return true, { tokens = tokens - cost, lastTime = now }
	end
	return false, { tokens = tokens, lastTime = now }
end

return TokenBucket
