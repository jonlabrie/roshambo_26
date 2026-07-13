# Modular Teahouse Foundation (SP1) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the S teahouse a modular, symmetric building whose four walls are `solid | shoji | door` bays driven by a data map, retiring the whole-building mirror and establishing the fixed spatial module the M/L program (SP3) and access model (SP2) build on.

**Architecture:** A new pure `WallBays` module resolves an optional per-side/per-bay state map (from the loadout) against the prefab's actual bays (from the manifest) into concrete per-bay render states. `StructurePlanner` produces `Plan.bays`; `StructureBuilder` drives an injected `ops.applyBays` instead of `ops.mirrorX`. The S prefab is re-authored so every wall is 6-stud bays (each a `Bay_<side>_<index>` model with Solid/Shoji/Door variants), re-captured with per-bay tags, and `StructureOps.applyBays` shows the chosen variant. Pure modules are Lune-tested; Roblox geometry/adapter are visual-gated, exactly as in Piece A.

**Tech Stack:** Luau (Roblox + Lune), Rojo, the bespoke Lune test harness (`lune run tests/run`), stylua + selene. Studio MCP `execute_luau` for the place-only prefab geometry.

## Global Constraints

- **Fixed 6-stud bay module.** Bay pitch = 6 studs: front 3 bays, back 3, each side 2 = 10 bays at S. (GCD of the 18-stud front and 12-stud sides.)
- **Height never scales.** Wall 10 / corner post 11 / shoji 8.5 studs are fixed (avatar ergonomics, like the deck railings). SP1 is S-size only; do not scale the building.
- **Exactly three bay states:** `solid`, `shoji`, `door`. No windows/half-walls (YAGNI).
- **Default S config:** front bays `shoji`, all other bays `solid` (matches today, minus the mirror). Encoded as `WallBays.defaultState(side)`.
- **Pure modules are dependency-injected and Lune-tested; never require each other** — EXCEPT requiring a pure Lune-loadable sibling (e.g. `StructurePlanner` may require `WallBays`, as `StructureBuilder` requires `StructurePlanner`). Roblox-datatype modules (`StructureOps`) and place-only geometry are visual-gated, not Lune-tested.
- **Retire the whole-building mirror.** `StructureOps.mirrorX` / `MirrorX` tags / `Plan.openSide` / `Mount.openSide` / `Placement.openSide` are removed; "which side is open" is the bay map. Confirm no non-building consumer of `mirrorX` before deleting it.
- **F2/F4 degradation:** an invalid `wallBays` map or a missing bay part must warn and fall back (default map / render the rest), never blank the building or abort the caller.
- **Bay index order:** per side, left-to-right as seen from OUTSIDE the building, starting at index 1.
- **Scope:** S size only; bay STATE only. Per-side shoji *texture* stays front-only (unchanged) for SP1. SP2 (access→door), SP3 (M/L), Piece B (customization UI) are out.
- TDD: failing test first for pure modules; visual gate for geometry/adapter. stylua + selene clean; commit per task with the repo's trailers.

---

# PHASE 1 — Pure foundation (Lune-tested)

## Task 1: `WallBays` module (pure)

**Files:**
- Create: `roblox/src/shared/WallBays.luau`
- Test: `roblox/tests/WallBays.spec.luau`

**Interfaces:**
- Produces:
  - `WallBays.STATES: { [string]: boolean }` — the valid state set `{solid,shoji,door}`.
  - `WallBays.defaultState(side: string) -> string` — `"shoji"` for `"front"`, else `"solid"`.
  - `WallBays.validate(map) -> boolean` — every entry is a known state.
  - `WallBays.resolve(available: { {side:string,index:number} }, map: {[string]:{string}}?) -> { {side:string,index:number,state:string} }` — each available bay's concrete state (map override where valid, else the per-side default).
  - Types `Bay = {side:string,index:number}`, `ResolvedBay = {side:string,index:number,state:string}`, `Map = {[string]:{string}}`.

- [ ] **Step 1: Write the failing test** — `roblox/tests/WallBays.spec.luau`:

