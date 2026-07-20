# Teahouse Access Control Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a teahouse owner set who may enter their deck (Public / Friends / Private + invite list) and enforce it physically with client-rendered themed gates plus a server region-gate backstop.

**Architecture:** A per-player access policy persisted on the backend by userId; the Roblox server resolves usernames↔ids and friendship, computes each viewer's blocked-pad set, and pushes it out; each client raises client-local collidable gates only where it's blocked; a server region loop teleports back anyone disallowed who slips through. Pure `AccessPolicy.canEnter` and `AccessGates` geometry are Lune-tested; the backend never sees usernames.

**Tech Stack:** Express + Mongoose + Vitest (backend TS); Luau + Rojo + bespoke Lune harness (Roblox); dependency-injected pure modules Lune-tested against real data.

## Global Constraints

- **3-way mode, Public default:** `mode ∈ {'public','friends','private'}`; default `{ mode: 'public', invited: [] }`. The world starts open; a gate exists only around a currently-occupied deck whose owner's mode blocks the viewer.
- **`invited` is a list of Roblox userIds (numbers), never usernames**, unique, length ≤ `MAX_INVITED` (= 50). The backend server validates/stores only numeric ids; username↔id and id→name resolution happen on the **Roblox server**.
- **Owner is always allowed** (`viewerId == ownerId` → can enter); the owner can't self-lock or self-invite.
- **Enforcement is per-client-local** (each client only answers "is this gate solid to me?" — no collision groups) **plus a server backstop** (`PivotTo` teleport-back). Both use geometry derived from `(deckCF, deckSize)`; the privacy gate is TALL enough to seal (distinct from the deliberately-low fall-guard) and is only ever built for a *blocked* viewer.
- **Access only applies to a lit/occupied deck** (owner present). Portal-in is unaffected (it lands you on your own deck → owner → allowed).
- **Deck-local orientation** (per `TreatmentApplier`): `-Z` = front/view, `+Z` = back/access (the open edge), `±X` = side railings. `SizeClasses.deckFootprint(deckSize)` is symmetric (`minX = -maxX`, `minZ = -maxZ`).
- **CFrames as 12-number row-major arrays; sizes as 3-number arrays** in every pure Luau module (no Roblox datatypes → Lune-testable).
- **Tests:** backend `cd server && npm test` (Vitest); Roblox `cd roblox && lune run tests/run` (auto-discovers `*.spec.luau`); lint `cd roblox && stylua --check src tests && selene src`.
- **Every commit** ends with the two trailers:
  ```
  Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_01Vf1gZydECjVW7ot94YH3ho
  ```

---

## File structure

**Backend (TS):**
- `server/src/economy.ts` — MODIFY: `MAX_INVITED`, `AccessMode`, `ACCESS_MODES`, `TeahouseAccess`, `DEFAULT_ACCESS`.
- `server/src/loadout.ts` — MODIFY: `validateAccess`.
- `server/src/models/User.ts` — MODIFY: `teahouseAccess` field.
- `server/src/routes/apiV1.ts` — MODIFY: `GET /economy` field + `PUT /access`.
- `server/src/economy.test.ts` / `server/src/loadout.test.ts` — MODIFY: tests.

**Roblox pure (Lune-tested):**
- `roblox/src/shared/AccessPolicy.luau` — CREATE: `canEnter`.
- `roblox/src/shared/AccessGates.luau` — CREATE: `deckBackGate`, `evictionPoint`.
- `roblox/tests/AccessPolicy.spec.luau`, `roblox/tests/AccessGates.spec.luau` — CREATE.

**Roblox runtime (visual-gate-proven):**
- `roblox/default.project.json` — MODIFY: 5 new RemoteEvents.
- `roblox/src/server/NetworkClient.luau` — MODIFY: `setAccess`.
- `roblox/src/server/main.server.luau` — MODIFY: stash + echo access, compute/push engine, 3 handlers, backstop.
- `roblox/src/client/AccessGateController.client.luau` — CREATE.
- `roblox/src/client/TeahouseController.client.luau` — MODIFY: Access panel section.
- `roblox/src/server/PadSites.luau` — MODIFY (Task 10): `accessGates` per pad.
- `roblox/tools/studio/surveyAccessGates.luau` — CREATE (Task 10).

---

## Task 1: Backend access model + `validateAccess`

**Files:**
- Modify: `server/src/economy.ts`, `server/src/loadout.ts`
- Test: `server/src/economy.test.ts`, `server/src/loadout.test.ts`

**Interfaces:**
- Produces: `MAX_INVITED: number` (=50); `AccessMode = 'public'|'friends'|'private'`; `ACCESS_MODES: Set<string>`; `TeahouseAccess = { mode: AccessMode; invited: number[] }`; `DEFAULT_ACCESS: TeahouseAccess`; `validateAccess(value): { ok: true } | { ok: false; error: 'BAD_ACCESS' }`.

- [ ] **Step 1: Write the failing tests**

Append to `server/src/economy.test.ts`:

```typescript
import { MAX_INVITED, ACCESS_MODES, DEFAULT_ACCESS } from './economy';

describe('access constants', () => {
    it('MAX_INVITED is 50', () => {
        expect(MAX_INVITED).toBe(50);
    });
    it('ACCESS_MODES holds exactly the three modes', () => {
        expect([...ACCESS_MODES].sort()).toEqual(['friends', 'private', 'public']);
    });
    it('DEFAULT_ACCESS is public with an empty list', () => {
        expect(DEFAULT_ACCESS).toEqual({ mode: 'public', invited: [] });
    });
});
```

Append to `server/src/loadout.test.ts`:

```typescript
import { validateAccess } from './loadout';

describe('validateAccess', () => {
    it('accepts a well-formed public payload', () => {
        expect(validateAccess({ mode: 'public', invited: [] })).toEqual({ ok: true });
    });
    it('accepts a private payload with invited ids', () => {
        expect(validateAccess({ mode: 'private', invited: [1, 2, 3] })).toEqual({ ok: true });
    });
    it('accepts friends mode', () => {
        expect(validateAccess({ mode: 'friends', invited: [] })).toEqual({ ok: true });
    });
    it('rejects a non-object', () => {
        expect(validateAccess(null)).toEqual({ ok: false, error: 'BAD_ACCESS' });
        expect(validateAccess([])).toEqual({ ok: false, error: 'BAD_ACCESS' });
    });
    it('rejects an unknown mode', () => {
        expect(validateAccess({ mode: 'secret', invited: [] })).toEqual({ ok: false, error: 'BAD_ACCESS' });
    });
    it('rejects an extra key', () => {
        expect(validateAccess({ mode: 'public', invited: [], evil: 1 })).toEqual({ ok: false, error: 'BAD_ACCESS' });
    });
    it('rejects a non-array invited', () => {
        expect(validateAccess({ mode: 'public', invited: 'x' })).toEqual({ ok: false, error: 'BAD_ACCESS' });
    });
    it('rejects a non-positive or non-integer userId', () => {
        expect(validateAccess({ mode: 'private', invited: [0] })).toEqual({ ok: false, error: 'BAD_ACCESS' });
        expect(validateAccess({ mode: 'private', invited: [1.5] })).toEqual({ ok: false, error: 'BAD_ACCESS' });
        expect(validateAccess({ mode: 'private', invited: [-4] })).toEqual({ ok: false, error: 'BAD_ACCESS' });
    });
    it('rejects duplicate ids', () => {
        expect(validateAccess({ mode: 'private', invited: [7, 7] })).toEqual({ ok: false, error: 'BAD_ACCESS' });
    });
    it('rejects over the cap', () => {
        const many = Array.from({ length: 51 }, (_, i) => i + 1);
        expect(validateAccess({ mode: 'private', invited: many })).toEqual({ ok: false, error: 'BAD_ACCESS' });
    });
});
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd server && npx vitest run src/economy.test.ts src/loadout.test.ts`
Expected: FAIL — `MAX_INVITED`/`validateAccess` not exported.

