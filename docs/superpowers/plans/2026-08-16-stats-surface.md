# Stats Surface Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the history plan 1 started accruing into the queries and API the Stats room's walls will read — Records, Heat and Volume, with qualification, and without inventing any display.

**Architecture:** One new `stats.ts` query module beside the existing `leaderboards.ts`, a small `windows.ts` that owns time-window and qualification vocabulary so no caller invents its own, and thin REST/socket handlers that call them. Two capture gaps in plan 1 are closed first, because three of the queries are impossible without them. Every query is a pure function over Mongo; every arithmetic decision is extracted so it is testable without a database.

**Tech Stack:** TypeScript, Express, Socket.io, Mongoose 9, Vitest, mongodb-memory-server.

**Spec:** `docs/superpowers/specs/2026-08-16-stats-room-design.md` (§3 Heat vs Rank, §4 taxonomy, §4.4 participation)

**Predecessor:** `docs/superpowers/plans/2026-08-16-stats-data-capture.md` (merged, `3f0b39a..4e63eeb`)

## Global Constraints

- **This is plan 2 of 3.** Plan 3 is the Roblox displays and is additionally blocked on retargeting `BoardController` at the kōsatsu boards. **This plan ships NO display and NO client rendering.**
- **`pointsDelta` is safe to sum ONLY for LOSS rows.** On a WIN it records the NEW POT rather than the gain (`GameRules.ts:18-24`), so summing WIN deltas overstates earnings by a growing multiple. On a LOSS it is exactly `-forfeitedPot`, which is correct and is how windowed forfeits are derived. **Earnings always come from `BankEvent`; forfeits always come from LOSS rows. Never mix.**
- **`totalPoints` is a spendable wallet** decremented by purchases; never a ranking basis. `lifetimeBanked` is monotonic career earnings.
- **All windows are half-open `[from, to)`** — adopted in plan 1. Every new query and helper follows it; an event exactly at `to` belongs to the next window.
- **Rates are per THROW, never per round elapsed.** Abstention is normal play.
- **Heat is never labelled as Rank.** Heat has no qualification and is explicitly form, not standing (spec §3). Any function returning an unqualified rate must make that plain in its name or its return shape.
- **Edge (win rate − 33.3%) is PARKED** pending a real player base — do not implement it.
- Tests: `cd server && npm test`. Build: `cd server && npm run build` (must stay tsc-clean). `npm run build` does NOT type-check tests (`tsconfig` excludes `src/**/*.test.ts`) and Vitest never type-checks — type-check touched test files explicitly at `--strict`.
- When a task appends a `describe` to an existing test file, DB lifecycle hooks stay at file scope, declared once. `connectTestDb` is not idempotent.
- Commit style: `feat(server): ...` / `fix(server): ...`, imperative, body explaining WHY.

---

### Task 1: Close the two capture gaps plan 2 depends on

Three later queries are impossible against the data as currently written. Both fixes are in `Settlement`.

**Gap A — `PlayerRound` does not record the resolved user.** `Settlement.ts:107` writes `userId: entry.userId`, which is the *claimed* JWT id from the client and is optional (`RoundEngine.ts:18` `userId?: string`). A guest playing on a `deviceId` alone therefore writes rows with **no user id**, so per-user aggregation over `PlayerRound` silently omits them. `BankEvent` and `Session` both key on the resolved `user._id`; this must too.

**Gap B — there is no timestamped streak history.** `User.bestStreak` is an all-time maximum with no date, so "longest streak this week" cannot be answered. `BankEvent.streakAtBank` only covers streaks that were *banked* — but the spec (§4.1) explicitly wants cautious bankers and reckless riders to compete equally, so streaks ending in SAFE or LOSS must count too.

**Files:**
- Modify: `server/src/engine/Settlement.ts`
- Create: `server/src/models/StreakEvent.ts`
- Test: `server/src/engine/Settlement.test.ts`

**Interfaces:**
- Consumes: nothing from later tasks.
- Produces: `PlayerRound.userId` is always the resolved `user._id`. `StreakEvent` model `{ userId, length, endedBy: 'SAFE' | 'LOSS', endedAt }`.

- [ ] **Step 1: Write the failing tests**

Append to `server/src/engine/Settlement.test.ts` (the file already has DB hooks — do not add more):

```typescript
describe('Settlement — capture for the stats surface', () => {
    it('records the RESOLVED user on PlayerRound, even for a guest with no JWT', async () => {
        const user = await User.create({ deviceId: 'guest-1' });
        await settleRound({
            roundId: 'r-guest', worldThrow: 'S', counts: { R: 1, P: 0, S: 0 },
            throws: new Map([['guest-1', { deviceId: 'guest-1', platform: 'pwa', throw: 'R', seq: 1 } as ThrowEntry]]),
            timestamp: new Date(),
        });
        const row = await PlayerRound.findOne({ roundId: 'r-guest' });
        expect(row?.userId?.toString()).toBe(user._id.toString());
    });

    it('records a completed streak when a run ends in a LOSS', async () => {
        const user = await User.create({ deviceId: 'streak-1', currentStreak: 4, pointsAtStake: 27 });
        await settleRound({
            roundId: 'r-loss', worldThrow: 'P', counts: { R: 1, P: 0, S: 0 },
            throws: new Map([['streak-1', { deviceId: 'streak-1', platform: 'pwa', throw: 'R', seq: 1 } as ThrowEntry]]),
            timestamp: new Date(),
        });
        const events = await StreakEvent.find({ userId: user._id });
        expect(events).toHaveLength(1);
        expect(events[0].length).toBe(4);
        expect(events[0].endedBy).toBe('LOSS');
    });

    it('records a completed streak when a run ends in a SAFE', async () => {
        const user = await User.create({ deviceId: 'streak-2', currentStreak: 6 });
        await settleRound({
            roundId: 'r-safe', worldThrow: 'R', counts: { R: 1, P: 0, S: 0 },
            throws: new Map([['streak-2', { deviceId: 'streak-2', platform: 'pwa', throw: 'R', seq: 1 } as ThrowEntry]]),
            timestamp: new Date(),
        });
        const event = await StreakEvent.findOne({ userId: user._id });
        expect(event?.length).toBe(6);
        expect(event?.endedBy).toBe('SAFE');
    });

    it('records NOTHING when a WIN extends a streak', async () => {
        const user = await User.create({ deviceId: 'streak-3', currentStreak: 2 });
        await settleRound({
            roundId: 'r-win', worldThrow: 'S', counts: { R: 1, P: 0, S: 0 },
            throws: new Map([['streak-3', { deviceId: 'streak-3', platform: 'pwa', throw: 'R', seq: 1 } as ThrowEntry]]),
            timestamp: new Date(),
        });
        expect(await StreakEvent.countDocuments({ userId: user._id })).toBe(0);
    });

    it('records NOTHING when a player with no streak loses', async () => {
        const user = await User.create({ deviceId: 'streak-4', currentStreak: 0 });
        await settleRound({
            roundId: 'r-nostreak', worldThrow: 'P', counts: { R: 1, P: 0, S: 0 },
            throws: new Map([['streak-4', { deviceId: 'streak-4', platform: 'pwa', throw: 'R', seq: 1 } as ThrowEntry]]),
            timestamp: new Date(),
        });
        expect(await StreakEvent.countDocuments({ userId: user._id })).toBe(0);
    });
});
```

Add to that file's imports if absent:

```typescript
import StreakEvent from '../models/StreakEvent';
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server && npx vitest run src/engine/Settlement.test.ts`
Expected: FAIL — cannot find module `../models/StreakEvent`.

- [ ] **Step 3: Create the StreakEvent model**

Create `server/src/models/StreakEvent.ts`:

