# ROADMAP — Cooking Rush P0–P6

Active phase: **P0**. Work top to bottom. Check boxes only when the task's acceptance
criteria all pass. Exit criteria gate the next phase.

## P0 — Foundation fixes (`tasks/P0.md`) — REVISED per ISSUES.md #8–#17
- [x] P0.1 Level-session validation: anti-farm + server-computed stars (CRITICAL)
- [x] P0.2 Remote rate limiting
- [x] P0.3 Profile session locking
- [x] P0.4 Dev/prod DataStore namespacing
- [x] P0.5 Real-config invariant + snapshot test suite
- [x] P0.6 Gate Studio auto-start behind DEBUG_AUTOSTART
- [ ] P0.7 Doc reconciliation (multi-output dispenser = won't-do)
- **Exit:** security specs green; two-server clobber test passes; real-config suite green; env split verified.


## P1 — Roblox-native core (`tasks/P1.md`)
- [ ] P1.0 Streaming-safe binding: CollectionService tags, StreamingEnabled=true (ISSUES #13 — prerequisite)
- [ ] P1.1 Hub world + RestaurantPlot system
- [ ] P1.2 Instant-start onboarding (cooking ≤15s from spawn)
- [ ] P1.3 Interaction + camera model
- [ ] P1.4 Game-feel pass (JuiceService + Effects.lua)
- [ ] P1.5 Mobile performance budget enforced
- **Exit:** new player on phone is cooking within 15s, in a hub showing other players'
  restaurant states, at 60fps on low-end device.

## P2 — Telemetry (`tasks/P2.md`)
- [ ] P2.1 TelemetryService wrapper
- [ ] P2.2 Funnel + economy + level-failure events
- [ ] P2.3 Metrics checklist doc (what we read weekly)
- **Exit:** every funnel step emits; "where do players quit" answerable from data.

## P3 — Meta-progression spine (`tasks/P3.md`)
- [ ] P3.1 Recipe Mastery
- [ ] P3.2 Restaurant Prestige (per-restaurant) + hub visibility
- [ ] P3.3 Chef collection: configs, RecruitService (gacha+pity), fusion, equip
- [ ] P3.4 Chefs follow avatar in hub + passive tags applied in levels
- [ ] P3.5 Daily quests + login streak
- [ ] P3.6 Starter cosmetic store (small)
- **Exit:** player always has ≥2 visible next-goals; D1 improves vs P2 baseline.

## P4 — Soft launch loop (`tasks/P4.md`)
- [ ] P4.1 Economy simulation script
- [ ] P4.2 Remote-tunable balance (config hot-values)
- [ ] P4.3 Weekly funnel-leak fix ritual (recurring, human+Claude)
- **Exit (human-checked):** D1 ≥ 30–35%, median session ≥ 10 min, ≥60% of first
  sessions reach first level complete.

## P5 — Live-ops machine (`tasks/P5.md`)
- [ ] P5.1 Event/limited availability runner
- [ ] P5.2 Season pass (free+premium tracks)
- [ ] P5.3 Leaderboards
- [ ] P5.4 Restaurant #3 as pure config (the recurring M6 test)
- **Exit:** two consecutive weekly content updates shipped with zero engine changes.

## P6 — Social economy & monetization (`tasks/P6.md`)
- [ ] P6.1 Idle empire (spatial collect at hub buildings)
- [ ] P6.2 Trading with guardrails
- [ ] P6.3 Full cosmetics + convenience gamepasses
- **Exit:** trading live 2 weeks with no economy incidents; no P2W complaints trending.

## Blocked / Decisions
(Claude Code: log pillar conflicts and open design questions here instead of hacking.)
- DECIDED: prestige scope = per-restaurant.
- DECIDED: Dispenser stays single-output; multi-item machines = one dispenser per item (ISSUES #16).
- DECIDED: shipped GameConfig values are balance truth; content doc is reference (ISSUES #17).
- OPEN: station interaction = ProximityPrompt vs direct click (P1.3 playtest decides).

## Traceability — M7–M12 designs & ISSUES #8–17 → phase tasks

The P0–P6 plan **re-sequences** the `docs/COOKING_GAME_ROADMAP_M7-M12.md` system designs
rather than building them in M-order: it front-loads the Roblox-native core (P1) and
telemetry (P2) — which have **no M7–M12 equivalent** — ahead of the meta-progression, and
splits the M10 live-ops bundle across P3 (quests/streaks) and P5 (events/seasons/boards).
Idle (M9) is deferred to P6 so it compounds an already-proven core loop.

### M7–M12 design milestones → phase tasks

| Design milestone (M7–M12 roadmap) | Phase task(s) | Notes |
|---|---|---|
| M7.1 Recipe Mastery | P3.1 | Formula + config; no authored content |
| M7.2 Restaurant Prestige (per-restaurant) | P3.2 | + hub visibility (P1 dependency); scope DECIDED per-restaurant |
| M8.1–8.2 Chef configs + Recruitment (gacha + pity) | P3.3 | RecruitService server-authoritative |
| M8.3 Equip / inventory / fusion | P3.3 | Equip-slot cap grows via prestige (M7→M8 tie) |
| M8 Chefs in-world (model/passives) | P3.4 | Chefs follow avatar in hub + passive tags applied in levels |
| M9 Idle / Passive Empire | P6.1 | Spatial collect at hub buildings; deferred behind core loop |
| M10.1 Events & limited restaurants | P5.1 | Availability window runner |
| M10.2 Daily quests + streaks | P3.5 | Habit hook pulled forward into the spine |
| M10.3 Season pass (free + premium) | P5.2 | |
| M10.4 Leaderboards | P5.3 | OrderedDataStore-backed |
| M11 Social & Trading | P6.2 | Trading with guardrails; co-op kitchens not yet scheduled in P0–P6 |
| M12 Cosmetics (identity) | P3.6 (starter), P6.3 (full) | Starter store small in spine; full set at P6 |
| M12 Convenience gamepasses / gem bundles | P6.3 | Time-savers, not walls |
| (M6 recurring test — restaurant #3 as pure config) | P5.4 | Not an M7–M12 system; the zero-engine-code regression test |

### ISSUES #8–17 → phase tasks

| Issue | Title | Phase task |
|---|---|---|
| #8 | `SubmitLevelResult` session tracking (coin-farm exploit) `[CRITICAL]` | P0.1 |
| #9 | Server recompute stars (don't trust client) | P0.1 |
| #10 | Remote rate limiting | P0.2 |
| #11 | Cross-server profile session locking | P0.3 |
| #12 | Dev/prod DataStore namespacing | P0.4 |
| #13 | Streaming-safe station/seat binding (P1 prerequisite) | P1.0 |
| #14 | Generator/economy tests against real configs | P0.5 |
| #15 | Gate the Studio auto-start hack | P0.6 |
| #16 | Dispenser multi-output — won't-do | P0.7 |
| #17 | Doc/config balance divergence — config is truth | P0.7 |
