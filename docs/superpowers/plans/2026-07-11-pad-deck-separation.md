# Pad / Deck Separation (Piece A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the deck a hand-agnostic S/M/L **pad** (deck slab + beam frame + posts) built procedurally, and make the teahouse a **building-only** prefab placed onto the deck via an authored `placement` — fixing the stray-post and left-hand mirror bugs.

**Architecture:** Three units with clean seams — `PadBuilder` (procedural deck+beams+posts, hand-agnostic), `StructureBuilder` (building-only prefab), `BuildingPlacer` (pure offset+facing transform + fit-check). `TreatmentApplier` composes them: build pad → build building → place → fit-check → shutter/lit. Pure math/data modules are Lune-tested; Roblox part builders are visual-gated (the established pattern for `TreatmentApplier`/`PadOps`).

**Tech Stack:** Luau; Lune test harness (`lune run tests/run`); Rojo → Studio; CollectionService tags on a `ServerStorage.StructurePrefabs.teahouse-1story` prefab authored by `tools/studio/captureTeahouseBase.luau`.

## Global Constraints

- **Dependency injection:** Luau modules NEVER `require` each other except pure siblings; runtime deps (Roblox datatypes) are injected as an `ops`/`Deps` table. Same files run under Lune (tests) and Roblox (runtime). Pure modules = Lune-tested; Roblox builders = visual-gated.
- **12-number CFrame arrays** everywhere in the pure layer (`Spec.cframe` order = pos x,y,z then row-major 3×3): `world = pos + R*local`. Build a real CFrame with `CFrame.new(table.unpack(cf12))`.
- **Area scale intent:** deck sizes scale by **√area** — `S=1.0`, `M=√1.3≈1.1402`, `L=√1.6≈1.2649` linear (= `SizeClasses.scale`). Do NOT reintroduce linear 1.3/1.6.
- **Deck datum = veranda-floor underside (local Y=0)**; posts live below it and are already `PadBuilder`'s job. The deck slab top is the `y=0` plane the building sits on.
- **Deck part set** (to move out of the prefab into `PadBuilder`): `EngawaF, EngawaS, EngawaSupport, Perim F/B/L/R, Joist, Girder, Koran, Newel, Baluster, RailCap, RailMid`. **`Tatami` stays building-side** (interior mat). There is NO part named `Deck`/`EngawaBarrier`/`WallPost` — do not invent them.
- **Test harness matchers (ONLY these exist):** `.toBe`, `.toEqual`, `.toBeCloseTo(expected, eps?)`, `.toBeTruthy`, `.toBeNil`, `.toThrow` (wrap the throwing call in a closure). No `toBeFalsy`/`toContain`/`.not`.
- **Piece A uses per-site DEFAULTS** authored in `PadSites`. Separate deck/teahouse OWNERSHIP (the `owned = {[sizeClass]: loadout}` server data) is **Piece B** — do not touch the server or `net:getTeahouses` here.
- **S deck = 26 × 20** (fixed here), local `X[-13,13], Z[-10,10]`, symmetric & centered on the mount. Reference building footprint ≈ 18.7 × 12.7; engawa ≈ 7.5.
- **Commit trailers** on every commit:
  ```
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ
  ```
- **Run tests with** `lune run tests/run` from `roblox/` (whole suite; the harness auto-discovers `tests/*.spec.luau`). There is no single-test runner flag.

---

# PHASE 1 — Pure foundation (Lune-tested, unwired)

New pure modules only; zero runtime behavior change until Phase 3 wires them. Safe to land independently.

## Task 1: Symmetric deck footprint

**Files:**
- Modify: `roblox/src/shared/SizeClasses.luau`
- Test: `roblox/tests/SizeClasses.spec.luau`

**Interfaces:**
- Consumes: existing `SizeClasses.scale` (`S=1.0, M=√1.3, L=√1.6`), existing `Footprint` type.
- Produces: `SizeClasses.DECK_BASE: Footprint` and `SizeClasses.deckFootprint(deckSize: string): Footprint` — the **symmetric, centered** deck extent (distinct from the legacy `BASE_FOOTPRINT`/`footprintFor`, which stay untouched this phase).

