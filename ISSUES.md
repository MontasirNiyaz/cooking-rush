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

## 10. M9 — Idle / Passive Empire `[milestone:M9]` — DONE

Owned restaurants accrue offline income; the loop that gives chefs/prestige somewhere to
compound. Idle yield is derived from existing config — no new per-restaurant authoring.

- [x] Pure `IdleMath.accrue(rate, mult, elapsed, cap)` + `cappedElapsed`/`isCapped`/
  `capFraction` (13 specs). Server clamps the clock, then calls this.
- [x] `IdleService` (server-authoritative): per-restaurant accrual from `lastCollect`
  (repurposed `lastIncomeClaim`), `collect` (one/all) grants via EconomyService + resets the
  timestamp, output = base (`dailyIncome` × `IDLE_RATE_MULT`) × prestige × assigned-chef
  passives × avg menu mastery.
- [x] **Anti-exploit:** `elapsed = os.time() - lastCollect` (server clock only); clamped to
  `[0, cap]` so a tampered client clock can't mint coins. New restaurants start accruing from
  first sight, not epoch.
- [x] Chef assignment: `idleAssignments` profile field; `autoAssign` fills free slots with the
  best unassigned chefs (`ChefMath.chefIdleValue`), `unassign` for control. Fusion strips
  consumed chefs from assignments.
- [x] Offline cap upgrade — gem sink (`purchaseCap`: `IDLE_CAP_UPGRADE_HOURS` per
  `IDLE_CAP_UPGRADE_GEM_COST` gems, up to `IDLE_CAP_MAX_BONUS_HOURS`).
- [x] Profile v4 (+ migration `[3]`): `idleAssignments`, `idleCapBonusHours`.
- [x] `IdleUIController`: live-ticking pending counter, Collect/Collect-All, chef assignment
  chips, cap upgrade, floating "+N" number-pop.

**Verification (Studio, Rojo-synced):** clean Schema-validated boot; full suite **129/129**
(+13). End-to-end integration confirmed: 1h accrual = 25; 100h clamped to the 8h cap = 200;
prestige 2 → ×1.5 = 300; collect grants + resets timestamp (next pending 0); auto-assign 2
chefs → ×1.2544 = 31; unassign; cap upgrade → 12h for 25 gems.

**Reserved:** a "world map" node UI (vs. the current list panel) is a presentation upgrade;
the loop itself is complete.

---

## 9. M8 — Chef Collection & Recruitment `[milestone:M8]` — DONE

The headline collection/gacha system. Chefs are config rows; their passives are effect tags
the existing engine already consumes, so a 200-chef roster is pure data.

### 9.1 Chef data + passives
- [x] `Config/Chefs.lua` — 11-chef roster across 6 rarities, with a rarity ladder, colours,
  and composable passive tags. `Config/RecruitCrates.lua` — two crates (coins/gems) with
  weighted drop tables + pity rules.
- [x] Passive tags wired into existing systems: `cookSpeedMult` + `burnImmuneChance` →
  `Station` cooker; `tipMult` → `OrderController` earnings (+ server ceiling); `autoServe` →
  `ChefController` timer → `CustomerController:autoServeOne` (reuses the normal serve path).

### 9.2 Recruitment (server-authoritative gacha)
- [x] `RecruitService` rolls with its own `Random`, charges cost (coins/gems, atomic +
  refund), applies the **pity** floor, and mints the chef with a server-issued uid.
- [x] Pure `GachaMath`: `pick` (weighted, deterministic on a [0,1) roll), `filterByMinRarity`,
  `nextPity`, `resolveRecruit`. Drop odds published in-UI (aggregated per rarity).

### 9.3 Equip / inventory / fusion
- [x] Profile v3: `chefs`, `equippedChefs`, `pity`, `nextChefUid` (+ migration `[2]`).
- [x] `ChefService` equip/unequip with a slot cap that grows on total prestige
  (`ChefMath.equipSlots`, the M7→M8 tie), and fusion (`CHEF_FUSION_DUPES` dupes → +1 level,
  burning least-valuable copies first). All server-validated + idempotent.
- [x] Client: `ChefController` aggregates equipped passives at level start; `ChefUIController`
  is a data-driven Chefs panel (recruit w/ odds, collection, equip/unequip, fuse).
- [x] Pure `ChefMath`: passive aggregation (mult stacking, independent burn-immunity, OR
  autoServe), level/shiny scaling, equip slots, fusion cost. 31 new specs.

