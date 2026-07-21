# Arena Display Redesign — Mawari-dōrō Revolving Lantern

**Date:** 2026-07-21
**Branch:** `m4b-zendojo-art-pass`
**Status:** Design — awaiting review
**Supersedes:** Task 6 ("ThrowDrum dressing") of `docs/superpowers/plans/2026-07-20-arena-water-striker-visual-pass.md`, and the throw-drum assumptions in that plan's Task 5.

## Summary

Replace the Arena's placeholder hexagonal **World-Throw drum** (a generic horizontal barrel atop the shōrō) with a **mawari-dōrō** (回り灯籠) — an authentic Edo/early-Meiji **revolving lantern**. The new display is a squat, wide **12-facet inner drum** that rotates on a **vertical axis** behind a fixed outer shade with **four windows**, crowning the shōrō tower where the drum already sits (~y148). It reads the World Throw from all four cardinal directions, glows warm at night, and unifies the game's R/P/S glyphs on the approved PWA artwork.

The signed-off reveal *behavior* (rest → strike-kicked spin → cubic glide to the World-Throw detent) is preserved wholesale. This is a **visual/display redesign**; it explicitly does **not** rebuild the physical water-drive linkage — that is deferred to the T8 drive-chain technical pass.

## Motivation

The centerpiece "Water Striker" monument was flagged as a visual sore thumb. A water-machinery-driven mechanical display is already in the spirit of Edo *karakuri*, but the barrel drum reads as generic. The mawari-dōrō is the genuine period ancestor of a "spinning drum" display: it is historically authentic, it glows (harmonizing with the chōchin lanterns across the canyon), it makes the result readable from every approach in a multi-sided canyon, and it becomes a landmark beacon visible from the valley floor, bridges, and teahouse decks.

## Design decisions (all user-approved during brainstorming)

