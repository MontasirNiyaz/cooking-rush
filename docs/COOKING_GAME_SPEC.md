# Roblox "Cooking Rush" — Build Spec for Claude Code

A time-management cooking game heavily inspired by **Cooking Fever** (Nordcurrent).
This document is the authoritative build plan. Follow it top-to-bottom. The single
most important rule is in §2: **the engine is generic, the content is data.** You
should almost never write per-restaurant or per-level logic — you write systems that
read config tables.

---

## 1. Reference: what we're cloning

Core loop from Cooking Fever:

1. **Customers arrive** at tables/queue, each with a patience meter that drains over time.
2. **Order shown** — one or more menu items per customer.
3. **Prep** at stations: grill, fryer, oven, drink dispenser, assembly counter, etc.
4. **Serve** the finished dish to the right customer before patience runs out.
5. **Payment + tips** — faster service = bigger tip; consecutive clean serves = **combo multiplier**.
6. **Level ends** on a timer or when the scripted customer roster is exhausted.
7. **Stars** awarded by hitting coin thresholds (1/2/3 stars).
8. **Between levels**: spend coins/gems on equipment upgrades and new recipes.
9. **Restaurants**: each has ~40 levels, its own menu, its own station set, and unlocks via XP + currency.
10. **Two currencies**: coins (soft, earned) and gems (premium, scarce).

Levels in CF are **fixed rosters** (not random) — the same customers order the same
things in the same order. We support that, but we make it cheap (see §7 level generator).

---

## 2. Design pillars (non-negotiable)

1. **Data-driven everything.** A Restaurant, Level, Ingredient, Recipe, and Station are
   all plain Luau tables in `ReplicatedStorage/Shared/Config`. Adding content = adding a
   config entry. Adding *new mechanics* = the only time you touch engine code.
2. **Three station archetypes cover ~95% of stations** (see §6). You do NOT write a new
   class per appliance. A "Fryer" and a "Grill" are the same `Cooker` archetype with
   different data.
3. **Server-authoritative economy & saves.** The client runs the gameplay sim for
   responsiveness, but coins/gems/unlocks/level results are validated and written on the
   server. Never trust the client for currency.
4. **Composition over inheritance** for runtime entities; small modules with single
   responsibilities.
5. **Tweak-don't-fork.** New level = override a few fields on a generated baseline. New
   restaurant = one config module + an asset folder. If you find yourself copy-pasting a
   system, stop and parameterize it instead.

---

## 3. Tech stack & tooling

- **Language:** Luau.
- **Sync:** **Rojo** — this project lives on the filesystem (that's how you, Claude Code,
  edit it). Set up `default.project.json` mapping `src/` into the DataModel. The developer
  runs `rojo serve` and connects from Studio.
- **No heavy framework required.** Use a lightweight service/controller pattern (hand-rolled
  or Knit-style). If you pull in a library, prefer well-known single-file modules:
  `Signal`, `Promise`, `Trove`/`Maid` for cleanup. Keep dependencies minimal and vendored
  under `Shared/Packages`.
- **Persistence:** `DataStoreService`, wrapped in a session-locked profile module
  (ProfileService-style pattern; you may vendor ProfileService).
- **Testing:** a `tests/` folder with TestEZ specs for the pure-logic modules (recipe
  resolution, economy math, level generation, star calc). These must run without a live
  game session.

---

## 4. Repository / DataModel layout