- [ ] **Step 1: Write the failing test** — append inside `tests/SizeClasses.spec.luau` (new `describe`):

```luau
describe("SizeClasses.deckFootprint", function()
    test("S deck is symmetric 26x20 centered on the mount", function()
        local d = SizeClasses.deckFootprint("S")
        expect(d.minX).toBeCloseTo(-13)
        expect(d.maxX).toBeCloseTo(13)
        expect(d.minZ).toBeCloseTo(-10)
        expect(d.maxZ).toBeCloseTo(10)
    end)
    test("M and L decks scale each side by sqrt(area) and stay centered", function()
        local function ctr(f) return (f.minX + f.maxX) / 2, (f.minZ + f.maxZ) / 2 end
        local m = SizeClasses.deckFootprint("M")
        local cx, cz = ctr(m)
        expect(cx).toBeCloseTo(0)
        expect(cz).toBeCloseTo(0)
        expect(m.maxX).toBeCloseTo(13 * math.sqrt(1.3))
        local l = SizeClasses.deckFootprint("L")
        expect(l.maxZ).toBeCloseTo(10 * math.sqrt(1.6))
    end)
    test("deck AREA scales by the size factor", function()
        local function area(f) return (f.maxX - f.minX) * (f.maxZ - f.minZ) end
        local s = area(SizeClasses.deckFootprint("S"))
        expect(area(SizeClasses.deckFootprint("L")) / s).toBeCloseTo(1.6)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lune run tests/run`
Expected: FAIL — `attempt to call a nil value (field 'deckFootprint')`.

- [ ] **Step 3: Implement** — in `SizeClasses.luau`, after `footprintFor`:

```luau
-- The DECK/pad extent (symmetric, centered on the mount) — distinct from the legacy
-- post-only BASE_FOOTPRINT. S = 26 x 20. Scales each side by sqrt(area) via `scale`.
SizeClasses.DECK_BASE = { minX = -13, maxX = 13, minZ = -10, maxZ = 10 } :: Footprint

function SizeClasses.deckFootprint(deckSize: string): Footprint
    local s = SizeClasses.scale[deckSize]
    local b = SizeClasses.DECK_BASE
    return { minX = b.minX * s, maxX = b.maxX * s, minZ = b.minZ * s, maxZ = b.maxZ * s }
end
```

- [ ] **Step 4: Run to verify it passes**

Run: `lune run tests/run`
Expected: PASS (count +3).

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/SizeClasses.luau roblox/tests/SizeClasses.spec.luau
git commit -m "feat(roblox): symmetric centered deck footprint (deckFootprint) [trailers]"
```

## Task 2: Placement transform (offset + facing → CFrame)

**Files:**
- Create: `roblox/src/shared/BuildingPlacer.luau`
- Test: `roblox/tests/BuildingPlacer.spec.luau`

**Interfaces:**
- Produces:
  - `BuildingPlacer.Placement` type = `{ offset: { number }, facing: string, openSide: string }` where `offset = {dx, dz}` (deck-local studs), `facing ∈ {"N","S","E","W"}`, `openSide ∈ {"left","right"}`.
  - `BuildingPlacer.facingYaw(facing: string): number` — degrees CCW about local Y: `N=0, E=90, S=180, W=270`.
  - `BuildingPlacer.placeCF(placement): { number }` — a 12-number **deck-local** CFrame: translate by `(dx, 0, dz)`, rotate `facingYaw` about Y. This is the building's transform relative to the deck datum; the caller composes it with the deck's world CFrame.

- [ ] **Step 1: Write the failing test** — `tests/BuildingPlacer.spec.luau`:

```luau
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local BuildingPlacer = require("../src/shared/BuildingPlacer")

describe("BuildingPlacer.facingYaw", function()
    test("maps N/E/S/W to 0/90/180/270", function()
        expect(BuildingPlacer.facingYaw("N")).toBe(0)
        expect(BuildingPlacer.facingYaw("E")).toBe(90)
        expect(BuildingPlacer.facingYaw("S")).toBe(180)
        expect(BuildingPlacer.facingYaw("W")).toBe(270)
    end)
end)

