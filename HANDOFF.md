# Cooking Rush — Handoff Document

## Goal

Build a Roblox cooking game ("Cooking Rush") using a data-driven architecture where adding a new restaurant requires only a config file — zero engine code changes. Proving this with FastFood (shipped) and Sushi (M6 config-only milestone).

---

## Current Progress

| Milestone | Status |
|-----------|--------|
| M0 — Project skeleton, config, pure logic, server/client stubs | **Complete** |
| M1 — Station archetypes, 3D interaction, serve a cheeseburger | **Complete** (code + world) |
| M2 — Full level loop, patience meters, combo, timer, stars | **Complete** |
| M3 — LevelGenerator → LevelController, unit tests | **Complete** |
| M4 — DataStore profiles, SubmitLevelResult server validation | **Complete** |
| M5 — ProgressionService, UpgradeService, Shop UI | **Complete** |
| M6 — Sushi restaurant (config-only) | **Complete** |
| M7 — Meta-progression spine: Recipe Mastery + Restaurant Prestige | **Complete** (code + unit tests + Studio verification) |
| M8 — Chef Collection & Recruitment (gacha, equip, fusion, passives) | **Complete** (code + 31 new specs + Studio integration verified) |
| M9 — Idle / Passive Empire (offline accrual, chef assignment, gem cap) | **Complete** (code + 13 new specs + Studio integration verified) |

---

## Architecture Overview

