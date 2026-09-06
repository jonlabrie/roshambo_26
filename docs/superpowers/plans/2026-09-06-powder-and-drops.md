# Powder & Drops (sub-project A) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** The second economy exists on the backend: a sealed `powder` balance that points and Robux can flow into and that only fireworks can flow out of; shells melt back to powder at list price; the flat firecracker-per-WIN becomes a streak-tier drop table that also mints golden tickets; and a show can be reserved on powder fuel.

**Architecture:** Backend only (`server/`), plus two Lune-tested `NetworkClient` calls. Every balance move is one conditional Mongo update (the `fireworks/spend` and `/purchase` idiom), never read-then-save. Two new fixtures hold the contracts: the shells fixture gains the ineligible list, and `shared-fixtures/firework-drops.json` holds the drop tiers and their cases; runtime code holds literals and tests assert equality (the GameRules pattern; `rootDir` is `src/`). The Hanabiya's melt UI and any `main.server.luau` handler are deliberately NOT in this plan: the server file is being split in parallel and this plan must not touch it.

**Tech Stack:** TypeScript (Express 5, Mongoose, Vitest + mongodb-memory-server), Luau under Lune for the client calls, Node `crypto.randomUUID`.

**Spec:** `docs/superpowers/specs/2026-09-05-fireworks-show-system-design.md` — §7 (powder, the flow table, the seal, drops by streak tier), §10 row A, §12. Decisions 10 on `docs/wiki/program/backlog.md` § "Fireworks show system — decisions taken in conversation". Read §7 first.

## Global Constraints

- **THE SEAL: powder buys only things that burn.** No endpoint may move powder to `totalPoints`, `lifetimeBanked`, or any durable field; no purchase of a durable may accept powder. `topup` is one-way (points → powder). Tests must state this where a test can (negative/reverse amounts refused; melt credits powder never points).
- **Every balance move is ONE conditional `findOneAndUpdate`** with the balance check in the filter (`{ $gte: n }`) and the move in `$inc` — the `fireworks/spend` (`apiV1.ts` ~L370) and `/purchase` (~L452) idiom. Never `bankPot`'s read-then-equality form.
- **Settlement's grant stays inside its single atomic `findByIdAndUpdate`** (`Settlement.ts` ~L146-162). The drop is computed as a pure function of the post-win `streak` (already at ~L108) BEFORE that call.
- **Runtime code never imports `shared-fixtures/*`** (`rootDir: ./src`; the container is built from `server/`). Literals in code; tests assert equality with the fixture, exactly as `fireworks.test.ts` does for `SHELL_IDS`.
- **No edits to `roblox/src/server/main.server.luau`** (register ceiling; concurrent split). The shop's melt verb and any remote handler are the first task after the split lands — recorded on the backlog by Task 8.
- **Additive wire changes only**: `powder` appears on `/economy` and `/fireworks`; `ShellState` gains `powderEligible`; existing consumers ignore unknown keys (verified: `pushFireworkState` forwards the body; `ShopController` reads `shells`/`mortars` only).
- **Rare/secret/special shells are outside powder in both directions.** Today the list is EMPTY (every shipped shell is a shop shell); the flag and the fixture exist so the first rare shell is one line, not a design.
- **Golden tickets are minted here, consumed in sub-project C.** Shape: `goldenTickets: [{ id, earnedAt }]`, appended by `$push` inside the settlement update. No gifting, no booking, no redemption in this plan.
- TDD every task; `cd server && npm test && npx tsc --noEmit`; Luau: `cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools`. Commit style `type(scope): summary`, trailer `Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>` after a blank line. Stage only the files each task names. Fresh worktree `.worktrees/powder`, branch `thread/powder`; `git fetch` before every push; never rebase or reset on a dirty tree.

---

## File map

| file | responsibility |
|---|---|
| `shared-fixtures/firework-shells.json` | + `powderIneligible: []` (+ comment) |
| `shared-fixtures/firework-drops.json` (new) | drop tiers, ticket streak, and `dropForStreak` cases |
| `server/src/fireworks.ts` | `POWDER_INELIGIBLE`, `isPowderEligible`, `ShellState.powderEligible` |
| `server/src/fireworks.test.ts` | fixture contract for the ineligible list; flag on `shellStates` |
| `server/src/drops.ts` (new) | `DROP_TABLE` literals, `dropForStreak(streak)` |
| `server/src/drops.test.ts` (new) | fixture cases |
| `server/src/models/User.ts` | `powder`, `goldenTickets` |
| `server/src/models/PowderGrant.ts` (new) | idempotency ledger for external grants (Robux seam) |
| `server/src/engine/Settlement.ts` | drop table replaces the flat firecracker grant |
| `server/src/engine/Settlement.test.ts` | tier cases |
| `server/src/routes/apiV1.ts` | `powder/topup`, `fireworks/melt`, `powder/grant`, `powder` on `/economy` + `/fireworks`, `fuel: 'powder'` on `shows/reserve` |
| `server/src/routes/apiV1.test.ts` | route tests |
| `roblox/src/server/NetworkClient.luau` + `roblox/tests/NetworkClient.spec.luau` | `postPowderTopup`, `postFireworkMelt` |
| `docs/wiki/world/fireworks.md`, `docs/wiki/world/core-loop.md`, `docs/wiki/world/hanabiya.md`, `docs/wiki/program/backlog.md`, `docs/wiki/log.md` | as-built, the fifth points field that is not points, melt UI deferred, ship entry |

---

### Task 1: The powder-eligibility flag (fixture + `fireworks.ts`)

**Files:**
- Modify: `shared-fixtures/firework-shells.json`
- Modify: `server/src/fireworks.ts` (~L73-104)
- Test: `server/src/fireworks.test.ts`

**Interfaces:**
- Produces: `POWDER_INELIGIBLE: ReadonlySet<string>` (empty today); `isPowderEligible(shellId: string): boolean` (false for unknown ids); `ShellState = { count, launchable, reason, powderEligible: boolean }`.

- [ ] **Step 1: Extend the fixture**

Add two keys to `shared-fixtures/firework-shells.json`, after `mortars` (keep the file valid JSON; both Lune readers only consume `shells`/`mortars`, so this is additive):