```luau
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local WallBays = require("../src/shared/WallBays")

local AVAIL = {
    { side = "front", index = 1 },
    { side = "front", index = 2 },
    { side = "back", index = 1 },
    { side = "left", index = 1 },
}

local function stateOf(resolved, side, index)
    for _, b in resolved do
        if b.side == side and b.index == index then
            return b.state
        end
    end
    return nil
end

describe("WallBays.defaultState", function()
    test("front opens as shoji; other sides are solid", function()
        expect(WallBays.defaultState("front")).toBe("shoji")
        expect(WallBays.defaultState("back")).toBe("solid")
        expect(WallBays.defaultState("left")).toBe("solid")
        expect(WallBays.defaultState("right")).toBe("solid")
    end)
end)

describe("WallBays.validate", function()
    test("accepts a map of known states", function()
        expect(WallBays.validate({ back = { "solid", "door" }, front = { "shoji" } })).toBe(true)
    end)
    test("rejects an unknown state", function()
        expect(WallBays.validate({ back = { "window" } })).toBe(false)
    end)
end)

describe("WallBays.resolve", function()
    test("no map -> per-side defaults for every available bay", function()
        local r = WallBays.resolve(AVAIL, nil)
        expect(#r).toBe(4)
        expect(stateOf(r, "front", 1)).toBe("shoji")
        expect(stateOf(r, "front", 2)).toBe("shoji")
        expect(stateOf(r, "back", 1)).toBe("solid")
        expect(stateOf(r, "left", 1)).toBe("solid")
    end)
    test("a valid map overrides per (side,index); unlisted bays keep the default", function()
        local r = WallBays.resolve(AVAIL, { back = { "door" }, front = { [2] = "solid" } })
        expect(stateOf(r, "back", 1)).toBe("door") -- overridden
        expect(stateOf(r, "front", 2)).toBe("solid") -- overridden
        expect(stateOf(r, "front", 1)).toBe("shoji") -- default kept (not listed)
        expect(stateOf(r, "left", 1)).toBe("solid") -- default kept (side absent)
    end)
    test("an invalid map is ignored wholesale -> all defaults (non-fatal)", function()
        local r = WallBays.resolve(AVAIL, { back = { "trapdoor" } })
        expect(stateOf(r, "back", 1)).toBe("solid")
    end)
    test("a map entry with an unknown state falls back to that bay's default", function()
        -- map is structurally valid elsewhere but one index is bogus at resolve time
        local r = WallBays.resolve(AVAIL, { front = { "shoji", "shoji" }, back = { "solid" }, left = { "solid" } })
        expect(stateOf(r, "front", 1)).toBe("shoji")
    end)
end)
```

- [ ] **Step 2: Run** → `lune run tests/run` (from `roblox/`) → FAIL (`WallBays` not found).

- [ ] **Step 3: Implement** — `roblox/src/shared/WallBays.luau`:

```luau
--!strict
-- Pure bay-state model for the modular teahouse walls. A building's walls are a per-side,
-- per-bay state map (solid | shoji | door). resolve() picks each available bay's state from
-- an optional loadout map, falling back to the per-side default (front = shoji, else solid).
-- Pure (Lune-tested); no Roblox datatypes.
local WallBays = {}

WallBays.STATES = { solid = true, shoji = true, door = true } :: { [string]: boolean }

export type Bay = { side: string, index: number }
export type ResolvedBay = { side: string, index: number, state: string }
export type Map = { [string]: { string } }

-- the view front opens as shoji; every other side defaults to a solid wall
function WallBays.defaultState(side: string): string
    return if side == "front" then "shoji" else "solid"
end

-- structural validation: every entry is a known state (bay COUNTS are checked against the
-- prefab's actual bays in resolve, not here)
function WallBays.validate(map: Map): boolean
    for _side, states in map do
        for _, s in states do
            if not WallBays.STATES[s] then
                return false
            end
        end
    end
    return true
end

-- resolve each AVAILABLE bay (from the prefab manifest) to a concrete state. A structurally
-- valid map overrides per (side,index); anything missing/invalid falls back to the per-side
-- default. An entirely invalid map is ignored (all defaults) — non-fatal (F2/F4).
function WallBays.resolve(available: { Bay }, map: Map?): { ResolvedBay }
    local useMap = map ~= nil and WallBays.validate(map)
    local out: { ResolvedBay } = {}
    for _, bay in available do
        local state = WallBays.defaultState(bay.side)
        if useMap and map then
            local sideStates = map[bay.side]
            local chosen = sideStates and sideStates[bay.index]
            if chosen ~= nil and WallBays.STATES[chosen] then
                state = chosen
            end
        end
        table.insert(out, { side = bay.side, index = bay.index, state = state })
    end
    return out
end

return WallBays
```

