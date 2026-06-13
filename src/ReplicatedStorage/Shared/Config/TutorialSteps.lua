--!strict
-- Onboarding tutorial steps (P1.2). Pure data — the TutorialController is a
-- generic engine that runs ANY sequence defined here; teaching content is config.
--
-- Each step:
--   id          unique string.
--   trigger     when the step becomes active:
--                 { kind = "levelStart" }            — when the level starts Playing
--                 { kind = "afterStep", step = id }  — when another step completes
--   highlight   what to point at (the controller resolves it to a world Part):
--                 { kind = "station", id = "<stationId>" }  — the tagged station Part
--                 { kind = "occupiedSeat" }                 — a seat with a customer
--                 { kind = "none" }
--   promptText  one short, non-blocking instruction line.
--   completeOn  how the step is satisfied (observed from existing gameplay signals):
--                 { kind = "hold", item = "<ingredientId>" }  — player holds item
--                 { kind = "produce", station = "<stationId>" }— station output ready
--                 { kind = "serve" }                          — a customer served
--                 { kind = "interactAny" }                    — any station interaction
--                 { kind = "timer", seconds = n }             — after a delay
--
-- Steps never block input: they only add a highlight + a hint label. Ignoring a
-- prompt cannot soft-lock — there is no gating on completion.

export type TutorialTrigger =
	{ kind: "levelStart" }
	| { kind: "afterStep", step: string }

export type TutorialHighlight =
	{ kind: "station", id: string }
	| { kind: "occupiedSeat" }
	| { kind: "none" }

export type TutorialComplete =
	{ kind: "hold", item: string }
	| { kind: "produce", station: string }
	| { kind: "serve" }
	| { kind: "interactAny" }
	| { kind: "timer", seconds: number }

export type TutorialStep = {
	id: string,
	trigger: TutorialTrigger,
	highlight: TutorialHighlight,
	promptText: string,
	completeOn: TutorialComplete,
}

-- The starter sequence teaches the core loop on FastFood level 1 (menu: cola/fries):
-- grab a Cola, then serve the waiting customer. Two interactions, well under 15s.
local TutorialSteps: { TutorialStep } = {
	{
		id         = "grab_drink",
		trigger    = { kind = "levelStart" },
		highlight  = { kind = "station", id = "drink_dispenser" },
		promptText = "Tap the drink machine to grab a Cola",
		completeOn = { kind = "hold", item = "cola" },
	},
	{
		id         = "serve_customer",
		trigger    = { kind = "afterStep", step = "grab_drink" },
		highlight  = { kind = "occupiedSeat" },
		promptText = "Carry it to the waiting customer and serve",
		completeOn = { kind = "serve" },
	},
	{
		id         = "free_play",
		trigger    = { kind = "afterStep", step = "serve_customer" },
		highlight  = { kind = "none" },
		promptText = "Nice! Keep serving customers before their patience runs out.",
		completeOn = { kind = "timer", seconds = 4 },
	},
}

return TutorialSteps
