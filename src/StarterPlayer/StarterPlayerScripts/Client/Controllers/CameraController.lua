--!strict
-- Fixed in-level kitchen camera (P1.3). During a level the camera is locked to a
-- readable, isometric-ish framing whose values come from the restaurant config
-- (camera.focus / camera.offset / camera.fov) — no per-restaurant code. In the
-- hub it returns to the normal free player camera.

local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Enums       = require(ReplicatedStorage.Shared.Modules.Enums)
local Restaurants = require(ReplicatedStorage.Shared.Config.Restaurants)

local CameraController = {}

local DEFAULT_FOV = 70

local function vec(t: { x: number, y: number, z: number }): Vector3
	return Vector3.new(t.x, t.y, t.z)
end

local function applyLevelCamera(restaurantId: string)
	local restaurant = Restaurants[restaurantId]
	if not restaurant or not restaurant.camera then return end
	local cam = Workspace.CurrentCamera
	if not cam then return end

	local c = restaurant.camera
	local focus = vec(c.focus)
	local pos   = focus + vec(c.offset)
	cam.CameraType  = Enum.CameraType.Scriptable
	cam.FieldOfView = c.fov
	cam.CFrame      = CFrame.lookAt(pos, focus)
end

local function freeCamera()
	local cam = Workspace.CurrentCamera
	if not cam then return end
	cam.CameraType  = Enum.CameraType.Custom
	cam.FieldOfView = DEFAULT_FOV
end

function CameraController:init()
	local LevelController = require(script.Parent.LevelController)

	LevelController.StateChanged:Connect(function(newState: string)
		if newState == Enums.LevelState.Intro or newState == Enums.LevelState.Playing then
			local level = LevelController.currentLevel
			if level then applyLevelCamera(level.restaurantId) end
		elseif newState == Enums.LevelState.Idle then
			freeCamera()  -- back in the hub: free movement camera
		end
		-- Results keeps the locked kitchen camera behind the results panel.
	end)
end

return CameraController