```json
    "powderIneligibleComment": "Shells OUTSIDE the powder economy in both directions (spec 2026-09-05 §7): not buyable with powder, not meltable. Rare / secret / special shells go here when they exist. EMPTY today -- every shipped shell is a shop shell. server/src/fireworks.ts's POWDER_INELIGIBLE is asserted equal to this list.",
    "powderIneligible": []
```

- [ ] **Step 2: Write the failing tests**

Append to `server/src/fireworks.test.ts`:

```ts
describe('the fixture is the powder-eligibility contract too', () => {
    it('POWDER_INELIGIBLE equals the fixture list', () => {
        expect([...POWDER_INELIGIBLE].sort()).toEqual([...fixtures.powderIneligible].sort());
    });
    it('every ineligible id is a real shell', () => {
        for (const id of fixtures.powderIneligible) expect(fixtures.shells).toContain(id);
    });
    it('isPowderEligible: true for every shipped shell today, false for unknown ids', () => {
        for (const id of SHELL_IDS) expect(isPowderEligible(id)).toBe(!POWDER_INELIGIBLE.has(id));
        expect(isPowderEligible('moonshot')).toBe(false);
    });
    it('shellStates carries powderEligible per shell', () => {
        const states = shellStates({ firecracker: 2 }, noGear);
        expect(states.firecracker.powderEligible).toBe(true);
        expect(states.kamuro.powderEligible).toBe(true);
    });
});
```

Add `POWDER_INELIGIBLE, isPowderEligible` to the import list at the top of the test.

- [ ] **Step 3: Run to verify it fails** — `cd server && npx vitest run src/fireworks.test.ts` → FAIL (`POWDER_INELIGIBLE` not exported).

- [ ] **Step 4: Implement**

In `server/src/fireworks.ts`, after `REQUIREMENTS`:

```ts
// OUTSIDE THE POWDER ECONOMY IN BOTH DIRECTIONS (spec 2026-09-05 §7): not buyable with powder, not
// meltable. Prestige that converts to fungible value stops being prestige. Empty today — every
// shipped shell is a shop shell — and asserted equal to shared-fixtures/firework-shells.json's
// `powderIneligible` so the first rare shell is one line on each side.
export const POWDER_INELIGIBLE: ReadonlySet<string> = new Set<string>([]);

export function isPowderEligible(shellId: string): boolean {
    return (SHELL_IDS as readonly string[]).includes(shellId) && !POWDER_INELIGIBLE.has(shellId);
}
```

Change `ShellState` and every return in `evaluateShell` to carry the flag:

```ts
export type ShellState = { count: number; launchable: boolean; reason: string | null; powderEligible: boolean };
```

Simplest: rename the existing function body to `evaluateLaunchable(shellId, count, ctx): { count; launchable; reason }` and make `evaluateShell` wrap it: `return { ...evaluateLaunchable(shellId, count, ctx), powderEligible: isPowderEligible(shellId) };`.

- [ ] **Step 5: Run the suite and type-check** — `npm test && npx tsc --noEmit`. Any test that `toEqual`s a `ShellState` literal now needs `powderEligible` — update those assertions (search `launchable:` in tests).

- [ ] **Step 6: Commit**

```bash
git add shared-fixtures/firework-shells.json server/src/fireworks.ts server/src/fireworks.test.ts
git commit -m "feat(powder): powderEligible on every shell state; the ineligible list is a fixture contract (empty today)

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 2: The drop table (`drops.ts` + fixture)

**Files:**
- Create: `shared-fixtures/firework-drops.json`
- Create: `server/src/drops.ts`
- Test: `server/src/drops.test.ts`

**Interfaces:**
- Produces: `DROP_TABLE = { default: 'firecracker', tiers: { 3: 'peony', 5: 'wa' }, ticketAtStreak: 6 }`; `dropForStreak(streak: number): { shellId: string; ticket: boolean }` — streak is the POST-win streak (1 on the first win of a run). `shellId` is `tiers[streak]` if present else `default`; `ticket` is `streak === ticketAtStreak`. Non-positive or non-integer streak → `{ shellId: default, ticket: false }`.

These tiers are the spec's STARTING VALUES, not rulings: a ticket at six follows from the roof's capacity math (spec §5). Changing a tier is a fixture edit plus the literal.

- [ ] **Step 1: Write the fixture**

```json
{
    "comment": "What a WIN drops, keyed to the streak AFTER the win (spec 2026-09-05 §7 'Drops by streak tier'). Awarded on the WIN event so it is neutral to Bank vs Stake. Drops are ITEMS, never powder amounts. Every shell here must be in firework-shells.json and must NOT be in its powderIneligible list (a drop you cannot fire yet must at least melt). server/src/drops.ts's DROP_TABLE is asserted equal to this.",
    "default": "firecracker",
    "tiers": { "3": "peony", "5": "wa" },
    "ticketAtStreak": 6,
    "cases": [
        { "streak": 1, "shellId": "firecracker", "ticket": false, "why": "first win of a run" },
        { "streak": 2, "shellId": "firecracker", "ticket": false },
        { "streak": 3, "shellId": "peony", "ticket": false, "why": "the first tier" },
        { "streak": 4, "shellId": "firecracker", "ticket": false, "why": "between tiers falls back to the default" },
        { "streak": 5, "shellId": "wa", "ticket": false },
        { "streak": 6, "shellId": "firecracker", "ticket": true, "why": "the golden ticket, with the default shell beside it" },
        { "streak": 7, "shellId": "firecracker", "ticket": false, "why": "one ticket per crossing, not per round above it" },
        { "streak": 12, "shellId": "firecracker", "ticket": false },
        { "streak": 0, "shellId": "firecracker", "ticket": false, "why": "defensive: never called on a non-win, but must not throw" },
        { "streak": -3, "shellId": "firecracker", "ticket": false },
        { "streak": 2.5, "shellId": "firecracker", "ticket": false }
    ]
}
```

- [ ] **Step 2: Write the failing test**

```ts
// server/src/drops.test.ts
import { describe, it, expect } from 'vitest';
import fixture from '../../shared-fixtures/firework-drops.json';
import shells from '../../shared-fixtures/firework-shells.json';
import { DROP_TABLE, dropForStreak } from './drops';