```
cooking-rush/
├── default.project.json
├── README.md
├── src/
│   ├── ReplicatedStorage/
│   │   └── Shared/
│   │       ├── Config/
│   │       │   ├── GameConfig.lua          -- global tuning constants
│   │       │   ├── Ingredients.lua         -- every raw/intermediate/final item
│   │       │   ├── Recipes.lua             -- how items combine into dishes
│   │       │   ├── Stations.lua            -- station archetype instances (data)
│   │       │   ├── Customers.lua           -- customer archetypes (patience, sprites, tip curve)
│   │       │   ├── Upgrades.lua            -- upgrade trees keyed by station/recipe id
│   │       │   └── Restaurants/
│   │       │       ├── init.lua            -- registry: requires every restaurant module
│   │       │       ├── FastFood.lua
│   │       │       ├── Sushi.lua
│   │       │       └── ...                 -- one module per restaurant
│   │       ├── Modules/                    -- pure shared logic (no side effects)
│   │       │   ├── RecipeResolver.lua
│   │       │   ├── LevelGenerator.lua
│   │       │   ├── EconomyMath.lua          -- tip/combo/star calculations
│   │       │   ├── Schema.lua               -- runtime validation of config tables
│   │       │   └── Enums.lua
│   │       ├── Packages/                    -- vendored libs (Signal, Promise, Trove...)
│   │       └── Remotes.lua                  -- defines/creates all RemoteEvents/Functions
│   ├── ServerScriptService/
│   │   └── Server/
│   │       ├── init.server.lua              -- bootstraps services in dependency order
│   │       └── Services/
│   │           ├── DataService.lua          -- profile load/save, session lock
│   │           ├── EconomyService.lua       -- authoritative coins/gems
│   │           ├── ProgressionService.lua   -- XP, restaurant/level unlocks
│   │           ├── UpgradeService.lua       -- purchase + persist upgrades
│   │           └── LevelService.lua         -- receive level result, validate, reward
│   └── StarterPlayer/
│       └── StarterPlayerScripts/
│           └── Client/
│               ├── init.client.lua          -- bootstraps controllers
│               ├── Controllers/
│               │   ├── LevelController.lua   -- owns the active-level state machine
│               │   ├── StationController.lua -- input → station archetype behavior
│               │   ├── CustomerController.lua-- spawns/ticks customers from level data
│               │   ├── OrderController.lua   -- order matching + serve validation
│               │   ├── ComboController.lua   -- combo streak + multiplier
│               │   └── UIController.lua      -- routes UI state, no game logic
│               └── Entities/                 -- runtime, composable
│                   ├── Station.lua           -- generic; behavior chosen by archetype
│                   ├── ItemStack.lua
│                   ├── Customer.lua
│                   └── Order.lua
└── tests/
    ├── RecipeResolver.spec.lua
    ├── EconomyMath.spec.lua
    └── LevelGenerator.spec.lua
```

---

## 5. Data schemas (the heart of the project)

Define these as typed Luau tables. Add a `Schema.lua` validator that asserts every config
entry matches its shape on server boot — this catches content bugs immediately. Use
`--!strict` and Luau type annotations throughout.

### 5.1 Ingredient (`Ingredients.lua`)
```lua
type Ingredient = {
    id: string,            -- "raw_patty"
    displayName: string,
    icon: string,          -- asset id
    category: "raw" | "intermediate" | "final" | "drink" | "topping",
}
```

### 5.2 Station (`Stations.lua`)
The archetype is the whole trick. See §6 for behavior.
```lua
type Station = {
    id: string,                 -- "grill"
    displayName: string,
    archetype: "Cooker" | "Dispenser" | "Assembler",
    capacity: number,           -- simultaneous slots
    -- Cooker fields:
    input: string?,             -- ingredient id consumed
    output: string?,            -- ingredient id produced
    cookTime: number?,          -- sec to "done"
    burnTime: number?,          -- sec after done until wasted
    -- Dispenser fields:
    produces: string?,          -- ingredient id
    refillTime: number?,        -- sec to regenerate one unit
    maxStock: number?,
    -- Assembler fields handled by recipe (see Recipe.steps)
    upgradeTreeId: string?,     -- key into Upgrades.lua
}
```

### 5.3 Recipe (`Recipes.lua`)
A recipe is an ordered/option set of steps that yields a `final` item.
```lua
type RecipeStep =
    { kind: "cook", station: string, item: string }       -- needs a Cooker output
  | { kind: "dispense", station: string, item: string }   -- needs a Dispenser item
  | { kind: "assemble", base: string, add: {string} }      -- Assembler: base + toppings

type Recipe = {
    id: string,                 -- "cheeseburger"
    displayName: string,
    icon: string,
    steps: {RecipeStep},
    basePrice: number,          -- coins before tip/combo
    prepHintSeconds: number,    -- used by generator to estimate difficulty
}
```

### 5.4 Customer archetype (`Customers.lua`)
```lua
type CustomerType = {
    id: string,
    sprites: {string},
    basePatience: number,       -- seconds, scaled per level
    tipCurve: { fast: number, ok: number, slow: number }, -- multipliers vs basePrice
}
```

