# Teahouse Size Tiers Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the single scaled teahouse with three authored per-size prefabs (S 2×1, M 3×2, L 4×3), shell-only (engawa/koran come from the deck), selected by size instead of scaled.

**Architecture:** Add a pure `SizeClasses.prefabName(baseStyle, size)` resolver and a per-size `SizeClasses.buildingFootprint(size)`; `StructureBuilder.build` clones a passed prefab name; `TreatmentApplier` resolves the per-size prefab, drops `ScaleTo`, and fit-checks against the per-size footprint. Two new prefabs (S, L) and a stripped-down M are hand-authored in Studio.

**Tech Stack:** Luau/Rojo/Lune (Roblox); interactive Studio geometry authoring (via MCP + user visual gate).

## Global Constraints

- **Commit footer (verbatim on every commit):**
  ```
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ
  ```
- **Sizes** (bay counts, `long walls × short walls`, front/back = long): S = 2×1 (6 bays), M = 3×2 (10 bays, the current prefab), L = 4×3 (14 bays). Bay ≈ 6.2 studs.
- **Prefabs** live under `ServerStorage.StructurePrefabs` named **`teahouse-1story-s` / `-m` / `-l`**. `baseStyle` stays the *style* string `"teahouse-1story"`; the **size** picks the prefab.
- **`prefabName(baseStyle, size)` = `` `{baseStyle}-{size:lower()}` `` ** (e.g. `("teahouse-1story","M") → "teahouse-1story-m"`).
- **Teahouse = shell only:** bays/walls, hip roof, interior tatami, shoji track (kamoi/shikii/groove-rails/wall-posts). **No engawa veranda floor, no koran railing** — the deck (`PadOps` slab + railing) provides both. Strip `Skirt`/`SkirtEnd`/`Koran`/`WEndRail`/`EngawaSupport` from M.
- **Building scale retired:** remove `model:ScaleTo(...)`; `SizeClasses.scale` stays only for `deckFootprint`.
- **Dormant/vacant pads show the new S** (2×1) darkened; no logic change (STARTER stays `"S"`).
- **Prefabs are place-state** — persist only when the user saves the place; interactive authoring uses one-attempt-then-STOP-and-ask (the stop-and-ask working rule).

## Execution modes

- **Tasks 1–4 (code):** subagent-driven, TDD/Lune (Task 4 is runtime glue proven by lint + the final gate).
- **Tasks 5–7 (authoring):** **main session, interactive Studio** with the user — NOT subagents. Geometry + measurement + a per-size visual gate.
- **Task 8:** the final combined visual gate + orphan cleanup (main session).

Order rationale: land the code first (Tasks 1–4 clone `teahouse-1story-{s,m,l}` and drop scale — unit-tested with fakes, no dependency on the prefabs existing), then author the three prefabs (Tasks 5–7), then integrate at the gate (Task 8). Between Task 5 and Task 8 the runtime is transitionally broken (the old `teahouse-1story` name is no longer cloned) — that's fine; we don't Play until Task 8.

---

## File Structure

- **Modify** `roblox/src/shared/SizeClasses.luau` — add `prefabName`, `buildingFootprint`.
- **Modify** `roblox/tests/SizeClasses.spec.luau` — tests for both.
- **Modify** `roblox/src/shared/StructureBuilder.luau` — `build` takes a `prefabName` arg.
- **Modify** `roblox/tests/StructureBuilder.spec.luau` — pass + assert `prefabName`.
- **Modify** `roblox/src/server/TreatmentApplier.luau` — resolve per-size prefab, drop `ScaleTo`, per-size fit-check.
- **Studio place-state** (no git): `ServerStorage.StructurePrefabs.teahouse-1story-{s,m,l}` authored; old `teahouse-1story` removed.

---

### Task 1: `SizeClasses.prefabName`

**Files:**
- Modify: `roblox/src/shared/SizeClasses.luau` (add before `return SizeClasses`)
- Test: `roblox/tests/SizeClasses.spec.luau`

