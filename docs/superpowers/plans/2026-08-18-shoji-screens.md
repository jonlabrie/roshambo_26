# Shoji Screens Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make every teahouse shoji screen slide — hold a prompt, the screen moves, everyone in the house sees it, and the owner's arrangement is still there tomorrow.

**Architecture:** A pure `ShojiRun` module owns all the arithmetic (clamping, grooves, displacement) and is Lune-tested; the Roblox-runtime files stay thin. The server owns each screen's offset, writes it as a `ShojiOpen` attribute on the bay model, and a client controller tweens the leaf to match — the same attribute-plus-controller pattern the day/night and lantern systems use. Prompts are bound by a client controller modelled directly on `BackDoorController.client.luau`, which already solved prompt binding across teahouse rebuilds. Persistence rides the existing `net:setTeahouse` → `PUT /api/v1/players/:id/teahouses/:sizeClass` path, exactly as `SetBackDoor` does.

**Tech Stack:** Luau (Rojo-managed `src/`), Lune test harness, stylua + selene; TypeScript + vitest for the loadout validator; one Studio tool for place-only prefab work.

**Spec:** `docs/superpowers/specs/2026-08-18-shoji-screens-design.md`

## Global Constraints

- **1 stud = 1 foot, 1 inch = 1/12 stud.** Every dimension below is in studs.
- **Bay pitch is 6.00; a leaf is 5.90 wide; groove pitch is 0.20.** Groove `i` of an N-bay run sits at `wallCentre + (i - (N+1)/2) * 0.20`.
- **A screen clamps to its run's ends and no tighter.** No per-screen travel cap. Any bay may be the one the stack covers.
- **Owner slides persist; visitor slides do not.** A visitor's slide is live for everyone present and gone at the next materialize.
- **Luau modules take Roblox services by dependency injection** — no `game:GetService` in anything under `src/shared`, so it runs under Lune.
- **`StructurePrefabs` is place-only.** Prefab edits happen through a committed, idempotent Studio tool, and the place must be SAVED afterwards.
- **Owner gates are visual and belong to the owner.** One attempt, then they look.

---

## File Structure

**New**
- `roblox/src/shared/ShojiRun.luau` — pure: groove z per bay, clamp, displacement, side-map normalisation.
- `roblox/tests/ShojiRun.spec.luau` — its suite.
- `roblox/src/client/ShojiController.client.luau` — binds prompts, tweens leaves from `ShojiOpen`.
- `roblox/tools/studio/trackShojiBays.luau` — re-tracks prefab leaves onto grooves, merges each side's rails into one sill.

**Modified**
- `roblox/src/server/StructureOps.luau` — `applyShoji`, called wherever `applyBays` is.
- `roblox/src/server/main.server.luau` — `SlideShoji` handler, the hold loop, owner-only debounced persist.
- `roblox/default.project.json` — `SlideShoji` + `ShojiState` RemoteEvents.
- `server/src/loadout.ts` + `server/src/loadout.test.ts` — `shojiOpen` key and validator.
- `docs/wiki/world/teahouses.md`, `docs/wiki/program/friends-family-baseline.md`, `docs/wiki/log.md`.

---

### Task 1: `ShojiRun` — the arithmetic, with nothing Roblox in it

**Files:**
- Create: `roblox/src/shared/ShojiRun.luau`
- Test: `roblox/tests/ShojiRun.spec.luau`

**Interfaces:**
- Produces: `ShojiRun.PITCH` (6.00), `ShojiRun.GROOVE_PITCH` (0.20), `ShojiRun.grooveOffset(index, count) -> number`, `ShojiRun.clamp(index, count, open) -> number`, `ShojiRun.displacement(open) -> number`, `ShojiRun.resolve(sideMap, count) -> { number }`, `ShojiRun.directionFrom(open) -> number`.
- Consumes: nothing.