```typescript
import mongoose, { Schema, Document, Types } from 'mongoose';

// ONE ROW PER COMPLETED STREAK. `User.bestStreak` is an all-time maximum with no date, so
// "longest streak this week" is unanswerable without this. `BankEvent.streakAtBank` is not a
// substitute: it only sees streaks that were BANKED, and the spec wants cautious bankers and
// reckless riders to compete equally on the streak board — a rider whose run ends in a LOSS
// must still appear.
//
// Written only when a run actually ENDS, so this collection is far smaller than PlayerRound:
// one row per streak, not one per round. Banking does NOT end a streak (wallet.ts resets
// stakingStreak, never currentStreak), so the only terminators are SAFE and LOSS.
export interface IStreakEvent extends Document {
    userId: Types.ObjectId;
    length: number;
    endedBy: 'SAFE' | 'LOSS';
    endedAt: Date;
}

const StreakEventSchema: Schema = new Schema({
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true },
    length: { type: Number, required: true },
    endedBy: { type: String, enum: ['SAFE', 'LOSS'], required: true },
    endedAt: { type: Date, default: Date.now },
});

// "longest streak in this window", globally and per player.
StreakEventSchema.index({ endedAt: -1, length: -1 });
StreakEventSchema.index({ userId: 1, endedAt: -1 });

export default mongoose.model<IStreakEvent>('StreakEvent', StreakEventSchema);
```

- [ ] **Step 4: Record the resolved user on PlayerRound**

In `server/src/engine/Settlement.ts`, in the `PlayerRound.create({ ... })` call, replace the `userId` line:

```typescript
                await PlayerRound.create({
                    deviceId: entry.deviceId,
                    // THE RESOLVED user, not entry.userId (the client's claimed JWT id, which is
                    // absent for a guest playing on a deviceId alone). BankEvent and Session both
                    // key on the resolved id; a per-user aggregation over PlayerRound that used the
                    // claimed one would silently omit every guest.
                    userId: user._id,
                    robloxUserId: entry.robloxUserId,
```

- [ ] **Step 5: Write the streak event**

In `server/src/engine/Settlement.ts`, immediately after the `PlayerRound.create({...})` call and before `const counters = ...`, add:

```typescript
                // A run just ended. Banking does not end a streak (wallet.ts resets only
                // stakingStreak), so SAFE and LOSS are the only terminators. Written after the
                // history row and before the wallet update, matching the existing ordering
                // rationale: a failure here leaves the player unscored rather than mis-scored.
                const endedStreak = user.currentStreak || 0;
                if (result !== 'WIN' && endedStreak > 0) {
                    await StreakEvent.create({
                        userId: user._id,
                        length: endedStreak,
                        endedBy: result,
                        endedAt: data.timestamp,
                    });
                }
```

and add the import at the top of the file:

```typescript
import StreakEvent from '../models/StreakEvent';
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd server && npm test`
Expected: PASS, all suites.

- [ ] **Step 7: Verify build and type-check the test file**

Run: `cd server && npm run build`
Run: `cd server && npx tsc --noEmit --strict --esModuleInterop --resolveJsonModule --skipLibCheck --target es2022 --module commonjs --moduleResolution node src/engine/Settlement.test.ts`
Expected: both clean.

- [ ] **Step 8: Commit**

```bash
git add server/src/models/StreakEvent.ts server/src/engine/Settlement.ts server/src/engine/Settlement.test.ts
git commit -m "feat(server): record the resolved user and completed streaks

Two capture gaps that make three of the stats surface's queries impossible.

PlayerRound recorded entry.userId — the client's CLAIMED JWT id, which is optional — so
every guest playing on a deviceId alone wrote rows with no user id at all, and any per-user
aggregation over that collection silently omitted them. BankEvent and Session both key on
the resolved id; now so does this.

And there was no timestamped streak history: User.bestStreak is an all-time maximum with no
date, so 'longest streak this week' could not be answered. BankEvent.streakAtBank is not a
substitute because it only sees BANKED streaks, and the spec wants cautious bankers and
reckless riders to compete equally — a rider whose run ends in a LOSS must still appear.

StreakEvent is written only when a run ends, so it is far smaller than PlayerRound: one row
per streak, not per round. Banking does not end a streak, so SAFE and LOSS are the only
terminators.

NO BACKFILL: both are correct from here forward only. Historical PlayerRound rows keep
whatever userId they were given, and no streak that ended before this commit is recorded."
```

---

### Task 2: Window and qualification vocabulary

Every query below takes a window and some take a qualification threshold. Putting them in one module stops each caller inventing its own — which is how two boards end up disagreeing about when a week starts.

**Files:**
- Create: `server/src/windows.ts`
- Create: `server/src/windows.test.ts`

**Interfaces:**
- Consumes: nothing.
- Produces: `type Window = { from: Date; to: Date }`; `rollingWindow(now: Date, ms: number): Window`; `calendarDayUTC(now: Date): Window`; `calendarWeekUTC(now: Date): Window`; `HOUR_MS`, `DAY_MS`, `WEEK_MS`; `QUALIFY: { week: number; month: number; career: number }`.

- [ ] **Step 1: Write the failing tests**

Create `server/src/windows.test.ts`:

```typescript
import { describe, it, expect } from 'vitest';
import { rollingWindow, calendarDayUTC, calendarWeekUTC, HOUR_MS, DAY_MS, WEEK_MS, QUALIFY } from './windows';

describe('windows', () => {
    it('a rolling window ends at now and starts span-ago', () => {
        const now = new Date(Date.UTC(2026, 7, 16, 14, 30, 0));
        const w = rollingWindow(now, HOUR_MS);
        expect(w.to.toISOString()).toBe(now.toISOString());
        expect(w.from.toISOString()).toBe(new Date(Date.UTC(2026, 7, 16, 13, 30, 0)).toISOString());
    });

    it('a calendar day runs from UTC midnight to the NEXT midnight, half-open', () => {
        const w = calendarDayUTC(new Date(Date.UTC(2026, 7, 16, 14, 30, 0)));
        expect(w.from.toISOString()).toBe('2026-08-16T00:00:00.000Z');
        expect(w.to.toISOString()).toBe('2026-08-17T00:00:00.000Z');
    });

    it('a calendar day is stable anywhere inside it', () => {
        const a = calendarDayUTC(new Date(Date.UTC(2026, 7, 16, 0, 0, 0)));
        const b = calendarDayUTC(new Date(Date.UTC(2026, 7, 16, 23, 59, 59, 999)));
        expect(a.from.toISOString()).toBe(b.from.toISOString());
        expect(a.to.toISOString()).toBe(b.to.toISOString());
    });

    it('a calendar week starts MONDAY 00:00 UTC', () => {
        // 2026-08-16 is a Sunday; its week began Monday the 10th
        const w = calendarWeekUTC(new Date(Date.UTC(2026, 7, 16, 12, 0, 0)));
        expect(w.from.toISOString()).toBe('2026-08-10T00:00:00.000Z');
        expect(w.to.toISOString()).toBe('2026-08-17T00:00:00.000Z');
    });

    it('a Monday belongs to the week it starts, not the one before', () => {
        const w = calendarWeekUTC(new Date(Date.UTC(2026, 7, 10, 0, 0, 0)));
        expect(w.from.toISOString()).toBe('2026-08-10T00:00:00.000Z');
    });

    it('windows are exactly one span long', () => {
        const day = calendarDayUTC(new Date(Date.UTC(2026, 7, 16, 5, 0, 0)));
        expect(day.to.getTime() - day.from.getTime()).toBe(DAY_MS);
        const week = calendarWeekUTC(new Date(Date.UTC(2026, 7, 16, 5, 0, 0)));
        expect(week.to.getTime() - week.from.getTime()).toBe(WEEK_MS);
    });

    it('qualification thresholds are ordered and non-trivial', () => {
        expect(QUALIFY.week).toBeGreaterThan(0);
        expect(QUALIFY.month).toBeGreaterThan(QUALIFY.week);
        expect(QUALIFY.career).toBeGreaterThanOrEqual(QUALIFY.month);
    });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server && npx vitest run src/windows.test.ts`
Expected: FAIL — cannot find module `./windows`.

- [ ] **Step 3: Write the module**

Create `server/src/windows.ts`:

```typescript
// TIME AND QUALIFICATION VOCABULARY. Every stats query takes a window, and several take a
// minimum sample. Defining them once stops each caller inventing its own idea of when a week
// starts — which is how two boards end up disagreeing about the same player.
//
// ALL WINDOWS ARE HALF-OPEN [from, to). An event landing exactly on a boundary belongs to the
// LATER window, never both. Adopted repo-wide in plan 1.
//
// ALL CALENDAR WINDOWS ARE UTC. Not a placeholder for "local time later": players span the
// world and share one World Throw, so a board whose day boundary depends on the viewer would
// rank the same two players differently for each of them.
export interface Window {
    from: Date;
    to: Date;
}

export const HOUR_MS = 60 * 60 * 1000;
export const DAY_MS = 24 * HOUR_MS;
export const WEEK_MS = 7 * DAY_MS;

// HEAT uses rolling windows — "who is on a tear right now" means the last hour, not the hour
// since midnight, which would be nearly empty at 00:05.
export function rollingWindow(now: Date, ms: number): Window {
    return { from: new Date(now.getTime() - ms), to: new Date(now.getTime()) };
}

// RANK uses calendar windows — a standing has to name a period players can agree on.
export function calendarDayUTC(now: Date): Window {
    const from = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
    return { from, to: new Date(from.getTime() + DAY_MS) };
}

// Weeks start MONDAY, the ISO convention. getUTCDay() is 0 for Sunday, so shift it.
export function calendarWeekUTC(now: Date): Window {
    const day = calendarDayUTC(now);
    const dow = (now.getUTCDay() + 6) % 7; // Mon=0 … Sun=6
    const from = new Date(day.from.getTime() - dow * DAY_MS);
    return { from, to: new Date(from.getTime() + WEEK_MS) };
}

// MINIMUM SAMPLE FOR A RATE BOARD, in THROWS (never rounds elapsed — abstention is normal
// play). A blind player wins 1/3 of rounds, so the standard error of an observed win rate is
// 0.4714/sqrt(n): separating a +5-point edge from luck takes ~356 throws, and +3 points takes
// ~990. Below these, a board ranks noise and the top of it is whoever played least.
//
// These numbers are MEANT TO BE PRINTED on the board next to the ranking ("qualified: 350+
// throws this week"). A rule players can read is worth more here than statistical elegance.
export const QUALIFY = {
    week: 350,
    month: 1000,
    career: 1000,
};
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server && npx vitest run src/windows.test.ts`
Expected: PASS, 7 tests.

- [ ] **Step 5: Commit**

```bash
git add server/src/windows.ts server/src/windows.test.ts
git commit -m "feat(server): one place that owns time windows and qualification

Every stats query takes a window and several take a minimum sample. Defining them once stops
each caller inventing its own idea of when a week starts, which is how two boards end up
disagreeing about the same player.

Windows are half-open [from, to) as adopted in plan 1, and calendar windows are UTC — not a
placeholder for localisation. Players span the world and share one World Throw, so a board
whose day boundary depended on the viewer would rank the same two players differently for
each of them.

Heat gets rolling windows because 'who is on a tear right now' means the last hour, not the
hour since midnight, which is nearly empty at 00:05. Rank gets calendar windows because a
standing has to name a period players can agree on.

Qualification thresholds are in THROWS, never rounds elapsed, and are derived: at a 1/3 blind
win rate the standard error is 0.4714/sqrt(n), so separating a +5-point edge from luck takes
~356 throws. They are meant to be printed on the board beside the ranking."
```

---

### Task 3: Records queries

Discrete events with no sample-size problem, so short windows are legitimate (spec §4.1). These ship first because they work with fifty players.

**Files:**
- Create: `server/src/stats.ts`
- Create: `server/src/stats.test.ts`

**Interfaces:**
- Consumes: `Window` from Task 2; `StreakEvent` from Task 1.
- Produces: `longestStreaks(w: Window, limit: number): Promise<StreakRow[]>` where `StreakRow = { userId: Types.ObjectId; length: number; endedBy: 'SAFE' | 'LOSS'; endedAt: Date }`; `biggestBanks(w: Window, limit: number): Promise<BankRow[]>` where `BankRow = { userId: Types.ObjectId; amount: number; streakAtBank: number; timestamp: Date }`; `biggestRounds(w: Window, limit: number): Promise<RoundRow[]>` where `RoundRow = { userId: Types.ObjectId; pointsDelta: number; timestamp: Date }`.

- [ ] **Step 1: Write the failing tests**

Create `server/src/stats.test.ts`:

```typescript
import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { connectTestDb, clearTestDb, disconnectTestDb } from './test/db';
import User from './models/User';
import BankEvent from './models/BankEvent';
import StreakEvent from './models/StreakEvent';
import PlayerRound from './models/PlayerRound';
import { longestStreaks, biggestBanks, biggestRounds } from './stats';

beforeAll(connectTestDb);
afterAll(disconnectTestDb);
beforeEach(clearTestDb);

const at = (h: number) => new Date(Date.UTC(2026, 7, 16, h, 0, 0));
const W = { from: at(10), to: at(20) };

describe('records — longest streaks', () => {
    it('ranks by length, longest first', async () => {
        const a = await User.create({ deviceId: 'a' });
        const b = await User.create({ deviceId: 'b' });
        await StreakEvent.create({ userId: a._id, length: 3, endedBy: 'LOSS', endedAt: at(12) });
        await StreakEvent.create({ userId: b._id, length: 9, endedBy: 'SAFE', endedAt: at(13) });
        const rows = await longestStreaks(W, 10);
        expect(rows.map(r => r.length)).toEqual([9, 3]);
    });

    it('counts streaks that ended in a LOSS, not just banked ones', async () => {
        const a = await User.create({ deviceId: 'a' });
        await StreakEvent.create({ userId: a._id, length: 7, endedBy: 'LOSS', endedAt: at(12) });
        const rows = await longestStreaks(W, 10);
        expect(rows).toHaveLength(1);
        expect(rows[0].endedBy).toBe('LOSS');
    });

    it('excludes streaks outside the window, and the boundary at `to` belongs to the next window', async () => {
        const a = await User.create({ deviceId: 'a' });
        await StreakEvent.create({ userId: a._id, length: 5, endedBy: 'LOSS', endedAt: at(9) });
        await StreakEvent.create({ userId: a._id, length: 6, endedBy: 'LOSS', endedAt: at(20) });
        await StreakEvent.create({ userId: a._id, length: 4, endedBy: 'LOSS', endedAt: at(10) });
        const rows = await longestStreaks(W, 10);
        expect(rows.map(r => r.length)).toEqual([4]);
    });

    it('honours the limit', async () => {
        const a = await User.create({ deviceId: 'a' });
        for (const n of [1, 2, 3, 4, 5]) {
            await StreakEvent.create({ userId: a._id, length: n, endedBy: 'LOSS', endedAt: at(12) });
        }
        expect(await longestStreaks(W, 2)).toHaveLength(2);
    });
});

describe('records — biggest banks', () => {
    it('ranks by amount and carries the streak it was banked at', async () => {
        const a = await User.create({ deviceId: 'a' });
        await BankEvent.create({ userId: a._id, amount: 27, streakAtBank: 3, timestamp: at(12) });
        await BankEvent.create({ userId: a._id, amount: 243, streakAtBank: 5, timestamp: at(13) });
        const rows = await biggestBanks(W, 10);
        expect(rows.map(r => r.amount)).toEqual([243, 27]);
        expect(rows[0].streakAtBank).toBe(5);
    });

    it('excludes banks outside the window', async () => {
        const a = await User.create({ deviceId: 'a' });
        await BankEvent.create({ userId: a._id, amount: 999, timestamp: at(9) });
        await BankEvent.create({ userId: a._id, amount: 9, timestamp: at(12) });
        expect((await biggestBanks(W, 10)).map(r => r.amount)).toEqual([9]);
    });
});

describe('records — biggest rounds', () => {
    it('ranks WIN rows by pointsDelta, which on a WIN is the pot reached', async () => {
        const a = await User.create({ deviceId: 'a' });
        await PlayerRound.create({ userId: a._id, roundId: 'r1', playerThrow: 'R', playerResult: 'WIN', pointsDelta: 9, timestamp: at(12) });
        await PlayerRound.create({ userId: a._id, roundId: 'r2', playerThrow: 'R', playerResult: 'WIN', pointsDelta: 81, timestamp: at(13) });
        expect((await biggestRounds(W, 10)).map(r => r.pointsDelta)).toEqual([81, 9]);
    });

    it('NEVER returns a LOSS row, whose pointsDelta is a negative forfeit', async () => {
        const a = await User.create({ deviceId: 'a' });
        await PlayerRound.create({ userId: a._id, roundId: 'r1', playerThrow: 'R', playerResult: 'LOSS', pointsDelta: -81, timestamp: at(12) });
        await PlayerRound.create({ userId: a._id, roundId: 'r2', playerThrow: 'R', playerResult: 'WIN', pointsDelta: 3, timestamp: at(13) });
        const rows = await biggestRounds(W, 10);
        expect(rows).toHaveLength(1);
        expect(rows[0].pointsDelta).toBe(3);
    });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server && npx vitest run src/stats.test.ts`
