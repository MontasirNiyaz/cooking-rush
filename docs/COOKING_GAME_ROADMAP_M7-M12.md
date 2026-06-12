# Cooking Rush — Incremental Growth Roadmap (M7–M12)

Addendum to `COOKING_GAME_SPEC.md`. M0–M6 shipped a complete, scalable single-restaurant
loop (data-driven restaurants, generated levels, economy, persistence, upgrades). This
roadmap layers the **incremental-growth meta** that keeps players in the top Roblox games
returning for weeks instead of one session.

Every system below obeys the original pillars: **generic engine + content as data**,
**server-authoritative economy**, **pure testable logic**, **tweak don't fork**. If a new
system can't be expressed as a config schema + a generic system, redesign it until it can.

## Reference map (what we're borrowing and from where)

| System | Genre reference | Why it works |
|---|---|---|
| Prestige / rebirth | Pet Sim 99, Steal a Brainrot | Resets short-term progress for permanent multipliers → infinite ceiling on finite content |
| Collection + gacha (Chefs) | Adopt Me, Pet Sim 99 | Rarity tiers + hatch/recruit RNG drives the core dopamine + collection completion goals |
| Idle / passive empire | Steal a Brainrot, Bee Swarm | Income while offline turns session play into a hybrid idle loop, raises DAU |
| Layered progression tracks | Blox Fruits | Multiple parallel ladders (skill, collection, prestige, mastery) so no one runs out |
| Live-ops events / seasons | All top titles | Limited-time content + season pass = recurring re-engagement spikes |
| Trading + scarcity | Adopt Me, Pet Sim 99 | Player economy + limited items create social stickiness and self-sustaining value |
| Daily quests / streaks | All top titles | Cheap habit hooks; low build cost, high retention |
| Cosmetics / identity | Adopt Me | Ethical monetization sink that doesn't gate gameplay |

Design north star (from current top-performer postmortems): **monetize with the player,
not against them.** Power is earnable; money buys time and identity, not walls.

---

## M7 — Meta-progression spine: Mastery + Prestige

The cheapest, highest-leverage milestone. Makes all existing M0–M6 content infinitely
replayable before adding any new content type.

### 7.1 Recipe Mastery (grind ladder)
Cooking a dish accrues mastery XP. Mastery levels grant small permanent buffs to that dish.
- New config: `Mastery.lua` — `{ recipeId, thresholds = {xp...}, perLevelBonus = { tipMult? , cookSpeed? } }`.
- New profile field: `mastery = { ["cheeseburger"] = { level, xp } }`.
- `EconomyMath` already computes serve value — extend it to fold in mastery bonus.
- Server is the only writer; client reports serves, server increments mastery.
- UI: a mastery bar per dish on the restaurant menu screen + completion %.

### 7.2 Restaurant Prestige (reset-for-multiplier loop)
Once a restaurant is 3-starred to completion, the player can **Franchise** it: reset its
level stars/upgrades in exchange for a permanent **Prestige Multiplier** on all future
earnings from that restaurant, plus a slice of **Prestige Tokens** (new soft-premium
currency between coins and gems).
- New config: `Prestige.lua` — formula params only (curve constants), not per-restaurant code.
- `EconomyMath.prestigeMultiplier(prestigeLevel) -> number` (pure, unit-tested).
- New profile fields: `prestige = { ["fastfood"] = level }`, `prestigeTokens`.
- `ProgressionService` owns the franchise transaction (validate completion → reset → grant).
- **Decision to confirm with design:** prestige scope = per-restaurant (recommended, like
  Pet Sim zone prestige) vs whole-account rebirth. Per-restaurant is more forgiving and
  layers better with the chef system in M8.

**Scalability note:** both systems are formula + config. No new content is authored; they
multiply the value of every restaurant the generator already produces.

---

## M8 — Chef Collection & Recruitment (the "pet" system)

The headline engagement system. Chefs are this game's pets: collectible, rarity-tiered,
equip-able, and they grant passive bonuses. This is what makes the game *a Roblox game*.

### 8.1 Chef data
New config `Chefs.lua`:
```lua
type Chef = {
    id: string,
    displayName: string,
    rarity: "Common"|"Uncommon"|"Rare"|"Epic"|"Legendary"|"Mythic",
    model: string,                 -- follows player / shown in kitchen
    passives: {                    -- composable effect tags
        cookSpeedMult: number?,    -- speeds Cooker archetype
        tipMult: number?,
        autoServe: boolean?,       -- auto-delivers a ready dish periodically
        burnImmuneChance: number?, -- ignores burn timer sometimes
    },
    shinyChance: number,           -- variant for collection chase
}
```
Passives are **effect tags consumed by existing systems** (StationController reads
`cookSpeedMult`, OrderController reads `autoServe`). Adding a chef = a config row; the
engine already knows how to apply every tag. New tags are the only code touch.

### 8.2 Recruitment (gacha) — `RecruitService` (server, authoritative)
- New config `RecruitCrates.lua`: `{ id, cost = {coins?|gems?}, dropTable = { {chefId, weight} } }`.
- Server rolls with a seeded, **server-side** RNG — clients never compute drops.
- **Pity system** (industry standard, retention + fairness): guaranteed rarity floor after
  N pulls without a high-tier. Store `pityCounter` on profile.
- Publish drop rates in-UI (platform policy + player trust).

### 8.3 Equipping & inventory
- Profile: `chefs = { {uid, chefId, shiny, level} }`, `equippedChefs = {uid, uid, ...}` with
  an equip-slot cap that grows via prestige (ties M7 → M8).
