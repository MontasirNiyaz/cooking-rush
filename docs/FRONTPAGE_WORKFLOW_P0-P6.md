# Cooking Rush — Front-Page Workflow (Audit + Phases P0–P6)

Supersedes the sequencing in `COOKING_GAME_ROADMAP_M7-M12.md` (the systems in that doc
remain valid; this document re-orders them and inserts the missing Roblox-native layer).
Read after `COOKING_GAME_SPEC.md` and `FASTFOOD_CONTENT_AND_LEVELS.md`.

---

## Part 1 — Audit of the current design (M0–M6 + roadmap docs)

### A. Strategic gaps (front-page blockers)

| # | Gap | Why it blocks front page |
|---|---|---|
| 1 | **No 3D world.** The design is a screen/menu flow (map → level select → level). | Roblox hits are *places*. Players expect to walk a world, see their restaurant as a building, see other avatars. A "mobile game embedded in Roblox" reads as cheap and churns instantly. |
| 2 | **Slow time-to-fun.** Menus + 3-level tutorial before mastery of one dish. | Front-page games put the core verb in the player's hands in 10–20 seconds. Most churn happens in the first minute. |
| 3 | **Social invisible until M11.** | Visible other-player progress (their kitchen, their chefs, their prestige) is a core motivator in every top earner and costs little to surface early. |
| 4 | **No telemetry.** | Roblox's discovery algorithm ranks heavily on D1/D7 retention, session length, and monetization quality. Without funnel analytics you are tuning blind. |
| 5 | **Game feel orphaned.** Original spec parked "juice" in M7-Polish; the roadmap overwrote M7 with Mastery/Prestige. | Sound, hit-feedback, coin pops, serve VFX are not polish — they are the perceived quality bar that decides first-minute retention. |
| 6 | **No mobile performance budget.** | The majority of Roblox players are on phones. A cooking game with many animated customers + VFX must hit 60fps on low-end devices or ratings tank. |
| 7 | **No discovery/ops plan.** Icon/title CTR, soft launch, content cadence. | Front page is earned through algorithm metrics + click-through + weekly updates, not just game quality. |

### B. Defects in the previous documents (own and fix these)

1. **Golden-test design flaw** (`FASTFOOD_CONTENT_AND_LEVELS.md` §7): the levels 4/10/20
   rosters were hand-written, then specified as equality targets for the seeded generator.
   A real RNG stream will not reproduce hand-invented decimals. **Fix:** treat those tables
   as *design-intent references* for tuning only. Replace equality tests with **snapshot
   tests**: run `LevelGenerator.generate` with a pinned seed, human-review the output
   against the design intent, commit the actual output as the snapshot, assert against it
   thereafter. Regression safety preserved, fiction removed.
2. **Milestone collision:** original spec M7 = Polish; roadmap M7 = Mastery/Prestige.
   **Fix:** retire the old M7-Polish label. Game feel is now Phase 1 work (below), not a
   deferred milestone. Roadmap M7–M12 keep their names but are re-sequenced into phases.
3. **Tutorial pacing:** 3 gated tutorial levels is mobile-style onboarding. Compress to an
   in-world, interruptible flow (Phase 1.2). Levels 1–3 remain as authored content but the
   *teaching* must not block play.
4. **Dispenser multi-output change** (already flagged in the content doc) — confirm it
   landed in the engine; it is a dependency for every future restaurant.

---

## Part 2 — Workflow P0–P6

Phases are sequential; tasks inside a phase can parallelize. Roadmap systems (M7–M12) are
slotted where they earn their keep. Each phase ends with a measurable exit criterion.

---

### P0 — Foundation fixes (small, do first)
- Convert golden tests → snapshot tests (B1). Re-pin all three snapshots.
- Verify multi-output Dispenser merged; schema-validate on boot.
- Add `GameConfig.lua` constants for everything still hardcoded.
- Set up a `dev` place + `production` place; DataStore namespacing per environment.

**Exit:** test suite green with snapshot model; dev/prod separation works.

### P1 — Roblox-native core (the biggest lift, the biggest payoff)

**1.1 Hub world.** One streamed map: a food-court plaza. Each restaurant is a physical
building; the player's owned restaurants show *their* upgrade/prestige state (signage,
decor tier) — visible to every player on the server. Walk up to a door → start a level.
World replaces the map/level-select menus (level select becomes a board at the door).
- Engine note: hub is a `HubService` + per-building `RestaurantPlot` model bound to the
  same restaurant configs. No per-restaurant world code; building visuals keyed by config id.

