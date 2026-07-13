# B1 Player Back Door Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a player add/move/remove a single back door on the teahouse they currently occupy — live re-rendered and persisted to that size's loadout — driving SP1's dormant modular-bay machinery in production.

**Architecture:** Server-authoritative, mirroring the existing favoriting flow. A pure `BackDoorEditor` (Lune-tested) computes the new `wallBays` map; the Roblox server validates occupancy/range, re-applies `StructureOps.applyBays` to the already-materialized `Structure` (variants are hidden not destroyed, so no rebuild), persists via a new `NetworkClient.setTeahouse` PUT, and echoes state; a client controller places per-bay ProximityPrompts on the occupant's own back wall. The Node server's `validateLoadout` gains a `wallBays` whitelist + `validateWallBays` (the deferred SP1 gate).

**Tech Stack:** Luau (Rojo/Lune) for the Roblox client+server; TypeScript/Express/Vitest for the Node server; ProximityPrompt + RemoteEvents for the interaction.

## Global Constraints

- **Commit footer (verbatim on every commit):**
  ```
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ
  ```
- **Server-authoritative:** the client only *requests*; the server validates, re-renders, and persists. Never trust the client for pad/size — derive them from the server-side occupancy stash.
- **Occupant-only:** the edit applies only to the teahouse the firing player currently occupies. A player with no active claim is ignored.
- **Per-size:** the edit persists to the currently-occupied size's loadout only (owning both M and L, editing L never touches M).
- **Back-wall-only (v1):** only `back` bays. Front/side doors are out of scope.
- **One door slot:** at most one `back` bay is `door`. Setting a new bay moves the door; re-selecting the active bay removes it.
- **Free:** no points cost.
- **Side names** (from `Bay_<side>_<index>` model names): `front`, `back`, `left`, `right`. The back wall has 3 bays (`Bay_back_1..3`); derive the count from the manifest, do not hardcode it in the handler.
- **`wallBays` lists are dense arrays** of `solid | shoji | door` (JSON-array-safe, never sparse/objects).
- **F2/F4 (non-fatal):** a bad request, a streaming/rebuild race, a missing bay/variant, or a failed persist must warn-and-continue — never error out of the join/round loop. A failed persist keeps the live door for the session (lost next join); no revert.
- **Reuse `PUT /api/v1/players/:id/teahouses/:sizeClass`** (whole-loadout replace) — no new REST endpoint.
- **Luau conventions:** pure shared modules are Lune-tested and use relative `require("./X")` only for types; Roblox-runtime files (`main.server.luau`, `*.client.luau`) are dependency-wired and proven by the visual gate, not Lune tests.

---

## File Structure

- **Create** `roblox/src/shared/BackDoorEditor.luau` — pure one-door-slot logic (`setBackDoor`, `backDoorIndex`).
- **Create** `roblox/tests/BackDoorEditor.spec.luau` — Lune tests for the above.
- **Create** `roblox/src/client/BackDoorController.client.luau` — per-bay prompts on the occupant's back wall; fires `SetBackDoor`; relabels from `BackDoorState`.
- **Modify** `server/src/loadout.ts` — add `wallBays` to `LOADOUT_KEYS`; add + export `validateWallBays` and its caps; call it from `validateLoadout`.
- **Modify** `server/src/loadout.test.ts` — tests for `validateWallBays` and `wallBays` inside `validateLoadout`.
- **Modify** `roblox/src/server/NetworkClient.luau` — add `setTeahouse(uid, sizeClass, loadout)`.
- **Modify** `roblox/tests/NetworkClient.spec.luau` — test for `setTeahouse`.
- **Modify** `roblox/default.project.json` — declare `SetBackDoor` + `BackDoorState` RemoteEvents.
- **Modify** `roblox/src/server/main.server.luau` — require `WallBays`+`BackDoorEditor`; wire the two remotes; add the occupancy stash; `SetBackDoor` handler; `BackDoorState` echo on claim.