Expected: FAIL — cannot find module `./stats`.

- [ ] **Step 3: Write the module**

Create `server/src/stats.ts`:

```typescript
import { Types } from 'mongoose';
import BankEvent from './models/BankEvent';
import StreakEvent from './models/StreakEvent';
import PlayerRound from './models/PlayerRound';
import { Window } from './windows';

// RECORDS — discrete, verifiable events with no sample-size problem, so short windows are
// legitimate and exciting (spec §4.1). These are the boards that work on launch day with
// fifty players, unlike any rate.

export interface StreakRow {
    userId: Types.ObjectId;
    length: number;
    endedBy: 'SAFE' | 'LOSS';
    endedAt: Date;
}

export async function longestStreaks(w: Window, limit: number): Promise<StreakRow[]> {
    const rows = await StreakEvent.find({ endedAt: { $gte: w.from, $lt: w.to } })
        .sort({ length: -1, endedAt: 1 })
        .limit(limit)
        .select('userId length endedBy endedAt');
    return rows.map(r => ({ userId: r.userId, length: r.length, endedBy: r.endedBy, endedAt: r.endedAt }));
}

export interface BankRow {
    userId: Types.ObjectId;
    amount: number;
    streakAtBank: number;
    timestamp: Date;
}

export async function biggestBanks(w: Window, limit: number): Promise<BankRow[]> {
    const rows = await BankEvent.find({ timestamp: { $gte: w.from, $lt: w.to } })
        .sort({ amount: -1, timestamp: 1 })
        .limit(limit)
        .select('userId amount streakAtBank timestamp');
    return rows.map(r => ({ userId: r.userId, amount: r.amount, streakAtBank: r.streakAtBank, timestamp: r.timestamp }));
}

export interface RoundRow {
    userId: Types.ObjectId;
    pointsDelta: number;
    timestamp: Date;
}

// WIN ROWS ONLY. On a WIN, `pointsDelta` is the pot REACHED that round, which is exactly the
// "biggest single round" figure. On a LOSS it is a negative forfeit and on a SAFE it is zero —
// neither belongs on a records board, and including LOSS rows would put the worst round in the
// game at the bottom of a list titled "biggest".
export async function biggestRounds(w: Window, limit: number): Promise<RoundRow[]> {
    const rows = await PlayerRound.find({
        playerResult: 'WIN',
        timestamp: { $gte: w.from, $lt: w.to },
    })
        .sort({ pointsDelta: -1, timestamp: 1 })
        .limit(limit)
        .select('userId pointsDelta timestamp');
    return rows.map(r => ({ userId: r.userId, pointsDelta: r.pointsDelta, timestamp: r.timestamp }));
}
```

- [ ] **Step 4: Add the supporting index**

`biggestRounds` filters on `playerResult` and `timestamp`. In `server/src/models/PlayerRound.ts`, beside the existing indexes, add:

```typescript
// The "biggest round in this window" records board.
PlayerRoundSchema.index({ playerResult: 1, timestamp: -1, pointsDelta: -1 });
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd server && npx vitest run src/stats.test.ts`
Expected: PASS, 8 tests.

- [ ] **Step 6: Full suite, build, strict type-check**

Run: `cd server && npm test && npm run build`
Run: `cd server && npx tsc --noEmit --strict --esModuleInterop --resolveJsonModule --skipLibCheck --target es2022 --module commonjs --moduleResolution node src/stats.test.ts`
Expected: all clean.

- [ ] **Step 7: Commit**

```bash
git add server/src/stats.ts server/src/stats.test.ts server/src/models/PlayerRound.ts
git commit -m "feat(server): records boards — longest streaks, biggest banks, biggest rounds

Discrete events with no sample-size problem, so short windows are legitimate. These are the
boards that work on launch day with fifty players, unlike any rate.

longestStreaks reads StreakEvent rather than BankEvent.streakAtBank, so a rider whose run
ended in a LOSS competes with a banker who cashed out — which the spec explicitly wants.

biggestRounds filters to WIN rows only. On a WIN, pointsDelta is the pot REACHED that round,
which is exactly the figure the board wants; on a LOSS it is a negative forfeit, which would
put the worst round in the game at the bottom of a list titled 'biggest'."
```

---

### Task 4: Volume and rate queries

Volume rewards commitment and needs no qualification. Rates need a minimum sample and are the reason Task 2 exists.

**Files:**
- Modify: `server/src/stats.ts`
- Modify: `server/src/stats.test.ts`

**Interfaces:**
- Consumes: `Window`, `QUALIFY` from Task 2; `earningsInWindow` from `leaderboards.ts` (plan 1).
- Produces: `throwsInWindow(userId, w): Promise<number>`; `forfeitsInWindow(userId, w): Promise<number>`; `playerVolume(userId, w): Promise<{ throws: number; roundsPresent: number; earned: number }>`; `playerRates(userId, w, minThrows): Promise<{ throws: number; qualified: boolean; minThrows: number; pointsPerThrow: number | null; captureRate: number | null; participationRate: number | null }>`.

- [ ] **Step 1: Write the failing tests**

Append to `server/src/stats.test.ts` (DB hooks are already at file scope — add none):

