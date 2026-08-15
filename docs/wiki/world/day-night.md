---
shelf: world
updated: 2026-08-15
---

# Day/Night

The arena is a **night-first world** (owner direction, 2026-07-22): fireworks, the
glowing mawari-dōrō, chōchin, water features are the main stage; day is a short
bright interlude. The cycle foundation and its subscriber families are committed
(`411c3e0`, `0c44f11`, `9fe5479` + the 2026-08-02 subscriber wave).

## The foundation

`src/shared/DayNight.luau` (pure, Lune-tested) + `DayNightController.client.luau` +
`EventBus.DayNight`; the server publishes `ReplicatedStorage.DayNightConfig`
attributes at boot. Phases: dawn 0.00–0.10, day 0.10–0.28, dusk 0.28–0.53, night
0.53–1.00; `CycleLength` default 600 s; global sync via
`t = ((GetServerTimeNow() − CycleEpoch)/CycleLength + PhaseOffset) % 1` with a
**fixed absolute epoch** — never per-server boot time. `nightFactor` is the one knob
subscribers use; `DayNightConfig.CurrentNightFactor` is the late-subscriber backstop.

**Scope ruling (owner, repeated corrections — binding):** the system does three
things ONLY — set `Lighting.ClockTime` on the night-dominant schedule, fire the
signal, keep global sync. It must NEVER touch Brightness / Ambient / OutdoorAmbient /
Fog / ColorCorrection — a mood-table approach dimmed everything and was scrapped.

Test knobs: `Workspace.DayNightLockT` freezes the cycle (0.19 mid-day, 0.40 dusk,
0.70 night). Live values verified 2026-08-15: `DayNightLockT = 0.19`,
`PreNightTestLockT = 0.19`, `DayNightStartT` cleared. The publish requirement lives
on [[place-state]].

## Subscribers

- **Night glyphs** (`GlyphDayNight.client.luau` + `Glyphs.buildNightNeon`): day =
  gold SurfaceGui glyphs; night = **extruded solid Neon meshes** of the same glyphgen
  shapes (R ring `134649637477578`, P bar `113127066887467`, S caret
  `93306116397070`), color (179,130,108), live-tunable, riding the drum's spin set.
  Two dead ends are recorded so they aren't retried: a SurfaceGui can never bloom
  (capped below the Bloom threshold), and Neon + SurfaceAppearance glows the
  ColorMap's own color, ignoring Part.Color. The distance bug's true cause: a
  GroupTransparency-faded SurfaceGui still draws beyond ~120 studs — flip `Visible`
  when fully faded.
- **Lanterns** (`src/shared/LanternGlow.luau`): profile `stone` (yamadoro) goes
  fully out by day; profile `paper` (chōchin + deck/newel lanterns) **never goes
  out**, because the lantern telegraph is a game display players read
  ([[viewing-platform]]).
- **Water VFX** (`src/shared/VfxNightDim.luau`): 135 objects across BOTH
  `CanyonWorld.Arena` and `CanyonWorld.Water` (an Arena-only scan silently misses
  the river runs). **The lever is `LightInfluence`, lerped toward 0.75** — dimming
  Brightness alone is visually undetectable at `LightInfluence 0`, and influence
  must be lerped, never scaled (authored is 0). Owner: "looks great at dusk."
  Water VFX dim at night; only the glyphs brighten.
- Sky ambient floor for the trail lanterns: `17bbb08` ([[paths]]).

## Gates & decisions

- 2026-07-22 owner: night-first framing; scope ruling above.
- Glyph geometry path B chosen (pure Neon meshes) over baked-ColorMap templates —
  the owner needs live color tuning; the first hand-built geometry was rejected for
  wrong sizes, not the concept.
- Planned reuses of the dragon-king carvings (eye-level named gallery; a Robux-only
  8-sided "magic lamp" deck item) are captured on [[backlog]].

## Raw layer

- spec/plan: `docs/superpowers/specs/2026-07-22-day-night-cycle-design.md`,
  `docs/superpowers/plans/2026-07-22-day-night-cycle-foundation.md`
- key commits: `411c3e0` core · `9fe5479` controller · `400262b` night-glyph
  checkpoint · `9503859` pierced panels ([[arena-square]]) · `17bbb08` night floor
