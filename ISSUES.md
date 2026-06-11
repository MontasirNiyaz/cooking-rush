# Tracked Issues

Draft issues for Cooking Rush, derived from the roadmap and in-code markers. Ready to be filed as GitHub issues (titles map 1:1 to suggested issue titles; labels suggested in brackets).

---

## 1. Remove / gate the Studio auto-start hack before production `[tech-debt]`

`src/StarterPlayer/StarterPlayerScripts/Client/init.client.lua:26-32` auto-starts FastFood level 1 after a 3-second delay whenever `RunService:IsStudio()` is true. This is an M1 test convenience and must not ship in a production build — level start should be driven by the menu / `RequestLevelStart` flow.

- [ ] Move auto-start behind an explicit debug flag (e.g. `GameConfig.DEBUG_AUTOSTART`)
- [ ] Default it off; document it in HANDOFF.md

---

## 2. M2 — Level state machine, patience meters, combo & star results `[milestone:M2]` — DONE (commit `e8bd759`)

Full level loop: Idle → Intro (3s) → Playing → Results.

- [x] `LevelController.elapsed` timer increments on Heartbeat while Playing
- [x] `endLevel()` computes stars via `EconomyMath.starsFor(coinsEarned, level.goals)` and fires `StateChanged("Results")` (stars stored on `LevelController.stars` *before* the state fires so the UI can read it)
- [x] Per-customer patience UI (BillboardGui bar on the seat Part) that drains with `customer:getPatienceFraction()`; red under 25%
- [x] Full-screen Results panel in `UIController` showing coins earned + star count
- [x] Verify combo streak increments on serve and resets on angry departure

**Also fixed (was blocking 3-star on level 1):** customers are now admitted
only when a seat is free, so arrivals queue by time instead of being orphaned
seatless. Previously level 1 (4 customers, 3 seats) stranded customer 4 with no
prompt and no patience bar.

Verified in Studio: unattended run drove Idle→Intro→Playing→Results with bars
draining and going red <25%, and customer 4 re-seated on a freed seat. Attended
run totaled 36 coins with the star filling correctly (combo + non-zero star
path confirmed).

---

## 3. M3 — Wire LevelGenerator into LevelController & tune difficulty `[milestone:M3]` — DONE

- [x] Replace any static spawn list with `LevelGenerator.generate(...)` — already wired in `LevelService` (`RequestLevelStart` + server-side `SubmitLevelResult` re-generation). No static list existed.
- [x] Generate FastFood's 40 levels from config — verified all 40 indices produce valid rosters + ordered star goals.
- [x] Tune the difficulty curve (customer rate, patience, order complexity) — order complexity was flat (single-item orders through ~level 20 because `maxOrders` rode the smoothstep `t`). Made it **config-driven** (`GameConfig.MIN_MAX_ORDERS` / `MAX_MAX_ORDERS`) and ramped on *linear* progress: now ~lvl 1–10 single-item, 11–30 up to 2-item, 31–40 up to 3-item. Customer count / patience / spawn gap were already healthy.
- [x] Run the TestEZ specs in `tests/` via a Studio test runner — see issue #7 below; **27/27 pass**.

---

## 4. M4 — DataStore profiles & authoritative level-result validation `[milestone:M4]` — DONE

- [x] `DataService` full DataStore profile load/save — load already had GetAsync + reconcile + migrations + autosave; **added durability**: `BindToClose` shutdown flush, `UpdateAsync` + retry-with-backoff, and a per-player overlap guard. Still falls back to `DEFAULT_PROFILE` when the DataStore is unavailable (Studio without API access). Verified real persistence in Studio (a profile loaded coins=184 across sessions).
- [x] Server-side `SubmitLevelResult` validation — already present in `LevelService`: type checks, server-side level re-generation, `theoreticalMax` overage rejection, star clamp. Confirmed.
- [x] Persist stars/coins; wire `EconomyService` + `ProgressionService:recordStars` — already wired in `SubmitLevelResult`. Confirmed.
- [x] Daily reward reachable from UI — added `ProfileController` (client): fetches `GetProfile` (with a join-race retry), shows persistent coins/gems, and a **Daily Reward** button that invokes `ClaimDaily`. Extracted the eligibility rule to a pure `EconomyMath.canClaimDaily` (unit-tested). Verified end-to-end: claim → +50, repeat → already-claimed, balance persisted.