- [ ] **Step 1: Write the failing test** — `roblox/tests/ShojiRun.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local ShojiRun = require("../src/shared/ShojiRun")

describe("ShojiRun.clamp — a screen stops at the ends of its own run", function()
    test("the end screens can only travel inward", function()
        -- a four-bay run: bay 1 can go 0..+3, bay 4 can go -3..0
        expect(ShojiRun.clamp(1, 4, 3)).toBe(3)
        expect(ShojiRun.clamp(1, 4, 4)).toBe(3)
        expect(ShojiRun.clamp(1, 4, -1)).toBe(0)
        expect(ShojiRun.clamp(4, 4, -3)).toBe(-3)
        expect(ShojiRun.clamp(4, 4, 1)).toBe(0)
    end)

    test("an interior screen travels both ways", function()
        expect(ShojiRun.clamp(3, 4, -2)).toBe(-2)
        expect(ShojiRun.clamp(3, 4, 1)).toBe(1)
        expect(ShojiRun.clamp(3, 4, 2)).toBe(1)
    end)

    test("there is no per-screen cap — only the run", function()
        -- the owner's ruling, 2026-08-18: a whole run may tuck into one bay
        expect(ShojiRun.clamp(1, 4, 3)).toBe(3)
    end)

    test("a one-bay run cannot move at all", function()
        expect(ShojiRun.clamp(1, 1, 2)).toBe(0)
    end)

    test("nonsense resolves to closed rather than erroring", function()
        expect(ShojiRun.clamp(1, 4, 0 / 0)).toBe(0)
        expect(ShojiRun.clamp(1, 4, nil :: any)).toBe(0)
    end)
end)

describe("ShojiRun — a whole run can stack in any single bay", function()
    test("every screen can reach every bay position", function()
        for count = 2, 4 do
            for target = 1, count do
                for index = 1, count do
                    local want = target - index
                    expect(ShojiRun.clamp(index, count, want)).toBe(want)
                end
            end
        end
    end)
end)

describe("ShojiRun.grooveOffset — one channel per screen, centred on the wall", function()
    test("two grooves straddle the wall's mid-plane", function()
        expect(ShojiRun.grooveOffset(1, 2)).toBe(-0.1)
        expect(ShojiRun.grooveOffset(2, 2)).toBe(0.1)
    end)

    test("three grooves put the middle screen on the mid-plane", function()
        expect(ShojiRun.grooveOffset(1, 3)).toBe(-0.2)
        expect(ShojiRun.grooveOffset(2, 3)).toBe(0)
        expect(ShojiRun.grooveOffset(3, 3)).toBe(0.2)
    end)

    test("four grooves span 0.60 between the outer two", function()
        expect(ShojiRun.grooveOffset(4, 4) - ShojiRun.grooveOffset(1, 4)).toBeCloseTo(0.6, 0.0001)
    end)

    test("no two screens in a run share a groove", function()
        for count = 2, 4 do
            local seen = {}
            for i = 1, count do
                local z = ShojiRun.grooveOffset(i, count)
                expect(seen[z]).toBe(nil)
                seen[z] = true
            end
        end
    end)
end)

describe("ShojiRun.directionFrom — which way a hold sends a screen", function()
    test("a closed screen opens, an open one shuts", function()
        expect(ShojiRun.directionFrom(0)).toBe(1)
        expect(ShojiRun.directionFrom(0.4)).toBe(1)
        expect(ShojiRun.directionFrom(0.5)).toBe(-1)
        expect(ShojiRun.directionFrom(2)).toBe(-1)
    end)

    test("it reads the DISTANCE from home, so a screen slid either way comes back", function()
        expect(ShojiRun.directionFrom(-0.4)).toBe(1)
        expect(ShojiRun.directionFrom(-2)).toBe(1)
    end)
end)

describe("ShojiRun.displacement — travel in bay-widths becomes studs", function()
    test("one bay-width is the pitch", function()
        expect(ShojiRun.displacement(1)).toBe(6)
        expect(ShojiRun.displacement(-2)).toBe(-12)
        expect(ShojiRun.displacement(0.5)).toBe(3)
    end)
end)

describe("ShojiRun.resolve — a stored map becomes one number per bay", function()
    test("missing entries are closed", function()
        expect(ShojiRun.resolve(nil, 3)).toEqual({ 0, 0, 0 })
        expect(ShojiRun.resolve({ 1 }, 3)).toEqual({ 1, 0, 0 })
    end)

    test("stored values are clamped to the run they land in", function()
        -- a house that shrank: a saved offset from a wider run must not hang a screen off the end
        expect(ShojiRun.resolve({ 3, 0 }, 2)).toEqual({ 1, 0 })
    end)

    test("junk in a slot is closed, not an error", function()
        expect(ShojiRun.resolve({ "x" :: any, 1 }, 2)).toEqual({ 0, 0 })
    end)
end)
```