Task order: 1 (Node validation) → 2 (`BackDoorEditor`) → 3 (`NetworkClient.setTeahouse`) → 4 (server wiring, declares remotes) → 5 (client controller + end-to-end visual gate). Tasks 1–3 are independent and fully unit-tested; 4–5 are Roblox-runtime glue proven by lint/analyze + the visual gate.

---

### Task 1: Node `validateWallBays` + loadout whitelist

**Files:**
- Modify: `server/src/loadout.ts`
- Test: `server/src/loadout.test.ts`

**Interfaces:**
- Consumes: existing `Check` type, `validateLoadout` in `server/src/loadout.ts`.
- Produces: `export function validateWallBays(value: unknown): Check`; `export const KNOWN_SIDES`, `WALLBAY_STATES`, `MAX_BAYS_PER_SIDE`. `validateLoadout` now accepts a loadout carrying a valid `wallBays` and rejects an invalid one (error `BAD_WALLBAYS`).

- [ ] **Step 1: Write the failing tests**

Add to `server/src/loadout.test.ts` — extend the import on line 2 and append two blocks:

```ts
// line 2 becomes:
import {
    validateLoadout,
    validateSizeClass,
    validatePadPreferences,
    validateWallBays,
    MAX_CLASSES,
    MAX_BAYS_PER_SIDE,
} from './loadout';
```

```ts
describe('validateWallBays', () => {
    it('accepts an empty map and valid dense side lists', () => {
        expect(validateWallBays({}).ok).toBe(true);
        expect(validateWallBays({ back: ['solid', 'door', 'solid'], front: ['shoji'] }).ok).toBe(true);
    });
    it('rejects non-objects', () => {
        expect(validateWallBays(null).ok).toBe(false);
        expect(validateWallBays(['solid']).ok).toBe(false);
        expect(validateWallBays('back').ok).toBe(false);
    });
    it('rejects an unknown side key', () => {
        expect(validateWallBays({ roof: ['solid'] }).ok).toBe(false);
    });
    it('rejects a non-array side value', () => {
        expect(validateWallBays({ back: 'door' }).ok).toBe(false);
    });
    it('rejects an unknown bay state', () => {
        expect(validateWallBays({ back: ['window'] }).ok).toBe(false);
    });
    it('rejects an over-length side list', () => {
        expect(validateWallBays({ back: Array(MAX_BAYS_PER_SIDE + 1).fill('solid') }).ok).toBe(false);
    });
});

describe('validateLoadout wallBays', () => {
    it('accepts a loadout carrying a valid wallBays', () => {
        expect(validateLoadout({ baseStyle: 't', wallBays: { back: ['solid', 'door', 'solid'] } }).ok).toBe(true);
    });
    it('rejects a loadout with an invalid wallBays', () => {
        expect(validateLoadout({ baseStyle: 't', wallBays: { back: ['trapdoor'] } }).ok).toBe(false);
    });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd server && npx vitest run src/loadout.test.ts`
Expected: FAIL — `validateWallBays` is not exported (import error / undefined), and `validateLoadout({... wallBays ...})` currently returns `ok:false` via `UNKNOWN_KEY` so the "accepts" case fails.

- [ ] **Step 3: Implement**

In `server/src/loadout.ts`, add the constants + validator (place after the `LOADOUT_KEYS` line and before `validateLoadout`), and add `'wallBays'` to `LOADOUT_KEYS`:

```ts
const LOADOUT_KEYS = new Set(['baseStyle', 'colorScheme', 'shoji', 'tatami', 'flags', 'wallArt', 'wallBays']);

export const KNOWN_SIDES = new Set(['front', 'back', 'left', 'right']);
export const WALLBAY_STATES = new Set(['solid', 'shoji', 'door']);
export const MAX_BAYS_PER_SIDE = 8;

export function validateWallBays(value: unknown): Check {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
        return { ok: false, error: 'BAD_WALLBAYS' };
    }
    for (const [side, states] of Object.entries(value as Record<string, unknown>)) {
        if (!KNOWN_SIDES.has(side)) return { ok: false, error: 'BAD_WALLBAYS' };
        if (!Array.isArray(states) || states.length > MAX_BAYS_PER_SIDE) {
            return { ok: false, error: 'BAD_WALLBAYS' };
        }
        for (const s of states) {
            if (typeof s !== 'string' || !WALLBAY_STATES.has(s)) {
                return { ok: false, error: 'BAD_WALLBAYS' };
            }
        }
    }
    return { ok: true };
}
```

In `validateLoadout`, insert the `wallBays` check between the `UNKNOWN_KEY` loop and the `byteLength` check:

```ts
    for (const k of Object.keys(obj)) {
        if (!LOADOUT_KEYS.has(k)) return { ok: false, error: 'UNKNOWN_KEY' };
    }
    if (obj.wallBays !== undefined) {
        const wb = validateWallBays(obj.wallBays);
        if (!wb.ok) return wb;
    }
    if (Buffer.byteLength(JSON.stringify(obj), 'utf8') > MAX_LOADOUT_BYTES) {
        return { ok: false, error: 'LOADOUT_TOO_LARGE' };
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd server && npx vitest run src/loadout.test.ts`
Expected: PASS (all `validateWallBays` + `validateLoadout wallBays` cases green, existing cases still green).

- [ ] **Step 5: Commit**

```bash
git add server/src/loadout.ts server/src/loadout.test.ts
git commit -m "feat(server): whitelist + validate loadout.wallBays (B1)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ"
```

---

### Task 2: `BackDoorEditor` pure module

**Files:**
- Create: `roblox/src/shared/BackDoorEditor.luau`
- Test: `roblox/tests/BackDoorEditor.spec.luau`

**Interfaces:**
- Consumes: nothing (self-contained; inlines its own `Map` type `{ [string]: { string } }`, structurally identical to `WallBays.Map`).
- Produces:
  - `BackDoorEditor.setBackDoor(wallBays: Map?, index: number?, backBayCount: number): Map` — returns a NEW map with a dense `back` list carrying one `door` at `index` (others `solid`), or with `back` dropped when `index` is nil / out of `1..backBayCount` / equal to the current door bay (toggle-off). Other sides pass through unchanged; input is not mutated.
  - `BackDoorEditor.backDoorIndex(wallBays: Map?): number?` — the 1-based index of the back `door` bay, or nil.

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/BackDoorEditor.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local BackDoorEditor = require("../src/shared/BackDoorEditor")
local describe, test, expect = harness.describe, harness.test, harness.expect
local set = BackDoorEditor.setBackDoor
local idx = BackDoorEditor.backDoorIndex