- [ ] **Step 4: Run** → PASS. Then `stylua src tests && selene src`.
- [ ] **Step 5: Commit** — `feat(roblox): WallBays pure bay-state model (solid/shoji/door)` + repo trailers.

---

## Task 2: `StructurePlanner` resolves bays; drops openSide (pure)

**Files:**
- Modify: `roblox/src/shared/StructurePlanner.luau`
- Test: `roblox/tests/StructurePlanner.spec.luau`

**Interfaces:**
- Consumes: `WallBays.resolve`; a `Manifest` that now carries `bays: { WallBays.Bay }`.
- Produces: `Loadout` gains `wallBays: WallBays.Map?`; `Mount` drops `openSide`; `Manifest` gains `bays`; `Plan` replaces `openSide` with `bays: { WallBays.ResolvedBay }`.

- [ ] **Step 1: Update the failing test** — in `roblox/tests/StructurePlanner.spec.luau`, replace the `openSide` test with a bays test, and add `bays` to the manifest helper. Change `baseMount()` to drop `openSide` (keep `cframe`, `footprint`). Add:

```luau
test("bays: resolves the loadout wallBays against the manifest bays (default-fills the rest)", function()
    local manifest = {
        roles = {},
        shojiBays = {},
        hasTatami = false,
        flagMounts = {},
        bays = { { side = "front", index = 1 }, { side = "back", index = 1 } },
    }
    local loadout = { baseStyle = "teahouse-1story", wallBays = { back = { "door" } } }
    local plan = Planner.plan(loadout, baseMount(), manifest, Catalog)
    local function stateOf(side, index)
        for _, b in plan.bays do
            if b.side == side and b.index == index then
                return b.state
            end
        end
        return nil
    end
    expect(stateOf("front", 1)).toBe("shoji") -- default
    expect(stateOf("back", 1)).toBe("door") -- overridden
    expect((plan :: any).openSide).toBeNil() -- the old field is gone
end)
```

