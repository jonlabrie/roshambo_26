# Stats Data Capture Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Start recording the four things the Stats room needs and the server does not currently keep — forfeited points, bank events, session presence, and a leaderboard basis that survives spending — so history exists by the time any wall is built.

**Architecture:** Pure additive server work, no display and no client changes. Three new Mongo collections/fields plus two small query modules. Every unit of arithmetic is extracted into a pure function so it is testable without a database; anything touching Mongo is tested against `mongodb-memory-server` via the existing `src/test/db.ts` helpers.

**Tech Stack:** TypeScript, Express, Socket.io, Mongoose 9, Vitest, mongodb-memory-server.

**Spec:** `docs/superpowers/specs/2026-08-16-stats-room-design.md` (§5 Schema consequences, §7 Sequencing)

## Global Constraints

- **This is plan 1 of 3.** Plan 2 is the stats surface (Records/Heat/Volume queries + API); plan 3 is the Roblox displays. This plan ships alone and is a prerequisite for both — the spec's §7 requires history to accrue before walls exist.
- **`pointsDelta` is not an increment.** On a WIN `GameRules.potDelta` records the NEW pot, not the gain (`server/src/engine/GameRules.ts:18-24`). **Never compute earnings by summing `PlayerRound.pointsDelta`.** Earnings come from bank events only.
- **`totalPoints` is a spendable wallet**, decremented by purchases. It must never be a ranking basis. `lifetimeBanked` is career earnings and is monotonic.
- **Rate stats are per THROW, never per round elapsed** (spec §2). This plan records presence so that denominator can exist later.
- Tests: `cd server && npm test`. Build: `cd server && npm run build` (must stay `tsc`-clean).
- Commit style: `feat(server): ...` / `fix(server): ...`, imperative, explaining *why* in the body.

---

### Task 1: Record forfeited points

`lifetimeForfeited` is the missing half of capture rate (banked ÷ (banked + forfeited)). The pot lost on a LOSS is currently written nowhere.

**Files:**
- Modify: `server/src/models/User.ts`
- Modify: `server/src/engine/Settlement.ts` (`buildCounterUpdate`, and its call site in `settleRound`)
- Test: `server/src/engine/Settlement.test.ts`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces: `buildCounterUpdate(thrown: Throw, result: RoundResult, newPot: number, forfeited: number)` — the fourth parameter is new. `IUser.lifetimeForfeited: number`.

- [ ] **Step 1: Write the failing test**

Append to `server/src/engine/Settlement.test.ts`:

```typescript
describe('buildCounterUpdate — forfeited points', () => {
    it('records the forfeited pot on a LOSS', () => {
        const update = buildCounterUpdate('R', 'LOSS', 0, 27);
        expect(update.$inc.lifetimeForfeited).toBe(27);
    });

    it('forfeits nothing on a WIN', () => {
        expect(buildCounterUpdate('R', 'WIN', 3, 0).$inc.lifetimeForfeited).toBe(0);
    });

    it('forfeits nothing on a SAFE', () => {
        expect(buildCounterUpdate('R', 'SAFE', 9, 0).$inc.lifetimeForfeited).toBe(0);
    });

    it('a LOSS from an empty pot forfeits nothing', () => {
        expect(buildCounterUpdate('R', 'LOSS', 0, 0).$inc.lifetimeForfeited).toBe(0);
    });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/engine/Settlement.test.ts`
Expected: FAIL — `Expected 4 arguments, but got 3` at build, or `undefined` for `lifetimeForfeited`.

- [ ] **Step 3: Add the field to the User model**

In `server/src/models/User.ts`, add to the `IUser` interface next to `lifetimeBanked`:

```typescript
    lifetimeBanked: number;
    // The other half of capture rate: everything ever built and then lost. Monotonic,
    // like lifetimeBanked. Together they answer "what fraction of what you built did you keep".
    lifetimeForfeited: number;
```

and to `UserSchema` next to the `lifetimeBanked` field:

```typescript
    lifetimeBanked: { type: Number, default: 0 },
    lifetimeForfeited: { type: Number, default: 0 },
```

- [ ] **Step 4: Widen `buildCounterUpdate`**

In `server/src/engine/Settlement.ts`, change the signature and the `$inc` block:

```typescript
export function buildCounterUpdate(thrown: Throw, result: RoundResult, newPot: number, forfeited: number) {
    const throwKey = ({ R: 'throwsR', P: 'throwsP', S: 'throwsS' } as const)[thrown];
    return {
        $inc: {
            roundsPlayed: 1,
            wins: result === 'WIN' ? 1 : 0,
            safes: result === 'SAFE' ? 1 : 0,
            losses: result === 'LOSS' ? 1 : 0,
            // Capture rate's denominator. Passed in rather than derived here because only the
            // caller knows the PRE-round pot; by the time we have `newPot` a LOSS has zeroed it.
            lifetimeForfeited: forfeited,
            [throwKey]: 1,
        } as Record<string, number>,
        $set: { unresolvedWin: result === 'WIN' },
        $max: { bestPot: newPot },
    };
}
```

- [ ] **Step 5: Pass the forfeited amount at the call site**

In `settleRound` in the same file, replace the `buildCounterUpdate` call:

```typescript
                const forfeited = result === 'LOSS' ? (user.pointsAtStake || 0) : 0;
                const counters = buildCounterUpdate(entry.throw, result, pot, forfeited);
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd server && npm test`
Expected: PASS, all suites.