```typescript
describe('volume', () => {
    it('counts throws in the window, excluding the boundary at `to`', async () => {
        const a = await User.create({ deviceId: 'a' });
        for (const [h, id] of [[9, 'x'], [12, 'y'], [20, 'z']] as [number, string][]) {
            await PlayerRound.create({ userId: a._id, roundId: id, playerThrow: 'R', playerResult: 'WIN', pointsDelta: 1, timestamp: at(h) });
        }
        expect(await throwsInWindow(a._id, W)).toBe(1);
    });

    it('counts a guest\'s throws, which are keyed on the resolved user', async () => {
        const a = await User.create({ deviceId: 'guest' });
        await PlayerRound.create({ userId: a._id, roundId: 'g1', playerThrow: 'R', playerResult: 'SAFE', pointsDelta: 0, timestamp: at(12) });
        expect(await throwsInWindow(a._id, W)).toBe(1);
    });
});

describe('forfeits', () => {
    it('sums LOSS deltas as a POSITIVE forfeited total', async () => {
        const a = await User.create({ deviceId: 'a' });
        await PlayerRound.create({ userId: a._id, roundId: 'l1', playerThrow: 'R', playerResult: 'LOSS', pointsDelta: -27, timestamp: at(12) });
        await PlayerRound.create({ userId: a._id, roundId: 'l2', playerThrow: 'R', playerResult: 'LOSS', pointsDelta: -9, timestamp: at(13) });
        expect(await forfeitsInWindow(a._id, W)).toBe(36);
    });

    it('IGNORES WIN rows, whose delta is the new pot and not a gain', async () => {
        const a = await User.create({ deviceId: 'a' });
        await PlayerRound.create({ userId: a._id, roundId: 'w1', playerThrow: 'R', playerResult: 'WIN', pointsDelta: 81, timestamp: at(12) });
        await PlayerRound.create({ userId: a._id, roundId: 'l1', playerThrow: 'R', playerResult: 'LOSS', pointsDelta: -3, timestamp: at(13) });
        expect(await forfeitsInWindow(a._id, W)).toBe(3);
    });

    it('is zero when nothing was lost', async () => {
        const a = await User.create({ deviceId: 'a' });
        expect(await forfeitsInWindow(a._id, W)).toBe(0);
    });
});

describe('rates and qualification', () => {
    it('reports NOT qualified and null rates below the minimum', async () => {
        const a = await User.create({ deviceId: 'a' });
        await PlayerRound.create({ userId: a._id, roundId: 'r1', playerThrow: 'R', playerResult: 'WIN', pointsDelta: 1, timestamp: at(12) });
        const rates = await playerRates(a._id, W, 10);
        expect(rates.qualified).toBe(false);
        expect(rates.pointsPerThrow).toBeNull();
        expect(rates.minThrows).toBe(10);
        expect(rates.throws).toBe(1);
    });

    it('computes points per THROW once qualified', async () => {
        const a = await User.create({ deviceId: 'a' });
        for (let i = 0; i < 4; i++) {
            await PlayerRound.create({ userId: a._id, roundId: `r${i}`, playerThrow: 'R', playerResult: 'WIN', pointsDelta: 1, timestamp: at(12) });
        }
        await BankEvent.create({ userId: a._id, amount: 40, timestamp: at(13) });
        const rates = await playerRates(a._id, W, 4);
        expect(rates.qualified).toBe(true);
        expect(rates.pointsPerThrow).toBe(10);
    });

    it('computes capture rate as banked over banked-plus-forfeited', async () => {
        const a = await User.create({ deviceId: 'a' });
        for (let i = 0; i < 2; i++) {
            await PlayerRound.create({ userId: a._id, roundId: `t${i}`, playerThrow: 'R', playerResult: 'WIN', pointsDelta: 1, timestamp: at(12) });
        }
        await BankEvent.create({ userId: a._id, amount: 30, timestamp: at(13) });
        await PlayerRound.create({ userId: a._id, roundId: 'l1', playerThrow: 'R', playerResult: 'LOSS', pointsDelta: -10, timestamp: at(14) });
        const rates = await playerRates(a._id, W, 1);
        expect(rates.captureRate).toBeCloseTo(0.75, 5);
    });

    it('leaves capture rate null when nothing was built', async () => {
        const a = await User.create({ deviceId: 'a' });
        await PlayerRound.create({ userId: a._id, roundId: 'r1', playerThrow: 'R', playerResult: 'SAFE', pointsDelta: 0, timestamp: at(12) });
        const rates = await playerRates(a._id, W, 1);
        expect(rates.captureRate).toBeNull();
    });
});
```

Extend the existing import from `./stats` (do not add a second import line):

```typescript
import { longestStreaks, biggestBanks, biggestRounds, throwsInWindow, forfeitsInWindow, playerRates } from './stats';
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server && npx vitest run src/stats.test.ts`
Expected: FAIL — `throwsInWindow` is not exported.

- [ ] **Step 3: Write the volume and forfeit queries**

Append to `server/src/stats.ts`:

```typescript
// VOLUME — rewards commitment rather than skill, needs no qualification, and must be labelled
// as commitment wherever it is shown (spec §4.3).

export async function throwsInWindow(userId: Types.ObjectId, w: Window): Promise<number> {
    return PlayerRound.countDocuments({ userId, timestamp: { $gte: w.from, $lt: w.to } });
}

// THE ONE PLACE `pointsDelta` MAY BE SUMMED. The column is poisonous for earnings because on a
// WIN it records the new POT rather than the gain — but on a LOSS it is exactly the pot that
// was forfeited, negated. Filtering to LOSS rows is what makes the sum meaningful, so the
// filter is not an optimisation and must never be relaxed.
export async function forfeitsInWindow(userId: Types.ObjectId, w: Window): Promise<number> {
    const [row] = await PlayerRound.aggregate([
        { $match: { userId, playerResult: 'LOSS', timestamp: { $gte: w.from, $lt: w.to } } },
        { $group: { _id: null, lost: { $sum: '$pointsDelta' } } },
    ]);
    return row ? Math.abs(row.lost) : 0;
}
```

- [ ] **Step 4: Write the rate query**

Append to `server/src/stats.ts`:

```typescript
// RATES — need a minimum sample, so every result carries the threshold it was judged against
// and whether it met it. A rate board that silently drops unqualified players looks broken to
// the player who is missing from it; one that includes them ranks noise. Returning `qualified`
// plus `minThrows` lets the caller show "142 / 350 throws" instead of nothing.
//
// Denominator is THROWS, never rounds elapsed: abstention is normal play, and a patient player
// who throws in a fifth of rounds is playing well, not playing little.
export interface PlayerRates {
    throws: number;
    qualified: boolean;
    minThrows: number;
    pointsPerThrow: number | null;
    captureRate: number | null;
    participationRate: number | null;
}

export async function playerRates(
    userId: Types.ObjectId,
    w: Window,
    minThrows: number
): Promise<PlayerRates> {
    const throws = await throwsInWindow(userId, w);
    const qualified = throws >= minThrows;

    // Capture rate and participation are reported even when unqualified for the RATE board,
    // because they answer different questions and have their own denominators; only
    // pointsPerThrow is gated, since it is the one a leaderboard would rank on.
    const [earned, forfeited, present] = await Promise.all([
        earningsInWindow(userId, w.from, w.to),
        forfeitsInWindow(userId, w),
        roundsPresent(userId, w.from, w.to),
    ]);

    const built = earned + forfeited;
    return {
        throws,
        qualified,
        minThrows,
        pointsPerThrow: qualified && throws > 0 ? earned / throws : null,
        captureRate: built > 0 ? earned / built : null,
        participationRate: present > 0 ? throws / present : null,
    };
}
```

and extend the imports at the TOP of `server/src/stats.ts`:

```typescript
import { earningsInWindow } from './leaderboards';
import { roundsPresent } from './sessions';
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd server && npx vitest run src/stats.test.ts`
Expected: PASS, 17 tests.

- [ ] **Step 6: Full suite, build, strict type-check**

Run: `cd server && npm test && npm run build`
Run: `cd server && npx tsc --noEmit --strict --esModuleInterop --resolveJsonModule --skipLibCheck --target es2022 --module commonjs --moduleResolution node src/stats.test.ts`
Expected: all clean.

- [ ] **Step 7: Commit**

```bash
git add server/src/stats.ts server/src/stats.test.ts
git commit -m "feat(server): volume and rate queries, with qualification carried in the result

Volume rewards commitment and needs no qualification. Rates need a minimum sample, so every
result carries the threshold it was judged against and whether it met it — a board can then
show '142 / 350 throws' rather than silently omitting a player, which looks broken to the
player who is missing.

forfeitsInWindow is the ONE place pointsDelta may be summed. The column is poisonous for
earnings because a WIN records the new pot rather than the gain — but on a LOSS it is exactly
the forfeited pot, negated. The LOSS filter is what makes the sum meaningful; it is not an
optimisation and must never be relaxed.

Denominator throughout is THROWS, never rounds elapsed: abstention is normal play, and a
patient player who throws in a fifth of rounds is playing well, not playing little."
```

---

### Task 5: Heat — scoping a board to who is actually here

Heat is per-server as well as global (owner: "current global/local points leader"). `BankEvent` carries no `instanceId`, and adding one would need a Roblox client change. It is not needed: presence already knows who is in an instance, so "local" means *ranking the people currently here* by their own window figures.

**Files:**
- Modify: `server/src/sessions.ts`
- Modify: `server/src/stats.ts`
- Modify: `server/src/sessions.test.ts`
- Modify: `server/src/stats.test.ts`

**Interfaces:**
- Consumes: `Session` from plan 1; `topEarnersInWindow` from `leaderboards.ts`.
- Produces: `presentIn(instanceId: string): Promise<Types.ObjectId[]>`; `heatBoard(w: Window, limit: number, userIds?: Types.ObjectId[]): Promise<{ userId: Types.ObjectId; earned: number }[]>`.