describe("BackDoorEditor.setBackDoor", function()
    test("sets a dense back list with the door at the chosen index", function()
        local out = set(nil, 2, 3)
        expect(#out.back).toBe(3)
        expect(out.back[1]).toBe("solid")
        expect(out.back[2]).toBe("door")
        expect(out.back[3]).toBe("solid")
    end)

    test("moves the door when a different index is chosen", function()
        local a = set(nil, 1, 3)
        local b = set(a, 3, 3)
        expect(b.back[1]).toBe("solid")
        expect(b.back[3]).toBe("door")
        expect(idx(b)).toBe(3)
    end)

    test("toggles off when the active index is re-chosen (drops back)", function()
        local a = set(nil, 2, 3)
        local b = set(a, 2, 3)
        expect(b.back == nil).toBe(true)
        expect(idx(b) == nil).toBe(true)
    end)

    test("clears when index is nil", function()
        local a = set(nil, 2, 3)
        local b = set(a, nil, 3)
        expect(b.back == nil).toBe(true)
    end)

    test("out-of-range index yields no back door", function()
        expect(set(nil, 0, 3).back == nil).toBe(true)
        expect(set(nil, 4, 3).back == nil).toBe(true)
    end)

    test("passes other sides through unchanged and does not mutate input", function()
        local input = { front = { "shoji", "shoji" } }
        local out = set(input, 1, 3)
        expect(out.front[1]).toBe("shoji")
        expect(out.front[2]).toBe("shoji")
        expect(out.back[1]).toBe("door")
        expect(input.back == nil).toBe(true) -- input untouched
        expect(#input.front).toBe(2)
    end)
end)

describe("BackDoorEditor.backDoorIndex", function()
    test("nil map / nil back / no door -> nil", function()
        expect(idx(nil) == nil).toBe(true)
        expect(idx({}) == nil).toBe(true)
        expect(idx({ back = { "solid", "solid" } }) == nil).toBe(true)
    end)

    test("finds the door index", function()
        expect(idx({ back = { "solid", "door", "solid" } })).toBe(2)
    end)
end)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `require("../src/shared/BackDoorEditor")` errors (module does not exist).

- [ ] **Step 3: Implement**

Create `roblox/src/shared/BackDoorEditor.luau`:

```lua
--!strict
-- Pure one-door-slot logic for the modular back wall. A teahouse's back wall carries at most
-- one `door` bay; setBackDoor sets / moves / clears it and returns a NEW wallBays map with a
-- DENSE back list (JSON-array-safe). backDoorIndex reads the current back door bay. No Roblox
-- datatypes -> Lune-tested. Mirrors PreferenceEditor. The Map type is structurally WallBays.Map.
local BackDoorEditor = {}

export type Map = { [string]: { string } }

-- the 1-based index of the back wall's `door` bay, or nil if none.
function BackDoorEditor.backDoorIndex(wallBays: Map?): number?
    if wallBays == nil then
        return nil
    end
    local back = wallBays.back
    if back == nil then
        return nil
    end
    for i, state in back do
        if state == "door" then
            return i
        end
    end
    return nil
end

-- Return a NEW map whose back wall has a single `door` at `index` (all other back bays `solid`),
-- or NO back door when `index` is nil, out of 1..backBayCount, or equal to the bay that is ALREADY
-- the door (toggle-off). Clearing drops the `back` key entirely so WallBays.resolve falls back to
-- the all-solid default. Other sides are deep-copied through unchanged; the input is not mutated.
function BackDoorEditor.setBackDoor(wallBays: Map?, index: number?, backBayCount: number): Map
    local out: Map = {}
    if wallBays ~= nil then
        for side, states in wallBays do
            if side ~= "back" then
                local copy = {}
                for i, s in states do
                    copy[i] = s
                end
                out[side] = copy
            end
        end
    end
    local current = BackDoorEditor.backDoorIndex(wallBays)
    local keep = false
    if index ~= nil and index >= 1 and index <= backBayCount and index ~= current then
        keep = true
    end
    if keep then
        local back = {}
        for i = 1, backBayCount do
            back[i] = if i == index then "door" else "solid"
        end
        out.back = back
    end
    return out
end

return BackDoorEditor
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS — the `BackDoorEditor` describe blocks green; all other specs still green.

- [ ] **Step 5: Lint**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: no output (clean). If stylua reports formatting, run `stylua src tests` then re-check.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/BackDoorEditor.luau roblox/tests/BackDoorEditor.spec.luau
git commit -m "feat(roblox): BackDoorEditor pure one-door-slot logic (B1)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ"
```

---

### Task 3: `NetworkClient.setTeahouse`

**Files:**
- Modify: `roblox/src/server/NetworkClient.luau:132-138` (add after `setPreferences`)
- Test: `roblox/tests/NetworkClient.spec.luau` (append a describe block)

**Interfaces:**
- Consumes: the existing `NetworkClient._request(self, method, path, bodyTable?)` → `Result`.
- Produces: `NetworkClient.setTeahouse(self, robloxUserId: string, sizeClass: string, loadout: any): Result` — `PUT /api/v1/players/{robloxUserId}/teahouses/{sizeClass}` with body `{ loadout = loadout }`.

- [ ] **Step 1: Write the failing test**

Append to `roblox/tests/NetworkClient.spec.luau` (before the final EOF), mirroring the `setPreferences` block:

```lua
describe("NetworkClient.setTeahouse", function()
    test("PUTs the loadout to the per-size teahouse path and returns the echo", function()
        local f = makeDeps({
            {
                ok = true,
                statusCode = 200,
                body = '{"sizeClass":"L","loadout":{"baseStyle":"teahouse-1story"}}',
            },
        })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:setTeahouse("9", "L", { baseStyle = "teahouse-1story", wallBays = { back = { "solid", "door", "solid" } } })
        expect(res.ok).toBe(true)
        expect(res.data.sizeClass).toBe("L")
        expect(f.calls[1].method).toBe("PUT")
        expect(f.calls[1].url).toBe("http://x/api/v1/players/9/teahouses/L")
        local sent = serde.decode("json", f.calls[1].body :: string)
        expect(sent.loadout.baseStyle).toBe("teahouse-1story")
        expect(sent.loadout.wallBays.back[2]).toBe("door")
    end)

    test("surfaces a 400 fail-fast", function()
        local f = makeDeps({ { ok = true, statusCode = 400, body = '{"error":"BAD_WALLBAYS"}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:setTeahouse("9", "L", { baseStyle = "t" })
        expect(res.ok).toBe(false)
        expect(res.error).toBe("BAD_WALLBAYS")
        expect(#f.calls).toBe(1)
    end)
end)
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `net:setTeahouse` is nil (attempt to call a nil value).

- [ ] **Step 3: Implement**

In `roblox/src/server/NetworkClient.luau`, add after `setPreferences` (after line 138, before `return NetworkClient`):

```lua
function NetworkClient.setTeahouse(self: any, robloxUserId: string, sizeClass: string, loadout: any): Result
    return self:_request(
        "PUT",
        `/api/v1/players/{robloxUserId}/teahouses/{sizeClass}`,
        { loadout = loadout }
    )
end
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `cd roblox && lune run tests/run`
Expected: PASS — the `setTeahouse` block green; all other specs still green.

- [ ] **Step 5: Lint**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/server/NetworkClient.luau roblox/tests/NetworkClient.spec.luau
git commit -m "feat(roblox): NetworkClient.setTeahouse PUT (B1)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ"
```

---

### Task 4: Server wiring — remotes, occupancy stash, `SetBackDoor` handler, `BackDoorState` echo

**Files:**
- Modify: `roblox/default.project.json:11-22` (add two RemoteEvents to `RoshamboRemotes`)
- Modify: `roblox/src/server/main.server.luau` (requires at 11-30; claim/leave at 412-450; new handler after 477)

**Interfaces:**
- Consumes: `BackDoorEditor.setBackDoor` / `.backDoorIndex` (Task 2); `NetworkClient.setTeahouse` (Task 3); existing `StructureOps.readManifest`/`applyBays`, `WallBays.resolve`, the `sitesFolder` container, the `action` returned by `SiteCoordinator:onJoin` (`{ padId, teahouse = { size, loadout } }`).
- Produces: `SetBackDoor` (RemoteEvent, client→server, payload `{ bayIndex: number }`) and `BackDoorState` (RemoteEvent, server→client, payload `{ padId: string, backDoorIndex: number? }`), fired to the owner on claim and after each successful edit.

This file is Roblox-runtime (not Lune-testable), consistent with `SetPadPreference`'s handler having no unit test. Verification is lint/analyze + the visual gate in Task 5.

- [ ] **Step 1: Declare the remotes**

In `roblox/default.project.json`, add two entries to `RoshamboRemotes` (after `PreferenceState` on line 22 — add a comma to that line):

```json
                "SetPadPreference": { "$className": "RemoteEvent" },
                "PreferenceState": { "$className": "RemoteEvent" },
                "SetBackDoor": { "$className": "RemoteEvent" },
                "BackDoorState": { "$className": "RemoteEvent" }
```

- [ ] **Step 2: Require the new modules + remotes**

In `roblox/src/server/main.server.luau`, after line 18 (`PreferenceEditor = require(...)`), add:

```lua
local BackDoorEditor = require(shared:WaitForChild("BackDoorEditor"))
local WallBays = require(shared:WaitForChild("WallBays"))
```

After line 30 (`PreferenceState = ...`), add:

```lua
local SetBackDoor = remotes:WaitForChild("SetBackDoor") :: RemoteEvent
local BackDoorState = remotes:WaitForChild("BackDoorState") :: RemoteEvent
```

- [ ] **Step 3: Add the occupancy stash + claim echo**

After the `playerPrefs` declaration (line 378), add the house stash:

```lua
-- The teahouse each player currently occupies, for occupant-gated live edits (B1 back door):
-- padId + the occupied SIZE + that size's loadout (the merge target for wallBays edits).
local playerHouse: { [string]: { padId: string, size: string, loadout: any } } = {}
```

In `PlayerAdded` (the claim success block), replace lines 433-435:

```lua
            applier:apply(action.padId, action.spec, action.treatment, action.deckSize, action.teahouse)
            local tsize = action.teahouse and action.teahouse.size or "bare"
            print(`[D.5] {player.UserId} claimed {action.padId} deck={action.deckSize} teahouse={tsize}`)
```

with (stash the house + echo initial back-door state when a teahouse was built):

```lua
            applier:apply(action.padId, action.spec, action.treatment, action.deckSize, action.teahouse)
            local tsize = action.teahouse and action.teahouse.size or "bare"
            print(`[D.5] {player.UserId} claimed {action.padId} deck={action.deckSize} teahouse={tsize}`)
            if action.teahouse ~= nil and action.teahouse.loadout ~= nil then
                playerHouse[uid] = {
                    padId = action.padId,
                    size = action.teahouse.size,
                    loadout = action.teahouse.loadout,
                }
                if player:IsDescendantOf(Players) then
                    BackDoorState:FireClient(player, {
                        padId = action.padId,
                        backDoorIndex = BackDoorEditor.backDoorIndex(action.teahouse.loadout.wallBays),
                    })
                end
            end
```

In the early-leave cleanup inside `PlayerAdded` (line 430, next to `playerPrefs[uid] = nil`), also clear the stash:

```lua
                playerPrefs[uid] = nil
                playerHouse[uid] = nil
```

In `PlayerRemoving` (line 444, next to `playerPrefs[...] = nil`), clear the stash:

```lua
    playerPrefs[tostring(player.UserId)] = nil
    playerHouse[tostring(player.UserId)] = nil
```

- [ ] **Step 4: Add the `SetBackDoor` handler**

After the `SetPadPreference.OnServerEvent` block (after line 477), add:

```lua
SetBackDoor.OnServerEvent:Connect(function(player, payload)
    local uid = tostring(player.UserId)
    local house = playerHouse[uid]
    if house == nil then
        return -- not occupying a teahouse this session; ignore (occupant-only)
    end
    -- find the live, already-materialized structure to read its back-bay count + re-render
    local siteFolder = sitesFolder:FindFirstChild("MaterializedSite_" .. house.padId)
    local structure = siteFolder and siteFolder:FindFirstChild("Structure")
    if structure == nil then
        return -- streaming / rebuild race: nothing to re-render (F2/F4)
    end
    local manifest = StructureOps.readManifest(structure)
    local backBayCount = 0
    for _, bay in manifest.bays do
        if bay.side == "back" then
            backBayCount += 1
        end
    end
    local bayIndex = if typeof(payload) == "table" then payload.bayIndex else nil
    if typeof(bayIndex) ~= "number" or bayIndex < 1 or bayIndex > backBayCount then
        return -- ill-typed / out-of-range request
    end
    local newWallBays = BackDoorEditor.setBackDoor(house.loadout.wallBays, bayIndex, backBayCount)
    -- merge into a NEW copy of the occupied size's loadout (don't alias the stash pre-persist)
    local newLoadout = {}
    for k, v in house.loadout do
        newLoadout[k] = v
    end
    newLoadout.wallBays = newWallBays
    -- live, server-authoritative re-render (replicates to every client)
    StructureOps.applyBays(structure, WallBays.resolve(manifest.bays, newWallBays))
    house.loadout = newLoadout
    -- best-effort persist: a failure keeps the live door this session (lost next join), no revert
    local persisted = net:setTeahouse(uid, house.size, newLoadout)
    if not persisted.ok then
        warn(`[B1] setTeahouse failed for {uid}/{house.size}: {tostring(persisted.error)}`)
    end
    if player:IsDescendantOf(Players) then
        BackDoorState:FireClient(player, {
            padId = house.padId,
            backDoorIndex = BackDoorEditor.backDoorIndex(newWallBays),
        })
    end
end)
```

- [ ] **Step 5: Lint + analyze**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean. (If `stylua --check` complains, run `stylua src tests` then re-check.)

- [ ] **Step 6: Run the Luau suite (nothing should regress)**

Run: `cd roblox && lune run tests/run`
Expected: PASS — no existing spec regresses (this task adds no new spec; `main.server.luau` is runtime-only).

- [ ] **Step 7: Commit**

```bash
git add roblox/default.project.json roblox/src/server/main.server.luau
git commit -m "feat(roblox): server back-door handler + remotes + occupancy stash (B1)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ"
```

---

### Task 5: Client `BackDoorController` + end-to-end visual gate

**Files:**
- Create: `roblox/src/client/BackDoorController.client.luau`

**Interfaces:**
- Consumes: `SetBackDoor` (fires `{ bayIndex }`) and `BackDoorState` (receives `{ padId, backDoorIndex }`) from Task 4; `workspace.TeahouseSites.MaterializedSite_<padId>.Structure` with direct-child `Bay_back_<i>` models.
- Produces: nothing consumed by later tasks (this is the leaf).

Auto-runs as a LocalScript (`src/client` → `StarterPlayerScripts.RoshamboClient`). Roblox-runtime; verified by lint + the visual gate below.

- [ ] **Step 1: Implement the controller**

Create `roblox/src/client/BackDoorController.client.luau`:

```lua
--!strict
-- Per-player back-door editor. When the server assigns this player a teahouse (BackDoorState),
-- puts a ProximityPrompt on each of that teahouse's back bays (Bay_back_<i>). Triggering a bay
-- asks the server to make it the single back door (or, on the active bay, to remove it). The
-- door re-renders SERVER-side; this only fires the request and relabels prompts from the echoed
-- backDoorIndex. Only ever runs for the local player's own occupied teahouse (BackDoorState is
-- fired to that player alone).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local SetBackDoor = remotes:WaitForChild("SetBackDoor") :: RemoteEvent
local BackDoorState = remotes:WaitForChild("BackDoorState") :: RemoteEvent

