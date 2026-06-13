--!strict
-- Sakura Sushi — second restaurant. Pure data; no new engine code required.

return {
	id             = "sushi",
	displayName    = "Sakura Sushi",
	unlock         = { level = 10, coins = 2500, gems = 0 },

	stationIds     = { "fish_prep", "tuna_prep", "sushi_roller", "rice_dispenser", "soup_pot", "tea_dispenser" },
	menu           = { "salmon_nigiri", "tuna_roll", "miso_soup", "green_tea" },
	customerTypeIds = { "casual", "tourist", "critic" },

	dailyIncome    = 80,
	levelCount     = 40,

	-- Fixed in-level kitchen camera (P1.3); same framing, shifted to the Sushi
	-- kitchen (X ~34).
	camera = {
		focus  = { x = 34, y = 3, z = -3 },
		offset = { x = 0,  y = 18, z = 24 },
		fov    = 45,
	},

	levelOverrides = {
		[1]  = { tutorial = true, customerCount = 4, menuPool = { "green_tea", "salmon_nigiri" } },
		[10] = { customerCount = 8 },
		[25] = { customerCount = 14 },
		[40] = { bossRush = true, durationScale = 1.3 },
	},
}