**Verification (Studio, Rojo-synced):** clean Schema-validated boot; full suite **116/116**
(+31 over M7's 85). End-to-end integration confirmed against a controlled profile: recruit
charges cost + mints chef + advances pity; equip enforces the 3-slot cap and grows to 5 at
prestige 2; fusion consumes 3 dupes → level 2 and re-gates on too few dupes; aggregated
passives reflect the leveled chef.

**Reserved:** in-world chef models (`Chef.model`) aren't spawned yet (passives are fully
live; model rendering needs assets + world layout — see HANDOFF M8 notes).

---

## 8. M7 — Meta-progression spine: Recipe Mastery + Restaurant Prestige `[milestone:M7]` — DONE

First incremental-growth milestone. Both systems are formula + config (no authored
content) so they multiply the value of every restaurant the generator already produces.

### 8.1 Recipe Mastery
- [x] `Config/Mastery.lua` — one global default curve (`defaultThresholds` +
  `defaultPerLevelBonus`) covering every recipe, with sparse per-recipe `overrides` and a
  pure `resolve(recipeId)`. Adding a recipe needs zero mastery config.
- [x] Profile field `mastery = { [recipeId] = { level, xp } }` (DataService v2 + migration).
- [x] `EconomyMath` mastery math: `masteryLevel`, `masteryTipMult`, `masteryCookSpeedMult`,
  `masteryMult`; `serveValue` extended with an optional `earningsMult`. All pure + tested.
- [x] **Server is the only writer.** Client tallies serves per recipe (`LevelController.serves`)
  and submits them in `SubmitLevelResult`; server clamps each to the roster
  (`EconomyMath.rosterRecipeCounts`) and `MasteryService:applyServes` grants XP.
- [x] UI: per-dish mastery level + progress bar in the Shop panel (Recipe Mastery section).
- [ ] *Reserved:* `cookSpeed` mastery bonus math exists/tested but isn't wired to live
  stations yet (shared cook-step ownership needs a design pass — see HANDOFF M7 notes).

### 8.2 Restaurant Prestige (Franchise)
- [x] `Config/Prestige.lua` — curve params only (`coinMultPerLevel`, `tokensBase`,
  `tokensPerLevel`, `maxLevel`, `equipSlotsPerLevel` hook for M8).
- [x] `EconomyMath.prestigeMultiplier` / `prestigeTokenGrant` (pure + tested).
- [x] Profile fields `prestige = { [restaurantId] = level }`, `prestigeTokens`.
- [x] `ProgressionService:franchise` — validates every level is 3-starred, resets that
  restaurant's stars + its stations' upgrades, bumps prestige, grants tokens; behind the
  new `FranchiseRestaurant` remote. **Scope: per-restaurant** (roadmap recommendation).
- [x] Earnings ceiling stays exact: `theoreticalMax` now folds in the player's real mastery
  (`masteryMultFn`) + prestige (`globalMult`) so the server validates the boosted coins
  without trusting the client.
- [x] UI: Franchise button per restaurant (enabled only when fully 3-starred) + prestige
  level / earnings multiplier display + Prestige Token balance in the Shop panel.

**Verification:** `rojo build` compiles the whole project (all new files parse). The 23 new
EconomyMath mastery/prestige assertions pass (run inline against the real implementations
in Studio Edit; PASS=23 FAIL=0). A live in-avatar franchise/mastery playthrough is pending
a Rojo connect — the live Studio tree wasn't synced this session.

---

## 7. TestEZ specs cannot be run directly via `execute_luau` `[tech-debt]` — DONE

The specs in `tests/` use bare `describe`/`it`/`expect` globals that TestEZ injects via `setfenv`. The earlier blocker was the lack of a runner, not the language — `setfenv` works fine in Studio (verified). Rather than vendor the full TestEZ library, a minimal runner provides the slice of the DSL the specs actually use.

- [x] Added `tests/TestRunner.lua` (synced to `ServerStorage.Tests.TestRunner`) — a minimal TestEZ-compatible runner (`describe`/`it`/`expect(x).to.equal(y)`/`.to.be.ok()`) that `setfenv`-injects the DSL and runs every sibling `*.spec` module. `runAll()` reports pass/fail. Current suite: 63/63 pass.
- [x] Documented `run tests` steps in the README (Testing section).