describe("BuildingPlacer.placeCF", function()
    test("pure offset with facing N is identity rotation + translation", function()
        local cf = BuildingPlacer.placeCF({ offset = { 3, -4 }, facing = "N", openSide = "left" })
        expect(cf[1]).toBeCloseTo(3)  -- x
        expect(cf[2]).toBeCloseTo(0)  -- y
        expect(cf[3]).toBeCloseTo(-4) -- z
        expect(cf[4]).toBeCloseTo(1)  -- R00 (no yaw)
        expect(cf[12]).toBeCloseTo(1) -- R22
    end)
    test("facing E is a +90deg yaw (R13 = sin90 = 1)", function()
        local cf = BuildingPlacer.placeCF({ offset = { 0, 0 }, facing = "E", openSide = "left" })
        expect(cf[6]).toBeCloseTo(1)   -- R02 = sin(90)
        expect(cf[10]).toBeCloseTo(-1) -- R20 = -sin(90)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lune run tests/run`
Expected: FAIL — module `BuildingPlacer` not found.

- [ ] **Step 3: Implement** — `src/shared/BuildingPlacer.luau`:

```luau
--!strict
-- Pure placer for Piece A. Turns a {offset, facing, openSide} placement into the building's
-- deck-LOCAL transform (12-number CFrame, Spec.cframe order) and answers fit questions. No
-- Roblox datatypes (Lune-tested). `facing` snaps to the deck's 4 edges; `openSide` selects the
-- shoji L-wrap (consumed by StructureBuilder, not here).
local BuildingPlacer = {}

export type Placement = { offset: { number }, facing: string, openSide: string }

local YAW = { N = 0, E = 90, S = 180, W = 270 }

function BuildingPlacer.facingYaw(facing: string): number
    local y = YAW[facing]
    if y == nil then
        error(`BuildingPlacer.facingYaw: bad facing '{facing}'`)
    end
    return y
end

-- Y-axis rotation matrix (row-major) for a CCW yaw in degrees, plus a (dx,0,dz) translation.
function BuildingPlacer.placeCF(p: Placement): { number }
    local rad = math.rad(BuildingPlacer.facingYaw(p.facing))
    local c, s = math.cos(rad), math.sin(rad)
    local dx, dz = p.offset[1], p.offset[2]
    -- pos, then R = [ c 0 s ; 0 1 0 ; -s 0 c ]
    return { dx, 0, dz, c, 0, s, 0, 1, 0, -s, 0, c }
end

return BuildingPlacer
```

- [ ] **Step 4: Run to verify it passes**

Run: `lune run tests/run`
Expected: PASS.

Note: `math.cos`/`math.sin` of these exact multiples of 90° are IEEE-deterministic across arch; not committed as an asset, so no genmodel drift concern.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/BuildingPlacer.luau roblox/tests/BuildingPlacer.spec.luau
git commit -m "feat(roblox): BuildingPlacer placement transform (offset+facing) [trailers]"
```

## Task 3: Fit-check (building within deck at a placement)

**Files:**
- Modify: `roblox/src/shared/BuildingPlacer.luau`
- Test: `roblox/tests/BuildingPlacer.spec.luau`

**Interfaces:**
- Consumes: `BuildingPlacer.facingYaw` (Task 2), `SizeClasses.Footprint` shape (`{minX,maxX,minZ,maxZ}`).
- Produces: `BuildingPlacer.fits(buildingFP, deckFP, placement): boolean` — true iff the building footprint, rotated by `facing` and translated by `offset`, lies entirely within the deck footprint. `facing` is a 90° multiple, so the rotated building AABB is axis-aligned (swap X/Z extents for E/W).

- [ ] **Step 1: Write the failing test** — append to `tests/BuildingPlacer.spec.luau`:

```luau
describe("BuildingPlacer.fits", function()
    local deck = { minX = -13, maxX = 13, minZ = -10, maxZ = 10 } -- S deck 26x20
    local bldg = { minX = -9.35, maxX = 9.35, minZ = -6.35, maxZ = 6.35 } -- ~18.7x12.7 centered
    test("centered, facing N, fits", function()
        expect(BuildingPlacer.fits(bldg, deck, { offset = {0,0}, facing = "N", openSide = "left" })).toBe(true)
    end)
    test("tucked to a corner (leaving engawa) still fits", function()
        expect(BuildingPlacer.fits(bldg, deck, { offset = {3.6, 3.6}, facing = "N", openSide = "left" })).toBe(true)
    end)
    test("overhanging the +X edge does not fit", function()
        expect(BuildingPlacer.fits(bldg, deck, { offset = {5, 0}, facing = "N", openSide = "left" })).toBe(false)
    end)
    test("facing E swaps the building's X/Z extents; 18.7-wide across the 20-deep deck fits", function()
        expect(BuildingPlacer.fits(bldg, deck, { offset = {0,0}, facing = "E", openSide = "left" })).toBe(true)
    end)
    test("facing N with an 18.7-deep building on a 20-deep deck barely fits but not offset", function()
        local tall = { minX = -6.35, maxX = 6.35, minZ = -9.35, maxZ = 9.35 }
        expect(BuildingPlacer.fits(tall, deck, { offset = {0, 2}, facing = "N", openSide = "left" })).toBe(false)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lune run tests/run`
Expected: FAIL — `attempt to call a nil value (field 'fits')`.

- [ ] **Step 3: Implement** — add to `BuildingPlacer.luau` (before `return`):

```luau
type FP = { minX: number, maxX: number, minZ: number, maxZ: number }

-- Rotate a footprint's half-extents by a 90-deg-multiple yaw. 0/180 keep (halfX,halfZ);
-- 90/270 swap them. Footprints are centered on the building's own origin, so we track
-- half-extents then re-center at the placement offset.
function BuildingPlacer.fits(buildingFP: FP, deckFP: FP, p: Placement): boolean
    local halfX = (buildingFP.maxX - buildingFP.minX) / 2
    local halfZ = (buildingFP.maxZ - buildingFP.minZ) / 2
    local yaw = BuildingPlacer.facingYaw(p.facing)
    if yaw == 90 or yaw == 270 then
        halfX, halfZ = halfZ, halfX
    end
    local dx, dz = p.offset[1], p.offset[2]
    return (dx - halfX) >= deckFP.minX
        and (dx + halfX) <= deckFP.maxX
        and (dz - halfZ) >= deckFP.minZ
        and (dz + halfZ) <= deckFP.maxZ
end
```

- [ ] **Step 4: Run to verify it passes**

Run: `lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/BuildingPlacer.luau roblox/tests/BuildingPlacer.spec.luau
git commit -m "feat(roblox): BuildingPlacer.fits (building within deck at placement) [trailers]"
```

**Phase 1 gate:** `lune run tests/run` all green; no runtime behavior changed (new modules unused). Safe checkpoint.

---

# PHASE 2 — Procedural deck geometry (build + visual gate)

Move the deck out of the prefab and build it procedurally. Roblox-part tasks are **visual-gated** (materialize in Studio Play, eyeball) — the established pattern; they have no pure failing test.

## Task 4: Beam/post node layout (pure)

**Files:**
- Create: `roblox/src/shared/PadFrame.luau`
- Test: `roblox/tests/PadFrame.spec.luau`

**Interfaces:**
- Consumes: `SizeClasses.Footprint`.
- Produces: `PadFrame.nodes(deckFP): { {id: string, x: number, z: number} }` — the 6 post/beam nodes (4 corners + 2 mid-long-edge) inset by the post half-width `PH=0.6`; and `PadFrame.beams(deckFP): { {id: string, from: string, to: string} }` — the 5 beams (2 long `FL-FR`,`BL-BR`; 3 short `FL-BL`,`FR-BR`,`MF-MB`). IDs match `PadPlanner` (`FL,FR,BL,BR,MF,MB`).

- [ ] **Step 1: Write the failing test** — `tests/PadFrame.spec.luau`:

```luau
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local PadFrame = require("../src/shared/PadFrame")

local S = { minX = -13, maxX = 13, minZ = -10, maxZ = 10 }

describe("PadFrame.nodes", function()
    test("6 nodes at the corners + mid-long-edges, inset by PH", function()
        local n = {}
        for _, node in PadFrame.nodes(S) do n[node.id] = node end
        expect(n.FL.x).toBeCloseTo(-13 + 0.6)
        expect(n.FL.z).toBeCloseTo(-10 + 0.6)
        expect(n.BR.x).toBeCloseTo(13 - 0.6)
        expect(n.BR.z).toBeCloseTo(10 - 0.6)
        expect(n.MF.x).toBeCloseTo(0)
        expect(n.MF.z).toBeCloseTo(-10 + 0.6)
    end)
end)

describe("PadFrame.beams", function()
    test("2 long + 3 short, tying the 6 nodes", function()
        local b = PadFrame.beams(S)
        expect(#b).toBe(5)
        local pairs_ = {}
        for _, beam in b do pairs_[beam.from .. "-" .. beam.to] = true end
        expect(pairs_["FL-FR"]).toBe(true) -- long front
        expect(pairs_["BL-BR"]).toBe(true) -- long back
        expect(pairs_["FL-BL"]).toBe(true) -- short left
        expect(pairs_["FR-BR"]).toBe(true) -- short right
        expect(pairs_["MF-MB"]).toBe(true) -- short middle
    end)
end)
```

- [ ] **Step 2: Run** → FAIL (`PadFrame` not found).

- [ ] **Step 3: Implement** — `src/shared/PadFrame.luau`:

```luau
--!strict
-- Pure layout of a pad's beam frame and post nodes from a deck footprint. IDs match PadPlanner.
-- 2 long beams (front FL-FR, back BL-BR), 3 short (left FL-BL, right FR-BR, middle MF-MB);
-- posts drop from the 6 nodes (PadPlanner owns the terrain raycast). Pure (Lune-tested).
local PadFrame = {}
local PH = 0.6 -- post half-width; outer face flush to the deck corner

export type FP = { minX: number, maxX: number, minZ: number, maxZ: number }

function PadFrame.nodes(fp: FP)
    local cx = (fp.minX + fp.maxX) / 2
    return {
        { id = "FL", x = fp.minX + PH, z = fp.minZ + PH },
        { id = "FR", x = fp.maxX - PH, z = fp.minZ + PH },
        { id = "BL", x = fp.minX + PH, z = fp.maxZ - PH },
        { id = "BR", x = fp.maxX - PH, z = fp.maxZ - PH },
        { id = "MF", x = cx, z = fp.minZ + PH },
        { id = "MB", x = cx, z = fp.maxZ - PH },
    }
end

function PadFrame.beams(_fp: FP)
    return {
        { id = "Long_F", from = "FL", to = "FR" },
        { id = "Long_B", from = "BL", to = "BR" },
        { id = "Short_L", from = "FL", to = "BL" },
        { id = "Short_R", from = "FR", to = "BR" },
        { id = "Short_M", from = "MF", to = "MB" },
    }
end

return PadFrame
```

- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(roblox): PadFrame beam/post node layout (pure) [trailers]`.

## Task 5: Procedural deck slab + beams + railings (Roblox, visual gate)

**Files:**
- Modify: `roblox/src/server/PadOps.luau` (add deck-geometry ops), `roblox/src/shared/PadBuilder.luau` (build deck from `PadFrame` + `deckFootprint`).

**Interfaces:**
- Consumes: `PadFrame.nodes/beams`, `SizeClasses.deckFootprint`, existing `PadPlanner.planSupport` (posts), existing injected `ops.buildPost`.
- Produces: `PadBuilder.buildDeck(deckSize, mountCF, ops)` — parents a symmetric deck slab, the 5 beams, engawa railings around the deck edge, and the 6 posts into the ops container. Extends the existing `PadBuilder.build` (which currently only plans posts).

- [ ] **Step 1: Add deck-geometry ops** to `PadOps.new(...)` return table — real Roblox parts (a thin slab at `y=0`, wood beams under it per `PadFrame.beams` node coords, railing posts+rails around the perimeter). Use the existing `buildPost` style (anchored, `CanCollide=false`, `CastShadow=false`). Example slab op:

```luau
buildDeckSlab = function(deckFP)
    local p = Instance.new("Part")
    p.Name, p.Anchored, p.CanCollide, p.CastShadow = "PadDeck", true, false, false
    p.Size = Vector3.new(deckFP.maxX - deckFP.minX, 0.5, deckFP.maxZ - deckFP.minZ)
    p.Material = Enum.Material.WoodPlanks
    local cx, cz = (deckFP.minX + deckFP.maxX) / 2, (deckFP.minZ + deckFP.maxZ) / 2
    p.CFrame = mountCF * CFrame.new(cx, -0.25, cz)  -- top at y=0
    p.Parent = parent
end,
```
(Add `buildBeam(fromNode, toNode)` and `buildRailing(edge)` similarly — wood parts spanning the node coords / along the deck edges.)

- [ ] **Step 2: Wire `PadBuilder.buildDeck`** to call, in order: `deckFootprint(deckSize)` → `ops.buildDeckSlab(fp)` → for each `PadFrame.beams(fp)` `ops.buildBeam(...)` → railings → `PadPlanner.planSupport(fp, mountCF12, ops.raycastGround, ops.blockedByPath)` → `ops.buildPost` per post (existing path).

- [ ] **Step 3: Visual gate** — in Studio Play, temporarily register one site and call the new path (or once Phase 3 wires it, just Play). Confirm: symmetric slab centered on the mount, 5 beams under it forming the 2-long/3-short frame, railings on the edges, 6 posts dropping to terrain (embed/void/cantilever behaving as before). Eyeball on a flat pad and a sloped pad (e.g. T06).

- [ ] **Step 4: Commit** — `feat(roblox): PadBuilder builds procedural deck+beams+railings [trailers]`.

## Task 6: Strip the deck parts from the prefab (Studio re-capture, visual gate)

**Files:**
- Modify: `roblox/tools/studio/captureTeahouseBase.luau` (extend the strip list), then re-run it in Studio to re-author `ServerStorage.StructurePrefabs.teahouse-1story`.

- [ ] **Step 1: Extend the capture strip** — in `captureTeahouseBase.luau`, where it strips `EngawaPost`, also destroy the deck set: `EngawaF, EngawaS, EngawaSupport, Perim F/B/L/R, Joist, Girder, Koran, Newel, Baluster, RailCap, RailMid`. Keep `Tatami` (interior), walls, roof, shoji. Loosen the "nothing below datum" assert if the removed frame defined it — the new datum floor is the building's own floor plane; assert the remaining prefab's lowest part is the building floor (`Tatami`/wall base), not a veranda frame.

- [ ] **Step 2: Re-capture** — run `captureTeahouseBase.luau` in Studio against `workspace.TeahousePrototype` to regenerate the `teahouse-1story` prefab (building-only). Confirm `StructureOps.readManifest` still yields `roles/shojiBays/hasTatami/flagMounts` (the shoji/wall/roof tags are untouched).

- [ ] **Step 3: Visual gate** — materialize a teahouse; confirm the building renders with NO built-in deck/engawa (it now sits on the Phase-2 procedural deck). **Save the place** (prefab is place-only until the ServerStorage Rojo-mount follow-up).

- [ ] **Step 4: Commit** — `chore(roblox): strip deck/engawa from teahouse-1story prefab capture [trailers]` (the `.luau` tool change; note in the message that the prefab itself is place-only and re-captured by hand).

**Phase 2 gate:** deck renders procedurally & symmetric; building prefab is deck-less; posts unchanged. The stray-post + left-hand mirror bugs are gone because the deck no longer mirrors. Visual gate on T05/T06 (both left-hand) specifically.

---

# PHASE 3 — Wire placement + data plumbing

## Task 7: `openSide` replaces `mirror` (pure planner + ops)

**Files:**
- Modify: `roblox/src/shared/StructurePlanner.luau`, `roblox/src/server/StructureOps.luau`
- Test: `roblox/tests/StructurePlanner.spec.luau`

**Interfaces:**
- Consumes: `StructurePlanner.Mount` (drop `hand`; add nothing — openSide comes via loadout/placement), the shoji bay tags.
- Produces: `Plan.openSide: string?` (replaces `Plan.mirror`); the building's shoji L-wrap is selected on `front + openSide`. `StructureOps` applies shoji to the openSide walls instead of mirroring the whole model.

- [ ] **Step 1: Write the failing test** — in `StructurePlanner.spec.luau`, assert `plan.openSide == "right"` when the mount/placement carries `openSide="right"`, and that `plan.mirror` is gone. (Mirror math for the whole building is removed; only shoji-side selection remains.)

- [ ] **Step 2: Run** → FAIL.

- [ ] **Step 3: Implement** — replace `mirror = mount.hand == "left"` with `openSide = placement.openSide` threaded through `plan`. In `StructureOps`, replace the whole-model `mirrorX` call with shoji-wrap selection (build shoji on the front + openSide bays; leave the other two as solid walls). Remove the `MirrorX`/`MirrorXRigid` reliance for the building (those tags were mostly on the now-removed deck parts).

- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(roblox): openSide shoji-wrap replaces whole-building mirror [trailers]`.

## Task 8: `SiteCoordinator` carries `deckSize` + optional `teahouse` (pure)

**Files:**
- Modify: `roblox/src/shared/SiteCoordinator.luau`
- Test: `roblox/tests/SiteCoordinator.spec.luau`

**Interfaces:**
- Produces: `Action` gains `deckSize: string` and `teahouse: { size: string, loadout: any, placement: BuildingPlacer.Placement }?`. Existing `scale`/`footprint`/`sizeClass` stay for now (additive; removed in a later cleanup) so the runtime keeps working until Task 10.

- [ ] **Step 1: Write the failing test** — assert that `onJoin` for an owner of an M teahouse on a site whose default deck is L yields `action.deckSize == "L"`, `action.teahouse.size == "M"`, and `action.teahouse.placement` = the site default. Assert a **vacant** action yields `deckSize == "S"` and `teahouse = { size = "S", loadout = dormant, placement = <site default> }` — the darkened **S starter bundle** shown at every unoccupied pad (NOT the perch `maxSize`; NOT bare). Assert **onLeave** reverts to the same S starter.

- [ ] **Step 2: Run** → FAIL.

- [ ] **Step 3: Implement** — thread the site's default `deckSize` + default `placement` (from `spec`, see Task 9) and the owner's teahouse into the Action. Change `dormantOf` to emit **`deckSize = "S"`** with a **dormant S teahouse** (`VacantState` dormant loadout at size S) rather than `maxSize`. Keep `SizeClasses.fitsWithin(teahouse.size, deckSize)` as the claim guard for the owner's teahouse.

- [ ] **Step 4: Run** → PASS.
- [ ] **Step 5: Commit** — `feat(roblox): SiteCoordinator emits deckSize + optional teahouse [trailers]`.

## Task 9: `PadSites` default `{ deckSize, teahouse{size, placement} }`

**Files:**
- Modify: `roblox/src/server/PadSites.luau`

- [ ] **Step 1** — replace each site's `hand` field with `deckSize` (default = `maxSize`) and a default `placement = { offset, facing, openSide }` authored so the open front faces that pad's access. Convert the 3 left-hand sites (`T03, T05, T06`) to `openSide = "left"`, the rest `"right"`; author `facing`/`offset` per perch (start from `facing` toward the view + a corner-tuck `offset`; refine in the Task 12 visual gate).

- [ ] **Step 2** — no unit test (data). Verified by the Task 12 visual gate.
- [ ] **Step 3: Commit** — `feat(roblox): PadSites default deckSize + placement per perch [trailers]`.

## Task 10: `TreatmentApplier` composes pad + placed building

**Files:**
- Modify: `roblox/src/server/TreatmentApplier.luau`, `roblox/src/server/main.server.luau`

**Interfaces:**
- Consumes: `PadBuilder.buildDeck`, `StructureBuilder.build` (building-only), `BuildingPlacer.placeCF`/`fits`.
- Produces: `apply(padId, spec, treatment, deckSize, teahouse?)` — new signature. Composition: tear down site → `buildDeck(deckSize, mountCF)` → if `teahouse`: build building (at `teahouse.size` scale), `fits`-check (`warn`+skip on fail), place via `placeCF` composed with the deck world CFrame → shutter/lit.

- [ ] **Step 1: Write the failing test** — none pure (Roblox datatypes; visual-gated). Instead, update the 4 `applier:apply(...)` call sites in `main.server.luau` to pass `(padId, spec, treatment, action.deckSize, action.teahouse)`.

- [ ] **Step 2: Implement** — rewrite `apply` body: build the deck (always), then build+place the building only when `treatment.kind == "structure"` and `teahouse ~= nil`; scale the **building** by `SizeClasses.scale[teahouse.size]` (NOT the deck); fit-check non-fatal; keep the `shutter` + streaming-persistent behavior.

- [ ] **Step 3: Visual gate** — Play; every occupied perch shows a symmetric deck + a correctly placed building; vacant perches show a dormant building on a max-size deck.

- [ ] **Step 4: Commit** — `feat(roblox): TreatmentApplier composes deck + placed building [trailers]`.

## Task 11: Bare-deck support (teahouse = nil)

**Files:**
- Modify: `roblox/src/shared/VacantState.luau` (allow a treatment with no building), `roblox/src/server/TreatmentApplier.luau`

- [ ] **Step 1: Write the failing test** (VacantState) — a **deck-only** treatment (a player who owns a deck but no teahouse — a Piece-B ownership case) resolves to `kind="structure"` with `loadout=nil` (no building), and `TreatmentApplier` then builds only the deck. NOTE: this is a *capability*, not the vacant default — unoccupied pads still show the S starter bundle (Task 8), not a bare deck.

- [ ] **Step 2: Implement** — when `treatment.loadout == nil` (or `kind=="bare"`), `apply` builds the deck and skips the building. `dormant()`'s hard-coded `baseStyle` no longer forces a building on a bare deck.

- [ ] **Step 3: Run** (VacantState pure test) → PASS; **visual gate** a bare deck.
- [ ] **Step 4: Commit** — `feat(roblox): bare-deck pads (no teahouse) [trailers]`.

## Task 12: Full visual gate + cleanup

- [ ] **Step 1** — Play and eyeball the representative matrix: **bare L deck**, **S teahouse on L deck**, **all 4 facings**, **left vs right openSide**, on flat + sloped perches (T05/T06). Tune `PadSites` placements until the engawa + shoji + access read right. Confirm no stray posts.
- [ ] **Step 2** — remove now-dead code: legacy `BASE_FOOTPRINT`/`footprintFor` if nothing else uses them (grep first: `PadSiteFit`, `SiteCoordinator`); the `scale`/`footprint`/`sizeClass` Action fields once `apply` no longer reads them; `StructureOps.mirrorX` if unused.
- [ ] **Step 3: Run** `lune run tests/run` → all green.
- [ ] **Step 4: Commit** — `chore(roblox): remove pre-separation footprint/mirror dead code [trailers]`.

**Phase 3 gate:** decks hand-agnostic, buildings placed per authored defaults, bare decks work, all tests green, visual matrix approved. **Save the place** (prefab + any place-only geometry).

---

## Notes / open follow-ups (not blocking Piece A)

- The `teahouse-1story` prefab is **place-only** (re-captured by hand); committing it via a Rojo `ServerStorage` mount is a pre-existing open follow-up.
- **Piece B** consumes the `placement` seam: real deck/teahouse ownership (server data), a placement-override preference UI, and the access variable auto-deriving `facing`.
- The M/L **authored** building prefabs (vs the √area `ScaleTo` proxy) remain a later art task.
