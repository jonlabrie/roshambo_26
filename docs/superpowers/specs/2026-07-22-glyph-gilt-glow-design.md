# Glyph Gilt↔Glow — Design Spec

**Date:** 2026-07-22
**Branch:** `m4b-zendojo-art-pass`
**Status:** Design — approved, ready for writing-plans
**Builds on:** the day/night foundation (`EventBus.DayNight` + `nightFactor`, spec `2026-07-22-day-night-cycle-design.md`), the shared `Glyphs` module, and `DrumController` (which renders the glyphs onto the 12 spinning mawari-dōrō facets).

## Summary

The first **subscriber** to the day/night `nightFactor` signal. The World-Throw glyphs on the revolving lantern read **gilded gold by day** and **warm-amber glow by night**, crossfading with `nightFactor`. Today they use a `SurfaceGui` with `LightInfluence = 0` (always full-bright) → identical day and night; this makes them respond to the cycle so the tower "turns on" at dusk, its glowing glyphs seen spinning through the pierced dragon-king cutouts.

Purely visual/ambient; does not touch round logic, the drum's motion, or the day/night foundation. It only consumes `EventBus.DayNight`.

## Why this approach

The glyphs are flat `SurfaceGui` art on spinning parts, not materials — so "Metal ↔ Neon" isn't literal. The equivalent, and what we want, is a **crossfade between two full-bright renders**:
- **Day group** — the current approved look (gold core + ink outline).
- **Night group** — warm-amber core + a soft amber halo/bloom behind it.

Keeping `LightInfluence = 0` on the `SurfaceGui` means neither group darkens with the scene: the gold reads as gilt-on-cypress in daylight, and the amber reads as self-lit/glowing against the dark (faux-glow — **no real light is cast**, per the mobile-perf rules; the pierced dragons still show the bright glyphs behind them). The day↔night change is a pure transparency crossfade, not a lighting trick.

Each group is a **`CanvasGroup`** so its `GroupTransparency` fades the whole group as one composited layer — a clean dissolve, without overlapping semi-transparent sub-layers blending messily.

## Architecture

### 1. `Glyphs.luau` — `renderDayNight(parent, symbol) -> ()`

Adds a new builder alongside the existing `render` (which stays for other callers). It creates, under `parent` (the facet's `SurfaceGui`):

- a **Day `CanvasGroup`** containing the existing two-layer glyph (outline = ink, core = gold) — the current approved look, built from `Glyphs.IMAGE[symbol]`. `GroupTransparency = 0` initially.
- a **Night `CanvasGroup`** containing: a **halo** (the wider outline image scaled ~1.5×, tinted amber, partial `ImageTransparency` for a feathered bloom) behind an **amber core** (+ an amber/ink outline for definition). `GroupTransparency = 1` initially (hidden by day).

Both groups fill the canvas (aspect-locked like today, so the ○ ring stays round). Each group is tagged via `CollectionService` (tag `"GlyphDayNight"`) with an attribute `layer = "day" | "night"` so the subscriber can find + drive them. Colors are named constants in `Glyphs.luau` (`GOLD`, `INK`, `AMBER`, `AMBER_HALO`), tunable at the Play gate.

`Instance`/`Color3`/`CanvasGroup` usage stays confined to this function (the module remains Lune-safe: tests only touch `Glyphs.IMAGE` and the exposed palette constants).

### 2. `GlyphDayNight.client.luau` — the subscriber (new, standalone auto-run LocalScript)

Same pattern as `ChochinSway.client.luau` (nothing starts it). On startup it:
1. Reads the current value from `ReplicatedStorage.DayNightConfig:GetAttribute("CurrentNightFactor")` (or `0`) and applies it to any already-tagged groups.
2. Subscribes to `EventBus.DayNight` and, on each fire, applies `nightFactor` to all tagged groups:
   - `layer == "day"` → `GroupTransparency = nightFactor`
   - `layer == "night"` → `GroupTransparency = 1 − nightFactor`
3. Uses `CollectionService:GetInstanceAddedSignal("GlyphDayNight")` to apply the current `nightFactor` to groups created after startup (DrumController builds the glyphs at runtime, possibly after this script primes).

It never reads or drives the drum's motion — the groups ride the spinning facets automatically as children of the facet `SurfaceGui`s.

### 3. `DrumController.client.luau` — one-line change

Replace the per-facet call `Glyphs.render(gui, SYMBOL_FOR_FACE[k], GOLD, INK_OUTLINE)` with `Glyphs.renderDayNight(gui, SYMBOL_FOR_FACE[k])`. The `SurfaceGui` (still `LightInfluence = 0`), facet capture, and all motion are unchanged. The local `GOLD`/`INK_OUTLINE` constants there become unused for glyph rendering (the palette now lives in `Glyphs.luau`); remove them if nothing else uses them.

## Data flow

`DayNightController` (fires) → `EventBus.DayNight { t, nightFactor, phase }` → `GlyphDayNight` → `CanvasGroup.GroupTransparency` on the tagged Day/Night groups. During the day/night plateaus `nightFactor` is constant, so no updates fire; the crossfade happens only across dusk/dawn.

## Colors (starting values — tuned at the Play gate)

- **Day:** gold core `Color3.fromRGB(212, 176, 102)`, ink outline `(20, 17, 16)` (current).
- **Night:** amber core `~(255, 178, 92)`, amber halo `~(255, 146, 60)` at ~0.5 `ImageTransparency`, scaled ~1.5×. Outline stays ink for shape definition (revisit at the gate).

## Testing

- **Pure/deterministic (Lune):** `Glyphs.renderDayNight` is a function; the palette constants (`GOLD`, `INK`, `AMBER`, `AMBER_HALO`) exist and are valid `{r,g,b}`-style values. (Rendering itself is `Instance`-based → Play-only, not Lune-tested.)
- **Live gate (Play only):** glyphs read gold by day; as `nightFactor` climbs through dusk they dissolve to amber with a soft halo; deep night = amber glow readable through the pierced dragons; dawn dissolves back to gold. A glyph built (or a client joining) mid-night starts amber, not gold. One attempt, then STOP and show the user.

## Scope boundary

Consumes `EventBus.DayNight` only. Does **not** modify the day/night foundation, drum motion, round logic, or scene lighting. The waterfall/foam/turbulence night-dimming is a **separate** subscriber (and dims at night — the opposite direction from the glyphs).

## Files

- **New:** `roblox/src/client/GlyphDayNight.client.luau`, `roblox/tests/Glyphs.spec.luau` (if not present; minimal palette/API test).
- **Modify:** `roblox/src/shared/Glyphs.luau` (add `renderDayNight` + palette constants), `roblox/src/client/DrumController.client.luau` (one-line render swap).
