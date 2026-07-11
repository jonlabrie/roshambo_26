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

- [ ] **Re-survey the 14 pad locations in `Sandbox/PadRefs`** (`PadRef_T01–T14`) → Deck-anchored `mountCF`
      + terrain-derived `maxSize` per site. **Clearance/spacing already user-verified** ✓ — so the D.4-backlog
      spacing-collision pass is NOT needed; just read each site's current max.
- [ ] **Regenerate `PadSites.luau`** from the current PadRef locations (the D.4 bake surveyed the old
      `CanyonTeahouses.Teahouse_01–14`; the authoritative locations are now the PadRefs).
- [ ] **Register all 14 as SITES** and wire the runtime to materialize across all 14 (scale the proven 1–2-pad
      loop; large-first size-cap assignment via the registry).
- [ ] **Retire the 14 legacy `CanyonTeahouses`** (freeze/remove; runtime-materialized teahouses replace them).
      The old T05/T06 left-hand shoji/SideWall bug resolves itself on materialization (the MirrorX-tagged prefab).
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