- `ChefController` (client) renders equipped chefs in-kitchen and applies passive tags to
  the active level at start.
- Duplicate chefs feed a **fusion/level-up** sink (merge dupes → stronger chef), draining
  the collection so the gacha keeps meaning something.

**Scalability note:** one generic Chef entity + effect-tag system. A 200-chef roster is a
data file. Fusion, pity, and drop tables are all config-tunable without engine edits.

---

## M9 — Idle / Passive Empire

Converts owned-but-idle restaurants into an offline income engine — the loop that lifts
DAU and gives prestige tokens/chefs somewhere to compound.

- Assign equipped/benched chefs to **auto-run** a restaurant; output scales with chef
  passives + prestige multiplier + mastery.
- `IdleService` (server): compute accrued earnings from `lastCollect` timestamp on join,
  capped by an offline-cap (e.g. 8h) that upgrades extend — a clean gem/robux sink.
- Pure `IdleMath.accrue(state, elapsed) -> earnings` (unit-tested, no Roblox API).
- "Collect" UI on the world map with the satisfying number pop these games rely on.
- Anti-exploit: server clamps `elapsed` to real session/timestamp deltas; never trust client clock.

**Scalability note:** idle yield is derived from existing per-restaurant config +
chef tags. No new per-restaurant authoring.

---

## M10 — Live-Ops: Events, Seasons, Quests, Leaderboards

The recurring re-engagement layer. The data-driven engine makes this nearly free — a
limited-time restaurant is just a restaurant config with a time window.

### 10.1 Events & limited restaurants
- Extend `Restaurant` schema with optional `availability = { startUtc, endUtc }` and
  `eventCurrencyId`. A holiday restaurant = one config file that auto-appears/expires.
- Event currency buys event-exclusive chefs/cosmetics → scarcity (Adopt Me playbook).

### 10.2 Daily quests + streaks — `QuestService`
- `Quests.lua`: templated objectives (`serve N dishes`, `3-star X`, `recruit a chef`)
  with a generator that rolls a daily set scaled to player progress.
- Login streak counter with escalating rewards; resets on miss (habit hook).

### 10.3 Season pass (Battle Pass)
- `Seasons.lua`: free + premium track, XP from play, tiered rewards. Premium track is the
  primary ethical monetization (value, not gating).

### 10.4 Leaderboards — `LeaderboardService`
- OrderedDataStore-backed: global high score per restaurant, prestige level, collection %.
- Friends/server boards for social comparison.

**Scalability note:** every live-ops object is config + a generic runner. Shipping a new
seasonal event should require **zero new Luau logic** — the M6 test, extended.

---

## M11 — Social & Trading

Self-sustaining economy + social stickiness. Highest complexity/risk; sequence last among
gameplay milestones.

- **Trading** (`TradeService`, fully server-authoritative, both-confirm, anti-scam locks):
  trade chefs, cosmetics, prestige tokens. Never auto-execute; log every trade.
- **Co-op kitchens** (optional, the "social PvP-lite" analog): a shared rush-hour server
  event where players in a server contribute serves toward a community goal for shared
  rewards — collaborative, not predatory, which fits the cooking theme better than a
  "steal" mechanic.
- **Tradeability flags** on items (some event/exclusive items untradeable) to protect the
  economy from the start — retrofitting scarcity later is painful.

**Risk note:** trading invites scams and duplication exploits. Gate behind an account-age /
playtime check, rate-limit, and make every grant server-validated and idempotent.

---

## M12 — Monetization & Cosmetics (ethical)

Designed to respect the audience and the "monetize with the player" principle.

- **Cosmetic store:** restaurant decor themes, chef skins, plating/serve VFX, name colors.
  Pure identity, zero power. Driven by `Cosmetics.lua` config.
- **Convenience gamepasses:** larger offline cap, extra equip slots, auto-collect, 2x mastery
  XP. Time-savers, not walls — everything remains earnable free.
- **Gem bundles** as the premium-currency on-ramp.
- Hard rules: publish all gacha odds; no pay-to-win exclusives that close skill gaps; no dark
  patterns (fake timers, confusing currencies). The audience skews young — design as if a
  regulator and a parent are reading.

---

## Cross-cutting: keeping it scalable & healthy

1. **One new config schema per system, validated in `Schema.lua` on boot.** If a feature
   needs branching engine code per content item, it's mis-designed.
2. **All currency, drops, trades, and rewards are server-authoritative and idempotent.**
   Clients send intents; the server computes truth. This matters far more once trading exists.
3. **Pure-logic modules stay pure and tested:** `EconomyMath`, `IdleMath`, `LevelGenerator`,
   prestige/mastery formulas, drop-table rolling. These are where balance bugs hide.
4. **Balance is data, not code.** Keep every curve constant in config so designers tune
   without redeploys. Build a small internal "economy sim" script that fast-forwards a
   simulated player through M7–M9 to sanity-check progression pacing before launch.
5. **Layered ladders by design:** a player should always have one of {next star, next
   mastery level, next chef, next prestige, next quest, next season tier} within reach.
   That overlap is the actual retention engine.

## Suggested build order

M7 (spine) → M8 (chefs) → M9 (idle) → M10 (live-ops) → M11 (social/trading) → M12 (monetize).

Rationale: deepen existing content cheaply first (M7), add the core collection hook (M8),
give it a place to compound (M9), make re-engagement recurring (M10), then social/economy
(M11) and monetization (M12) once the loops are proven fun without spending.
