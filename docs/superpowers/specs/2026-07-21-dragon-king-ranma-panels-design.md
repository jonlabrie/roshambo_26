# Eight Dragon-King Ranma Panels — Design Spec

**Date:** 2026-07-21
**Branch:** `m4b-zendojo-art-pass`
**Status:** Design — awaiting review (concept + **Marigold** pipeline PROVEN in-engine, 2026-07-22)
**Builds on:** the mawari-dōrō revolving-lantern display (`2026-07-21-arena-mawari-doro-display-design.md`) — this is a decoration layer on that lantern's 8 shade panels; it does not touch the display mechanism or the glyphs.

## Summary

Carve each of the **eight great dragon kings** (八大龍王, Hachidai Ryūō) into the eight `ShadePanel` faces of the mawari-dōrō lantern as **ranma** (欄間) transom-style relief. The carvings are **normal-mapped flat MeshParts** (a `SurfaceAppearance` per panel: an AO-baked weathered-cypress albedo + a real predicted surface-normal map), so each dragon reads as *carved into the wood* and responds to the scene's sun — not as a flat photo decal. Thematically perfect: the Hachidai Ryūō are rain/water deities, apt for a water-machinery bell-tower monument.

## Why normal-mapped, not real geometry

Real displacement geometry (a heightfield mesh per panel) gives true silhouette but is heavy — eight high-poly relief meshes on a crowning centerpiece. A normal map + baked ambient occlusion reads as deep carving at the distances/angles the crown is actually viewed, at near-zero cost. **Verified in-engine:** a full-size test panel rendered as convincing carved wood under real lighting (see Prototype Findings).

## The pipeline: Marigold-predicted geometry (adopted 2026-07-22)

The carving's **normal + shading come from the Marigold monocular-estimation model**, run on a dragon reference image *by the user*, not derived from the image's luminance. This is the decisive quality step: luminance-from-color conflates **ink/paint** with **depth** (a black-inked eye reads as a deep pit even if flush); Marigold predicts actual surface geometry, so the relief reads as *shape*, not tone. Per dragon the user supplies **two maps only**:

- **Marigold-Normals** → the `NormalMap` (real geometry). Verified in Play at full size: relief reads correctly and is **not inverted** — **no green-channel flip needed** for these maps.
- **Marigold-IID shading layer** → baked into the wood `ColorMap` as the AO/cavity term (retires the old luminance-highpass AO hack).
- The **color image is NOT needed** (uniform cypress albedo). It'd only matter for the unused `keepColor` path (tint wood by the dragon's own colors).
- Marigold albedo + residual layers are **not used** (de-lit color is redundant under uniform wood; residual is specular — wrong for matte cypress).

The deriver is `scratchpad/relief_marigold.cjs` (dependency-free Node, promote to `roblox/tools/glyphs/`): inputs `<name>_normal.png` + `<name>_shading.png` → outputs `<name>_mari_normal.png` (green-flip and keepColor are optional flags, both **off**) + `<name>_mari_albedo.png` (weathered cypress `[150,132,104]` × Marigold-shading AO, floor 0.28) + a re-light `_preview.png` sanity check. Deterministic; regenerate from the committed source maps.

## Prototype findings (load-bearing — these shaped the design)

1. **The Marigold deriver works.** `scratchpad/relief_marigold.cjs` turns a Marigold normal+shading pair into a Roblox `SurfaceAppearance` texture set. A local re-light (uniform wood) and the in-engine Play test both read as a genuine deep ranma carving — clearly better than the earlier luminance path (`relief.cjs`, kept only for reference). The shading→AO normalization uses 1st/99th-percentile clamp so a pure-black recessed background darkens correctly.
2. **`SurfaceAppearance` renders the carving correctly** (full-size, sun-lit) with `ColorMap` = wood×AO albedo, `NormalMap` = Marigold normal, `Material = Wood`, `DoubleSided = true`.
3. **CRITICAL — the mesh must be a persistent asset, NOT a live `EditableMesh`.** An `EditableMesh`-backed MeshPart (`Content.fromObject(em)`) does **not replicate to Play clients** — the client falls back to a default ~1-stud cube (this caused every "tiny square" symptom). The fix, proven by building the same mesh client-side (renders full-size): ship **one flat-plane mesh as a committed binary `.rbxm`** (exactly like `BonshoBell.rbxm`; see memory `roblox-rojo-meshpart-rbxm`), or a published mesh asset, and reuse it for all 8 panels. (The 2026-07-22 Play test used a client-built slab, which is why it rendered.)
4. **Surface-appearance alpha:** the AO albedo currently has no alpha channel; `AlphaMode.Overlay` (default) rendered it. If a mode needs alpha, regenerate the albedo as RGBA (alpha 255). Decide during implementation and lock it.
5. **`SurfaceAppearance` does not render in Edit** — only in Play. All visual gates for this feature must run in Play.
6. **Normal convention:** the Marigold maps rendered right-way-out with **no green flip** (flag left off). Re-verify at each dragon's gate; flip only if a future map inverts.
7. **Every uploaded image is moderation-gated** (renders blank until Roblox approves — usually a few minutes; the Nanda pair cleared fast). Batch all uploads up front.

