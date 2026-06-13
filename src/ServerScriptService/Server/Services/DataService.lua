--!strict
-- Loads and saves player profiles.
-- All other services read/write through getProfile() — never touch DataStore directly.
-- Durability: at most one in-flight save per player, retry-with-backoff on failure,
-- and a BindToClose flush so the final session state is persisted on shutdown.
-- Cross-server safety: a session lock (SessionLock) is acquired inside the load
-- UpdateAsync and re-verified on every save, so a stale server can't clobber a
-- player who has hopped to a newer one.

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig  = require(ReplicatedStorage.Shared.Config.GameConfig)
local SessionLock = require(ReplicatedStorage.Shared.Modules.SessionLock)
local EnvConfig   = require(ReplicatedStorage.Shared.Modules.EnvConfig)

export type Profile = {
	coins: number,
	gems: number,
	xp: number,
	playerLevel: number,
	unlockedRestaurants: { [string]: boolean },
	levelStars: { [string]: number },
	upgrades: { [string]: number },
	lastDailyClaim: number,
	lastIncomeClaim: { [string]: number },
	seenTutorial: boolean,  -- false until the first onboarding level is completed
	version: number,
	sessionLock: SessionLock.Lock?,  -- server-only; set inside load/save transforms
}

local CURRENT_VERSION = 1

local DEFAULT_PROFILE: Profile = {
	coins = 100, gems = 5, xp = 0, playerLevel = 1,
	unlockedRestaurants = { fastfood = true },
	levelStars = {}, upgrades = {},
	lastDailyClaim = 0, lastIncomeClaim = {},
	seenTutorial = false,
	version = CURRENT_VERSION,
}

-- Schema migrations: index = version being migrated FROM
local MIGRATIONS: { (Profile) -> () } = {
	-- [1] = function(p) p.newField = "default" end,
}

local ENV: EnvConfig.Env  = EnvConfig.resolveEnv(game.PlaceId, GameConfig.PLACE_ENV)
local STORE_NAME: string  = EnvConfig.storeName(GameConfig.DATASTORE_NAME, ENV)
local store: DataStore    = DataStoreService:GetDataStore(STORE_NAME)
local profiles: { [number]: Profile } = {}
local saving:   { [number]: boolean } = {}  -- userId → save in flight (no overlap)

local SAVE_RETRIES = 3

local DataService = {}

local function reconcile(data: any, defaults: any)
	for k, v in pairs(defaults) do
		if data[k] == nil then
			data[k] = if type(v) == "table" then table.clone(v :: any) else v
		end
	end
end

local function migrate(p: Profile)
	while p.version < CURRENT_VERSION do
		local fn = MIGRATIONS[p.version]
		if fn then fn(p) end
		p.version += 1
	end
end

local function freshProfile(): Profile
	local p = table.clone(DEFAULT_PROFILE :: any)
	-- Deep-clone table fields so sessions don't share the default's sub-tables.
	p.unlockedRestaurants = table.clone(DEFAULT_PROFILE.unlockedRestaurants)
	p.levelStars          = {}
	p.upgrades            = {}
	p.lastIncomeClaim     = {}
	return p
end

-- Atomically acquires the session lock and loads (or initialises) the profile.
-- Returns nil when another server holds a live lock (the player is kicked to retry).
local function load(player: Player): Profile?
	local key   = "player_" .. player.UserId
	local jobId = game.JobId
	local now   = os.time()
	local ttl   = GameConfig.SESSION_LOCK_TTL

	local acquired = false
	local loaded: Profile? = nil

	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old: any)
			-- Refuse if another server holds a live (unexpired) lock.
			if type(old) == "table" and not SessionLock.canAcquire(old.sessionLock, jobId, now) then
				acquired = false
				return nil  -- cancel write; leave their data + lock untouched
			end

			local data: Profile
			if type(old) == "table" then
				data = old :: any
				reconcile(data, DEFAULT_PROFILE)
				migrate(data)
			else
				data = freshProfile()
			end
			data.sessionLock = SessionLock.make(jobId, now, ttl)
			acquired = true
			loaded   = data
			return data
		end)
	end)

	if ok and acquired and loaded then
		profiles[player.UserId] = loaded
		return loaded
	end

	if ok and not acquired then
		-- Foreign live lock: the session is still active on another server.
		warn(string.format("[DataService] %s is locked on another server — kicking to retry", player.Name))
		player:Kick("Your save is still active on another server. Please rejoin in a few seconds.")
		return nil
	end

	-- DataStore unavailable (e.g. Studio without API access): fall back to an
	-- in-memory default so the game stays playable locally (no persistence, no lock).
	warn(string.format("[DataService] load failed for %s (%s) — using in-memory default",
		player.Name, tostring(err)))
	local profile = freshProfile()
	profiles[player.UserId] = profile
	return profile
end

-- `release` (on leave/shutdown) clears the lock so another server can take over
-- immediately; otherwise the lock is refreshed to keep this session's claim alive.
local function save(player: Player, release: boolean?)
	local userId = player.UserId
	local p = profiles[userId]
	if not p then return end
	if saving[userId] then return end  -- a save is already in flight for this player
	saving[userId] = true

	local key   = "player_" .. userId
	local jobId = game.JobId
	for attempt = 1, SAVE_RETRIES do
		local aborted = false
		-- UpdateAsync is atomic and queues per key. The transform re-checks the
		-- lock so a stale server can't overwrite a session that moved on.
		local ok, err = pcall(function()
			store:UpdateAsync(key, function(old: any)
				local now = os.time()
				if type(old) == "table" and not SessionLock.canAcquire(old.sessionLock, jobId, now) then
					aborted = true
					return nil  -- a newer server owns this profile; don't clobber it
				end
				p.sessionLock = if release then nil else SessionLock.make(jobId, now, GameConfig.SESSION_LOCK_TTL)
				return p
			end)
		end)
		if ok then
			if aborted then
				warn(string.format("[DataService] save for %s aborted — lock held by another server", player.Name))
			end
			saving[userId] = false
			return
		end
		warn(string.format("[DataService] save attempt %d/%d for %s failed: %s",
			attempt, SAVE_RETRIES, player.Name, tostring(err)))
		task.wait(attempt)  -- linear backoff
	end

	warn(string.format("[DataService] GAVE UP saving %s after %d attempts", player.Name, SAVE_RETRIES))
	saving[userId] = false
end

function DataService:init()
	print(string.format("[DataService] environment=%s placeId=%d store=%q", ENV, game.PlaceId, STORE_NAME))

	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(function(player)
		save(player, true)  -- final save + release the lock
		profiles[player.UserId] = nil
	end)

	-- Autosave loop
	task.spawn(function()
		while true do
			task.wait(GameConfig.AUTOSAVE_INTERVAL)
			for _, player in ipairs(Players:GetPlayers()) do
				save(player)
			end
		end
	end)

	-- Handle players already connected (race with server startup)
	for _, player in ipairs(Players:GetPlayers()) do
		load(player)
	end

	-- Flush every active profile on server shutdown so the final session state
	-- isn't lost. BindToClose blocks shutdown (up to ~30s) until this returns.
	game:BindToClose(function()
		local pending = 0
		for _, player in ipairs(Players:GetPlayers()) do
			pending += 1
			task.spawn(function()
				save(player, true)  -- release on shutdown so the next server loads cleanly
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait()
		end
	end)
end

function DataService:getProfile(player: Player): Profile?
	return profiles[player.UserId]
end

function DataService:save(player: Player)
	save(player)
end

return DataService
