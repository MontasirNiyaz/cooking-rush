--!nonstrict
-- Config-driven, idempotent world builder (P1.0 — replaces build_sushi_world.lua).
--
-- The in-world kitchen Parts live in the place file, not in Rojo source, so this
-- script is the version-controlled record of that world. Paste it into the Studio
-- command bar (Edit mode) — or run via the MCP execute_luau Edit datamodel — to
-- (re)build every restaurant's stations and the shared seats.
--
-- What it does, idempotently:
--   * Flips workspace.StreamingEnabled = TRUE (the controllers now bind by
--     CollectionService tag, so streaming is safe — see ISSUES #13 / P1.0).
--   * Ensures a Part for every station id and seat below, matched by StationId
--     attribute / seat name so re-runs never duplicate.
--   * Applies the "Station" / "Seat" tags the controllers bind to — including to
--     pre-existing hand-placed Parts that predate tagging.
--
-- Adding a restaurant's world = add a STATIONS entry. No engine code, no new tool.

local CollectionService = game:GetService("CollectionService")

local STATION_TAG = "Station"
local SEAT_TAG    = "Seat"

-- Colour by station role (project convention).
local COLOUR = {
	shelf     = Color3.fromRGB(90, 170, 90),   -- green
	cooker    = Color3.fromRGB(190, 70, 70),   -- red
	dispenser = Color3.fromRGB(70, 120, 200),  -- blue
	assembler = Color3.fromRGB(210, 190, 70),  -- yellow
}

-- Per-restaurant station layout: { stationId, x, z, role }.
-- z = -14 back row (shelves / dispensers), z = -7 front row (appliances).
-- FastFood occupies X -21..0, Sushi X 20..48 — no overlap, shared seats between.
local STATIONS = {
	fastfood = {
		{ "raw_patty_shelf", -21, -14, "shelf" },
		{ "raw_fries_shelf", -14, -14, "shelf" },
		{ "bun_shelf",        -7, -14, "shelf" },
		{ "cheese_shelf",      0, -14, "shelf" },
		{ "grill",           -21,  -7, "cooker" },
		{ "fryer",           -14,  -7, "cooker" },
		{ "bun_counter",      -7,  -7, "assembler" },
		{ "drink_dispenser",   0,  -7, "dispenser" },
	},
	sushi = {
		{ "raw_salmon_shelf", 20, -14, "shelf" },
		{ "raw_tuna_shelf",   27, -14, "shelf" },
		{ "nori_shelf",       34, -14, "shelf" },
		{ "miso_base_shelf",  41, -14, "shelf" },
		{ "rice_dispenser",   48, -14, "dispenser" },
		{ "fish_prep",        20,  -7, "cooker" },
		{ "tuna_prep",        27,  -7, "cooker" },
		{ "soup_pot",         34,  -7, "cooker" },
		{ "sushi_roller",     41,  -7, "assembler" },
		{ "tea_dispenser",    48,  -7, "dispenser" },
	},
}

-- Shared seats: { name, x, z }. Between the two kitchens at Z = +4.
local SEATS = {
	{ "Seat1", -14, 4 },
	{ "Seat2",  -7, 4 },
	{ "Seat3",   0, 4 },
}

local function ensureTag(inst: Instance, tag: string): boolean
	if not CollectionService:HasTag(inst, tag) then
		CollectionService:AddTag(inst, tag)
		return true
	end
	return false
end

local function ensureFolder(name: string): Folder
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f
end

local function buildWorld()
	workspace.StreamingEnabled = true

	local stationsFolder = ensureFolder("Stations")
	local seatsFolder    = ensureFolder("Seats")

	-- Index existing station Parts by StationId.
	local existingStations = {}
	for _, p in ipairs(stationsFolder:GetChildren()) do
		if p:IsA("BasePart") and p:GetAttribute("StationId") then
			existingStations[p:GetAttribute("StationId")] = p
		end
	end

	local createdStations, taggedStations = 0, 0
	for _, layout in pairs(STATIONS) do
		for _, entry in ipairs(layout) do
			local id, x, z, role = entry[1], entry[2], entry[3], entry[4]
			local part = existingStations[id]
			if not part then
				part = Instance.new("Part")
				part.Name = id
				part.Anchored = true
				part.Size = Vector3.new(5, 3, 3)
				part.Position = Vector3.new(x, 1, z)
				part.Color = COLOUR[role] or Color3.fromRGB(160, 160, 160)
				part:SetAttribute("StationId", id)
				part.Parent = stationsFolder
				existingStations[id] = part
				createdStations += 1
			end
			if ensureTag(part, STATION_TAG) then taggedStations += 1 end
		end
	end

	-- Index existing seats by name.
	local existingSeats = {}
	for _, p in ipairs(seatsFolder:GetChildren()) do
		if p:IsA("BasePart") then existingSeats[p.Name] = p end
	end

	local createdSeats, taggedSeats = 0, 0
	for _, entry in ipairs(SEATS) do
		local name, x, z = entry[1], entry[2], entry[3]
		local part = existingSeats[name]
		if not part then
			part = Instance.new("Part")
			part.Name = name
			part.Anchored = true
			part.Size = Vector3.new(5, 1, 5)
			part.Position = Vector3.new(x, 0.5, z)
			part.Color = Color3.fromRGB(190, 130, 60) -- orange
			part.Parent = seatsFolder
			existingSeats[name] = part
			createdSeats += 1
		end
		if ensureTag(part, SEAT_TAG) then taggedSeats += 1 end
	end

	return string.format(
		"[build_world] StreamingEnabled=true | stations: +%d new, +%d tagged | seats: +%d new, +%d tagged",
		createdStations, taggedStations, createdSeats, taggedSeats)
end

return buildWorld()
