# ZenDojo Mossy Gorge — Vertical Slice Plan

> **Purpose:** Prove the full "lush green moss over dark wet stone" look from the reference by building **one complete cliff section with all four layers combined**, judged in context — instead of testing single layers that always disappoint in isolation.

**Goal:** A single canyon wall section (behind the two clearing teahouses) that reads like the reference: dark wet stone showing through a mossy-green cliff, ferns/plants tucked into it, a Japanese maple accent, wrapped in mist and warm lantern light.

**Reference:** the misty Japanese gorge — moss-draped dark cliffs, warm lanterns, pink maple accents, waterfalls, mist. (Two images provided 2026-07-06 and 2026-07-10.)

## Honest calibration (read first)

- The reference images are **AI photoreal-painterly**. Roblox — faceted voxel terrain, no custom shaders — will capture the **feeling** (lush, moody, mossy gorge), **not** photoreal fidelity. Success = "evocative and lush," not "matches the render."
- No single layer *is* the look. We judge the **combination**, once, in context.

## What we proved on 2026-07-10 (so we don't repeat it)

- ❌ Flat `SetMaterialColor` tint on terrain = spray paint. Dead.
- ✅ **`MaterialVariant` with a real texture renders on terrain cliffs** — confirmed. This is the method for the moss surface.
- ❌ Scavenged free Roblox moss "textures" = unreliable junk decals. We need a proper CC0 map.
- ✅ The fern/moss mesh **scatter machinery** (raycast-to-surface, orient-to-normal) already works from the earlier swatch prototype.

## The slice location

The **north/east clearing wall behind the two teahouses** — world box roughly `x −335..−260, y 205..250, z −95..−45`. Chosen because it's in view, already has teahouses + chōchin + deck for context, and presents a good wall face with varied slope. (User: confirm or nudge this box before Phase 2.)

## Division of labor

- **I do fully (no input needed):** mist, lighting, color grade, all terrain repaint/scatter scripting, maple placement, every capture + revert.
- **Needs you (the two real inputs):**
  1. **One CC0 moss texture set** (color + normal) *into Roblox as image assets* — because I can't download to your disk (sandbox-blocked) and can't upload to your account. See Phase 2 for the exact hand-off options.
  2. **One foliage-mesh source** picked, and (if paid) bought + downloaded + FBX-imported via Studio's 3D Importer — because I can't drive that importer remotely. See Phase 3.

---

## Global constraints

- **Place-only geometry.** Everything here (terrain repaint, scattered meshes, maple, mist parts) persists only in the saved `.rbxl` — **you save the place**. Nothing here is committed to git except this plan and any reusable builder scripts.
- **Every terrain edit is snapshotted** to `ServerStorage` before writing, so every phase is one-command revertible.
- **Scan any imported mesh pack for backdoors before it ever goes near publish** (per standing rule) — though imported FBX meshes carry no scripts, so this is a low risk here; still eyeball for stray `Script`/`require`.
- **Backdoor/junk textures:** only use CC0 sources (Poly Haven / ambientCG) for the moss maps, not random Roblox decals.

---

## Phase 1 — Mood: mist + lighting + color grade  *(all mine, do first, zero assets)*

**Why first:** it needs nothing from you, it's fully reversible, and it will transform the *entire* canyon immediately — the current scene is dark and flat, and the reference's magic is 50% atmosphere. This de-risks everything and gives us an immediate before/after.

- [ ] **1.1** Snapshot current `Lighting` + `Atmosphere` property values to a scratch note (for revert).
- [ ] **1.2** Add/tune `Atmosphere` (Density ~0.35, Offset, greyish-green Color, Haze, Glare) for gorge depth haze.
- [ ] **1.3** Set `Lighting.Technology = Future`; tune `ClockTime`/`Brightness`/`Ambient`/`OutdoorAmbient` to a cool-but-not-blue dusk so the warm chōchin `PointLight`s pop.
- [ ] **1.4** Add `ColorCorrection` (slight desaturate, faint warm tint, lifted blacks) + modest `Bloom` + `SunRays`.
- [ ] **1.5** Add a **river-level mist layer**: low, near-zero-velocity `ParticleEmitter`s (large soft smoke texture, `LockedToPart`) hugging the water line, filling the gorge floor.
- [ ] **1.6** Capture + **you look**. Tune to taste. **Gate:** mood approved before spending on assets.

---

## Phase 2 — Moss cliff surface  *(TerrainDetail material override — needs your texture hand-off)*

