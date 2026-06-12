--!strict
-- Loads and saves player profiles.
-- All other services read/write through getProfile() — never touch DataStore directly.
-- Durability: at most one in-flight save per player, retry-with-backoff on failure,
-- and a BindToClose flush so the final session state is persisted on shutdown.
-- (Full cross-server session locking is future work — see ISSUES.md.)

local DataStoreService = game:GetService("DataStoreService")
local Players          = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

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
	-- M7 meta-progression
	mastery: { [string]: { level: number, xp: number } },  -- recipeId → mastery
	prestige: { [string]: number },                        -- restaurantId → prestige level
	prestigeTokens: number,                                -- soft-premium currency
	-- M8 chef collection
	chefs: { { uid: number, chefId: string, shiny: boolean, level: number } },
	equippedChefs: { number },                             -- equipped chef uids
	pity: { [string]: number },                            -- crateId → consecutive sub-floor pulls
	nextChefUid: number,                                   -- server-authoritative uid counter
	version: number,
}

local CURRENT_VERSION = 3

local DEFAULT_PROFILE: Profile = {
	coins = 100, gems = 5, xp = 0, playerLevel = 1,
	unlockedRestaurants = { fastfood = true },
	levelStars = {}, upgrades = {},
	lastDailyClaim = 0, lastIncomeClaim = {},
	mastery = {}, prestige = {}, prestigeTokens = 0,
	chefs = {}, equippedChefs = {}, pity = {}, nextChefUid = 1,
	version = CURRENT_VERSION,
}

-- Schema migrations: index = version being migrated FROM
local MIGRATIONS: { (Profile) -> () } = {
	-- v1 → v2: add M7 meta-progression fields.
	[1] = function(p)
		p.mastery        = p.mastery or {}
		p.prestige       = p.prestige or {}
		p.prestigeTokens = p.prestigeTokens or 0
	end,
	-- v2 → v3: add M8 chef-collection fields.
	[2] = function(p)
		p.chefs         = p.chefs or {}
		p.equippedChefs = p.equippedChefs or {}
		p.pity          = p.pity or {}
		p.nextChefUid   = p.nextChefUid or 1
	end,
}

local store: DataStore = DataStoreService:GetDataStore(GameConfig.DATASTORE_NAME)
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

local function load(player: Player): Profile
	local key = "player_" .. player.UserId
	local ok, data = pcall(store.GetAsync, store, key)
	local profile: Profile
	if ok and type(data) == "table" then
		profile = data :: any
		reconcile(profile, DEFAULT_PROFILE)
		migrate(profile)
	else
		profile = table.clone(DEFAULT_PROFILE :: any)
		-- Deep-clone table fields
		profile.unlockedRestaurants = table.clone(DEFAULT_PROFILE.unlockedRestaurants)
		profile.levelStars          = {}
		profile.upgrades            = {}
		profile.lastIncomeClaim     = {}
		profile.mastery             = {}
		profile.prestige            = {}
		profile.chefs               = {}
		profile.equippedChefs       = {}
		profile.pity                = {}
	end
	profiles[player.UserId] = profile
	return profile
end

local function save(player: Player)
	local userId = player.UserId
	local p = profiles[userId]
	if not p then return end
	if saving[userId] then return end  -- a save is already in flight for this player
	saving[userId] = true

	local key = "player_" .. userId
	for attempt = 1, SAVE_RETRIES do
		-- UpdateAsync is atomic and queues per key; the transform ignores the old
		-- value because the in-memory profile is authoritative for this session.
		local ok, err = pcall(function()
			store:UpdateAsync(key, function()
				return p
			end)
		end)
		if ok then
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
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(function(player)
		save(player)
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
				save(player)
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
