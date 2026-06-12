--!strict
-- Pure environment resolution for DataStore namespacing (P0.4 / ISSUES #12).
-- Keeps dev/Studio writes off production keys: the store name is prefixed by the
-- environment a place id maps to. No Roblox API; the placeId + map are injected.

local EnvConfig = {}

export type Env = "dev" | "prod"

-- Maps a place id to its environment via the GameConfig.PLACE_ENV table.
-- Any place id not explicitly listed is treated as "dev" — production must be
-- opted in, so a forgotten/new place can never write production data by default.
function EnvConfig.resolveEnv(placeId: number, placeEnvMap: { [number]: string }): Env
	local env = placeEnvMap[placeId]
	if env == "prod" then return "prod" end
	return "dev"
end

-- Namespaced store name, e.g. ("CookingRushV1", "dev") -> "dev_CookingRushV1".
function EnvConfig.storeName(baseName: string, env: Env): string
	return env .. "_" .. baseName
end

return EnvConfig