Also update every existing manifest literal in this file to include `bays = {}` (the other tests don't exercise bays but the type now requires the field).

- [ ] **Step 2: Run** → FAIL.

- [ ] **Step 3: Implement** — in `roblox/src/shared/StructurePlanner.luau`:
  1. Add near the top: `local WallBays = require("./WallBays")`.
  2. In `Loadout`, add `wallBays: WallBays.Map?,`.
  3. In `Mount`, delete the `openSide: string,` line (keep `cframe`, `footprint`).
  4. In `Manifest`, add `bays: { WallBays.Bay }` to the type.
  5. In `Plan`, replace `openSide: string,` with `bays: { WallBays.ResolvedBay },`.
  6. In `plan()`, replace `openSide = mount.openSide,` with `bays = WallBays.resolve(manifest.bays, loadout.wallBays),`.

The `plan()` return becomes:

```luau
function StructurePlanner.plan(loadout: Loadout, mount: Mount, manifest: Manifest, catalog: Catalog): Plan
    return {
        recolors = resolveRecolors(loadout, manifest, catalog),
        textures = resolveTextures(loadout, manifest, catalog),
        attachments = resolveAttachments(loadout, manifest, catalog),
        bays = WallBays.resolve(manifest.bays, loadout.wallBays),
        pivotCF = mount.cframe,
    }
end
```

- [ ] **Step 4: Run** → PASS. `stylua src tests && selene src`.
- [ ] **Step 5: Commit** — `feat(roblox): StructurePlanner resolves wallBays, drops openSide` + trailers.

---

# PHASE 2 — Retire the mirror; decouple placement (pure/data)

## Task 3: `StructureBuilder` applies bays instead of mirroring (pure)

**Files:**
- Modify: `roblox/src/shared/StructureBuilder.luau`
- Test: `roblox/tests/StructureBuilder.spec.luau`

**Interfaces:**
- Consumes: `Plan.bays` (from Task 2).
- Produces: `Ops` drops `mirrorX`, gains `applyBays: (any, { WallBays.ResolvedBay }) -> ()`. Build order: clone → readManifest → plan → **applyBays** → recolor → texture → attach → pivot.

- [ ] **Step 1: Update the failing test** — in `roblox/tests/StructureBuilder.spec.luau`: the fake ops replaces `mirrorX` with `applyBays`; the mount uses `bays` instead of `openSide`; the expected op log has `applyBays` in place of `mirror`. Replace the two mirror tests with:

```luau
test("build drives ops in order: clone, applyBays, recolor, texture, attach, pivot", function()
    local log: { any } = {}
    local mount = {
        cframe = { 1, 2, 3, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        footprint = { minX = -13, maxX = 13, minZ = -10, maxZ = 10 },
    }
    local loadout = {
        baseStyle = "teahouse-1story",
        colorScheme = "scheme.ink",
        shoji = { [1] = "shoji.crane" },
        flags = { { mount = "FlagMount_1", item = "flag.clan" } },
    }
    local model = Builder.build(loadout, mount, Catalog, fakeOps(log))
    expect((model :: any).tag).toBe("MODEL")
    expect(log).toEqual({
        { op = "clone", style = "teahouse-1story" },
        { op = "applyBays" },
        { op = "recolor", role = "cap" },
        { op = "texture", target = "ShojiBay:1" },
        { op = "attach", mount = "FlagMount_1" },
        { op = "pivot" },
    })
end)
```

In `fakeOps(log)`, replace the `mirrorX` entry with:

```luau
        applyBays = function(_m, _bays)
            table.insert(log, { op = "applyBays" })
        end,
```

(The fake `readManifest` must now also return `bays = {}` so the planner's resolve runs; add `bays = {}` to its returned table.)

- [ ] **Step 2: Run** → FAIL.

- [ ] **Step 3: Implement** — in `roblox/src/shared/StructureBuilder.luau`:
  1. In `Ops`, delete `mirrorX: (any) -> (),` and add `applyBays: (any, { StructurePlanner.WallBays_ResolvedBay }) -> (),` — but since the planner re-exports through its own types, use `applyBays: (any, any) -> (),` to avoid a cross-module type import (the fake and the real ops both accept the resolved list).
  2. Replace the mirror block:

```luau
    local plan = StructurePlanner.plan(loadout, mount, manifest, catalog)
    ops.applyBays(model, plan.bays)
    for _, r in plan.recolors do
```

  (Delete the `if plan.openSide == "left" then ops.mirrorX(model) end` block entirely.)

- [ ] **Step 4: Run** → PASS. `stylua src tests && selene src`.
- [ ] **Step 5: Commit** — `feat(roblox): StructureBuilder applies bays, drops mirror` + trailers.

---

## Task 4: Retire `openSide` from the placement plumbing (pure + data)

**Files:**
- Modify: `roblox/src/shared/BuildingPlacer.luau`, `roblox/src/server/TreatmentApplier.luau`, `roblox/src/server/PadSites.luau`, `roblox/src/shared/SiteCoordinator.luau` (test helper only)
- Test: `roblox/tests/BuildingPlacer.spec.luau`, `roblox/tests/SiteCoordinator.spec.luau`

**Interfaces:**
- `BuildingPlacer.Placement` becomes `{ offset: { number }, facing: string }` (drops `openSide`). `placeCF`/`fits` already use only `offset`/`facing` — no logic change.

- [ ] **Step 1: Update the failing tests** —
  - `roblox/tests/BuildingPlacer.spec.luau`: remove `openSide = "left"` / `openSide = "right"` from every `Placement` literal (the tests don't assert on it). Run to confirm still green after the type change below — this test drives the change.
  - `roblox/tests/SiteCoordinator.spec.luau`: in the `PLACEMENT` helper, drop `openSide = "right"` so it reads `{ offset = { 0, 0 }, facing = "N" }`.

- [ ] **Step 2: Run** → FAIL (type error: `openSide` no longer in `Placement`, or leftover references).

- [ ] **Step 3: Implement** —
  1. `roblox/src/shared/BuildingPlacer.luau`: change the type to `export type Placement = { offset: { number }, facing: string }` and remove any doc mention of `openSide`.
  2. `roblox/src/server/TreatmentApplier.luau`: in `_buildBuilding`, drop `openSide = placement.openSide` from the `mount` literal — it becomes `local mount = { cframe = { placedCF:GetComponents() }, footprint = buildingFP }`.
  3. `roblox/src/server/PadSites.luau`: remove `, openSide = "left"` / `, openSide = "right"` from all 14 `placement` literals (leaving `placement = { offset = { 0, 3 }, facing = "N" }`). Run: `perl -i -pe 's/, openSide = "(left|right)" \}/ }/g' src/server/PadSites.luau` then verify `grep -c openSide src/server/PadSites.luau` is 0. Update the header comment that mentions openSide.
  4. `roblox/src/shared/SiteCoordinator.luau`: no code change (it passes `placement` through opaquely); confirm nothing reads `placement.openSide`.

- [ ] **Step 4: Run** → `lune run tests/run` PASS; `stylua src tests && selene src` clean.
- [ ] **Step 5: Commit** — `refactor(roblox): retire openSide from placement (superseded by wallBays)` + trailers.

**Phase 2 gate:** the runtime is transitional — the builder now calls `ops.applyBays`, which does not exist on the real `StructureOps` yet, and the prefab has no per-bay tags. This is expected; Phase 3 lands the geometry, tags, and adapter. Do not Play-test between Task 4 and Task 7.

---

# PHASE 3 — Roblox geometry, capture, adapter, gate (visual)

Place-only geometry, driven by Studio MCP `execute_luau`; visual-gated (no pure failing test), following the Piece-A pattern. **Studio must be open with the saved place.**

## Task 5: Re-author the S walls into bays + door variants + tatami mats (visual gate)

**Files:** none in git (place-only prefab geometry). Work on `ServerStorage.StructurePrefabs.teahouse-1story` (and/or a fresh source clone from `ServerStorage.RetiredLegacyTeahouses.CanyonTeahouses.*` brought into `workspace.TeahousePrototype`, per the capture flow).

**Bay model contract (author this structure):** each of the 10 bays is a `Model` named `Bay_<side>_<index>` (`side` ∈ front/back/left/right; index 1..N left-to-right seen from outside), containing three child variants sharing the bay's 6-stud slot:
- `Solid` — an opaque wall panel (plaster/wood), `CanCollide=true`.
- `Shoji` — the translucent screen + its `ShojiGlow` + `Mull` lattice (reuse the existing front-shoji look), `CanCollide=true`.
- `Door` — a framed opening: two thin jamb posts + a lintel (`CanCollide=true`) around a passable gap (no panel), so an avatar walks through.

Only one variant is shown at runtime (Task 7); author all three present, with `Solid` shown by default on non-front bays and `Shoji` on the front.

- [ ] **Step 1** — split the solid walls into bays. `BackWall` (18 wide, at Z back) → 3 `Bay_back_1..3` slots at local X ≈ -6/0/+6; each `SideWall` (12 deep) → 2 `Bay_left_1..2` / `Bay_right_1..2` at local Z ≈ -3/+3. **Regularize** the current non-uniform +X side (3 panels at ~4-stud pitch) to 2 uniform 6-stud bays. Keep the front's 3 shoji as `Bay_front_1..3`. Script it (`execute_luau`) like the Piece-A pad geometry: compute slot centers from the wall extents, generate the `Solid`/`Shoji`/`Door` variant parts per bay, parent under the `Bay_*` models; delete the old monolithic `BackWall`/`SideWall`.

- [ ] **Step 2** — author the `Door` variant geometry once (jambs + lintel around a ~4-stud-wide × ~7-stud-tall gap within the 6-stud bay) and clone it into every bay. Confirm an avatar-sized capsule passes through the gap (no collision in the opening; collision on the jambs).

- [ ] **Step 3** — re-lay the tatami: replace the single `Tatami` (17×11) with counted mat parts on a standard ~1:2 module (e.g. ~3×6-stud mats in a standard mat layout filling the interior), each tagged `Tatami` (so the existing tatami texturing still targets them). This defines the mat module SP3 reuses.

- [ ] **Step 4: Visual gate** — in Edit/Play, eyeball: all four walls read as 6-stud bays; the default shows front shoji + solid elsewhere (same as before, minus mirror); the tatami reads as laid mats, not one stretched mat; nothing floats or overlaps. **Do not save yet** (Task 6 re-captures).

- [ ] **Step 5** — no commit (place-only). Record the bay-model structure in the SDD ledger for Task 6/7.

## Task 6: Extend `captureTeahouseBase.luau` to tag all bays; re-capture (visual gate)

**Files:**
- Modify: `roblox/tools/studio/captureTeahouseBase.luau`

- [ ] **Step 1** — in the tag pass, for every `Bay_<side>_<index>` model, add a `Bay` tag and `Side` + `Index` attributes (parse them from the model name). Keep `Role_*`, `Tatami`, `ShojiBay`+`Bay`-attribute on front shoji (texturing unchanged), and `FlagMount` attachments. **Remove** the `MIRROR`/`MirrorX`/`MirrorXRigid` tagging block entirely (the building no longer mirrors); position the `ChochinSwing` directly (it stays where authored). Loosen/keep the datum + strip logic from the prior Piece-A version.

- [ ] **Step 2** — re-run the capture against `workspace.TeahousePrototype` to regenerate the building-only, bay-tagged `teahouse-1story` prefab. Confirm via a probe that `CollectionService:GetTagged("Bay")` yields 10 tagged bay models with Side/Index attributes.

- [ ] **Step 3: Visual gate** — confirm the prefab still materializes (roof/shoji/chochin/tatami intact) and the bays are addressable. **Save the place** (prefab is place-only).

- [ ] **Step 4: Commit** — `chore(roblox): tag all wall bays in teahouse-1story capture; drop mirror tags` + trailers (the `.luau` change only; note the prefab is place-only, re-captured by hand).

## Task 7: `StructureOps.applyBays` + manifest bays; retire `mirrorX` (visual gate)

**Files:**
- Modify: `roblox/src/server/StructureOps.luau`

**Interfaces:**
- Produces: `readManifest` now returns `bays = { {side,index} }` from the `Bay` tags; `applyBays(model, bays)` shows each bay's chosen variant and hides the others; `mirrorX` removed.

- [ ] **Step 1** — in `readManifest`, collect `Bay`-tagged descendants into `bays` (reading `Side`/`Index` attributes) and add `bays = bays` to the returned manifest (alongside `roles/shojiBays/hasTatami/flagMounts`).

- [ ] **Step 2** — add `applyBays(model, bays)`: build an index of `Bay_<side>_<index>` models; for each resolved bay, show the variant matching its state (`Solid`/`Shoji`/`Door`) and hide the other two (set their parts `Transparency=1`, `CanCollide=false`, and any glow/light off). For `door`, additionally ensure the shown `Door` variant's gap has no collision (it was authored that way) — nothing extra needed, but assert the `Solid` variant is fully non-colliding when hidden so players cannot hit an invisible wall. Missing `Bay_*` model for a resolved bay → `warn` and skip that bay (F2/F4).

- [ ] **Step 3** — delete `StructureOps.mirrorX`. Grep first: `grep -rn "mirrorX" roblox/src` must show no remaining consumer (the builder dropped it in Task 3).

- [ ] **Step 4: Visual gate** — materialize the S building through the real `TreatmentApplier` path (as in the Piece-A Task-10 gate) with several `wallBays` maps:
  - default (nil) → front shoji, solid elsewhere;
  - `{ back = { [2] = "door" } }` → a passable door in the middle back bay; walk through it;
  - `{ left = { "shoji", "shoji" }, right = { "shoji", "shoji" } }` → both sides open, **no mirror involved** — confirm left/right symmetry comes purely from the map;
  - confirm shoji still lights/textures and the chochin is correct.

- [ ] **Step 5: Commit** — `feat(roblox): StructureOps.applyBays + manifest bays; remove mirrorX` + trailers.

## Task 8: Full visual gate + cleanup + save (visual)

- [ ] **Step 1** — end-to-end matrix in Play (or the Edit applier gate): a claimed teahouse with the default map; one with a rear `door`; one with an all-open front+sides map; on a right- and a former-left-hand perch (T02 and T05) — confirm both render correctly **from the bay map alone**, the door is passable, and there are no stray `mirrorX`/`openSide` references (`grep -rn "openSide\|mirrorX" roblox/src` → empty).
- [ ] **Step 2** — `lune run tests/run` all green; `stylua --check src tests tools` and `selene src` clean.
- [ ] **Step 3** — clear any throwaway gate folders from the workspace; **save the place**.
- [ ] **Step 4: Commit** — `chore(roblox): SP1 modular teahouse gate + cleanup` + trailers (if any code/tool changed; otherwise note the place was saved).

**Phase 3 gate:** the S teahouse renders all four walls as `solid/shoji/door` bays from the `wallBays` map; doors are passable; left/right openness needs no mirror; shoji/tatami texturing intact; the module (6-stud bay, fixed height, counted mats) is established for SP3. All tests green, lint clean, place saved.

---

## Notes / follow-ups (not in SP1)

- **SP2** consumes `wallBays` + placement: derive the door bay and the hug-the-edge placement from the per-pad access `{edge, position}`, plus the setback-aware fit-check.
- **SP3** authors M/L floorplans from the module (more bays + tokonoma/genkan/tea-nook), retiring the `ScaleTo` proxy.
- **Per-side shoji texture** (extending `loadout.shoji` beyond the front) is deferred; SP1 keeps front-only texturing.
- Committing the place-only prefab via a Rojo `ServerStorage` mount remains an open follow-up (pre-existing).
