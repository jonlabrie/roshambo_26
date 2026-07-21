# Eight Dragon-King Ranma Panels — Design Spec

**Date:** 2026-07-21
**Branch:** `m4b-zendojo-art-pass`
**Status:** Design — awaiting review (concept + pipeline PROVEN in-engine)
**Builds on:** the mawari-dōrō revolving-lantern display (`2026-07-21-arena-mawari-doro-display-design.md`) — this is a decoration layer on that lantern's 8 shade panels; it does not touch the display mechanism or the glyphs.

## Summary

Carve each of the **eight great dragon kings** (八大龍王, Hachidai Ryūō) into the eight `ShadePanel` faces of the mawari-dōrō lantern as **ranma** (欄間) transom-style relief. The carvings are **normal-mapped flat MeshParts** (a `SurfaceAppearance` per panel: an AO-baked weathered-cypress albedo + a normal map derived from a dragon carving image), so each dragon reads as *carved into the wood* and responds to the scene's sun — not as a flat photo decal. Thematically perfect: the Hachidai Ryūō are rain/water deities, apt for a water-machinery bell-tower monument.

## Why normal-mapped, not real geometry

Real displacement geometry (a heightfield mesh per panel) gives true silhouette but is heavy — eight high-poly relief meshes on a crowning centerpiece. A normal map + baked ambient occlusion reads as deep carving at the distances/angles the crown is actually viewed, at near-zero cost. **Verified in-engine:** a full-size test panel rendered as convincing carved wood under real lighting (see Prototype Findings).

## Prototype findings (load-bearing — these shaped the design)

1. **The relief deriver works.** `scratchpad/relief.cjs` (dependency-free Node): decode a carving PNG → luminance ≈ height → **normal map** (strength ~7) + a **wood albedo with AO baked in** (`wood × ao`, AO strength ~3.2, cavities darkened). A local render (uniform wood, lit) reads as a genuine ranma carving. The deriver + `glyphgen`-style pipeline are proven.
2. **`SurfaceAppearance` renders the carving correctly** (full-size, sun-lit) with `ColorMap` = AO albedo, `NormalMap` = derived normal, `Material = Wood`, `DoubleSided = true`.
3. **CRITICAL — the mesh must be a persistent asset, NOT a live `EditableMesh`.** An `EditableMesh`-backed MeshPart (`Content.fromObject(em)`) does **not replicate to Play clients** — the client falls back to a default ~1-stud cube (this caused every "tiny square" symptom). The fix, proven by building the same mesh client-side (renders full-size): ship **one flat-plane mesh as a committed binary `.rbxm`** (exactly like `BonshoBell.rbxm`; see memory `roblox-rojo-meshpart-rbxm`), or a published mesh asset, and reuse it for all 8 panels.
4. **Surface-appearance alpha:** the AO albedo currently has no alpha channel; `AlphaMode.Overlay` (default) rendered it. If a mode needs alpha, regenerate the albedo as RGBA (alpha 255). Decide during implementation and lock it.
5. **`SurfaceAppearance` does not render in Edit** — only in Play. All visual gates for this feature must run in Play.
6. **Normal convention:** Roblox may need the normal map's **green channel flipped** (OpenGL vs. DirectX). Verify at the live gate; if relief looks inverted, flip green in `relief.cjs` and re-derive.
7. **Every uploaded image is moderation-gated** (renders blank until Roblox approves — minutes). Batch all uploads up front.

Reference proto asset (Nanda, already uploaded): AO albedo `rbxassetid://128886730210198`, normal `rbxassetid://113106126786860`. Source image resized to 774×1024 (3:4).

## Architecture

### 1. The reusable plane mesh (`.rbxm`)

One flat quad MeshPart with correct 0-1 UVs, built once and committed as `roblox/assets/meshes/RanmaPanel.rbxm` (built via `CreateMeshPartAsync` from an `EditableMesh` quad → Studio Save-to-File → `.rbxmx`→`.rbxm` rename, per the bell recipe). It carries no texture itself; each panel instance gets its own `SurfaceAppearance`. Registered in `WorkspaceConvention` allowlist as needed.