- [ ] **Step 2: Run it, watch it fail.** `cd roblox && lune run tests/run` — expect `attempt to call a nil value` (the module does not exist).

- [ ] **Step 3: Write `roblox/src/shared/ShojiRun.luau`:**

```lua
--!strict
-- The arithmetic of a sliding shoji run. Pure — no Roblox globals, no instances — so it runs
-- under Lune and every rule below is tested without a place open.
--
-- A run is one wall's shoji bays, numbered 1..count along the wall. A screen's position is
-- `open`, its travel in BAY-WIDTHS from its own bay: 0 is home, +1 is parked over the next bay
-- up the run, -2 is two bays down it.
--
-- THERE IS NO PER-SCREEN TRAVEL CAP (owner, 2026-08-18). A screen may slide anywhere between
-- the first and last bay positions of its wall, so an entire run can tuck into a single bay and
-- that bay can be any of them. The fullest opening is therefore count-1 bays: the screens have
-- to be somewhere, and this design has no pocket to hide them in.
local ShojiRun = {}

ShojiRun.PITCH = 6.0 -- bay spacing, and so the travel of one full bay-width
ShojiRun.GROOVE_PITCH = 0.20 -- depth between adjacent channels

-- Groove z for bay `index` of a `count`-bay run, relative to the wall's mid-plane. Centred, so
-- a two-bay run straddles the wall and a four-bay run stands 0.30 proud of each face. Every bay
-- gets its OWN groove: that is what lets a whole run stack in one bay without clipping.
function ShojiRun.grooveOffset(index: number, count: number): number
    return (index - (count + 1) / 2) * ShojiRun.GROOVE_PITCH
end

-- Travel in bay-widths -> studs along the wall.
function ShojiRun.displacement(open: number): number
    return open * ShojiRun.PITCH
end

-- Clamp a requested travel to what the run allows: a screen may reach any bay position, and no
-- position beyond the run. Anything that is not a finite number reads as closed, because a
-- screen that refuses to render is worse than one that is shut.
function ShojiRun.clamp(index: number, count: number, open: number?): number
    if typeof(open) ~= "number" or open ~= open or open == math.huge or open == -math.huge then
        return 0
    end
    local lo, hi = 1 - index, count - index
    return math.clamp(open, lo, hi)
end

-- Which way a hold should send a screen: open while it is nearer home than half a bay, shut
-- once it is past that. One prompt does both jobs, so the rule has to be a function of position
-- rather than of a remembered state -- and it reads the DISTANCE from home, so a screen slid to
-- -2 comes back the way it went rather than continuing off the end of the wall.
--
-- Note the sign: this returns the direction of TRAVEL for a screen at rest. The handler latches
-- it once at hold-start; recomputing per step would reverse a screen under the player's finger
-- the moment it crossed the half mark.
function ShojiRun.directionFrom(open: number): number
    return if math.abs(open) < 0.5 then 1 else -1
end

-- A stored side map (a list of travels, one per bay) resolved against the run actually built.
-- Extra entries are dropped and missing ones read as closed, so a house that changed size does
-- not hang a screen off the end of a shorter wall.
function ShojiRun.resolve(stored: { number }?, count: number): { number }
    local out = table.create(count, 0)
    for i = 1, count do
        local v = if stored ~= nil then stored[i] else nil
        out[i] = ShojiRun.clamp(i, count, v)
    end
    return out
end

return ShojiRun
```

- [ ] **Step 4: Run the suite.** `lune run tests/run` → all green. Then `stylua --check src tests tools && selene src tools`.