describe('the fixture is the contract', () => {
    it('DROP_TABLE equals the fixture', () => {
        expect(DROP_TABLE).toEqual({ default: fixture.default, tiers: fixture.tiers, ticketAtStreak: fixture.ticketAtStreak });
    });
    it('every drop shell is a real, powder-eligible shell', () => {
        const all = [fixture.default, ...Object.values(fixture.tiers)];
        for (const id of all) {
            expect(shells.shells).toContain(id);
            expect(shells.powderIneligible).not.toContain(id);
        }
    });
});

describe('dropForStreak — every fixture case', () => {
    for (const c of fixture.cases) {
        it(`streak ${c.streak} → ${c.shellId}${c.ticket ? ' + ticket' : ''}`, () => {
            expect(dropForStreak(c.streak)).toEqual({ shellId: c.shellId, ticket: c.ticket });
        });
    }
});
```

- [ ] **Step 3: Run to verify it fails** — `npx vitest run src/drops.test.ts` → `Cannot find module './drops'`.

- [ ] **Step 4: Implement**

```ts
// server/src/drops.ts
// WHAT A WIN DROPS (spec 2026-09-05 §7). Keyed to the streak AFTER the win and awarded on the WIN
// event, so it never leans on Bank vs Stake — banking does not reset currentStreak. Drops are
// ITEMS: "you got a peony" is legible to an eight-year-old; a number ticking up is not. A dropped
// gear shell a player cannot fire yet is not a dead item — it melts (Task 4).
//
// LITERALS, asserted equal to shared-fixtures/firework-drops.json by drops.test.ts. The tiers are
// starting values: the ticket at six follows from the rooftop's capacity (spec §5), and every
// tier is one fixture edit plus this table.
export const DROP_TABLE = {
    default: 'firecracker',
    tiers: { 3: 'peony', 5: 'wa' } as Record<number, string>,
    ticketAtStreak: 6,
};

export type Drop = { shellId: string; ticket: boolean };

export function dropForStreak(streak: number): Drop {
    if (!Number.isInteger(streak) || streak < 1) return { shellId: DROP_TABLE.default, ticket: false };
    return {
        shellId: DROP_TABLE.tiers[streak] ?? DROP_TABLE.default,
        ticket: streak === DROP_TABLE.ticketAtStreak,
    };
}
```

(`toEqual` compares `{ "3": "peony" }` from JSON against `{ 3: 'peony' }` — object keys are strings in both; fine.)

- [ ] **Step 5: Run** — `npx vitest run src/drops.test.ts && npx tsc --noEmit` → PASS.

- [ ] **Step 6: Commit**

```bash
git add shared-fixtures/firework-drops.json server/src/drops.ts server/src/drops.test.ts
git commit -m "feat(powder): the drop table -- streak tiers as a fixture contract; a golden ticket at the ticket streak

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 3: `powder` and `goldenTickets` on the user; settlement grants by tier

**Files:**
- Modify: `server/src/models/User.ts` (interface ~L10-70, schema ~L108-126)
- Modify: `server/src/engine/Settlement.ts` (~L108, ~L146-162)
- Test: `server/src/engine/Settlement.test.ts` (~L55-78)

**Interfaces:**
- Consumes: Task 2's `dropForStreak`.
- Produces: `IUser.powder: number` (schema default 0); `IUser.goldenTickets: { id: string; earnedAt: Date }[]` (schema `[Schema.Types.Mixed]`, default `[]`).

- [ ] **Step 1: Write the failing tests**

In `Settlement.test.ts`, replace `it('a WIN grants one firecracker', …)` with a tier-driven set. Streak after the win is `currentStreak + 1`, so seed `currentStreak` accordingly:

```ts
    describe('the drop table (spec §7): what a WIN grants depends on the streak after it', () => {
        const winFor = (deviceId: string, currentStreak: number) => ({
            roundId: `r-${deviceId}`,
            worldThrow: 'S' as const, // R beats S -> WIN
            counts: { R: 1, P: 0, S: 0 },
            throws: throwsMap([[`pwa:${deviceId}`, { throw: 'R', seq: 1, platform: 'pwa', deviceId }]]),
            timestamp: new Date(),
        });

        it('first win of a run: one firecracker, no ticket', async () => {
            const user = await User.create({ deviceId: 'd1', currentStreak: 0 });
            await settleRound(winFor('d1', 0));
            const after = await User.findById(user._id);
            expect(after!.fireworks.get('firecracker')).toBe(1);
            expect(after!.goldenTickets).toEqual([]);
            expect(after!.powder).toBe(0);
        });

        it('third win: a peony, no firecracker', async () => {
            const user = await User.create({ deviceId: 'd3', currentStreak: 2 });
            await settleRound(winFor('d3', 2));
            const after = await User.findById(user._id);
            expect(after!.fireworks.get('peony')).toBe(1);
            expect(after!.fireworks.get('firecracker') ?? 0).toBe(0);
        });

        it('sixth win: the default shell AND a golden ticket with an id and a time', async () => {
            const user = await User.create({ deviceId: 'd6', currentStreak: 5 });
            await settleRound(winFor('d6', 5));
            const after = await User.findById(user._id);
            expect(after!.fireworks.get('firecracker')).toBe(1);
            expect(after!.goldenTickets).toHaveLength(1);
            expect(after!.goldenTickets[0].id).toMatch(/^[0-9a-f-]{36}$/);
            expect(after!.goldenTickets[0].earnedAt).toBeInstanceOf(Date);
        });

        it('seventh win: no second ticket', async () => {
            const user = await User.create({ deviceId: 'd7', currentStreak: 6, goldenTickets: [{ id: 'x', earnedAt: new Date() }] });
            await settleRound(winFor('d7', 6));
            const after = await User.findById(user._id);
            expect(after!.goldenTickets).toHaveLength(1);
        });

        it('a SAFE grants nothing', async () => {
            const user = await User.create({ deviceId: 'dS', currentStreak: 2 });
            await settleRound({ ...winFor('dS', 2), worldThrow: 'R' }); // R vs R -> SAFE
            const after = await User.findById(user._id);
            expect(after!.fireworks.size).toBe(0);
            expect(after!.goldenTickets).toEqual([]);
        });
    });
```

Keep the existing `'a LOSS grants nothing'` test.