**Remaining (future):** full cross-server session locking (current durability is BindToClose + retry, not a lock token). Persistent-balance HUD currently refreshes on join and after a level result.

---

## 5. M5 — Progression unlocks, upgrade trees & Shop UI `[milestone:M5]` — DONE

- [x] Restaurant unlock flow surfaced in UI — `ShopController` lists every restaurant from `Config/Restaurants` with its unlocked state or unlock requirement (level/coins/gems); the Unlock button invokes `UnlockRestaurant`, server-authoritative via `ProgressionService:canUnlockRestaurant`. Verified: Sushi correctly gated with `level_required` at player level 1.
- [x] Apply upgrade modifiers to live station behaviour — the duplicated effective-stat math (it lived in **both** `Station.lua` and `UpgradeService.lua`) was extracted to a pure shared `Modules/UpgradeMath.lua`, so client and server can't drift. `StationController` now applies each player's real per-station upgrade levels (via `Station:setUpgradeLevel`) at level start (`Intro`) instead of the hardcoded `0`. Verified: drink_dispenser maxStock 8→12 (+4) and grill cookTime 12→10.8 (×0.90) in the effective config.
- [x] Build Upgrade / Shop UI screens — `ShopController` builds a single data-driven Shop panel (🛒 toggle): a **Station Upgrades** section (current level + next tier name/cost + Buy) and a **Restaurants** section, both generated entirely from config. `ProfileController` now owns the single client-side profile cache (`get()` / `Changed` signal / `refresh()`) so the shop, station upgrades, and balance HUD all read one source and refresh after a server-authoritative change.

**Verified in Studio:** clean boot (no errors); a real `PurchaseUpgrade("drink_dispenser")` deducted coins 184→34 and bumped the level 0→1 (persisted server-side); an unaffordable grill upgrade (200 at 184 coins) was rejected with `insufficient_coins`; Sushi unlock gated with `level_required`. Full suite **63/63 pass** (+10 new `UpgradeMath` specs).

**Remaining (future):** the balance HUD refreshes on join / level result / profile-Changed — purchases made *through the shop UI* update it via `refresh()`, but out-of-band currency changes won't reflect until the next refresh.

---

## 6. M6 — Add the Sushi restaurant as pure config `[milestone:M6]`

The architecture's central claim. `Config/Restaurants/Sushi.lua` and the Sushi station/recipe/ingredient configs already exist — this milestone validates the full loop runs for Sushi with **zero new engine code**.

- [ ] Build the Sushi kitchen world (stations + seats) in the place file
- [ ] Play through Sushi level 1 end-to-end
- [ ] Confirm no engine/controller code was modified to support it

---

## 7. TestEZ specs cannot be run directly via `execute_luau` `[tech-debt]` — DONE

The specs in `tests/` use bare `describe`/`it`/`expect` globals that TestEZ injects via `setfenv`. The earlier blocker was the lack of a runner, not the language — `setfenv` works fine in Studio (verified). Rather than vendor the full TestEZ library, a minimal runner provides the slice of the DSL the specs actually use.

- [x] Added `tests/TestRunner.lua` (synced to `ServerStorage.Tests.TestRunner`) — a minimal TestEZ-compatible runner (`describe`/`it`/`expect(x).to.equal(y)`/`.to.be.ok()`) that `setfenv`-injects the DSL and runs every sibling `*.spec` module. `runAll()` reports pass/fail. Current suite: 63/63 pass.
- [x] Documented `run tests` steps in the README (Testing section).
