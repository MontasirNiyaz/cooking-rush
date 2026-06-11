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

## 4. M4 — DataStore profiles & authoritative level-result validation `[milestone:M4]`

- [ ] `DataService` full DataStore profile load/save (currently falls back to `DEFAULT_PROFILE` when DataStore is unavailable)
- [ ] Server-side `SubmitLevelResult` validation (never trust client coin/star totals)
- [ ] Persist stars/coins; wire `EconomyService` + `ProgressionService:recordStars`
- [ ] Daily reward (`EconomyService:claimDaily`) reachable from UI

---

## 5. M5 — Progression unlocks, upgrade trees & Shop UI `[milestone:M5]`

- [ ] Restaurant unlock flow (`ProgressionService:canUnlockRestaurant` already exists) surfaced in UI
- [ ] Apply `UpgradeService:effectiveStation` modifiers to live station behaviour
- [ ] Build Upgrade / Shop UI screens

---

## 6. M6 — Add the Sushi restaurant as pure config `[milestone:M6]`

The architecture's central claim. `Config/Restaurants/Sushi.lua` and the Sushi station/recipe/ingredient configs already exist — this milestone validates the full loop runs for Sushi with **zero new engine code**.

- [ ] Build the Sushi kitchen world (stations + seats) in the place file
- [ ] Play through Sushi level 1 end-to-end
- [ ] Confirm no engine/controller code was modified to support it

---

## 7. TestEZ specs cannot be run directly via `execute_luau` `[tech-debt]` — DONE

The specs in `tests/` use bare `describe`/`it`/`expect` globals that TestEZ injects via `setfenv`. The earlier blocker was the lack of a runner, not the language — `setfenv` works fine in Studio (verified). Rather than vendor the full TestEZ library, a minimal runner provides the slice of the DSL the specs actually use.

- [x] Added `tests/TestRunner.lua` (synced to `ServerStorage.Tests.TestRunner`) — a minimal TestEZ-compatible runner (`describe`/`it`/`expect(x).to.equal(y)`/`.to.be.ok()`) that `setfenv`-injects the DSL and runs every sibling `*.spec` module. `runAll()` reports pass/fail. Current suite: 27/27 pass.
- [x] Documented `run tests` steps in the README (Testing section).