### 5.5 Restaurant (`Restaurants/<Name>.lua`)
This is ALL that defines a restaurant. No restaurant-specific scripts anywhere else.
```lua
return {
    id = "fastfood",
    displayName = "Fast Food Court",
    unlock = { level = 1, coins = 0, gems = 0 },   -- progression gate
    stationIds = { "grill", "drink_dispenser", "bun_counter", "fryer" },
    menu = { "cheeseburger", "fries", "cola" },     -- recipe ids available here
    customerTypeIds = { "casual", "hurried", "family" },
    dailyIncome = 50,
    -- Levels: either authored or generated. Prefer generated (see §7).
    levelCount = 40,
    levelOverrides = {            -- sparse: only levels that deviate from the curve
        [1] = { tutorial = true, customerCount = 4 },
        [40] = { bossRush = true, durationScale = 1.2 },
    },
}
```

### 5.6 Level (resolved at runtime, never hand-authored in full)
```lua
type SpawnEntry = {
    atSecond: number,
    customerTypeId: string,
    orders: {string},          -- recipe ids
    patienceScale: number,
}
type Level = {
    restaurantId: string,
    index: number,
    duration: number,          -- 0 = until roster exhausted
    spawns: {SpawnEntry},
    goals: { oneStar: number, twoStar: number, threeStar: number }, -- coin thresholds
}
```

---

## 6. Station archetype system (key abstraction)

There is **one** `Station.lua` entity. Its behavior is selected by `archetype`. Implement
each archetype as a small strategy module the entity delegates to:

- **Cooker** — `place(item)` puts a unit in a slot → after `cookTime` it's *done* (servable)
  → after `cookTime + burnTime` it's *burnt* (auto-cleared, counts as waste). Grill, fryer,
  oven, pot, coffee machine-with-timing all use this. Differences are pure data.
- **Dispenser** — auto-refills `produces` up to `maxStock` every `refillTime`; `take()`
  pulls one ready unit. Soda fountain, pre-made sides.
- **Assembler** — holds a `base` then accepts `add` toppings until it matches a recipe's
  `assemble` step, producing the `final` item. Burger build counter, sushi roll, pizza.

Adding a new appliance that fits these = a `Stations.lua` entry, zero code. Only a genuinely
novel mechanic (e.g., a station that needs stirring mini-game) justifies a 4th archetype —
and even then you add an archetype, not a per-station script.

`StationController` maps player input to `Station:interact()`; the archetype decides what
that means. Keep all timing on the client sim but report only **outcomes** (dish served,
waste) to the server.

---

## 7. Level generation (scalability centerpiece)

This is the "starter code with slight tweaks" the design calls for. **Do not author 40
spawn tables per restaurant by hand.** Instead:

`LevelGenerator.generate(restaurant, index) -> Level`

Algorithm:
1. Compute a **difficulty scalar** `d` from `index` (e.g. eased curve 0→1 across `levelCount`).
2. Derive parameters from `d`:
   - `customerCount = lerp(4, 18, d)`
   - `spawnDensity` (gap between arrivals shrinks as `d` rises)
   - `maxOrdersPerCustomer = 1 + floor(d * 2)`
   - `patienceScale = lerp(1.3, 0.8, d)`
   - menu pool = `restaurant.menu` (optionally widen as `d` rises)
3. Build `spawns` by sampling customer types and orders from the pools with a **seeded RNG**
   (`Random.new(restaurantHash + index)`) so a given level is deterministic and replayable —
   matching CF's fixed-roster feel without hand authoring.
4. Compute `goals` from expected earnings: estimate achievable coins from order prices ×
   count × tip assumptions; set 1/2/3-star thresholds as fractions of that.
5. **Apply `levelOverrides[index]`** last — shallow-merge any authored deviations (tutorials,
   boss levels, set-piece rosters). This is the "slight tweak" path.

Result: a brand-new restaurant with 40 tuned levels comes from ONE config file. Authored
levels remain possible but are the exception, not the rule.

Keep `LevelGenerator` **pure** (config in → Level table out, no Roblox API) so it's unit-tested.

---

## 8. Economy, scoring & stars (`EconomyMath.lua`)

Pure module, unit-tested. Functions:
- `serveValue(recipe, serveSpeed, comboMultiplier) -> coins` — basePrice × tipMultiplier
  (from `serveSpeed` bucket) × combo.
- `comboMultiplier(streak) -> number` — e.g. 1.0, 1.1, 1.25, 1.5 capped; resets on a missed
  customer or wrong dish.
- `starsFor(coinsEarned, goals) -> 0|1|2|3`.
- `levelReward(stars, coinsEarned) -> { coins, gems, xp }` — gems only on first-time
  3-star or milestones (keep gems scarce, like CF).

Currency rules: coins fund most upgrades and new recipes; gems gate premium restaurants and
a few power upgrades. EconomyService is the only writer of currency.

