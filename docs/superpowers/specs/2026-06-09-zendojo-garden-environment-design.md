# ZenDojo Garden Environment — Design

**Goal:** Turn the bottom two terraces into a lush, candle-lit Japanese stroll-garden — teahouses fronting onto living water channels and still reflecting pools, linked by stone paths and arched bridges, dressed in mature foliage, lit at blue-hour dusk with drifting fireflies — so the arena reads as *a special natural place, found and lovingly made into the best place to play.*

**Architecture:** Geometry stays code-driven — pure builders in `roblox/tools/builders/` → committed `assets/*.model.json` (`lune run tools/genmodels`) → referenced in `default.project.json`; `ArenaLayout.luau` remains the single coordinate authority; all water (creek + tier channels + pools) is carved in the MCP-run terrain heightfield `tools/studio/buildTerrain.luau` (not Rojo-synced); atmosphere (lighting presets, fireflies, reflections) runs in client controllers over the existing `EventBus`. This **extends** the creek water-feature rework ([2026-06-09-zendojo-creek-water-feature-design.md](2026-06-09-zendojo-creek-water-feature-design.md)) — the creek now exists and drives the machine; this spec makes the rest of the bowl a garden around it.

**Tech Stack:** Luau, Rojo, Lune test harness, Roblox Terrain (WriteVoxels heightfield), Roblox Lighting + ParticleEmitter/PointLight, MCP Studio for terrain builds and USER GATEs.

---

## 1. Vibe & guiding principle

One continuation of the creek spec's rule: **nothing reads as engineering.** The garden is "nature, gently guided" — water that looks like it found its own way, stone that looks aged and placed by hand, planting that looks decades mature. The mood is **dark and magical, lit by candle and torchlight**, but still legible: a competitive arena where players must read their throw, the bell, and the World Throw across the bowl. Restraint over spectacle — pools of warm light in deep cool shadow, not a floodlit stage.

The bottom two terraces (tier 1, tier 2) carry the water garden. Tier 3 (top) is dry garden — foliage and lanterns only; the water story lives in the lower bowl where the bell and creek are. The shrine/apron level stays raked gravel.

## 2. Tier water gardens (engawa over a garden channel)

The rear **paddy "trench"** on tiers 1 & 2 (currently a broken, dry tanada band in `buildTerrain.luau`) is **removed and replaced** by a **garden water channel that runs in FRONT of the teahouses** — between each hut and the central stone path. The arrangement, per terrace, from the back wall inward toward the arena:

1. **Rear foliage bank** against the wall up to the next tier (mature planting, §5).
2. **Teahouse**, long (door) side facing the centre, as built.
3. **Engawa veranda** — a new platform along the teahouse front, **cantilevered out over the water on timber posts** that drop into the channel. Water passes beneath its lip ("water beneath").
4. **The channel** ("water beside"): per the approved **hybrid** water story, it **flows** where it fronts the huts (gentle current, sound, sparkle) and **widens into still reflecting pools** at the quiet gaps between hut clusters — each pool calm enough to mirror a lantern and the roof line.
5. **Arched timber bridge** from the central path across the channel to each teahouse engawa.
6. **Stone ring path** on the centre side, where players actually move.

