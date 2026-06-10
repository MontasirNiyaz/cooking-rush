--!strict
-- All game-wide enum constants. Import from here; never write raw strings in systems.

export type StationArchetype   = "Cooker" | "Dispenser" | "Assembler"
export type IngredientCategory = "raw" | "intermediate" | "final" | "drink" | "topping"
export type LevelState         = "Idle" | "Intro" | "Playing" | "Results"
export type OrderState         = "Waiting" | "Ready" | "Served" | "Failed"
export type CustomerState      = "Arriving" | "Waiting" | "Served" | "Leaving" | "Angry"
export type ServeSpeed         = "fast" | "ok" | "slow"

local Enums = {
	StationArchetype = {
		Cooker    = "Cooker"    :: StationArchetype,
		Dispenser = "Dispenser" :: StationArchetype,
		Assembler = "Assembler" :: StationArchetype,
	},
	IngredientCategory = {
		Raw          = "raw"          :: IngredientCategory,
		Intermediate = "intermediate" :: IngredientCategory,
		Final        = "final"        :: IngredientCategory,
		Drink        = "drink"        :: IngredientCategory,
		Topping      = "topping"      :: IngredientCategory,
	},
	LevelState = {
		Idle    = "Idle"    :: LevelState,
		Intro   = "Intro"   :: LevelState,
		Playing = "Playing" :: LevelState,
		Results = "Results" :: LevelState,
	},
	OrderState = {
		Waiting = "Waiting" :: OrderState,
		Ready   = "Ready"   :: OrderState,
		Served  = "Served"  :: OrderState,
		Failed  = "Failed"  :: OrderState,
	},
	CustomerState = {
		Arriving = "Arriving" :: CustomerState,
		Waiting  = "Waiting"  :: CustomerState,
		Served   = "Served"   :: CustomerState,
		Leaving  = "Leaving"  :: CustomerState,
		Angry    = "Angry"    :: CustomerState,
	},
	ServeSpeed = {
		Fast = "fast" :: ServeSpeed,
		Ok   = "ok"   :: ServeSpeed,
		Slow = "slow" :: ServeSpeed,
	},
}

return Enums
