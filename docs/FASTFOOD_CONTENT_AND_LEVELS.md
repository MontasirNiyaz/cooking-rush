# FastFood Court — Concrete Content & Level Design

Companion to `COOKING_GAME_SPEC.md`. This is the **content layer** for restaurant #1:
real ingredients, recipes, stations, customers, generator tuning, and a set of fully
specified levels. Drop these values straight into the `Config/` modules.

Conventions: times in **seconds**, prices in **coins**. These are starting balance values —
all of them live in config so they're tunable without code changes.

---

## 1. Ingredients (`Ingredients.lua`)

| id | displayName | category |
|---|---|---|
| `raw_patty` | Raw Patty | raw |
| `cooked_patty` | Cooked Patty | intermediate |
| `bun` | Bun | raw |
| `cheese` | Cheese Slice | topping |
| `lettuce` | Lettuce | topping |
| `tomato` | Tomato | topping |
| `raw_fries` | Raw Fries | raw |
| `cooked_fries` | Fries | final |
| `cola` | Cola | drink |
| `orange` | Orange Soda | drink |

---

## 2. Stations (`Stations.lua`)

| id | archetype | capacity | key timings | notes |
|---|---|---|---|---|
| `grill` | Cooker | 4 | cookTime 4, burnTime 5 | `raw_patty` → `cooked_patty` |
| `fryer` | Cooker | 2 | cookTime 6, burnTime 6 | `raw_fries` → `cooked_fries` |
| `assembler` | Assembler | 3 | — | holds `bun`, accepts toppings |
| `soda_fountain` | Dispenser | — | refillTime 3, maxStock 4 | **multi-output**, see below |

```lua
grill = {
    id = "grill", displayName = "Grill", archetype = "Cooker",
    capacity = 4, input = "raw_patty", output = "cooked_patty",
    cookTime = 4, burnTime = 5, upgradeTreeId = "grill_speed",
},
fryer = {
    id = "fryer", displayName = "Fryer", archetype = "Cooker",
    capacity = 2, input = "raw_fries", output = "cooked_fries",
    cookTime = 6, burnTime = 6, upgradeTreeId = "fryer_speed",
},
assembler = {
    id = "assembler", displayName = "Prep Counter", archetype = "Assembler",
    capacity = 3,
},
soda_fountain = {
    id = "soda_fountain", displayName = "Soda Fountain", archetype = "Dispenser",
    outputs = { "cola", "orange" },   -- see schema note
    refillTime = 3, maxStock = 4, upgradeTreeId = "soda_capacity",
},
```

> **One deliberate schema extension.** The original `Dispenser` had a single `produces`.
> Real fast-food soda machines pour multiple drinks, and coffee/dessert machines later will
> too. Change `produces: string` → `outputs: {string}`, with independent ready-stock per
> output. This is a ~10-line change to the Dispenser archetype, done **once**, and every
> future multi-output machine becomes pure data. This is the only engine touch this content
> requires — exactly the "new mechanic → touch engine minimally" rule from the spec.

---

## 3. Recipes (`Recipes.lua`)

| id | basePrice | prepHint (s) | steps |
|---|---|---|---|
| `plain_burger` | 16 | 5 | cook patty → assemble bun+patty |
| `cheeseburger` | 22 | 6 | cook patty → assemble bun+patty+cheese |
| `deluxe_burger` | 32 | 9 | cook patty → assemble bun+patty+cheese+lettuce+tomato |
| `fries` | 12 | 6 | cook fries |
| `cola` | 7 | 1 | dispense cola |
| `orange` | 7 | 1 | dispense orange |

```lua
cheeseburger = {
    id = "cheeseburger", displayName = "Cheeseburger", basePrice = 22, prepHintSeconds = 6,
    steps = {
        { kind = "cook", station = "grill", item = "cooked_patty" },
        { kind = "assemble", base = "bun", add = { "cooked_patty", "cheese" } },
    },
},
fries = {
    id = "fries", displayName = "Fries", basePrice = 12, prepHintSeconds = 6,
    steps = { { kind = "cook", station = "fryer", item = "cooked_fries" } },
},
cola = {
    id = "cola", displayName = "Cola", basePrice = 7, prepHintSeconds = 1,
    steps = { { kind = "dispense", station = "soda_fountain", item = "cola" } },
},
```

---

## 4. Customer types (`Customers.lua`)

| id | basePatience (s) | tipCurve {fast / ok / slow} | behavior |
|---|---|---|---|
| `casual` | 35 | 1.30 / 1.10 / 1.00 | default, forgiving, tips well |
| `hurried` | 22 | 1.20 / 1.00 / 0.90 | short fuse, single orders |
| `family` | 32 | 1.25 / 1.05 / 1.00 | always 2–3 orders |

`tipCurve` multiplies `basePrice`. Serve-speed buckets (share with `EconomyMath`):
fast = served with >60% patience left, ok = 30–60%, slow = <30%.

---

## 5. Upgrade trees (`Upgrades.lua`) — examples

