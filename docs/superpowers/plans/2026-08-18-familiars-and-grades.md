# Familiars and Grades Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every player one small bird that reads the round result — rises on a win, perches on a safe, startles on a loss — and wears their grade, earned from milestones.

**Architecture:** A pure milestone module scored at settlement against rows the server already writes; grade is a pure function of the count. The Roblox server broadcasts a small roster so plumage is visible to everyone, and a client controller owns one CFrame-lerped bird per present player, gated on `drumRest`.

**Tech Stack:** TypeScript + Mongoose + Vitest (server); Luau + the Lune harness (Roblox). No new dependencies, no new data capture.

**Spec:** `docs/superpowers/specs/2026-08-18-familiars-and-grades-design.md`

## Global Constraints

- **EVERY BIRD REACTION GATES ON `drumRest`.** `RevealTheater` lands ~3.45s before the throw drum settles. Petals spoil a round for their owner; **a bird visible across the arena spoils it for everyone watching that player.** Follow `TheaterController.client.luau`'s existing gate — do not schedule off `RevealTheater` arrival.
- **A milestone is EARN-ONCE and MONOTONIC.** Persist with `$addToSet` so re-running settlement cannot duplicate or revoke. **Never derive one from `totalPoints`** — it is a wallet, decremented by purchases, so the milestone would be revoked by shopping. `bestPot` (`$max`) and `lifetimeBanked` (never decreases) are the safe bases.
- **The client computes NO rules.** The wire carries `grade` (1–15), `gradeName` and `band` (1–5). ⚠ This **overrides spec §6's** "held to a fixture in `shared-fixtures/`" — that directory exists for cross-language parity, and there is no second implementation of milestone rules. A table-driven test in TypeScript is the honest equivalent; a shared fixture with one implementation is cargo cult. The catalog stays server-side data.
- **No Humanoid, no physics.** One anchored part per bird, CFrame-lerped from a pure function, with distance LOD. This is the 2026-07-04 metagame spec's own prescription.
- Luau: `stylua src tests tools` and `selene src tools` must pass (selene's scope excludes `tests`). Server: `npm test` in `server/`.
- ⚠ **A new RemoteEvent needs a Rojo RESTART, not a reconnect** — `default.project.json` is read once at `rojo serve` startup.

---

## File Structure

| file | responsibility | change |
|---|---|---|
| `server/src/engine/Milestones.ts` | the catalog, `earnedFor`, `gradeFor` | **create** |
| `server/src/models/User.ts` | user document | + `milestones: string[]` |
| `server/src/engine/Settlement.ts` | per-player persistence | + evaluate and `$addToSet` |
| `server/src/routes/apiV1.ts` | the join call | + `grade`, `gradeName`, `band`, `milestones` |
| `roblox/src/shared/ChoreographyMachine.luau` | reveal cue construction | + `result` on the consequence cue |
| `roblox/src/shared/BirdFlight.luau` | pure flight math | **create** |
| `roblox/src/client/BirdController.client.luau` | one bird per present player | **create** |
| `roblox/src/server/main.server.luau` | roster broadcast | + `FamiliarRoster` |
| `roblox/default.project.json` | remotes | + `FamiliarRoster` |
| `roblox/src/client/TheaterController.client.luau` | reveal effects | retire the disc, fix a stale comment |

---

### Task 1: The milestone catalog and the grade ladder

**Files:**
- Create: `server/src/engine/Milestones.ts`
- Test: `server/src/engine/Milestones.test.ts`

**Interfaces:**
- Produces: `earnedFor(stats: MilestoneStats): string[]`, `gradeFor(count: number): Grade`
  where `MilestoneStats = { bestPot, lifetimeBanked, bestStreak, weekThrows, hasBanked, hasWon }`
  and `Grade = { index: number, name: string, band: number }`

- [ ] **Step 1: Write the failing tests**

```ts
import { describe, it, expect } from 'vitest';
import { earnedFor, gradeFor, CATALOG } from './Milestones';

const NOTHING = { bestPot: 0, lifetimeBanked: 0, bestStreak: 0, weekThrows: 0, hasBanked: false, hasWon: false };

describe('milestones — powers generate the ladder without hand-authoring it', () => {
    it('awards every pot threshold at or below what was reached', () => {
        const ids = earnedFor({ ...NOTHING, bestPot: 27 });
        expect(ids).toContain('pot.9');
        expect(ids).toContain('pot.27');
        expect(ids).not.toContain('pot.81');
    });

    it('awards every career threshold at or below what was banked', () => {
        const ids = earnedFor({ ...NOTHING, lifetimeBanked: 1500 });
        expect(ids).toContain('career.100');
        expect(ids).toContain('career.1000');
        expect(ids).not.toContain('career.10000');
    });

    it('awards streak milestones from the BEST streak, which never decreases', () => {
        expect(earnedFor({ ...NOTHING, bestStreak: 5 })).toEqual(
            expect.arrayContaining(['run.3', 'run.5'])
        );
    });

    it('a brand new player has earned nothing at all', () => {
        expect(earnedFor(NOTHING)).toEqual([]);
    });

    it('every id in the catalog is unique — a duplicate would double-count a grade', () => {
        const ids = CATALOG.map(m => m.id);
        expect(new Set(ids).size).toBe(ids.length);
    });
});

describe('the grade ladder', () => {
    it('starts at 10th kyu and reaches it on the first milestone — acknowledge a player before they leave', () => {
        expect(gradeFor(0).name).toBe('unranked');
        expect(gradeFor(1).name).toBe('10th kyu');
    });

    it('counts kyu DOWN then dan UP, fifteen grades, never past 5th dan', () => {
        const names = Array.from({ length: 400 }, (_, i) => gradeFor(i).name);
        expect(names).toContain('1st kyu');
        expect(names).toContain('1st dan');
        expect(names[names.length - 1]).toBe('5th dan');
        expect(new Set(names).size).toBe(16); // 15 grades + unranked
    });

    it('never goes backwards as milestones accumulate', () => {
        let last = -1;
        for (let n = 0; n < 400; n++) {
            const i = gradeFor(n).index;
            expect(i).toBeGreaterThanOrEqual(last);
            last = i;
        }
    });

    it('maps fifteen grades onto five plumage bands, because fifteen birds cannot be told apart', () => {
        const bands = new Set(Array.from({ length: 400 }, (_, i) => gradeFor(i).band));
        expect(bands.size).toBeLessThanOrEqual(5);
    });
});
```

- [ ] **Step 2: Run them and watch them fail**

Run: `cd server && npx vitest run src/engine/Milestones.test.ts`
Expected: FAIL — cannot resolve `./Milestones`

- [ ] **Step 3: Implement**

```ts
// THE CATALOG IS DATA, AND TWO FAMILIES ARE POWERS. Depth and Career generate new milestones
// indefinitely without anyone hand-authoring a hundred achievements, and their spacing gets
// naturally harder exactly where the ladder does.
//
// EARN-ONCE AND MONOTONIC, both of them: `bestPot` is kept via `$max` and `lifetimeBanked` never
// decreases. NEVER build one on `totalPoints` — it is a wallet and is decremented by purchases,
// so the milestone would be revoked by shopping.
export interface MilestoneStats {
    bestPot: number;
    lifetimeBanked: number;
    bestStreak: number;
    weekThrows: number;
    hasBanked: boolean;
    hasWon: boolean;
}

export interface Milestone {
    id: string;
    earned: (s: MilestoneStats) => boolean;
}

const POT_STEPS = [9, 27, 81, 243, 729, 2187, 6561, 19683];
const CAREER_STEPS = [100, 1000, 10000, 100000, 1000000];
const RUN_STEPS = [3, 5, 7, 10];

export const CATALOG: Milestone[] = [
    { id: 'first.win', earned: s => s.hasWon },
    { id: 'first.bank', earned: s => s.hasBanked },
    { id: 'presence.qualified', earned: s => s.weekThrows >= 360 },
    ...POT_STEPS.map(n => ({ id: `pot.${n}`, earned: (s: MilestoneStats) => s.bestPot >= n })),
    ...CAREER_STEPS.map(n => ({ id: `career.${n}`, earned: (s: MilestoneStats) => s.lifetimeBanked >= n })),
    ...RUN_STEPS.map(n => ({ id: `run.${n}`, earned: (s: MilestoneStats) => s.bestStreak >= n })),
];

export function earnedFor(stats: MilestoneStats): string[] {
    return CATALOG.filter(m => m.earned(stats)).map(m => m.id);
}

export interface Grade {
    index: number;
    name: string;
    band: number;
}

// KYU COUNTS DOWN, THEN DAN COUNTS UP, hinged at 1st dan as a real event. Thresholds widen as you
// climb, so 10th kyu lands on a player's first evening and 1st dan stays uncommon. Fifteen grades:
// judo's upper dan are largely honorary, so this stops at 5th.
const NAMES = [
    '10th kyu', '9th kyu', '8th kyu', '7th kyu', '6th kyu',
    '5th kyu', '4th kyu', '3rd kyu', '2nd kyu', '1st kyu',
    '1st dan', '2nd dan', '3rd dan', '4th dan', '5th dan',
];
const THRESHOLDS = [1, 2, 3, 4, 6, 8, 10, 13, 16, 19, 23, 27, 31, 35, 40];

export function gradeFor(count: number): Grade {
    let index = 0;
    for (let i = 0; i < THRESHOLDS.length; i++) {
        if (count >= THRESHOLDS[i]) index = i + 1;
    }
    // FIVE BANDS, NOT FIFTEEN. Fifteen visually distinct birds is neither achievable nor legible
    // across an arena; five is. The exact grade is printed where there is room for it — the slip
    // in the vestibule and the teahouse banner — and the bird carries only the band.
    const band = index === 0 ? 0 : Math.min(5, Math.ceil(index / 3));
    return { index, name: index === 0 ? 'unranked' : NAMES[index - 1], band };
}
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: `cd server && npx vitest run src/engine/Milestones.test.ts`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/src/engine/Milestones.ts server/src/engine/Milestones.test.ts
git commit -m "feat(server): milestones and the grade ladder"
```

---

### Task 2: Earn them at settlement, and put the grade on the wire

**Files:**
- Modify: `server/src/models/User.ts`, `server/src/engine/Settlement.ts`, `server/src/routes/apiV1.ts`
- Test: `server/src/engine/Settlement.test.ts`, `server/src/routes/apiV1.test.ts`

**Interfaces:**
- Consumes: `earnedFor`, `gradeFor` (Task 1)
- Produces: `User.milestones: string[]`; `GET /api/v1/players/:robloxUserId` gains `grade`, `gradeName`, `band`, `milestones`

- [ ] **Step 1: Write the failing tests**

In `Settlement.test.ts` (match the file's existing round-building helpers):

```ts
// R beats S. Seeding pointsAtStake: 3 means this win takes the pot to 9 and earns `pot.9`
// in the same round it is reached — which is the behaviour "from the post-write state" means.
const winsToNine = (roundId: string) => settleRound({
    roundId,
    worldThrow: 'S',
    counts: { R: 1, P: 1, S: 1 },
    throws: throwsMap([
        ['pwa:devA', { throw: 'R', seq: 1, platform: 'pwa', deviceId: 'devA' }],
        ['roblox:77', { throw: 'S', seq: 1, platform: 'roblox', robloxUserId: '77', instanceId: 'job-1' }],
        ['roblox:88', { throw: 'P', seq: 1, platform: 'roblox', robloxUserId: '88', instanceId: 'job-1' }],
    ]),
    timestamp: new Date(),
});

it('awards milestones at settlement, from the post-write state', async () => {
    const user = await User.create({ deviceId: 'devA', pointsAtStake: 3 });
    await winsToNine('r1');
    const after = await User.findById(user._id);
    expect(after?.milestones).toContain('first.win');
    expect(after?.milestones).toContain('pot.9');
});

it('never awards the same milestone twice, however many rounds settle', async () => {
    const user = await User.create({ deviceId: 'devA', pointsAtStake: 3 });
    await winsToNine('r1');
    await winsToNine('r2');
    const ids = (await User.findById(user._id))?.milestones ?? [];
    expect(new Set(ids).size).toBe(ids.length);
});
```

In `apiV1.test.ts`:

```ts
it('carries the grade on the join call, so other clients can render plumage', async () => {
    await User.create({ robloxId: '12345', identityTier: 'roblox', milestones: ['first.win', 'pot.9'] });
    const app = makeApp(makeEngine(), new ResultsStore());
    const res = await request(app).get('/api/v1/players/12345').set('X-API-Key', API_KEY).expect(200);
    expect(res.body.grade).toBe(2);
    expect(res.body.gradeName).toBe('9th kyu');
    expect(res.body.band).toBe(1);
});
```

- [ ] **Step 2: Run them and watch them fail**

Run: `cd server && npx vitest run src/engine/Settlement.test.ts src/routes/apiV1.test.ts`
Expected: FAIL — `milestones` is undefined

- [ ] **Step 3: Add the field**

In `server/src/models/User.ts`, beside the other counters:

```ts
    // EARNED, NEVER REVOKED. Append-only via $addToSet, so settling the same round twice cannot
    // duplicate an id and nothing a player does — including spending every point they own — can
    // take a grade away. That is the whole reason grade is built on milestones rather than on a
    // rate or on time played.
    milestones: string[];
```

and in the schema: `milestones: { type: [String], default: [] },`

- [ ] **Step 4: Award them at settlement**

In `Settlement.ts`, immediately after the `findByIdAndUpdate` that produces `updated`:

```ts
                // AGAINST THE POST-WRITE STATE. `updated` already carries this round's bestPot,
                // lifetimeBanked and bestStreak, so a pot reached THIS round earns its milestone
                // now rather than one round late.
                const earned = earnedFor({
                    bestPot: updated.bestPot || 0,
                    lifetimeBanked: updated.lifetimeBanked || 0,
                    bestStreak: updated.bestStreak || 0,
                    // Windowed presence is NOT known here and is not worth a per-player query on
                    // every round; `presence.qualified` is awarded on the join call instead, in
                    // Step 5, where the user is already loaded and `throwsInWindow` is one call.
                    weekThrows: 0,
                    hasBanked: (updated.lifetimeBanked || 0) > 0,
                    hasWon: result === 'WIN' || (updated.bestStreak || 0) > 0,
                });
                const fresh = earned.filter(id => !(updated.milestones || []).includes(id));
                if (fresh.length > 0) {
                    await User.findByIdAndUpdate(user._id, { $addToSet: { milestones: { $each: fresh } } });
                }
```

- [ ] **Step 5: Award the windowed milestone, and put the grade on the join call**

`presence.qualified` is the one milestone that needs a WINDOW, which settlement deliberately does
not query per player per round. The join call already has the user loaded, so it costs one call
there and is checked once per session rather than sixty times an hour.

In `apiV1.ts`'s `GET /players/:robloxUserId`, before building the response:

```ts
            // THE ONE WINDOWED MILESTONE. Awarded here rather than at settlement because it needs
            // a 7-day throw count, and settling a round must not run a per-player aggregation for
            // every participant. Once earned it is permanent like every other one — a player who
            // qualifies one week and then plays less does not lose it.
            if (!(user.milestones || []).includes('presence.qualified')) {
                const w = rollingWindow(new Date(), WEEK_MS);
                if ((await throwsInWindow(user._id, w)) >= QUALIFY.week) {
                    await User.findByIdAndUpdate(user._id, { $addToSet: { milestones: 'presence.qualified' } });
                    user.milestones = [...(user.milestones || []), 'presence.qualified'];
                }
            }
            const grade = gradeFor((user.milestones || []).length);
```

then beside `displayName`:

```ts
                grade: grade.index,
                gradeName: grade.name,
                band: grade.band,
                milestones: user.milestones || [],
```

Add the imports (`gradeFor`, `throwsInWindow`, `rollingWindow`, `WEEK_MS`, `QUALIFY`).

- [ ] **Step 6: Run the tests and watch them pass**

Run: `cd server && npm test`
Expected: PASS, whole server suite

- [ ] **Step 7: Commit**

```bash
git add server/src
git commit -m "feat(server): milestones are earned at settlement and ride the join call"
```

---

### Task 3: The consequence cue carries the result

**Files:**
- Modify: `roblox/src/shared/ChoreographyMachine.luau`
- Test: `roblox/tests/ChoreographyMachine.spec.luau`

**Interfaces:**
- Produces: `cue.result` (`"WIN" | "SAFE" | "LOSS"`) on every `consequence` cue

- [ ] **Step 1: Write the failing test**

```lua
test("a consequence cue names the RESULT, not just the effect it selected", function()
    -- LOSS selects nil from an empty pool, so a listener that inferred the outcome from the
    -- effect could not tell a loss from an unknown effect -- and it would be coupled to the
    -- effect catalog, which is exactly what EffectRegistry exists to prevent.
    local cues = ChoreographyMachine.revealCues({
        worldThrow = "R",
        results = { ["1"] = { result = "LOSS" }, ["2"] = { result = "WIN" } },
    }, { random = function() return 0 end, staggerMaxMs = 0, selectEffect = function() return nil end })
    local seen = {}
    for _, c in cues do
        if c.kind == "consequence" then
            seen[c.userId] = c.result
        end
    end
    expect(seen["1"]).toBe("LOSS")
    expect(seen["2"]).toBe("WIN")
end)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `result` is nil

- [ ] **Step 3: Add the field**

In `ChoreographyMachine.luau`, in the consequence cue:

```lua
            kind = "consequence",
            userId = userId,
            -- THE RESULT TRAVELS, not just the effect chosen from it. An effect is swappable data
            -- (that is what EffectRegistry is for) and LOSS's pool is empty, so a listener reading
            -- the effect cannot distinguish a loss from an unknown effect. `r.result` is already
            -- in hand; carrying it decouples every consumer from the effect catalog.
            result = r.result,
            effect = opts.selectEffect(r.result, { worldThrow = reveal.worldThrow }),
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: `cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/ChoreographyMachine.luau roblox/tests/ChoreographyMachine.spec.luau
git commit -m "feat(roblox): a consequence cue names the result, not just its effect"
```

---

### Task 4: The flight math

**Files:**
- Create: `roblox/src/shared/BirdFlight.luau`
- Test: `roblox/tests/BirdFlight.spec.luau`

**Interfaces:**
- Produces: `BirdFlight.offsetFor(state: string, elapsed: number, seed: number): Vector3`,
  `BirdFlight.DURATION: { [string]: number }`, `BirdFlight.stateAfter(state, elapsed): string`

- [ ] **Step 1: Write the failing tests**

```lua
local BirdFlight = require("../src/shared/BirdFlight")

describe("BirdFlight", function()
    test("idle orbits without drifting away", function()
        for t = 0, 10, 0.25 do
            local o = BirdFlight.offsetFor("IDLE", t, 7)
            expect(o.Magnitude < 6).toBe(true)
        end
    end)

    test("WIN rises — the only state whose height increases", function()
        local a = BirdFlight.offsetFor("WIN", 0.1, 7)
        local b = BirdFlight.offsetFor("WIN", 1.5, 7)
        expect(b.Y > a.Y).toBe(true)
    end)

    test("SAFE settles onto a perch and STAYS there", function()
        local a = BirdFlight.offsetFor("SAFE", 1.5, 7)
        local b = BirdFlight.offsetFor("SAFE", 2.0, 7)
        expect((a - b).Magnitude < 0.05).toBe(true)
        expect(a.Y < 3).toBe(true) -- shoulder height, not overhead
    end)

    test("LOSS darts away and comes back", function()
        local away = BirdFlight.offsetFor("LOSS", 0.5, 7)
        local back = BirdFlight.offsetFor("LOSS", BirdFlight.DURATION.LOSS, 7)
        local idle = BirdFlight.offsetFor("IDLE", BirdFlight.DURATION.LOSS, 7)
        expect(away.Magnitude > 8).toBe(true)
        expect((back - idle).Magnitude < 1.5).toBe(true)
    end)

    test("every state returns to IDLE when its beat is over", function()
        for _, s in { "WIN", "SAFE", "LOSS" } do
            expect(BirdFlight.stateAfter(s, BirdFlight.DURATION[s] + 0.01)).toBe("IDLE")
            expect(BirdFlight.stateAfter(s, 0.1)).toBe(s)
        end
    end)

    test("is deterministic per seed, so two clients render the same bird", function()
        expect(BirdFlight.offsetFor("IDLE", 3.3, 7)).toBe(BirdFlight.offsetFor("IDLE", 3.3, 7))
        expect(BirdFlight.offsetFor("IDLE", 3.3, 7) ~= BirdFlight.offsetFor("IDLE", 3.3, 8)).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run them and watch them fail**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — cannot resolve `BirdFlight`

- [ ] **Step 3: Implement**

Pure: no `game`, no service, no `os.clock`. Every value is a function of `(state, elapsed, seed)` so the same bird renders identically on every client and the whole thing is testable under Lune.

```lua
--!strict
-- WHERE THE BIRD IS, as a pure function of state, time and a per-player seed. No Roblox service
-- and no randomness at call time: two clients watching the same player must draw the same bird,
-- and Lune must be able to check the curves without a DataModel.
local BirdFlight = {}

BirdFlight.DURATION = { WIN = 3.0, SAFE = 2.6, LOSS = 2.0 }

local ORBIT_R = 2.6
local ORBIT_Y = 3.2
local ORBIT_SPEED = 1.1

local function orbit(t: number, seed: number, radius: number, y: number): Vector3
    local a = t * ORBIT_SPEED + seed
    return Vector3.new(math.cos(a) * radius, y + math.sin(a * 1.7) * 0.25, math.sin(a) * radius)
end

function BirdFlight.stateAfter(state: string, elapsed: number): string
    local d = BirdFlight.DURATION[state]
    if not d or elapsed > d then
        return "IDLE"
    end
    return state
end

function BirdFlight.offsetFor(state: string, elapsed: number, seed: number): Vector3
    if state == "WIN" then
        -- RISES, and rising is the whole grammar: the space above a head is the only region never
        -- occluded by another avatar, so height is what survives a crowd on a small screen.
        local k = math.min(1, elapsed / BirdFlight.DURATION.WIN)
        return orbit(elapsed * 2.2, seed, ORBIT_R * (1 + k), ORBIT_Y + k * 5.5)
    elseif state == "SAFE" then
        -- SETTLES AND STAYS. A landed bird is unmistakable, and "nothing changed, you are fine" is
        -- exactly what perching says. Eased so the landing reads rather than snapping.
        local k = math.min(1, elapsed / 1.2)
        local ease = 1 - (1 - k) * (1 - k)
        local perch = Vector3.new(0.9, 1.6, 0.35)
        return orbit(elapsed, seed, ORBIT_R, ORBIT_Y):Lerp(perch, ease)
    elseif state == "LOSS" then
        -- DARTS OFF AND COMES BACK: the pot was lost, not the companion. Out fast, back slower,
        -- landing exactly on the idle orbit so there is no snap when the state expires.
        local d = BirdFlight.DURATION.LOSS
        local k = math.min(1, elapsed / d)
        local away = orbit(elapsed, seed, 14, ORBIT_Y + 3)
        local home = orbit(elapsed, seed, ORBIT_R, ORBIT_Y)
        return if k < 0.4 then home:Lerp(away, k / 0.4) else away:Lerp(home, (k - 0.4) / 0.6)
    end
    return orbit(elapsed, seed, ORBIT_R, ORBIT_Y)
end

return BirdFlight
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: `cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/BirdFlight.luau roblox/tests/BirdFlight.spec.luau
git commit -m "feat(roblox): the bird's flight, as pure math"
```

---

### Task 5: The roster on the wire

**Files:**
- Modify: `roblox/default.project.json`, `roblox/src/server/main.server.luau`

**Interfaces:**
- Produces: `FamiliarRoster` RemoteEvent carrying `{ [userId] = { grade, gradeName, band } }`
- Consumes: `grade`/`band` from `getPlayer` (Task 2)

- [ ] **Step 1: Declare the remote**

In `roblox/default.project.json`, inside `RoshamboRemotes`:

```json
                "FamiliarRoster": { "$className": "RemoteEvent" },
```

⚠ **RESTART `rojo serve` after this.** `default.project.json` is read once at startup; a reconnect will not create the instance and the controller will hang on `WaitForChild`.

- [ ] **Step 2: Broadcast it**

In `main.server.luau`: keep a `familiarRoster: { [string]: any }` table. Populate a player's entry from the `getPlayer` response already fetched on join (it now carries `grade`, `gradeName`, `band`), fire the whole roster to all clients on join and on leave, and re-fire when a settlement changes anyone's grade.

```lua
-- THE WHOLE ROSTER, NOT A DELTA. It is one small table for the players actually present, it is
-- sent on events that are already rare (join, leave, a grade change), and a late-joining client
-- needs the full picture anyway. A delta protocol here would be complexity bought with nothing.
local function pushFamiliarRoster()
    FamiliarRoster:FireAllClients(familiarRoster)
end
```

- [ ] **Step 3: Verify it in Studio**

Run `rojo serve` fresh, reconnect, Play, and confirm `ReplicatedStorage.RoshamboRemotes.FamiliarRoster` exists and a roster arrives.

- [ ] **Step 4: Commit**

```bash
git add roblox/default.project.json roblox/src/server/main.server.luau
git commit -m "feat(roblox): broadcast the familiar roster so plumage is social"
```

---

### Task 6: The bird

**Files:**
- Create: `roblox/src/client/BirdController.client.luau`

**Interfaces:**
- Consumes: `BirdFlight` (Task 4), `FamiliarRoster` (Task 5), `EventBus.Cue` and the `drumRest` gate

- [ ] **Step 1: Build it**

No unit test: this file is Roblox-runtime rendering, and the logic worth testing is already pure in `BirdFlight`. Follow `LanternController.client.luau` for the drum gate and `TheaterController.client.luau` for cue subscription.

Requirements, each load-bearing:

1. **One bird per PRESENT player**, created on `PlayerAdded`/roster arrival and destroyed on `PlayerRemoving`. An anchored, `CanCollide = false`, `CanQuery = false` part parented to a dedicated folder — never to the character, which respawns.
2. **Driven from `RenderStepped`**, position = character root CFrame × `BirdFlight.offsetFor(state, elapsed, seed)`. Seed from the userId so it is stable and differs per player.
3. ⚠ **REACTIONS GATE ON `drumRest`.** Subscribe to `EventBus.Cue`, read `cue.result` (Task 3), and **hold it** until the drum rests, exactly as `TheaterController` does. A bird that celebrates on `RevealTheater` arrival announces the round ~3.45s early — and it is visible to everyone watching that player, not just its owner.
4. **Plumage from the roster's `band`**: colour saturation, tail-streamer length, crest, and a night glow driven off the existing `nightFactor` attribute.
5. **Distance LOD**: beyond a threshold, stop the per-frame update and fall back to a billboard; beyond a second, hide entirely. Both distances are Studio-gate numbers — put them in named constants with a comment saying they are unmeasured.

- [ ] **Step 2: Verify in Studio**

Two clients, one Play session. Confirm both see the same bird on the same player, that a win rises and a safe perches, and that **nothing moves before the drum settles**.

- [ ] **Step 3: Commit**

```bash
git add roblox/src/client/BirdController.client.luau
git commit -m "feat(roblox): every player gets a bird that reads the round"
```

---

### Task 7: Retire what the bird replaces

**Files:**
- Modify: `roblox/src/client/TheaterController.client.luau`, `roblox/src/shared/EffectRegistry.luau`

- [ ] **Step 1: Remove the disc and correct the record**

- **Delete `umbrellaPop` and its `umbrella()` function.** It draws one flat cylinder above the head with no ribs, shaft or canopy curve; the owner read it as a cloud, which is the correct reading of a featureless disc. The bird's perch now carries SAFE. Remove the entry from `EffectRegistry.SAFE` too.
- **Keep `growPetals`.** Petals were never the problem — being the *only* thing was. They stay as a win flourish alongside the bird.
- **Fix the stale comment.** `petals(character)` is annotated *"the grow itself is server-side (replicated scale)"*. `applyGrow` was deleted; `main.server.luau:384` still refers to "the recipe the deleted applyGrow used". Replace with a line saying the grow is gone and the bird's rise replaces it.

- [ ] **Step 2: Run everything**

Run: `cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools`
Expected: PASS — `EffectSelector.spec.luau` pins the pools, so an empty `SAFE` may need its expectation updated deliberately.

- [ ] **Step 3: Commit**

```bash
git add roblox/src
git commit -m "fix(roblox): retire the disc that read as a cloud"
```

---

## Studio gate — the owner looks

**Not a task.** Two clients in one Play session, and the `nightFactor` cycle at dusk.

1. **Does a win read as a win from across the arena**, on another player, without looking at the HUD?
2. **Does the perch land?** It is the state that replaces the misread disc; if it does not read as a bird sitting down, this has not worked.
3. **Nothing may move before the drum settles.** Watch another player's bird through a full reveal.
4. **Plumage bands** — are five distinguishable at arena distance? Which grades map to which band is deliberately unset (spec §10).
5. **LOD distances** — both constants are guesses until measured on the A13.