---

## 9. Progression & upgrades

- **ProgressionService**: tracks XP, current restaurant/level unlock state. A restaurant
  unlocks when `playerLevel >= unlock.level` and the player pays `unlock.coins/gems`.
- **UpgradeService**: `Upgrades.lua` defines per-station/recipe upgrade trees
  (`{ level, cost, effect = { field = "cookTime", mult = 0.85 } }`). Upgrades are stored on
  the profile and applied as **modifiers** over base `Stations.lua` data at level start —
  never mutate the base config.
- Daily login reward + per-restaurant passive `dailyIncome` (CF parity), granted by a server
  routine using profile timestamps.

---

## 10. Persistence (`DataService.lua`)

Profile schema (session-locked, autosave + on-leave save):
```lua
{
    coins = 0, gems = 0, xp = 0,
    unlockedRestaurants = { fastfood = true },
    levelStars = { ["fastfood:1"] = 3, ... },   -- best stars per level
    upgrades = { ["grill"] = 2, ["fryer"] = 1, ... },
    lastDailyClaim = 0, lastIncomeClaim = {},
    version = 1,                                  -- migrate on schema bumps
}
```
Use a reconciliation step so new fields get defaults; keep a `version` + migration table.

---

## 11. UI (`UIController.lua` + UI modules)

UI is **state-driven and dumb** — it renders state the controllers own, emits intents back.
Screens: Main Menu → World/Restaurant Map → Level Select → In-Level HUD (orders, timer,
coin counter, combo) → Results (stars, rewards) → Upgrade/Shop. Build the in-level HUD to
read entirely from `LevelController` state so it works for every restaurant unchanged.
Mobile-first: large touch targets, since the genre is mobile.

---

## 12. Networking (`Remotes.lua`)

Minimal surface, all server-validated:
- `RequestLevelStart(restaurantId, index)` → server checks unlock, returns resolved `Level`.
- `SubmitLevelResult(payload)` → server **re-validates plausibility** (coins ≤ theoretical
  max for that level, time sane) before awarding. Reject impossible results.
- `PurchaseUpgrade(id)`, `UnlockRestaurant(id)`, `ClaimDaily()` → all economy writes.
Never send raw currency from client; send intents, let the server compute deltas.

---

## 13. Build order (milestones for Claude Code)

Work in vertical slices; each milestone should be runnable.

- **M0 — Skeleton:** Rojo project, folder tree, `Remotes`, service/controller bootstraps,
  empty `Schema` validator passing. Game boots, no gameplay.
- **M1 — One station, one dish:** `Cooker` archetype + `Assembler` + `Dispenser`, hardcode
  the FastFood config (cheeseburger/fries/cola), serve to a single static customer. Prove
  the archetype model end-to-end on the client.
- **M2 — Level loop:** `LevelController` state machine (intro → playing → results), customer
  spawning from a *static* spawn list, patience meters, serve matching, combo, timer, stars.
- **M3 — Generator:** replace static spawns with `LevelGenerator`; generate FastFood's 40
  levels from config; tune the difficulty curve. Unit tests for generator + economy.
- **M4 — Economy & persistence:** EconomyService + DataService (DataStore profiles),
  SubmitLevelResult validation, star/coin saving, daily reward.
- **M5 — Progression & upgrades:** ProgressionService unlocks, UpgradeService trees applied
  as modifiers, Upgrade/Shop UI.
- **M6 — Second restaurant (the proof):** add `Sushi.lua` — a new config file + assets ONLY.
  If it requires engine changes, the abstraction failed; fix the engine, not the content.
- **M7 — Polish:** sounds, juice, mobile tuning, more restaurants as pure data.

The success test for the whole architecture: **M6 ships a full 40-level restaurant with no
new Luau logic.** Optimize every earlier decision toward making that true.

---

## 14. Conventions & guardrails

- `--!strict` everywhere; annotate config types and export them from `Enums.lua`/`Schema.lua`.
- No magic numbers in systems — they live in `GameConfig.lua` or the relevant config table.
- Entities clean up via `Trove`/`Maid`; no leaked connections between levels.
- Pure logic (resolver, generator, economy) must be free of Roblox APIs and unit-tested.
- Client owns the sim for feel; server owns truth for money. When in doubt, validate server-side.
- Before adding any per-restaurant or per-level code path, ask: "can this be a config field or
  an override instead?" The answer is almost always yes.
- Commit per milestone with a short note on what's runnable.
