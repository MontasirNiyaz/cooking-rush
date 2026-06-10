--!strict
-- Fast Food Court — the starter restaurant (always unlocked).
-- Adding a new restaurant = copying this file and changing values. Zero engine code.

return {
	id             = "fastfood",
	displayName    = "Fast Food Court",
	unlock         = { level = 1, coins = 0, gems = 0 },

	stationIds     = { "grill", "fryer", "bun_counter", "drink_dispenser" },
	menu           = { "cheeseburger", "fries", "cola" },
	customerTypeIds = { "casual", "hurried", "family" },

	dailyIncome    = 50,
	levelCount     = 40,

	-- Authored deviations from the generated curve (sparse overrides).
	levelOverrides = {
		[1] = { tutorial = true, customerCount = 4, menuPool = { "cola", "fries" } },
		[5] = { customerCount = 6 },
		[20] = { customerCount = 12 },
		[40] = { bossRush = true, durationScale = 1.2 },
	},
}