local MAKE_LABEL = "Add a door here"
local REMOVE_LABEL = "Remove this door"

local prompts: { [number]: ProximityPrompt } = {} -- bayIndex -> its prompt
local activeIndex: number? = nil

local function relabel()
    for i, prompt in prompts do
        prompt.ActionText = if i == activeIndex then REMOVE_LABEL else MAKE_LABEL
    end
end

local function anchorPart(bay: Instance): BasePart?
    if bay:IsA("Model") and bay.PrimaryPart then
        return bay.PrimaryPart
    end
    return bay:FindFirstChildWhichIsA("BasePart", true)
end

-- Create one prompt per back bay (deduped), then relabel to the current active door.
local function bindBays(structure: Instance)
    for _, child in structure:GetChildren() do
        local idxStr = child.Name:match("^Bay_back_(%d+)$")
        if idxStr then
            local i = tonumber(idxStr) :: number
            if prompts[i] == nil then
                local anchor = anchorPart(child)
                if anchor then
                    local prompt = Instance.new("ProximityPrompt")
                    prompt.ActionText = MAKE_LABEL
                    prompt.ObjectText = "Back wall"
                    prompt.KeyboardKeyCode = Enum.KeyCode.E
                    prompt.MaxActivationDistance = 12
                    prompt.RequiresLineOfSight = false
                    prompt.Parent = anchor
                    prompt.Triggered:Connect(function()
                        SetBackDoor:FireServer({ bayIndex = i })
                    end)
                    prompts[i] = prompt
                end
            end
        end
    end
    relabel()
