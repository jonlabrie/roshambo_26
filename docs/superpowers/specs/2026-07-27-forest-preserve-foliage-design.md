# Forest Preserve Foliage — Design

**Date:** 2026-07-27
**Status:** Approved in brainstorm; supersedes the arrangements-based planting approach for the upper canyon (the 13-arrangement draft row has been removed from the place).

## Vision

The experience is a privately managed, exclusive resort built in an otherwise pristine forested
canyon — intimate, not expansive. The western (upper) canyon becomes a **forest preserve**: plenty
of trees, never enough to seriously impede movement, with the falls and pool chain as the
destinations players discover. Two aesthetic laws govern everything:

1. **Care gradient.** Pruned/tended flora (niwaki, sakura, groomed plantings) appears only where
   the resort visibly tends: the square, path edges, teahouse approaches. The preserve is the
   untended zone: sugi, wild conifers, ferns, moss, reeds. Players read where they are by how
   groomed the trees look.
2. **Fitted to the space.** Nothing is placed as a fixed-size composition. Planting derives from
   zone volumes drawn against the real terrain plus per-zone density — the failure mode of the
   retired arrangements (pre-composed groups, out of scale for their sites) is structurally
   impossible.

The ground-level feel is a Japanese cedar grove (kodachi): tall straight trunks, high canopy, open
shaded floor, filtered light — sugi-dominant like a real plantation forest, with momiji reserved
as rare placed jewels.

## Scope

**In:** foliage for the western canyon (zones, scatter tooling, new SugiMid asset grade, waterline
species cull and top-up, optional ground-mist layer with a fireflies-ready ambience seam).

**Out (explicitly future):** destination settings (fishing dock on the upper pool, one or two
clearings near the lower falls, collectible fauna), and the one-or-two discovery paths connecting
them — paths become obvious only after the destinations exist. The preserve must not preclude
them: reservation zones keep those sites nearly empty so future builds remove almost nothing.

## Zones & Recipes

Zone volumes are place-only authoring artifacts in `Workspace.Sandbox.FoliageZones`: translucent,
color-coded Parts (box or cylinder) the user drags/resizes/duplicates freely. Attributes:
`Recipe` (string), `DensityScale` (number, default 1), optional `Mist` (bool), optional `Seed`
override. Overlapping zones are permitted; `KeepOut` always wins.

Recipes live in one committed module, `roblox/tools/studio/foliageZoneRecipes.luau`:

| Recipe | Palette | Character |
|---|---|---|
| `PreserveCore` | SugiMid ~75%, FirM 15%, CedarS 10% | Walkable forest body. Spacing band 14–22 studs with occasional 2–3-tree clumps; slope limit; stays a few studs off the waterline. |
| `WallFringe` | Blob conifers (ConiferA/B/C) + CedarM, larger scale | Backdrop only — canyon walls, high ledges, far banks. Tighter spacing, steeper slopes allowed. |
| `WaterMargin` | Reeds / muhly grass / ferns; lilies only where the zone sets `Still = true` (calm pond surfaces) | Top-ups after the tropical cull. |
| `FutureClearing` | PreserveCore palette at ~30% density; inner half empty | The dock/clearing reservations. |
| `KeepOut` | Nothing | Paths, builds, water, spawn sightlines. |

## Scatter Engine

Extends the Lune-tested `CanopyScatter` core:

- Deterministic per-zone integer-LCG seed — re-runs reproduce exactly; no `Date.now`/randomness.
- Dart-throw placement honoring the recipe spacing band, with a clump bias option.
- Per-tree terrain raycast (terrain only), scale jitter (~±15%), random yaw.
- Mandatory per-clone engine flags per the scatter standard (RenderFidelity Automatic; CastShadow,
  CanQuery, CanTouch off), with one deliberate exception: **Mid- and hero-grade trunk parts keep
  `CanCollide = true`** (players must not ghost through the forest). Foliage parts and wall blobs
  are fully non-collidable.
- Output bakes to `Workspace.CanyonWorld.Foliage.Preserve.<ZoneName>` folders — wipe-and-rerun is
  **per zone**, so tuning one area never disturbs another.
- Hand curation (deleting/nudging individual trees, placing jewels) happens only after zone shapes
  are final; re-runs before that point are free, and none run after curation begins.

## Assets & Grades