- [ ] **Step 1: Write the failing tests**

Append to `server/src/sessions.test.ts` (hooks are at file scope — add none):

```typescript
describe('presentIn', () => {
    it('returns the players whose session in that instance is still open', async () => {
        const a = await User.create({ deviceId: 'a' });
        const b = await User.create({ deviceId: 'b' });
        await reconcilePresence('inst-A', [a._id, b._id], at(0));
        const ids = await presentIn('inst-A');
        expect(ids.map(String).sort()).toEqual([a._id.toString(), b._id.toString()].sort());
    });

    it('omits players who have left', async () => {
        const a = await User.create({ deviceId: 'a' });
        const b = await User.create({ deviceId: 'b' });
        await reconcilePresence('inst-A', [a._id, b._id], at(0));
        await reconcilePresence('inst-A', [a._id], at(5));
        expect((await presentIn('inst-A')).map(String)).toEqual([a._id.toString()]);
    });

    it('does not leak players from another instance', async () => {
        const a = await User.create({ deviceId: 'a' });
        const b = await User.create({ deviceId: 'b' });
        await reconcilePresence('inst-A', [a._id], at(0));
        await reconcilePresence('inst-B', [b._id], at(0));
        expect((await presentIn('inst-A')).map(String)).toEqual([a._id.toString()]);
    });

    it('returns an empty list for an unknown instance', async () => {
        expect(await presentIn('nobody-here')).toEqual([]);
    });
});
```

Extend the existing `./sessions` import with `presentIn`.

Append to `server/src/stats.test.ts`:

```typescript
describe('heat', () => {
    it('ranks by window earnings, ignoring career standing', async () => {
        const veteran = await User.create({ deviceId: 'veteran', lifetimeBanked: 90_000 });
        const newcomer = await User.create({ deviceId: 'newcomer', lifetimeBanked: 3 });
        await BankEvent.create({ userId: veteran._id, amount: 10, timestamp: at(12) });
        await BankEvent.create({ userId: newcomer._id, amount: 400, timestamp: at(12) });
        const rows = await heatBoard(W, 10);
        expect(rows.map(r => r.userId.toString())).toEqual([newcomer._id.toString(), veteran._id.toString()]);
    });

    it('restricted to a set of players, ranks only those players', async () => {
        const here = await User.create({ deviceId: 'here' });
        const elsewhere = await User.create({ deviceId: 'elsewhere' });
        await BankEvent.create({ userId: elsewhere._id, amount: 5000, timestamp: at(12) });
        await BankEvent.create({ userId: here._id, amount: 5, timestamp: at(12) });
        const rows = await heatBoard(W, 10, [here._id]);
        expect(rows).toHaveLength(1);
        expect(rows[0].userId.toString()).toBe(here._id.toString());
    });

    it('is empty when the restricted set has banked nothing in the window', async () => {
        const here = await User.create({ deviceId: 'here' });
        expect(await heatBoard(W, 10, [here._id])).toEqual([]);
    });
});
```

Extend the existing `./stats` import with `heatBoard`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server && npx vitest run src/sessions.test.ts src/stats.test.ts`
Expected: FAIL — `presentIn` and `heatBoard` are not exported.

- [ ] **Step 3: Add `presentIn`**

Append to `server/src/sessions.ts`:

```typescript
// WHO IS IN THIS INSTANCE RIGHT NOW. An open session in the instance IS presence — this is the
// same state reconcilePresence maintains, read rather than written.
export async function presentIn(instanceId: string): Promise<Types.ObjectId[]> {
    const rows = await Session.find({ instanceId, endedAt: { $exists: false } }).select('userId');
    return [...new Set(rows.map(r => r.userId.toString()))].map(id => new Types.ObjectId(id));
}
```

- [ ] **Step 4: Add `heatBoard`**

Append to `server/src/stats.ts`:

```typescript
// HEAT — "who is on a tear right now" (spec §3). Deliberately unqualified and deliberately
// independent of career standing: a newcomer must be able to top it while ranking nowhere
// all-time. It is FORM, not standing, and whatever shows it must say so.
//
// The optional `userIds` is how a board becomes LOCAL. BankEvent carries no instanceId, and
// adding one would need a Roblox client change — but it is not needed: presence already knows
// who is in an instance, so "the leader in this server" means ranking the people currently
// here by their own window figures. That is also the more honest reading: a player who earned
// elsewhere and then walked in is genuinely one of the hottest players in the room.
export async function heatBoard(
    w: Window,
    limit: number,
    userIds?: Types.ObjectId[]
): Promise<{ userId: Types.ObjectId; earned: number }[]> {
    if (userIds && userIds.length === 0) return [];
    const match: Record<string, unknown> = { timestamp: { $gte: w.from, $lt: w.to } };
    if (userIds) match.userId = { $in: userIds };

    const rows = await BankEvent.aggregate([
        { $match: match },
        { $group: { _id: '$userId', earned: { $sum: '$amount' } } },
        { $sort: { earned: -1 } },
        { $limit: limit },
    ]);
    return rows.map(r => ({ userId: r._id as Types.ObjectId, earned: r.earned as number }));
}
```

- [ ] **Step 5: Add the LIVE streak board**

`longestStreaks` reads `StreakEvent`, which only holds streaks that have ENDED. The spec (§4.1)
asks for a live board too — a run of 9 currently in progress is the most exciting number in the
game and appears nowhere yet. That lives on `User.currentStreak`.

Append to `server/src/stats.ts`:

```typescript
// THE LIVE BOARD. StreakEvent holds only COMPLETED runs, so a streak in progress — the most
// exciting number in the game while it lasts — appears in none of the above. This reads the
// running counter instead. `currentStreak` survives banking (wallet.ts resets only
// stakingStreak), so a cautious banker riding a long run still shows here.
//
// Restricted by `userIds` the same way heatBoard is, so a server can ask "who is on the
// longest run in THIS room right now".
export async function liveStreaks(
    limit: number,
    userIds?: Types.ObjectId[]
): Promise<{ userId: Types.ObjectId; length: number }[]> {
    if (userIds && userIds.length === 0) return [];
    const filter: Record<string, unknown> = { currentStreak: { $gt: 0 } };
    if (userIds) filter._id = { $in: userIds };

    const rows = await User.find(filter).sort({ currentStreak: -1 }).limit(limit).select('currentStreak');
    return rows.map(u => ({ userId: u._id as Types.ObjectId, length: u.currentStreak }));
}
```

Add `import User from './models/User';` to the top of `server/src/stats.ts`.

Add the supporting index in `server/src/models/User.ts`, after the schema and before the model
export:

```typescript
// The live streak board.
UserSchema.index({ currentStreak: -1 });
```

Append these tests to `server/src/stats.test.ts`, and extend the existing `./stats` import with
`liveStreaks`:

```typescript
describe('live streaks', () => {
    it('ranks players by their running streak, longest first', async () => {
        await User.create({ deviceId: 'a', currentStreak: 2 });
        await User.create({ deviceId: 'b', currentStreak: 9 });
        expect((await liveStreaks(10)).map(r => r.length)).toEqual([9, 2]);
    });

    it('omits players who are not on a streak', async () => {
        await User.create({ deviceId: 'a', currentStreak: 0 });
        await User.create({ deviceId: 'b', currentStreak: 4 });
        const rows = await liveStreaks(10);
        expect(rows).toHaveLength(1);
        expect(rows[0].length).toBe(4);
    });

    it('restricted to a set of players, ranks only those players', async () => {
        const here = await User.create({ deviceId: 'here', currentStreak: 3 });
        await User.create({ deviceId: 'elsewhere', currentStreak: 30 });
        const rows = await liveStreaks(10, [here._id]);
        expect(rows).toHaveLength(1);
        expect(rows[0].length).toBe(3);
    });
});
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd server && npx vitest run src/sessions.test.ts src/stats.test.ts`
Expected: PASS.

- [ ] **Step 6: Full suite, build, strict type-check**

Run: `cd server && npm test && npm run build`
Run: `cd server && npx tsc --noEmit --strict --esModuleInterop --resolveJsonModule --skipLibCheck --target es2022 --module commonjs --moduleResolution node src/stats.test.ts src/sessions.test.ts`
Expected: all clean.

- [ ] **Step 7: Commit**

```bash
git add server/src/sessions.ts server/src/stats.ts server/src/sessions.test.ts server/src/stats.test.ts
git commit -m "feat(server): heat boards, and local scoping via presence

