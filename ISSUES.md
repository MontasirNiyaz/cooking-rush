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

## 6. M6 — Add the Sushi restaurant as pure config `[milestone:M6]` — DONE

The architecture's central claim, validated: the full game loop runs for Sushi with **zero new engine code**. The M6 commit touched only 3 config files + a world-build tool — no controller/service/entity changed (`git diff --stat`).

- [x] Completed the Sushi content (config-only) — the existing Sushi config had latent gaps: nothing produced `raw_salmon`, `raw_tuna`, `nori`, or `miso_base`, and `fish_prep` is salmon-only. Added four ingredient-shelf Dispensers + a `tuna_prep` Cooker to `Config/Stations.lua` (reusing the existing archetypes), and pointed `tuna_roll`'s cook step at `tuna_prep`. No new station behaviour code — just data.
- [x] Build the Sushi kitchen world (stations + seats) — built 10 Sushi station Parts to the right of FastFood (X 20..48), sharing the existing 3 seats. The world isn't Rojo-tracked, so the builder is checked in as [`tools/build_sushi_world.lua`](tools/build_sushi_world.lua) (idempotent; run in the Edit command bar) — the version-controlled record of the layout.
- [x] Validate the loop end-to-end — boot: Schema validates the new config and `StationController` wires **18 stations** (8 FastFood + 10 Sushi). `LevelGenerator.generate(sushi, 1)` yields the tutorial roster (salmon_nigiri + green_tea, goals 6/15/24). Drove the **whole Sushi menu** through the real `Station` archetypes from config alone: green_tea (dispense), salmon_nigiri (salmon shelf → fish_prep → rice → roller), tuna_roll (tuna shelf → tuna_prep → +nori +rice → roller), miso_soup (miso_base shelf → soup_pot) — each produced its final item and `salmon_nigiri` fulfils its order. The restaurant unlock gate itself was confirmed server-authoritative in M5 (Sushi rejected with `level_required`).
- [x] Confirm no engine/controller code was modified — `git diff` for the M6 commit shows only `Config/Stations.lua`, `Config/Recipes.lua`, `Config/Restaurants/Sushi.lua`, and `tools/build_sushi_world.lua`.

**Note:** a live in-avatar playthrough wasn't scripted (MCP can't drive the running client's UI/input). Verification used the actual `Station`/`RecipeResolver`/`LevelGenerator` modules the live game runs, exercised deterministically. To see it in-game: unlock Sushi (reach player level 10 + 2500 coins, or temporarily lower `Sushi.unlock`) and start Sushi level 1 from the menu flow.

---

## 7. TestEZ specs cannot be run directly via `execute_luau` `[tech-debt]` — DONE

The specs in `tests/` use bare `describe`/`it`/`expect` globals that TestEZ injects via `setfenv`. The earlier blocker was the lack of a runner, not the language — `setfenv` works fine in Studio (verified). Rather than vendor the full TestEZ library, a minimal runner provides the slice of the DSL the specs actually use.

- [x] Added `tests/TestRunner.lua` (synced to `ServerStorage.Tests.TestRunner`) — a minimal TestEZ-compatible runner (`describe`/`it`/`expect(x).to.equal(y)`/`.to.be.ok()`) that `setfenv`-injects the DSL and runs every sibling `*.spec` module. `runAll()` reports pass/fail. Current suite: 63/63 pass.
- [x] Documented `run tests` steps in the README (Testing section).

---
---

# P0 Evaluation — June 2026 (pre-P0–P6 run)

Code review of `main` @ c18f9cd against the P0–P6 plan. Issues 8–15 below are new;
they re-scope phase P0. File as GitHub issues 1:1.

---

## 8. CRITICAL — `SubmitLevelResult` has no session tracking: coin-farming exploit `[security] [P0]`

`Services/LevelService.lua` validates `coinsEarned <= theoreticalMax * tolerance` but:
- never verifies the player **started** the level (no active-session record),
- never limits **how many times** a result can be submitted,
- receives `timeTaken` in the payload (line 44 comment) and **never reads it**.

A client can loop `SubmitLevelResult` with near-max coins and farm currency/XP without playing.

- [ ] `RequestLevelStart` records `activeSession[player] = { restaurantId, levelIndex, startedClock = os.clock() }`
- [ ] `SubmitLevelResult` rejects unless payload matches the active session; consume the session on accept (one submit per start)
- [ ] Validate elapsed: `os.clock() - startedClock >= minPlausibleSeconds(level)` (e.g. last spawn `atSecond` × a config factor, `GameConfig.MIN_RESULT_TIME_FACTOR`)
- [ ] Clear session on PlayerRemoving
- [ ] Unit-test the pure plausibility function