- [ ] **Step 5: Commit** — `feat(roblox): ShojiRun — the arithmetic of a sliding screen run`.

---

### Task 2: `shojiOpen` on the loadout, validated server-side

**Files:**
- Modify: `server/src/loadout.ts`
- Test: `server/src/loadout.test.ts`

**Interfaces:**
- Consumes: `KNOWN_SIDES`, `MAX_BAYS_PER_SIDE` (both already exported).
- Produces: `validateShojiOpen(value): Check`, `shojiOpen` accepted by `validateLoadout`.

- [ ] **Step 1: Write the failing tests** — append to `server/src/loadout.test.ts`:

```ts
describe('validateShojiOpen', () => {
    it('accepts a per-side list of travels', () => {
        expect(validateShojiOpen({ front: [0, 1, -1], back: [0] }).ok).toBe(true);
    });

    it('accepts an empty map (every screen closed)', () => {
        expect(validateShojiOpen({}).ok).toBe(true);
    });

    it('rejects an unknown side', () => {
        expect(validateShojiOpen({ roof: [0] }).ok).toBe(false);
    });

    it('rejects more entries than a wall can have bays', () => {
        expect(validateShojiOpen({ front: new Array(MAX_BAYS_PER_SIDE + 1).fill(0) }).ok).toBe(false);
    });

    it('rejects values no run could produce', () => {
        // the true limit is the run's own length and lives in ShojiRun; this only refuses nonsense
        expect(validateShojiOpen({ front: [MAX_BAYS_PER_SIDE] }).ok).toBe(false);
        expect(validateShojiOpen({ front: [Number.NaN] }).ok).toBe(false);
        expect(validateShojiOpen({ front: [Number.POSITIVE_INFINITY] }).ok).toBe(false);
    });

    it('rejects a non-list side and a non-object map', () => {
        expect(validateShojiOpen({ front: 'open' }).ok).toBe(false);
        expect(validateShojiOpen([0, 1]).ok).toBe(false);
    });

    it('travels are continuous, not just whole bays', () => {
        expect(validateShojiOpen({ front: [0.5, -1.25] }).ok).toBe(true);
    });
});

describe('validateLoadout with shojiOpen', () => {
    it('accepts a loadout carrying one', () => {
        expect(validateLoadout({ baseStyle: 'teahouse-1story', shojiOpen: { front: [1, 0] } }).ok).toBe(true);
    });

    it('rejects the whole loadout when it is malformed', () => {
        // half-applying a bad map would leave a house in a state nobody chose
        expect(validateLoadout({ baseStyle: 'teahouse-1story', shojiOpen: { front: ['x'] } }).ok).toBe(false);
    });
});
```

- [ ] **Step 2: Run, watch it fail.** `cd server && npx vitest run src/loadout.test.ts` — `validateShojiOpen is not a function`.

- [ ] **Step 3: Implement** in `server/src/loadout.ts`. Add `'shojiOpen'` to `LOADOUT_KEYS`, then beside `validateWallBays`:

```ts
// Where each shoji screen has been slid, in bay-widths from its own bay: { front: [0, 1, -1] }.
// The REAL limit is the run's own length (a four-bay wall lets its first screen travel +3 and no
// more), and that lives in ShojiRun on the Roblox side, which knows how many bays were built.
// This is the storage guard: it refuses what no run of any size could produce, so nonsense never
// reaches the database, and leaves the exact clamp to the code that knows the wall.
export function validateShojiOpen(value: unknown): Check {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
        return { ok: false, error: 'BAD_SHOJI_OPEN' };
    }
    for (const [side, travels] of Object.entries(value as Record<string, unknown>)) {
        if (!KNOWN_SIDES.has(side)) return { ok: false, error: 'BAD_SHOJI_OPEN' };
        if (!Array.isArray(travels) || travels.length > MAX_BAYS_PER_SIDE) {
            return { ok: false, error: 'BAD_SHOJI_OPEN' };
        }
        for (const t of travels) {
            if (typeof t !== 'number' || !Number.isFinite(t)) return { ok: false, error: 'BAD_SHOJI_OPEN' };
            if (Math.abs(t) >= MAX_BAYS_PER_SIDE) return { ok: false, error: 'BAD_SHOJI_OPEN' };
        }
    }
    return { ok: true };
}
```