end

BackDoorState.OnClientEvent:Connect(function(payload)
    if typeof(payload) ~= "table" or typeof(payload.padId) ~= "string" then
        return
    end
    activeIndex = payload.backDoorIndex
    -- The structure is materialized server-side and replicating; wait (bounded) for it. Use
    -- WaitForChild, not FindFirstChild, to survive the async-replication startup race.
    local sitesFolder = workspace:WaitForChild("TeahouseSites")
    local siteFolder = sitesFolder:WaitForChild("MaterializedSite_" .. payload.padId, 15)
    local structure = siteFolder and siteFolder:WaitForChild("Structure", 15)
    if structure then
        bindBays(structure)
    else
        relabel()
    end
end)
```

- [ ] **Step 2: Lint**

Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.

- [ ] **Step 3: Run the Luau suite (no regressions)**

Run: `cd roblox && lune run tests/run`
Expected: PASS — no existing spec regresses.

- [ ] **Step 4: Visual gate (manual, in Studio — end-to-end proof of Tasks 4+5)**

Sync with Rojo (`cd roblox && rojo serve`, connect in Studio) and Play. Verify, one attempt then STOP and ask the user to confirm (per the stop-and-ask working rule):

1. **Own teahouse only:** spawn as an owner (a `User.teahouses` entry exists for your `robloxId`). ProximityPrompts appear on your teahouse's 3 back bays; a *second* player's teahouse shows none on its back wall for you.
2. **Add a door:** trigger a back bay's prompt (`E`). That bay's wall opens to a door **immediately** (live); the prompt relabels to "Remove this door". Walk through the opening onto the back of the deck.
3. **Move the door:** trigger a different back bay. The door moves there; the previously-doored bay returns to a solid wall; only one door at a time.
4. **Remove the door:** trigger the active door bay again. The wall returns to solid; prompt relabels to "Add a door here".
5. **Persistence:** with a door set, leave and rejoin (or rerun). On respawn onto that perch at that size, the door is present from the start (persisted `wallBays`).

- [ ] **Step 5: Commit**

```bash
git add roblox/src/client/BackDoorController.client.luau
git commit -m "feat(roblox): BackDoorController client back-wall prompts (B1)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
Claude-Session: https://claude.ai/code/session_01V59ArCLfybKvRQMH6x4ZCQ"
```

---

## Notes for the executor

- **Do not commit** `SecretsLocal.luau`, `server/.env`, Atlas credentials, or API keys. Never insert/require asset id `139590959377658`.
- **Place-only geometry** persists only when the *user* saves the place — the visual gate (Task 5, Step 4) is a user-confirmed check; make one attempt, then stop and ask the user to look.
- The visual gate needs a player whose server `User.teahouses` has at least one size entry for their `robloxId`. If none exists, seed one with `PUT /api/v1/players/:robloxUserId/teahouses/:sizeClass` (body `{ "loadout": { "baseStyle": "teahouse-1story" } }`) before testing — this is also the first real exercise of the newly-whitelisted `wallBays` path.
