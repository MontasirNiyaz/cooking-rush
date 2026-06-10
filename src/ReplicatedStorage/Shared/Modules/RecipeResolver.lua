--!strict
-- Pure recipe logic. No Roblox API. Inject config as arguments for unit-test isolation.
--
-- Concepts:
--   ItemBag = {[ingredientId]: count}  — what the player is currently holding
--   An order is a recipe id. Delivering the recipe.id item (final/drink) fulfils it.

local RecipeResolver = {}

export type ItemBag = { [string]: number }

-- Returns true if the item the player is holding satisfies the order (recipe).
-- Simple: orders are fulfilled by delivering exactly recipe.id.
function RecipeResolver.itemFulfillsOrder(heldItemId: string, recipeId: string): boolean
	return heldItemId == recipeId
end

-- Returns the complete list of ingredient ids a recipe requires across all steps.
function RecipeResolver.getRequiredItems(recipe: any): { string }
	local items: { string } = {}
	for _, step in ipairs(recipe.steps) do
		if step.kind == "cook" or step.kind == "dispense" then
			table.insert(items, step.item)
		elseif step.kind == "assemble" then
			table.insert(items, step.base)
			for _, add in ipairs(step.add) do
				table.insert(items, add)
			end
		end
	end
	return items
end

-- Returns the station id responsible for each step, in order.
function RecipeResolver.getStepStations(recipe: any): { string? }
	local stations: { string? } = {}
	for _, step in ipairs(recipe.steps) do
		if step.kind == "cook" or step.kind == "dispense" then
			table.insert(stations, step.station)
		elseif step.kind == "assemble" then
			table.insert(stations, nil) -- assembler is chosen by proximity in-game
		end
	end
	return stations
end

-- Returns true if the assembler's current contents (base + toppings added so far)
-- match the assemble step of the given recipe.
function RecipeResolver.assemblerMatchesRecipe(
	recipe: any,
	baseItem: string?,
	addedItems: { string }
): boolean
	local assembleStep: any = nil
	for _, step in ipairs(recipe.steps) do
		if step.kind == "assemble" then
			assembleStep = step
			break
		end
	end
	if not assembleStep then return false end

	if baseItem ~= assembleStep.base then return false end
	if #addedItems ~= #assembleStep.add then return false end

	-- Order-insensitive match for the add items
	local needed: { [string]: number } = {}
	for _, item in ipairs(assembleStep.add) do
		needed[item] = (needed[item] or 0) + 1
	end
	for _, item in ipairs(addedItems) do
		if not needed[item] or needed[item] == 0 then return false end
		needed[item] -= 1
	end
	return true
end

-- Given a set of items on an assembler, returns the first matching recipe id or nil.
function RecipeResolver.findAssemblerRecipe(
	baseItem: string?,
	addedItems: { string },
	recipes: { [string]: any }
): string?
	for id, recipe in pairs(recipes) do
		if RecipeResolver.assemblerMatchesRecipe(recipe, baseItem, addedItems) then
			return id
		end
	end
	return nil
end

-- Given a Cooker station config and the item placed, returns the output item id.
-- Returns nil if the placed item doesn't match the station's expected input.
function RecipeResolver.cookerOutput(stationConfig: any, placedItemId: string): string?
	if stationConfig.input == placedItemId then
		return stationConfig.output
	end
	return nil
end

return RecipeResolver
