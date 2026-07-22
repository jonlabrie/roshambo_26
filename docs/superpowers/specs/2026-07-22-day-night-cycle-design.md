# Day/Night Cycle — Design Spec

**Date:** 2026-07-22
**Branch:** `m4b-zendojo-art-pass`
**Status:** Design — awaiting user review
**Builds on:** the milestone-4a client `EventBus` (`roblox/src/client/EventBus.luau`) and the DI/Lune-safe module pattern (pure logic in `src/shared`, Roblox types injected by the `*.client.luau` / `main.server.luau` entries).

## Summary

A **server-authoritative, continuous, night-dominant** day/night cycle for the ZenDojo arena. The server owns one shared clock; every client derives the same cycle phase locally and renders Lighting from it, then publishes a single normalized **`nightFactor` ∈ [0,1]** on the client EventBus. Visual systems (glyph gilt↔glow, waterfall foam/turbulence dimming, and later fireflies/lanterns/fireworks) subscribe to that one number and interpolate their own look — so the whole arena transforms in lockstep as dusk falls, at near-zero cost.

This is **foundation infrastructure.** It ships the cycle + the `nightFactor` contract. The subscribers (glyphs, falls, …) are separate follow-on specs that bind to the contract defined here.

## Why night-dominant

The arena is a **night-first world**: fireworks, the glowing revolving lantern, chōchin, fireflies, and the water features are the main stage, and all read best after dark. Day is a short, bright interlude that shows off the gilt glyphs and the garden in sunlight and makes nightfall feel earned. So night is the *primary* state by design, not the exception.

## Goals / non-goals

**Goals:** one shared clock for all players; a continuous loop with a long night; a single clean signal (`nightFactor`) other systems bind to; a pure, Lune-tested phase→look mapping; zero per-frame network traffic.

**Non-goals:** gameplay effects (purely visual/ambient — the World Throw is unaffected); per-player time; weather; a settings UI. The cycle does not gate or alter round logic.

## Architecture — three pieces, clean boundaries

### 1. `DayNight.luau` (new, `src/shared/`) — the pure core

Lune-safe: no `Instance`/`Color3`/`Enum` at module scope or in its functions; colors are `{r,g,b}` arrays (0–1), everything else numbers/tables. Holds:

- **`DayNight.PHASES`** — the tunable proportions table, as `t`-fractions of one loop (`t ∈ [0,1)`, uniform time). Starting values:
  | phase | `t` range | share | `nightFactor` |
  |-------|-----------|-------|---------------|
  | dawn  | `[0.00, 0.10)` | 10% | ramps **1 → 0** (smoothstep) |
  | day   | `[0.10, 0.28)` | 18% | `0` |
  | dusk  | `[0.28, 0.45)` | 17% | ramps **0 → 1** (smoothstep) |
  | night | `[0.45, 1.00)` | 55% | `1` |
- **`DayNight.phaseAt(t) -> { nightFactor: number, phase: string }`** — pure; `phase ∈ {"dawn","day","dusk","night"}`; `nightFactor` smoothstepped across dawn/dusk so it is continuous and monotonic within each transition.
- **`DayNight.lightingAt(t) -> LightingState`** — pure; returns plain data the client applies to `Lighting`: `{ clockTime, brightness, outdoorAmbient={r,g,b}, ambient={r,g,b}, fogEnd, fogColor={r,g,b}, ccTint={r,g,b}, ccBrightness }`. `clockTime` is mapped through the phase bands (not linear in `t`) so the built-in sun/moon position matches the night-dominant schedule.

### 2. `DayNightController.client.luau` (new, `src/client/`) — the renderer

Per frame (`RunService.RenderStepped`, throttled to ~10 Hz for the Lighting writes; `nightFactor` published only when it changes by ≥ ε):
1. Read shared config (below) → compute `t = ((workspace:GetServerTimeNow() − epoch) / length + offset) % 1`.
2. `local look = DayNight.lightingAt(t)` → apply to `Lighting` (+ its `Atmosphere`/`ColorCorrection` children; create them once if absent). Toggle a moon/stars state for the night band.
3. `local ph = DayNight.phaseAt(t)` → `EventBus.DayNight:Fire({ t = t, nightFactor = ph.nightFactor, phase = ph.phase })` on change.

All Roblox types (`Lighting`, `workspace`, `RunService`, `EventBus`, `Color3.new`, `Enum`) are injected/looked-up here, never in `DayNight.luau`.

### 3. Server (`main.server.luau`) — owns the truth