Reference proto asset (Nanda, Marigold, uploaded 2026-07-22, verified in Play): wood×AO albedo `rbxassetid://97220985193839`, normal `rbxassetid://89423039554241`. Source maps 1240×1640 (3:4-ish portrait).

## Architecture

### 1. The reusable plane mesh (`.rbxm`)

One flat quad MeshPart with correct 0-1 UVs, built once and committed as `roblox/assets/meshes/RanmaPanel.rbxm` (built via `CreateMeshPartAsync` from an `EditableMesh` quad → Studio Save-to-File → `.rbxmx`→`.rbxm` rename, per the bell recipe). It carries no texture itself; each panel instance gets its own `SurfaceAppearance`. Registered in `WorkspaceConvention` allowlist as needed.

### 2. Relief asset pipeline (per dragon)

`roblox/tools/glyphs/relief_marigold.cjs` (promote from scratchpad, alongside `glyphgen.cjs`): input a dragon's **Marigold normal + shading** PNGs (same WxH, ~3:4 portrait), output `<name>_mari_albedo.png` (wood × Marigold-shading AO) + `<name>_mari_normal.png`. Upload both → record `rbxassetid` per dragon in a shared table. Deterministic; regenerate from committed source maps. Tunables (locked at gate): AO floor/gamma, wood tone; `flipG`/`keepColor` flags stay **off**. The original color image is **not** an input.

### 3. Builder integration (`ThrowDrum.luau`)

The 8 `ShadePanel{i}` currently emit as cypress `Part`s. Add — **as an overlay carving MeshPart per panel** (leave the structural cypress panel behind it): a `RanmaCarving{i}` MeshPart referencing `RanmaPanel.rbxm`, sized to the image aspect (3:4, fit to the panel — **no stretch**), seated ~0.15–0.2 studs proud of the panel face, with a `SurfaceAppearance` (`ColorMap`/`NormalMap` = that panel's dragon assets, `Material = Wood`, `DoubleSided`, `AlphaMode` per finding #4). Which dragon → which panel is a data map (`DRAGON_FOR_PANEL`). MeshParts + SurfaceAppearance in a builder follow the committed-`.rbxm` + `$path` pattern already used for the bell.

### 4. The eight dragons (data)

`DRAGON_FOR_PANEL` maps the 8 panels (world dirs 30/60/120/150/210/240/300/330) to the Hachidai Ryūō, each with its albedo+normal asset IDs: **Nanda 難陀** (done), **Upananda 跋難陀**, **Sāgara 娑伽羅**, **Vāsuki 和修吉**, **Takshaka 德叉迦**, **Anavatapta 阿那婆達多**, **Manasvin 摩那斯**, **Utpalaka 優鉢羅**. Ordering (e.g., Nanda/Upananda as a pair on adjacent panels) is a decision at build time.

## Assets needed from the user

For each of the seven remaining dragon kings: a **Marigold normal map + Marigold shading map** (two PNGs, same size, ~3:4 portrait), extracted the same way as Nanda from a carving reference in Nanda's style. **No color image needed.** Nanda's pair is in hand and verified.

## Open decisions (resolve at spec review / gate)

- AO floor/gamma + wood tone (match the lantern's `CypressWeathered`?) — tune in `relief_marigold.cjs`, verify in Play.
- `AlphaMode` + whether albedo needs an alpha channel (finding #4).
- ~~Normal green-flip~~ — **resolved:** no flip for Marigold maps (finding #6); re-check per dragon.
- Dragon→panel assignment order.
- Panel-fit: center the 3:4 carving with side margin vs. add a carved border to fill the ~4:5 panel.

## Scope boundary

Purely decorative on the finished lantern. Does **not** touch the display mechanism, glyphs, rotation, or the water drive. The carvings are static (they ride the fixed shade, not the spinning inner drum).

## Testing

- Pure/deterministic: `relief_marigold.cjs` output stable from committed source maps; `RanmaPanel.rbxm` byte-stable; `ThrowDrum` builder emits `RanmaCarving1..8` with the right assets (Lune contract test on the part names + per-panel dragon map); `genmodels` determinism.
- **Live gate (Play only — SurfaceAppearance doesn't render in Edit):** all 8 carvings render full-size at the right panels, read as carved wood under the day/night cycle, relief not inverted (else green-flip), no z-fight with the cypress panel, moderation cleared. One attempt, then STOP and show the user.

## Files

- **New:** `roblox/assets/meshes/RanmaPanel.rbxm`, `roblox/tools/glyphs/relief_marigold.cjs` (promoted), a shared `DragonKings`/asset-ID module, spec + plan.
- **Modify:** `roblox/tools/builders/ThrowDrum.luau` (emit the 8 carving MeshParts), `WorkspaceConvention` allowlist, `ThrowDrum.spec`.
- **Source (committed):** the 8 dragons' Marigold normal + shading PNG pairs (16 files).
