# CLAUDE.md — Cooking Rush

Roblox time-management cooking game (Cooking Fever-inspired). M0–M6 complete:
data-driven engine, generated levels, economy, persistence, upgrades, 2nd restaurant.
Current work: phases P0–P6 in `ROADMAP.md` / `tasks/`.

## Reference docs (read only what the current task cites)
- `docs/COOKING_GAME_SPEC.md` — engine architecture, schemas, conventions
- `docs/FASTFOOD_CONTENT_AND_LEVELS.md` — restaurant #1 content + balance values
- `docs/COOKING_GAME_ROADMAP_M7-M12.md` — system designs for meta-progression
- `docs/FRONTPAGE_WORKFLOW_P0-P6.md` — audit + phase rationale

## Non-negotiable pillars (violating these fails the task)
1. **Engine generic, content data.** New restaurants, levels, chefs, events, cosmetics,
   quests = config entries in `Shared/Config/`. If a feature needs per-content Luau
   branches, stop and redesign the schema instead.
2. **Server-authoritative economy.** Clients send intents; server computes truth. All
   currency/drops/grants/trades happen in server Services, validated and idempotent.
3. **Pure logic stays pure.** `EconomyMath`, `LevelGenerator`, `IdleMath`, prestige/
   mastery formulas, drop rolls: no Roblox APIs, fully unit-tested in `tests/`.
4. **Tweak, don't fork.** Never copy-paste a system for a variant. Parameterize.
5. **Phone-first.** Every UI/interaction must work one-handed on a small touchscreen
   with large hit targets. Perf budget: 60fps on low-end mobile, in-kitchen draw calls
   < 300, pooled customers/VFX.

## Conventions
- Luau `--!strict` everywhere; types exported from `Schema.lua`/`Enums.lua`.
- Every config table validated by `Schema.lua` on server boot — extend the validator
  whenever you add/extend a schema.
- No magic numbers in systems; constants live in `GameConfig.lua` or the owning config.
- Runtime entities clean up via Trove; zero leaked connections between levels.
- Remotes defined only in `Shared/Remotes.lua`; never trust client values for money/time.
- Tests: snapshot model for generator output (run with pinned seed → human review →
  commit snapshot → assert). Never hand-author "expected" RNG output.
- DataStore: profiles are session-locked, versioned, reconciled with defaults on load.
  Use the `dev` namespace unless explicitly told to touch production.

## How to work
1. Open `ROADMAP.md`, find the first unchecked task in the active phase, open its task
   file in `tasks/`. Work **one task at a time**.
2. A task is done only when every Acceptance criterion passes and tests are green.
3. On completion: check the box in `ROADMAP.md`, commit with message `P<phase>.<task>: <summary>`.
4. If a task conflicts with a pillar or a schema can't express the content, do not hack
   around it — write the conflict into `ROADMAP.md` under "Blocked/Decisions" and stop
   that task.
5. Do not start tasks from a later phase while the current phase has unchecked exit
   criteria, unless the task file marks it parallel-safe.

## Definition of done (every task)
- [ ] Schema validation passes on boot
- [ ] Unit/snapshot tests added or updated, all green
- [ ] No new magic numbers in system code
- [ ] Works on a phone-sized viewport (if UI/interaction touched)
- [ ] Server authority preserved (if economy/data touched)
- [ ] ROADMAP.md updated