Channel water is **terrain** (one continuous waterline, the creek's lesson — no pooled segments). The engawa, posts, and bridges are **builder parts**.

## 3. The natural creek — realism pass

The creek exists but currently reads engineered: a near-straight, constant-width channel on the SW diagonal. Make it read found:

- **Gentle meander** — a sinuous lateral wiggle around the SW drive line, still arriving at the wheel reach (the fast, narrowed reach that drives the wheel is preserved — realism must not starve the machine).
- **Variable width** — pinch and widen along its run.
- **Rocky bed & banks** — scattered river stones, a gravel bar, mossy banks, a few stepping-stone punctuations (no functional crossing; the sandō runs parallel, per the creek spec).
- **One or two grade breaks** — a small riffle and a quiet pool before the wheel race, in addition to the existing tier-wall cascades.
- **The only deliberate man-made touch:** the tasteful timber sluice/weir at the wheel (existing) and the small **branch weirs** that bleed a little creek water into the tier channels at the rim end of each terrace — stone-lined and restrained, the visible reason the garden channels have water.

## 4. Paths & bridges

- **Stone ring path** on the centre side of each terrace — aged cut stone, the main circulation.
- **Arched timber bridges** (dark timber, gentle camber) — one per teahouse, path → engawa.
- **Stepping stones** — mossy fieldstone across the still pools and as garden punctuation.
- **Tier-link slab paths** near the existing N/S/E-W ramps, so the rings connect into one walkable route.
- Paths keep **open sightlines** to the bell — planting and water frame views, never wall them off.

## 5. Foliage (lush, mature)

Layered planting, thick at tier edges and water banks, open over paths and bell sightlines:

- **Japanese maples** — the hero; a few large, leaning ones over the still pools.
- **Black pines** — sculptural, on tier 3 and flanking the torii.
- **Bamboo** stands at the rear foliage banks.
- **Moss, ferns, sedges** along all water edges.
- **Azalea / clipped shrub** low mounds for mass.
- A single hero **weeping cherry** near the entrance/torii.

Built as a `Foliage` scatter from `ArenaLayout` anchors (deterministic placement — the genmodels CI drift rule forbids `math.random`; use the established sin-hash). Trees are low-poly built parts/unions for graybox; a later art pass may swap meshes.

## 6. Lighting & time-of-day

**Blue-hour dusk** ships as **preset #1**, but lighting is built as a **swappable time-of-day preset system** so dawn / deep-night / moonlit / midday are later rows, not a rewrite:

- A **preset** is a small record: `ClockTime`/sky, `Ambient`/`OutdoorAmbient`, `Brightness`, `FogColor`/`FogEnd`, `ColorShift`, and a fixture-warmth + firefly-density factor. Presets live in the theme (`themes/ZenDojo`), keyed by name.
- A client **`TimeOfDayController`** applies the active preset to `Lighting` and broadcasts the active preset on the `EventBus` so ambient layers (fireflies, fixture glow) can key off it. Default preset: `dusk`.
- **Fixtures, restrained:** existing **stone lanterns** (ishidōrō) gain warm `PointLight`s; **standing torches** along the sandō; a few **hanging paper lanterns** at teahouse porches. Warm pools, deep cool shadows.

## 7. Ambient life (fireflies + reflections)

The signature magical layer, gated by the active time-of-day preset (present at dusk/night, faded out by day):

- **Firefly swarms** — a handful of invisible `ParticleEmitter` anchor parts in the foliage and over the pools. Motes: `LightEmission = 1`, `LightInfluence = 0` (self-glow in the dark), low `Rate`, long `Lifetime`, tiny `Speed` + high `Drag` + slight upward `Acceleration`, a fade-in/hold/out `Transparency` sequence with jittered lifetimes for the blink. Hundreds of motes, GPU-cheap, StreamingEnabled-culled.
- **Hero fireflies** — ~16–20 motes near the water/paths carrying a real `PointLight` (`Shadows = false`, `Range` ≈ 8–12, low `Brightness`), animated by **one** Heartbeat loop (sine drift + flicker) so they cast actual glints and reflections. The lights are the only non-trivial cost; the swarm is particles.
- A client **`FireflyController`** owns both, reading the active preset's firefly-density factor (0 by day).
- **Still-pool reflection/ripple** — gentle ripple decals/ParticleEmitters on the still pools so they catch lantern and firefly light.

## 8. Components to change

**Terrain (`tools/studio/buildTerrain.luau`, MCP main-session):**
- **Remove** the paddy-band block; **add** the tier-1/2 front channels + still-pool widenings as terrain water (one continuous waterline each).
- **Meander + rock** the creek (lateral wiggle, variable width, riffle/pool grade breaks); add the branch-weir notches feeding the tier channels.

**Builders (`roblox/tools/builders/`):**
- `Teahouse.luau` — add the **engawa** platform, support **posts** into the channel, and the **front bridge** per hut.
- `TerraceDressing.luau` — **relocate lanterns off the channel** onto the path edge (fixes the L1-8-in-the-trench problem that started this), and add hanging porch lanterns + sandō torches (or a new `Lighting`/`Fixtures` builder if cleaner).
- `Creek.luau` — extend dressing with meander rocks, the riffle/pool stones, branch-weir stones.
- `Footpath.luau` *(new)* — stone ring paths, stepping stones, tier-link slabs.
- `Bridge.luau` *(new)* — arched timber bridges (or fold into `Teahouse` if a bridge is always hut-bound; **decision: separate `Bridge` builder**, since stepping-stone/standalone crossings also want it).
- `Foliage.luau` *(new)* — maples, pines, bamboo, shrubs, moss/fern ground cover, the hero cherry, from layout anchors.

**`ArenaLayout.luau`:** add `waterGarden` (per-tier channel inner/outer radius, still-pool centres, branch-weir points), `footpath` (ring radii, tier-link points), `bridges` (per-hut crossing points), `foliage` (anchor clusters by species), and `firefly` (emitter anchors, hero-light ring). Coordinate authority for everything above.

**Theme (`src/shared/themes/ZenDojo` + `ThemeManifest`):** add the **time-of-day preset table** (dusk first) and firefly/fixture material+colour entries.

**Controllers (`roblox/src/client/`):**
- `TimeOfDayController.client.luau` *(new)* — apply preset to `Lighting`, broadcast active preset on `EventBus`.
- `FireflyController.client.luau` *(new)* — particle swarms + hero PointLights, gated by preset density.
- Existing reveal/board/hammer/wheel controllers — **unchanged** by this spec.

## 9. What to preserve (risks)

- **The creek's fast wheel reach** — meander/realism must not slow or starve the current that drives the wheel. The narrowed fast reach stays; the wiggle is upstream of it.
- **Bell sightlines** — planting and bridges must not block any player's view of the bell or the World Throw. Verify at the gate from multiple seats.
- **Gameplay legibility at dusk** — the dark-magical mood must not make the throw UI, bell, or World Throw hard to read. The dusk preset is tuned for readability first.
- **Deterministic builders** — foliage/firefly scatter uses the sin-hash, never `math.random` (genmodels CI drift check).
- **ArenaLayout ↔ controller sync** — inlined client constants mirror `ArenaLayout` at build time; every coordinate move updates both (keep-in-sync comments).
- **StreamingEnabled** — new stage models get `ModelStreamingMode.Persistent` server-side (the lesson from the wheels), so controllers see their parts.

## 10. Testing

- `ArenaLayout.spec` — channels inside their tiers and clear of huts; pools mirror lantern anchors; footpath rings between tier radii; bridges span path→engawa; foliage/firefly anchors on solid ground, off the water, clear of sightlines.
- Builder specs — `Teahouse` gains engawa+posts+bridge members; `Footpath`, `Bridge`, `Foliage` emit expected parts; `TerraceDressing` lanterns sit on the path edge, not in the channel band.
- Theme spec — preset table has `dusk`; each preset has the required lighting fields; firefly density present.
- `genmodels` drift check green; `stylua` / `selene` / `rojo build` pass.
- **USER GATEs (MCP, main session):**
  - *Terrain gate:* tier channels + pools hold continuous water; creek reads natural; no dry trenches; lanterns out of the water.
  - *Atmosphere gate:* dusk preset reads dark-magical yet legible; fireflies drift and reflect on the pools; fixtures pool warm light; sightlines to the bell intact.

## 11. Build sequencing (for the plan)

1. **ArenaLayout** — add `waterGarden`, `footpath`, `bridges`, `foliage`, `firefly`; remove paddy assumptions.
2. **Terrain** — remove paddy band; carve tier channels + still pools + branch weirs; meander/rock the creek. **MCP terrain gate.**
3. **Teahouse** — engawa + posts + front bridge.
4. **Footpath + Bridge** builders; **TerraceDressing** lanterns relocated.
5. **Foliage** builder + anchors.
6. **Theme** time-of-day preset table (dusk) + `TimeOfDayController`; fixtures lit.
7. **FireflyController** + pool reflections.
8. **USER GATE** — full garden live at dusk; tune water, planting, light, fireflies.

> Natural seams: steps 1–5 are the **physical garden** (terrain + builders), 6–7 the **atmosphere** (presets + ambient). If the single plan grows unwieldy, split there into two plans — each is independently testable.
