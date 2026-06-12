--!strict
-- Client bootstrap. Initialises controllers in dependency order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
ReplicatedStorage:WaitForChild("Shared", 15)

local GameConfig  = require(ReplicatedStorage.Shared.Config.GameConfig)

local Controllers = script.Controllers

local ComboController    = require(Controllers.ComboController)
local OrderController    = require(Controllers.OrderController)
local CustomerController = require(Controllers.CustomerController)
local StationController  = require(Controllers.StationController)
local LevelController    = require(Controllers.LevelController)
local UIController       = require(Controllers.UIController)
local ProfileController  = require(Controllers.ProfileController)
local ShopController     = require(Controllers.ShopController)

ComboController:init()
OrderController:init()
CustomerController:init()
StationController:init()
LevelController:init()
UIController:init()
ProfileController:init()
ShopController:init()

print("[Client] Cooking Rush client ready.")

-- Dev convenience: auto-start level 1, but ONLY when the debug flag is on AND
-- we're in Studio. Defaults off so production boots into the normal menu/idle flow.
if GameConfig.DEBUG_AUTOSTART and RunService:IsStudio() then
	task.delay(3, function()
		print("[Client] DEBUG_AUTOSTART: auto-starting FastFood level 1")
		LevelController:startLevel("fastfood", 1)
	end)
end