- [ ] **Step 3: Implement in `server/src/economy.ts`**

Add (after `DECORATION_PROPS`):

```typescript
export const MAX_INVITED = 50;
export type AccessMode = 'public' | 'friends' | 'private';
export const ACCESS_MODES: Set<string> = new Set<string>(['public', 'friends', 'private']);
export type TeahouseAccess = { mode: AccessMode; invited: number[] };
export const DEFAULT_ACCESS: TeahouseAccess = { mode: 'public', invited: [] };
```

- [ ] **Step 4: Implement `validateAccess` in `server/src/loadout.ts`**

Extend the economy import at the top (it already imports `DECORATION_PROPS, MAX_DECORATIONS`):

```typescript
import { DECORATION_PROPS, MAX_DECORATIONS, ACCESS_MODES, MAX_INVITED } from './economy';
```

Add the validator:

```typescript
export function validateAccess(value: unknown): Check {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
        return { ok: false, error: 'BAD_ACCESS' };
    }
    const obj = value as Record<string, unknown>;
    for (const k of Object.keys(obj)) {
        if (k !== 'mode' && k !== 'invited') return { ok: false, error: 'BAD_ACCESS' };
    }
    if (typeof obj.mode !== 'string' || !ACCESS_MODES.has(obj.mode)) {
        return { ok: false, error: 'BAD_ACCESS' };
    }
    if (!Array.isArray(obj.invited) || obj.invited.length > MAX_INVITED) {
        return { ok: false, error: 'BAD_ACCESS' };
    }
    const seen = new Set<number>();
    for (const id of obj.invited) {
        if (typeof id !== 'number' || !Number.isInteger(id) || id < 1 || seen.has(id)) {
            return { ok: false, error: 'BAD_ACCESS' };
        }
        seen.add(id);
    }
    return { ok: true };
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd server && npx vitest run src/economy.test.ts src/loadout.test.ts`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add server/src/economy.ts server/src/loadout.ts server/src/economy.test.ts server/src/loadout.test.ts
git commit -m "feat(server): teahouse access model + validateAccess"
```

---

## Task 2: User schema + apiV1 access routes

**Files:**
- Modify: `server/src/models/User.ts`, `server/src/routes/apiV1.ts`

**Interfaces:**
- Consumes: `validateAccess` (Task 1), `DEFAULT_ACCESS` (Task 1).
- Produces: `user.teahouseAccess` persistence; `GET /economy` returns `teahouseAccess`; `PUT /players/:robloxUserId/access`.

> **No new unit-test file** — the repo has no route test suite. Verify with `cd server && npm test` (no regressions) + `cd server && npm run build` (type-checks). Both are the deliverable check.

- [ ] **Step 1: Add the schema field in `server/src/models/User.ts`**

Add to the `IUser` interface (after `deckDecorations`):

```typescript
    deckDecorations: { id: number; propId: string; offset: [number, number]; facing: 'N' | 'E' | 'S' | 'W' }[];
    teahouseAccess: { mode: 'public' | 'friends' | 'private'; invited: number[] };
    updatedAt: Date;
```

Add to the schema (after the `deckDecorations` line):

```typescript
    deckDecorations: { type: [Schema.Types.Mixed], default: [] },
    teahouseAccess: {
        type: { mode: { type: String, enum: ['public', 'friends', 'private'], default: 'public' }, invited: { type: [Number], default: [] } },
        default: () => ({ mode: 'public', invited: [] }),
    },
```

- [ ] **Step 2: Wire routes in `server/src/routes/apiV1.ts`**

Extend the imports:

```typescript
import {
    validatePurchase, applyPurchase, validateDisplay, PRICES, DEFAULT_TEAHOUSE_LOADOUT,
    Size, EconomyState, appendDecoration, DEFAULT_ACCESS,
} from '../economy';
import { validateLoadout, validateSizeClass, validatePadPreferences, validateDecorations, validateAccess } from '../loadout';
```

In `GET /players/:robloxUserId/economy`, add `teahouseAccess` to the response object (next to `deckDecorations`):

```typescript
                deckDecorations: user.deckDecorations ?? [],
                teahouseAccess: user.teahouseAccess ?? DEFAULT_ACCESS,