### 2. Relief asset pipeline (per dragon)

`roblox/tools/glyphs/relief.cjs` (promote from scratchpad, alongside `glyphgen.cjs`): input a dragon carving PNG (clean, front-on, single panel, ~3:4), output `<name>_albedo.png` (wood × AO, RGBA) + `<name>_normal.png`. Upload both → record `rbxassetid` per dragon in a shared table. Deterministic; regenerate from committed source images. Tunables (locked at gate): normal strength, AO strength/radius, wood tone.

### 3. Builder integration (`ThrowDrum.luau`)

The 8 `ShadePanel{i}` currently emit as cypress `Part`s. Add — **as an overlay carving MeshPart per panel** (leave the structural cypress panel behind it): a `RanmaCarving{i}` MeshPart referencing `RanmaPanel.rbxm`, sized to the image aspect (3:4, fit to the panel — **no stretch**), seated ~0.15–0.2 studs proud of the panel face, with a `SurfaceAppearance` (`ColorMap`/`NormalMap` = that panel's dragon assets, `Material = Wood`, `DoubleSided`, `AlphaMode` per finding #4). Which dragon → which panel is a data map (`DRAGON_FOR_PANEL`). MeshParts + SurfaceAppearance in a builder follow the committed-`.rbxm` + `$path` pattern already used for the bell.

### 4. The eight dragons (data)

`DRAGON_FOR_PANEL` maps the 8 panels (world dirs 30/60/120/150/210/240/300/330) to the Hachidai Ryūō, each with its albedo+normal asset IDs: **Nanda 難陀** (done), **Upananda 跋難陀**, **Sāgara 娑伽羅**, **Vāsuki 和修吉**, **Takshaka 德叉迦**, **Anavatapta 阿那婆達多**, **Manasvin 摩那斯**, **Utpalaka 優鉢羅**. Ordering (e.g., Nanda/Upananda as a pair on adjacent panels) is a decision at build time.

## Assets needed from the user

Seven more dragon-king carving images in **Nanda's style** — clean, front-on, single-panel, ~3:4, weathered-wood carving on a neutral ground (AI-generated to match). Nanda is in hand.

## Open decisions (resolve at spec review / gate)

- Relief strength + wood tone (match the lantern's `CypressWeathered`?) — tune in `relief.cjs`, verify in Play.
- `AlphaMode` + whether albedo needs an alpha channel (finding #4).
- Normal green-flip (finding #6).
- Dragon→panel assignment order.
- Panel-fit: center the 3:4 carving with side margin vs. add a carved border to fill the ~4:5 panel.

## Scope boundary

Purely decorative on the finished lantern. Does **not** touch the display mechanism, glyphs, rotation, or the water drive. The carvings are static (they ride the fixed shade, not the spinning inner drum).

## Testing

- Pure/deterministic: `relief.cjs` output stable from committed source images; `RanmaPanel.rbxm` byte-stable; `ThrowDrum` builder emits `RanmaCarving1..8` with the right assets (Lune contract test on the part names + per-panel dragon map); `genmodels` determinism.
- **Live gate (Play only — SurfaceAppearance doesn't render in Edit):** all 8 carvings render full-size at the right panels, read as carved wood under the day/night cycle, relief not inverted (else green-flip), no z-fight with the cypress panel, moderation cleared. One attempt, then STOP and show the user.

## Files

- **New:** `roblox/assets/meshes/RanmaPanel.rbxm`, `roblox/tools/glyphs/relief.cjs` (promoted), a shared `DragonKings`/asset-ID module, spec + plan.
- **Modify:** `roblox/tools/builders/ThrowDrum.luau` (emit the 8 carving MeshParts), `WorkspaceConvention` allowlist, `ThrowDrum.spec`.
- **Source (committed):** the 8 dragon carving PNGs.