1. **Form:** mawari-dōrō — inner rotating glyph-carrier + fixed outer windowed shade. This is the real device's construction.
2. **Glyph carrier geometry:** a **12-facet prism** (flat panels, one glyph each), not a smooth round drum — flat facets keep the glyph crisp and legible at distance; direct evolution of today's 6-face hex drum.
3. **Windows:** **four** (N/E/S/W). The 12 facets carry R,P,S repeated ×4 at 30° spacing; because the pattern has 90° periodicity and the windows are 90° apart, **all four windows always show the same symbol**, and a **30° step advances all four to the next symbol**.
4. **Axis:** **vertical** (spin about the hub's local Y). Detents recur every **90°**.
5. **Illumination (day + night from one construction):** the field/drum is **opaque gray weathered cypress** — cream by reflection in daylight, dark at night (blocks the interior lamp). The **glyph is always full-bright** and is the only thing that glows at night. Net: gold-on-cypress by day, a lit glyph on darkened wood by night (the "stencil" look), in warm gold rather than cold white. A warm interior `PointLight` supplies the night halo.
6. **Material:** the **entire drum and shade are gray weathered cypress** (`CypressWeathered`), unifying the crown with the tower. Daytime glyph contrast is carried by the glyph's **white outline** (built into the approved art), so no 3D relief is required.
7. **Crown composition:** the lantern crowns the tower where the drum already sits — vertical stack of **bonshō bell (hanging under the hip roof) → hip roof → lantern beacon → miniature kawara hip-roof cap → gilt hōju finial**. Proportion is **squat and wide** (a lantern firebox under a big roof cap), because circumference — not height — is the constraint.
8. **Size:** **radius ≈ 11 studs (~22 diameter, "Beacon"), ~56% of the 39-stud roof.** Chosen in-situ over Compact (r7) and Middle (r9). Body height ~8–10 studs (squat). Final proportions tuned live in Studio against the roofline (glyph size is the lever if it reads top-heavy).
9. **Glyphs = the approved PWA artwork.** `src/components/Symbols.tsx` is the source of truth: Rock = a ring (white stroke 4.5 under color stroke 2.5), Paper = a rounded bar (white 5 / color 3), Scissors = an **upward** chevron `∧` (white 4.5 / color 2.5). These replace the placeholder Unicode `○ ─ ∧`.
10. **Chevron orientation:** **∧ (upward) everywhere**, including the HUD pick buttons (which previously used ∨). The prior "happy-side / sad-side" asymmetry is **retired for now** (see Consequences). Recorded in memory `roshambo-happy-sad-sides`.
11. **Glyph portability approach:** rebuild the glyphs as **native Roblox UI** (no image uploads) in a shared `Glyphs.luau` module — resolution-independent, recolorable per surface, no CI asset-drift. Images are the fallback only if native fidelity disappoints at the live gate.
12. **Cross-surface scope:** unify the glyphs on the **lantern**, the **chōchin** (`LanternController`), and the **HUD** (round-history slots + pick buttons in `main.client.luau`). **Deferred:** the split-flap kōsatsu boards (`BoardController` + `FlapScheduler`) — those animate a character *alphabet*, so frame-based glyphs would break the flap effect.

## Architecture

Three cooperating pieces, each independently testable:

### 1. `Glyphs.luau` (new, shared)

Pure UI-builder module mirroring `Symbols.tsx`. No dependencies on game state.

- **Interface:** `Glyphs.build(symbol: "R"|"P"|"S", coreColor: Color3, opts?): GuiObject` — returns a self-contained `Frame` (parent-anchored, `Size` from `opts` or fill) rendering the white-outlined colored glyph. `opts` may carry `outlineColor` (default white), `strokeScale`, and `pixelSize`.
- **Construction (native UI, matching the two-pass SVG strokes):**
  - **Rock:** two concentric circular frames (`UICorner` 0.5) with `UIStroke` — a thicker white ring behind, a thinner colored ring centered on it → white-core-white band = the outlined ring.
  - **Paper:** two stacked rounded bars (`UICorner`) — white (taller) behind, colored (shorter) in front, both full-width with rounded caps.
  - **Scissors:** two rounded bars (as Paper) rotated to meet at an apex, forming an upward chevron; each bar white-behind/color-front.
- **Why native, not images:** resolution independence, per-surface recolor (mirrors the PWA's `currentColor`), zero asset-upload / CI-drift, and these glyphs are simple enough to reproduce exactly.
- **Consumers:** the lantern (gold core, on a `SurfaceGui` with `LightInfluence = 0`), the chōchin, and the HUD.

### 2. Geometry — `tools/builders/ThrowDrum.luau` (rewrite) + `ArenaLayout.luau`

Follows the existing geometry-as-code pipeline: pure builder → `genmodels.luau` → committed `assets/ThrowDrum.model.json` (Rojo-synced, CI drift-checked). Built the "Teahouse-builder way" from primitives — no mesh/`.rbxm` (per `roblox-rojo-meshpart-rbxm`).

**Parts contract (names the `DrumController` and tests depend on):**

*Inner carrier (spins about local Y):*
- `Drum` — invisible vertical-axis hub (unchanged role).
- `Face0`–`Face11` — the 12 cypress facet panels forming the dodecagonal ring (radius ~11; facet chord ~5.7 studs).
- Per facet, the glyph is drawn at runtime by the controller onto a `SurfaceGui` (see §3) — the *panel* geometry ships in the model; the glyph UI is controller-attached (not baked into `model.json`) so it stays recolorable and shares `Glyphs.luau`. (Facets are the only spun display parts; light internal spokes/floor may exist for structure but are static/symmetric.)

*Outer shade (fixed, does not spin):*
- `Post1`–`Post4` — corner uprights; the four gaps between them are the windows (window arc ≤ 30° so exactly one facet reads per window).
- `RoofCap` (+ supporting parts) — a miniature kawara hip-roof matching the tower roof.
- `Finial` — gilt hōju on top; a thin bronze/gold band under the cap.
- `Base` — a ring seating the lantern on the crown.
- `Lamp` — a warm `PointLight` inside for the night halo.

**`ArenaLayout.throwDrum`** gains: `radius = 11`, `height` (~8–10), `faces = 12`, `windows = 4`, retains `pos = {-2, 148, 0}` and drops the old `yaw = 90` / `southSpokeR` horizontal-axis fields. Values are tuned live against the roofline.

### 3. `DrumStep.luau` (generalize 6→12) + `DrumController.client.luau` (rewrite)

- **`DrumStep`:** generalize from 6 to **12 faces**. `faceForThrow` still returns 0/1/2; symbols recur every **3 facets (90°)**; `landingStep`/`symmetric` operate over 12. Pure, fixture-testable.
- **`DrumController`:**
  - Capture the spinning parts (the 12 facets + their attached glyph UIs) as hub offsets — same offset-capture pattern as today/`WheelController`.
  - Spin about the hub's **local Y** (was local X).
  - Build each facet's glyph via `Glyphs.build("R"/"P"/"S", GOLD)` on a `SurfaceGui` (`LightInfluence = 0`) — **replaces** the runtime Unicode `TextLabel`.
  - Preserve the motion state machine verbatim: rest through ACTIVE+TALLY; on `gongHit`, steady spin for `SPIN_SEC` then cubic-Hermite glide to the World-Throw detent over `GLIDE_SEC`; `landTargetFor` steps by **90° (π/2)** instead of 180°; the stuck-guard and `drumRest` cue are unchanged.
  - The pin-wheel flick (`applyKick` on `BellDrive` parts) is **left as-is** — it keeps animating as ambient machinery keyed to the same strike. Reconnecting it visually to the vertical lantern is T8's job.

### Retrofits (bundled)

- **`LanternController.client.luau`** (chōchin): replace the `GLYPH` Unicode table + `TextLabel` with `Glyphs.build` on the lantern faces (keep the existing sway/replication logic).
- **`main.client.luau`** (HUD): replace the round-history `GLYPH` slots and the `BTN_GLYPH` pick buttons with `Glyphs.build`; **scissors is ∧ everywhere** (drop the `∨` button variant).

## Scope boundary (explicit)

**In scope:** the mawari-dōrō display (geometry, controller, `DrumStep`), the shared `Glyphs.luau`, and the chōchin + HUD retrofits.

**Out of scope (deferred):**
- **Physical drive-linkage reconnection** — the "paddle physically flicks the drum near the roof" read no longer connects to a vertical lantern up on the crown. Reworking the vertical drive so the machinery visibly turns the lantern belongs to the **T8 drive-chain technical pass** (which already owns the shu-moku/gantry realignment to the raised bell). During this pass, the lantern spins keyed to the strike and the pin-wheel flicks independently, as today.
- **Split-flap kōsatsu boards** (`BoardController` + `FlapScheduler`) — a separate effort (the flap animates a character alphabet).
- **True bloom on the glyph** — the always-bright `SurfaceGui` + interior `PointLight` reads as lit; a Neon backing for a bloom halo is a possible later polish, not baseline.

## Consequences & trade-offs

- **Mechanism vs. visual pass:** the vertical axis is a controller change, but it stays within "visual pass doesn't disturb the signed-off mechanism" because the reveal *behavior* is preserved and the drive-linkage rework is deferred to T8.
- **Happy-side / sad-side retired (for now):** with ∧ upright on all four windows, the arena loses the flipped-chevron mood split. Preservable later by baking the chevron upright on the front/back facets and inverted on the left/right facets (rock/paper still read identically all around). Recorded in `roshambo-happy-sad-sides`.
- **Glyph size ↔ top-heaviness:** the Beacon diameter (~56% of the roof) is bold; if it reads top-heavy live, shrink the glyphs (and thus the drum) — glyph size is the lever, balanced against the roofline at the live gate.
- **Native-UI glyph fidelity:** the ring and bar are trivial; the chevron is the only fiddly one. Fallback to uploaded PNGs only if the live gate shows it isn't crisp enough.

## Testing

- **`Glyphs.spec.luau`** — builds all three symbols; honors `coreColor` and `outlineColor`; produces the expected sub-parts (ring/bar/chevron); chevron apex points up.
- **`DrumStep.spec.luau`** — 12 faces; `faceForThrow` 0/1/2; symbol detents recur every 3 facets; `landingStep` reaches the target within 3 steps across all start/throw combinations.
- **`ThrowDrum.spec.luau`** — parts contract: `Drum`, `Face0`–`Face11`, four `Post`s, `RoofCap`, `Finial`, `Base`, `Lamp`; 12 facets; RPS×4 facet pattern; determinism (regen twice → identical `model.json`).
- **Determinism:** `lune run tests/run` green; `lune run tools/genmodels` ×2 → `assets/ThrowDrum.model.json` changes once, stable on re-run; `stylua --check` + `selene` clean.
- **Live gate (Studio, one attempt then STOP and show the user):** day look (gold-on-cypress, all four windows agree, legible from the valley floor); night look (field dark, glyph glows warm, halo); full round — rest → strike → spin → glide-to-rest on the World Throw at a 90° detent; chōchin + HUD show the new glyphs.

## Sequencing

Replaces T6 in the visual-pass plan. Order within this spec's plan: `Glyphs.luau` → `DrumStep` generalization → `ThrowDrum` builder + `ArenaLayout` → regen → `DrumController` → chōchin + HUD retrofits → live gate. Afterward the visual pass continues with T7 (waterwheel); T8 (drive-chain) now also owns reconnecting the vertical drive to the lantern.

## Files

- **New:** `roblox/src/shared/Glyphs.luau`, `roblox/tests/Glyphs.spec.luau`, this spec, and the implementation plan.
- **Rewrite:** `roblox/tools/builders/ThrowDrum.luau`, `roblox/src/client/DrumController.client.luau`.
- **Modify:** `roblox/tools/builders/ArenaLayout.luau`, `roblox/src/shared/DrumStep.luau`, `roblox/src/client/LanternController.client.luau`, `roblox/src/client/main.client.luau`, `roblox/tests/ThrowDrum.spec.luau`, `roblox/tests/DrumStep.spec.luau`.
- **Regenerated:** `roblox/assets/ThrowDrum.model.json`.
- **Reference (read-only, source of truth for the glyphs):** `src/components/Symbols.tsx`.