```lua
grill_speed = {
    { level = 1, cost = { coins = 250 },  effect = { field = "cookTime", mult = 0.90 } },
    { level = 2, cost = { coins = 600 },  effect = { field = "cookTime", mult = 0.82 } },
    { level = 3, cost = { coins = 1500 }, effect = { field = "capacity", add = 1 } },
},
soda_capacity = {
    { level = 1, cost = { coins = 200 },  effect = { field = "maxStock", add = 2 } },
    { level = 2, cost = { coins = 500 },  effect = { field = "refillTime", mult = 0.80 } },
},
```
Applied as modifiers over base station data at level start — never mutate base config.

---

## 6. Generator tuning (`LevelGenerator`, FastFood curve)

Concrete constants. `levelCount = 40`, so `d = (index - 1) / 39` (linear; swap the easing
function here later without touching callers).

```lua
customerCount      = round( lerp(4, 18, d) )
spawnGapSeconds    = lerp(4.5, 1.8, d)          -- gap between arrivals
maxOrdersPerCust   = 1 + floor(d * 2)            -- 1 → 3
patienceScale      = lerp(1.30, 0.85, d)         -- multiplies basePatience
```

Menu pool **widens with progress** (don't dump the full menu on level 1):

| level range | recipe pool | customer types |
|---|---|---|
| 1–3 | tutorial-locked (see §7) | casual |
| 4–9 | plain_burger, cheeseburger, fries, cola | casual |
| 10–24 | + deluxe_burger, orange | casual, hurried |
| 25–40 | full menu | casual, hurried, family |

Star goals from expected earnings. Let `E = expectedCoins` (sum of sampled order prices ×
avg tip 1.12). Then:

```lua
goals = { oneStar = round(E * 0.65), twoStar = round(E * 0.82), threeStar = round(E * 0.97) }
```

Seed the RNG with `Random.new(hash("fastfood") + index)` so each level is deterministic and
replayable — Cooking Fever's fixed-roster feel, for free.

---

## 7. The levels

Three authored set-pieces (tutorial 1–3), three golden references (the generator's expected
output — write tests asserting equality), one authored boss (40).

### Level 1 — "First Shift" (AUTHORED tutorial)
Teaches: grill a patty, assemble a burger, serve. One dish only.
```lua
[1] = {
    tutorial = true, restaurantId = "fastfood", index = 1, duration = 0,
    menuLock = { "plain_burger" },
    spawns = {
        { atSecond = 2,  customerTypeId = "casual", orders = {"plain_burger"}, patienceScale = 1.6 },
        { atSecond = 10, customerTypeId = "casual", orders = {"plain_burger"}, patienceScale = 1.6 },
        { atSecond = 20, customerTypeId = "casual", orders = {"plain_burger"}, patienceScale = 1.6 },
        { atSecond = 32, customerTypeId = "casual", orders = {"plain_burger"}, patienceScale = 1.6 },
    },
    goals = { oneStar = 40, twoStar = 55, threeStar = 64 },
}
```

### Level 2 — "Cheese, Please" (AUTHORED)
Introduces cheese + cheeseburger + drinks.
```lua
[2] = {
    tutorial = true, restaurantId = "fastfood", index = 2, duration = 0,
    menuLock = { "plain_burger", "cheeseburger", "cola" },
    spawns = {  -- 5 customers, some 2-item orders
        { atSecond = 2,  customerTypeId = "casual", orders = {"cheeseburger"},          patienceScale = 1.5 },
        { atSecond = 9,  customerTypeId = "casual", orders = {"plain_burger", "cola"},   patienceScale = 1.5 },
        { atSecond = 17, customerTypeId = "casual", orders = {"cheeseburger", "cola"},   patienceScale = 1.5 },
        { atSecond = 26, customerTypeId = "casual", orders = {"cheeseburger"},          patienceScale = 1.5 },
        { atSecond = 35, customerTypeId = "casual", orders = {"plain_burger", "cola"},   patienceScale = 1.5 },
    },
    goals = { oneStar = 75, twoStar = 100, threeStar = 120 },
}
```

### Level 3 — "Fry Cook" (AUTHORED)
Introduces the fryer + fries. Last tutorial; slightly tighter patience.
```lua
[3] = {
    tutorial = true, restaurantId = "fastfood", index = 3, duration = 0,
    menuLock = { "plain_burger", "cheeseburger", "fries", "cola" },
    spawns = {  -- 6 customers
        { atSecond = 2,  customerTypeId = "casual", orders = {"cheeseburger", "fries"},        patienceScale = 1.4 },
        { atSecond = 8,  customerTypeId = "casual", orders = {"fries", "cola"},                 patienceScale = 1.4 },
        { atSecond = 15, customerTypeId = "casual", orders = {"cheeseburger", "fries", "cola"}, patienceScale = 1.4 },
        { atSecond = 23, customerTypeId = "casual", orders = {"plain_burger", "fries"},         patienceScale = 1.4 },
        { atSecond = 31, customerTypeId = "casual", orders = {"cheeseburger", "cola"},          patienceScale = 1.4 },
        { atSecond = 40, customerTypeId = "casual", orders = {"fries", "fries"},                patienceScale = 1.4 },
    },
    goals = { oneStar = 110, twoStar = 145, threeStar = 170 },
}
```

### Level 4 — "Open Floor" (GOLDEN — generator output, d = 0.077)
First fully generated level. This is the **test target**: `LevelGenerator.generate(fastfood, 4)`
must produce this (modulo the seeded sampling — pin the seed in the test).
Resolved params: `customerCount = 5`, `spawnGap ≈ 4.3s`, `maxOrders = 1`, `patienceScale ≈ 1.27`.
```lua
-- expected resolved Level (golden):
{
    restaurantId = "fastfood", index = 4, duration = 0,
    spawns = {
        { atSecond = 2,    customerTypeId = "casual", orders = {"cheeseburger"}, patienceScale = 1.27 },
        { atSecond = 6.3,  customerTypeId = "casual", orders = {"cola"},         patienceScale = 1.27 },
        { atSecond = 10.6, customerTypeId = "casual", orders = {"plain_burger"}, patienceScale = 1.27 },
        { atSecond = 14.9, customerTypeId = "casual", orders = {"fries"},        patienceScale = 1.27 },
        { atSecond = 19.2, customerTypeId = "casual", orders = {"cheeseburger"}, patienceScale = 1.27 },
    },
    goals = { oneStar = 52, twoStar = 65, threeStar = 77 },
}
```

### Level 10 — "Lunch Rush" (GOLDEN, d = 0.231)
`customerCount = 7`, `spawnGap ≈ 3.7s`, `maxOrders = 1` (floor(0.46)=0 → 1), `patienceScale ≈ 1.20`.
Pool now includes `deluxe_burger`, `orange`; `hurried` customers appear.
```lua
{
    restaurantId = "fastfood", index = 10, duration = 0,
    spawns = {
        { atSecond = 2,    customerTypeId = "casual",  orders = {"deluxe_burger"}, patienceScale = 1.20 },
        { atSecond = 5.7,  customerTypeId = "hurried", orders = {"cola"},          patienceScale = 1.20 },
        { atSecond = 9.4,  customerTypeId = "casual",  orders = {"cheeseburger"},  patienceScale = 1.20 },
        { atSecond = 13.1, customerTypeId = "hurried", orders = {"fries"},         patienceScale = 1.20 },
        { atSecond = 16.8, customerTypeId = "casual",  orders = {"deluxe_burger"}, patienceScale = 1.20 },
        { atSecond = 20.5, customerTypeId = "casual",  orders = {"orange"},        patienceScale = 1.20 },
        { atSecond = 24.2, customerTypeId = "hurried", orders = {"cheeseburger"},  patienceScale = 1.20 },
    },
    goals = { oneStar = 90, twoStar = 113, threeStar = 134 },
}
```

### Level 20 — "Double Trouble" (GOLDEN, d = 0.487)
`customerCount = 11`, `spawnGap ≈ 3.1s`, `maxOrders = 1 + floor(0.97) = 1`… nudges toward 2 at
the next band, `patienceScale ≈ 1.08`. `family` customers (2–3 orders) now in the pool — this
is where multi-item orders stack up. (Roster omitted for length; generate and pin as golden.)
```lua
{
    restaurantId = "fastfood", index = 20, duration = 0,
    -- 11 customers, ~3.1s gaps, mix of casual/hurried/family, full pre-boss menu
    goals = { oneStar = 175, twoStar = 221, threeStar = 261 },
}
```

### Level 40 — "Grand Opening Finale" (AUTHORED boss)
Caps the restaurant. Max density, full menu, heavy deluxe + family orders, tight patience,
`durationScale = 1.2` so the round runs longer under sustained pressure. Hand-authored
because set-piece pacing (a mid-round breather, then a final surge) reads better than the
generator's even distribution.
```lua
[40] = {
    boss = true, restaurantId = "fastfood", index = 40, durationScale = 1.2,
    -- ~18 customers; authored 3-phase pacing: ramp (1–8), breather (9–11), surge (12–18)
    -- heavy on deluxe_burger + family multi-orders; patienceScale ≈ 0.82
    goals = { oneStar = 420, twoStar = 530, threeStar = 620 },
}
```

---

## 8. How Claude Code should use this

1. Write §1–§5 into the `Config/` modules verbatim; run `Schema.lua` validation on boot.
2. Apply the §2 multi-output Dispenser schema change (once).
3. Set the §6 constants in `LevelGenerator` and the FastFood config.
4. Add levels 1–3 and 40 to `FastFood.levelOverrides`.
5. Add **golden tests**: assert `LevelGenerator.generate(fastfood, n)` for n ∈ {4, 10, 20}
   equals the pinned rosters above (seed the RNG in-test). These tests are how you'll catch
   any future generator regression.
6. Playtest levels 1–4 end to end; tune the curve constants (not code) until level 4 feels
   like the "farming sweet spot" the genre rewards.

Once this proves out, a second restaurant (Sushi, etc.) is the same exercise: one content
file of real numbers + curve constants. No new systems.