- **Source root**: `C:\Users\19146\cooking-rush\src\`
- **Sync tool**: **Rojo live sync** (`rojo serve` + the managed Studio plugin, installed via `rojo plugin install`). Edit files on disk → they sync into Studio automatically. This replaced the earlier `execute_luau` full-`Source` pushes and resolved the disk↔Studio drift (the in-Studio scripts had been hand-condensed copies). Run `rojo serve` from the repo root, then Rojo → Connect in Studio.
- **Config layer**: `ReplicatedStorage.Shared.Config.{Stations, Recipes, Ingredients, Customers, Upgrades, Restaurants}`
- **Pure logic**: `ReplicatedStorage.Shared.Modules.{RecipeResolver, EconomyMath, LevelGenerator, Schema}`
- **Server**: `src/ServerScriptService/Server/init.server.lua` — boots DataService → LevelService → PlayerService
- **Client**: `src/StarterPlayer/StarterPlayerScripts/Client/init.client.lua` — boots all 6 controllers in dependency order

### Station archetypes (all in `Station.lua` entity)
- **Cooker** — `cookTimer`/`burnTimer` slot array; `interact` places or picks up
- **Dispenser** — `stock`/`refill` tick; `interact` returns item if hands empty
- **Assembler** — `_base` + `_added[]`; matches recipe via `RecipeResolver`

### Two-value interact return (critical design)
```lua
function Station:interact(heldItemId: string?): (string?, boolean)
-- (outputItem, consumed)
-- (item, false)  → pick up / receive item
-- (nil,  true)   → held item was consumed by station
-- (nil,  false)  → nothing happened
```

### One-item carry
`StationController.heldItem` (ItemStack entity) is the single source of truth for what the player holds. CustomerController reads it for serving; UIController polls it on Heartbeat.

### World layout (Edit-mode Parts)
- `Workspace.Stations/` — 8 Parts, each with `StationId` string attribute
  - Back row (Z=−14, green): `raw_patty_shelf`, `raw_fries_shelf`, `bun_shelf`, `cheese_shelf`
  - Middle row (Z=−7): `grill` (red), `fryer` (red), `bun_counter` (yellow), `drink_dispenser` (blue)
- `Workspace.Seats/` — 3 orange Parts at Z=+4 (`Seat1`, `Seat2`, `Seat3`)
- `Workspace.StreamingEnabled = false` (required — streaming caused `GetChildren()` to return empty)

---

## What Worked

- **Two-value interact return** — changed `interact() → string?` to `interact() → (string?, boolean)`. The `consumed` boolean is the only reliable way to distinguish "item accepted" from "nothing happened" when both return nil.
- **Ingredient shelves as Dispensers** with `maxStock=999, refillTime=1` — unlimited raw materials without special-casing.
- **DataService pcall fallback** — `GetAsync` fails in Studio (no DataStore access); code falls through to `DEFAULT_PROFILE` with `fastfood=true`, so `RequestLevelStart` always succeeds without network.
- **Studio auto-start**: `if RunService:IsStudio() then task.delay(3, LevelController:startLevel(...)) end` in `init.client.lua`.
- **M0 verification** via direct `execute_luau` assertions — bypasses TestEZ global injection problem with `describe`/`it`/`expect` in strict Luau.
- **Disabling StreamingEnabled** — workspace Parts exist in Edit mode but `GetChildren()` returns 0 on the client at startup when streaming is on. Set `workspace.StreamingEnabled = false` to fix.

## What Didn't Work

- **TestEZ specs via `execute_luau`** — specs use bare `describe`/`it`/`expect` globals injected by TestEZ's `setfenv`, which is unavailable in `--!strict` Luau. Cannot call spec files directly. Workaround: run equivalent assertions manually in `execute_luau`.
- **`interact() → string?` (old return)** — ambiguous: both "placed item" and "nothing happened" returned nil. Required the two-value return fix.
- **`Dispenser` without hands-full guard** — old code would dispense even if player already held an item. Fixed: `if heldItemId then return nil, false end` at top of `_dispenserInteract`.

---

## Key Files

| File | Purpose |
|------|---------|
| `src/StarterPlayer/StarterPlayerScripts/Client/Entities/Station.lua` | Station entity — all 3 archetypes, two-value interact |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/StationController.lua` | Scans Workspace.Stations, wires ProximityPrompts, owns `heldItem` |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/CustomerController.lua` | Spawns customers, assigns seats, wires serving ProximityPrompts |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/UIController.lua` | HUD: coins, combo, held item, level state (no assets) |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/OrderController.lua` | `tryServe(customer, heldItemId)` → RecipeResolver → EconomyMath → ComboController → coins |
| `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/LevelController.lua` | `startLevel`, `addCoins`, `endLevel`, `StateChanged` signal, `CoinsChanged` signal |
| `src/ReplicatedStorage/Shared/Config/Stations.lua` | All station configs including ingredient shelves |
| `src/ReplicatedStorage/Shared/Config/Recipes.lua` | Recipe graph (cheeseburger, fries, cola, etc.) |
| `src/ServerScriptService/Server/Services/LevelService.lua` | `RequestLevelStart` + `SubmitLevelResult` (validates coins **and** mastery serves) |
| `src/ServerScriptService/Server/Services/DataService.lua` | DataStore profiles (v2: + `mastery`/`prestige`/`prestigeTokens`); pcall-guarded, falls back to DEFAULT_PROFILE in Studio |
| `src/ServerScriptService/Server/Services/MasteryService.lua` | Server-authoritative recipe mastery: applies validated serve tallies → XP/levels |
| `src/ServerScriptService/Server/Services/ProgressionService.lua` | XP/levels/unlocks + the **franchise** (prestige) transaction |
| `src/ReplicatedStorage/Shared/Config/Mastery.lua` | Recipe-mastery curve (global default + sparse per-recipe overrides) |
| `src/ReplicatedStorage/Shared/Config/Prestige.lua` | Prestige curve params (earnings mult, token grant, equip-slot hook for M8) |
| `src/ReplicatedStorage/Shared/Config/Chefs.lua` | Chef roster, rarity ladder/colours, passive effect-tags |
| `src/ReplicatedStorage/Shared/Config/RecruitCrates.lua` | Gacha crates: cost + weighted drop table + pity rule |
| `src/ReplicatedStorage/Shared/Modules/GachaMath.lua` | Pure weighted-roll + pity (server-authoritative drops) |
| `src/ReplicatedStorage/Shared/Modules/ChefMath.lua` | Pure passive aggregation, equip-slot count, fusion cost |
| `src/ServerScriptService/Server/Services/RecruitService.lua` | Server-authoritative recruit (rolls, charges, mints, pity) |
| `src/ServerScriptService/Server/Services/ChefService.lua` | Equip/unequip/fuse; equip-slot cap from total prestige |
| `src/StarterPlayer/.../Controllers/ChefController.lua` | Aggregates equipped passives at level start; drives autoServe |
| `src/StarterPlayer/.../Controllers/ChefUIController.lua` | Chefs panel: recruit (published odds), collection, equip, fuse |
| `src/ReplicatedStorage/Shared/Modules/IdleMath.lua` | Pure offline accrual + cap (server clamps the clock, then calls this) |
| `src/ServerScriptService/Server/Services/IdleService.lua` | Idle accrual/collect, chef assignment, gem cap upgrade (server-authoritative) |
| `src/StarterPlayer/.../Controllers/IdleUIController.lua` | Idle panel: live-ticking pending, Collect, assign chefs, cap upgrade, number-pop |

---

## M7 — Meta-progression spine (Recipe Mastery + Restaurant Prestige)

The first incremental-growth milestone. No new content is authored — both systems are
formula + config that multiply the value of every restaurant the generator already makes.

### Design decisions
- **Prestige scope = per-restaurant** (not whole-account rebirth). Per the roadmap's
  recommendation: more forgiving, and it layers with the M8 chef equip-slot growth
  (`Prestige.equipSlotsPerLevel` is a reserved hook for that).
- **Serve reporting is batched, not per-serve.** The client tallies serves per recipe
  during a level (`LevelController.serves`) and submits the tally inside the existing
  `SubmitLevelResult` payload — no new per-serve remote to spam. The server clamps each
  count to `EconomyMath.rosterRecipeCounts(level.spawns)` so mastery can't be farmed
  past real play, then `MasteryService:applyServes` grants XP.
- **Server-authoritative earnings, exactly.** Mastery (per-recipe tip mult) and prestige
  (per-restaurant earnings mult) are folded into the client's *live* coin counter for
  feel, and the server re-derives the **same** ceiling in `EconomyMath.theoreticalMax`
  (now takes a `masteryMultFn` + `globalMult`) using the player's real profile values.
  Because those values only grow through validated play, the ceiling can't be gamed.
  Mastery XP for the just-played level is applied *after* the ceiling check so a level
  never inflates its own validation.

### Where it lives
- Pure math in `EconomyMath`: `masteryLevel`, `masteryTipMult`, `masteryCookSpeedMult`,
  `masteryMult`, `prestigeMultiplier`, `prestigeTokenGrant`, `rosterRecipeCounts`
  (all unit-tested — 23 new specs, run via `TestRunner.runAll()`).
- `MasteryService` (server) owns mastery writes; `ProgressionService:franchise` owns the
  prestige transaction (validate full 3-star completion → reset that restaurant's stars +
  its stations' upgrades → bump prestige → grant Prestige Tokens).
- Profile **v2**: added `mastery`, `prestige`, `prestigeTokens` (migration `[1]` in
  `DataService`, reconcile + fallback handle existing saves).
- UI: `ShopController` gained a **Recipe Mastery** section (level + progress bar per
  unlocked-menu dish) and a **Franchise** button per restaurant (enabled only when every
  level is 3-starred); status line now shows Prestige Tokens.

### `cookSpeed` mastery bonus — reserved
`Mastery.defaultPerLevelBonus.cookSpeed` and `EconomyMath.masteryCookSpeedMult` exist and
are tested, but are **not yet wired to live stations**: stations cook intermediate items
shared across recipes, so mapping a recipe's mastery onto a station's `cookTime` needs a
design pass (which dish "owns" a shared cook step?). Only the tip-value bonus affects live
economy today. Wire cookSpeed when that ownership question is settled.

## M8 — Chef Collection & Recruitment

The headline collection system. Chefs are this game's pets: collectible, rarity-tiered,
equip-able config rows whose `passives` are **effect tags consumed by the existing engine**.
Adding a chef is one row in `Chefs.lua`; only a brand-new *tag* would touch code.

### Effect tags (all wired live)
- `cookSpeedMult` → `Station:setChefModifiers` shortens effective cook time (>1 = faster)
- `tipMult` → folded into `OrderController` `earningsMult` (and the server ceiling)
- `burnImmuneChance` → `Station._cookerTick` rolls a one-time save per slot before a burn
- `autoServe` → `ChefController` calls `CustomerController:autoServeOne()` on an interval,
  reusing the normal serve path so combo/mastery/earnings all apply

### Server authority (the important part for a gacha + tradeable economy later)
- `RecruitService` rolls with its **own** `Random`, applies the pity floor, charges the
  cost, and mints the chef with a server-issued `nextChefUid`. Clients send only the intent.
- `ChefService` validates equip (slot cap = `CHEF_BASE_EQUIP_SLOTS + equipSlotsPerLevel *
  totalPrestige` — the M7→M8 tie) and fusion (consume `CHEF_FUSION_DUPES` dupes → +1 level,
  burning least-valuable copies first: unequipped, non-shiny, lower-level).
- The earnings ceiling in `SubmitLevelResult` now folds equipped chefs' aggregated `tipMult`
  into `globalMult` alongside prestige, so chef-boosted coins stay validated and ungameable.
- Pure, unit-tested math: `GachaMath` (rolling/pity) and `ChefMath` (aggregation/slots/fusion)
  — 31 new specs, suite now **116/116**.

### Profile v3
Added `chefs` ({uid, chefId, shiny, level}), `equippedChefs` (uids), `pity` (per-crate
counter), `nextChefUid`. Migration `[2]` in `DataService`; reconcile + fallback handle
existing saves.

### Reserved
- **In-world chef models** (`Chef.model`) aren't spawned yet — passives are fully live, but
  the followed/kitchen model rendering is a visual follow-up (needs assets + world layout).
- `autoServe` delivers via the existing serve path; a bespoke "chef walks the dish over"
  animation is also model-dependent and deferred.

## M9 — Idle / Passive Empire

Turns owned-but-idle restaurants into an offline income engine — the loop that gives chefs
and prestige somewhere to compound. Idle yield is **derived from existing config** (no new
per-restaurant authoring): each unlocked restaurant accrues at a base rate from its
`dailyIncome`, scaled by prestige × assigned-chef passives × average menu mastery.

### Server owns the clock (anti-exploit)
`IdleService` computes `elapsed = os.time() - lastCollect` per restaurant — the client never
supplies a delta. `IdleMath.accrue` clamps `elapsed` to `[0, capSeconds]` (so a wound-back
client clock yields 0, and a far-past one is capped). Collect grants via `EconomyService`
and resets `lastCollect` to `os.time()`. A restaurant's timestamp is initialised to "now" on
first sight so a freshly-unlocked one doesn't read as instantly capped.

### Pieces
- Pure `IdleMath`: `accrue`, `cappedElapsed`, `isCapped`, `capFraction` (13 specs).
- Profile **v4**: repurposed the pre-existing `lastIncomeClaim` as the per-restaurant idle
  last-collect timestamp; added `idleAssignments` ({restaurantId → uids}) and
  `idleCapBonusHours`. Migration `[3]`. Fusion now also strips consumed chefs from idle
  assignments.
- `IdleService`: `getState` (UI snapshot), `collect` (one or all), `autoAssign` (fills free
  idle slots with the best unassigned chefs by `ChefMath.chefIdleValue`), `unassign`,
  `purchaseCap` (gem sink, `IDLE_CAP_UPGRADE_GEM_COST` per `IDLE_CAP_UPGRADE_HOURS`).
- `IdleUIController`: live-ticking pending counter (projected client-side between fetches,
  reconciled on collect), Collect/Collect-All, per-restaurant chef assignment chips, cap
  upgrade, and a floating "+N" number-pop.
- All idle tuning is in `GameConfig` (`IDLE_RATE_MULT`, cap hours, gem cost, chef slots).

### Reserved / tuning notes
- Base rate reads `dailyIncome` as a *daily* figure scaled by `IDLE_RATE_MULT` (=12) — a
  single global knob to balance the idle economy without touching restaurant configs.
- A "world map" with restaurant nodes (vs. the current list panel) is a presentation
  upgrade for later; the loop itself is complete.

## Next Steps (M10 — Live-Ops: Events, Seasons, Quests, Leaderboards)
The recurring re-engagement layer, nearly free thanks to the data-driven engine. Build:
limited-time restaurants via an optional `availability = { startUtc, endUtc }` + event
currency on the `Restaurant` schema (a holiday restaurant = one config file that
auto-appears/expires); `QuestService` with a `Quests.lua` daily-objective generator + login
streaks; a `Seasons.lua` battle pass (free + premium track); and an OrderedDataStore-backed
`LeaderboardService`. Goal: shipping a seasonal event should need **zero new Luau logic** —
the M6 config-only test, extended. See the M7–M12 roadmap.

### Full cheeseburger serve flow (reference for testing)

### Full cheeseburger serve flow (reference for testing)
1. **Bun Shelf** (back row) → E → hold `bun`
2. **Assembly Counter** (middle row, yellow) → E → bun placed, hands empty
3. **Patty Shelf** → E → hold `raw_patty`
4. **Grill** (middle row, red) → E → raw_patty placed, wait ~12 s for "Grill: Ready: cooked_patty"
5. **Grill** → E → hold `cooked_patty`
6. **Assembly Counter** → E → patty added, hands empty
7. **Cheese Shelf** → E → hold `cheese_slice`
8. **Assembly Counter** → E → complete → hold `cheeseburger`
9. Walk to green **Seat** Part → E → coins awarded

---

## Studio Setup Checklist (fresh session)

1. Open `C:\Users\19146\cooking-rush` in Studio (place file or Rojo sync).
2. Confirm `workspace.StreamingEnabled == false`.
3. Confirm `Workspace.Stations` has 8 Parts with correct `StationId` attributes.
4. Confirm `Workspace.Seats` has 3 Parts.
5. Press **Play** — after 3 s the console should print:
   ```
   [StationController] Wired 8 stations
   [CustomerController] Found 3 seats
   [Client] Studio: auto-starting FastFood level 1
   ```
6. Walk within 8 studs of any station Part — ProximityPrompt appears with action text.