And in `validateLoadout`, beside the `wallBays` branch:

```ts
    if (obj.shojiOpen !== undefined) {
        const so = validateShojiOpen(obj.shojiOpen);
        if (!so.ok) return so;
    }
```

- [ ] **Step 4: Run.** `npx vitest run src/loadout.test.ts` → green, then `npm test` for the whole server suite.

- [ ] **Step 5: Commit** — `feat(server): shojiOpen on the teahouse loadout`.

---

### Task 3: Re-track the prefabs — OWNER GATE

**Files:**
- Create: `roblox/tools/studio/trackShojiBays.luau`

**Interfaces:**
- Consumes: `ShojiRun.grooveOffset` (required as a CLONE — Studio caches a ModuleScript's result forever, and this tool will be run repeatedly during tuning; see `buildStatsBoards.luau`'s header for the bite).
- Produces: prefab leaves on their own grooves; one sill per side.

**Context:** every part of a bay currently shares one z, and two of the L's four front panels share a plane — they would collide when slid past each other. This is the only geometry work in the item.

- [ ] **Step 1: Write the tool.** For each of `teahouse-1story-s/m/l`, for each side, collect `Bay_<side>_<i>` in index order, then:
  - The **leaf** (paper, `ShojiGlow`, kumiko, stiles) of bay `i` moves to `wallPlane + grooveOffset(i, count)` in the wall's normal axis, keeping x/y.
  - The **rails** of every bay on that side are replaced by ONE sill part per height (top and bottom) spanning the run's full width, with z-size `count * GROOVE_PITCH + 0.16` so it visibly houses the channels.
  - Every moved part keeps its `ShownTransparency` attribute and its name; nothing is reparented, so `applyBays` and `TreatmentApplier`'s `shutter()` keep working by name.
  - **Idempotent**: every z is computed from the bay's index and the run's count, never nudged from what it finds, so a second run is a no-op. Print a table of what moved.

- [ ] **Step 2: Run it in Studio** (Edit datamodel, via `execute_luau`), then re-run it and confirm the second run reports zero movement.

- [ ] **Step 3: Verify by measurement, not by eye** — re-read every `Bay_*/Shoji` leaf z per prefab and assert: no two bays of a side share a z, spacing is exactly 0.20, and the set is centred on the wall plane.

- [ ] **Step 4: OWNER GATE.** Ask the owner to look at an **L** teahouse specifically — its sill stands 0.20 proud of each face, which is the one place this item changes a teahouse's silhouette. One attempt, then they look. **The owner must SAVE the place**; prefabs are place-only.

- [ ] **Step 5: Commit** the tool — `feat(roblox): a channel per shoji screen (Studio tool)`.

---

### Task 4: Apply saved offsets when a house materializes

**Files:**
- Modify: `roblox/src/server/StructureOps.luau`

**Interfaces:**
- Consumes: `ShojiRun.resolve`, `ShojiRun.displacement`; `manifest.bays` (already carries `{ side, index }`).
- Produces: `StructureOps.applyShoji(model, bays, shojiOpen)`, which moves each shown leaf and writes the `ShojiOpen` attribute on its bay model.

- [ ] **Step 1: Implement `applyShoji`.** For each bay in the manifest, resolve its side's travels, move `Bay_<side>_<i>/Shoji` by `displacement(open)` along the wall's own axis (the bay model's local X — take it from the bay's `Solid` panel CFrame, the one part that never moves), and `bay:SetAttribute("ShojiOpen", open)`.
  - Move the leaf with `PivotTo`, not by writing part CFrames one at a time: it is a Model, and a per-part write is where a rotation gets lost.
  - A missing bay, missing `Shoji` variant, or missing side entry warns and is skipped — the same failure posture `applyBays` already takes (F2/F4).