- [ ] **Step 7: Verify the build is clean**

Run: `cd server && npm run build`
Expected: no output, exit 0.

- [ ] **Step 8: Commit**

```bash
git add server/src/models/User.ts server/src/engine/Settlement.ts server/src/engine/Settlement.test.ts
git commit -m "feat(server): record forfeited points, the missing half of capture rate

lifetimeForfeited is incremented on a LOSS by the pot that was lost. Passed into
buildCounterUpdate rather than derived there, because only the caller still knows the
PRE-round pot — by the time newPot exists a LOSS has already zeroed it.

Capture rate (banked / (banked + forfeited)) is the single best risk-management number
in the game and was uncomputable without this."
```

---

### Task 2: Bank events

Banking is a bare `$inc` that writes no history (`server/src/wallet.ts`), so "points earned last week" is uncomputable. This adds the event log. It is the single most important task in the plan.

**Files:**
- Create: `server/src/models/BankEvent.ts`
- Modify: `server/src/wallet.ts`
- Modify: `server/src/transports/socketAdapter.ts` (the `bank` handler's `bankPot` call)
- Modify: `server/src/routes/apiV1.ts` (the `POST /bank` route's `bankPot` call)
- Test: `server/src/wallet.test.ts`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `BankEvent` model with fields `{ userId, amount, streakAtBank, platform, timestamp }`; `bankPot(userId: string, platform: 'pwa' | 'roblox')` — the second parameter is new and required.

- [ ] **Step 1: Write the failing test**

Append to `server/src/wallet.test.ts`:

```typescript
describe('bankPot — event log', () => {
    it('writes one BankEvent recording the amount and the streak', async () => {
        const user = await User.create({
            deviceId: 'devBank1', pointsAtStake: 27, stakingStreak: 3, currentStreak: 3,
        });
        await bankPot(user._id.toString(), 'pwa');

        const events = await BankEvent.find({ userId: user._id });
        expect(events).toHaveLength(1);
        expect(events[0].amount).toBe(27);
        expect(events[0].streakAtBank).toBe(3);
        expect(events[0].platform).toBe('pwa');
    });

    it('writes NO event when there is nothing staked', async () => {
        const user = await User.create({ deviceId: 'devBank2', pointsAtStake: 0 });
        await bankPot(user._id.toString(), 'pwa');
        expect(await BankEvent.countDocuments({ userId: user._id })).toBe(0);
    });

    it('records the platform it was banked from', async () => {
        const user = await User.create({ deviceId: 'devBank3', pointsAtStake: 9, stakingStreak: 2 });
        await bankPot(user._id.toString(), 'roblox');
        const event = await BankEvent.findOne({ userId: user._id });
        expect(event?.platform).toBe('roblox');
    });

    it('the event amount matches the wallet increase', async () => {
        const user = await User.create({ deviceId: 'devBank4', pointsAtStake: 81, totalPoints: 100 });
        const updated = await bankPot(user._id.toString(), 'pwa');
        const event = await BankEvent.findOne({ userId: user._id });
        expect(updated?.totalPoints).toBe(181);
        expect(event?.amount).toBe(81);
    });
});
```

Add these imports at the top of `server/src/wallet.test.ts` if not already present:

```typescript
import BankEvent from './models/BankEvent';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/wallet.test.ts`
Expected: FAIL — cannot find module `./models/BankEvent`.

- [ ] **Step 3: Create the model**

Create `server/src/models/BankEvent.ts`:

```typescript
import mongoose, { Schema, Document, Types } from 'mongoose';

// ONE ROW PER BANK. The wallet's own counters (totalPoints, lifetimeBanked) are running
// totals with no timestamps, so without this collection "points earned last week" cannot be
// answered at all. PlayerRound cannot substitute: on a WIN its pointsDelta records the NEW
// POT rather than the gain, so summing that column overstates earnings badly
// (0->1->3->9 writes 1,3,9 for a pot worth 9).
export interface IBankEvent extends Document {
    userId: Types.ObjectId;
    amount: number;
    streakAtBank: number;
    platform: 'pwa' | 'roblox';
    timestamp: Date;
}

const BankEventSchema: Schema = new Schema({
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    amount: { type: Number, required: true },
    // How long the streak was when they chose to stop. The whole bank-vs-stake story lives
    // in the distribution of this number.
    streakAtBank: { type: Number, default: 0 },
    platform: { type: String, enum: ['pwa', 'roblox'], default: 'pwa' },
    timestamp: { type: Date, default: Date.now },
});

// Windowed earnings for one player, and global "who earned most this week".
BankEventSchema.index({ userId: 1, timestamp: -1 });
BankEventSchema.index({ timestamp: -1 });

export default mongoose.model<IBankEvent>('BankEvent', BankEventSchema);
```

- [ ] **Step 4: Emit the event from `bankPot`**

Replace the whole of `server/src/wallet.ts`:

```typescript
import User, { IUser } from './models/User';
import BankEvent from './models/BankEvent';

// Bank = move the at-stake pot into totalPoints. currentStreak (win streak) is
// NOT reset by banking — only stakingStreak is. Atomic: the filter guards
// against double-banking races.
export async function bankPot(userId: string, platform: 'pwa' | 'roblox'): Promise<IUser | null> {
    const user = await User.findById(userId);
    // null return is overloaded: nothing staked OR lost a concurrent-update race;
    // benign in single-process deployment.
    if (!user || user.pointsAtStake <= 0) return null;

    const amount = user.pointsAtStake;
    const streakAtBank = user.stakingStreak || 0;

    const updated = await User.findOneAndUpdate(
        { _id: user._id, pointsAtStake: user.pointsAtStake },
        {
            $inc: { totalPoints: amount, lifetimeBanked: amount },
            $set: { pointsAtStake: 0, stakingStreak: 0, unresolvedWin: false },
        },
        { new: true }
    );

    // AFTER the atomic update, and only if it won the race — a bank that did not happen must
    // not leave an event behind. The reverse ordering would overstate earnings on every lost
    // race. A crash in this gap loses one event, which is the acceptable direction to fail.
    if (updated) {
        await BankEvent.create({ userId: user._id, amount, streakAtBank, platform })
            .catch(err => console.error('Error writing BankEvent:', (err as Error).message));
    }

    return updated;
}
```

- [ ] **Step 5: Update both call sites**

In `server/src/transports/socketAdapter.ts`, in the `socket.on('bank', ...)` handler:

```typescript
                const updated = await bankPot(user._id.toString(), 'pwa');
```

In `server/src/routes/apiV1.ts`, in the `POST /bank` route:

```typescript
            const updated = await bankPot(user._id.toString(), 'roblox');
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `cd server && npm test`
Expected: PASS, all suites.

- [ ] **Step 7: Verify the build is clean**

Run: `cd server && npm run build`
Expected: no output, exit 0. If `tsc` complains about a missing second argument to `bankPot`, a call site was missed — there are exactly two.

- [ ] **Step 8: Commit**

```bash
git add server/src/models/BankEvent.ts server/src/wallet.ts server/src/wallet.test.ts server/src/transports/socketAdapter.ts server/src/routes/apiV1.ts
git commit -m "feat(server): log bank events, so earnings can be windowed at all

Banking was a bare \`$inc\` on the User document writing no history, so lifetimeBanked is a
running total with no timestamps and 'points earned last week' was uncomputable.
PlayerRound cannot substitute: on a WIN its pointsDelta records the NEW POT rather than
the gain, so summing it overstates earnings (0->1->3->9 writes 1,3,9 for a pot of 9).

The event is written AFTER the atomic update and only when it won the race, so a bank that
did not happen leaves no event. A crash in that gap loses one event, which is the
acceptable direction to fail.

streakAtBank is recorded because the entire bank-vs-stake story is the distribution of
how long players ride before stopping."
```

---

### Task 3: Rank on career earnings, not the wallet

Both leaderboards sort by `totalPoints`, which is a spendable wallet — so a player who buys fireworks falls down the board. This extracts the query and corrects the basis.

**Files:**
- Create: `server/src/leaderboards.ts`
- Create: `server/src/leaderboards.test.ts`
- Modify: `server/src/models/User.ts` (index)
- Modify: `server/src/transports/socketAdapter.ts` (the `topPoints` query in `get-stats`)
- Modify: `server/src/routes/apiV1.ts` (the `GET /leaderboards` query)

**Interfaces:**
- Consumes: nothing.
- Produces: `topByCareer(filter: Record<string, unknown>, limit: number): Promise<IUser[]>`

- [ ] **Step 1: Write the failing test**

Create `server/src/leaderboards.test.ts`:

```typescript
import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { connectTestDb, clearTestDb, disconnectTestDb } from './test/db';
import User from './models/User';
import { topByCareer } from './leaderboards';

describe('topByCareer', () => {
    beforeAll(connectTestDb);
    afterAll(disconnectTestDb);
    beforeEach(clearTestDb);

    it('ranks by career earnings, NOT by the spendable wallet', async () => {
        // The spender earned more but bought a teahouse; they must still outrank the hoarder.
        await User.create({ deviceId: 'spender', lifetimeBanked: 900, totalPoints: 10 });
        await User.create({ deviceId: 'hoarder', lifetimeBanked: 100, totalPoints: 100 });

        const leaders = await topByCareer({}, 50);
        expect(leaders.map(u => u.deviceId)).toEqual(['spender', 'hoarder']);
    });

    it('honours the limit', async () => {
        for (let i = 0; i < 5; i++) {
            await User.create({ deviceId: `dev${i}`, lifetimeBanked: i * 10 });
        }
        expect(await topByCareer({}, 3)).toHaveLength(3);
    });

    it('filters, so a country board only contains that country', async () => {
        await User.create({ deviceId: 'us1', country: 'US', lifetimeBanked: 50 });
        await User.create({ deviceId: 'jp1', country: 'JP', lifetimeBanked: 500 });

        const leaders = await topByCareer({ country: 'US' }, 50);
        expect(leaders.map(u => u.deviceId)).toEqual(['us1']);
    });

    it('treats a player who never banked as zero rather than omitting them', async () => {
        await User.create({ deviceId: 'never' });
        const leaders = await topByCareer({}, 50);
        expect(leaders.map(u => u.deviceId)).toContain('never');
    });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/leaderboards.test.ts`
Expected: FAIL — cannot find module `./leaderboards`.

- [ ] **Step 3: Create the query module**

Create `server/src/leaderboards.ts`:

```typescript
import User, { IUser } from './models/User';

// RANK ON CAREER EARNINGS, NEVER ON THE WALLET. `totalPoints` is spendable and is
// decremented by every purchase (routes/store.ts, routes/apiV1.ts), so ranking on it means a
// player who spends on fireworks or a teahouse FALLS DOWN THE BOARD — the leaderboard would
// punish exactly the economy engagement the game wants. `lifetimeBanked` is monotonic.
export const LEADERBOARD_FIELDS =
    'deviceId displayName lifetimeBanked totalPoints robloxId identityTier currentStreak bestStreak';

export async function topByCareer(filter: Record<string, unknown>, limit: number): Promise<IUser[]> {
    return User.find(filter)
        .sort({ lifetimeBanked: -1 })
        .limit(limit)
        .select(LEADERBOARD_FIELDS);
}
```

- [ ] **Step 4: Add the supporting index**

In `server/src/models/User.ts`, after the schema definition and before the model export, add:

```typescript
// The standings sort. Without this every leaderboard read is a collection scan.
UserSchema.index({ lifetimeBanked: -1 });
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd server && npx vitest run src/leaderboards.test.ts`
Expected: PASS, 4 tests.

- [ ] **Step 6: Use it in both call sites**

In `server/src/transports/socketAdapter.ts`, replace the `topPoints` query in the `get-stats` handler:

```typescript
                // 2. Highest CAREER earnings (Top 50 - All Time). Was totalPoints, which is a
                // spendable wallet — see leaderboards.ts.
                const topPoints = await topByCareer({}, 50);
```

and add the import at the top of that file:

```typescript
import { topByCareer } from '../leaderboards';
```

In `server/src/routes/apiV1.ts`, replace the `GET /leaderboards` query:

```typescript
            const leaders = await topByCareer(filter, 50);
```

and add the import at the top of that file:

```typescript
import { topByCareer } from '../leaderboards';
```

- [ ] **Step 7: Run the full suite and build**

Run: `cd server && npm test && npm run build`
Expected: all suites PASS, build clean.

- [ ] **Step 8: Commit**

```bash
git add server/src/leaderboards.ts server/src/leaderboards.test.ts server/src/models/User.ts server/src/transports/socketAdapter.ts server/src/routes/apiV1.ts
git commit -m "fix(server): rank on career earnings, not on the spendable wallet

Both leaderboards sorted by totalPoints, which is decremented by every purchase. A player
who earned a fortune and spent it on fireworks or a teahouse FELL DOWN THE BOARD — the
standings actively punished engagement with the economy they exist to drive.

lifetimeBanked is monotonic career earnings and is the correct basis. Extracted the query
into leaderboards.ts so the rule lives in one place with the reasoning attached, and both
call sites now share it. Added the descending index it sorts on."
```

---

### Task 4: Session presence for the PWA

`PlayerRound` rows only exist when a player throws, so someone who watched 40 rounds and threw 5 is indistinguishable from someone who arrived for 5. Abstention is normal play (spec §2), so participation rate needs presence. This records **session intervals**, not a row per player per round — at a thousand concurrents that would be ~1.4M writes a day for nothing.

**Files:**
- Create: `server/src/models/Session.ts`
- Create: `server/src/sessions.ts`
- Create: `server/src/sessions.test.ts`
- Modify: `server/src/transports/socketAdapter.ts`

**Interfaces:**
- Consumes: nothing.
- Produces: `openSession(input: OpenSessionInput): Promise<ISession>` where `OpenSessionInput = { userId: Types.ObjectId; platform: 'pwa' | 'roblox'; instanceId?: string }`, `closeSession(sessionId: string, at: Date): Promise<void>`, `touchSession(sessionId: string, at: Date): Promise<void>`, `roundsPresent(userId: Types.ObjectId, from: Date, to: Date): Promise<number>`

- [ ] **Step 1: Write the failing test**

Create `server/src/sessions.test.ts`:

```typescript
import { describe, it, expect, beforeAll, afterAll, beforeEach } from 'vitest';
import { connectTestDb, clearTestDb, disconnectTestDb } from './test/db';
import User from './models/User';
import Round from './models/Round';
import Session from './models/Session';
import { openSession, closeSession, touchSession, roundsPresent } from './sessions';

const at = (min: number) => new Date(Date.UTC(2026, 7, 16, 12, min, 0));

describe('sessions', () => {
    beforeAll(connectTestDb);
    afterAll(disconnectTestDb);
    beforeEach(clearTestDb);

    it('opens a session that is not yet ended', async () => {
        const user = await User.create({ deviceId: 'devS1' });
        const session = await openSession({ userId: user._id, platform: 'pwa' });
        expect(session.endedAt).toBeUndefined();
        expect(await Session.countDocuments({})).toBe(1);
    });

    it('closes a session with an end time', async () => {
        const user = await User.create({ deviceId: 'devS2' });
        const session = await openSession({ userId: user._id, platform: 'pwa' });
        await closeSession(session._id.toString(), at(30));
        const stored = await Session.findById(session._id);
        expect(stored?.endedAt?.toISOString()).toBe(at(30).toISOString());
    });

    it('counts only the rounds that fall inside a session', async () => {
        const user = await User.create({ deviceId: 'devS3' });
        // present 12:00 -> 12:10
        const session = await openSession({ userId: user._id, platform: 'pwa' });
        await Session.findByIdAndUpdate(session._id, { $set: { startedAt: at(0) } });
        await closeSession(session._id.toString(), at(10));

        await Round.create({ id: 'r-start', worldThrow: 'R', timestamp: at(0) });   // exactly at open, inside
        await Round.create({ id: 'r-inside', worldThrow: 'P', timestamp: at(5) });      // inside
        await Round.create({ id: 'r-after', worldThrow: 'S', timestamp: at(20) });      // outside

        expect(await roundsPresent(user._id, at(0), at(60))).toBe(2);
    });

    it('counts an OPEN session as running up to the window end', async () => {
        const user = await User.create({ deviceId: 'devS4' });
        const session = await openSession({ userId: user._id, platform: 'pwa' });
        await Session.findByIdAndUpdate(session._id, { $set: { startedAt: at(0) } });

        await Round.create({ id: 'r1', worldThrow: 'R', timestamp: at(5) });
        await Round.create({ id: 'r2', worldThrow: 'P', timestamp: at(50) });

        expect(await roundsPresent(user._id, at(0), at(60))).toBe(2);
    });

    it('does not double-count a round covered by two overlapping sessions', async () => {
        const user = await User.create({ deviceId: 'devS5' });
        for (const _ of [1, 2]) {
            const s = await openSession({ userId: user._id, platform: 'pwa' });
            await Session.findByIdAndUpdate(s._id, { $set: { startedAt: at(0) } });
            await closeSession(s._id.toString(), at(10));
        }
        await Round.create({ id: 'r1', worldThrow: 'R', timestamp: at(5) });

        expect(await roundsPresent(user._id, at(0), at(60))).toBe(1);
    });

    it('touch moves lastSeenAt without ending the session', async () => {
        const user = await User.create({ deviceId: 'devS6' });
        const session = await openSession({ userId: user._id, platform: 'pwa' });
        await touchSession(session._id.toString(), at(45));
        const stored = await Session.findById(session._id);
        expect(stored?.lastSeenAt?.toISOString()).toBe(at(45).toISOString());
        expect(stored?.endedAt).toBeUndefined();
    });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/sessions.test.ts`
Expected: FAIL — cannot find module `./models/Session`.

- [ ] **Step 3: Create the model**

Create `server/src/models/Session.ts`:

```typescript
import mongoose, { Schema, Document, Types } from 'mongoose';

// PRESENCE, RECORDED AS INTERVALS. Abstention is normal play — a player may watch for a
// readable pattern and throw in a third of rounds — so "rounds present" is a different
// number from "rounds thrown", and every participation stat needs both.
//
// DELIBERATELY NOT a row per player per round: at a thousand concurrents that is ~1.4M
// writes a day to record mostly nothing. One row per session is exact and cheap, because
// rounds-present falls out of counting Round timestamps inside the interval.
export interface ISession extends Document {
    userId: Types.ObjectId;
    platform: 'pwa' | 'roblox';
    instanceId?: string;
    startedAt: Date;
    lastSeenAt: Date;
    endedAt?: Date;
}

const SessionSchema: Schema = new Schema({
    userId: { type: Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    platform: { type: String, enum: ['pwa', 'roblox'], default: 'pwa' },
    instanceId: { type: String, index: true },
    startedAt: { type: Date, default: Date.now },
    // Advanced by heartbeats. A session whose process died is closed at its lastSeenAt by the
    // stale sweep, so an interval never runs to infinity.
    lastSeenAt: { type: Date, default: Date.now },
    endedAt: { type: Date },
});

SessionSchema.index({ userId: 1, startedAt: -1 });
SessionSchema.index({ endedAt: 1, lastSeenAt: 1 });

export default mongoose.model<ISession>('Session', SessionSchema);
```

- [ ] **Step 4: Create the session functions**

Create `server/src/sessions.ts`:

```typescript
import { Types } from 'mongoose';
import Session, { ISession } from './models/Session';
import Round from './models/Round';

export interface OpenSessionInput {
    userId: Types.ObjectId;
    platform: 'pwa' | 'roblox';
    instanceId?: string;
}

export async function openSession(input: OpenSessionInput): Promise<ISession> {
    return Session.create({
        userId: input.userId,
        platform: input.platform,
        instanceId: input.instanceId,
    });
}

export async function closeSession(sessionId: string, at: Date): Promise<void> {
    await Session.findByIdAndUpdate(sessionId, { $set: { endedAt: at, lastSeenAt: at } });
}

export async function touchSession(sessionId: string, at: Date): Promise<void> {
    await Session.findByIdAndUpdate(sessionId, { $set: { lastSeenAt: at } });
}

// How many rounds ran while this player was present, in [from, to].
//
// An OPEN session is treated as running to `to`, so a player currently online counts.
// Overlapping sessions must NOT double-count — the same player can be connected on two
// devices — so rounds are collected into a Set of ids rather than summed per interval.
export async function roundsPresent(userId: Types.ObjectId, from: Date, to: Date): Promise<number> {
    const sessions = await Session.find({
        userId,
        startedAt: { $lte: to },
        $or: [{ endedAt: { $exists: false } }, { endedAt: { $gte: from } }],
    }).select('startedAt endedAt');

    if (sessions.length === 0) return 0;

    const ranges = sessions.map(s => ({
        start: s.startedAt > from ? s.startedAt : from,
        end: s.endedAt && s.endedAt < to ? s.endedAt : to,
    }));

    const rounds = await Round.find({
        $or: ranges.map(r => ({ timestamp: { $gte: r.start, $lte: r.end } })),
    }).select('id');

    return new Set(rounds.map(r => r.id)).size;
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd server && npx vitest run src/sessions.test.ts`
Expected: PASS, 6 tests.

- [ ] **Step 6: Wire the PWA lifecycle**

In `server/src/transports/socketAdapter.ts`, add the import:

```typescript
import { openSession, closeSession } from '../sessions';
```

Inside `io.on('connection', (socket: Socket) => {`, declare a holder near the top of the handler body:

```typescript
        let sessionId: string | null = null;
```

In the `socket.on('sync-player', ...)` handler, **inside the `try` block**, immediately after the `if (!user) { ... return; }` guard (this is the only place `user` is in scope), add:

```typescript
            // One session per connection. sync-player is the first point at which the socket
            // is attached to a resolved user, so it is where presence starts.
            if (!sessionId && user) {
                sessionId = (await openSession({ userId: user._id, platform: 'pwa' }))._id.toString();
            }
```

Then add a disconnect handler alongside the other `socket.on` handlers:

```typescript
        socket.on('disconnect', async () => {
            if (sessionId) {
                await closeSession(sessionId, new Date());
                sessionId = null;
            }
        });
```

- [ ] **Step 7: Run the full suite and build**

Run: `cd server && npm test && npm run build`
Expected: all suites PASS, build clean.

- [ ] **Step 8: Commit**

```bash
git add server/src/models/Session.ts server/src/sessions.ts server/src/sessions.test.ts server/src/transports/socketAdapter.ts
git commit -m "feat(server): record presence as session intervals

PlayerRound rows exist only when a player throws, so someone who watched forty rounds and
threw five was indistinguishable from someone who arrived for five. Abstention is normal
play — players hang out and wait for a readable pattern — so participation rate needs a
denominator that presence, not throws, provides.

Recorded as INTERVALS rather than a row per player per round: at a thousand concurrents
that would be ~1.4M writes a day to record mostly nothing. Rounds-present falls out of
counting Round timestamps inside the interval, which is exact and costs one row per
session.

roundsPresent de-duplicates via a Set of round ids, because the same player can hold two
overlapping sessions on two devices and must not be counted twice."
```

---

### Task 5: Session presence for Roblox

Roblox game servers have no socket lifecycle, so presence arrives as a roster heartbeat. Sessions that stop reporting are closed by a sweep, so an interval never runs to infinity.

**Files:**
- Modify: `server/src/sessions.ts`
- Modify: `server/src/sessions.test.ts`
- Modify: `server/src/routes/apiV1.ts`
- Modify: `server/src/index.ts`

**Interfaces:**
- Consumes: `openSession`, `closeSession`, `touchSession` from Task 4.
- Produces: `reconcilePresence(instanceId: string, userIds: Types.ObjectId[], at: Date): Promise<{ opened: number; touched: number; closed: number }>`, `closeStaleSessions(olderThan: Date): Promise<number>`

- [ ] **Step 1: Write the failing test**

Append to `server/src/sessions.test.ts`:

```typescript
describe('presence reconciliation', () => {
    beforeAll(connectTestDb);
    afterAll(disconnectTestDb);
    beforeEach(clearTestDb);

    it('opens sessions for players newly present', async () => {
        const a = await User.create({ deviceId: 'ra' });
        const result = await reconcilePresence('inst1', [a._id], at(0));
        expect(result.opened).toBe(1);
        expect(await Session.countDocuments({ instanceId: 'inst1', endedAt: { $exists: false } })).toBe(1);
    });

    it('touches players still present rather than opening a second session', async () => {
        const a = await User.create({ deviceId: 'ra' });
        await reconcilePresence('inst1', [a._id], at(0));
        const result = await reconcilePresence('inst1', [a._id], at(5));
        expect(result.opened).toBe(0);
        expect(result.touched).toBe(1);
        expect(await Session.countDocuments({ instanceId: 'inst1' })).toBe(1);
    });

    it('closes sessions for players who have left', async () => {
        const a = await User.create({ deviceId: 'ra' });
        const b = await User.create({ deviceId: 'rb' });
        await reconcilePresence('inst1', [a._id, b._id], at(0));
        const result = await reconcilePresence('inst1', [a._id], at(5));
        expect(result.closed).toBe(1);
        const bSession = await Session.findOne({ userId: b._id });
        expect(bSession?.endedAt?.toISOString()).toBe(at(5).toISOString());
    });

    it('does not touch sessions belonging to another instance', async () => {
        const a = await User.create({ deviceId: 'ra' });
        await reconcilePresence('inst1', [a._id], at(0));
        await reconcilePresence('inst2', [], at(5));
        expect(await Session.countDocuments({ instanceId: 'inst1', endedAt: { $exists: false } })).toBe(1);
    });

    it('closes sessions whose instance stopped reporting, at their lastSeenAt', async () => {
        const a = await User.create({ deviceId: 'ra' });
        await reconcilePresence('deadInstance', [a._id], at(0));
        await Session.updateMany({}, { $set: { lastSeenAt: at(0) } });

        const closed = await closeStaleSessions(at(10));
        expect(closed).toBe(1);
        const stored = await Session.findOne({ userId: a._id });
        // closed at lastSeenAt, NOT at sweep time — the player was not present for those 30 minutes
        expect(stored?.endedAt?.toISOString()).toBe(at(0).toISOString());
    });

    it('leaves fresh sessions alone', async () => {
        const a = await User.create({ deviceId: 'ra' });
        await reconcilePresence('liveInstance', [a._id], at(20));
        await Session.updateMany({}, { $set: { lastSeenAt: at(20) } });
        expect(await closeStaleSessions(at(10))).toBe(0);
    });
});
```

Add to the imports at the top of `server/src/sessions.test.ts`:

```typescript
import { openSession, closeSession, touchSession, roundsPresent, reconcilePresence, closeStaleSessions } from './sessions';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/sessions.test.ts`
Expected: FAIL — `reconcilePresence` is not exported.

- [ ] **Step 3: Implement reconciliation and the sweep**

Append to `server/src/sessions.ts`:

```typescript
// A Roblox game server reports who is in it. There is no socket lifecycle here, so presence
// is a roster diff: open for the newly present, touch the still-present, close the departed.
export async function reconcilePresence(
    instanceId: string,
    userIds: Types.ObjectId[],
    at: Date
): Promise<{ opened: number; touched: number; closed: number }> {
    const open = await Session.find({ instanceId, endedAt: { $exists: false } }).select('userId');
    const openByUser = new Map(open.map(s => [s.userId.toString(), s]));
    const present = new Set(userIds.map(id => id.toString()));

    let opened = 0;
    let touched = 0;
    for (const id of userIds) {
        const existing = openByUser.get(id.toString());
        if (existing) {
            await touchSession(existing._id.toString(), at);
            touched++;
        } else {
            await Session.create({ userId: id, platform: 'roblox', instanceId, startedAt: at, lastSeenAt: at });
            opened++;
        }
    }

    let closed = 0;
    for (const [userKey, session] of openByUser) {
        if (!present.has(userKey)) {
            await closeSession(session._id.toString(), at);
            closed++;
        }
    }

    return { opened, touched, closed };
}

// A game server that crashes stops reporting, leaving sessions open forever and inflating
// every player's rounds-present. Close them AT THEIR lastSeenAt, not at sweep time — the
// player was not present for the silent interval, and dating it now would invent presence.
export async function closeStaleSessions(olderThan: Date): Promise<number> {
    const stale = await Session.find({
        endedAt: { $exists: false },
        lastSeenAt: { $lt: olderThan },
    }).select('lastSeenAt');

    for (const session of stale) {
        await Session.findByIdAndUpdate(session._id, { $set: { endedAt: session.lastSeenAt } });
    }
    return stale.length;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server && npx vitest run src/sessions.test.ts`
Expected: PASS, 12 tests.

- [ ] **Step 5: Add the presence endpoint**

In `server/src/routes/apiV1.ts`, add the import:

```typescript
import { reconcilePresence } from '../sessions';
```

and add this route beside the other `/instances/...` routes:

```typescript
    // A game server reports its roster. Called on the same cadence as the throw flush.
    router.post('/instances/:instanceId/presence', async (req, res) => {
        try {
            const ids = req.body?.robloxUserIds;
            if (!Array.isArray(ids)) {
                res.status(400).json({ error: 'BAD_REQUEST' });
                return;
            }
            const users = await Promise.all(
                ids.map((robloxUserId: string) => resolveUser({ robloxUserId: String(robloxUserId) }))
            );
            const userIds = users.filter((u): u is NonNullable<typeof u> => !!u).map(u => u._id);
            const result = await reconcilePresence(req.params.instanceId, userIds, new Date());
            res.json(result);
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });
```

- [ ] **Step 6: Schedule the sweep**

In `server/src/index.ts`, add the import:

```typescript
import { closeStaleSessions } from './sessions';
```

and inside the `httpServer.listen(PORT, () => {` callback, beside the existing `setInterval(() => engine.tick(), 1000);`:

```typescript
            // Close sessions whose reporter went silent. Two minutes is four missed
            // heartbeats at the 30s cadence — long enough to survive a hiccup, short enough
            // that a crashed game server does not inflate presence for long.
            const STALE_MS = 2 * 60 * 1000;
            setInterval(() => {
                closeStaleSessions(new Date(Date.now() - STALE_MS))
                    .catch(err => console.error('Stale session sweep failed:', (err as Error).message));
            }, 60 * 1000);
```

- [ ] **Step 7: Run the full suite and build**

Run: `cd server && npm test && npm run build`
Expected: all suites PASS, build clean.

- [ ] **Step 8: Commit**

```bash
git add server/src/sessions.ts server/src/sessions.test.ts server/src/routes/apiV1.ts server/src/index.ts
git commit -m "feat(server): Roblox presence by roster heartbeat, with a stale sweep

Roblox game servers have no socket lifecycle, so presence arrives as a roster and is
reconciled as a diff: open for the newly present, touch the still-present, close the
departed.

A crashed game server stops reporting, which would leave sessions open forever and inflate
every player's rounds-present. The sweep closes them AT THEIR lastSeenAt rather than at
sweep time — the player was not there during the silence, and dating it now would invent
presence that never happened."
```

---

### Task 6: Windowed earnings

Proves the capture actually answers the question it was built for, and gives plan 2 its first query.

**Files:**
- Modify: `server/src/leaderboards.ts`
- Modify: `server/src/leaderboards.test.ts`

**Interfaces:**
- Consumes: `BankEvent` from Task 2.
- Produces: `earningsInWindow(userId: Types.ObjectId, from: Date, to: Date): Promise<number>`, `topEarnersInWindow(from: Date, to: Date, limit: number): Promise<{ userId: Types.ObjectId; earned: number }[]>`

- [ ] **Step 1: Write the failing test**

Append to `server/src/leaderboards.test.ts`:

```typescript
describe('windowed earnings', () => {
    const at = (day: number) => new Date(Date.UTC(2026, 7, day, 12, 0, 0));

    it('sums only the banks inside the window', async () => {
        const user = await User.create({ deviceId: 'w1' });
        await BankEvent.create({ userId: user._id, amount: 10, timestamp: at(1) });
        await BankEvent.create({ userId: user._id, amount: 20, timestamp: at(5) });
        await BankEvent.create({ userId: user._id, amount: 40, timestamp: at(9) });

        expect(await earningsInWindow(user._id, at(3), at(7))).toBe(20);
    });

    it('is zero for a player who banked nothing in the window', async () => {
        const user = await User.create({ deviceId: 'w2' });
        await BankEvent.create({ userId: user._id, amount: 10, timestamp: at(1) });
        expect(await earningsInWindow(user._id, at(3), at(7))).toBe(0);
    });

    it('ranks earners within the window, not by career', async () => {
        const grinder = await User.create({ deviceId: 'grinder', lifetimeBanked: 10_000 });
        const hot = await User.create({ deviceId: 'hot', lifetimeBanked: 10 });
        // the career leader banked long ago; the hot player banked this week
        await BankEvent.create({ userId: grinder._id, amount: 9_000, timestamp: at(1) });
        await BankEvent.create({ userId: hot._id, amount: 300, timestamp: at(5) });

        const top = await topEarnersInWindow(at(3), at(7), 10);
        expect(top).toHaveLength(1);
        expect(top[0].userId.toString()).toBe(hot._id.toString());
        expect(top[0].earned).toBe(300);
    });

    it('adds up several banks by the same player', async () => {
        const user = await User.create({ deviceId: 'w3' });
        await BankEvent.create({ userId: user._id, amount: 3, timestamp: at(4) });
        await BankEvent.create({ userId: user._id, amount: 9, timestamp: at(5) });
        await BankEvent.create({ userId: user._id, amount: 27, timestamp: at(6) });

        const top = await topEarnersInWindow(at(3), at(7), 10);
        expect(top[0].earned).toBe(39);
    });
});
```

Add to the imports at the top of `server/src/leaderboards.test.ts`:

```typescript
import BankEvent from './models/BankEvent';
import { topByCareer, earningsInWindow, topEarnersInWindow } from './leaderboards';
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/leaderboards.test.ts`
Expected: FAIL — `earningsInWindow` is not exported.

- [ ] **Step 3: Implement the window queries**

Append to `server/src/leaderboards.ts`:

```typescript
import { Types } from 'mongoose';
import BankEvent from './models/BankEvent';

// EARNINGS COME FROM BANK EVENTS, NEVER FROM PlayerRound.pointsDelta. On a WIN that column
// records the NEW POT rather than the gain, so a 0->1->3->9 run writes 1,3,9 for a pot worth
// 9 and summing it overstates earnings by a growing multiple.
export async function earningsInWindow(userId: Types.ObjectId, from: Date, to: Date): Promise<number> {
    const [row] = await BankEvent.aggregate([
        { $match: { userId, timestamp: { $gte: from, $lte: to } } },
        { $group: { _id: null, earned: { $sum: '$amount' } } },
    ]);
    return row?.earned ?? 0;
}

// "Who is having the best week" — Heat, in the spec's terms. Deliberately independent of
// career standing: a newcomer on a tear must be able to top this while ranking nowhere.
export async function topEarnersInWindow(
    from: Date,
    to: Date,
    limit: number
): Promise<{ userId: Types.ObjectId; earned: number }[]> {
    const rows = await BankEvent.aggregate([
        { $match: { timestamp: { $gte: from, $lte: to } } },
        { $group: { _id: '$userId', earned: { $sum: '$amount' } } },
        { $sort: { earned: -1 } },
        { $limit: limit },
    ]);
    return rows.map(r => ({ userId: r._id as Types.ObjectId, earned: r.earned as number }));
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd server && npx vitest run src/leaderboards.test.ts`
Expected: PASS, 8 tests.

- [ ] **Step 5: Run the full suite and build**

Run: `cd server && npm test && npm run build`
Expected: all suites PASS, build clean.

- [ ] **Step 6: Commit**

```bash
git add server/src/leaderboards.ts server/src/leaderboards.test.ts
git commit -m "feat(server): windowed earnings, the question that started this

earningsInWindow and topEarnersInWindow sum BankEvent amounts over a period — the thing
that was uncomputable before the event log existed, and the first Heat board's query.

Both are deliberately independent of career standing: a newcomer on a tear must be able to
top 'best week' while ranking nowhere on the banzuke. That separation is the whole point of
the spec's Heat-vs-Rank distinction."
```

---

## What this plan deliberately does NOT do

- **No displays.** Nothing here is visible in game. That is plan 3, and it is additionally blocked on retargeting `BoardController` at the kōsatsu boards — it has no-opped since the jumbotron was removed (T23).
- **No stats surface.** The Records/Heat/Volume queries and their API belong to plan 2 and depend on the history this plan starts accruing.
- **No skill stats.** Edge and the participation-vs-winrate study need defect (h) to be ACTIVE, not merely fixed — both deployed environments run `TEST_MODE`, so nothing exercises the plurality rule yet.
- **No backfill.** Bank events and sessions start from deploy. There is no historical data to reconstruct them from, and inventing it would poison the first season's numbers.
