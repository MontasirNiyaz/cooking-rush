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
local MasteryService     = require(Services.MasteryService)
local RecruitService     = require(Services.RecruitService)
local ChefService        = require(Services.ChefService)
local IdleService        = require(Services.IdleService)
local LevelService       = require(Services.LevelService)

-- Init order respects dependency graph.
DataService:init()
EconomyService:init()
ProgressionService:init()
UpgradeService:init()
MasteryService:init()
RecruitService:init()
ChefService:init()
IdleService:init()
LevelService:init()

print("[Server] Cooking Rush server ready.")
