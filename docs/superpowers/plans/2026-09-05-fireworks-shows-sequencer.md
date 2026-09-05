# Fireworks Shows & Sequencer (sub-project B) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A show is data, validated identically on both sides of the wire, reserved atomically on the backend, and played back by the Roblox game server through the existing `FireworkLaunched` broadcast — so a large hand-authored show can be run on the A13 and the director's scale assumption finally measured.

**Architecture:** A shared fixture (`shared-fixtures/shows.json`) holds the show grammar and its validation cases; `server/src/shows.ts` and `roblox/src/shared/ShowPlan.luau` are twins held to it, the way the game rules are. The backend gains one endpoint that debits every shell a show needs in a single conditional update (all or nothing). The game server gains a runner that walks cues on its own clock and emits each through the same launch payload the single-shell path emits, from the same muzzle math. A Studio-only proving verb plays hand-authored show files from the five stations and the rooftop battery so the A13 test needs no console.

**Tech Stack:** TypeScript (Express 5, Mongoose, Vitest, `mongodb-memory-server` for route tests), Luau under Lune (bespoke harness in `roblox/tests/harness.luau`; `stylua` + `selene` in CI), Rojo (`default.project.json` is the RemoteEvents contract).

**Spec:** `docs/superpowers/specs/2026-09-05-fireworks-show-system-design.md` — §1 (show), §2 (sequencer), §3 (stages), §10 row B, §12 (testing). Read it first.

## Global Constraints

- **TDD every task**: failing test → run → minimal code → run → commit. Server suite: `cd server && npm test`. Luau suite: `cd roblox && lune run tests/run` (1847 tests green at plan time). Before any Luau commit: `cd roblox && stylua --check src tests tools && selene src tools` (selene fails on warnings; CI runs exactly this scope).
- **Shared modules take no Roblox globals** (`--!strict`, pure, DI). `roblox/src/shared/*.luau` must run under Lune. Only `main.server.luau` / `*.client.luau` touch services.
- **Inventory fuel only.** `fuel: 'powder'` is sub-project A; this plan refuses it with `FUEL_UNSUPPORTED`.
- **Deck stage only for players.** A player's show targets `deck:<their robloxUserId>` and nothing else (spec §3, decision 4). Stations and the rooftop are reachable in this plan only through the Studio-gated proving verb.
- **Spend first, broadcast second** (the existing launch rule). A show that cannot be fully paid does not start; once reserved, playback continues even if the owner leaves.
- **`FireworkLaunched` payload stays backward compatible.** New fields (`showId`) are additive; `origin` is a `Vector3`, `heading` a `{x,y,z}` table or nil, `seed` a number, `by` a string, `boosted` boolean or nil, `apexHeight` number or nil — exactly as today.
- **The director is not touched.** No throttling in the sequencer; density is the director's job (spec §2.3).
- **No console UI, no calendar, no tickets, no powder, no client rendering changes** except the proving panel's new section. Those are sub-projects A, C and D.
- **Limits are config**: `SHOW_MAX_CUES = 120`, `SHOW_MAX_DURATION_S = 300`, `SHOW_TAIL_MS = 6000` (time after the last cue before a stage is free again).
- **Commit style** `type(scope): summary`; every commit ends with a blank line and `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>`. Stage only the files each task names. This is a two-session repo: `git fetch` before every push; never rebase or reset on a dirty tree ([[parallel-threads]] rule 0). Code work happens in a fresh worktree `.worktrees/shows` on branch `thread/shows`.

---

## File map

| file | responsibility |
|---|---|
| `shared-fixtures/shows.json` (new) | the show grammar: limits, stage slot tables, validation cases |
| `server/src/shows.ts` (new) | `validateShow`, `SHOW_LIMITS`, `DECK_STAGE`, `tallyShells` — TS twin |
| `server/src/shows.test.ts` (new) | fixture-driven validator tests |
| `server/src/routes/apiV1.ts` | `POST /players/:robloxUserId/shows/reserve` |
| `server/src/routes/apiV1.test.ts` | reserve route tests |
| `roblox/tests/fixtures/shows.luau` (new) | reads `shared-fixtures/shows.json` under Lune |
| `roblox/src/shared/ShowPlan.luau` (new) | `validate`, `DECK_SLOTS`, `LIMITS` — Luau twin |
| `roblox/src/shared/ShowPlayer.luau` (new) | pure timeline + per-stage scheduling |
| `roblox/src/shared/FireworkShows.luau` (new) | hand-authored show drafts for the proving verb and the A13 test |
| `roblox/src/server/NetworkClient.luau` | `postShowReserve` |
| `roblox/src/server/main.server.luau` | extracted launch helpers; `RequestShowGo`; `RequestProvingShow`; the runner |
| `roblox/src/client/ProvingController.client.luau` | a "Shows" section with one Play button per draft |
| `roblox/default.project.json` | two new RemoteEvents |
| `roblox/tests/{ShowPlan,ShowPlayer,FireworkShows,NetworkClient}.spec.luau` | Luau tests |
| `docs/wiki/world/fireworks.md`, `docs/wiki/log.md` | as-built, ship entry, the A13 gate |

---

### Task 1: The show fixture and the TypeScript validator

**Files:**
- Create: `shared-fixtures/shows.json`
- Create: `server/src/shows.ts`
- Test: `server/src/shows.test.ts`

