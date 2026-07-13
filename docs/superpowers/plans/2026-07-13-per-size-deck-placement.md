# Per-Size Deck Placement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Place each perch's deck from a per-size authored table (`PadSites.deckPlacements[size]`) and center the teahouse on it, replacing the single fixed `mountCF` + per-pad teahouse `placement`.

**Architecture:** A new pure `DeckPlacement.resolve` looks up the deck-pivot CFrame for the requested size (falling back to `maxSize`). `PadSites` carries `deckPlacements = { S, M, L }` instead of one `mountCF`. `TreatmentApplier` resolves the per-size datum and feeds it to the unchanged deck/post pipeline; `SiteCoordinator` emits a centered teahouse placement constant. The S/M placements are surveyed per perch in a final visual pass; L migrates from the current `mountCF`.

**Tech Stack:** Luau (Roblox + Lune), Rojo, the bespoke Lune harness (`lune run tests/run` from `roblox/`), stylua + selene. Studio MCP `execute_luau` for the place-only survey/bake.

## Global Constraints

- **Deck and teahouse sizes are independent inputs.** This piece consumes the two sizes; it does not manage the economy (Piece B).
- **Placement is authored per (pad × size), not computed.** No access mark, no placement rule. Reachability is guaranteed by the author placing each deck touching its access.
- **The teahouse is centered on the deck**, inheriting the deck's view orientation: placement constant `{ offset = { 0, 0 }, facing = "N" }`.
- **`deckPlacements[size]` is the deck PIVOT** (center; `y` = deck-top datum), consumed exactly as `mountCF` was by `PadBuilder.buildDeck` / `PadOps.new`.
- **F2/F4 degradation:** an unauthored/oversized size resolves to `maxSize`'s placement; if even that is missing, warn and skip the deck — never error the caller (matches `TreatmentApplier`'s existing transactional staging).
- **Pure modules are dependency-injected and Lune-tested; never require each other** (a pure module may require a pure Lune-loadable sibling). `TreatmentApplier`/`PadSites`/`main.server` use Roblox datatypes and are visual-gated, not Lune-tested.
- TDD for pure modules; `stylua --check src tests tools` and `selene src` clean; commit per task with the repo's trailers.

---

# PHASE 1 — Pure lookup + centered placement + per-size wiring (headless)

## Task 1: `DeckPlacement` pure module

**Files:**
- Create: `roblox/src/shared/DeckPlacement.luau`
- Test: `roblox/tests/DeckPlacement.spec.luau`

**Interfaces:**
- Produces: `DeckPlacement.resolve(deckPlacements: { [string]: { number } }, deckSize: string, maxSize: string) -> { number }?` — the deck-pivot 12-array for `deckSize`, else `maxSize`'s, else `nil`. Type `Placements = { [string]: { number } }`.

- [ ] **Step 1: Write the failing test** — `roblox/tests/DeckPlacement.spec.luau`:

```luau
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local DeckPlacement = require("../src/shared/DeckPlacement")

local S_CF = { 1, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local L_CF = { 9, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local PLACEMENTS = { S = S_CF, L = L_CF }

describe("DeckPlacement.resolve", function()
    test("returns the requested size's placement when authored", function()
        expect(DeckPlacement.resolve(PLACEMENTS, "S", "L")).toBe(S_CF)
        expect(DeckPlacement.resolve(PLACEMENTS, "L", "L")).toBe(L_CF)
    end)
    test("falls back to maxSize when the requested size is unauthored", function()
        expect(DeckPlacement.resolve(PLACEMENTS, "M", "L")).toBe(L_CF) -- M unauthored -> L
    end)
    test("returns nil when neither the size nor maxSize is authored", function()
        expect(DeckPlacement.resolve({ S = S_CF }, "M", "L")).toBe(nil)
    end)
end)
```

- [ ] **Step 2: Run** → `lune run tests/run` (from `roblox/`) → FAIL (`DeckPlacement` not found).

- [ ] **Step 3: Implement** — `roblox/src/shared/DeckPlacement.luau`:

```luau
--!strict
-- Pure per-size deck-placement lookup. Each pad authors a deck-pivot CFrame (12-number array)
-- per size in `deckPlacements`; resolve returns the one for `deckSize`, falling back to
-- `maxSize`'s placement when a size is unauthored (e.g. a not-yet-surveyed S/M), and nil when
-- even that is missing (the Roblox caller then skips the deck). Pure (Lune-tested).
local DeckPlacement = {}

export type Placements = { [string]: { number } }

function DeckPlacement.resolve(deckPlacements: Placements, deckSize: string, maxSize: string): { number }?
    return deckPlacements[deckSize] or deckPlacements[maxSize]
end

return DeckPlacement
```

- [ ] **Step 4: Run** → PASS (+3). Then `stylua src tests && selene src`.
- [ ] **Step 5: Commit** — `feat(roblox): DeckPlacement per-size deck-pivot lookup` + repo trailers.

---

## Task 2: `SiteCoordinator` emits a centered teahouse placement

**Files:**
- Modify: `roblox/src/shared/SiteCoordinator.luau`
- Test: `roblox/tests/SiteCoordinator.spec.luau`

**Interfaces:**
- Produces: `Action.teahouse.placement` is now the constant `{ offset = { 0, 0 }, facing = "N" }` (centered on the deck), no longer sourced from `spec.placement`.

- [ ] **Step 1: Update the failing test** — in `roblox/tests/SiteCoordinator.spec.luau`:
  1. In the `spec` helper, **delete** the `mountCF = { ... }` line and the `placement = PLACEMENT,` line (SiteCoordinator no longer reads either). Keep `PLACEMENT` defined at the top as the expected centered value. The helper becomes:

```luau
local PLACEMENT = { offset = { 0, 0 }, facing = "N" }
local function spec(id: string, maxSize: string?)
    return {
        id = id,
        maxSize = maxSize or "L",
        deckSize = maxSize or "L",
        vacantForm = "dormant-structure",
    }
end
```

  2. Change the placement assertion in the first test from `toBe` to `toEqual` (SiteCoordinator now emits its own centered constant — a distinct table with the same value):

```luau
        expect((a :: any).teahouse.placement).toEqual(PLACEMENT)
```

- [ ] **Step 2: Run** → `lune run tests/run` → FAIL (`teahouse.placement` is `nil` because `spec.placement` was removed).

- [ ] **Step 3: Implement** — in `roblox/src/shared/SiteCoordinator.luau`:
  1. Add near `STARTER` (after line 28):

```luau
-- The teahouse sits centered on the deck (walk-around default), inheriting the deck's view
-- orientation. Where the player REpositions it, or adds a back door, is Piece B.
local CENTERED = { offset = { 0, 0 }, facing = "N" }
```

  2. In `starterAction`, replace `placement = spec and spec.placement` with `placement = CENTERED`:

```luau
        teahouse = { size = STARTER, loadout = treatment.loadout, placement = CENTERED },
```

  3. In `onJoin`, replace `placement = rec.spec.placement` with `placement = CENTERED`:

```luau
                        teahouse = { size = size, loadout = loadout, placement = CENTERED },
```

- [ ] **Step 4: Run** → PASS. `stylua src tests && selene src`.
- [ ] **Step 5: Commit** — `feat(roblox): SiteCoordinator centers the teahouse on the deck` + repo trailers.

---

## Task 3: Per-size deck datum — `PadSites` data + `TreatmentApplier` + `main.server`

**Files:**
- Modify: `roblox/src/server/PadSites.luau` (all 14 entries + header)
- Modify: `roblox/src/server/TreatmentApplier.luau`
- Modify: `roblox/src/server/main.server.luau`

**Interfaces:**
- Consumes: `DeckPlacement.resolve` (Task 1).
- Produces: `PadSites[id].deckPlacements = { [size]: { number } }` (replaces `mountCF`); `TreatmentApplier.Deps` gains `deckPlacement`. Teahouse placement comes from `teahouse.placement` (the centered constant from Task 2) unchanged.

- [ ] **Step 1: Migrate the `PadSites` data.** For every one of the 14 entries, wrap the `mountCF` array as `deckPlacements.L` and delete the `placement` line. Run from `roblox/`:

```bash
perl -0777 -i -pe 's/mountCF = (\{[^}]*\}),/deckPlacements = { L = $1 },/g' src/server/PadSites.luau
perl -i -ne 'print unless /^\s*placement = \{ offset =/' src/server/PadSites.luau
```

Verify: `grep -c mountCF src/server/PadSites.luau` → header mentions only (no data lines); `grep -c 'deckPlacements = { L =' src/server/PadSites.luau` → `14`; `grep -c 'placement = {' src/server/PadSites.luau` → `0`. A migrated entry reads:

```luau
    ["T01"] = {
        id = "T01",
        displayName = "Near Perch 01",
        deckPlacements = { L = { 43.339, 200.6605, 121.6285, 0.9404, 0, 0.3401, 0, 1, 0, -0.3401, 0, 0.9404 } },
        maxSize = "L",
        deckSize = "L",
        vacantForm = "dormant-structure",
    },
```

- [ ] **Step 2: Update the `PadSites` header comment.** Replace the two paragraphs describing `mountCF` (the 2026-07-12 re-bake note and the Task 9/12 placement note) with:

```luau
-- 2026-07-13 PER-SIZE DECK PLACEMENT: `mountCF` (one deck-pivot) -> `deckPlacements = { S,M,L }`,
-- one authored deck PIVOT per size (12-number array, y = deck-top datum, view-oriented). Each
-- size is surveyed to touch that perch's access and extend toward the view; L migrated from the
-- prior mountCF (S/M surveyed in the deck-placement visual pass). The teahouse is centered on the
-- deck (SiteCoordinator), so the per-pad teahouse `placement` field is gone.
```

- [ ] **Step 3: Wire `DeckPlacement` into `TreatmentApplier`.** Edits in `roblox/src/server/TreatmentApplier.luau`:
  1. In `Deps` (after `sizeClasses`), add: `deckPlacement: any, -- pure per-size deck-pivot lookup (DeckPlacement)`.
  2. In `new()` (after `_sizeClasses = deps.sizeClasses,`), add: `_deckPlacement = deps.deckPlacement,`.
  3. Change `_buildBuilding`'s signature to take the resolved deck datum instead of `spec` (it only used `spec.mountCF`). Replace the function header and the `deckCF` line:

```luau
function TreatmentApplier:_buildBuilding(
    padId: string,
    deckCF12: { number },
    treatment: any,
    teahouse: any,
    deckSize: string,
    staging: Instance
)
```

  and replace `local deckCF = CFrame.new(table.unpack(spec.mountCF))` with:

```luau
    local deckCF = CFrame.new(table.unpack(deckCF12))
```

  4. In `apply()`, resolve the per-size datum once and thread it through. Replace everything from `local staging = Instance.new("Folder")` down **to and including** the `if not okBuilding then ... end` block (i.e. up to but NOT touching the final commit loop that `Destroy`s the old children and reparents `staging`'s children into `folder`) with the following. Note the resolve + nil-check are inserted *before* `staging` is created, so a missing placement skips without leaving an orphan folder:

```luau
    local deckCF12 = self._deckPlacement.resolve(spec.deckPlacements, deckSize, spec.maxSize)
    if deckCF12 == nil then
        warn(`[D.6] {padId}: no deck placement for size {deckSize} (maxSize {spec.maxSize}); skipping`)
        return
    end
    local staging = Instance.new("Folder")
    local mountCF = CFrame.new(table.unpack(deckCF12))
    local okDeck, deckErr = pcall(function()
        self._padBuilder.buildDeck(deckSize, deckCF12, self._padOpsNew(mountCF, staging))
    end)
    if not okDeck then
        warn(`[D.6] deck build failed for {padId}: {deckErr}`)
        staging:Destroy()
        return -- keep whatever was there (F4: no crash, no orphan swap)
    end
    if teahouse ~= nil and teahouse.loadout ~= nil then
        local okBuilding, buildingErr = pcall(function()
            self:_buildBuilding(padId, deckCF12, treatment, teahouse, deckSize, staging)
        end)
        if not okBuilding then
            warn(`[D.6] building step failed for {padId}: {buildingErr}; deck only`)
        end
    end
```

  (This drops the two `CFrame.new(table.unpack(spec.mountCF))` reads; everything downstream — `buildDeck`, `padOpsNew`, the commit/swap — is unchanged.)

- [ ] **Step 4: Inject `DeckPlacement` in `main.server`.** In `roblox/src/server/main.server.luau`:
  1. After the `SizeClasses` require (line 371), add: `local DeckPlacement = require(shared:WaitForChild("DeckPlacement"))`.
  2. In the `TreatmentApplier.new({ ... })` deps table (after `sizeClasses = SizeClasses,`), add: `deckPlacement = DeckPlacement,`.

- [ ] **Step 5: Run + lint** — `lune run tests/run` → all prior pure tests still green (these files aren't Lune-tested; nothing they touch breaks). `stylua --check src tests && selene src` clean.

- [ ] **Step 6: Commit** — `feat(roblox): per-size deck placement (PadSites deckPlacements + TreatmentApplier)` + repo trailers.

**Phase 1 gate:** the runtime is consistent but **only `L` is authored** — a vacant/starter pad requests `deckSize = "S"`, which `resolve` falls back to `L`'s placement, so an S-sized deck materializes centered on the pad (not yet touching access). This is expected and harmless; Phase 2 surveys the real S/M placements. Do not treat a centered S deck as a bug before Task 4.

---

# PHASE 2 — Survey S/M placements + visual gate (Studio, place-only)

## Task 4: Survey per-size deck placements + gate + tune

Place-only Studio work via MCP `execute_luau`, visual-gated, following the Piece-A survey pattern. **Studio must be open with the saved place, and the pad geometry (tunnels/paths) present.** This is collaborative: the user drags each deck into position; the tool bakes the CFrames.

- [ ] **Step 1: Bake tool.** Write `roblox/tools/studio/surveyDeckPlacements.luau` with two entry points driven by a `MODE` local:
  - `MODE = "place"`: for a given `padId` and `size`, build that size's deck (via `PadBuilder.buildDeck`) at the pad's current `deckPlacements[maxSize]` (or `.L`) into `workspace.DeckSurvey`, named `Deck_<padId>_<size>`, so the user can drag it to touch access and face the view.
  - `MODE = "bake"`: read every `workspace.DeckSurvey.Deck_<padId>_<size>` model's pivot (`:GetPivot():GetComponents()`), and print a ready-to-paste `deckPlacements` table per pad (S/M/L) for `PadSites`. (Print to output; the values are pasted into `PadSites` by hand, exactly as the mountCF survey was baked.)

- [ ] **Step 2: Survey each perch.** For each of the 14 perches, for each size up to its `maxSize` (S and M; L is already the migrated value but re-confirm/tune): build the deck (`MODE="place"`), have the user drag it so it **touches the perch's access (tunnel mouth / path) and extends toward the view**, then move to the next. Keep the sizes consistent per perch (same access edge, growing toward the view) so upgrades read as growth.

- [ ] **Step 3: Bake + paste.** Run `MODE="bake"`, and paste the printed `deckPlacements = { S = {...}, M = {...}, L = {...} }` tables into the 14 `PadSites` entries (replacing each `deckPlacements = { L = ... }`).

- [ ] **Step 4: Visual gate.** Materialize a representative matrix through the real `TreatmentApplier` path (as in the SP1 / Piece-A gates): an S deck (vacant starter) and an L deck (owned) on a right-hand perch (T02) and a former-left-hand perch (T05); plus an M deck on one perch. Confirm for each: the deck **touches access** (a player emerging steps onto it), it **extends toward the view**, and the **teahouse is centered with a walkable margin** (circle-around to the front works). On the tight L perch (T05), confirm the L teahouse's walk-around is blocked — the expected "player adds a back door in Piece B" case — and that it's left centered at best-fit (no crash, no door).

- [ ] **Step 5: Clean + save.** Delete `workspace.DeckSurvey`. `lune run tests/run` green; `stylua --check src tests tools && selene src` clean. **Save the place.**

- [ ] **Step 6: Commit** — `feat(roblox): survey per-size deck placements for all 14 perches` + repo trailers (the `PadSites` S/M values + the `surveyDeckPlacements.luau` tool; note the placements are place-only-derived, pasted by hand).

**Phase 2 gate:** every perch anchors each deck size touching its access and growing toward the view; the teahouse centers with walk-around where the deck margin allows; tight-pad L is left at best-fit for a Piece-B door. Tests green, lint clean, place saved.

---

## Notes / follow-ups (not in this plan)

- **Piece B** (next): the modular economy (deck / teahouse / decoration as independent earned items, teahouse ≤ deck, purchase gating), the customization UI, the **player back door** (SP1 `applyBays` on a `wallBays` map), and teahouse repositioning on roomy decks.
- The `wallBays` server whitelist (`server/src/loadout.ts`) remains deferred to Piece B (see the SP1 plan's follow-ups).
- Per-size authoring scales linearly with pads × sizes; revisit a rule/hybrid if the metagame's "50+ pads across two new valleys" lands.