Heat is 'who is on a tear right now' — unqualified by design and independent of career
standing, so a newcomer can top it while ranking nowhere all-time.

Local scoping does NOT need an instanceId on BankEvent, which would have meant a Roblox client
change. Presence already knows who is in an instance, so 'the leader in this server' means
ranking the people currently here by their own window figures. That is also the more honest
reading: a player who earned elsewhere and then walked in really is one of the hottest players
in the room."
```

---

### Task 6: The API surface

Expose the queries to both clients without inventing a display. The PWA reads over Socket.io, Roblox over `/api/v1`.

**Files:**
- Create: `server/src/routes/statsV1.ts`
- Create: `server/src/routes/statsV1.test.ts`
- Modify: `server/src/index.ts`
- Modify: `server/src/transports/socketAdapter.ts`

**Interfaces:**
- Consumes: everything from Tasks 2-5.
- Produces: `createStatsV1(): Router` mounted at `/api/v1/stats`; socket event `stats-surface`.

- [ ] **Step 1: Write the failing tests**

Create `server/src/routes/statsV1.test.ts`:

```typescript
import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import express from 'express';
import request from 'supertest';
import { connectTestDb, clearTestDb, disconnectTestDb } from '../test/db';
import User from '../models/User';
import BankEvent from '../models/BankEvent';
import StreakEvent from '../models/StreakEvent';
import { createStatsV1 } from './statsV1';

const app = express();
app.use(express.json());
app.use('/api/v1/stats', createStatsV1());

beforeAll(connectTestDb);
afterAll(disconnectTestDb);
beforeEach(clearTestDb);

describe('GET /api/v1/stats/records', () => {
    it('returns the three records boards for a window', async () => {
        const a = await User.create({ deviceId: 'a', displayName: 'Ayaka' });
        await StreakEvent.create({ userId: a._id, length: 7, endedBy: 'LOSS', endedAt: new Date() });
        await BankEvent.create({ userId: a._id, amount: 81, timestamp: new Date() });

        const res = await request(app).get('/api/v1/stats/records?window=day');
        expect(res.status).toBe(200);
        expect(res.body.window).toBe('day');
        expect(res.body.longestStreaks[0].length).toBe(7);
        expect(res.body.biggestBanks[0].amount).toBe(81);
        expect(Array.isArray(res.body.biggestRounds)).toBe(true);
    });

    it('rejects an unknown window rather than silently choosing one', async () => {
        const res = await request(app).get('/api/v1/stats/records?window=fortnight');
        expect(res.status).toBe(400);
    });

    it('names the players, so a caller does not need a second round trip', async () => {
        const a = await User.create({ deviceId: 'a', displayName: 'Ayaka' });
        await StreakEvent.create({ userId: a._id, length: 4, endedBy: 'SAFE', endedAt: new Date() });
        const res = await request(app).get('/api/v1/stats/records?window=day');
        expect(res.body.longestStreaks[0].displayName).toBe('Ayaka');
    });

    it('never returns a deviceId', async () => {
        const a = await User.create({ deviceId: 'secret-device', displayName: 'Ayaka' });
        await StreakEvent.create({ userId: a._id, length: 4, endedBy: 'SAFE', endedAt: new Date() });
        const res = await request(app).get('/api/v1/stats/records?window=day');
        expect(JSON.stringify(res.body)).not.toContain('secret-device');
    });
});

describe('GET /api/v1/stats/heat', () => {
    it('ranks by window earnings and labels itself as form', async () => {
        const a = await User.create({ deviceId: 'a', displayName: 'Ayaka' });
        await BankEvent.create({ userId: a._id, amount: 40, timestamp: new Date() });
        const res = await request(app).get('/api/v1/stats/heat?window=hour');
        expect(res.status).toBe(200);
        expect(res.body.kind).toBe('heat');
        expect(res.body.qualified).toBe(false);
        expect(res.body.leaders[0].earned).toBe(40);
    });

    it('scopes to an instance when one is given', async () => {
        const a = await User.create({ deviceId: 'a' });
        await BankEvent.create({ userId: a._id, amount: 40, timestamp: new Date() });
        const res = await request(app).get('/api/v1/stats/heat?window=hour&instanceId=empty-room');
        expect(res.status).toBe(200);
        expect(res.body.leaders).toEqual([]);
    });
});
```

If `supertest` is not already a devDependency, add it: `cd server && npm install -D supertest @types/supertest`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd server && npx vitest run src/routes/statsV1.test.ts`
Expected: FAIL — cannot find module `./statsV1`.

- [ ] **Step 3: Write the router**

Create `server/src/routes/statsV1.ts`:

```typescript
import { Router } from 'express';
import { Types } from 'mongoose';
import User from '../models/User';
import { longestStreaks, biggestBanks, biggestRounds, heatBoard } from '../stats';
import { presentIn } from '../sessions';
import { rollingWindow, calendarDayUTC, calendarWeekUTC, HOUR_MS, DAY_MS, WEEK_MS, Window } from '../windows';

const LIMIT = 10;

// HEAT gets ROLLING windows, RANK gets CALENDAR ones (see windows.ts). Records are read as
// calendar periods because they are a standing, not form.
function recordsWindow(name: string, now: Date): Window | null {
    if (name === 'day') return calendarDayUTC(now);
    if (name === 'week') return calendarWeekUTC(now);
    if (name === 'all') return { from: new Date(0), to: new Date(now.getTime() + DAY_MS) };
    return null;
}

function heatWindow(name: string, now: Date): Window | null {
    if (name === 'hour') return rollingWindow(now, HOUR_MS);
    if (name === 'day') return rollingWindow(now, DAY_MS);
    if (name === 'week') return rollingWindow(now, WEEK_MS);
    return null;
}

// NAME THE PLAYERS HERE. Every board returns user ids; resolving them once server-side saves
// the caller a second round trip, and — more importantly — keeps the projection in ONE place,
// so `deviceId` (a bearer credential on the socket path) cannot leak into an API response by
// someone adding a field to a shared list.
async function nameUsers(ids: Types.ObjectId[]): Promise<Map<string, string>> {
    if (ids.length === 0) return new Map();
    const users = await User.find({ _id: { $in: ids } }).select('displayName');
    return new Map(users.map(u => [u._id.toString(), u.displayName || 'Anonymous']));
}

export function createStatsV1(): Router {
    const router = Router();

    router.get('/records', async (req, res) => {
        try {
            const w = recordsWindow(String(req.query.window ?? ''), new Date());
            if (!w) {
                res.status(400).json({ error: 'BAD_WINDOW', accepts: ['day', 'week', 'all'] });
                return;
            }
            const [streaks, banks, rounds] = await Promise.all([
                longestStreaks(w, LIMIT),
                biggestBanks(w, LIMIT),
                biggestRounds(w, LIMIT),
            ]);
            const names = await nameUsers([
                ...streaks.map(r => r.userId),
                ...banks.map(r => r.userId),
                ...rounds.map(r => r.userId),
            ]);
            const name = (id: Types.ObjectId) => names.get(id.toString()) ?? 'Anonymous';
            res.set('Cache-Control', 'public, max-age=30');
            res.json({
                window: String(req.query.window),
                longestStreaks: streaks.map(r => ({ displayName: name(r.userId), length: r.length, endedBy: r.endedBy })),
                biggestBanks: banks.map(r => ({ displayName: name(r.userId), amount: r.amount, streakAtBank: r.streakAtBank })),
                biggestRounds: rounds.map(r => ({ displayName: name(r.userId), points: r.pointsDelta })),
            });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    router.get('/heat', async (req, res) => {
        try {
            const w = heatWindow(String(req.query.window ?? ''), new Date());
            if (!w) {
                res.status(400).json({ error: 'BAD_WINDOW', accepts: ['hour', 'day', 'week'] });
                return;
            }
            const instanceId = String(req.query.instanceId ?? '').trim();
            const scope = instanceId ? await presentIn(instanceId) : undefined;
            const rows = await heatBoard(w, LIMIT, scope);
            const names = await nameUsers(rows.map(r => r.userId));
            res.set('Cache-Control', 'public, max-age=15');
            res.json({
                // FORM, NOT STANDING. The wire says so, so a display cannot quietly present a
                // lucky hour as a ranking (spec §3).
                kind: 'heat',
                qualified: false,
                window: String(req.query.window),
                scope: instanceId || 'global',
                leaders: rows.map(r => ({ displayName: names.get(r.userId.toString()) ?? 'Anonymous', earned: r.earned })),
            });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    return router;
}
```

