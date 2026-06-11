--!strict
-- Generic station entity. Behaviour is selected by config.archetype.
-- Cooker / Dispenser / Assembler — three modules cover all appliances.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RecipeResolver = require(ReplicatedStorage.Shared.Modules.RecipeResolver)
local UpgradeMath    = require(ReplicatedStorage.Shared.Modules.UpgradeMath)
local Recipes        = require(ReplicatedStorage.Shared.Config.Recipes)
local Upgrades       = require(ReplicatedStorage.Shared.Config.Upgrades)
local Signal         = require(ReplicatedStorage.Shared.Packages.Signal)
local Trove          = require(ReplicatedStorage.Shared.Packages.Trove)

export type Station = {
	id: string,
	config: any,
	archetype: string,

	-- Signals
	StateChanged: any,   -- fires(newState: string)
	ItemReady:    any,   -- fires(itemId: string, slotIndex: number)
	ItemBurnt:    any,   -- fires(slotIndex: number)

	-- Returns (outputItem?, consumed):
	--   outputItem = item the player now gains (dispensed, picked up, or assembled dish)
	--   consumed   = true when the held item was placed into the station
	interact: (self: Station, heldItemId: string?) -> (string?, boolean),
	tick:     (self: Station, dt: number) -> (),
	destroy:  (self: Station) -> (),
}

-- ── Cooker slots ─────────────────────────────────────────────────────────────

type CookerSlot = {
	item: string,           -- output item being cooked
	cookTimer: number,
	burnTimer: number,
	state: "cooking" | "done" | "burnt",
}

-- ── Station constructor ───────────────────────────────────────────────────────

local Station = {}
Station.__index = Station

function Station.new(baseConfig: any, upgradeLevel: number): Station
	local cfg = UpgradeMath.effectiveStation(baseConfig, Upgrades[baseConfig.id], upgradeLevel)
	local self = setmetatable({
		id           = cfg.id,
		config       = cfg,
		archetype    = cfg.archetype,
		_baseConfig  = baseConfig,    -- unmodified config; effective cfg is recomputed from this
		_upgradeLevel = upgradeLevel,
		_trove       = Trove.new(),

		StateChanged = Signal.new(),
		ItemReady    = Signal.new(),
		ItemBurnt    = Signal.new(),

		-- Cooker
		_slots = {} :: { CookerSlot },

		-- Dispenser
		_stock = cfg.archetype == "Dispenser" and (cfg.maxStock or 0) or 0,
		_refillAccum = 0,

		-- Assembler
		_base        = nil :: string?,
		_added       = {} :: { string },
	}, Station)
	return self :: any
end

-- Recompute the effective config from the stored base config and a new upgrade
-- level. Called when the player's upgrades change (e.g. at the start of a level
-- after a shop purchase). Dispenser stock is refilled to the new cap.
function Station:setUpgradeLevel(upgradeLevel: number)
	if upgradeLevel == self._upgradeLevel then return end
	self._upgradeLevel = upgradeLevel
	self.config = UpgradeMath.effectiveStation(self._baseConfig, Upgrades[self._baseConfig.id], upgradeLevel)
	if self.archetype == "Dispenser" then
		self._stock = self.config.maxStock or 0
		self._refillAccum = 0
	end
end

-- ── Cooker behaviour ──────────────────────────────────────────────────────────

function Station:_cookerInteract(heldItemId: string?): (string?, boolean)
	if not heldItemId then
		-- No item held → try to pick up a done item
		for i, slot in ipairs(self._slots) do
			if slot.state == "done" then
				local item = slot.item
				table.remove(self._slots, i)
				return item, false
			end
		end
		return nil, false
	end
	-- Holding an item → try to place it in a free slot
	local output = RecipeResolver.cookerOutput(self.config, heldItemId)
	if not output then return nil, false end          -- wrong ingredient
	if #self._slots >= self.config.capacity then return nil, false end  -- full
	table.insert(self._slots, {
		item = output, cookTimer = 0, burnTimer = 0, state = "cooking"
	})
	return nil, true  -- held item consumed
end

function Station:_cookerTick(dt: number)
	for i = #self._slots, 1, -1 do
		local slot = self._slots[i]
		if slot.state == "cooking" then
			slot.cookTimer += dt
			if slot.cookTimer >= self.config.cookTime then
				slot.state = "done"
				self.ItemReady:Fire(slot.item, i)
			end
		elseif slot.state == "done" then
			slot.burnTimer += dt
			if slot.burnTimer >= self.config.burnTime then
				slot.state = "burnt"
				table.remove(self._slots, i)
				self.ItemBurnt:Fire(i)
			end
		end
	end
end

-- ── Dispenser behaviour ───────────────────────────────────────────────────────

function Station:_dispenserInteract(heldItemId: string?): (string?, boolean)
	if heldItemId then return nil, false end   -- hands full
	if self._stock <= 0 then return nil, false end
	self._stock -= 1
	return self.config.produces, false
end

function Station:_dispenserTick(dt: number)
	if self._stock >= self.config.maxStock then return end
	self._refillAccum += dt
	while self._refillAccum >= self.config.refillTime and self._stock < self.config.maxStock do
		self._refillAccum -= self.config.refillTime
		self._stock += 1
	end
end

-- ── Assembler behaviour ───────────────────────────────────────────────────────

function Station:_assemblerInteract(heldItemId: string?): (string?, boolean)
	if not heldItemId then
		-- No item held → pick up finished assembly if complete
		local recipeId = RecipeResolver.findAssemblerRecipe(self._base, self._added, Recipes)
		if recipeId then
			self._base  = nil
			self._added = {}
			return recipeId, false
		end
		return nil, false
	end

	if not self._base then
		-- Place base item (consumed)
		self._base = heldItemId
		return nil, true
	end

	-- Add a topping (consumed); if this completes the recipe, auto-hand the dish back
	table.insert(self._added, heldItemId)
	local recipeId = RecipeResolver.findAssemblerRecipe(self._base, self._added, Recipes)
	if recipeId then
		self._base  = nil
		self._added = {}
		return recipeId, true  -- topping consumed, finished dish returned
	end
	return nil, true  -- topping consumed, assembly still incomplete
end

-- ── Public API ────────────────────────────────────────────────────────────────

function Station:interact(heldItemId: string?): (string?, boolean)
	if self.archetype == "Cooker"    then return self:_cookerInteract(heldItemId)    end
	if self.archetype == "Dispenser" then return self:_dispenserInteract(heldItemId) end
	if self.archetype == "Assembler" then return self:_assemblerInteract(heldItemId) end
	return nil, false
end

function Station:tick(dt: number)
	if self.archetype == "Cooker"    then self:_cookerTick(dt)    end
	if self.archetype == "Dispenser" then self:_dispenserTick(dt) end
end

function Station:destroy()
	self._trove:Destroy()
	self.StateChanged:Destroy()
	self.ItemReady:Destroy()
	self.ItemBurnt:Destroy()
end

return Station
