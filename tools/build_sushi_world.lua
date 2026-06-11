--!nonstrict
-- Reproducible builder for the Sushi kitchen world (M6).
--
-- The in-world kitchen (station Parts) lives in the place file, not in Rojo source,
-- so this script is the version-controlled record of that world. Paste it into the
-- Studio command bar (Edit mode) — or run via the MCP execute_luau Edit datamodel —
-- to (re)build the Sushi stations. Idempotent: skips any StationId already present.
--
-- Layout: two rows to the right of the FastFood kitchen (X 20..48), sharing the
-- existing 3 seats at Z=4. FastFood occupies X -21..7, so there is no overlap.
-- Colours follow the project convention: shelves green, cookers red, dispensers
-- blue, assembler yellow.

local GREEN  = Color3.fromRGB(90, 170, 90)
local RED    = Color3.fromRGB(190, 70, 70)
local BLUE   = Color3.fromRGB(70, 120, 200)
local YELLOW = Color3.fromRGB(210, 190, 70)

-- { stationId, x, z, colour }
local PARTS = {
	-- Back row (shelves + rice), Z = -14
	{ "raw_salmon_shelf", 20, -14, GREEN },
	{ "raw_tuna_shelf",   27, -14, GREEN },
	{ "nori_shelf",       34, -14, GREEN },
	{ "miso_base_shelf",  41, -14, GREEN },
	{ "rice_dispenser",   48, -14, BLUE },
	-- Front row (appliances), Z = -7
	{ "fish_prep",        20, -7,  RED },
	{ "tuna_prep",        27, -7,  RED },
	{ "soup_pot",         34, -7,  RED },
	{ "sushi_roller",     41, -7,  YELLOW },
	{ "tea_dispenser",    48, -7,  BLUE },
}

local function buildSushiWorld()
	workspace.StreamingEnabled = false

	local stations = workspace:FindFirstChild("Stations")
	if not stations then
		stations = Instance.new("Folder")
		stations.Name = "Stations"
		stations.Parent = workspace
	end

	-- Index existing parts by StationId so re-runs don't duplicate.
	local existing = {}
	for _, p in ipairs(stations:GetChildren()) do
		if p:IsA("BasePart") and p:GetAttribute("StationId") then
			existing[p:GetAttribute("StationId")] = true
		end
	end

	local built = 0
	for _, entry in ipairs(PARTS) do
		local id, x, z, colour = entry[1], entry[2], entry[3], entry[4]
		if not existing[id] then
			local part = Instance.new("Part")
			part.Name = id
			part.Anchored = true
			part.Size = Vector3.new(5, 3, 3)
			part.Position = Vector3.new(x, 1, z)
			part.Color = colour
			part:SetAttribute("StationId", id)
			part.Parent = stations
			built += 1
		end
	end

	return string.format("[build_sushi_world] built %d new sushi station parts (%d already present)",
		built, #PARTS - built)
end

return buildSushiWorld()