## 9. Server trusts client star count — recompute instead `[security] [P0]`

`LevelService` clamps `payload.stars` but the server already has `coinsEarned` and the
re-generated `level.goals`. Clamping still lets a client claim 3 stars on 1-star coins,
inflating `levelReward` and first-clear gems.

- [ ] Replace the clamp with `stars = EconomyMath.starsFor(coinsEarned, level.goals)`; ignore `payload.stars` entirely (keep it only for telemetry mismatch logging)

## 10. No rate limiting on the remote surface `[security] [P0]`

No throttle on any RemoteFunction (`grep -rni ratelimit src/ServerScriptService` → empty).
`RequestLevelStart` regenerates a level per call (CPU); all invokes are spammable.

- [ ] Add a small per-player token-bucket guard module used by every `OnServerInvoke` (limits in `GameConfig.REMOTE_RATE_LIMITS`)
- [ ] Log + drop on breach

## 11. Cross-server profile session locking `[data-integrity] [P0]`

Known gap (issue #4 "Remaining"). `save()` runs `UpdateAsync` but the transform ignores
the stored value, so a stale server can overwrite newer data if a player hops servers.
Must land before soft launch (P4) traffic.

- [ ] Lock token in the profile (`sessionLock = { jobId, expiresAt }`) acquired via `UpdateAsync` compare on load; refuse/steal-after-expiry semantics
- [ ] `save()` transform verifies our lock before writing; release on leave/BindToClose
- [ ] Pure-test the lock state machine (acquire / steal / expire)

## 12. Dev/prod DataStore namespacing `[infra] [P0]`

Single store `"CookingRushV1"` for all environments. Studio/dev testing writes
production keys once API access is on.

- [ ] `GameConfig.PLACE_ENV` map (placeId → "dev"/"prod"); store name = `env .. "_" .. base`
- [ ] Boot log line stating environment; pure-test the mapping

## 13. Streaming-safe station/seat binding (P1 prerequisite) `[P1-prereq]`

README mandates `Workspace.StreamingEnabled = false` because `StationController` /
`CustomerController` snapshot `Workspace.Stations:GetChildren()` at startup. The P1 hub
world + mobile perf budget require StreamingEnabled **on**.

- [ ] Tag station/seat Parts with CollectionService tags (`Station`, `Seat`) + keep the `StationId` attribute
- [ ] Controllers bind via `GetTagged` + `GetInstanceAddedSignal/RemovedSignal` (streaming-safe, also removes the fixed-folder-name coupling)
- [ ] Flip `StreamingEnabled = true`; update README/HANDOFF
- [ ] Extend `tools/build_sushi_world.lua` pattern into a generic config-driven `tools/build_world.lua` that applies tags (world layout stays version-controlled)

## 14. Generator/economy tests never exercise real configs `[testing] [P0]`

All 63 specs run against mock configs. Nothing asserts that the *shipped* FastFood/Sushi
configs generate valid, balanced levels. (Supersedes the old "golden levels" idea from
`docs/FASTFOOD_CONTENT_AND_LEVELS.md` §7 — those tables are design references only.)

- [ ] Real-config invariant suite: for every restaurant × all `levelCount` indices —
      every ordered recipe is in the restaurant menu and producible by its stations;
      goals strictly ordered; customer types valid; spawn times sorted
- [ ] Snapshot suite: pin generated levels {1, 10, 25, 40} per restaurant (serialize →
      commit → assert); determinism spec already exists, this adds drift detection
- [ ] Difficulty monotonicity: customerCount non-decreasing, patienceScale non-increasing across indices

## 15. Close out the Studio auto-start hack (existing issue #1) `[tech-debt] [P0]`

Still live in `init.client.lua:31-37`.

- [ ] `GameConfig.DEBUG_AUTOSTART = false` gate; document in HANDOFF

## 16. Dispenser multi-output — CLOSE as won't-do `[decision]`

`docs/FASTFOOD_CONTENT_AND_LEVELS.md` §2 proposed `produces → outputs: {string}`. The
codebase established a better pattern: **one Dispenser per item** (see Sushi's shelves +
`green_tea`). Multi-drink fountains = multiple station Parts sharing a model. No engine
change; keeps the archetype trivial.

- [ ] Update the content doc + bundle task P0.2 to reflect the decision (done in bundle)

## 17. Doc/config balance divergence — config is truth `[docs]`

`GameConfig` tips (1.5/1.0/0.5 global) and shelf-style dispensers diverge from the
content doc's per-customer `tipCurve` and station tables. The shipped config is the
source of truth; the doc is a design reference.

- [ ] Add a "superseded by shipped config" banner to `docs/FASTFOOD_CONTENT_AND_LEVELS.md`