- [ ] **Step 2: Call it wherever `applyBays` is called** in `main.server.luau` (materialize, rebuild, back-door edit), passing `house.loadout.shojiOpen`. Grep for `applyBays(` — every site needs it, or a rebuild silently shuts every screen.

- [ ] **Step 3: Manual check in Studio (Play):** materialize a teahouse with `shojiOpen = { front = { 1, 0 } }` stubbed into the loadout and confirm the front screen renders parked over its neighbour, before anyone touches a prompt.

- [ ] **Step 4: Commit** — `feat(roblox): materialize a teahouse with its screens where they were left`.

---

### Task 5: `SlideShoji` — the hold loop, server-authoritative

**Files:**
- Modify: `roblox/default.project.json`, `roblox/src/server/main.server.luau`

**Interfaces:**
- Consumes: `ShojiRun.clamp`, `StructureOps.applyShoji`, `handlerQueue`, `net:setTeahouse`, `playerHouse`, `playerEconomy`.
- Produces: `SlideShoji` (client → server: `{ padId, side, index, held: boolean }`), `ShojiState` (server → client: `{ padId, side, index, open }`).

- [ ] **Step 1: Declare the remotes** in `default.project.json` beside `SetBackDoor`:

```json
                "SlideShoji": { "$className": "RemoteEvent" },
                "ShojiState": { "$className": "RemoteEvent" },
```
Rojo re-reads the project file only on connect — the implementer must RESTART `rojo serve`, not just reconnect.

- [ ] **Step 2: The handler**, modelled on `SetBackDoor.OnServerEvent` (`main.server.luau:1460`), through `handlerQueue:run(uid, ...)` for the same reason: this path yields on HTTP and a scripted client must not be able to issue unbounded PUTs.
  - **Who may slide:** anyone standing near the bay. Validate the player's character is within `MAX_ACTIVATION + 4` studs of that bay's `Solid` panel — the server never trusts the prompt fired, only that the player could plausibly reach it. There is no server-side "which pad is this player in" registry, and this check is what stands in for one.
  - **The loop:** `held = true` starts a per-(player, bay) loop advancing `open` by `SLIDE_RATE * dt` (`SLIDE_RATE = 1 / 1.2` bay-widths per second) in the direction implied by §4 of the spec — toward open below half, toward closed at or past it — clamped by `ShojiRun.clamp`, writing the attribute each step. `held = false`, the player leaving, or the structure dying stops it. One loop per player at a time.
  - **Direction is latched at hold-start**, not recomputed per step, or a screen crossing the half mark reverses under the player's finger.
  - Echo `ShojiState` to everyone at that pad on each step? **No** — the attribute already replicates. `ShojiState` exists only to tell the *holder's* client that its request was accepted, so a rejected hold does not leave a prompt looking stuck.

- [ ] **Step 3: Persist, owner only.** On hold end, if `playerHouse[uid]` exists and its `padId` matches the slid pad, debounce 2 s of quiet and then write: clone the loadout, set `shojiOpen[side][index]`, `net:setTeahouse(uid, house.size, newLoadout)`, and mirror into `playerEconomy[uid].teahouses[house.size]` — the same three-step shape `SetBackDoor` uses, for the same reason (rebuild paths render from the stash, not from `playerHouse`).
  - A visitor's hold end writes nothing. No error, no message: their slide simply is not theirs to keep.

- [ ] **Step 4: Test what can be tested.** The loop and the remote are Roblox-runtime and not unit-testable here; every rule they apply — the clamp, the direction, the displacement — is Task 1's and already covered. The check that matters at this step is a read of the handler against `SetBackDoor`: same queue, same stash-then-persist order, same F2/F4 skip-and-warn on a missing structure.

- [ ] **Step 5: Commit** — `feat(roblox): hold to slide a shoji screen, server-authoritative`.

---

### Task 6: `ShojiController` — prompts and the tween — OWNER GATE

**Files:**
- Create: `roblox/src/client/ShojiController.client.luau`

**Interfaces:**
- Consumes: `SlideShoji`, `ShojiState`, `ShojiRun.displacement`.
- Produces: nothing other than instances.

