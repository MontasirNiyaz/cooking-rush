--!strict
-- Per-player, per-remote rate limiting. Every OnServerInvoke calls
-- RemoteGuard.allow(player, remoteName) and drops (returns its failure value)
-- when the player's token bucket for that remote is empty. Buckets are isolated
-- per player, so one spammer can't starve anyone else. Limits live in
-- GameConfig.REMOTE_RATE_LIMITS; bucket math is the pure TokenBucket module.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig  = require(ReplicatedStorage.Shared.Config.GameConfig)
local TokenBucket = require(ReplicatedStorage.Shared.Modules.TokenBucket)

local RemoteGuard = {}

-- buckets[userId][remoteName] = TokenBucket.State
local buckets: { [number]: { [string]: TokenBucket.State } } = {}

local function limitFor(remoteName: string)
	local limits = GameConfig.REMOTE_RATE_LIMITS
	return limits[remoteName] or limits.__default
end

-- True if this invoke is within the player's rate budget (and spends a token).
-- False — and logs — when the bucket is empty; callers should drop the request.
function RemoteGuard.allow(player: Player, remoteName: string): boolean
	local userId = player.UserId
	local perPlayer = buckets[userId]
	if not perPlayer then
		perPlayer = {}
		buckets[userId] = perPlayer
	end

	local limit = limitFor(remoteName)
	local state = perPlayer[remoteName] or TokenBucket.new(limit.burst)
	local allowed, newState =
		TokenBucket.consume(state, os.clock(), limit.burst, limit.refillPerSecond, 1)
	perPlayer[remoteName] = newState

	if not allowed then
		warn(string.format("[RemoteGuard] dropped %s from %s (rate limit)", remoteName, player.Name))
	end
	return allowed
end

Players.PlayerRemoving:Connect(function(player)
	buckets[player.UserId] = nil
end)

return RemoteGuard
