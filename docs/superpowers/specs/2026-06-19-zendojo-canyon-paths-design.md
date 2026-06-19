# ZenDojo Canyon Paths — Design

**Status:** approved design, pre-plan (2026-06-19)
**Branch:** `m4b-zendojo-art-pass`
**Sub-project 1 of the "canyon village"** (paths → teahouses → bridge → interiors/spawns)

## Goal

Build the **circulation network** of the ZenDojo canyon: the lantern-lined, railed stone/timber paths and staircases that let players move from the clearing up both gorge walls and around the gorge, with junction landings. This is the *skeleton* the teahouses (sub-project 2) and bridge (sub-project 3) attach to.

North Star: the canyon-village reference images — mossy gorge, stone-paver switchback stairs with slim timber handrails, standing white-chōchin lantern poles + stone ishidōrō at the path edge, warm dusk lanterns, stilted teahouses up both walls, a suspension bridge at the pinch.

## World frame (context)

- Clearing at world origin, floor ≈ y112. Gorge runs up-canyon (−X, the Gaea head with the tall hero falls) and down-canyon (+X, the hand-carved gorge with the overlook decks, pools, and the 4 reworked waterfalls). Walls on both ±Z sides; rim well above the floor.
- Terrain is organic (imported + hand-carved). **Y is always provisional** — every path point must be raycast-snapped onto the live terrain surface.
- Existing reusable builders: `StoneLantern.luau`, `Bridge.luau` (generic), `Spec.luau` (part/model spec helpers), `ArenaLayout.luau` (coordinate authority). `Footpath.luau` is bowl-era (garden ring paths) — **not reused as-is**; a new `CanyonPath` builder is written instead.
- Place has `StreamingEnabled = true`; ~50 players/server.

## The path kit (reusable pieces)

A small set of pieces the builder composes per route segment:

1. **Tread** — **8-stud clear walking width** (confident two-abreast; avatar ≈4 studs visual). Two surface modes chosen by segment grade:
   - **Paver run** where grade ≤ ~15°: flat-ish stone paver tread laid on the terrain surface.
   - **Steps** where grade > ~15°: stone/timber step treads stacked down the slope (decorative).
2. **Walkability ramp (collision)** — beneath the decorative tread, a continuous **invisible smooth collision ramp** (`CanCollide = true`, `Transparency = 1`) following the route at the tread surface. Decorative pavers/steps sit on top **non-colliding**. Rationale: Roblox characters only auto-step ~2 studs, so real collidable stairs on organic terrain are janky; the smooth ramp guarantees clean traversal while the visible steps carry the look. Keep ramp slope ≤ ~45° so walking is reliable; steeper pitches become more/shorter switchback segments instead.
3. **Railings** — slim **timber posts + a single top rail** (lighter than the deck kōran), ~3 studs high. On the **drop side always**; both sides on exposed spans/brid-adjacent runs. Posts at a regular spacing along the segment.
4. **Lanterns at intervals (~every 20–24 studs along a route)** — alternating:
   - **standing chōchin pole** (white paper lantern on a dark post; Neon body + warm `PointLight`), and
   - **stone ishidōrō** at the path edge (reuse/extend `StoneLantern`),
   - plus occasional **hanging chōchin** where a tree/eave overhangs.
   Lanterns are warm (matching the existing deck telegraph palette). Hooking path lanterns into the lantern *telegraph* is explicitly **out of scope** (future).
5. **Junction landings** — where routes branch/meet, a **~14–18-stud paver clearing** (a small flat node), usually with a feature lantern.

## Route topology

Defined as **polylines of ordered waypoints**. Authoring method **B**: the builder/agent drafts a first-pass set of draggable waypoint markers on the live terrain; the user nudges/adds/deletes; final waypoints are baked into `ArenaLayout`.

Main routes (qualitative — exact geometry comes from the waypoint pass):
- **Near-wall trunk** — switchbacks up the near gorge wall from the clearing.
- **Far-wall trunk** — switchbacks up the far wall.
- **Floor path** — along the river from the clearing.
- **Pinch-bridge crossing** — links the two wall trunks at the pinch (the bridge *structure* is sub-project 3; here the trunks simply terminate at stub abutment points so the loop is ready to close).
- **Overlook spur** — connects to the existing twin overlook decks.

**Circumnavigation requirement:** the network must form **at least one continuous loop** around the gorge — floor + near-wall + far-wall, closed at the bottom by the clearing and at the top by the pinch-bridge crossing. (Until the bridge exists the two wall trunks form a "U" joined at the clearing; the bridge closes the loop.)

**Path classes:**
- `trunk` — the main 8-stud loop routes above.
- `spur` — narrower **private teahouse-access branches** off the loop (default ~5-stud tread, still railed + lit, more modest lantern rhythm). Spurs are *built* during teahouse placement (sub-project 2), but the `CanyonPath` builder supports the `spur` class from the start.

## Build pipeline

- **Waypoint authoring:** routes live as `{ name, class, waypoints = { {x,y,z}, ... } }`. Agent drafts markers in Studio (method B) → user adjusts → coordinates baked into a new **`paths` block in `ArenaLayout`**. (X/Z authoritative; Y provisional → snapped.)
- **`CanyonPath` builder (`tools/builders/CanyonPath.luau`):** pure logic that, given a route's waypoints + palette, emits the spec for tread + ramp + rails + lanterns:
  - classify each segment (paver vs steps) by grade,
  - place rail posts and lanterns at their spacings,
  - emit junction landings at shared waypoints.
  Pure/deterministic (sin-hash or LCG jitter only — no `math.random`, to pass CI drift checks), so it is **Lune-testable**.
- **Live snap pass (`tools/studio/buildPaths.luau`, MCP/Edit):** raycasts each waypoint and intermediate tread point down onto the terrain for Y + normal, then materializes the `CanyonPath` specs into `workspace.RoshamboStage` (e.g., under a `CanyonPaths` folder). Mirrors the `buildClearing`/`buildDowncanyon` pattern. Idempotent (rebuild the folder each run). Snapshot terrain only if it writes voxels (it shouldn't — paths sit on top).
- **Reproducible:** committed model JSON for the pure-buildable parts where practical; the snap pass is re-runnable from the baked waypoints.

## Testing

- **Lune unit tests** for `CanyonPath` pure logic: segment grade → paver/steps classification; lantern interval spacing (count over a known-length route); rail post spacing; spur vs trunk width; landing emission at a junction waypoint.
- **Manual/Studio gate:** run the snap pass, walk the loop in Play (verify the invisible ramp gives clean traversal, no gaps, rails on drop sides, circumnavigation works), review lighting rhythm at dusk.

## Scope (YAGNI)

**In scope:** the path kit (tread, collision ramp, rails, lanterns, landings), the trunk loop + floor + overlook spur routes, the `spur` path class, the `CanyonPath` builder + `buildPaths` snap pass + `ArenaLayout.paths` schema, Lune tests.

**Out of scope (later sub-projects / future):**
- Teahouses and their spur paths' actual placement (sub-project 2).
- The suspension-bridge **structure** (sub-project 3) — only stub abutment endpoints here.
- Spawn points / fast-travel between landings.
- Hooking path lanterns into the lantern *telegraph*.
- Carving paths into the terrain (paths sit on top via the collision ramp).

## Open parameters (sensible defaults, tune at the gate)

- Trunk tread width 8 / spur 5 studs; rail height ~3; lantern interval ~20–24; landing size ~14–18; grade threshold ~15° for steps; max ramp slope ~45°.