- [ ] **Step 1: Copy the lifecycle from `BackDoorController.client.luau` verbatim in shape** — `watchFolder` / `bindStructure` / late-arrival `ChildAdded`. That controller exists because RemoteEvents are not ordered against instance replication and every rebuild swaps the Structure under a stable site folder; a controller that binds at event-arrival time is racy. Do not re-derive this.

- [ ] **Step 2: One prompt per shoji bay.**
  - Anchor it to the bay's **`Solid` panel**, never to the leaf: the leaf is the thing that moves, and a prompt riding it drags off its own bay (the same trap `BackDoorController` documents at its `anchorPart`).
  - `HoldDuration = 60` so it never completes; drive `PromptButtonHoldBegan` → `SlideShoji:FireServer({ ..., held = true })` and `PromptButtonHoldEnded` → `held = false`.
  - `KeyboardKeyCode = Enum.KeyCode.E` is taken by the Favorite prompt and `F` by the back door — use **`Enum.KeyCode.G`** and record why in a comment.
  - `MaxActivationDistance = 12`, `RequiresLineOfSight = false`.
  - `ActionText` reads "Slide open" or "Slide shut" from the bay's current `ShojiOpen` attribute, updated on its `GetAttributeChangedSignal`.

- [ ] **Step 3: Tween the leaf** from `ShojiOpen`. On every change, tween the `Shoji` model's pivot to `home + displacement(open)` along the bay's local X over ~0.12 s linear — short enough to feel driven by the hold, long enough to hide the server's step rate. Cache `home` per bay at bind time: it is the pivot when the attribute is 0, and re-deriving it from the current pivot accumulates error.

- [ ] **Step 4: OWNER GATE.** In Play: hold a prompt on an M or L teahouse, slide a screen the length of the wall, stack a run into one bay, walk through the opening, and check a second client sees the same positions. Ask the owner for one look at prompt density on the L (14 shoji bays) — the fallback, if it is noisy, is one prompt per run rather than per bay.

- [ ] **Step 5: Commit** — `feat(roblox): shoji prompts and the slide tween`.

---

### Task 7: Close item 5

**Files:**
- Modify: `docs/wiki/world/teahouses.md`, `docs/wiki/program/friends-family-baseline.md`, `docs/wiki/log.md`

- [ ] **Step 1:** Record on [[teahouses]]: the channel geometry (groove pitch, the L's proud sill), hold-to-slide, owner-persists/visitor-does-not, the N−1 rule, and that the variant slot was already wired end to end with placeholder art. Move item 5 to closed on the baseline board with the owner's gate date. Append a `## [date] ship | shoji screens` entry to the log.
- [ ] **Step 2:** `node tools/wiki/lint.mjs` → 0 errors. Full Luau suite, `stylua --check src tests tools`, `selene src tools`, and the server suite once more.
- [ ] **Step 3:** Commit `docs(wiki): item 5 closed — sliding shoji`, and remind the owner to **save the place** (prefab channels are place-only).

---

## Self-Review

**Spec coverage.** §2 → Task 1. §2.1 → Task 3. §3 → Tasks 4 and 6. §4 → Tasks 5 and 6. §5 → Tasks 2, 4 and 5. §6 (the variant slot) → **not covered by a task**, deliberately: the spec's §6 asks for one test proving the slot resolves, and that belongs with the catalog work rather than in a plan about motion. It is called out here so its absence is a decision rather than a gap.

**Placeholder scan.** No TBDs. Every code step carries real code or, where the file is Roblox-runtime and untestable, an exact list of what it must do and which existing file it copies its shape from.

**Type consistency.** `ShojiRun.clamp(index, count, open)` is called with that argument order in Tasks 4 and 5; `grooveOffset(index, count)` likewise in Task 3; `displacement(open)` in Tasks 4 and 6; `directionFrom(open)` in Task 5. `shojiOpen` is a per-side map of arrays in the validator (Task 2), in `resolve` (Task 1) and in the persist step (Task 5). Every interface a later task calls is defined and tested in Task 1 — `directionFrom` was drafted into Task 5 and moved here on review, because a rule the handler owns privately is a rule nothing can test.