```

Add the new route (next to `PUT .../decorations`):

```typescript
    router.put('/players/:robloxUserId/access', async (req, res) => {
        try {
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            const access = req.body?.access;
            const check = validateAccess(access);
            if (!check.ok) { res.status(400).json({ error: check.error }); return; }
            user.teahouseAccess = access;
            await user.save();
            res.json({ teahouseAccess: user.teahouseAccess });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });
```

- [ ] **Step 3: Run the suite (no regressions)**

Run: `cd server && npm test`
Expected: PASS.

- [ ] **Step 4: Verify the build type-checks**

Run: `cd server && npm run build`
Expected: `tsc` completes with no errors.

- [ ] **Step 5: Commit**

```bash
git add server/src/models/User.ts server/src/routes/apiV1.ts
git commit -m "feat(server): persist teahouseAccess + PUT /access route"
```

---

## Task 3: `AccessPolicy.canEnter` (pure decision)

**Files:**
- Create: `roblox/src/shared/AccessPolicy.luau`
- Test: `roblox/tests/AccessPolicy.spec.luau`

**Interfaces:**
- Produces: `AccessPolicy.canEnter(mode: string, invited: { number }, viewerId: number, ownerId: number, isFriend: boolean): boolean`.

- [ ] **Step 1: Write the failing tests**

Create `roblox/tests/AccessPolicy.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local AccessPolicy = require("../src/shared/AccessPolicy")

describe("AccessPolicy.canEnter", function()
    test("owner always enters regardless of mode", function()
        expect(AccessPolicy.canEnter("private", {}, 10, 10, false)).toBe(true)
        expect(AccessPolicy.canEnter("friends", {}, 10, 10, false)).toBe(true)
    end)
    test("public lets anyone in", function()
        expect(AccessPolicy.canEnter("public", {}, 99, 10, false)).toBe(true)
    end)
    test("friends: only a friend (or owner) enters", function()
        expect(AccessPolicy.canEnter("friends", {}, 99, 10, true)).toBe(true)
        expect(AccessPolicy.canEnter("friends", {}, 99, 10, false)).toBe(false)
    end)
    test("private: only an invited id (or owner) enters", function()
        expect(AccessPolicy.canEnter("private", { 5, 99, 7 }, 99, 10, false)).toBe(true)
        expect(AccessPolicy.canEnter("private", { 5, 7 }, 99, 10, false)).toBe(false)
    end)
    test("private ignores friendship", function()
        expect(AccessPolicy.canEnter("private", {}, 99, 10, true)).toBe(false)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement `roblox/src/shared/AccessPolicy.luau`**

```lua
--!strict
-- Pure access decision for teahouse access control (2026-07-19). No Roblox datatypes -> Lune-tested.
-- isFriend is resolved on the Roblox server (viewer:IsFriendsWith(ownerId)) and passed in, so this
-- stays pure. The owner always passes their own gate.
local AccessPolicy = {}

function AccessPolicy.canEnter(
    mode: string,
    invited: { number },
    viewerId: number,
    ownerId: number,
    isFriend: boolean
): boolean
    if viewerId == ownerId then
        return true
    end
    if mode == "public" then
        return true
    elseif mode == "friends" then
        return isFriend
    elseif mode == "private" then
        for _, id in invited do
            if id == viewerId then
                return true
            end
        end
        return false
    end
    return false -- unknown mode: fail closed
end

return AccessPolicy
```

- [ ] **Step 4: Run to verify it passes + lint**

Run: `cd roblox && lune run tests/run`
Expected: PASS.
Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/AccessPolicy.luau roblox/tests/AccessPolicy.spec.luau
git commit -m "feat(roblox): AccessPolicy.canEnter pure decision"
```

---

## Task 4: `AccessGates` geometry (deck-back gate + eviction point)

**Files:**
- Create: `roblox/src/shared/AccessGates.luau`
- Test: `roblox/tests/AccessGates.spec.luau`

**Interfaces:**
- Consumes: `SizeClasses.deckFootprint(deckSize)` (existing) — `{ minX, maxX, minZ, maxZ }`.
- Produces:
  - `AccessGates.GATE_H`, `AccessGates.GATE_T`, `AccessGates.EVICT_OUT`, `AccessGates.EVICT_Y` (constants).
  - `AccessGates.deckBackGate(deckCF12: { number }, deckSize: string): { cframe: { number }, size: { number } }` — the wall spanning the deck's `+Z` back edge, deck rotation preserved. `cframe` = 12-number row-major array; `size` = `{ width, GATE_H, GATE_T }`.
  - `AccessGates.evictionPoint(deckCF12: { number }, deckSize: string): { number }` — a 12-number CFrame array just outside the back edge on the path side.

- [ ] **Step 1: Write the failing tests**

Create `roblox/tests/AccessGates.spec.luau`:

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local AccessGates = require("../src/shared/AccessGates")
local SizeClasses = require("../src/shared/SizeClasses")

-- identity deck at the world origin: deck-local axes == world axes
local IDENTITY = { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1 }

describe("AccessGates.deckBackGate", function()
    test("spans the full deck width at the +Z back edge", function()
        local fp = SizeClasses.deckFootprint("S")
        local g = AccessGates.deckBackGate(IDENTITY, "S")
        -- width = full deck width; thickness + height are the sealing wall
        expect(g.size[1]).toBeCloseTo(fp.maxX - fp.minX)
        expect(g.size[2]).toBeCloseTo(AccessGates.GATE_H)
        expect(g.size[3]).toBeCloseTo(AccessGates.GATE_T)
        -- centered on X, half-height up, at the back edge z = maxZ
        expect(g.cframe[1]).toBeCloseTo(0)
        expect(g.cframe[2]).toBeCloseTo(AccessGates.GATE_H / 2)
        expect(g.cframe[3]).toBeCloseTo(fp.maxZ)
    end)
    test("is tall enough to seal (well above a jump)", function()
        expect(AccessGates.GATE_H >= 10).toBe(true)
    end)
end)

describe("AccessGates.evictionPoint", function()
    test("sits outside the back edge on the path side (+Z), at standing height", function()
        local fp = SizeClasses.deckFootprint("S")
        local e = AccessGates.evictionPoint(IDENTITY, "S")
        expect(e[1]).toBeCloseTo(0)
        expect(e[2]).toBeCloseTo(AccessGates.EVICT_Y)
        expect(e[3]).toBeCloseTo(fp.maxZ + AccessGates.EVICT_OUT)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — module not found.

- [ ] **Step 3: Implement `roblox/src/shared/AccessGates.luau`**

```lua
--!strict
-- Pure gate geometry for teahouse access control (2026-07-19). Derives the deck-back privacy gate
-- and the eviction target from a deck's CFrame + size. No Roblox datatypes (12-number row-major
-- CFrame arrays, 3-number size arrays) -> Lune-tested. Composition mirrors PortalTarget.deckLanding:
-- world = deckPos + deckRot * localOffset, deck rotation preserved. Deck-local: -Z front/view, +Z
-- back/access (open edge). The gate is TALL (GATE_H) to seal -- distinct from the low fall-guard --
-- and is only ever built for a blocked viewer.
local SizeClasses = require("./SizeClasses")

local AccessGates = {}

AccessGates.GATE_H = 12 -- seal height (well above the ~7-stud jump)
AccessGates.GATE_T = 1 -- wall thickness
AccessGates.EVICT_OUT = 4 -- studs beyond the back edge, onto the path
AccessGates.EVICT_Y = 3 -- HRP standing height above the deck datum

-- compose a deck-local translation (ox,oy,oz) with the deck CFrame: rotate the offset by the deck's
-- rotation and add to the deck position; keep the deck rotation. Returns a 12-number array.
local function compose(deckCF12: { number }, ox: number, oy: number, oz: number): { number }
    local px, py, pz = deckCF12[1], deckCF12[2], deckCF12[3]
    local r00, r01, r02 = deckCF12[4], deckCF12[5], deckCF12[6]
    local r10, r11, r12 = deckCF12[7], deckCF12[8], deckCF12[9]
    local r20, r21, r22 = deckCF12[10], deckCF12[11], deckCF12[12]
    local wx = px + r00 * ox + r01 * oy + r02 * oz
    local wy = py + r10 * ox + r11 * oy + r12 * oz
    local wz = pz + r20 * ox + r21 * oy + r22 * oz
    return { wx, wy, wz, r00, r01, r02, r10, r11, r12, r20, r21, r22 }
end

function AccessGates.deckBackGate(deckCF12: { number }, deckSize: string): { cframe: { number }, size: { number } }
    local fp = SizeClasses.deckFootprint(deckSize)
    local width = fp.maxX - fp.minX
    -- centered on X, raised half-height, at the +Z back edge
    local cframe = compose(deckCF12, 0, AccessGates.GATE_H / 2, fp.maxZ)
    return { cframe = cframe, size = { width, AccessGates.GATE_H, AccessGates.GATE_T } }
end

function AccessGates.evictionPoint(deckCF12: { number }, deckSize: string): { number }
    local fp = SizeClasses.deckFootprint(deckSize)
    return compose(deckCF12, 0, AccessGates.EVICT_Y, fp.maxZ + AccessGates.EVICT_OUT)
end

return AccessGates
```

- [ ] **Step 4: Run to verify it passes + lint**

Run: `cd roblox && lune run tests/run`
Expected: PASS.
Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/AccessGates.luau roblox/tests/AccessGates.spec.luau
git commit -m "feat(roblox): AccessGates deck-back gate + eviction geometry"
```

---

## Task 5: Server — remotes, stash, and the blocked-set compute/push engine

**Files:**
- Modify: `roblox/default.project.json`, `roblox/src/server/NetworkClient.luau`, `roblox/src/server/main.server.luau`

**Interfaces:**
- Consumes: `AccessPolicy.canEnter` (Task 3), `AccessGates.deckBackGate` (Task 4), `SizeClasses.resolveBuilt`/`DeckPlacement.resolve` (existing), `PadSites` (existing).
- Produces:
  - 5 RemoteEvents: `SetAccess`, `InviteUser`, `RevokeUser` (client→server), `AccessState`, `AccessBlocked` (server→client).
  - `NetworkClient.setAccess(robloxUserId, access): Result` → `PUT /players/{id}/access`.
  - `playerEconomy[uid].teahouseAccess` stashed from the join fetch.
  - `deckCFForClaim(uid) -> (deckCF12?, deckSize?)` reused; `recomputeAllAccess()` (pushes `AccessBlocked{ blocked }` to every player) + `pushAccessState(player, uid)` helpers.
  - `AccessBlocked { blocked: { { padId: string, gates: { { cframe: {number}, size: {number} } } } } }`.

- [ ] **Step 1: Declare the 5 remotes**

In `roblox/default.project.json`, inside `RoshamboRemotes`, add after the decoration remotes (`DecorationPlaced`):

```json
                "DecorationPlaced": { "$className": "RemoteEvent" },
                "SetAccess": { "$className": "RemoteEvent" },
                "InviteUser": { "$className": "RemoteEvent" },
                "RevokeUser": { "$className": "RemoteEvent" },
                "AccessState": { "$className": "RemoteEvent" },
                "AccessBlocked": { "$className": "RemoteEvent" }
```

(Ensure the preceding `"DecorationPlaced"` line ends with a comma.)

- [ ] **Step 2: Add `NetworkClient.setAccess`**

In `roblox/src/server/NetworkClient.luau`, add before `return NetworkClient`:

```lua
function NetworkClient.setAccess(self: any, robloxUserId: string, access: any): Result
    return self:_request("PUT", `/api/v1/players/{robloxUserId}/access`, { access = access })
end
```

- [ ] **Step 3: Handle the remotes + require the pure modules in `main.server.luau`**

Add the remote handles (after the `DecorationPlaced` handle):

```lua
local DecorationPlaced = remotes:WaitForChild("DecorationPlaced") :: RemoteEvent
local SetAccess = remotes:WaitForChild("SetAccess") :: RemoteEvent
local InviteUser = remotes:WaitForChild("InviteUser") :: RemoteEvent
local RevokeUser = remotes:WaitForChild("RevokeUser") :: RemoteEvent
local AccessState = remotes:WaitForChild("AccessState") :: RemoteEvent
local AccessBlocked = remotes:WaitForChild("AccessBlocked") :: RemoteEvent
```

Add the requires (next to the other `shared` requires, e.g. after `DecorationCatalog`):

```lua
local AccessPolicy = require(shared:WaitForChild("AccessPolicy"))
local AccessGates = require(shared:WaitForChild("AccessGates"))
```

- [ ] **Step 4: Stash `teahouseAccess` + extend the type**

Extend the `playerEconomy` type annotation with:

```lua
        portalOwned: boolean,
        deckDecorations: { any },
        teahouseAccess: { mode: string, invited: { number } },
```

In the join handler's `playerEconomy[uid] = { ... }` init, add:

```lua
            deckDecorations = (ecoData and ecoData.deckDecorations) or {},
            teahouseAccess = (ecoData and ecoData.teahouseAccess) or { mode = "public", invited = {} },
```

(Access is NOT added to the `echoEconomy` payload — the owner's panel reads a dedicated `AccessState` echo, and other clients read `AccessBlocked`.)

- [ ] **Step 5: Add the compute/push engine helpers**

`main.server.luau` already has a `deckCFForClaim`-style resolver inside `PortalController.new({...})`. Add a reusable file-scope version + the access helpers, placed AFTER the `applier` block and the `rebuildClaimedPad` helper (so `PadSites`, `SizeClasses`, `DeckPlacement`, `playerEconomy` are all in scope), and BEFORE the handlers:

```lua
-- (deckCF12, deckSize) for a claimed owner's currently-built deck, or nil,nil.
local function deckCFForUid(uid: string): ({ number }?, string?)
    local e = playerEconomy[uid]
    if e == nil or e.claimedPadId == nil then
        return nil, nil
    end
    local spec = PadSites[e.claimedPadId]
    if spec == nil then
        return nil, nil
    end
    local teaSizes = {}
    for s in e.teahouses do
        table.insert(teaSizes, s)
    end
    local built = SizeClasses.resolveBuilt(e.maxDeckSize, teaSizes, spec.maxSize, e.deckDisplay, e.teahouseDisplay)
    if built == nil then
        return nil, nil
    end
    return DeckPlacement.resolve(spec.deckPlacements, built.deckSize, spec.maxSize), built.deckSize
end

-- friend cache keyed "viewerId:ownerId" (friendship is static within a session).
local friendCache: { [string]: boolean } = {}
local function isFriend(viewer: Player, ownerId: number): boolean
    local key = `{viewer.UserId}:{ownerId}`
    local cached = friendCache[key]
    if cached ~= nil then
        return cached
    end
    local ok, result = pcall(function()
        return viewer:IsFriendsWith(ownerId)
    end)
    local val = ok and result == true
    friendCache[key] = val
    return val
end

-- The gate specs a blocked viewer needs at one occupied pad: the derived deck-back gate + any
-- authored tunnel-mouth gates (PadSites[padId].accessGates, empty until the survey task).
local function gatesForPad(padId: string, deckCF12: { number }, deckSize: string): { any }
    local gates = { AccessGates.deckBackGate(deckCF12, deckSize) }
    local spec = PadSites[padId]
    local authored = spec and spec.accessGates
    if authored then
        for _, g in authored do
            table.insert(gates, { cframe = g.cframe, size = g.size })
        end
    end
    return gates
end

-- For each present player, push the set of occupied pads they are BLOCKED from (with gate specs).
-- Invite lists never leave the server. Cheap: O(viewers x occupiedPads).
local function recomputeAllAccess()
    -- snapshot occupied pads (owner present + claimed), with each owner's access + built deck.
    local occupied: { { padId: string, ownerId: number, mode: string, invited: { number }, deckCF12: { number }, deckSize: string } } = {}
    for _, owner in Players:GetPlayers() do
        local ouid = tostring(owner.UserId)
        local e = playerEconomy[ouid]
        if e ~= nil and e.claimedPadId ~= nil and e.teahouseAccess ~= nil then
            local deckCF12, deckSize = deckCFForUid(ouid)
            if deckCF12 ~= nil and deckSize ~= nil then
                table.insert(occupied, {
                    padId = e.claimedPadId,
                    ownerId = owner.UserId,
                    mode = e.teahouseAccess.mode,
                    invited = e.teahouseAccess.invited,
                    deckCF12 = deckCF12,
                    deckSize = deckSize,
                })
            end
        end
    end
    for _, viewer in Players:GetPlayers() do
        local blocked = {}
        for _, pad in occupied do
            local friend = if pad.mode == "friends" then isFriend(viewer, pad.ownerId) else false
            if not AccessPolicy.canEnter(pad.mode, pad.invited, viewer.UserId, pad.ownerId, friend) then
                table.insert(blocked, { padId = pad.padId, gates = gatesForPad(pad.padId, pad.deckCF12, pad.deckSize) })
            end
        end
        AccessBlocked:FireClient(viewer, { blocked = blocked })
    end
end
```

- [ ] **Step 6: Add `pushAccessState` (owner's panel echo)**

Add after `recomputeAllAccess` (resolves each invited userId to a filtered name; caches names):

```lua
-- userId -> username cache (names are stable); resolution yields, so cache aggressively.
local nameCache: { [number]: string } = {}
local function resolveName(userId: number): string
    local cached = nameCache[userId]
    if cached ~= nil then
        return cached
    end
    local ok, name = pcall(function()
        return Players:GetNameFromUserIdAsync(userId)
    end)
    local resolved = if ok and type(name) == "string" then filterExternalName(name) else tostring(userId)
    nameCache[userId] = resolved
    return resolved
end

-- Echo the owner's own access state (mode + named invitees) to their panel. `notice` is an optional
-- transient message (bad name / already invited / list full) surfaced by the panel.
local function pushAccessState(player: Player, uid: string, notice: string?)
    local e = playerEconomy[uid]
    if e == nil or e.teahouseAccess == nil or not player:IsDescendantOf(Players) then
        return
    end
    local invited = {}
    for _, id in e.teahouseAccess.invited do
        table.insert(invited, { userId = id, name = resolveName(id) })
    end
    AccessState:FireClient(player, { mode = e.teahouseAccess.mode, invited = invited, notice = notice })
end
```

- [ ] **Step 7: Fire access state/blocked on join + occupancy changes**

In the join handler, after the existing `echoEconomy(player, uid)` at the end of the claim/stash block, add:

```lua
        echoEconomy(player, uid)
        pushAccessState(player, uid)
        recomputeAllAccess()
```

In `Players.PlayerRemoving` (the economy one that clears `playerEconomy[uid]`), after the existing cleanup, add a recompute so a departed owner's gates drop for everyone:

```lua
    handlerQueue:clear(tostring(player.UserId))
    recomputeAllAccess()
```

(Place `recomputeAllAccess()` AFTER `playerEconomy[...] = nil` so the leaver's pad is no longer occupied.)

- [ ] **Step 8: Verify + lint**

Run: `cd roblox && lune run tests/run`
Expected: PASS (459+ from prior tasks; runtime file unaffects the pure suite).
Run: `cd roblox && rojo build -o /tmp/ac-t5-check.rbxl`
Expected: succeeds.
Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.

- [ ] **Step 9: Commit**

```bash
git add roblox/default.project.json roblox/src/server/NetworkClient.luau roblox/src/server/main.server.luau
git commit -m "feat(roblox): access remotes, stash + blocked-set compute/push engine"
```

---

## Task 6: Server — SetAccess / InviteUser / RevokeUser handlers

**Files:**
- Modify: `roblox/src/server/main.server.luau`

**Interfaces:**
- Consumes: `recomputeAllAccess`, `pushAccessState`, `net:setAccess` (Task 5); `ACCESS_MODES` semantics; `MAX_INVITED` (=50, hardcode with a named local + comment referencing the TS authority).
- Produces: the three mutating handlers, each HandlerQueue'd + owner-gated + post-yield presence-rechecked.

- [ ] **Step 1: Add the three handlers**

Add after the decoration handlers (`SetDecorationRemove.OnServerEvent`). Add a `MAX_INVITED` local near the top-of-file constants (mirrors `server/src/economy.ts`):

```lua
local MAX_INVITED = 50 -- mirrors server/src/economy.ts MAX_INVITED
local ACCESS_MODES = { public = true, friends = true, private = true }
```

```lua
SetAccess.OnServerEvent:Connect(function(player, payload)
    handlerQueue:run(tostring(player.UserId), function()
        local uid = tostring(player.UserId)
        local e = playerEconomy[uid]
        if e == nil or e.claimedPadId == nil or e.teahouseAccess == nil then
            return -- owner-only, occupying a claimed pad
        end
        local mode = if typeof(payload) == "table" then payload.mode else nil
        if typeof(mode) ~= "string" or not ACCESS_MODES[mode] then
            return
        end
        if mode == e.teahouseAccess.mode then
            return -- no-op
        end
        local newAccess = { mode = mode, invited = table.clone(e.teahouseAccess.invited) }
        local persisted = net:setAccess(uid, newAccess)
        if not persisted.ok then
            warn(`[AC] setAccess(mode) failed for {uid}: {tostring(persisted.error)}`)
            pushAccessState(player, uid)
            return
        end
        if not player:IsDescendantOf(Players) then
            return
        end
        e.teahouseAccess = newAccess
        recomputeAllAccess()
        pushAccessState(player, uid)
    end)
end)

InviteUser.OnServerEvent:Connect(function(player, payload)
    handlerQueue:run(tostring(player.UserId), function()
        local uid = tostring(player.UserId)
        local e = playerEconomy[uid]
        if e == nil or e.claimedPadId == nil or e.teahouseAccess == nil then
            return
        end
        local username = if typeof(payload) == "table" then payload.username else nil
        if typeof(username) ~= "string" or #username == 0 or #username > 20 then
            return
        end
        if #e.teahouseAccess.invited >= MAX_INVITED then
            pushAccessState(player, uid, "Invite list is full")
            return
        end
        local ok, resolved = pcall(function()
            return Players:GetUserIdFromNameAsync(username)
        end)
        if not ok or typeof(resolved) ~= "number" then
            pushAccessState(player, uid, `No player named "{username}"`)
            return
        end
        if resolved == player.UserId then
            pushAccessState(player, uid, "You always have access to your own teahouse")
            return
        end
        for _, id in e.teahouseAccess.invited do
            if id == resolved then
                pushAccessState(player, uid, "Already invited")
                return
            end
        end
        local newInvited = table.clone(e.teahouseAccess.invited)
        table.insert(newInvited, resolved)
        local newAccess = { mode = e.teahouseAccess.mode, invited = newInvited }
        local persisted = net:setAccess(uid, newAccess)
        if not persisted.ok then
            warn(`[AC] setAccess(invite) failed for {uid}: {tostring(persisted.error)}`)
            pushAccessState(player, uid)
            return
        end
        if not player:IsDescendantOf(Players) then
            return
        end
        e.teahouseAccess = newAccess
        recomputeAllAccess()
        pushAccessState(player, uid, `Invited {resolveName(resolved)}`)
    end)
end)

RevokeUser.OnServerEvent:Connect(function(player, payload)
    handlerQueue:run(tostring(player.UserId), function()
        local uid = tostring(player.UserId)
        local e = playerEconomy[uid]
        if e == nil or e.claimedPadId == nil or e.teahouseAccess == nil then
            return
        end
        local userId = if typeof(payload) == "table" then payload.userId else nil
        if typeof(userId) ~= "number" then
            return
        end
        local newInvited = {}
        local found = false
        for _, id in e.teahouseAccess.invited do
            if id == userId then
                found = true
            else
                table.insert(newInvited, id)
            end
        end
        if not found then
            return -- stale id: no-op
        end
        local newAccess = { mode = e.teahouseAccess.mode, invited = newInvited }
        local persisted = net:setAccess(uid, newAccess)
        if not persisted.ok then
            warn(`[AC] setAccess(revoke) failed for {uid}: {tostring(persisted.error)}`)
            pushAccessState(player, uid)
            return
        end
        if not player:IsDescendantOf(Players) then
            return
        end
        e.teahouseAccess = newAccess
        recomputeAllAccess()
        pushAccessState(player, uid)
    end)
end)
```

- [ ] **Step 2: Verify + lint**

Run: `cd roblox && lune run tests/run`
Expected: PASS.
Run: `cd roblox && rojo build -o /tmp/ac-t6-check.rbxl`
Expected: succeeds.
Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add roblox/src/server/main.server.luau
git commit -m "feat(roblox): SetAccess/InviteUser/RevokeUser handlers"
```

---

## Task 7: Server — region backstop (teleport-back / eviction)

**Files:**
- Modify: `roblox/src/server/main.server.luau`

**Interfaces:**
- Consumes: `AccessPolicy.canEnter`, `AccessGates.evictionPoint`, `deckCFForUid`, `isFriend`, `SizeClasses.deckFootprint` (existing).
- Produces: a background loop that PivotTo's a disallowed player out of any occupied deck region.

- [ ] **Step 1: Add the backstop loop**

Add near the end of `main.server.luau` (after the `portalController:start()` block, before/after the coordinator poll loop):

```lua
-- Access backstop: the authoritative half of enforcement. Every ACCESS_TICK seconds, for each
-- occupied deck, teleport back any player standing on it who is not allowed in (canEnter=false).
-- Catches side jump-ins, exploiters who nulled a local gate, and eviction when a mode flips /
-- an invite is revoked. Owner + allowed guests are never moved. Uses deck-LOCAL bounds so it
-- follows the deck's rotation.
local ACCESS_TICK = 0.3
task.spawn(function()
    while true do
        task.wait(ACCESS_TICK)
        -- snapshot occupied decks once per tick
        for _, owner in Players:GetPlayers() do
            local ouid = tostring(owner.UserId)
            local e = playerEconomy[ouid]
            if e == nil or e.claimedPadId == nil or e.teahouseAccess == nil then
                continue
            end
            local deckCF12, deckSize = deckCFForUid(ouid)
            if deckCF12 == nil or deckSize == nil then
                continue
            end
            local fp = SizeClasses.deckFootprint(deckSize)
            local deckCF = CFrame.new(table.unpack(deckCF12))
            local evictCF = CFrame.new(table.unpack(AccessGates.evictionPoint(deckCF12, deckSize)))
            for _, viewer in Players:GetPlayers() do
                if viewer == owner then
                    continue -- owner is always allowed; never evict
                end
                local char = viewer.Character
                local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
                if root == nil then
                    continue
                end
                -- is the viewer standing within this deck's footprint (deck-local), within a height band?
                local rel = deckCF:PointToObjectSpace(root.Position)
                if rel.X < fp.minX or rel.X > fp.maxX or rel.Z < fp.minZ or rel.Z > fp.maxZ then
                    continue
                end
                if rel.Y < -2 or rel.Y > AccessGates.GATE_H then
                    continue -- far below/above the deck plane: not on this deck
                end
                local friend = if e.teahouseAccess.mode == "friends" then isFriend(viewer, owner.UserId) else false
                if not AccessPolicy.canEnter(e.teahouseAccess.mode, e.teahouseAccess.invited, viewer.UserId, owner.UserId, friend) then
                    char:PivotTo(evictCF)
                end
            end
        end
    end
end)
```

- [ ] **Step 2: Verify + lint**

Run: `cd roblox && lune run tests/run`
Expected: PASS.
Run: `cd roblox && rojo build -o /tmp/ac-t7-check.rbxl`
Expected: succeeds.
Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.

- [ ] **Step 3: Commit**

```bash
git add roblox/src/server/main.server.luau
git commit -m "feat(roblox): access region backstop (teleport-back eviction)"
```

---

## Task 8: Client — `AccessGateController`

**Files:**
- Create: `roblox/src/client/AccessGateController.client.luau`

**Interfaces:**
- Consumes: `AccessBlocked { blocked: { { padId, gates: { { cframe: {number}, size: {number} } } } } }` (Task 5).
- Produces: client-local collidable gate parts, rebuilt on each `AccessBlocked` message.

- [ ] **Step 1: Implement `roblox/src/client/AccessGateController.client.luau`**

```lua
--!strict
-- Renders the themed privacy gates for teahouse access control (2026-07-19). The server pushes
-- AccessBlocked with the exact gate specs (cframe + size) for every occupied pad THIS client is
-- blocked from (invite lists never reach the client). We build client-LOCAL parts (created on the
-- client, so they collide with the local character without any collision group) at those specs.
-- A re-push fully rebuilds; a pad no longer present (owner left, or we became allowed) loses its
-- gate. Placeholder noren art -> themed art pass later.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local AccessBlocked = remotes:WaitForChild("AccessBlocked") :: RemoteEvent

-- A client-only container under workspace. A part created with Instance.new ON THE CLIENT and
-- parented to workspace exists only in THIS client's world (never replicated to the server or other
-- players) and DOES simulate locally — so it collides with the local character and no one else's.
-- (A PlayerGui parent would NOT simulate physics; it must be workspace.)
local folder = Instance.new("Folder")
folder.Name = "AccessGates"
folder.Parent = workspace

local NOREN = Color3.fromRGB(120, 40, 45) -- placeholder curtain color

local function buildGate(spec: any): Part?
    if typeof(spec) ~= "table" or typeof(spec.cframe) ~= "table" or typeof(spec.size) ~= "table" then
        return nil
    end
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = true -- solid to the local character (client physics)
    part.CanQuery = false
    part.CanTouch = false
    part.Transparency = 0.35
    part.Color = NOREN
    part.Material = Enum.Material.Fabric
    part.Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
    part.CFrame = CFrame.new(table.unpack(spec.cframe))
    return part
end

local function rebuild(blocked: any)
    for _, c in folder:GetChildren() do
        c:Destroy()
    end
    if typeof(blocked) ~= "table" then
        return
    end
    for _, entry in blocked do
        if typeof(entry) == "table" and typeof(entry.gates) == "table" then
            local padFolder = Instance.new("Folder")
            padFolder.Name = tostring(entry.padId)
            padFolder.Parent = folder
            for _, gspec in entry.gates do
                local gate = buildGate(gspec)
                if gate then
                    gate.Parent = padFolder
                end
            end
        end
    end
end

AccessBlocked.OnClientEvent:Connect(function(p)
    if typeof(p) == "table" then
        rebuild(p.blocked)
    end
end)
```

- [ ] **Step 2: Verify + lint**

Run: `cd roblox && rojo build -o /tmp/ac-t8-check.rbxl`
Expected: succeeds.
Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.
Run: `cd roblox && lune run tests/run`
Expected: PASS (pure suite unaffected).

- [ ] **Step 3: Commit**

```bash
git add roblox/src/client/AccessGateController.client.luau
git commit -m "feat(roblox): AccessGateController renders client-local privacy gates"
```

---

## Task 9: Client — Access panel section

**Files:**
- Modify: `roblox/src/client/TeahouseController.client.luau`

**Interfaces:**
- Consumes: `AccessState { mode, invited: { { userId, name } }, notice? }` (Task 5); fires `SetAccess { mode }`, `InviteUser { username }`, `RevokeUser { userId }`.
- Produces: the Access section (mode toggle + invite field + invitee list + notice).

> Roblox GUI file — no Lune coverage. Verify with `rojo build` + lint + the visual gate.

- [ ] **Step 1: Add the remote handles**

Near the other `remotes:WaitForChild` lines in `TeahouseController.client.luau`, add:

```lua
local SetAccess = remotes:WaitForChild("SetAccess") :: RemoteEvent
local InviteUser = remotes:WaitForChild("InviteUser") :: RemoteEvent
local RevokeUser = remotes:WaitForChild("RevokeUser") :: RemoteEvent
local AccessState = remotes:WaitForChild("AccessState") :: RemoteEvent
```

Add module state near the other latest-state locals (e.g. next to `backDoorIndex`):

```lua
local access = { mode = "public", invited = {} :: { { userId: number, name: string } } }
local accessNotice: string? = nil
```

- [ ] **Step 2: Build the Access section at construction time**

Add after the decorations section builders (before `render` is defined). Uses the existing palette locals (`BG`, `TEXT`, `GOLD`, `DIM`, `DANGER`):

```lua
sectionLabel(82, "Access")

-- mode toggle row (public / friends / private)
local accessModeRow = Instance.new("Frame")
accessModeRow.Name = "AccessModeRow"
accessModeRow.LayoutOrder = 83
accessModeRow.Size = UDim2.new(1, 0, 0, 30)
accessModeRow.BackgroundTransparency = 1
accessModeRow.Parent = panel
do
    local l = Instance.new("UIListLayout")
    l.FillDirection = Enum.FillDirection.Horizontal
    l.Padding = UDim.new(0, 6)
    l.SortOrder = Enum.SortOrder.LayoutOrder
    l.Parent = accessModeRow
end
local accessModeButtons: { [string]: TextButton } = {}
for i, mode in { "public", "friends", "private" } do
    local button = Instance.new("TextButton")
    button.Name = mode
    button.LayoutOrder = i
    button.Size = UDim2.fromOffset(100, 30)
    button.BackgroundColor3 = BG
    button.BackgroundTransparency = 0.1
    button.TextColor3 = TEXT
    button.Font = Enum.Font.Gotham
    button.TextSize = 12
    button.Text = mode:sub(1, 1):upper() .. mode:sub(2)
    button.Parent = accessModeRow
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 6)
    corner.Parent = button
    button.MouseButton1Click:Connect(function()
        SetAccess:FireServer({ mode = mode })
    end)
    accessModeButtons[mode] = button
end

-- invite field + button (shown only in private mode)
local inviteRow = Instance.new("Frame")
inviteRow.Name = "InviteRow"
inviteRow.LayoutOrder = 84
inviteRow.Size = UDim2.new(1, 0, 0, 30)
inviteRow.BackgroundTransparency = 1
inviteRow.Visible = false
inviteRow.Parent = panel
local inviteBox = Instance.new("TextBox")
inviteBox.Name = "InviteBox"
inviteBox.Size = UDim2.new(1, -70, 1, 0)
inviteBox.BackgroundColor3 = BG
inviteBox.BackgroundTransparency = 0.1
inviteBox.TextColor3 = TEXT
inviteBox.PlaceholderText = "username"
inviteBox.Font = Enum.Font.Gotham
inviteBox.TextSize = 12
inviteBox.ClearTextOnFocus = false
inviteBox.Text = ""
inviteBox.Parent = inviteRow
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = inviteBox
end
local inviteButton = Instance.new("TextButton")
inviteButton.Name = "InviteButton"
inviteButton.AnchorPoint = Vector2.new(1, 0)
inviteButton.Position = UDim2.fromScale(1, 0)
inviteButton.Size = UDim2.fromOffset(64, 30)
inviteButton.BackgroundColor3 = BG
inviteButton.BackgroundTransparency = 0.1
inviteButton.TextColor3 = GOLD
inviteButton.Font = Enum.Font.GothamBold
inviteButton.TextSize = 12
inviteButton.Text = "Invite"
inviteButton.Parent = inviteRow
do
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 6)
    c.Parent = inviteButton
end
inviteButton.MouseButton1Click:Connect(function()
    local name = inviteBox.Text
    if #name > 0 then
        InviteUser:FireServer({ username = name })
        inviteBox.Text = ""
    end
end)

local noticeLabel = Instance.new("TextLabel")
noticeLabel.Name = "AccessNotice"
noticeLabel.LayoutOrder = 85
noticeLabel.Size = UDim2.new(1, 0, 0, 16)
noticeLabel.BackgroundTransparency = 1
noticeLabel.TextColor3 = GOLD
noticeLabel.Font = Enum.Font.Gotham
noticeLabel.TextSize = 11
noticeLabel.TextXAlignment = Enum.TextXAlignment.Left
noticeLabel.Text = ""
noticeLabel.Visible = false
noticeLabel.Parent = panel

-- invitee list (shown only in private mode)
local inviteeContainer = Instance.new("ScrollingFrame")
inviteeContainer.Name = "Invitees"
inviteeContainer.LayoutOrder = 86
inviteeContainer.Size = UDim2.new(1, 0, 0, 96)
inviteeContainer.CanvasSize = UDim2.new()
inviteeContainer.AutomaticCanvasSize = Enum.AutomaticSize.Y
inviteeContainer.ScrollBarThickness = 6
inviteeContainer.BackgroundTransparency = 1
inviteeContainer.BorderSizePixel = 0
inviteeContainer.Visible = false
inviteeContainer.Parent = panel
local inviteeLayout = Instance.new("UIListLayout")
inviteeLayout.FillDirection = Enum.FillDirection.Vertical
inviteeLayout.Padding = UDim.new(0, 4)
inviteeLayout.SortOrder = Enum.SortOrder.LayoutOrder
inviteeLayout.Parent = inviteeContainer
```

- [ ] **Step 3: Add the access render helpers + call from `render()`**

Add a render helper (before `render`):

```lua
local function renderAccess()
    for mode, button in accessModeButtons do
        local selected = access.mode == mode
        button.TextColor3 = if selected then GOLD else TEXT
        button.BackgroundTransparency = if selected then 0 else 0.1
    end
    local isPrivate = access.mode == "private"
    inviteRow.Visible = isPrivate
    inviteeContainer.Visible = isPrivate
    noticeLabel.Visible = accessNotice ~= nil
    noticeLabel.Text = accessNotice or ""

    for _, child in inviteeContainer:GetChildren() do
        if child ~= inviteeLayout then
            child:Destroy()
        end
    end
    if isPrivate then
        for i, entry in access.invited do
            local row = Instance.new("Frame")
            row.Name = "Invitee_" .. tostring(entry.userId)
            row.LayoutOrder = i
            row.Size = UDim2.new(1, 0, 0, 22)
            row.BackgroundTransparency = 1
            row.Parent = inviteeContainer
            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -28, 1, 0)
            label.BackgroundTransparency = 1
            label.TextColor3 = TEXT
            label.Font = Enum.Font.Gotham
            label.TextSize = 12
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Text = entry.name
            label.Parent = row
            local remove = Instance.new("TextButton")
            remove.AnchorPoint = Vector2.new(1, 0)
            remove.Position = UDim2.fromScale(1, 0)
            remove.Size = UDim2.fromOffset(22, 22)
            remove.BackgroundColor3 = BG
            remove.BackgroundTransparency = 0.1
            remove.TextColor3 = DANGER
            remove.Font = Enum.Font.GothamBold
            remove.TextSize = 14
            remove.Text = "x"
            remove.Parent = row
            local c = Instance.new("UICorner")
            c.CornerRadius = UDim.new(0, 4)
            c.Parent = remove
            local uid = entry.userId
            remove.MouseButton1Click:Connect(function()
                RevokeUser:FireServer({ userId = uid })
            end)
        end
    end
end
```

In `render()`, after the decorations block (before `renderFavorites`), add:

```lua
    renderAccess()
```

Also make the whole Access section owner-only by hiding it when the player owns no deck (place these after `renderAccess()` in `render`, using the existing `vm.ownsDeck`):

```lua
    accessModeRow.Visible = vm.ownsDeck
    if not vm.ownsDeck then
        inviteRow.Visible = false
        inviteeContainer.Visible = false
        noticeLabel.Visible = false
    end
```

- [ ] **Step 4: Wire the `AccessState` echo**

Add near the other `OnClientEvent` handlers:

```lua
AccessState.OnClientEvent:Connect(function(p)
    if typeof(p) ~= "table" then
        return
    end
    access.mode = p.mode or "public"
    access.invited = p.invited or {}
    accessNotice = p.notice
    render()
end)
```

- [ ] **Step 5: Verify + lint**

Run: `cd roblox && rojo build -o /tmp/ac-t9-check.rbxl`
Expected: succeeds.
Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.
Run: `cd roblox && lune run tests/run`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/client/TeahouseController.client.luau
git commit -m "feat(roblox): access panel section (mode toggle + invite/revoke)"
```

---

## Task 10: Tunnel-gate survey tool + authored data

**Files:**
- Create: `roblox/tools/studio/surveyAccessGates.luau`
- Modify: `roblox/src/server/PadSites.luau`

**Interfaces:**
- Consumes: `PadSites` shape (existing per-pad tables).
- Produces: `PadSites[padId].accessGates: { { cframe: {number}, size: {number} } }` (optional per pad); a Studio survey tool that bakes it. Task 5's `gatesForPad` already reads this field, so no server logic changes.

> This task authors DATA via an in-Studio survey (like the deck-placement survey). The tool and the baked values are the deliverable; there is no Lune test for authored geometry.

- [ ] **Step 1: Write the survey tool `roblox/tools/studio/surveyAccessGates.luau`**

```lua
--!strict
-- Studio survey tool for teahouse tunnel-mouth access gates (2026-07-19). Run in Edit mode. For
-- each pad that is reached via a tunnel ("where appropriate"), it spawns a draggable slab at the
-- pad's deck position; drag/scale each slab to fill its tunnel mouth, then run the tool again with
-- MODE="bake" to print the PadSites[padId].accessGates literals to paste into PadSites.luau.
-- Mirrors tools/studio/surveyDeckPlacements.luau. Place-only; values are baked into PadSites.
local Workspace = game:GetService("Workspace")
local ServerScriptService = game:GetService("ServerScriptService")

-- EDIT THESE for the run:
local MODE = "place" -- "place" spawns draggable slabs; "bake" reads them back and prints literals
local PAD_IDS = { "T03", "T14" } -- the pads whose access is a tunnel (author "where appropriate")

local PadSites = require(ServerScriptService:WaitForChild("Server"):WaitForChild("PadSites"))

local FOLDER_NAME = "AccessGateSurvey"

local function place()
    local folder = Workspace:FindFirstChild(FOLDER_NAME)
    if folder then
        folder:Destroy()
    end
    folder = Instance.new("Folder")
    folder.Name = FOLDER_NAME
    folder.Parent = Workspace
    for _, padId in PAD_IDS do
        local spec = PadSites[padId]
        if spec == nil then
            warn(`[survey] unknown pad {padId}`)
            continue
        end
        local place12 = spec.deckPlacements[spec.deckSize] or spec.deckPlacements[spec.maxSize]
        local slab = Instance.new("Part")
        slab.Name = padId
        slab.Anchored = true
        slab.CanCollide = false
        slab.Color = Color3.fromRGB(200, 60, 60)
        slab.Transparency = 0.4
        slab.Size = Vector3.new(8, 8, 1)
        slab.CFrame = CFrame.new(place12[1], place12[2] + 4, place12[3])
        slab.Parent = folder
    end
    print(`[survey] placed {#PAD_IDS} draggable slabs under Workspace.{FOLDER_NAME}; drag each into its tunnel mouth, then set MODE="bake"`)
end

local function bake()
    local folder = Workspace:FindFirstChild(FOLDER_NAME)
    if folder == nil then
        warn(`[survey] no {FOLDER_NAME} folder; run MODE="place" first`)
        return
    end
    for _, slab in folder:GetChildren() do
        if slab:IsA("BasePart") then
            local c = { slab.CFrame:GetComponents() }
            -- GetComponents returns x,y,z, r00,r01,r02, r10,r11,r12, r20,r21,r22 (12 numbers)
            local cf = string.format(
                "{ %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f }",
                c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12]
            )
            local sz = string.format("{ %.4f, %.4f, %.4f }", slab.Size.X, slab.Size.Y, slab.Size.Z)
            print(`["${slab.Name}"] accessGates = { { cframe = {cf}, size = {sz} } },`)
        end
    end
    print("[survey] paste each printed accessGates line into the matching PadSites entry")
end

if MODE == "place" then
    place()
else
    bake()
end
```

- [ ] **Step 2: Add `accessGates` to the surveyed pads in `PadSites.luau`**

Run the tool in Studio (`MODE="place"`, drag slabs into the tunnel mouths of the tunnel-accessed pads, then `MODE="bake"`), and paste the printed `accessGates` line into each matching pad entry. For example, `T03` gains:

```lua
    ["T03"] = {
        id = "T03",
        displayName = "Near Perch 03",
        deckPlacements = { --[[ ...existing... ]] },
        maxSize = "L",
        deckSize = "L",
        vacantForm = "dormant-structure",
        accessGates = { { cframe = { --[[ 12 surveyed numbers ]] }, size = { --[[ 3 ]] } } },
    },
```

Pads reached only by open paths (no tunnel) get no `accessGates` — the derived deck-back gate + backstop already cover them.

- [ ] **Step 3: Verify the data parses + lint**

Run: `cd roblox && lune run tests/run`
Expected: PASS (PadSites still loads; no test asserts the new field).
Run: `cd roblox && rojo build -o /tmp/ac-t10-check.rbxl`
Expected: succeeds.
Run: `cd roblox && stylua --check src tests && selene src`
Expected: clean.

- [ ] **Step 4: Commit**

```bash
git add roblox/tools/studio/surveyAccessGates.luau roblox/src/server/PadSites.luau
git commit -m "feat(roblox): tunnel-mouth access-gate survey tool + authored data"
```

---

## Visual gate (after Task 10 — run in Studio via Rojo, not a task)

Deploy the backend (push the branch → dev App Runner) and `rojo serve`, then with two players (or a second account/test client):
1. Owner opens the panel Access section; toggles **Public → Private** — a second player standing on the deck is bounced (backstop) and sees the noren gate at the deck back; a non-owner walking up is stopped at the gate.
2. **Friends** mode — a Roblox friend of the owner walks straight in; a non-friend is stopped.
3. **Invite by username** (online and offline) — the named player passes; a bad name shows the notice, no change.
4. **Revoke** — the evicted player is bounced next tick and the gate reappears for them.
5. A **side jump-in** onto the deck is bounced by the backstop.
6. The **tunnel-mouth gate** stops a blocked player at the tunnel (surveyed pads).
7. Owner and allowed guests always pass; Public decks have no gate at all.

---

## Self-Review notes (for the executor)

- **Spec coverage:** policy + persistence (T1,T2), `canEnter` (T3), gate/eviction geometry (T4), server stash/compute/push + remotes (T5), the three mutating handlers + username/name resolution (T6), backstop (T7), client gates (T8), panel UI (T9), tunnel survey (T10) — all spec sections covered.
- **Type consistency:** `teahouseAccess = { mode, invited: number[] }` and the `AccessBlocked { blocked: {{ padId, gates: {{ cframe, size }} }} }` / `AccessState { mode, invited: {{ userId, name }}, notice? }` shapes match across producer (T5/T6) and consumers (T8/T9); `canEnter` and `AccessGates` signatures match their call sites in T5/T7.
- **Known deferred (do NOT build):** guest-pass / portal-to-friend, block/ban lists, per-decoration/per-floor/time-limited access, gate art.