- [ ] **Step 4: Add the per-player endpoint**

`playerRates` and `QUALIFY` exist and nothing calls them. The room is personal-first (spec §6):
a player's own standing greets them on entry, and that needs an endpoint.

Add to `server/src/routes/statsV1.ts`, inside `createStatsV1()`:

```typescript
    // PERSONAL-FIRST. The room reads the viewer before it reads the world (spec §6), so this
    // is the endpoint the entry slips use. It returns the qualification threshold alongside
    // the figures, so a display can honestly show "142 / 350 throws" rather than a blank.
    router.get('/player/:robloxUserId', async (req, res) => {
        try {
            const w = calendarWeekUTC(new Date());
            const user = await User.findOne({ robloxId: String(req.params.robloxUserId) }).select('_id displayName currentStreak bestStreak lifetimeBanked');
            if (!user) {
                res.status(404).json({ error: 'NOT_FOUND' });
                return;
            }
            const rates = await playerRates(user._id, w, QUALIFY.week);
            res.set('Cache-Control', 'private, max-age=15');
            res.json({
                displayName: user.displayName || 'Anonymous',
                career: {
                    banked: user.lifetimeBanked ?? 0,
                    bestStreak: user.bestStreak ?? 0,
                },
                currentStreak: user.currentStreak ?? 0,
                week: rates,
            });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });
```

Extend that file's imports:

```typescript
import { longestStreaks, biggestBanks, biggestRounds, heatBoard, playerRates } from '../stats';
import { rollingWindow, calendarDayUTC, calendarWeekUTC, HOUR_MS, DAY_MS, WEEK_MS, QUALIFY, Window } from '../windows';
```

Append these tests to `server/src/routes/statsV1.test.ts`:

```typescript
describe('GET /api/v1/stats/player/:robloxUserId', () => {
    it('returns career figures and the weekly rates', async () => {
        await User.create({ robloxId: '4242', displayName: 'Ayaka', lifetimeBanked: 900, bestStreak: 6, currentStreak: 2 });
        const res = await request(app).get('/api/v1/stats/player/4242');
        expect(res.status).toBe(200);
        expect(res.body.displayName).toBe('Ayaka');
        expect(res.body.career.banked).toBe(900);
        expect(res.body.currentStreak).toBe(2);
    });

    it('reports the qualification threshold even when unqualified, so a display can show progress', async () => {
        await User.create({ robloxId: '4243', displayName: 'Kenshin' });
        const res = await request(app).get('/api/v1/stats/player/4243');
        expect(res.body.week.qualified).toBe(false);
        expect(res.body.week.minThrows).toBeGreaterThan(0);
        expect(res.body.week.throws).toBe(0);
        expect(res.body.week.pointsPerThrow).toBeNull();
    });

    it('404s for an unknown player rather than inventing an empty one', async () => {
        const res = await request(app).get('/api/v1/stats/player/nobody');
        expect(res.status).toBe(404);
    });

    it('never returns a deviceId', async () => {
        await User.create({ robloxId: '4244', deviceId: 'secret-device', displayName: 'Ayaka' });
        const res = await request(app).get('/api/v1/stats/player/4244');
        expect(JSON.stringify(res.body)).not.toContain('secret-device');
    });
});
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server && npx vitest run src/routes/statsV1.test.ts`
Expected: PASS, 10 tests.

- [ ] **Step 5: Mount the router**

In `server/src/index.ts`, beside the existing `app.use('/api/v1', createApiV1(engine, store));`:

```typescript
        app.use('/api/v1/stats', createStatsV1());
```

and add the import at the top:

```typescript
import { createStatsV1 } from './routes/statsV1';
```

Note `/api/v1/stats` is mounted separately rather than inside `createApiV1` because it needs neither the engine nor the store, and because these boards are readable without the `X-API-Key` gate that guards player mutation.

- [ ] **Step 6: Serve the same surface to the PWA**

In `server/src/transports/socketAdapter.ts`, add a handler beside the existing `get-stats`:

```typescript
        // The Stats room's surface, for the PWA. Same queries as /api/v1/stats — the wire
        // shapes differ because the transports do, but the numbers come from one place.
        socket.on('get-stats-surface', async (data: { window?: string }) => {
            try {
                const now = new Date();
                const w = calendarDayUTC(now);
                const heat = rollingWindow(now, HOUR_MS);
                const [streaks, banks, hot] = await Promise.all([
                    longestStreaks(w, 10),
                    biggestBanks(w, 10),
                    heatBoard(heat, 10),
                ]);
                socket.emit('stats-surface', {
                    day: { longestStreaks: streaks, biggestBanks: banks },
                    heat: { kind: 'heat', qualified: false, leaders: hot },
                });
            } catch (err) {
                console.error('Error fetching stats surface:', (err as Error).message);
            }
        });
```

and extend that file's imports:

```typescript
import { longestStreaks, biggestBanks, heatBoard } from '../stats';
import { calendarDayUTC, rollingWindow, HOUR_MS } from '../windows';
```

- [ ] **Step 7: Full suite, build, strict type-check**

Run: `cd server && npm test && npm run build`
Run: `cd server && npx tsc --noEmit --strict --esModuleInterop --resolveJsonModule --skipLibCheck --target es2022 --module commonjs --moduleResolution node src/routes/statsV1.test.ts`
Expected: all clean.

- [ ] **Step 8: Commit**

```bash
git add server/src/routes/statsV1.ts server/src/routes/statsV1.test.ts server/src/index.ts server/src/transports/socketAdapter.ts server/package.json server/package-lock.json
git commit -m "feat(server): the stats surface, over REST and the socket

Exposes the records and heat boards to both clients. One set of queries, two wire shapes,
because the transports differ and the numbers must not.

Player names are resolved server-side, which saves the caller a round trip and keeps the
projection in ONE place — so deviceId, a bearer credential on the socket path, cannot leak
into an API response because someone added a field to a shared list. That is exactly how it
leaked once already.

The heat response carries kind:'heat' and qualified:false on the wire, so a display cannot
quietly present a lucky hour as a standing. An unknown window is a 400 rather than a silent
fallback: a board that shows the wrong period looks identical to one that shows the right one."
```

---

## What this plan deliberately does NOT do

- **No display.** Plan 3 owns the Roblox walls and is additionally blocked on retargeting `BoardController` at the kōsatsu boards — it has no-opped since the jumbotron was removed (T23).
- **No Edge.** Win rate − 33.3% stays parked until there is a real player base to judge it against, per the spec. It is also meaningless until defect (h) is ACTIVE — both environments still run `TEST_MODE`, so the World Throw is not yet the crowd.
- **No participation-vs-winrate study.** §4.4's population scatter needs the same live-play data as Edge.
- **No seasons.** Space is reserved in the room, not built; season length is deliberately unset until real play patterns exist.
- **No backfill.** `StreakEvent` starts empty and `PlayerRound.userId` is correct only from Task 1 forward. Boards covering periods before this plan will under-report, and inventing the missing rows would poison the first season's numbers.
