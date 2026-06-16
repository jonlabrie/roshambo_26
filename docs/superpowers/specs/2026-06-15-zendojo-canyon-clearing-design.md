# ZenDojo Canyon — The Clearing (Focal Heart) — Design

**Goal:** Build the canyon's gathering heart: a leveled riverside clearing where ~50 players watch the World Throw resolve on the ported bell/throw machine, staged against the waterfall and plunge pool that drive it, with the river meandering past and out the lowest fall.

**Architecture:** The clearing sits at the canyon's world origin on the imported (1.5×) terrain. The eroded floor is leveled to a gentle grade by a targeted MCP terrain operation. The proven bowl machine (bell, shu-moku striker, shōrō pavilion, throw drum, waterwheel, sōzu, kōsatsu flip-boards) and its client controllers are **ported and re-staged** at clearing coordinates — components are largely position-driven, so re-staging is a coordinate + minor-geometry change, not a rebuild. Water (plunge pool, in-fall, boundary fall) is Roblox terrain water plus fall/mist VFX. Coordinate authority moves from the bowl's radial `ArenaLayout` to a canyon clearing layout (see §7).

**Tech Stack:** Luau, Rojo, Lune tests, Roblox Terrain (WriteVoxels) + water, MCP Roblox Studio for terrain ops and gates.

**Scope:** This spec covers ONLY the clearing focal heart — terrain leveling of the clearing shelf, the immediate water (plunge pool + in-fall + boundary fall), re-staging the ported machine + controllers, the flip-boards, and the sandy outcrop gathering space. Out of scope (later specs): teahouse placement, the full-gorge river/falls cascade, the circulation network (paths/stairs/bridges), and atmosphere (lighting presets, fireflies, planting).

This extends the canyon redesign ([2026-06-15 canyon greybox / memory `zendojo-canyon-redesign`]). The bowl arena it replaces is preserved in git.

---

## 1. Vibe & guiding principle

The clearing is the one place every player ends up and where the *game* visibly happens. It must read as a **natural riverside shrine-clearing** — a flatter shelf the river carved, made into a gathering place — with the **waterfall as the energy source** driving the machine. The machine is "nature gently put to work": water enters the clearing as a fall, drives the wheel, and leaves as a fall. Restraint over spectacle; the falls + pool + centred shrine are the focal composition seen from the outcrop and from every teahouse perch above.

## 2. Spatial layout (the staging)

World frame: clearing centre ≈ world origin; the canyon runs along X (upstream/head at −X, downstream/boundary at +X); Z is cross-canyon. (Terrain imported at 1.5× — see the canyon-redesign memory for the world↔contract mapping.)

- **Back third (upstream, −X):** the **plunge pool** at the base of the **in-fall waterfall** — where water enters the clearing.
- **Centre, at the pool's downstream lip:** the **machine**, on the clearing centreline so the bell is the hero focal point and stays visible from the teahouse perches up-canyon (NOT tucked against the cliff).
- **Front two-thirds (downstream of the machine):** the enlarged, leveled **sandy outcrop** — the gathering space for ~50, facing back/up at the machine + pool + falls.
- **River:** meanders out of the pool, **past one side of the machine**, across/beside the outcrop, and exits the **lowest/boundary fall** at the downstream edge (a view platform there; players cannot pass).
- **Sightlines:** players on the outcrop face the machine; teahouse perches on both walls look down to it. Verified by raycast when teahouses are placed (later spec) — the centred, off-cliff machine placement is chosen to keep those sightlines open.

## 3. Terrain — leveling the clearing shelf

The eroded clearing floor descends ≈60 studs across its length (too steep for a standing crowd). A targeted terrain operation **levels the clearing into a gentle-grade shelf** — one broad flat-ish gathering surface (a slight downstream grade is fine; not stepped terraces). This is done in `tools/studio/buildTerrain.luau`-style MCP WriteVoxels over the clearing region only (the surrounding gorge walls untouched), or a Studio sculpt pass; it is verified at the terrain gate. The leveled shelf sits a little above the pool (so the pool reads as recessed at the back) and above the downstream lip (so the river drops away to the boundary fall).

## 4. Water (clearing-immediate)