**Interfaces:**
- Consumes: `SHELL_IDS`, `REQUIREMENTS` from `server/src/fireworks.ts` (a requirement of kind `gear` carries `mortar: 'mortar:S'|'mortar:M'|'mortar:L'`).
- Produces:
  - `type Cue = { t_ms: number; slot: string; shellId: string }`
  - `type ShowInput = { stageId: string; fuel: 'inventory' | 'powder'; cues: Cue[]; title?: string }`
  - `type StageSlots = Record<string, string>` — slot name → `'none' | 'any' | 'mortar:S' | 'mortar:M' | 'mortar:L'`
  - `SHOW_LIMITS = { maxCues: 120, maxDurationS: 300 }` (read from the fixture)
  - `DECK_STAGE: StageSlots` (read from the fixture's `stages.deck`)
  - `validateShow(cues: unknown, stage: StageSlots): { ok: true } | { ok: false; error: ShowError; cue?: number }` where `ShowError = 'EMPTY' | 'TOO_MANY_CUES' | 'TOO_LONG' | 'BAD_CUE' | 'NEGATIVE_TIME' | 'CUES_OUT_OF_ORDER' | 'BAD_SLOT' | 'BAD_SHELL' | 'TIER_MISMATCH'`
  - `tallyShells(cues: Cue[]): Record<string, number>`
  - `shellMortar(shellId: string): string | null` (from `REQUIREMENTS`; `null` for no-gear shells)

- [ ] **Step 1: Write the fixture**

```json
{
    "comment": "The show grammar — the contract between server/src/shows.ts and roblox/src/shared/ShowPlan.luau. Both validators run every case below; a rule that exists on one side only is a CI failure, not a drift. Cue shells must be ids from firework-shells.json; the tier each needs comes from that fixture's `mortars` list.",
    "limits": { "maxCues": 120, "maxDurationS": 300 },
    "stagesComment": "slot -> what may fire from it. 'none' = only shells with no gear requirement (the hand); 'mortar:X' = only shells whose required mortar is X; 'any' = anything (public tubes accept every shell, as the proving path does today).",
    "stages": {
        "deck": { "hand": "none", "mortar:S": "mortar:S", "mortar:M": "mortar:M", "mortar:L": "mortar:L" },
        "proving": { "north arena": "any", "bridge": "any", "upper north": "any", "mid pool": "any", "hi west": "any", "hanabiya roof": "any" }
    },
    "cases": [
        { "name": "one firecracker from the hand is a valid show", "stage": "deck", "cues": [{ "t_ms": 0, "slot": "hand", "shellId": "firecracker" }], "expect": "ok" },
        { "name": "a gear shell from its own tier's mortar", "stage": "deck", "cues": [{ "t_ms": 0, "slot": "mortar:S", "shellId": "peony" }, { "t_ms": 1500, "slot": "mortar:M", "shellId": "willow" }], "expect": "ok" },
        { "name": "equal times are allowed — a volley", "stage": "deck", "cues": [{ "t_ms": 0, "slot": "mortar:S", "shellId": "peony" }, { "t_ms": 0, "slot": "mortar:M", "shellId": "wa" }], "expect": "ok" },
        { "name": "a condition shell is allowed; the condition is checked at fire time", "stage": "deck", "cues": [{ "t_ms": 0, "slot": "hand", "shellId": "ishibana" }], "expect": "ok" },
        { "name": "public tubes accept any shell", "stage": "proving", "cues": [{ "t_ms": 0, "slot": "mid pool", "shellId": "kamuro" }, { "t_ms": 700, "slot": "hanabiya roof", "shellId": "firecracker" }], "expect": "ok" },
        { "name": "an empty show is not a show", "stage": "deck", "cues": [], "expect": "EMPTY" },
        { "name": "cues must be in time order", "stage": "deck", "cues": [{ "t_ms": 1000, "slot": "hand", "shellId": "firecracker" }, { "t_ms": 500, "slot": "hand", "shellId": "firecracker" }], "expect": "CUES_OUT_OF_ORDER", "cue": 1 },
        { "name": "no negative times", "stage": "deck", "cues": [{ "t_ms": -1, "slot": "hand", "shellId": "firecracker" }], "expect": "NEGATIVE_TIME", "cue": 0 },
        { "name": "unknown slot", "stage": "deck", "cues": [{ "t_ms": 0, "slot": "mortar:XL", "shellId": "peony" }], "expect": "BAD_SLOT", "cue": 0 },
        { "name": "unknown shell", "stage": "deck", "cues": [{ "t_ms": 0, "slot": "hand", "shellId": "moonshot" }], "expect": "BAD_SHELL", "cue": 0 },
        { "name": "a gear shell cannot fire from the hand", "stage": "deck", "cues": [{ "t_ms": 0, "slot": "hand", "shellId": "peony" }], "expect": "TIER_MISMATCH", "cue": 0 },
        { "name": "a gear shell cannot fire from another tier's mortar", "stage": "deck", "cues": [{ "t_ms": 0, "slot": "mortar:M", "shellId": "peony" }], "expect": "TIER_MISMATCH", "cue": 0 },
        { "name": "a no-gear shell cannot fire from a mortar", "stage": "deck", "cues": [{ "t_ms": 0, "slot": "mortar:S", "shellId": "firecracker" }], "expect": "TIER_MISMATCH", "cue": 0 },
        { "name": "a malformed cue", "stage": "deck", "cues": [{ "t_ms": "soon", "slot": "hand", "shellId": "firecracker" }], "expect": "BAD_CUE", "cue": 0 },
        { "name": "too long", "stage": "deck", "cues": [{ "t_ms": 0, "slot": "hand", "shellId": "firecracker" }, { "t_ms": 300001, "slot": "hand", "shellId": "firecracker" }], "expect": "TOO_LONG" }
    ],
    "tooManyComment": "The TOO_MANY_CUES case is generated by each test (maxCues + 1 hand firecrackers) rather than written out here."
}
```

- [ ] **Step 2: Write the failing test**

```ts
// server/src/shows.test.ts
import { describe, it, expect } from 'vitest';
import fixture from '../../shared-fixtures/shows.json';
import shellFixture from '../../shared-fixtures/firework-shells.json';
import { validateShow, tallyShells, shellMortar, SHOW_LIMITS, DECK_STAGE, Cue } from './shows';

describe('the fixture is the contract', () => {
    it('limits come from the fixture', () => {
        expect(SHOW_LIMITS).toEqual(fixture.limits);
    });
    it('DECK_STAGE is the fixture deck stage', () => {
        expect(DECK_STAGE).toEqual(fixture.stages.deck);
    });
    it('every case shell is a catalogued shell or deliberately unknown', () => {
        for (const c of fixture.cases) {
            for (const cue of c.cues) {
                if (c.expect !== 'BAD_SHELL') expect(shellFixture.shells).toContain(cue.shellId);
            }
        }
    });
});

describe('validateShow — every fixture case', () => {
    for (const c of fixture.cases) {
        it(c.name, () => {
            const stage = (fixture.stages as Record<string, Record<string, string>>)[c.stage];
            const r = validateShow(c.cues, stage);
            if (c.expect === 'ok') {
                expect(r).toEqual({ ok: true });
            } else {
                expect(r.ok).toBe(false);
                if (!r.ok) {
                    expect(r.error).toBe(c.expect);
                    if ('cue' in c) expect(r.cue).toBe(c.cue);
                }
            }
        });
    }
    it('TOO_MANY_CUES at maxCues + 1', () => {
        const cues: Cue[] = Array.from({ length: SHOW_LIMITS.maxCues + 1 }, (_, i) => ({ t_ms: i * 10, slot: 'hand', shellId: 'firecracker' }));
        expect(validateShow(cues, DECK_STAGE)).toEqual({ ok: false, error: 'TOO_MANY_CUES' });
        expect(validateShow(cues.slice(0, SHOW_LIMITS.maxCues), DECK_STAGE)).toEqual({ ok: true });
    });
    it('rejects non-array input as EMPTY', () => {
        expect(validateShow(undefined, DECK_STAGE)).toEqual({ ok: false, error: 'EMPTY' });
        expect(validateShow('nope', DECK_STAGE)).toEqual({ ok: false, error: 'EMPTY' });
    });
});

describe('helpers', () => {
    it('shellMortar reads REQUIREMENTS', () => {
        expect(shellMortar('peony')).toBe('mortar:S');
        expect(shellMortar('kamuro')).toBe('mortar:L');
        expect(shellMortar('firecracker')).toBeNull();
        expect(shellMortar('ishibana')).toBeNull();
        expect(shellMortar('nope')).toBeNull();
    });
    it('tallyShells counts per id', () => {
        expect(tallyShells([
            { t_ms: 0, slot: 'hand', shellId: 'firecracker' },
            { t_ms: 0, slot: 'mortar:S', shellId: 'peony' },
            { t_ms: 500, slot: 'hand', shellId: 'firecracker' },
        ])).toEqual({ firecracker: 2, peony: 1 });
    });
});
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd server && npx vitest run src/shows.test.ts`
Expected: FAIL — `Cannot find module './shows'`. (The TEST imports the JSON fixture exactly as `fireworks.test.ts` does; the module under test does not — see the literals note in Step 4.)

- [ ] **Step 4: Write minimal implementation**

```ts
// server/src/shows.ts
// A SHOW IS DATA (spec 2026-09-05-fireworks-show-system-design §1). This is the TypeScript twin of
// roblox/src/shared/ShowPlan.luau; both are held to shared-fixtures/shows.json so a rule that
// exists on one side only fails CI instead of letting a client author a show the backend refuses
// (or worse, the reverse). Limits bound payload size, not spectacle — density is the director's
// business, not the validator's.
import { SHELL_IDS, REQUIREMENTS } from './fireworks';

export type Cue = { t_ms: number; slot: string; shellId: string };
export type ShowInput = { stageId: string; fuel: 'inventory' | 'powder'; cues: Cue[]; title?: string };
export type StageSlots = Record<string, string>; // slot -> 'none' | 'any' | 'mortar:S' | 'mortar:M' | 'mortar:L'
export type ShowError =
    | 'EMPTY' | 'TOO_MANY_CUES' | 'TOO_LONG' | 'BAD_CUE' | 'NEGATIVE_TIME'
    | 'CUES_OUT_OF_ORDER' | 'BAD_SLOT' | 'BAD_SHELL' | 'TIER_MISMATCH';
export type ShowCheck = { ok: true } | { ok: false; error: ShowError; cue?: number };

// LITERALS, asserted equal to shared-fixtures/shows.json by shows.test.ts — the same pattern as
// GameRules.ts vs game-rules.json. Runtime code never reads the fixture: `rootDir` is src/ and the
// deployed container is built from server/ alone.
export const SHOW_LIMITS = { maxCues: 120, maxDurationS: 300 };
export const DECK_STAGE: StageSlots = { hand: 'none', 'mortar:S': 'mortar:S', 'mortar:M': 'mortar:M', 'mortar:L': 'mortar:L' };

export function shellMortar(shellId: string): string | null {
    const req = REQUIREMENTS[shellId];
    return req && req.kind === 'gear' ? req.mortar : null;
}

function isCue(c: unknown): c is Cue {
    if (typeof c !== 'object' || c === null) return false;
    const o = c as Record<string, unknown>;
    return typeof o.t_ms === 'number' && Number.isFinite(o.t_ms)
        && typeof o.slot === 'string' && typeof o.shellId === 'string';
}

export function validateShow(cues: unknown, stage: StageSlots): ShowCheck {
    if (!Array.isArray(cues) || cues.length === 0) return { ok: false, error: 'EMPTY' };
    if (cues.length > SHOW_LIMITS.maxCues) return { ok: false, error: 'TOO_MANY_CUES' };
    let last = -Infinity;
    for (let i = 0; i < cues.length; i++) {
        const c = cues[i];
        if (!isCue(c)) return { ok: false, error: 'BAD_CUE', cue: i };
        if (c.t_ms < 0) return { ok: false, error: 'NEGATIVE_TIME', cue: i };
        if (c.t_ms < last) return { ok: false, error: 'CUES_OUT_OF_ORDER', cue: i };
        last = c.t_ms;
        const accepts = stage[c.slot];
        if (accepts === undefined) return { ok: false, error: 'BAD_SLOT', cue: i };
        if (!(SHELL_IDS as readonly string[]).includes(c.shellId)) return { ok: false, error: 'BAD_SHELL', cue: i };
        const needs = shellMortar(c.shellId);
        if (accepts === 'none' && needs !== null) return { ok: false, error: 'TIER_MISMATCH', cue: i };
        if (accepts.startsWith('mortar:') && needs !== accepts) return { ok: false, error: 'TIER_MISMATCH', cue: i };
        // 'any' accepts everything (public tubes).
    }
    if (last > SHOW_LIMITS.maxDurationS * 1000) return { ok: false, error: 'TOO_LONG' };
    return { ok: true };
}

export function tallyShells(cues: Cue[]): Record<string, number> {
    const out: Record<string, number> = {};
    for (const c of cues) out[c.shellId] = (out[c.shellId] ?? 0) + 1;
    return out;
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd server && npx vitest run src/shows.test.ts && npx tsc --noEmit`
Expected: PASS, no type errors.

- [ ] **Step 6: Commit**

```bash
git add shared-fixtures/shows.json server/src/shows.ts server/src/shows.test.ts
git commit -m "feat(shows): the show grammar as a shared fixture, and its TypeScript validator

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: The Luau twin — `ShowPlan.luau`

**Files:**
- Create: `roblox/tests/fixtures/shows.luau`
- Create: `roblox/src/shared/ShowPlan.luau`
- Test: `roblox/tests/ShowPlan.spec.luau`

**Interfaces:**
- Consumes: `roblox/tests/fixtures/fireworkShells.luau` (`shells`, `mortars = { { shell, mortar } }`), `MortarPlacement.SHELL_MORTAR` (`{ [shellId]: "mortar:S" }`).
- Produces (module `ShowPlan`):
  - `ShowPlan.LIMITS = { maxCues = 120, maxDurationS = 300 }` (transcribed; the spec asserts it equals the fixture)
  - `ShowPlan.DECK_SLOTS: { [string]: string }`, `ShowPlan.PROVING_SLOTS: { [string]: string }` (transcribed; asserted against the fixture)
  - `type Cue = { t_ms: number, slot: string, shellId: string }`
  - `ShowPlan.validate(cues: any, stage: { [string]: string }, shellMortar: { [string]: string }, knownShells: { [string]: boolean }) : { ok: boolean, error: string?, cue: number? }` — `cue` is **zero-based** to match the fixture and the TS twin
  - `ShowPlan.tally(cues: { Cue }): { [string]: number }`
  - `ShowPlan.knownShellSet(ids: { string }): { [string]: boolean }`

- [ ] **Step 1: Write the fixture reader**

```lua
--!strict
-- shared-fixtures/shows.json, read under Lune the same way fireworkShells.luau reads its fixture:
-- never transcribed, so a case added on the server side is a case here the next time tests run.
local fs = require("@lune/fs")
local serde = require("@lune/serde")

local PATH = "../shared-fixtures/shows.json"

local decoded = serde.decode("json", fs.readFile(PATH))
assert(type(decoded) == "table", `{PATH} is not a table`)
assert(type(decoded.limits) == "table", `{PATH} has no limits`)
assert(type(decoded.stages) == "table", `{PATH} has no stages`)
assert(type(decoded.cases) == "table" and #decoded.cases > 0, `{PATH} lists no cases`)

export type Case = { name: string, stage: string, cues: { any }, expect: string, cue: number? }

return {
    limits = decoded.limits :: { maxCues: number, maxDurationS: number },
    stages = decoded.stages :: { [string]: { [string]: string } },
    cases = decoded.cases :: { Case },
}
```

- [ ] **Step 2: Write the failing test**

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local ShowPlan = require("../src/shared/ShowPlan")
local MortarPlacement = require("../src/shared/MortarPlacement")
local fixture = require("./fixtures/shows")
local shellFixture = require("./fixtures/fireworkShells")

local known = ShowPlan.knownShellSet(shellFixture.shells)

describe("ShowPlan -- the fixture is the contract", function()
    test("LIMITS equal the fixture", function()
        expect(ShowPlan.LIMITS).toEqual(fixture.limits)
    end)
    test("DECK_SLOTS and PROVING_SLOTS equal the fixture stages", function()
        expect(ShowPlan.DECK_SLOTS).toEqual(fixture.stages.deck)
        expect(ShowPlan.PROVING_SLOTS).toEqual(fixture.stages.proving)
    end)
end)

describe("ShowPlan.validate -- every fixture case", function()
    for _, c in fixture.cases do
        test(c.name, function()
            local r = ShowPlan.validate(c.cues, fixture.stages[c.stage], MortarPlacement.SHELL_MORTAR, known)
            if c.expect == "ok" then
                expect(r.ok).toBe(true)
                expect(r.error).toBeNil()
            else
                expect(r.ok).toBe(false)
                expect(r.error).toBe(c.expect)
                if c.cue ~= nil then
                    expect(r.cue).toBe(c.cue)
                end
            end
        end)
    end
    test("TOO_MANY_CUES at maxCues + 1, and exactly maxCues is fine", function()
        local cues = {}
        for i = 1, ShowPlan.LIMITS.maxCues + 1 do
            table.insert(cues, { t_ms = (i - 1) * 10, slot = "hand", shellId = "firecracker" })
        end
        expect(ShowPlan.validate(cues, ShowPlan.DECK_SLOTS, MortarPlacement.SHELL_MORTAR, known).error).toBe("TOO_MANY_CUES")
        table.remove(cues)
        expect(ShowPlan.validate(cues, ShowPlan.DECK_SLOTS, MortarPlacement.SHELL_MORTAR, known).ok).toBe(true)
    end)
    test("non-table input is EMPTY", function()
        expect(ShowPlan.validate(nil, ShowPlan.DECK_SLOTS, MortarPlacement.SHELL_MORTAR, known).error).toBe("EMPTY")
        expect(ShowPlan.validate("nope", ShowPlan.DECK_SLOTS, MortarPlacement.SHELL_MORTAR, known).error).toBe("EMPTY")
    end)
end)

describe("ShowPlan.tally", function()
    test("counts per shell id", function()
        expect(ShowPlan.tally({
            { t_ms = 0, slot = "hand", shellId = "firecracker" },
            { t_ms = 0, slot = "mortar:S", shellId = "peony" },
            { t_ms = 500, slot = "hand", shellId = "firecracker" },
        })).toEqual({ firecracker = 2, peony = 1 })
    end)
end)
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd roblox && lune run tests/run 2>&1 | tail -5`
Expected: the run errors on `require("../src/shared/ShowPlan")` (module missing). If the harness aborts the whole run on a missing module, that is the expected red.

- [ ] **Step 4: Write minimal implementation**

```lua
--!strict
-- A SHOW IS DATA. The Luau twin of server/src/shows.ts, held to shared-fixtures/shows.json by
-- tests/ShowPlan.spec.luau: every case the server validator runs, this one runs too, so the
-- console can refuse a show for exactly the reason the backend would and never sends one the
-- backend will bounce. Pure: no Roblox globals, runs under Lune.
--
-- Slot tables are transcribed here (the runtime cannot read the fixture); the spec asserts they
-- equal it. Add a slot in the fixture first, then here, or CI says so.
local ShowPlan = {}

export type Cue = { t_ms: number, slot: string, shellId: string }
export type Check = { ok: boolean, error: string?, cue: number? }

ShowPlan.LIMITS = { maxCues = 120, maxDurationS = 300 }

-- slot -> what may fire from it: "none" (no-gear shells only), "mortar:X" (that tier only), "any".
ShowPlan.DECK_SLOTS = { hand = "none", ["mortar:S"] = "mortar:S", ["mortar:M"] = "mortar:M", ["mortar:L"] = "mortar:L" }
ShowPlan.PROVING_SLOTS = {
    ["north arena"] = "any",
    ["bridge"] = "any",
    ["upper north"] = "any",
    ["mid pool"] = "any",
    ["hi west"] = "any",
    ["hanabiya roof"] = "any",
}

function ShowPlan.knownShellSet(ids: { string }): { [string]: boolean }
    local set = {}
    for _, id in ids do
        set[id] = true
    end
    return set
end

local function fail(error: string, cue: number?): Check
    return { ok = false, error = error, cue = cue }
end

local function isCue(c: any): boolean
    return type(c) == "table"
        and type(c.t_ms) == "number"
        and c.t_ms == c.t_ms -- not NaN
        and c.t_ms ~= math.huge
        and c.t_ms ~= -math.huge
        and type(c.slot) == "string"
        and type(c.shellId) == "string"
end

-- `cue` in a failure is ZERO-BASED, matching the fixture and the TypeScript twin.
function ShowPlan.validate(
    cues: any,
    stage: { [string]: string },
    shellMortar: { [string]: string },
    knownShells: { [string]: boolean }
): Check
    if type(cues) ~= "table" or #cues == 0 then
        return fail("EMPTY")
    end
    if #cues > ShowPlan.LIMITS.maxCues then
        return fail("TOO_MANY_CUES")
    end
    local last = -math.huge
    for i, c in ipairs(cues) do
        local idx = i - 1
        if not isCue(c) then
            return fail("BAD_CUE", idx)
        end
        if c.t_ms < 0 then
            return fail("NEGATIVE_TIME", idx)
        end
        if c.t_ms < last then
            return fail("CUES_OUT_OF_ORDER", idx)
        end
        last = c.t_ms
        local accepts = stage[c.slot]
        if accepts == nil then
            return fail("BAD_SLOT", idx)
        end
        if not knownShells[c.shellId] then
            return fail("BAD_SHELL", idx)
        end
        local needs = shellMortar[c.shellId]
        if accepts == "none" and needs ~= nil then
            return fail("TIER_MISMATCH", idx)
        end
        if string.sub(accepts, 1, 7) == "mortar:" and needs ~= accepts then
            return fail("TIER_MISMATCH", idx)
        end
    end
    if last > ShowPlan.LIMITS.maxDurationS * 1000 then
        return fail("TOO_LONG")
    end
    return { ok = true }
end

function ShowPlan.tally(cues: { Cue }): { [string]: number }
    local out: { [string]: number } = {}
    for _, c in cues do
        out[c.shellId] = (out[c.shellId] or 0) + 1
    end
    return out
end

return ShowPlan
```

- [ ] **Step 5: Run tests, format and lint**

Run: `cd roblox && lune run tests/run 2>&1 | tail -3 && stylua --check src tests tools && selene src tools`
Expected: all pass (1847 + the new tests), no style or lint output. If `stylua --check` fails, run `stylua src tests tools` and re-check.

- [ ] **Step 6: Commit**

```bash
git add roblox/tests/fixtures/shows.luau roblox/src/shared/ShowPlan.luau roblox/tests/ShowPlan.spec.luau
git commit -m "feat(shows): ShowPlan.luau -- the Luau validator, held to the same fixture as the server

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: `ShowPlayer.luau` — the pure timeline and per-stage scheduling

**Files:**
- Create: `roblox/src/shared/ShowPlayer.luau`
- Test: `roblox/tests/ShowPlayer.spec.luau`

**Interfaces:**
- Consumes: `ShowPlan.Cue`.
- Produces (module `ShowPlayer`):
  - `ShowPlayer.TAIL_MS = 6000`
  - `ShowPlayer.durationMs(cues): number` — last `t_ms` + `TAIL_MS`
  - `ShowPlayer.schedule(busyUntilMs: number?, nowMs: number, cues): { startAtMs: number, endAtMs: number }` — starts now if the stage is free, else the moment it frees
  - `ShowPlayer.timeline(cues, startAtMs: number): { { atMs: number, index: number, cue: Cue } }` — one entry per cue, in order, `index` one-based (Luau side; it is only used to name a cue in logs)
  - `ShowPlayer.delaysFrom(nowMs, timeline): { number }` — seconds to wait from now for each entry, never negative

- [ ] **Step 1: Write the failing test**

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local ShowPlayer = require("../src/shared/ShowPlayer")

local CUES = {
    { t_ms = 0, slot = "hand", shellId = "firecracker" },
    { t_ms = 1500, slot = "mortar:S", shellId = "peony" },
    { t_ms = 1500, slot = "mortar:M", shellId = "wa" },
    { t_ms = 4000, slot = "mortar:L", shellId = "kamuro" },
}

describe("ShowPlayer.durationMs", function()
    test("last cue plus the tail", function()
        expect(ShowPlayer.durationMs(CUES)).toBe(4000 + ShowPlayer.TAIL_MS)
    end)
    test("a one-cue show is just the tail", function()
        expect(ShowPlayer.durationMs({ CUES[1] })).toBe(ShowPlayer.TAIL_MS)
    end)
end)

describe("ShowPlayer.schedule -- one show per stage at a time", function()
    test("a free stage starts now", function()
        expect(ShowPlayer.schedule(nil, 10000, CUES)).toEqual({ startAtMs = 10000, endAtMs = 10000 + 4000 + ShowPlayer.TAIL_MS })
    end)
    test("a stage busy in the past is free", function()
        expect(ShowPlayer.schedule(9000, 10000, CUES).startAtMs).toBe(10000)
    end)
    test("a busy stage queues the show behind the current one", function()
        local s = ShowPlayer.schedule(12500, 10000, CUES)
        expect(s.startAtMs).toBe(12500)
        expect(s.endAtMs).toBe(12500 + 4000 + ShowPlayer.TAIL_MS)
    end)
end)

describe("ShowPlayer.timeline / delaysFrom", function()
    test("one entry per cue, in order, offset by the start", function()
        local tl = ShowPlayer.timeline(CUES, 5000)
        expect(#tl).toBe(4)
        expect(tl[1]).toEqual({ atMs = 5000, index = 1, cue = CUES[1] })
        expect(tl[3]).toEqual({ atMs = 6500, index = 3, cue = CUES[3] })
        expect(tl[4].atMs).toBe(9000)
    end)
    test("delays are seconds from now and never negative", function()
        local tl = ShowPlayer.timeline(CUES, 5000)
        expect(ShowPlayer.delaysFrom(5000, tl)).toEqual({ 0, 1.5, 1.5, 4 })
        expect(ShowPlayer.delaysFrom(6000, tl)).toEqual({ 0, 0.5, 0.5, 3 })
    end)
end)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd roblox && lune run tests/run 2>&1 | tail -3`
Expected: fails on the missing module.

- [ ] **Step 3: Write minimal implementation**

```lua
--!strict
-- WHEN EACH CUE FIRES. Pure: the game server owns the clock and task.delay; this module only
-- turns a show plus a start time into the moments to fire, and decides when a show may start on
-- a stage that is already playing one (spec §2.5: one show per stage at a time; a second go
-- queues behind the current show on that stage only). Testable under Lune because it never
-- touches a service.
local ShowPlayer = {}

export type Cue = { t_ms: number, slot: string, shellId: string }
export type Entry = { atMs: number, index: number, cue: Cue }

-- How long after the LAST cue a stage stays busy: enough for the tallest shell to burst and fade.
ShowPlayer.TAIL_MS = 6000

function ShowPlayer.durationMs(cues: { Cue }): number
    local last = 0
    for _, c in cues do
        if c.t_ms > last then
            last = c.t_ms
        end
    end
    return last + ShowPlayer.TAIL_MS
end

function ShowPlayer.schedule(busyUntilMs: number?, nowMs: number, cues: { Cue }): { startAtMs: number, endAtMs: number }
    local startAt = nowMs
    if busyUntilMs ~= nil and busyUntilMs > nowMs then
        startAt = busyUntilMs
    end
    return { startAtMs = startAt, endAtMs = startAt + ShowPlayer.durationMs(cues) }
end

function ShowPlayer.timeline(cues: { Cue }, startAtMs: number): { Entry }
    local out: { Entry } = {}
    for i, c in ipairs(cues) do
        table.insert(out, { atMs = startAtMs + c.t_ms, index = i, cue = c })
    end
    return out
end

function ShowPlayer.delaysFrom(nowMs: number, timeline: { Entry }): { number }
    local out = {}
    for _, e in timeline do
        table.insert(out, math.max(0, (e.atMs - nowMs) / 1000))
    end
    return out
end

return ShowPlayer
```

- [ ] **Step 4: Run tests, format and lint**

Run: `cd roblox && lune run tests/run 2>&1 | tail -3 && stylua --check src tests tools && selene src tools`
Expected: green and clean.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/ShowPlayer.luau roblox/tests/ShowPlayer.spec.luau
git commit -m "feat(shows): ShowPlayer.luau -- pure timeline and one-show-per-stage scheduling

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: The reserve endpoint and its NetworkClient call

**Files:**
- Modify: `server/src/routes/apiV1.ts` (add the route directly after `POST /players/:robloxUserId/fireworks/spend`, ~line 393)
- Test: `server/src/routes/apiV1.test.ts` (append inside `describe('fireworks', …)`)
- Modify: `roblox/src/server/NetworkClient.luau` (after `getFireworks`, ~line 215)
- Test: `roblox/tests/NetworkClient.spec.luau` (append one test, following the file's existing pattern for asserting method/path/body of a call)

**Interfaces:**
- Consumes: Task 1's `validateShow`, `tallyShells`, `shellMortar`, `DECK_STAGE`, `Cue`; the route file's existing `resolveUser`, `User`, `SHELL_IDS`.
- Produces:
  - `POST /api/v1/players/:robloxUserId/shows/reserve` body `{ show: { stageId, fuel, cues, title? } }`
    - 400 `{ error: 'BAD_SHOW' }` when `show` is not an object
    - 400 `{ error: 'FUEL_UNSUPPORTED' }` for any fuel other than `'inventory'`
    - 400 `{ error: 'BAD_STAGE' }` unless `stageId === 'deck:<robloxUserId of the path>'`
    - 400 `{ error: <ShowError>, cue? }` when validation fails
    - 409 `{ error: 'MORTAR_MISSING', slot }` when a cue's mortar slot names a tier the player does not own
    - 409 `{ error: 'INSUFFICIENT', needed: {shellId: n}, held: {shellId: n} }` when the atomic debit matches nothing
    - 200 `{ reservationId, stageId, cues, debited: {shellId: n}, remaining: {shellId: n} }`
  - `NetworkClient.postShowReserve(self, robloxUserId: string, show: any): Result` → `POST /api/v1/players/{id}/shows/reserve` with body `{ show = show }`

- [ ] **Step 1: Write the failing route tests**

Append inside `describe('fireworks', …)` in `server/src/routes/apiV1.test.ts`:

```ts
        describe('POST /players/:id/shows/reserve — a show debits everything up front, or nothing', () => {
            const show = (cues: object[], extra: object = {}) => ({
                show: { stageId: 'deck:910', fuel: 'inventory', cues, ...extra },
            });

            it('debits every shell a valid show needs in one step and reports what is left', async () => {
                await User.create({ robloxId: '910', mortars: ['mortar:S', 'mortar:M'], fireworks: { firecracker: 3, peony: 2, wa: 1 } });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/910/shows/reserve')
                    .set('X-API-Key', API_KEY)
                    .send(show([
                        { t_ms: 0, slot: 'hand', shellId: 'firecracker' },
                        { t_ms: 1000, slot: 'mortar:S', shellId: 'peony' },
                        { t_ms: 1000, slot: 'mortar:M', shellId: 'wa' },
                        { t_ms: 2000, slot: 'hand', shellId: 'firecracker' },
                    ]))
                    .expect(200);
                expect(res.body.reservationId).toMatch(/^[a-z0-9]{6,}$/);
                expect(res.body.stageId).toBe('deck:910');
                expect(res.body.debited).toEqual({ firecracker: 2, peony: 1, wa: 1 });
                expect(res.body.remaining).toEqual({ firecracker: 1, peony: 1, wa: 0 });
                const after = await User.findOne({ robloxId: '910' });
                expect(after!.fireworks.get('firecracker')).toBe(1);
                expect(after!.fireworks.get('wa')).toBe(0);
            });

            it('INSUFFICIENT debits nothing — all or nothing', async () => {
                await User.create({ robloxId: '911', mortars: ['mortar:S'], fireworks: { firecracker: 5, peony: 1 } });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/911/shows/reserve')
                    .set('X-API-Key', API_KEY)
                    .send({ show: { stageId: 'deck:911', fuel: 'inventory', cues: [
                        { t_ms: 0, slot: 'hand', shellId: 'firecracker' },
                        { t_ms: 500, slot: 'mortar:S', shellId: 'peony' },
                        { t_ms: 1000, slot: 'mortar:S', shellId: 'peony' },
                    ] } })
                    .expect(409);
                expect(res.body).toEqual({ error: 'INSUFFICIENT', needed: { firecracker: 1, peony: 2 }, held: { firecracker: 5, peony: 1 } });
                const after = await User.findOne({ robloxId: '911' });
                expect(after!.fireworks.get('firecracker')).toBe(5); // the firecracker was NOT taken
                expect(after!.fireworks.get('peony')).toBe(1);
            });

            it('refuses a mortar slot for a tier the player does not own, before debiting', async () => {
                await User.create({ robloxId: '912', mortars: ['mortar:S'], fireworks: { firecracker: 1, willow: 1 } });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/912/shows/reserve')
                    .set('X-API-Key', API_KEY)
                    .send({ show: { stageId: 'deck:912', fuel: 'inventory', cues: [
                        { t_ms: 0, slot: 'hand', shellId: 'firecracker' },
                        { t_ms: 500, slot: 'mortar:M', shellId: 'willow' },
                    ] } })
                    .expect(409);
                expect(res.body).toEqual({ error: 'MORTAR_MISSING', slot: 'mortar:M' });
                const after = await User.findOne({ robloxId: '912' });
                expect(after!.fireworks.get('firecracker')).toBe(1);
            });

            it('refuses powder fuel, other stages, malformed shows and invalid cues with the validator code', async () => {
                await User.create({ robloxId: '913', fireworks: { firecracker: 1 } });
                const app = makeApp(makeEngine(), new ResultsStore());
                const post = (body: object) => request(app).post('/api/v1/players/913/shows/reserve').set('X-API-Key', API_KEY).send(body);
                expect((await post({ show: { stageId: 'deck:913', fuel: 'powder', cues: [{ t_ms: 0, slot: 'hand', shellId: 'firecracker' }] } }).expect(400)).body.error).toBe('FUEL_UNSUPPORTED');
                expect((await post({ show: { stageId: 'rooftop', fuel: 'inventory', cues: [{ t_ms: 0, slot: 'hand', shellId: 'firecracker' }] } }).expect(400)).body.error).toBe('BAD_STAGE');
                expect((await post({ show: { stageId: 'deck:999', fuel: 'inventory', cues: [{ t_ms: 0, slot: 'hand', shellId: 'firecracker' }] } }).expect(400)).body.error).toBe('BAD_STAGE');
                expect((await post({}).expect(400)).body.error).toBe('BAD_SHOW');
                const bad = (await post({ show: { stageId: 'deck:913', fuel: 'inventory', cues: [{ t_ms: 0, slot: 'hand', shellId: 'peony' }] } }).expect(400)).body;
                expect(bad).toEqual({ error: 'TIER_MISMATCH', cue: 0 });
                const after = await User.findOne({ robloxId: '913' });
                expect(after!.fireworks.get('firecracker')).toBe(1);
            });

            it('CONCURRENT RESERVES CANNOT OVERSPEND — one conditional update per reservation', async () => {
                await User.create({ robloxId: '914', fireworks: { firecracker: 1 } });
                const app = makeApp(makeEngine(), new ResultsStore());
                const body = { show: { stageId: 'deck:914', fuel: 'inventory', cues: [{ t_ms: 0, slot: 'hand', shellId: 'firecracker' }] } };
                const [a, b] = await Promise.all([
                    request(app).post('/api/v1/players/914/shows/reserve').set('X-API-Key', API_KEY).send(body),
                    request(app).post('/api/v1/players/914/shows/reserve').set('X-API-Key', API_KEY).send(body),
                ]);
                expect([a.status, b.status].sort()).toEqual([200, 409]);
                const after = await User.findOne({ robloxId: '914' });
                expect(after!.fireworks.get('firecracker')).toBe(0);
            });
        });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/routes/apiV1.test.ts -t "shows/reserve"`
Expected: FAIL with 404s (route absent).

- [ ] **Step 3: Write the route**

Add to the imports at the top of `server/src/routes/apiV1.ts`:

```ts
import { validateShow, tallyShells, shellMortar, DECK_STAGE, Cue } from '../shows';
```

Insert after the `fireworks/spend` route:

```ts
    // A SHOW IS RESERVED BEFORE IT PLAYS (spec 2026-09-05-fireworks-show-system-design §2.1).
    // Everything the show needs is debited in ONE conditional update, so a show that cannot be
    // fully paid takes nothing — the same all-or-nothing the single-shell spend gets from its
    // conditional $inc, extended to a whole tally. Inventory fuel only here; powder is sub-project A.
    // Players may only reserve for their OWN deck (spec §3, decision 4); stations and the rooftop
    // arrive with consoles and tickets in sub-project C.
    router.post('/players/:robloxUserId/shows/reserve', async (req, res) => {
        try {
            const show = req.body?.show;
            if (typeof show !== 'object' || show === null) { res.status(400).json({ error: 'BAD_SHOW' }); return; }
            if (show.fuel !== 'inventory') { res.status(400).json({ error: 'FUEL_UNSUPPORTED' }); return; }
            if (show.stageId !== `deck:${req.params.robloxUserId}`) { res.status(400).json({ error: 'BAD_STAGE' }); return; }
            const check = validateShow(show.cues, DECK_STAGE);
            if (!check.ok) { res.status(400).json(check.cue === undefined ? { error: check.error } : { error: check.error, cue: check.cue }); return; }
            const cues = show.cues as Cue[];

            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }

            // Gear is personal: a mortar slot in the show must be a tier this player owns. Checked
            // before the debit so a show that could never launch muzzle-true takes no shells.
            const owned = new Set(user.mortars ?? []);
            for (const c of cues) {
                if (c.slot.startsWith('mortar:') && !owned.has(c.slot)) {
                    res.status(409).json({ error: 'MORTAR_MISSING', slot: c.slot });
                    return;
                }
            }

            const needed = tallyShells(cues);
            const filter: Record<string, unknown> = { _id: user._id };
            const inc: Record<string, number> = {};
            for (const [id, n] of Object.entries(needed)) {
                filter[`fireworks.${id}`] = { $gte: n };
                inc[`fireworks.${id}`] = -n;
            }
            const updated = await User.findOneAndUpdate(filter, { $inc: inc }, { new: true });
            if (!updated) {
                const held: Record<string, number> = {};
                for (const id of Object.keys(needed)) held[id] = user.fireworks?.get(id) ?? 0;
                res.status(409).json({ error: 'INSUFFICIENT', needed, held });
                return;
            }
            const remaining: Record<string, number> = {};
            for (const id of Object.keys(needed)) remaining[id] = updated.fireworks.get(id) ?? 0;
            res.json({
                reservationId: Math.random().toString(36).slice(2, 12),
                stageId: show.stageId,
                cues,
                debited: needed,
                remaining,
            });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });
```

`shellMortar` is imported for the reviewer's benefit only if used; if the implementation above does not need it, drop it from the import (unused imports are not a type error here, but keep the import list honest).

- [ ] **Step 4: Run the route tests, then the whole server suite**

Run: `cd server && npx vitest run src/routes/apiV1.test.ts -t "shows/reserve" && npm test && npx tsc --noEmit`
Expected: PASS. If a route-count or mount-order test exists and fails because a route was added, read that test — it binds to `mountRoutes`, not to a count — and fix only if it genuinely asserts something this route breaks.

- [ ] **Step 5: Write the failing NetworkClient test**

`roblox/tests/NetworkClient.spec.luau` builds fakes with its local `makeDeps(script, opts)`, which returns `f` with `f.deps` (a full `Deps`) and `f.calls` (each `{ method, url, headers, body }`), and constructs clients as `NetworkClient.new(CONFIG, f.deps)`. Append, in that shape (copy the exact `Resp` script entry form the `postThrows` test uses for a 200 with a JSON body):

```lua
describe("NetworkClient.postShowReserve", function()
    test("POSTs the show under { show = ... } to the player's reserve route", function()
        local f = makeDeps({ { ok = true, statusCode = 200, body = '{"reservationId":"abc"}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local show = { stageId = "deck:77", fuel = "inventory", cues = { { t_ms = 0, slot = "hand", shellId = "firecracker" } } }
        local res = net:postShowReserve("77", show)
        expect(res.ok).toBe(true)
        expect(res.data.reservationId).toBe("abc")
        expect(f.calls[1].method).toBe("POST")
        expect(f.calls[1].url).toBe("http://x/api/v1/players/77/shows/reserve")
        expect(f.calls[1].headers["Content-Type"]).toBe("application/json")
        expect(serde.decode("json", f.calls[1].body :: string).show.stageId).toBe("deck:77")
    end)
end)
```

- [ ] **Step 6: Run to verify it fails, implement, run again**

Run: `cd roblox && lune run tests/run 2>&1 | tail -3` — expected: the new test fails (`postShowReserve` is nil).

Add after `getFireworks` in `roblox/src/server/NetworkClient.luau`:

```lua
function NetworkClient.postShowReserve(self: any, robloxUserId: string, show: any): Result
    return self:_request("POST", `/api/v1/players/{robloxUserId}/shows/reserve`, { show = show })
end
```

Run: `cd roblox && lune run tests/run 2>&1 | tail -3 && stylua --check src tests tools && selene src tools` — expected: green and clean.

- [ ] **Step 7: Commit**

```bash
git add server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts roblox/src/server/NetworkClient.luau roblox/tests/NetworkClient.spec.luau
git commit -m "feat(shows): POST /shows/reserve debits a whole show in one conditional update, or nothing; NetworkClient.postShowReserve

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: Playback in the game server — extract the launch helpers, add `RequestShowGo`

**Files:**
- Modify: `roblox/default.project.json` (the `RoshamboRemotes` block, next to `RequestProvingFire`)
- Modify: `roblox/src/server/main.server.luau` (the `RequestFireworkLaunch` handler ~1545–1655 and new code beside it)

No Lune test can load `main.server.luau`; this task is verified in Studio (Step 6) and its pure parts were tested in Tasks 2–3. **Refactor behaviour-preservingly**: the single-shell path must produce byte-identical payloads after the extraction.

**Interfaces:**
- Consumes: `ShowPlan.validate/DECK_SLOTS/knownShellSet`, `ShowPlayer.schedule/timeline/delaysFrom`, `net:postShowReserve`, existing `deckSiteFor`, `muzzleOriginFor`, `LaunchSites.isValid`, `MortarPlacement.SHELL_MORTAR`, `BoostLuck`, `handlerQueue`, `pushFireworkState`, `FireworkCatalog`.
- Produces:
  - RemoteEvent `RequestShowGo` (client → server): `(show: { stageId, fuel, cues, title? })`
  - three local helpers in `main.server.luau`: `rollBoost(uid, shellId): boolean?`, `broadcastLaunch(fields)`, `playShow(stageKey: string, ownerUid: string, byLabel: string, cues, originFor: (cue) -> (Vector3?, Vector3?, number?), showId: string)`

- [ ] **Step 1: Add the remotes**

In `roblox/default.project.json`, after `"RequestProvingFire": { "$className": "RemoteEvent" },` add:

```json
                "RequestShowGo": { "$className": "RemoteEvent" },
                "RequestProvingShow": { "$className": "RemoteEvent" },
```

(`RequestProvingShow` is wired in Task 6; declaring both now keeps the contract edit in one place.)

- [ ] **Step 2: Extract the boost roll and the broadcast from the single-shell handler**

In `main.server.luau`, immediately above `RequestFireworkLaunch.OnServerEvent:Connect(...)`, add:

```lua
-- THE PITY RAMP, shared by every launch path (owner, 2026-09-06; math in BoostLuck): roll this
-- shell's luck against a per-player per-shell miss streak and return the VERDICT. Streaks are
-- session-lived by design. Extracted 2026-09 so a show's cues get the same bounded drought as a
-- hand launch — a show is not a way around the ramp, nor a way to be cheated by it.
local function rollBoost(uid: string, shellId: string): boolean?
    local baseChance = BoostLuck.baseChance(FireworkCatalog.RECIPES[shellId])
    if not baseChance then
        return nil
    end
    local streaks = boostMisses[uid] or {}
    boostMisses[uid] = streaks
    local verdict, newMisses = BoostLuck.roll(baseChance, streaks[shellId] or 0, math.random())
    streaks[shellId] = newMisses
    return verdict
end

-- ONE broadcast shape for every path (hand launch, proving, shows). `showId` is additive; clients
-- that do not know it ignore it. Field types are the contract FireworkController checks.
local function broadcastLaunch(fields: {
    shellId: string,
    origin: Vector3,
    heading: Vector3?,
    by: string,
    boosted: boolean?,
    apexHeight: number?,
    showId: string?,
})
    FireworkLaunched:FireAllClients({
        shellId = fields.shellId,
        origin = fields.origin,
        heading = fields.heading and { x = fields.heading.X, y = fields.heading.Y, z = fields.heading.Z } or nil,
        seed = math.random(1, 2 ^ 31 - 1),
        by = fields.by,
        boosted = fields.boosted,
        apexHeight = fields.apexHeight,
        showId = fields.showId,
    })
end
```

Then, inside the existing `RequestFireworkLaunch` handler, replace the pity-ramp block and the `FireworkLaunched:FireAllClients({...})` call with:

```lua
        local boosted = rollBoost(uid, shellId)
        broadcastLaunch({
            shellId = shellId,
            origin = origin,
            heading = heading,
            by = uid,
            boosted = boosted,
            apexHeight = publicApex,
        })
```

Nothing else in that handler changes. (The `heading` variable there is already a `Vector3?`; `publicApex` a `number?`.)

- [ ] **Step 3: Add the runner and the `RequestShowGo` handler**

Directly below the `RequestFireworkLaunch` handler, add:

```lua
-- ===== SHOWS (spec 2026-09-05-fireworks-show-system-design §2) =====
-- The server owns playback: a reserved show plays to the end on the server's clock whether or
-- not its owner is still here, and every client sees the same cues at the same moments. One show
-- per stage at a time; a second go on a busy stage queues behind it (ShowPlayer.schedule).
local RequestShowGo = remotes:WaitForChild("RequestShowGo") :: RemoteEvent
local ShowPlan = require(shared:WaitForChild("ShowPlan"))
local ShowPlayer = require(shared:WaitForChild("ShowPlayer"))
-- Every shell the client can draw: the catalogue's recipe keys (there is no separate id list on
-- this side; the fixture test asserts RECIPES covers every server id).
local KNOWN_SHELLS: { [string]: boolean } = {}
for id in FireworkCatalog.RECIPES do
    KNOWN_SHELLS[id] = true
end

local stageBusyUntilMs: { [string]: number } = {}

local function nowMs(): number
    return os.clock() * 1000
end

-- Play `cues` on `stageKey`. `originFor(cue)` resolves a cue's slot to (origin, heading, apex) at
-- FIRE time; a nil origin skips that cue with a warning rather than firing from nowhere.
local function playShow(
    stageKey: string,
    ownerUid: string,
    byLabel: string,
    cues: { ShowPlan.Cue },
    originFor: (ShowPlan.Cue) -> (Vector3?, Vector3?, number?),
    showId: string
)
    local sched = ShowPlayer.schedule(stageBusyUntilMs[stageKey], nowMs(), cues)
    stageBusyUntilMs[stageKey] = sched.endAtMs
    local timeline = ShowPlayer.timeline(cues, sched.startAtMs)
    local delays = ShowPlayer.delaysFrom(nowMs(), timeline)
    print(`[SHOW] {showId} on {stageKey} by {byLabel}: {#cues} cues, starts in {math.floor(delays[1] * 10) / 10}s`)
    for i, entry in timeline do
        task.delay(delays[i], function()
            local origin, heading, apex = originFor(entry.cue)
            if origin == nil then
                warn(`[SHOW] {showId} cue {entry.index} ({entry.cue.shellId} @ {entry.cue.slot}) had no origin; skipped`)
                return
            end
            broadcastLaunch({
                shellId = entry.cue.shellId,
                origin = origin,
                heading = heading,
                by = byLabel,
                boosted = rollBoost(ownerUid, entry.cue.shellId),
                apexHeight = apex,
                showId = showId,
            })
        end)
    end
end

-- A player's show from their OWN deck: validate (same rule the backend applies), reserve (debit
-- everything or nothing), then play. Origins are resolved per cue at fire time from the deck's
-- mortar placements; a hand cue launches from where the player stood when they pressed go, so a
-- show outlives the player walking away.
RequestShowGo.OnServerEvent:Connect(function(player, show)
    if typeof(show) ~= "table" or typeof(show.cues) ~= "table" then
        return
    end
    local uid = tostring(player.UserId)
    handlerQueue:run(uid, function()
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        if not root then
            return
        end
        local deck = deckSiteFor(uid)
        if deck == nil then
            return -- no deck, no stage (the client should not have offered go)
        end
        local pos = root.Position
        if not LaunchSites.isValid({ x = pos.X, y = pos.Y, z = pos.Z }, { deck }, uid) then
            return
        end
        local check = ShowPlan.validate(show.cues, ShowPlan.DECK_SLOTS, MortarPlacement.SHELL_MORTAR, KNOWN_SHELLS)
        if not check.ok then
            warn(`[SHOW] {uid} rejected: {check.error} cue {tostring(check.cue)}`)
            return
        end
        local body = { stageId = `deck:{uid}`, fuel = "inventory", cues = show.cues, title = show.title }
        local res = net:postShowReserve(uid, body)
        if not res.ok then
            -- Result carries `status` and `error` (and `data` when the body parsed) -- see NetworkClient.Result.
            warn(`[SHOW] {uid} reserve failed: {tostring(res.status)} {tostring(res.error)} {tostring(res.data and res.data.error)}`)
            if pushFireworkState then
                pushFireworkState(player)
            end
            return
        end
        if pushFireworkState then
            pushFireworkState(player) -- their counts just dropped by the whole show
        end
        local showId = tostring((res.data and res.data.reservationId) or `local-{math.random(1, 1e9)}`)
        local handFrame = root.CFrame
        local function originFor(cue: ShowPlan.Cue): (Vector3?, Vector3?, number?)
            if cue.slot == "hand" then
                return handFrame:PointToWorldSpace(Vector3.new(1.2, 0.6, -0.8)), nil, nil
            end
            local o, h = muzzleOriginFor(uid, Vector3.new(deck.pos.x, deck.pos.y, deck.pos.z), deck, cue.shellId)
            return o, h, nil
        end
        playShow(`deck:{uid}`, uid, uid, show.cues, originFor, showId)
    end)
end)
```

Names verified against the file at plan time: shared modules are required as `require(shared:WaitForChild("Name"))` (line ~56); `FireworkCatalog` exposes `RECIPES` only; `NetworkClient.Result` is `{ ok, data?, status?, error?, notReady?, rttMs? }`; `boostMisses` is the per-uid streak table at line ~822.

- [ ] **Step 4: Format, lint, and run the Luau suite**

Run: `cd roblox && stylua --check src tests tools && selene src tools && lune run tests/run 2>&1 | tail -3`
Expected: clean and green (the suite does not load `main.server.luau`, but stylua/selene do).

- [ ] **Step 5: Commit**

```bash
git add roblox/default.project.json roblox/src/server/main.server.luau
git commit -m "feat(shows): server-owned playback -- RequestShowGo validates, reserves, then plays a deck show through the shared launch broadcast; boost roll and broadcast extracted

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

- [ ] **Step 6: Studio check (the implementer runs this if Studio is available; otherwise it is the first item of Task 7's gate)**

With Rojo serving into the open place and the dev backend live: from a deck you own, in the server command bar, run

```lua
game.ReplicatedStorage.RoshamboRemotes.RequestShowGo:FireServer(...)
```

is client-side only, so instead run from the **client** command bar (Play Solo, switch to client):

```lua
game:GetService("ReplicatedStorage").RoshamboRemotes.RequestShowGo:FireServer({ stageId = "", fuel = "inventory", cues = {
  { t_ms = 0, slot = "hand", shellId = "firecracker" },
  { t_ms = 1500, slot = "mortar:S", shellId = "peony" },
  { t_ms = 3000, slot = "hand", shellId = "firecracker" },
} })
```

Expected: the output shows one `[SHOW] … 3 cues` line; three launches at 0, 1.5 and 3 s; the shell counts on the HUD drop by the whole show immediately; a second identical go while the first plays starts after the first's tail. A hand-only launch still works exactly as before (regression check of the extraction).

---

### Task 6: Hand-authored show drafts and the Studio-only proving verb

**Files:**
- Create: `roblox/src/shared/FireworkShows.luau`
- Test: `roblox/tests/FireworkShows.spec.luau`
- Modify: `roblox/src/server/main.server.luau` (beside the `RequestProvingFire` handler)
- Modify: `roblox/src/client/ProvingController.client.luau` (a new "Shows" section)

**Interfaces:**
- Consumes: `ShowPlan.validate/PROVING_SLOTS/LIMITS`, `ProvingPlan.RACKS`, Task 5's `playShow`, the existing proving origin code (station axis / rooftop mount), `RequestProvingShow` remote (declared in Task 5).
- Produces:
  - `FireworkShows.DRAFTS: { [name: string]: { title: string, cues: { Cue } } }` with at least `finale_v1`
  - `FireworkShows.ORDER: { string }` — display order
  - RemoteEvent `RequestProvingShow(name: string)` (Studio-gated on the server)

- [ ] **Step 1: Write the failing test**

```lua
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local FireworkShows = require("../src/shared/FireworkShows")
local ShowPlan = require("../src/shared/ShowPlan")
local ProvingPlan = require("../src/shared/ProvingPlan")
local MortarPlacement = require("../src/shared/MortarPlacement")
local shellFixture = require("./fixtures/fireworkShells")

local known = ShowPlan.knownShellSet(shellFixture.shells)

describe("FireworkShows -- every draft is a valid proving-stage show", function()
    test("ORDER names every draft exactly once", function()
        local seen = {}
        for _, name in FireworkShows.ORDER do
            expect(FireworkShows.DRAFTS[name]).toBeTruthy()
            expect(seen[name]).toBeNil()
            seen[name] = true
        end
        local n = 0
        for _ in FireworkShows.DRAFTS do
            n += 1
        end
        expect(#FireworkShows.ORDER).toBe(n)
    end)
    for name, draft in FireworkShows.DRAFTS do
        test(`{name} validates against PROVING_SLOTS with shipped shells only`, function()
            local r = ShowPlan.validate(draft.cues, ShowPlan.PROVING_SLOTS, MortarPlacement.SHELL_MORTAR, known)
            expect(r.ok).toBe(true)
        end)
        test(`{name} uses only real stations`, function()
            local racks = {}
            for _, r in ProvingPlan.RACKS do
                racks[r] = true
            end
            for _, c in draft.cues do
                expect(racks[c.slot]).toBe(true)
            end
        end)
    end
    test("finale_v1 is LARGE: it exists to stress the director", function()
        local f = FireworkShows.DRAFTS.finale_v1
        expect(#f.cues >= 80).toBe(true)
        -- at least one moment with six cues inside 300 ms -- a real volley, not a metronome
        local best = 0
        for i, c in f.cues do
            local n = 0
            for j = i, #f.cues do
                if f.cues[j].t_ms - c.t_ms <= 300 then
                    n += 1
                end
            end
            best = math.max(best, n)
        end
        expect(best >= 6).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd roblox && lune run tests/run 2>&1 | tail -3` — expected: missing module.

- [ ] **Step 3: Write the drafts**

```lua
--!strict
-- HAND-AUTHORED SHOWS for the proving verb and the A13 test (spec §10 row B). Pure data. These are
-- the first programs the sequencer plays and the first thing that puts many shells in one sky on
-- purpose; finale_v1 is deliberately dense so the director's concurrent-shell budget is exercised
-- at scale for the first time. Author here, sync with Rojo, press Play, open the proving panel.
local FireworkShows = {}

export type Cue = { t_ms: number, slot: string, shellId: string }
export type Draft = { title: string, cues: { Cue } }

local S = { "north arena", "bridge", "upper north", "mid pool", "hi west" }
local ROOF = "hanabiya roof"

local function cue(t_ms: number, slot: string, shellId: string): Cue
    return { t_ms = t_ms, slot = slot, shellId = shellId }
end

-- Build a program section: every `gapMs`, one shell round-robin across the five stations.
local function walk(startMs: number, gapMs: number, shells: { string }, count: number): { Cue }
    local out = {}
    for i = 1, count do
        table.insert(out, cue(startMs + (i - 1) * gapMs, S[((i - 1) % #S) + 1], shells[((i - 1) % #shells) + 1]))
    end
    return out
end

-- Fire `shellId` from every station (and the roof) within `spreadMs` of `atMs`.
local function volley(atMs: number, shellId: string, spreadMs: number, withRoof: boolean): { Cue }
    local out = {}
    for i, st in S do
        table.insert(out, cue(atMs + math.floor((i - 1) * spreadMs / #S), st, shellId))
    end
    if withRoof then
        table.insert(out, cue(atMs, ROOF, shellId))
    end
    return out
end

local function concat(...: { Cue }): { Cue }
    local out = {}
    for _, list in { ... } do
        for _, c in list do
            table.insert(out, c)
        end
    end
    table.sort(out, function(a, b)
        return a.t_ms < b.t_ms
    end)
    return out
end

FireworkShows.DRAFTS = {
    -- A short program to check timing by eye before anything heavy: one shell every second.
    warmup = {
        title = "Warm-up (5 shells, 1 s apart)",
        cues = walk(0, 1000, { "peony", "kiku", "wa", "rai", "willow" }, 5),
    },
    -- THE STRESS PROGRAM. ~2 minutes: an opening walk, three volleys that put six bursts in the
    -- sky inside 300 ms, a quiet middle, then a finale that stacks heavies. Shipped shells only.
    finale_v1 = {
        title = "Finale v1 (stress: volleys + heavies)",
        cues = concat(
            walk(0, 900, { "peony", "kiku", "rai" }, 15), -- 0–12.6 s: opening walk
            volley(15000, "wa", 250, true), -- 15 s: six red rings
            walk(18000, 600, { "willow", "hotaru", "banrai" }, 20), -- 18–29.4 s: faster walk
            volley(32000, "yashi", 200, true), -- 32 s
            volley(33000, "kiku", 200, false), -- 33 s: back-to-back volleys
            walk(37000, 1500, { "peony" }, 8), -- 37–47.5 s: quiet middle
            walk(52000, 400, { "wa", "rai", "kiku", "banrai" }, 20), -- 52–59.6 s: build
            volley(62000, "kamuro", 300, true), -- 62 s: heavies together — the case the budget exists for
            volley(63500, "janken", 300, false), -- 63.5 s
            volley(65000, "kamuro", 250, true), -- 65 s
            walk(68000, 300, { "hotaru", "yashi" }, 12) -- 68–71.3 s: close
        ),
    },
}

FireworkShows.ORDER = { "warmup", "finale_v1" }

return FireworkShows
```

Count check: 15 + 6 + 20 + 6 + 5 + 8 + 20 + 6 + 5 + 6 + 12 = 109 cues, under `maxCues` 120, last cue at ~71 s, well under `maxDurationS`. If the count test fails, adjust the walks, never the limits.

- [ ] **Step 4: Run to verify it passes, format, lint**

Run: `cd roblox && lune run tests/run 2>&1 | tail -3 && stylua --check src tests tools && selene src tools`
Expected: green and clean.

- [ ] **Step 5: The Studio-gated server verb**

In `main.server.luau`, first extract the proving origin resolution so the show path can reuse it. Inside the `RequestProvingFire` handler the two branches (rooftop mount vs station rack) each compute `origin`, `heading`, `apexHeight`. Move that computation into a local function placed above the handler:

```lua
-- Resolve a proving slot (a station name, or "hanabiya roof" = one random battery mount) to a
-- launch origin/heading/apex, exactly as RequestProvingFire does. Shared with RequestProvingShow.
local function provingOriginFor(rackName: string): (Vector3?, Vector3?, number?)
    if rackName == "hanabiya roof" then
        local mounts = {}
        for _, m in CollectionService:GetTagged("FireworkTubeMount") do
            if m:IsA("BasePart") then
                table.insert(mounts, m)
            end
        end
        if #mounts == 0 then
            return nil, nil, nil
        end
        local mount = mounts[math.random(1, #mounts)]
        local muzzle = mount.Size.Y / 2 + MortarPlacement.TUBE["mortar:L"].length
        return mount.CFrame:PointToWorldSpace(Vector3.new(0, muzzle + 0.2, 0)), mount.CFrame.UpVector, mount:GetAttribute("LaunchApex")
    end
    -- The existing handler's lookup, verbatim: the ProvingGround model under the proving stage folder,
    -- rack part named after the station.
    local ground = stageForProving and stageForProving:FindFirstChild("ProvingGround")
    local rack = ground and ground:FindFirstChild(rackName)
    if rack == nil or not rack:IsA("BasePart") then
        return nil, nil, nil
    end
    local axis = rack.CFrame.RightVector
    return rack.Position + axis * (rack.Size.X / 2 + 0.1), axis, rack:GetAttribute("LaunchApex")
end
```

Then make `RequestProvingFire` call `provingOriginFor(rackName)` and `broadcastLaunch({ shellId = shellId, origin = origin, heading = heading, by = "proving", boosted = if forceBoost == true then true else nil, apexHeight = apex })` instead of its two inline copies, keeping its Studio gate and its draft-id handling exactly as they are. `stageForProving` is the local the handler already uses (line ~1652); `provingOriginFor` must be declared after it.

Add the show verb beside it, with the identical Studio gate the fire verb uses:

```lua
local RequestProvingShow = remotes:WaitForChild("RequestProvingShow") :: RemoteEvent
local FireworkShows = require(shared.FireworkShows)

RequestProvingShow.OnServerEvent:Connect(function(_player, name)
    if not RunService:IsStudio() then
        return -- the same gate as RequestProvingFire: a published client's request dies here
    end
    if typeof(name) ~= "string" then
        return
    end
    local draft = FireworkShows.DRAFTS[name]
    if draft == nil then
        return
    end
    local function originFor(c: ShowPlan.Cue): (Vector3?, Vector3?, number?)
        return provingOriginFor(c.slot)
    end
    playShow("proving", "proving", "proving", draft.cues, originFor, `proving:{name}`)
end)
```

- [ ] **Step 6: The panel's "Shows" section**

In `ProvingController.client.luau`, after the shipped-shells section is built (near the `makeHeader` / `makeRow` calls that lay out modes), add a header `Shows` and one row per `FireworkShows.ORDER` entry with the draft's `title` and a single **Play** button (`makeButton(row, "Play", …)`) whose click does `RequestProvingShow:FireServer(name)`. Follow the file's existing button/row helpers exactly; no new UI primitives. Require `FireworkShows` the way the file requires `ProvingPlan`.

- [ ] **Step 7: Format, lint, suite; commit**

Run: `cd roblox && stylua --check src tests tools && selene src tools && lune run tests/run 2>&1 | tail -3`

```bash
git add roblox/src/shared/FireworkShows.luau roblox/tests/FireworkShows.spec.luau roblox/src/server/main.server.luau roblox/src/client/ProvingController.client.luau
git commit -m "feat(shows): hand-authored show drafts (warmup, finale_v1) and a Studio-only Play verb on the proving panel; proving origin resolution shared

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: Docs, the merge, and the A13 gate (owner-run)

**Files:**
- Modify: `docs/wiki/world/fireworks.md` (append an as-built section; bump `updated:`)
- Modify: `docs/wiki/log.md` (append a `ship` entry)

- [ ] **Step 1: `docs/wiki/world/fireworks.md`** — append:

```markdown
## Shows and the sequencer (sub-project B, built 2026-09)

Spec `docs/superpowers/specs/2026-09-05-fireworks-show-system-design.md` §1–§3; plan
`docs/superpowers/plans/2026-09-05-fireworks-shows-sequencer.md`.

**A show is data**: cues of `{ t_ms, slot, shellId }`, validated by twins held to
`shared-fixtures/shows.json` (`server/src/shows.ts`, `roblox/src/shared/ShowPlan.luau`). Limits
are config (`SHOW_LIMITS` / `ShowPlan.LIMITS`: read them, do not quote them). **Reserve, then
play**: `POST /api/v1/players/:id/shows/reserve` debits every shell in ONE conditional update or
nothing (inventory fuel only — powder is sub-project A; deck stage only — the rooftop and stations
arrive with consoles in C). The game server plays a reserved show on its own clock
(`ShowPlayer.luau` timing; one show per stage, a second queues behind), emitting each cue through
the same `FireworkLaunched` broadcast as a hand launch, with `showId` added and the pity ramp
applied per cue. Playback outlives the owner leaving.

**Studio-only proving verb**: the proving panel's *Shows* section plays `FireworkShows.DRAFTS`
(`warmup`, `finale_v1`) from the five stations and the rooftop battery. `finale_v1` is the stress
program — volleys of six inside 300 ms and stacked heavies — authored to exercise the director's
concurrent-shell budget at scale for the first time.

**The A13 gate — measure, don't assume.** Run `finale_v1` from the panel with the A13 joined to the
same server, standing at the arena square and again at a west teahouse. Record: frame-rate
behaviour during the 15 s, 32–33 s and 62–65 s volleys; whether bursts are visibly staggered
(expected: yes, by a few hundred ms) or dropped (never expected); audio reach. Park the bench per
the standing rule. Result: **not yet run** at merge — this line is the live fact.
```

- [ ] **Step 2: `docs/wiki/log.md`** — append:

```markdown
## [2026-09-0X] ship | Fireworks shows + sequencer (sub-project B): shows are data, reserved atomically, played by the server

Plan `docs/superpowers/plans/2026-09-05-fireworks-shows-sequencer.md`. Shared fixture
`shared-fixtures/shows.json` with TS/Luau twins; `POST /shows/reserve` (all-or-nothing, inventory
fuel, own deck only); `ShowPlayer.luau`; `RequestShowGo` playback through `FireworkLaunched` with
`showId`; boost roll, broadcast and proving origin resolution extracted and shared; `FireworkShows`
drafts and the panel's Studio-only Play verb. The A13 stress run (`finale_v1`) is the exit gate and
is owner-run; result recorded on [[fireworks]] when it happens.
```

(Replace `0X` with the actual day.)

- [ ] **Step 3: Lint, commit, push the branch, CI**

Run from the repo root: `node tools/wiki/lint.mjs | tail -1` (count must not rise).

```bash
git add docs/wiki/world/fireworks.md docs/wiki/log.md
git commit -m "docs(wiki): fireworks shows + sequencer as-built; the A13 gate as a live fact

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
git fetch origin && git push -u origin thread/shows
```

Confirm `server-ci` and `roblox-ci` are green on the branch before reporting.

- [ ] **Step 4: STOP — the owner's part**

Report to the owner: the branch, the CI links, the Studio check from Task 5 Step 6 (done or not), and the A13 procedure above. The owner runs the gate in Play with the A13; the finishing-a-development-branch skill presents the merge options. Do not merge `thread/shows` yourself; the terminal session owns `main` for code ([[parallel-threads]]).

---

## Self-review against the spec

- §1 show format, limits as config, shared validation with a fixture, fire-now as a one-cue show on the same path: Tasks 1–2 (format, fixture, twins); Task 5 (a one-cue show is just a show — no second path). ✔
- §2 reserve everything up front / once lit lit: Task 4 (single conditional update, 409 debits nothing); playback on the server's clock through `FireworkLaunched` with `by` + `showId`: Task 5; director untouched: Task 5 adds no throttling; owner leaves → continues: `task.delay` closures capture the deck frame, not the player; one show per stage, queued behind: Task 3 `schedule` + Task 5 `stageBusyUntilMs`. ✔
- §3 deck stage owner-only, rooftop/stations not reachable by players yet: Task 4 `BAD_STAGE`, Task 5 deck-only; proving slots only via the Studio gate: Task 6. ✔
- §10 row B deliverables: format+fixture (T1–2), `ShowPlayer` (T3), reserve (T4), playback (T5), proving verb + drafts (T6), the A13 test (T7 gate). ✔
- §12 testing: seal-type tests are sub-project A (no powder here); reserve atomicity, concurrency, validator cases both sides, timeline, drafts validity: present. ✔
- Type consistency: `Cue { t_ms, slot, shellId }` identical in TS and Luau; validator error codes identical; `cue` index zero-based on both sides (Task 2 note); `ShowPlayer.schedule(busyUntilMs?, nowMs, cues)` used the same way in Task 5; `broadcastLaunch` field names match the client's checks (`origin: Vector3`, `seed: number`, `shellId: string`). ✔
- Placeholders: none. Two "read the file for the exact name" instructions remain (the shared-module `require` form and `Result` field names in Task 5, the rack lookup in Task 6) because the file is 1700+ lines and the names must be copied, not guessed; each says exactly what to look for.
