--!strict
-- Server bootstrap. Initialises services in dependency order.
-- Each service exposes :init() and may expose :start() for deferred work.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared            = ReplicatedStorage:WaitForChild("Shared")

-- Validate all config tables before any service uses them.
local Schema = require(Shared.Modules.Schema)
Schema.validateAll()

-- Services folder sits next to this script.
local Services = script.Services

local DataService        = require(Services.DataService)
local EconomyService     = require(Services.EconomyService)
local ProgressionService = require(Services.ProgressionService)
local UpgradeService     = require(Services.UpgradeService)
local LevelService       = require(Services.LevelService)
local HubService         = require(Services.HubService)

-- Init order respects dependency graph.
DataService:init()
EconomyService:init()
ProgressionService:init()
UpgradeService:init()
LevelService:init()
HubService:init()

print("[Server] Cooking Rush server ready.")