| Grade | Asset | Role |
|---|---|---|
| Hero | Existing 6 sugi (~68k tris, 4 meshes) | Postcard moments only: falls frame, bridge approach, preserve entrance. |
| **SugiMid (new)** | 3 variants from the vendor set (~22 / 26 / 30 studs) at **~10k foliage + ~4k wood each** | The forest body. Under the importer's 20k file budget = one FBX carrying its two meshes (foliage + wood) — no part-splitting or manifest assembly. Fewer-but-larger cards with spray-scale compensation; smart wood favors trunk + major branches over fine twig count. Ships **single-sided** (the A13 rule for mass foliage); if thin at the gate, bump card count — do not reach for DoubleSided. |
| Blob | Kit ConiferA/B/C, CedarM/S, FirM (all single-sided) | Wall and distance fill; never adjacent to the player. |
| Jewel | MapleRed / MapleGold | Two or three placed moments (pool bank, falls overlook; later the destination clearings). Sakura stays out of the preserve — it belongs to tended zones. |

**Waterline:** survey the existing margin scatter and list species; cull the palm/cycad-reading
ones (the current tropical read), keep working grasses/ferns, top up via `WaterMargin` recipes.
Muhly grass (on disk) exports through the tree pipeline. Reeds, lilies, and vines are currently
unsourced: inventory first; source missing species (CC0, or toolbox **with the backdoor scan**) or
cut from v1. Vines are the most likely cut (they want cliff/bridge anchors — tended-zone business).

**DoubleSided doctrine (standing):** dense/dark card foliage (hero sugi, niwaki) = true; pale or
blob-canopy foliage = false (transmission blowout — see the sakura incident, 2026-07-26).

## Mist Layer (optional; built last; cuttable)

- Zones with `Mist = true` get invisible anchor parts at ~30-stud spacing, baked to
  `Preserve.Mist`, deterministic like all scatter.
- One ParticleEmitter per anchor: 12–20-stud soft sprites reusing the falls-mist texture, opacity
  0.04–0.09, near-zero velocity with slight lateral drift, emission confined to the bottom ~4
  studs so it pools knee-deep between trunks.
- `MistController.client.luau` (GlyphDayNight subscriber pattern: EventBus `DayNight` +
  `DayNightConfig` attribute backstop) drives intensity — thin silver by day, thicker and lower
  after dusk.
- **Ambience seam (fireflies-ready):** the controller reads its intensity from a small
  preserve-ambience scheduler value rather than raw `nightFactor`. The scheduler derives
  *tonight's mood* deterministically from the same fixed-epoch global clock as day/night, so when
  `FireflyController` arrives, misty nights and firefly nights alternate — identical for every
  player on every server, one shared particle budget, layers crossfade instead of stacking.
  Fireflies themselves are out of scope; only the socket ships.
- Budget: hard cap ~24 emitters, client-side only, live-tune attributes (`MistDensity`,
  `MistNightBoost`) on the stage; the layer deletes cleanly (one folder + one controller).

## Process & Gates

1. **Waterline cull** — survey produces a species list; user approves the cull; cull executes.
2. **SugiMid exports** — 3 variants imported and stood beside a hero sugi and the blobs: the
   *grade-lineup gate* (user judges canopy density and family resemblance before anything
   scatters).
3. **Zone painting** — first-draft zone volumes stamped over the western canyon; user
   drags/resizes/vetoes.
4. **First bake, one zone** — PreserveCore mid-canyon; walk it together; tune recipe knobs;
   re-bake until the feel is right at small scale.
5. **Full bake** — all zones; then **A13 re-bench** standing in the preserve (client memory +
   frame budget) before anything else proceeds.
6. **Hand-curation pass** — jewels placed, offenders deleted/nudged.
7. **Mist layer** — last, behind its own look-and-feel check.
8. **Final gate** — walk-around (day + night) + place save.

Every step is a look-and-veto point: one visual attempt per iteration, then stop and ask.

## Performance Constraints

- Target device: Samsung Galaxy A13 (agreed low-end proxy). Bench verdict on record: sugi heroes
  affordable as accents; zero headroom for double-sided alpha foliage in mass. ~1 GB client
  memory with CPU/GPU at frame budget — the preserve must not push memory meaningfully past that
  or add mass double-sided surfaces.
- All new mass assets single-sided, single-mesh, sharing textures where possible (the six sugi
  already share one 4096 atlas; after import, SugiMid's foliage SurfaceAppearance is pointed at
  that existing atlas asset rather than keeping its own duplicate upload).
- Mist is pure fill rate — capped, dialable, cuttable.