- [ ] **Step 2: Run to verify it fails** — `npx vitest run src/engine/Settlement.test.ts` → the peony and ticket cases FAIL (flat firecracker; `goldenTickets` undefined).

- [ ] **Step 3: Implement**

`server/src/models/User.ts` — interface, next to `fireworks`:

```ts
    // THE SECOND ECONOMY (spec 2026-09-05 §7). Powder buys only things that burn: points and Robux
    // flow IN, shells melt back INTO it, and nothing ever flows OUT to totalPoints or a durable.
    // Never rank by it, never sum it into earnings. Every move is a conditional $inc.
    powder: number;
    // Minted by the drop table at the ticket streak (Settlement); redeemed, gifted and booked in
    // sub-project C. Append-only here.
    goldenTickets: { id: string; earnedAt: Date }[];
```

schema, next to `fireworks`:

```ts
    powder: { type: Number, default: 0 },
    goldenTickets: { type: [Schema.Types.Mixed], default: [] },
```

`server/src/engine/Settlement.ts` — import `dropForStreak` from `'../drops'` and `randomUUID` from `'crypto'`. Before the `findByIdAndUpdate`, after `const streak = …`:

```ts
                // THE GRANT PATHWAY'S FIRST SOURCE, now a table (spec §7): what a WIN drops depends on
                // the streak AFTER it, computed here so the grant stays inside the one atomic write.
                const drop = result === 'WIN' ? dropForStreak(streak) : null;
```

In the update, replace the `...(result === 'WIN' ? { 'fireworks.firecracker': 1 } : {})` line with `...(drop ? { [`fireworks.${drop.shellId}`]: 1 } : {}),` and add, as a sibling of `$inc`/`$set`/`$max`:

```ts
                    ...(drop?.ticket ? { $push: { goldenTickets: { id: randomUUID(), earnedAt: data.timestamp } } } : {}),
```

- [ ] **Step 4: Run** — `npm test && npx tsc --noEmit` → PASS.

- [ ] **Step 5: Commit**

```bash
git add server/src/models/User.ts server/src/engine/Settlement.ts server/src/engine/Settlement.test.ts
git commit -m "feat(powder): powder and goldenTickets on the user; settlement grants by streak tier inside the one atomic write

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 4: `powder/topup` and `fireworks/melt`; `powder` on the reads

**Files:**
- Modify: `server/src/routes/apiV1.ts` (`/economy` ~L320-348, `/fireworks` ~L350-368, new routes after `fireworks/spend`)
- Test: `server/src/routes/apiV1.test.ts` (inside `describe('fireworks', …)`)

**Interfaces:**
- `GET …/economy` and `GET …/fireworks` both add `powder: number`.
- `POST …/powder/topup { points }` → 400 `BAD_AMOUNT` unless a positive integer; 409 `INSUFFICIENT_POINTS` with `{ held }`; 200 `{ powder, totalPoints }`.
- `POST …/fireworks/melt { shellId, count }` → 400 `BAD_SHELL`; 400 `BAD_COUNT` unless a positive integer; 400 `POWDER_INELIGIBLE`; 409 `NONE_HELD` with `{ held }`; 200 `{ shellId, count: remaining, powder, credited }` where `credited = count * SHELL_PRICES[shellId]`.

- [ ] **Step 1: Write the failing tests**

```ts
        describe('powder (spec §7): points and shells flow IN, nothing flows out but fireworks', () => {
            it('economy and fireworks reads carry powder (default 0)', async () => {
                await User.create({ robloxId: '920' });
                const app = makeApp(makeEngine(), new ResultsStore());
                expect((await request(app).get('/api/v1/players/920/economy').set('X-API-Key', API_KEY).expect(200)).body.powder).toBe(0);
                expect((await request(app).get('/api/v1/players/920/fireworks').set('X-API-Key', API_KEY).expect(200)).body.powder).toBe(0);
            });

            it('topup moves points into powder, one way, atomically', async () => {
                await User.create({ robloxId: '921', totalPoints: 10 });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/921/powder/topup').set('X-API-Key', API_KEY).send({ points: 4 }).expect(200);
                expect(res.body).toEqual({ powder: 4, totalPoints: 6 });
                const after = await User.findOne({ robloxId: '921' });
                expect(after!.totalPoints).toBe(6);
                expect(after!.powder).toBe(4);
                expect(after!.lifetimeBanked ?? 0).toBe(0); // career earnings untouched
            });

            it('topup refuses more than the wallet holds, and moves nothing', async () => {
                await User.create({ robloxId: '922', totalPoints: 3 });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/922/powder/topup').set('X-API-Key', API_KEY).send({ points: 4 }).expect(409);
                expect(res.body).toEqual({ error: 'INSUFFICIENT_POINTS', held: 3 });
                const after = await User.findOne({ robloxId: '922' });
                expect([after!.totalPoints, after!.powder]).toEqual([3, 0]);
            });

            it('topup is ONE WAY: zero, negative, fractional and non-numeric amounts are refused', async () => {
                await User.create({ robloxId: '923', totalPoints: 10, powder: 10 });
                const app = makeApp(makeEngine(), new ResultsStore());
                for (const points of [0, -4, 2.5, 'lots', undefined]) {
                    const res = await request(app).post('/api/v1/players/923/powder/topup').set('X-API-Key', API_KEY).send({ points }).expect(400);
                    expect(res.body.error).toBe('BAD_AMOUNT');
                }
                const after = await User.findOne({ robloxId: '923' });
                expect([after!.totalPoints, after!.powder]).toEqual([10, 10]);
            });

            it('melt turns held shells into powder at list price, atomically', async () => {
                await User.create({ robloxId: '924', fireworks: { peony: 3 } });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/924/fireworks/melt').set('X-API-Key', API_KEY).send({ shellId: 'peony', count: 2 }).expect(200);
                expect(res.body).toEqual({ shellId: 'peony', count: 1, powder: 6, credited: 6 }); // peony is 3
                const after = await User.findOne({ robloxId: '924' });
                expect(after!.fireworks.get('peony')).toBe(1);
                expect(after!.powder).toBe(6);
                expect(after!.totalPoints).toBe(0); // never points
            });

            it('melt refuses more than held, bad counts, unknown shells — and moves nothing', async () => {
                await User.create({ robloxId: '925', fireworks: { peony: 1 } });
                const app = makeApp(makeEngine(), new ResultsStore());
                const post = (body: object) => request(app).post('/api/v1/players/925/fireworks/melt').set('X-API-Key', API_KEY).send(body);
                expect((await post({ shellId: 'peony', count: 2 }).expect(409)).body).toEqual({ error: 'NONE_HELD', held: 1 });
                expect((await post({ shellId: 'peony', count: 0 }).expect(400)).body.error).toBe('BAD_COUNT');
                expect((await post({ shellId: 'peony', count: 1.5 }).expect(400)).body.error).toBe('BAD_COUNT');
                expect((await post({ shellId: 'moonshot', count: 1 }).expect(400)).body.error).toBe('BAD_SHELL');
                const after = await User.findOne({ robloxId: '925' });
                expect([after!.fireworks.get('peony'), after!.powder]).toEqual([1, 0]);
            });

            it('CONCURRENT MELTS CANNOT OVER-CREDIT — one conditional update per melt', async () => {
                await User.create({ robloxId: '926', fireworks: { wa: 1 } });
                const app = makeApp(makeEngine(), new ResultsStore());
                const body = { shellId: 'wa', count: 1 };
                const [a, b] = await Promise.all([
                    request(app).post('/api/v1/players/926/fireworks/melt').set('X-API-Key', API_KEY).send(body),
                    request(app).post('/api/v1/players/926/fireworks/melt').set('X-API-Key', API_KEY).send(body),
                ]);
                expect([a.status, b.status].sort()).toEqual([200, 409]);
                const after = await User.findOne({ robloxId: '926' });
                expect([after!.fireworks.get('wa'), after!.powder]).toEqual([0, 5]); // wa is 5
            });
        });
