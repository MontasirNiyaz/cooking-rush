# Cooking Rush

A time-management cooking game for Roblox, built on a **fully data-driven architecture**: adding a brand-new restaurant — its ingredients, recipes, stations, customers, and 40 levels — requires writing a single config file and **zero new engine code**.

The engine knows nothing about burgers or sushi. It knows about *archetypes* (a station that cooks, a station that dispenses, a station that assembles) and resolves everything else from data at runtime.

---

## Why data-driven?

Most cooking games hard-code each dish. Here, the entire content layer is declarative config under `ReplicatedStorage/Shared/Config/`, and a small set of pure-logic modules interpret it:

| Concern | Where it lives | Engine code needed to extend? |
|---------|----------------|-------------------------------|
| Ingredients & items | `Config/Ingredients.lua` | None |
| Recipes (cook / assemble graphs) | `Config/Recipes.lua` | None |
| Stations & their behaviour | `Config/Stations.lua` (`archetype` field) | None |
| Customer types & patience | `Config/Customers.lua` | None |
| Upgrade trees | `Config/Upgrades.lua` | None |
| A whole restaurant + its levels | `Config/Restaurants/<Name>.lua` | None |

The **M6 milestone** exists specifically to prove this: adding the *Sushi* restaurant is a config-only change.

---

## Station archetypes

Every station is one of three archetypes. Behaviour is selected by the `archetype` field in `Stations.lua` — the difference between a Grill and a Fryer is entirely data (`cookTime`, `burnTime`, `input`, `output`).

- **Cooker** — accepts a raw input, cooks it over `cookTime`, burns it after `burnTime`. Slot-based. (Grill, Fryer, Soup Pot, Fish Prep)
- **Dispenser** — produces an item on demand from finite `stock`, refilling over `refillTime`. Ingredient shelves use effectively-infinite stock. (Drink Dispenser, ingredient shelves)
- **Assembler** — collects a base + toppings and matches them against recipe steps to produce a finished dish. (Assembly Counter, Sushi Roller)

The player carries **one item at a time**. Interacting with a station either places the held item, picks one up, or does nothing — disambiguated by a two-value return `(outputItem: string?, consumed: boolean)`.

---

## Project structure

```
cooking-rush/
├── default.project.json          # Rojo project mapping
├── rokit.toml                    # Toolchain (Rojo 7.6.1)
├── src/
│   ├── ReplicatedStorage/Shared/
│   │   ├── Config/               # ── all game content lives here ──
│   │   │   ├── Ingredients.lua
│   │   │   ├── Recipes.lua
│   │   │   ├── Stations.lua
│   │   │   ├── Customers.lua
│   │   │   ├── Upgrades.lua
│   │   │   ├── GameConfig.lua
│   │   │   └── Restaurants/{FastFood, Sushi}.lua
│   │   ├── Modules/              # ── pure logic, no side effects ──
│   │   │   ├── RecipeResolver.lua   # item + steps → dish
│   │   │   ├── EconomyMath.lua      # serve value, combos, star ratings
│   │   │   ├── LevelGenerator.lua   # procedurally builds a restaurant's levels
│   │   │   ├── Schema.lua           # validates all config on boot
│   │   │   └── Enums.lua
│   │   ├── Packages/{Signal, Trove}.lua
│   │   └── Remotes.lua
│   ├── ServerScriptService/Server/
│   │   ├── init.server.lua
│   │   └── Services/             # DataService, EconomyService, LevelService,
│   │                             # ProgressionService, UpgradeService
│   └── StarterPlayer/StarterPlayerScripts/Client/
│       ├── init.client.lua
│       ├── Controllers/          # Level, Station, Customer, Order, Combo, UI
│       └── Entities/             # Station, Customer, Order, ItemStack
└── tests/                        # TestEZ specs (Economy, Recipe, LevelGenerator)
```

**Server is authoritative.** `EconomyService` is the only writer of coins/gems in the entire codebase; the client is never trusted for currency amounts.

---

## Tech stack

- **Luau** with `--!strict` throughout
- **[Rojo](https://rojo.space/)** 7.6.1 for filesystem ↔ Studio sync (managed via [Rokit](https://github.com/rojo-rbx/rokit))
- **TestEZ** for unit specs
- Lightweight **Signal** and **Trove** packages for events and cleanup

---

## Getting started

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then install the toolchain:
   ```sh
   rokit install
   ```
2. Start the Rojo server:
   ```sh
   rojo serve
   ```
3. In Roblox Studio, connect via the Rojo plugin, then press **Play**.

When running inside Studio, the client auto-starts FastFood level 1 after a short delay for convenience. The HUD shows coins, combo multiplier, the held item, and the level state. Walk up to a station (or a customer's seat) and press **E**.

> **Note:** the in-world kitchen (station Parts under `Workspace.Stations` and seats under `Workspace.Seats`) is built in the place file, not in source. Each station Part carries a `StationId` attribute that the client maps to its config. `Workspace.StreamingEnabled` must be **off** or the controllers won't see the Parts at startup.

---

## Testing

Unit specs live in `tests/` (TestEZ format) and cover the pure-logic modules — `RecipeResolver`, `EconomyMath`, and `LevelGenerator` — which contain all the rules and no Roblox side effects, so they're cheap to test in isolation.

---

## Roadmap

| Milestone | Scope | Status |
|-----------|-------|--------|
| **M0** | Project skeleton, full config layer, pure-logic modules, server/client stubs | ✅ Done |
| **M1** | Three station archetypes wired to 3D interaction; serve a cheeseburger end-to-end | ✅ Done |
| **M2** | Full level state machine (Intro → Playing → Results), patience meters, combo, timer, star calc | ⏳ Planned |
| **M3** | Wire `LevelGenerator` into `LevelController`; tune the 40-level difficulty curve; run specs | ⏳ Planned |
| **M4** | DataStore-backed profiles; server-side `SubmitLevelResult` validation; daily reward | ⏳ Planned |
| **M5** | Restaurant unlocks; upgrade trees applied as modifiers; Shop / Upgrade UI | ⏳ Planned |
| **M6** | Add the **Sushi** restaurant as pure config — proving zero engine code changes | ⏳ Planned |

See [`HANDOFF.md`](HANDOFF.md) for detailed architecture notes, design decisions, and the per-milestone implementation plan.
