--!strict
-- Client bootstrap. Initialises controllers in dependency order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
ReplicatedStorage:WaitForChild("Shared", 15)

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

-- Auto-start level 1 when running inside Studio (M1 test convenience).
if RunService:IsStudio() then
	task.delay(3, function()
		print("[Client] Studio: auto-starting FastFood level 1")
		LevelController:startLevel("fastfood", 1)
	end)
end