**Method (upgraded 2026-07-10 per user research — supersedes the earlier voxel-repaint idea):**
- Create a `MaterialVariant` whose `BaseMaterial` = the cliff terrain material (our cliffs are **Basalt**), and add **`TerrainDetail` children** for the **Top** and **Side** faces:
  - **Top face** → green **moss** PBR (color + normal + roughness) — engine paints this on flat/upward surfaces.
  - **Side face** → dark wet **stone** PBR — engine keeps this on steep/vertical drop-offs.
  - Roblox **auto-blends Top↔Side by true surface slope, per-pixel** — "moss on top, clean dark stone on the verticals," continuously, no per-voxel thresholds.
- Assign the variant as the **Material Override** for Basalt (Material Manager → Overrides → core/Terrain → Basalt → your variant). **Non-destructive**: no terrain repaint, instant one-click revert (clear override), and it covers the **whole canyon** consistently — so we judge it everywhere at once.

**Why this beats the repaint method:** no voxel rewrite/snapshot; engine-driven per-pixel slope blend (better than a coarse threshold); canyon-wide consistency; instant revert; normal+roughness maps hide facet ugliness.

**Texture hand-off — now two PBR sets (pick ONE delivery route):**
- **(a) You grab + upload (cleanest):** I give exact CC0 links — a **moss** set (e.g. ambientCG **Moss004** / Poly Haven **moss**) and a **dark wet rock** set (e.g. ambientCG **Rock035** / a dark slate), each with color + normal + roughness. You download, **Studio → Asset Manager → Import** the maps, paste me the image asset IDs.
- **(b) I fetch via your browser, you upload:** with your OK, I trigger the CC0 downloads to your disk in Chrome; you still do the Studio import (asset IDs back to me).

- [ ] **2.1** Get the two PBR sets' image asset IDs to me — moss (color+normal+roughness) and dark stone (color+normal+roughness).
- [ ] **2.2** I script `MaterialVariant` (BaseMaterial `Basalt`) + `TerrainDetail` **Top** (moss) + **Side** (stone), maps + `StudsPerTile` (~8–14 each).
- [ ] **2.3** Assign the variant as the **Basalt override** — I confirm scriptable vs a 2-click Material Manager step; if UI-only, I guide you through it.
- [ ] **2.4** Capture + **you look**. Tune `StudsPerTile`, Top/Side blend, roughness, tint. **Gate:** moss-on-stone reads right. (Revert = clear override / delete variant — instant, non-destructive.)

---

## Phase 3 — Foliage mesh scatter  *(needs your pack pick + import)*

**The decision:** pick ONE foliage-mesh source. Recommendation given your bar: a lush stylized pack we **tint green + warm-light** so isolated-render palette stops mattering (e.g. Tidal Flask **FANTASTIC** family — ferns/moss/undergrowth — or a greener equivalent we agree on). Import is FBX/glTF → Studio 3D Importer (your hands); I take over after.

- [ ] **3.1** Lock the foliage source; if paid, you buy + download.
- [ ] **3.2** You import the FBX/glTF via Studio's 3D Importer (I'll give scale/texture settings). Meshes land in workspace.
- [ ] **3.3** I quarantine + dedupe them into `ServerStorage.FoliageKit` (one clean template per species); eyeball for stray scripts.
- [ ] **3.4** I run the scatter on the slice: raycast the mossed cliff, orient ferns/moss clumps to the surface normal, cluster believably (denser on ledges + near water, sparse on sheer faces), green-tint + per-instance scale/rotation variance.
- [ ] **3.5** Capture + **you look**. Tune density/species mix. **Gate:** foliage layer reads lush, not sparse or clip-y.

---

## Phase 4 — Maple / cherry accents  *(I source; you approve any purchase)*

- [ ] **4.1** I source 1–2 Japanese maple (momiji) + cherry (sakura) meshes — free Creator Store or same foliage family (search "Japanese maple stylized fbx" / "sakura tree"). If the only good one is paid, I show you first.
- [ ] **4.2** Place 2–3 as accents on ledges/teahouse edges within the slice (the pink pop from the reference).
- [ ] **4.3** Capture + **you look**.

---

## Phase 5 — Judge the combined slice

- [ ] **5.1** Final capture of the full slice with all four layers live, framed with the teahouses + lanterns.
- [ ] **5.2** **You judge the complete look in context.** This is the real decision point: does it clear the bar?
- [ ] **5.3** If yes → we've got a proven recipe + reusable scripts to roll across the whole canyon (its own later plan). If no → we know exactly which layer is weak and fix that one, not all of them.

---

## Verification

- Each phase ends with a capture + your look; no phase proceeds until its gate passes.
- Every terrain edit has a `ServerStorage` snapshot; "revert phase N" restores it.
- The slice stays contained to the one wall box; the rest of the canyon is untouched until Phase 5 approves the recipe.

## Open decisions to resolve as we go

1. **Slice box** — confirm/nudge before Phase 2.
2. **Moss texture** — which CC0 set + which hand-off (a/b) in Phase 2.
3. **Foliage source** — the one still-open pick from Phase 3 (biggest spend/effort decision).
