# ZenDojo Canyon — Completion Plan (burndown)

**Purpose:** track the remaining work to **finish this canyon** — the D.6 test bed (legacy teahouse
migration) + access + the art pass. Estimating in **sessions** (≈ an evening like 2026-07-10). Ranges,
not commitments; visual/creative work is iteration-heavy and user-gated.

**Scope boundary:** this is *finishing the canyon only*. The wider meta-game (D.5 preference UI, E
economy/UI, remaining B/C) is a separate, much larger track — listed at the bottom for context, **not**
estimated into "canyon done." Background: [[roshambo-structure-builder]], [[roshambo-roadmap]],
[[roshambo-metagame-spec]].

Legend: `[x]` done · `[ ]` remaining.

---

## Track 1 — Legacy teahouse migration (D.6) — **~2 sessions**

The materialization machinery (D.1–D.4) is **BUILT & proven on 1–2 pads** (SiteCoordinator + TreatmentApplier
handle join→materialize→leave→dormant; SizeClasses; dynamic posts). Remaining is scale + retire + test:

- [x] ~~Re-survey PadRefs / regenerate `PadSites.luau`~~ — **NOT NEEDED** (verified 2026-07-11). All 14
      `PadRef_T01–T14` Pad datums match the baked `PadSites` mountCF exactly in yaw + Y, differing only by a
      consistent hand-dependent local offset (−5.9 fwd / ±6.1 right, marker-center vs mountCF-anchor). Same
      perches, not moved → `PadSites.luau` is authoritative as-is. (One minor: T11's marker is 2.4 studs
      shallower in fwd — cosmetic, yaw/Y still match.)
- [x] **Register all 14 as SITES** — done in `main.server.luau` (was hard-coded `T02,T06,T04`; now the
      `for i=1,14` `T%02d` loop, stable order). The `vacantActions()→apply()` loop already materializes all
      registered sites. 341 Lune tests green. **Pending Studio play visual gate** (Rojo-sync + Play → confirm
      14 materialize on-perch).
- [x] **Retire the legacy `CanyonTeahouses`** — 2026-07-11: moved (13 models, ~3053 parts) from
      `CanyonWorld.Legacy` to `ServerStorage.RetiredLegacyTeahouses` (frozen, not deleted; reversible;
      place-only, save the place). Play now renders only the materialized `TeahouseSites`. NOTE: 13 legacy
      models vs 14 pad sites — count discrepancy from the original survey, not yet reconciled.
- [ ] **Full-loop test** on the real perches (join/leave across servers) + per-site size tuning.

*Risk:* per-site size tuning iteration; verifying dormant/lit swaps read right on every perch.

---

## Track 2 — Access — **~0.5 session** (mostly DONE)

- [x] Far-Wall trunk paths, spurs, tunnels, and the **suspension bridge** — access defined to every pad
      **except TH7** (this session + prior).
- [x] **T03 access — DONE** (tunnel-based; no bridge).
- [x] ~~Bridge2~~ — **dropped**, not happening.
- [ ] **Teahouse-7 access** — the one remaining perch.
- [ ] **Tag path parts `AccessKeepOut`** so the dynamic-post planner omits posts landing on walkways
      (the `PadPlanner` rule is built but dormant until paths are tagged).

---

## Track 3 — Art-pass finish — **~2–4 sessions** (fuzziest)

- [x] **Terrain** — moss/rock PBR (`TerrainDetail` override on Slate), canyon-wide + tuned (2026-07-10).
      Recipe: [[zendojo-mossy-terrain-pbr]] / build-recipes §9.
- [ ] **Foliage scatter** — ferns/plants/rocks + Japanese maple/cherry accents (terrain Phase 3; also hides
      residual flat-area facets + texture tiling). Scatter machinery (raycast-to-surface, orient-to-normal)
      prototyped. See `plans/2026-07-10-zendojo-mossy-gorge-vertical-slice.md`.
- [ ] **Bonshō / shrine** art pass.
- [ ] **Teahouse prints** — the StructureCatalog shoji/tatami texture IDs are PLACEHOLDERS (won't render);
      need real prints via the CC0→localhost→`upload_image` pipeline (§9) + per-size **authored prefabs**
      (size is currently a scale proxy on the one base prefab).
- [ ] *(optional)* **Bridge sway** polish — deferred; continuous per-frame deform (keeps round ropes) or
      Beam cables.
- [ ] **TBD — Bamboo impostor / low-poly LOD** — `RealisticBamboo` is high-poly; canyon-wide rollout needs a
      billboard-cross impostor (pre-render → chroma-key to alpha → localhost `upload_image` → crossed textured
      quads, static near-mesh/far-impostor split) or a Blender-decimated `_LOD` mesh. Prototype not yet built.
      Foliage scatter is otherwise engine-optimized (RenderFidelity Automatic, shadows/collision/query off) —
      see [[zendojo-foliage-scatter]].

---

## Small cleanups — **~1 session**

- [ ] Server follow-ups: identityTier backfill migration (before anything branches on tier), personalHistory
      deviceId-undefined query guard, reveal race-guard test, repo-root eslint config.
- [ ] Commit the place-only `teahouse-1story` prefab via a Rojo `ServerStorage` mount (open follow-up since A).

---

## Estimate summary

| Bucket | Sessions |
|---|---|
| Teahouse migration (Track 1) alone | ~2 |
| **Finish the canyon** (Tracks 1–3 + cleanups) | **~4.5–6.5** |
| Wider meta-game (below) — separate track | ~10+ |

**Wider meta-game (context, NOT in "canyon done"):** D.5 (perch-preference UI), **E** (catalog/economy/equip
UI + ownership gates), remaining **B** (valley footings, pocket-garden applier, dressing), more **C**
(earning/inventory: pets/awards/flags/fireworks). Each its own spec→plan→build — the bulk of the game economy.

**Biggest estimate risks:** per-site size/spacing tuning; the art pass ballooning with taste iteration
(like the terrain tonight — great result, many rounds); teahouse prints need real art assets.