```

The `POWDER_INELIGIBLE` branch cannot be exercised while the list is empty; add this test with `it.skip` and a comment "un-skip when the first ineligible shell exists", asserting 400 `POWDER_INELIGIBLE`.

- [ ] **Step 2: Run to verify it fails** — `npx vitest run src/routes/apiV1.test.ts -t "powder"` → 404s / missing fields.

- [ ] **Step 3: Implement**

`/economy`: add `powder: user.powder ?? 0,` to the response object. `/fireworks`: add `powder: user.powder ?? 0` to its `res.json`. Import `isPowderEligible` from `'../fireworks'`.

After `fireworks/spend`:

```ts
    // POINTS → POWDER, ONE WAY (spec 2026-09-05 §7, decision 10). The wallet is the durable
    // economy; powder buys only things that burn. Nothing anywhere moves powder back, and this
    // route refuses any amount that is not a positive integer so it cannot be run in reverse.
    router.post('/players/:robloxUserId/powder/topup', async (req, res) => {
        try {
            const points = req.body?.points;
            if (!Number.isInteger(points) || points <= 0) { res.status(400).json({ error: 'BAD_AMOUNT' }); return; }
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }
            const updated = await User.findOneAndUpdate(
                { _id: user._id, totalPoints: { $gte: points } },
                { $inc: { totalPoints: -points, powder: points } },
                { new: true }
            );
            if (!updated) { res.status(409).json({ error: 'INSUFFICIENT_POINTS', held: user.totalPoints }); return; }
            res.json({ powder: updated.powder, totalPoints: updated.totalPoints });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    // SHELLS → POWDER at list price (the Hanabiya melts them). Safe because powder cannot leave
    // the economy: a melted shell can only become another firework. Eligibility is the one gate —
    // rare/secret/special shells are outside powder in both directions.
    router.post('/players/:robloxUserId/fireworks/melt', async (req, res) => {
        try {
            const shellId = req.body?.shellId;
            const count = req.body?.count;
            if (typeof shellId !== 'string' || !SHELL_IDS.includes(shellId as never)) { res.status(400).json({ error: 'BAD_SHELL' }); return; }
            if (!Number.isInteger(count) || count <= 0) { res.status(400).json({ error: 'BAD_COUNT' }); return; }
            if (!isPowderEligible(shellId)) { res.status(400).json({ error: 'POWDER_INELIGIBLE' }); return; }
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }
            const credited = count * SHELL_PRICES[shellId];
            const updated = await User.findOneAndUpdate(
                { _id: user._id, [`fireworks.${shellId}`]: { $gte: count } },
                { $inc: { [`fireworks.${shellId}`]: -count, powder: credited } },
                { new: true }
            );
            if (!updated) { res.status(409).json({ error: 'NONE_HELD', held: user.fireworks?.get(shellId) ?? 0 }); return; }
            res.json({ shellId, count: updated.fireworks.get(shellId) ?? 0, powder: updated.powder, credited });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });
```

- [ ] **Step 4: Run** — `npm test && npx tsc --noEmit` → PASS.

- [ ] **Step 5: Commit**

```bash
git add server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "feat(powder): topup (points -> powder, one way) and melt (shells -> powder at list price), both one conditional update; powder on the reads

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 5: The external grant seam (`PowderGrant`, idempotent by receipt)

**Files:**
- Create: `server/src/models/PowderGrant.ts`
- Modify: `server/src/routes/apiV1.ts`
- Test: `server/src/routes/apiV1.test.ts`

**Interfaces:**
- `POST …/powder/grant { amount, receiptId, source }` → 400 `BAD_AMOUNT` / `BAD_RECEIPT` (non-empty string ≤ 128) / `BAD_SOURCE` (one of `'robux' | 'gift' | 'ops'`); 200 `{ powder, credited: amount, duplicate: false }` on first sight; 200 `{ powder, credited: 0, duplicate: true }` on replay of the same `receiptId`. The Roblox game server will call this from `ProcessReceipt` in a later sub-project; no product ids here.

Idempotency = insert the grant row FIRST behind a unique index; a duplicate-key error means "already granted", so the credit runs at most once even under a retry storm.

- [ ] **Step 1: Write the failing tests**

```ts
        describe('powder/grant — the external seam, idempotent by receipt', () => {
            it('credits once and replays as a no-op', async () => {
                await User.create({ robloxId: '930' });
                const app = makeApp(makeEngine(), new ResultsStore());
                const body = { amount: 25, receiptId: 'rcpt-abc', source: 'robux' };
                const first = await request(app).post('/api/v1/players/930/powder/grant').set('X-API-Key', API_KEY).send(body).expect(200);
                expect(first.body).toEqual({ powder: 25, credited: 25, duplicate: false });
                const again = await request(app).post('/api/v1/players/930/powder/grant').set('X-API-Key', API_KEY).send(body).expect(200);
                expect(again.body).toEqual({ powder: 25, credited: 0, duplicate: true });
                expect((await User.findOne({ robloxId: '930' }))!.powder).toBe(25);
                expect(await PowderGrant.countDocuments({ receiptId: 'rcpt-abc' })).toBe(1);
            });
            it('refuses bad amounts, receipts and sources without writing', async () => {
                await User.create({ robloxId: '931' });
                const app = makeApp(makeEngine(), new ResultsStore());
                const post = (b: object) => request(app).post('/api/v1/players/931/powder/grant').set('X-API-Key', API_KEY).send(b);
                expect((await post({ amount: 0, receiptId: 'r', source: 'robux' }).expect(400)).body.error).toBe('BAD_AMOUNT');
                expect((await post({ amount: 5, receiptId: '', source: 'robux' }).expect(400)).body.error).toBe('BAD_RECEIPT');
                expect((await post({ amount: 5, receiptId: 'r', source: 'points' }).expect(400)).body.error).toBe('BAD_SOURCE');
                expect((await User.findOne({ robloxId: '931' }))!.powder).toBe(0);
                expect(await PowderGrant.countDocuments()).toBe(0);
            });
            it('two concurrent grants with one receipt credit exactly once', async () => {
                await User.create({ robloxId: '932' });
                const app = makeApp(makeEngine(), new ResultsStore());
                const body = { amount: 7, receiptId: 'rcpt-race', source: 'robux' };
                await Promise.all([1, 2, 3].map(() => request(app).post('/api/v1/players/932/powder/grant').set('X-API-Key', API_KEY).send(body)));
                expect((await User.findOne({ robloxId: '932' }))!.powder).toBe(7);
            });
        });
```

Import `PowderGrant` at the top of the test file. Since the unique index must exist before the race test, call `await PowderGrant.syncIndexes()` in the test file's `beforeAll` after `connectTestDb()` (mongodb-memory-server builds indexes lazily otherwise).

- [ ] **Step 2: Run to verify it fails** — `npx vitest run src/routes/apiV1.test.ts -t "powder/grant"` → 404s.

- [ ] **Step 3: Implement**

```ts
// server/src/models/PowderGrant.ts
import mongoose, { Schema, Document, Types } from 'mongoose';

// ONE ROW PER EXTERNAL POWDER GRANT, and the idempotency key for all of them. A Robux receipt
// (ProcessReceipt retries until it is told Granted), an ops gift, a future return reward: each
// names a receiptId once, and the unique index below is what makes "credit at most once" true
// under retries and races — the row is inserted BEFORE the balance moves, so a duplicate insert
// fails before it can credit.
export interface IPowderGrant extends Document {
    receiptId: string;
    userId: Types.ObjectId;
    amount: number;
    source: 'robux' | 'gift' | 'ops';
    createdAt: Date;
}

const PowderGrantSchema: Schema = new Schema({
    receiptId: { type: String, required: true, unique: true },
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    amount: { type: Number, required: true },
    source: { type: String, enum: ['robux', 'gift', 'ops'], required: true },
    createdAt: { type: Date, default: Date.now },
});

export default mongoose.model<IPowderGrant>('PowderGrant', PowderGrantSchema);
```

Route, after `powder/topup`:

```ts
    // EXTERNAL GRANTS (Robux via ProcessReceipt, gifts, ops). Idempotent by receiptId: the grant
    // row is inserted first behind a unique index, so a replay or a race credits at most once.
    router.post('/players/:robloxUserId/powder/grant', async (req, res) => {
        try {
            const { amount, receiptId, source } = req.body ?? {};
            if (!Number.isInteger(amount) || amount <= 0) { res.status(400).json({ error: 'BAD_AMOUNT' }); return; }
            if (typeof receiptId !== 'string' || receiptId.length === 0 || receiptId.length > 128) { res.status(400).json({ error: 'BAD_RECEIPT' }); return; }
            if (!['robux', 'gift', 'ops'].includes(source)) { res.status(400).json({ error: 'BAD_SOURCE' }); return; }
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }
            try {
                await PowderGrant.create({ receiptId, userId: user._id, amount, source });
            } catch (err) {
                if ((err as { code?: number }).code === 11000) {
                    res.json({ powder: user.powder ?? 0, credited: 0, duplicate: true });
                    return;
                }
                throw err;
            }
            const updated = await User.findByIdAndUpdate(user._id, { $inc: { powder: amount } }, { new: true });
            res.json({ powder: updated?.powder ?? 0, credited: amount, duplicate: false });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });
```

Import `PowderGrant` in the route file.

- [ ] **Step 4: Run** — `npm test && npx tsc --noEmit` → PASS. If the race test flakes because the index is not yet built, the `syncIndexes` in `beforeAll` is the fix, not a retry.

- [ ] **Step 5: Commit**

```bash
git add server/src/models/PowderGrant.ts server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "feat(powder): the external grant seam -- PowderGrant rows make every receipt credit at most once

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 6: Powder fuel on `shows/reserve`

**Files:**
- Modify: `server/src/routes/apiV1.ts` (the `shows/reserve` route)
- Test: `server/src/routes/apiV1.test.ts` (the existing reserve describe)

**Interfaces:**
- `fuel: 'powder'` is now accepted: every cue's shell must be powder-eligible (409 `POWDER_INELIGIBLE` with `shellId` otherwise); cost = Σ `SHELL_PRICES[shellId]` over cues; one conditional update `{ _id, powder: { $gte: cost } }` / `$inc: { powder: -cost }`; 409 `INSUFFICIENT_POWDER` with `{ needed: cost, held }`; 200 body gains `fuel` and `debited: { powder: cost }`. Inventory fuel is unchanged. Mortar ownership is checked for both fuels.

- [ ] **Step 1: Write the failing tests**

```ts
            it('powder fuel: debits the summed list price in one update, and owns no shells afterward', async () => {
                await User.create({ robloxId: '940', mortars: ['mortar:S'], powder: 10 });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/940/shows/reserve').set('X-API-Key', API_KEY)
                    .send({ show: { stageId: 'deck:940', fuel: 'powder', cues: [
                        { t_ms: 0, slot: 'hand', shellId: 'firecracker' },     // 1
                        { t_ms: 1000, slot: 'mortar:S', shellId: 'peony' },     // 3
                        { t_ms: 2000, slot: 'mortar:S', shellId: 'kiku' },      // 4
                    ] } }).expect(200);
                expect(res.body.fuel).toBe('powder');
                expect(res.body.debited).toEqual({ powder: 8 });
                const after = await User.findOne({ robloxId: '940' });
                expect(after!.powder).toBe(2);
                expect(after!.fireworks.size).toBe(0);
            });
            it('powder fuel: INSUFFICIENT_POWDER debits nothing; mortar ownership still applies', async () => {
                await User.create({ robloxId: '941', mortars: [], powder: 100 });
                const app = makeApp(makeEngine(), new ResultsStore());
                const poor = await request(app).post('/api/v1/players/941/shows/reserve').set('X-API-Key', API_KEY)
                    .send({ show: { stageId: 'deck:941', fuel: 'powder', cues: [{ t_ms: 0, slot: 'mortar:S', shellId: 'peony' }] } }).expect(409);
                expect(poor.body).toEqual({ error: 'MORTAR_MISSING', slot: 'mortar:S' });
                await User.updateOne({ robloxId: '941' }, { $set: { powder: 2 } });
                const broke = await request(app).post('/api/v1/players/941/shows/reserve').set('X-API-Key', API_KEY)
                    .send({ show: { stageId: 'deck:941', fuel: 'powder', cues: [{ t_ms: 0, slot: 'hand', shellId: 'firecracker' }, { t_ms: 500, slot: 'hand', shellId: 'firecracker' }, { t_ms: 900, slot: 'hand', shellId: 'firecracker' }] } }).expect(409);
                expect(broke.body).toEqual({ error: 'INSUFFICIENT_POWDER', needed: 3, held: 2 });
                expect((await User.findOne({ robloxId: '941' }))!.powder).toBe(2);
            });
```

Also change the existing test that asserts `fuel: 'powder'` → 400 `FUEL_UNSUPPORTED`: powder is supported now; that assertion goes away (keep one for an unknown fuel like `'wishes'` → `FUEL_UNSUPPORTED`).

- [ ] **Step 2: Run to verify it fails.**

- [ ] **Step 3: Implement**

In the reserve route: replace `if (show.fuel !== 'inventory')` with `if (show.fuel !== 'inventory' && show.fuel !== 'powder')`. After the mortar-ownership loop, branch:

```ts
            if (show.fuel === 'powder') {
                for (const c of cues) {
                    if (!isPowderEligible(c.shellId)) { res.status(409).json({ error: 'POWDER_INELIGIBLE', shellId: c.shellId }); return; }
                }
                const cost = cues.reduce((s, c) => s + SHELL_PRICES[c.shellId], 0);
                const updated = await User.findOneAndUpdate(
                    { _id: user._id, powder: { $gte: cost } },
                    { $inc: { powder: -cost } },
                    { new: true }
                );
                if (!updated) { res.status(409).json({ error: 'INSUFFICIENT_POWDER', needed: cost, held: user.powder ?? 0 }); return; }
                res.json({
                    reservationId: Math.random().toString(36).slice(2, 12),
                    stageId: show.stageId, fuel: 'powder', cues,
                    debited: { powder: cost }, remaining: { powder: updated.powder },
                });
                return;
            }
```

and add `fuel: 'inventory'` to the existing inventory response.

- [ ] **Step 4: Run** — `npm test && npx tsc --noEmit` → PASS.

- [ ] **Step 5: Commit**

```bash
git add server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "feat(powder): shows can be reserved on powder fuel -- summed list price, one conditional update, eligible shells only

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 7: `NetworkClient.postPowderTopup` and `postFireworkMelt`

**Files:**
- Modify: `roblox/src/server/NetworkClient.luau` (after `postShowReserve`)
- Test: `roblox/tests/NetworkClient.spec.luau`

**Interfaces:**
- `NetworkClient.postPowderTopup(self, robloxUserId: string, points: number): Result` → `POST /api/v1/players/{id}/powder/topup { points }`
- `NetworkClient.postFireworkMelt(self, robloxUserId: string, shellId: string, count: number): Result` → `POST /api/v1/players/{id}/fireworks/melt { shellId, count }`

No caller yet (the shop's melt verb waits for the server-file split). These exist so that task is a client change only.

- [ ] **Step 1: Failing spec** — in the file's `makeDeps` style (see the `postShowReserve` test added by sub-project B):

```lua
describe("NetworkClient powder calls", function()
    test("postPowderTopup POSTs { points }", function()
        local f = makeDeps({ { ok = true, statusCode = 200, body = '{"powder":4,"totalPoints":6}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:postPowderTopup("77", 4)
        expect(res.ok).toBe(true)
        expect(res.data.powder).toBe(4)
        expect(f.calls[1].method).toBe("POST")
        expect(f.calls[1].url).toBe("http://x/api/v1/players/77/powder/topup")
        expect(serde.decode("json", f.calls[1].body :: string).points).toBe(4)
    end)
    test("postFireworkMelt POSTs { shellId, count }", function()
        local f = makeDeps({ { ok = true, statusCode = 200, body = '{"shellId":"peony","count":1,"powder":6,"credited":6}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local res = net:postFireworkMelt("77", "peony", 2)
        expect(res.ok).toBe(true)
        expect(f.calls[1].url).toBe("http://x/api/v1/players/77/fireworks/melt")
        local sent = serde.decode("json", f.calls[1].body :: string)
        expect(sent.shellId).toBe("peony")
        expect(sent.count).toBe(2)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails; implement:**

```lua
function NetworkClient.postPowderTopup(self: any, robloxUserId: string, points: number): Result
    return self:_request("POST", `/api/v1/players/{robloxUserId}/powder/topup`, { points = points })
end

function NetworkClient.postFireworkMelt(self: any, robloxUserId: string, shellId: string, count: number): Result
    return self:_request("POST", `/api/v1/players/{robloxUserId}/fireworks/melt`, { shellId = shellId, count = count })
end
```

- [ ] **Step 3: Gates** — `cd roblox && lune run tests/run 2>&1 | tail -3 && stylua --check src tests tools && selene src tools`.

- [ ] **Step 4: Commit**

```bash
git add roblox/src/server/NetworkClient.luau roblox/tests/NetworkClient.spec.luau
git commit -m "feat(powder): NetworkClient.postPowderTopup and postFireworkMelt -- the shop's melt verb is a client change once the server split lands

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

### Task 8: Docs, push, CI, STOP

**Files:**
- Modify: `docs/wiki/world/fireworks.md`, `docs/wiki/world/core-loop.md`, `docs/wiki/world/hanabiya.md`, `docs/wiki/program/backlog.md`, `docs/wiki/log.md`

Per `docs/wiki/schema.md`: supersede, don't contradict; measurable facts carry their re-measure path; `log.md` kinds ∈ gate|ship|decision|drop|defect|migrate|lint|audit; `node tools/wiki/lint.mjs` count must not rise.

- [ ] **Step 1: `core-loop.md`** — in "The economy, and which number means what", add a fifth bullet after `bestPot`:

```markdown
- `powder` — **the second economy, and not points** (spec 2026-09-05 §7, decision 10). Points and
  Robux flow in, melted shells flow in, and only fireworks flow out. Never rank by it, never sum it
  into earnings, never let a route move it to `totalPoints` or a durable. Golden tickets
  (`goldenTickets[]`) are minted beside it by the drop table and belong to sub-project C.
```

- [ ] **Step 2: `fireworks.md`** — append a section:

```markdown
## Powder and drops (sub-project A, built 2026-09-06)

Spec §7; plan `docs/superpowers/plans/2026-09-06-powder-and-drops.md`. **Powder buys only things
that burn.** Flows: `POST …/powder/topup` (points → powder, one way, positive integers only);
`POST …/fireworks/melt` (shells → powder at list price, `powderEligible` shells only — the list of
ineligible shells is `firework-shells.json` `powderIneligible`, EMPTY today); `POST …/powder/grant`
(external: Robux receipts, gifts, ops — idempotent by `receiptId` via the `PowderGrant` collection);
`shows/reserve` accepts `fuel: "powder"` (summed list price, one conditional update). Every move is a
conditional `$inc`. `powder` rides on `/economy` and `/fireworks`; `ShellState` carries
`powderEligible`.

**Drops by streak tier** replace the flat firecracker-per-WIN: `shared-fixtures/firework-drops.json`
(default `firecracker`, tiers at 3 → `peony`, 5 → `wa`, a golden ticket at 6 with the default shell
beside it; one ticket per crossing) — starting values, re-read the fixture rather than this line.
Awarded on the WIN event inside settlement's single atomic write, so neutral to Bank vs Stake.

**Not here:** the Hanabiya's melt UI (a client change once `main.server.luau` is split — the
`NetworkClient` calls exist), ticket redemption/gifting/booking (C), Robux product ids.
```

- [ ] **Step 3: `hanabiya.md`** — one sentence under the roof section or a new short "Melting" line: the shop will melt shells back to powder; the backend route exists (2026-09-06); the counter verb waits for the server split.

- [ ] **Step 4: `backlog.md`** — append under the show-system decisions:

```markdown
## Hanabiya melt verb (banked 2026-09-06, after the server-file split)

Sub-project A shipped the backend (`fireworks/melt`) and `NetworkClient.postFireworkMelt`; the shop
row's "Melt" button and its `RequestMelt` remote handler were deliberately NOT added because
`main.server.luau` sits at the register ceiling and is being split. First client task after the
split: a Melt affordance per held, powder-eligible shell in `ShopController`, and a handler on the
extracted fireworks controller.
```

- [ ] **Step 5: `log.md`** — append:

```markdown
## [2026-09-06] ship | Powder + drops (sub-project A): the second economy, sealed; wins drop by streak tier

Plan `docs/superpowers/plans/2026-09-06-powder-and-drops.md`. `powder` and `goldenTickets` on the
user; topup (one way), melt (list price, eligible only), external grant (idempotent by receipt),
powder fuel on `shows/reserve`; drop table as a fixture contract replacing the flat firecracker
grant inside settlement's one atomic write. Backend + two NetworkClient calls only — no
`main.server.luau` change (the split is in flight); the shop's melt verb is banked. Dev needs a
`start-deployment` to pick this up (auto-deploy is off). Still on `thread/powder`, NOT merged.
```

- [ ] **Step 6: Lint, commit, push, CI**

`node tools/wiki/lint.mjs | tail -1` (baseline first, then after). Commit the five files; `git fetch origin && git push -u origin thread/powder`; confirm `server-ci` and `roblox-ci` green on the branch.

- [ ] **Step 7: STOP.** Report the branch, CI links, and that dev needs a redeploy after merge. The merge goes through the main thread; no self-merge.

---

## Self-review against the spec

- §7 flow table: points → powder (T4 topup), Robux → powder (T5 grant seam), shells → powder (T4 melt), powder → firing (T6 reserve), shells/powder → points NEVER (no route; T4 tests assert `totalPoints` untouched by melt and topup refuses reverse), powder → durable NEVER (no route accepts it; `/purchase` untouched). ✔
- §7 ineligible shells outside powder both ways: T1 flag, T4 melt 400, T6 reserve 409. ✔ (list empty; skip-test documents the branch)
- §7 powder never expires / no refunds: nothing decays it; no refund route. ✔
- §7 drops by tier, items not amounts, on the WIN event, neutral to banking: T2 + T3. ✔
- §10 row A: powder balance, top-up, melt, flag, drop table with fixture, Robux seam (no ids): T1–T5. ✔ Powder fuel path for B: T6. ✔
- §12: seal tests, melt eligibility, drop fixture, reserve atomicity, concurrency: present. ✔
- Type consistency: `Drop { shellId, ticket }` used identically in T2 and T3; `isPowderEligible` name identical in T1/T4/T6; response shapes match between routes and tests.
- No `main.server.luau` edit anywhere. ✔