**Interfaces:**
- Produces: `SizeClasses.prefabName(baseStyle: string, size: string): string` → `` `{baseStyle}-{size:lower()}` ``.

- [ ] **Step 1: Write the failing test**

Append to `roblox/tests/SizeClasses.spec.luau`:

```lua
describe("SizeClasses.prefabName", function()
    test("joins style + lowercased size", function()
        expect(SizeClasses.prefabName("teahouse-1story", "S")).toBe("teahouse-1story-s")
        expect(SizeClasses.prefabName("teahouse-1story", "M")).toBe("teahouse-1story-m")
        expect(SizeClasses.prefabName("teahouse-1story", "L")).toBe("teahouse-1story-l")
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `SizeClasses.prefabName` is nil.

- [ ] **Step 3: Implement**

In `roblox/src/shared/SizeClasses.luau`, before `return SizeClasses`:

```lua
-- the per-size prefab name for a style: "teahouse-1story" + "M" -> "teahouse-1story-m".
-- baseStyle stays the STYLE; size picks the authored prefab (scaling retired).
function SizeClasses.prefabName(baseStyle: string, size: string): string
    return `{baseStyle}-{string.lower(size)}`
end
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Lint**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/SizeClasses.luau roblox/tests/SizeClasses.spec.luau
git commit -m "feat(roblox): SizeClasses.prefabName (per-size prefab resolver)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ"
```

---

### Task 2: `SizeClasses.buildingFootprint`

**Files:**
- Modify: `roblox/src/shared/SizeClasses.luau` (add before `return SizeClasses`)
- Test: `roblox/tests/SizeClasses.spec.luau`

**Interfaces:**
- Consumes: the `Footprint` type already exported by `SizeClasses`.
- Produces: `SizeClasses.buildingFootprint(size: string): Footprint` — the per-size WALL footprint (symmetric, centred). Values derive from M's known footprint (the current `BUILDING_BASE`, walls 18.7×12.7 → `±9.35 × ±6.35`) scaled by bay ratio: S = 2/3 wide × 1/2 deep; L = 4/3 wide × 3/2 deep. (Refine from the authored prefab measurements in Tasks 5–7 if they differ materially — this footprint is a non-fatal fit-check safety net, `teahouse ≤ deck` is already guaranteed upstream.)

- [ ] **Step 1: Write the failing test**

Append to `roblox/tests/SizeClasses.spec.luau`:

```lua
describe("SizeClasses.buildingFootprint", function()
    local function wh(fp)
        return math.floor((fp.maxX - fp.minX) * 100) / 100, math.floor((fp.maxZ - fp.minZ) * 100) / 100
    end
    test("M is the reference ~18.7 x 12.7", function()
        local w, d = wh(SizeClasses.buildingFootprint("M"))
        expect(w).toBe(18.7)
        expect(d).toBe(12.7)
    end)
    test("S is smaller, L is larger (monotonic in both dims)", function()
        local sw, sd = wh(SizeClasses.buildingFootprint("S"))
        local mw, md = wh(SizeClasses.buildingFootprint("M"))
        local lw, ld = wh(SizeClasses.buildingFootprint("L"))
        expect(sw < mw and sd < md).toBe(true)
        expect(lw > mw and ld > md).toBe(true)
    end)
    test("footprints are symmetric about the origin", function()
        local fp = SizeClasses.buildingFootprint("L")
        expect(fp.minX).toBe(-fp.maxX)
        expect(fp.minZ).toBe(-fp.maxZ)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `buildingFootprint` is nil.

- [ ] **Step 3: Implement**

In `roblox/src/shared/SizeClasses.luau`, before `return SizeClasses`:

```lua
-- per-size WALL footprint (symmetric, centred). Retires the scaled BUILDING_BASE: sizes are now
-- distinct authored buildings. M is the reference (18.7 x 12.7); S/L scale by bay ratio
-- (S 2x1, M 3x2, L 4x3). Used for the non-fatal deck fit-check; refine from authored measurements.
local BUILDING_HALF = { S = { 6.25, 3.18 }, M = { 9.35, 6.35 }, L = { 12.45, 9.53 } } :: { [string]: { number } }
function SizeClasses.buildingFootprint(size: string): Footprint
    local h = BUILDING_HALF[size]
    return { minX = -h[1], maxX = h[1], minZ = -h[2], maxZ = h[2] }
end
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Lint**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/SizeClasses.luau roblox/tests/SizeClasses.spec.luau
git commit -m "feat(roblox): SizeClasses.buildingFootprint per-size wall footprint

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ"
```

---

### Task 3: `StructureBuilder.build` takes a `prefabName`

**Files:**
- Modify: `roblox/src/shared/StructureBuilder.luau:20-26`
- Test: `roblox/tests/StructureBuilder.spec.luau`

**Interfaces:**
- Produces: `StructureBuilder.build(loadout, mount, catalog, ops, prefabName: string)` — clones `ops.clonePrefab(prefabName)` instead of `loadout.baseStyle`; everything else unchanged.

- [ ] **Step 1: Update the failing test**

In `roblox/tests/StructureBuilder.spec.luau`, change the `build` call to pass a prefab name and assert the clone uses it. Replace the call + the first log entry:

```lua
    local model = Builder.build(loadout, mount, Catalog, fakeOps(log), "teahouse-1story-m")
    expect((model :: any).tag).toBe("MODEL")
    expect(log).toEqual({
        { op = "clone", style = "teahouse-1story-m" },
        { op = "applyBays" },
        { op = "recolor", role = "cap" },
        { op = "texture", target = "ShojiBay:1" },
        { op = "attach", mount = "FlagMount_1" },
        { op = "pivot" },
    })
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `build` ignores the new arg and clones `loadout.baseStyle` (`"teahouse-1story"`), so the logged style is `"teahouse-1story"`, not `"teahouse-1story-m"`.

- [ ] **Step 3: Implement**

In `roblox/src/shared/StructureBuilder.luau`, change the signature + the clone line:

```lua
function StructureBuilder.build(
    loadout: StructurePlanner.Loadout,
    mount: StructurePlanner.Mount,
    catalog: any,
    ops: Ops,
    prefabName: string
): any
    local model = ops.clonePrefab(prefabName)
```
(the rest of the function body is unchanged).

- [ ] **Step 4: Run to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Lint**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/StructureBuilder.luau roblox/tests/StructureBuilder.spec.luau
git commit -m "feat(roblox): StructureBuilder.build clones a passed prefabName (per-size prefabs)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ"
```

---

### Task 4: `TreatmentApplier` — per-size prefab, no scale, per-size fit-check

**Files:**
- Modify: `roblox/src/server/TreatmentApplier.luau` (`BUILDING_BASE` const + `_buildBuilding`)

Roblox-runtime glue (no Lune unit test — matches the file's existing runtime nature). Verification: `stylua`/`selene` clean + the full Lune suite still green (Tasks 1–3 cover the seams) + the Task 8 gate.

**Interfaces:**
- Consumes: `SizeClasses.prefabName` (Task 1), `SizeClasses.buildingFootprint` (Task 2), `StructureBuilder.build(..., prefabName)` (Task 3). `self._sizeClasses` is the injected `SizeClasses`; `teahouse.loadout.baseStyle` is the style; `teahouse.size` is `S`/`M`/`L`.

- [ ] **Step 1: Remove the scaled BUILDING_BASE constant**

Delete the `BUILDING_BASE` local (the `{ minX = -9.35, ... }` constant near the top of `TreatmentApplier.luau`) and its explanatory comment — it's replaced by `SizeClasses.buildingFootprint`.

- [ ] **Step 2: Rewrite the fit-check, prefab selection, and drop ScaleTo**

In `_buildBuilding`, replace the block that builds `buildingFP` from `BUILDING_BASE * s`, calls `structureBuilder.build`, and conditionally `ScaleTo`s, with:

```lua
    local placement = teahouse.placement
    local deckFP = self._sizeClasses.deckFootprint(deckSize)
    local buildingFP = self._sizeClasses.buildingFootprint(teahouse.size)
    if not self._buildingPlacer.fits(buildingFP, deckFP, placement) then
        warn(
            `[D.6] {padId}: {teahouse.size} building does not fit the {deckSize} deck at its placement; deck only`
        )
        return
    end
    -- world pivot = deck CFrame composed with the local placement transform (offset + facing)
    local deckCF = CFrame.new(table.unpack(deckCF12))
    local placedCF = deckCF * CFrame.new(table.unpack(self._buildingPlacer.placeCF(placement)))
    local mount = { cframe = { placedCF:GetComponents() }, footprint = buildingFP }
    local prefabName = self._sizeClasses.prefabName(teahouse.loadout.baseStyle, teahouse.size)
    local model = self._structureBuilder.build(teahouse.loadout, mount, self._catalog, self._structureOps, prefabName) :: Model
    model.Name = "Structure"
    -- (no ScaleTo: sizes are authored per-size prefabs, not a scaled base)
    if not treatment.lit then
        shutter(model)
    end
    model.Parent = staging
    if model:IsA("Model") then
        model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
    end
```

(Remove the now-unused `local s = self._sizeClasses.scale[teahouse.size]` line. Leave `deckFootprint`/`scale` for decks untouched elsewhere.)

- [ ] **Step 3: Lint + suite**

Run: `cd roblox && stylua --check src tests && selene src` (clean), then `cd roblox && lune run tests/run` (green — no regressions; StructureBuilder.spec already updated for the new signature in Task 3).

- [ ] **Step 4: Commit**

```bash
git add roblox/src/server/TreatmentApplier.luau
git commit -m "feat(roblox): TreatmentApplier picks per-size prefab, drops building scale, per-size fit-check

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ"
```

---

### Task 5 (INTERACTIVE — main session, Studio): Re-designate M → `teahouse-1story-m`, shell-only

Done with the user via Studio MCP + visual gate — NOT a subagent. No git commit (place-state).

- [ ] **Step 1: Duplicate the current prefab**

In Studio (Edit): clone `ServerStorage.StructurePrefabs.teahouse-1story` → rename the clone `teahouse-1story-m`, parented under `StructurePrefabs`. Keep the original `teahouse-1story` for now (removed in Task 8) so nothing hard-crashes if the place is Played mid-transition.

- [ ] **Step 2: Strip engawa/koran from `-m`**

Remove from `teahouse-1story-m`: the `Skirt` + `SkirtEnd` apron parts, the `Koran` folder, the `WEndRail` folder, and the `EngawaSupport` folder. **Keep** all `Bay_*` (with their tags/attributes), the roof (RoofF/RoofB/rafters/hip/ridge/gables/plate), tatami (TatamiMats/TatamiUnderlay/Table/MossF/InteriorGlow), the shoji track (Kamoi/Shikii/GrooveRail/WallPost), and the chōchin. Report exactly what was removed.

- [ ] **Step 3: Measure + visual gate (STOP and ask the user to look)**

Measure and report `teahouse-1story-m`'s wall footprint (bays extent) — expect ~18.7×12.7. Then: place `-m` on a real M deck at a perch (or Play), and confirm with the user — the deck's own koran railing is present with NO second (teahouse) railing, the veranda floor reads right against the shell, and the roof/tatami are intact. One attempt, then stop for the user.

- [ ] **Step 4: User saves the place** (place-state persistence).

---

### Task 6 (INTERACTIVE — main session, Studio): Author `teahouse-1story-s` (2×1)

- [ ] **Step 1: Build the S shell from M's tagged parts**

Duplicate `teahouse-1story-m` → `teahouse-1story-s`. Reduce to a **2×1** bay grid: keep front bays 1–2, back bays 1–2, one left bay, one right bay; delete the surplus bays (front/back bay 3, the second left/right bay). **Re-index** so each side is contiguous `1..N` (`Bay_front_1/2`, `Bay_back_1/2`, `Bay_left_1`, `Bay_right_1`) and each `Bay_*`'s `Index` attribute matches its name — `applyBays`/`readManifest` key off `Bay_<side>_<index>` with contiguous indices. Shrink the roof, tatami, and shoji track (kamoi/shikii/groove-rails) to the 2×1 footprint. Keep every kept bay's `Bay`/`Side`/`Index`/`Role_*`/`ShownTransparency` tags intact.

- [ ] **Step 2: Measure + visual gate (STOP and ask)**

Report the S wall footprint (expect ~12.5×6.35). Play (or place on an S deck): confirm the small S builds dormant on a vacant pad and lit when claimed, sits with generous yard on the S deck, the deck railing/veranda read right, and the **B1 back door** works on the 2 back bays (`Bay_back_1/2`). One attempt, then stop.

- [ ] **Step 3: User saves the place.**

---

### Task 7 (INTERACTIVE — main session, Studio): Author `teahouse-1story-l` (4×3)

- [ ] **Step 1: Build the L shell from M's tagged parts**

Duplicate `teahouse-1story-m` → `teahouse-1story-l`. Grow to a **4×3** bay grid: add a 4th front + 4th back bay and a 3rd left + 3rd right bay (copy an existing tagged bay of that side, re-index contiguously so `Bay_front_1..4`, `Bay_back_1..4`, `Bay_left_1..3`, `Bay_right_1..3`, each `Index` matching its name). Extend the roof, tatami, and shoji track to the 4×3 footprint.

- [ ] **Step 2: Verify L fits its deck (the spec's conditional)**

Place `teahouse-1story-l` centred on a real **L deck** at a perch. Measure the L teahouse footprint (walls, expect ~24.9×19) vs the L deck footprint (`deckFootprint("L")` ≈ 32.8×25.2). Confirm with the user that the front/view veranda keeps walk-around and the tight side is the **open back** (acceptable). If it genuinely crowds the pad, trim to **4×2** (drop the 3rd left/right bay) OR flag that the L deck placements need enlarging (which reopens only the L rows of the B2 deck survey) — do not ship a crowded L silently.

- [ ] **Step 3: Measure + visual gate (STOP and ask)**

Report the final L footprint; confirm L builds and reads right on the L deck, deck railing/veranda correct, back door works on the 4 back bays. One attempt, then stop.

- [ ] **Step 4: User saves the place.**

---

### Task 8 (INTERACTIVE — main session): Combined gate + orphan cleanup

- [ ] **Step 1: Full re-Play gate**

Rojo-sync (restart `rojo serve` so the code changes land) + Play. With the B2 test account (or by seeding sizes), confirm end-to-end: vacant pads show the **small S** darkened; claiming/buying an **S** builds `teahouse-1story-s` on its deck; **M** builds `teahouse-1story-m` (shell-only, single deck railing); **L** builds `teahouse-1story-l` and fits the L deck; no teahouse renders a second koran; the B1 back door works on each size's back bays. One attempt per size, then STOP and ask the user to confirm.

- [ ] **Step 2: Remove the orphan**

Once confirmed, delete the old `ServerStorage.StructurePrefabs.teahouse-1story` (now unreferenced — the code clones `teahouse-1story-{s,m,l}`).

- [ ] **Step 3: User saves the place** (persists all three prefabs + the orphan removal).

---

## Notes for the executor

- **Do not** commit `SecretsLocal.luau`/`server/.env`. Never insert/require asset id 139590959377658.
- **Bay indexing is load-bearing:** `readManifest`/`applyBays`/`WallBays.resolve` key off `Bay_<side>_<index>` and each part's `Bay`/`Side`/`Index` attributes. When adding/removing bays (Tasks 6–7), keep per-side indices contiguous `1..N` and each `Index` attribute matching its model name, or bays silently drop out of the wall.
- **No economy/deck change:** `baseStyle` stays `"teahouse-1story"`, `DEFAULT_TEAHOUSE_LOADOUT`/`VacantState.VACANT_BASE` unchanged, deck sizes/placements unchanged (unless Task 7 finds L doesn't fit).
- **Place-state persists only on save** — every interactive task ends by asking the user to save the place; the prefabs are not in git.
```
