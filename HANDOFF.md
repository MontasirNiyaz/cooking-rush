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
| M5 — ProgressionService, UpgradeService, Shop UI | Pending |
| M6 — Sushi restaurant (config-only) | Pending |

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
| `src/ServerScriptService/Server/Services/LevelService.lua` | `RequestLevelStart` remote handler, calls `LevelGenerator.generate` |
| `src/ServerScriptService/Server/Services/DataService.lua` | DataStore profiles; pcall-guarded, falls back to DEFAULT_PROFILE in Studio |

---

## Next Steps (M2)

### Goal
Full level state machine: Idle → Intro (3 s) → Playing → Results. Customers have visible patience meters. Combo display updates in real time. Level ends when all customers served or timer expires. Results screen shows coins + stars.

### What to implement

1. **LevelController** — `elapsed` timer increments on Heartbeat while Playing; `endLevel()` calculates stars via `EconomyMath.starRating(coins, targetCoins)` and fires `StateChanged("Results")`.

2. **CustomerController patience UI** — each customer's seat Part gets a BillboardGui bar that drains as `customer.patience` falls. Red when < 25%.

3. **Results screen** — UIController listens for `StateChanged("Results")` and overlays a full-screen panel showing coins earned and star count (1–3 stars).

4. **Combo label** — already wired; verify streak increments on serve and resets on angry departure.

5. **Level timer** (optional for M2 — FastFood level 1 is customer-count-based not time-based, so `allDone` check in CustomerController already handles end-of-level).

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