- **Plunge pool:** terrain `Water` filling the back-third basin to a flat level; recessed below the outcrop shelf.
- **In-fall:** a waterfall sheet entering at the upstream end into the pool — water-plane mesh + `Beam`/particle mist (custom VFX, since mesh/steep terrain can't use terrain water for a vertical sheet). A short **flume/launder** taps the in-fall and runs to the wheel top (§5).
- **Boundary fall:** the river leaves the downstream edge as the lowest fall — same VFX treatment — with a **view platform** and an invisible barrier (no further travel).
- The river between pool and boundary fall is terrain water in a shallow channel that **meanders past the machine**.

## 5. The machine — ported & re-staged

Port the bowl machine wholesale and re-stage it centred at the pool's downstream lip. Components (existing builders in `roblox/tools/builders/`, controllers in `roblox/src/client/`):

- **Bonshō bell** (`Bonsho.luau`) + **shu-moku striker** — the bell hangs at the centre; the striker swings to gong it on reveal. `HammerController` re-aimed to the clearing axis.
- **Shōrō pavilion** (`Shoro.luau`) — houses/frames the bell; the **throw drum** rides it (or sits beside) as in the bowl.
- **Throw drum** (`ThrowDrum.luau`) + `DrumController` — **unchanged behavior** (hold during ACTIVE → spin at lockout → glide to rest at gong).
- **Waterwheel** (`Waterwheel.luau`) — **now OVERSHOT**: sits **above** the pool, fed on top by the flume, draining into the pool below (no submersion/drag). This flips the wheel's spin direction vs. the bowl's undershot — `WheelController` spin sign updated. Drives the striker as before.
- **Sōzu** (`Sozu.luau`) + `SozuController` — beside the wheel; fills through ACTIVE, dumps/clacks at lockout, kicks the drum. Fed by a small bleed off the flume.
- **Kōsatsu flip-boards** (`BoardController` / board renderer) — **two human-scale boards** flanking the machine, facing the outcrop. **Clearing-local readability only** (sized/placed for nearby players, NOT for distant perches). Replaces the bowl's single large jumbotron-scale board.

The whole round still plays out visibly: drum spins → sōzu clacks at lockout → drum reveals → bell gongs at reveal → boards flip. Controllers keep their `EventBus`/round-cue wiring; only positions/axes (and the wheel spin sign) change.

## 6. The gathering space (outcrop)

The leveled **sandy outcrop** is the front two-thirds of the clearing — a believable flat surface for ~50 players, with a gentle downstream grade. Capacity sanity: ~50 players at ~4×2 stud footprints need well under the outcrop's area; it is comfortably sized with room for movement around the machine and to the river's edge. Spawn pads for arrivals are placed here (the spawn-choice UI is a later runtime feature; this spec just reserves clustered spawn points on the outcrop).

## 7. Components to change

- **Canyon coordinate authority:** introduce the clearing's coordinates as the canyon's monument-zone authority. The plan decides whether to (a) retrofit `ArenaLayout.luau`'s monument/machine coordinates to the clearing, or (b) add a `CanyonLayout` module (the `docs/superpowers/canyon/CanyonLayout.luau` draft) wired into `genmodels`/`default.project.json`. Either way: one source of truth for bell/shōrō/drum/wheel/flume/sōzu/board positions + the strike axis, mirrored into the controllers' inlined constants.
- **Terrain (`tools/studio/buildTerrain.luau` or a clearing-specific MCP script):** level the clearing shelf; carve the plunge-pool basin, the river channel, and the boundary-fall lip; fill with terrain water. MCP-run, verified at the terrain gate.
- **Builders:** `Waterwheel.luau` — overshot variant (raised above water; flume feeds the top). `Shoro`/`Bonsho`/`ThrowDrum`/`Sozu` — re-staged via layout coords (geometry largely unchanged). Flip-board builder/renderer — two human-scale boards.
- **Controllers (`src/client/`):** `WheelController` — spin sign flipped (overshot) + new wheel position. `HammerController` — re-aim the strike onto the clearing axis (preserve the approved swing *feel*; only heading/positions change). `SozuController`, `DrumController`, `BoardController` — re-target positions; behavior unchanged.
- **Fall/mist VFX:** in-fall and boundary-fall water sheets (mesh + Beam + particle mist), reusable for the wider gorge falls later.
- **Server:** mark the clearing/machine stage models `ModelStreamingMode.Persistent` (same lesson as the bowl — controllers capture parts at startup).

## 8. What to preserve (risks)

- **The approved drum behavior and hammer swing feel** — port intact; re-aim/re-position only.
- **Round-cue wiring** — controllers keep their `EventBus`/phase cues; the round still reads (spin → clack → reveal → gong → flip).
- **Overshot correctness** — the wheel must sit above the tailwater and be fed on top; verify the spin direction reads as water-driven (front/loaded side descending).
- **Bell visibility from up-canyon** — the centred, off-cliff placement is the whole reason for centring; verify the bell isn't occluded from representative perch positions.
- **Gameplay legibility** — flip-boards readable by clearing players; the bell/drum reveal readable across the outcrop.
- **Controller ↔ layout sync** — inlined client constants mirror the layout at build time; every coordinate move updates both.

## 9. Testing

- **Layout spec** (Lune): clearing machine coordinates are self-consistent — bell on the centreline; wheel above the pool water level (overshot); flume spans in-fall→wheel-top; sōzu beside the wheel; boards flank the machine facing the outcrop; nothing buried.
- **Builder specs:** overshot `Waterwheel` parts/position; re-staged machine members present.
- `genmodels` drift check, `stylua`/`selene`, `rojo build` green.
- **USER GATEs (MCP):**
  - *Terrain gate:* clearing leveled to a gentle grade; pool/river/boundary-fall basins hold continuous water; outcrop is a believable flat gathering surface.
  - *Machine gate:* full round plays out live in the clearing (drum spin → sōzu clack → reveal → bell gong → boards flip); overshot wheel reads right; hammer strikes true on the clearing axis; bell visible from sample perch positions.

## 10. Build sequence (for the plan)

1. **Canyon coordinate authority** — establish the clearing machine coordinates (resolve the ArenaLayout-vs-CanyonLayout decision); update controller constants.
2. **Terrain** — level the clearing shelf; carve pool/river/boundary-fall; fill water. **Terrain gate.**
3. **Overshot waterwheel** — builder variant + `WheelController` spin fix; flume re-route (in-fall→wheel-top→pool).
4. **Re-stage the rest of the machine** — bell/shōrō/drum/sōzu at clearing coords; re-aim `HammerController`; re-target `SozuController`/`DrumController`.
5. **Flip-boards** — two human-scale kōsatsu flanking the machine (`BoardController`/renderer), clearing-local.
6. **Fall/mist VFX** — in-fall + boundary-fall sheets + mist; basin ripples.
7. **Outcrop finish + spawn points.**
8. **USER GATE:** full clearing live (terrain + water + machine + a round playing out), then tune.