At startup, publish the cycle config **once** as attributes on a `Configuration` instance in `ReplicatedStorage` (e.g. `ReplicatedStorage.DayNightConfig`): `CycleEpoch` (= `workspace:GetServerTimeNow()` at boot, or a fixed value so restarts don't jump), `CycleLength` (seconds, starting **1200** = 20 min), `PhaseOffset` (starting fraction; lets us boot the world into night). The server streams **nothing** afterward — clients read these attributes + the shared `GetServerTimeNow()` clock and derive `t` themselves. Server-authoritative because the server solely owns epoch/length/offset; perfectly synced because `GetServerTimeNow()` is a shared server clock.

## The contract (design once — everything binds to this)

Add **`"DayNight"`** to the `NAMES` list in `src/client/EventBus.luau`. The channel carries:

```
EventBus.DayNight:Fire({ t: number, nightFactor: number, phase: string })
```

- **`nightFactor ∈ [0,1]`** — `0` full day, `1` deep night, smooth through dawn/dusk. **The main knob** subscribers use.
- `phase ∈ {"dawn","day","dusk","night"}` — for systems that want discrete behavior (e.g. spawn fireflies only in `night`).
- `t ∈ [0,1)` — raw cycle position, for anything needing the full curve.

Subscriber usage (illustrative — these are separate specs):
- **Glyph gilt↔glow:** Neon-layer `Transparency = 1 − nightFactor` (crossfades gilt Metal → warm Neon at dusk).
- **Waterfall foam/turbulence:** `emitterBrightness = lerp(dayBright, nightBright, nightFactor)`.

Late subscribers get the current value immediately: the controller caches the last payload and re-fires it to a newly-connected listener (or exposes `DayNightController.current()`), so a controller that starts after dusk isn't stuck at the default until the next change.

## Lighting targets (starting mood — tuned at the gate)

- **Day:** `clockTime ≈ 13`, `brightness ≈ 2`, bright neutral ambient, long clear fog. Gilt glyphs catch the sun.
- **Dusk/Dawn:** warm amber ambient, `clockTime` sweeping 17→19 / 5→7, fog warms and closes slightly.
- **Night:** `clockTime ≈ 0`, `brightness ≈ 0.4`, deep blue-grey ambient (moonlit, **not** pitch black — playability), cool `ColorCorrection` tint, closer fog. Dark enough that the lantern glow, chōchin, and fireworks carry the scene.

## Files

- **New:** `roblox/src/shared/DayNight.luau` (pure core), `roblox/src/client/DayNightController.client.luau` (renderer), `roblox/tests/DayNight.spec.luau` (Lune).
- **Modify:** `roblox/src/client/EventBus.luau` (add `"DayNight"` to `NAMES`), `roblox/src/main.server.luau` (publish `ReplicatedStorage.DayNightConfig` attributes at boot), `roblox/src/main.client.luau` (start `DayNightController`). If `DayNightConfig` must replicate, add it to `default.project.json`.

## Testing

- **Pure/deterministic (Lune, `DayNight.spec.luau`):** `phaseAt(t)` returns the right `phase` in each band; `nightFactor` is exactly `1` in night, `0` in day, monotonic across dawn (1→0) and dusk (0→1), and continuous at every band boundary (no jump); proportions sum to 1. `lightingAt(t)` returns in-range values and a `clockTime` that moves monotonically through each band. Table-driven over sampled `t`.
- **Runtime (Play-gated):** all clients derive the same `t` from `GetServerTimeNow()` (compare two clients); Lighting visibly cycles; `EventBus.DayNight` fires with a moving `nightFactor`; a late-joining subscriber receives the current value. Full loop shortened via a small `CycleLength` for the gate, then restored.

## Scope boundary

Ships the cycle + the `nightFactor` contract **only**. It takes over `Lighting` (today static at `ClockTime 14`). It does **not** build any subscriber — the glyph gilt↔glow pass and the waterfall night-dimming pass are separate specs that consume `EventBus.DayNight`. No gameplay change.

## Open decisions (resolve at spec review / gate)

- Exact `CycleLength` and phase proportions (starting 20 min / 55% night) — dial in Play.
- Boot phase (`PhaseOffset`) — start the world at night, dawn, or day?
- `CycleEpoch` fixed vs per-boot (does a server restart reset the time-of-day, or continue from a fixed origin?).
- Whether to drive `Atmosphere` (haze/density) in addition to legacy `FogEnd`, and moon/stars handling.
- Throttle rates (Lighting write Hz, `nightFactor` ε).