**1.2 Instant-start onboarding.** New player spawns *inside* the FastFood kitchen with one
customer already walking up and a single highlighted grill. Cooking within ~15s. Teaching
is contextual highlights + one-line prompts (a `TutorialController` driven by a step table
in config), interruptible, never a modal wall. Levels 1–3 content stays; the gating goes.

**1.3 Interaction & camera model.** Define once, generically: stations are tap/click
targets (ProximityPrompt or direct click — pick by playtest) with large mobile hit-boxes;
fixed isometric-ish kitchen camera during levels (readability beats free-cam); one-hand
portrait-friendly layout is non-negotiable.

**1.4 Game feel pass (the orphaned polish).** Per-event juice table in config:
serve → coin burst + chime + tip popup; combo → escalating pitch + screen pulse;
burn → smoke + sad trombone; star earned → confetti. Centralize in a `JuiceService`
reading an `Effects.lua` config so designers tune feel without code.

**1.5 Mobile performance budget.** Targets: 60fps on low-end (test on a ~3-year-old
Android), <300 draw call budget in-kitchen, customer models pooled and LOD'd, VFX through
a pooled emitter system. Add a perf checklist to CI notes.

**Exit:** a new player on a phone is cooking within 15s of spawn, in a 3D world where
other players' restaurants are visible, at 60fps.

### P2 — Telemetry & funnel
- Integrate Roblox AnalyticsService custom events: funnel (spawn → first interact → first
  serve → first level complete → D1 return), economy sinks/sources, level fail points,
  session length.
- A `TelemetryService` wrapper so events are one-liners everywhere.
- Define the dashboard you'll actually read: D1/D7 retention, avg session, first-session
  funnel conversion, level-N drop-off curve.

**Exit:** every funnel step emits; you can answer "where do players quit" with data.

### P3 — Meta-progression spine (roadmap M7 + M8, re-scoped)
- **Mastery + Prestige (M7)** as specced — now with prestige state *visible in the hub*
  (building upgrades, signage) so progression is social currency.
- **Chefs (M8)** as specced — equipped chefs follow your avatar in the hub (the Adopt Me
  visibility trick: your collection *is* your status). Gacha + pity + fusion per spec.
- Daily quests + login streak (pulled forward from M10 — they're cheap and retention-critical).

**Exit:** a player always has ≥2 visible next-goals; D1 measurably improves vs P2 baseline.

### P4 — Soft launch & iteration loop
- Release publicly unlisted/low-key; drive a small wave of traffic (sponsored ads optional).
- Iterate weekly on the telemetry: fix the top funnel leak each cycle.
- A/B the icon + title + thumbnail (CTR is a ranking input you control cheaply).
- Tune economy from real sink/source data; run the economy-sim script against observed play.

**Exit criteria to advance (rough targets, refine against genre data):** D1 ≥ 30–35%,
median session ≥ 10 min, first-session funnel ≥ 60% reaching first level complete.
Do not scale spend or build P5 content velocity until these hold.

### P5 — Live-ops machine (roadmap M10 + content velocity)
- Seasonal/limited restaurants via the `availability` schema; season pass; leaderboards.
- **Cadence commitment:** one content beat per week (new restaurant, event, or chef batch).
  The data-driven engine exists precisely to make this a config-authoring exercise —
  budget ~1 day/week of authoring, not engineering.
- Build the second restaurant (Sushi) and third here if not already shipped — each is the
  M6 test: config + assets only.

**Exit:** two consecutive weekly updates shipped with zero engine changes.

### P6 — Social economy & monetization (roadmap M9 + M11 + M12)
- Idle empire (M9) — now that hub buildings exist, idle income is *spatial* (collect at
  your buildings).
- Trading (M11) with the guardrails specced (account-age gate, untradeable event flags,
  idempotent server grants).
- Monetization (M12): cosmetics + convenience per spec. Note: ship a *small* cosmetic
  store earlier (P3) — modest early monetization signals quality to the algorithm and
  funds ads; P6 is the full build-out, not the first dollar.

**Exit:** trading live without economy incidents for 2 weeks; ARPDAU positive without
any P2W complaints trending in reviews.

---

## Part 3 — Operating rules for the whole run

1. **The pillar still rules:** every new feature is generic engine + config content. The
   weekly cadence in P5 is only possible if P1–P3 never violate this.
2. **Retention before monetization before content volume.** Don't author restaurant #4
   while D1 is below target; fix the funnel instead.
3. **Phone-first always.** Every UI and interaction reviewed on a small touchscreen before merge.
4. **One metric owner per phase.** Each phase's exit criterion is checked against telemetry,
   not vibes.
5. **Server-authoritative economy discipline doubles in importance** at P6 — audit all
   grant paths for idempotency before trading ships.
