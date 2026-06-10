--!strict
-- Loads and saves player profiles. Session-locked; one active save per player.
-- All other services read/write through getProfile() — never touch DataStore directly.

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
	version: number,
}

local CURRENT_VERSION = 1

local DEFAULT_PROFILE: Profile = {
	coins = 100, gems = 5, xp = 0, playerLevel = 1,
	unlockedRestaurants = { fastfood = true },
	levelStars = {}, upgrades = {},
	lastDailyClaim = 0, lastIncomeClaim = {},
	version = CURRENT_VERSION,
}

-- Schema migrations: index = version being migrated FROM
local MIGRATIONS: { (Profile) -> () } = {
	-- [1] = function(p) p.newField = "default" end,
}

local store: DataStore = DataStoreService:GetDataStore(GameConfig.DATASTORE_NAME)
local profiles: { [number]: Profile } = {}

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
	end
	profiles[player.UserId] = profile
	return profile
end

local function save(player: Player)
	local p = profiles[player.UserId]
	if not p then return end
	pcall(store.SetAsync, store, "player_" .. player.UserId, p)
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
end

function DataService:getProfile(player: Player): Profile?
	return profiles[player.UserId]
end

function DataService:save(player: Player)
	save(player)
end

return DataService
