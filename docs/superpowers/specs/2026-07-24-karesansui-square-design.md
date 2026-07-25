# Karesansui Square — Design

**Date:** 2026-07-24
**Status:** Approved (brainstorm gate)
**Branch:** m4b-zendojo-art-pass
**Reference:** `The Shoro square.png` (user's amplified render of the REAL arena; the raked
garden, shops, dock, and rear teahouse are the additive layers — this spec covers the garden).
First build of the "arena amplified" program (see the arena-amplified memory/roadmap).

## Intent

A framed, *viewed* karesansui rock garden wrapping the pavilion's east and south flanks.
It — with the shōrō/bell rising out of it — is the visual and spiritual heart of the
experience, but it is NOT the point of the square: **the square is the primary gathering
zone**, and the crowd owns the ground. The garden is a modest jewel that shapes plaza flow;
players never need to (and are gently prevented from) stepping onto the raking.

Decided at the gate:
- **Framed look-at garden** (classic contemplation garden), not a walkable plaza floor.
- **East + south wrap**, less expansive than the reference; machine untouched.
- **Low-barrier protection**, not hard exclusion and not visual-only.
- **Stones + raking** composition (no lantern/planting — that's merchant-row/decoration
  territory later).
- **Approach A**: textured field + client-built geometry ripples (hybrid).

## Layout (`ArenaLayout.karesansui` — single source of truth)

- **Two rectangular panels** (east panel fronting the tower; south panel along the
  gathering side), axis-aligned, on the clearing terrace (floor y≈112). Exact rectangles
  are pinned by a Studio survey (deck edge, stair foot, spawn pad, machine footings,
  future shop flank) — surveyed numbers get BAKED into the layout block; never derived
  from placed parts at runtime.
- **Named thoroughfare reservations, first-class in the layout block:**
  - `shopCorridor` — plaza-width (16–20 studs) promenade along the flank where the
    merchant row will stand. Reserved NOW; the future merchant-row build asserts against
    the same rectangle.
  - `eastCorridor` — same width, between the garden and the portal deck.
  These are main streets sized for crowds, not lanes. Every OTHER kerb edge keeps a
  ≥ 8-stud clear circulation margin.
- Panels keep clear of pavilion posts and the bearing-plinth line; the machine stands on
  its own ground and every sightline to the bell crosses raked ground.

## Structure (generated asset `Karesansui.model.json` — TerraceDressing pattern)

New builder `roblox/tools/builders/Karesansui.luau` + genmodels entry, emitting under
`RoshamboStage`:
- **Kerb**: dressed-slate frame (Slate, `palette.gravel` — the bearing-plinth vocabulary,
  reading as the reference's dark border band), ~0.8 wide, ~0.5 proud of the terrace,
  mitred corners, per panel.
- **Field slabs**: thin slabs (top ≈ terrace + 0.15) inside each kerb, carrying the raked
  MaterialVariant (below). Split per panel as needed; slabs are walk-surface-quality
  (CanCollide on) so a jumper inside doesn't fall through, but the guard makes entry rare.
- **Guards**: invisible 3.5-stud barriers on the kerb lines, CollisionGroup
  **`EngawaBarrier`** (blocks players at ankle-jump height; jumpers can get in AND out —
  no traps; fireworks/VFX pass, per the deck fall-guard rules).
- **Boulder islands are NOT in the asset**: mossy rocks placed live in Studio (place-only,
  eye-tuned like all canyon rocks), each tagged **`KaresansuiIsland`** (CollectionService).

## Raked surface (Approach A)

- **Field texture**: a deterministic Node tool script (`roblox/tools/glyphs/rakedtex.cjs`,
  the glyphgen precedent) renders a tileable raked-sand set — pale-gravel albedo + normal-map
  ridges at ~0.8-stud groove pitch — uploaded once via the recipe-doc §9 localhost
  pipeline into **two MaterialVariants** (`RakedSandNS`, `RakedSandEW` — same texture
  rotated 90°), one per panel matching its long axis. StudsPerTile tuned at the gate.
- **Ripple rings**: client-built low-relief EditableMesh geometry (the CamMesh pattern —
  EditableMesh doesn't replicate and Rojo JSON can't carry mesh geometry):
  - Pure module `roblox/src/shared/RakingMesh.luau`: given an island's center, footprint
    radius, and ring parameters → vertex/normal/tri description of concentric ripple
    ridges (~0.15 amplitude, radii ascending from the footprint, ring count scaling with
    boulder size), plus straight-comb transition at the outermost ring.
  - `roblox/src/client/KaresansuiController.client.luau`: at boot, finds every
    `KaresansuiIsland`-tagged rock, builds its rings via AssetService
    (CreateEditableMesh → CreateMeshPartAsync), anchors them proud of the field like
    flags-proud-of-bed. Engine flags per the scatter rules: Anchored, CanCollide/CanQuery/
    CanTouch off, CastShadow off. **Move/add/remove a tagged boulder in Studio → rings
    follow at next Play, no code edits.**
- **Night-first**: the relief is the point — ridge shadows under grazing chōchin light.
  Nothing emissive in the garden.

## Failure modes (all graceful, machine-isolated)

- No tagged boulders → clean raked field, no rings.
- EditableMesh API unavailable → rings skip silently (CamMesh fallback pattern).
- Texture upload rejected by moderation → slabs fall back to plain Sand material; garden
  still reads; re-upload later.
- The garden touches no stage attribute names, no controllers, no timing — it cannot
  affect the bell machine.

## Testing & gates

- **Lune (CI)**: builder spec — kerb rects inside the terrace, ZERO encroachment on
  `shopCorridor`/`eastCorridor`, clearance from pavilion posts + plinth line, guard
  height 3.5 + `EngawaBarrier` group, slab/kerb consistency; `RakingMesh.spec` — radii
  ascending from footprint, amplitude, vert/normal/tri bookkeeping, ring-count scaling.
  `genmodels` asset byte-stable (CI drift check).
- **Visual gates (one attempt → stop-and-ask, per standing rule):**
  1. **Survey** — measure real edges in Studio; bake corridors + panels into the layout.
  2. Kerb + field + raked texture.
  3. Boulders placed + rings generated.
  4. Night-lighting read of the ripple relief.

## Out of scope

Merchant row (own spec; inherits the corridor reservations), foliage densification, the
falls dock, the perch teahouse, any lantern/planting inside the garden, walkable-raking
enforcement beyond the low guard, and any change to machine geometry or timing.
