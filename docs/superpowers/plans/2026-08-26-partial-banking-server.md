# Partial Banking (server half) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a player bank part of their pot by dropping it to a lower rung of the 3ⁿ ladder, keeping the remainder riding — server-side rules, wallet, event record and both transports.

**Architecture:** One new pure function, `keepOptions(pot)`, returns the ladder values a pot may be dropped to. It is added to the fixture-gated rules and mirrored in Luau, so all implementations are held to the same table. `bankPot` gains a `keep` parameter defaulting to `0`, which makes today's full bank the zero case and keeps every existing caller correct. `BankEvent` gains a `partial` flag so the NERVE stat keeps measuring what it says it measures. Both transports pass `keep` through and validate it.

**Tech Stack:** TypeScript + Vitest (`server/`), Luau + a bespoke Lune harness (`roblox/`), Mongoose/MongoDB Atlas, Socket.io, Express.

**Spec:** `docs/superpowers/specs/2026-08-26-partial-banking-design.md`

## Global Constraints

- **TDD is mandatory** (`CLAUDE.md`): write the failing test first, watch it fail, then implement.
- **Integers only.** A pot is never fractional. Owner: *"I wouldn't let them split a point — 14 or 13 banked, never 13.5."* Every keep value is a ladder rung, so every banked difference is an integer by construction.
- **Pots stay on the 3ⁿ ladder** — 0, 1, 3, 9, 27, 81, … Nothing in this change may put a pot elsewhere.
- ⚠ **`currentStreak` is NEVER touched by banking**, partial or full. The gated aura reads it (`roblox/src/shared/StreakAura.luau`).
- ⚠ **`stakingStreak` is zeroed only when the pot reaches zero.** Owner ruling 2026-08-26: *"we don't zero stakingStreak if the pot isn't zeroed."* The condition moves from "a bank happened" to "the pot is now 0".
- ⚠ **Backward compatibility is required.** A bank request with no `keep` must behave exactly as today. Existing clients (the shipped PWA and Roblox client) send no `keep` and must keep working unchanged.
- ⚠ **The rules fixture gates three implementations.** `shared-fixtures/game-rules.json` is read by `server/src/engine/GameRules.test.ts` and `roblox/tests/GameRules.spec.luau`. Adding a section is safe until a harness reads it; Task 6 wires the Luau side.
- **Luau modules take Roblox services by injection and must name no Roblox type** in files the Lune harness requires.
- **Lint must pass at CI scope**: `cd roblox && stylua --check src tests tools && selene src tools` (selene fails on warnings).

**Commands:**
```bash
source ~/.nvm/nvm.sh && nvm use          # before any npm in this repo
cd server && npm test                    # vitest
cd roblox && lune run tests/run          # Luau tests
```

## Out of scope — read this before starting

⚠ **This plan is the SERVER HALF ONLY, deliberately.** The client affordance — what a player taps to drop a rung — **has not been designed**. The spec gives the copy (*"drop a level, pocket the difference"*) and nothing about the control, and the Roblox HUD needs the owner's eyes in Studio. Writing steps for it here would be invention.

The server half ships on its own because it is backward compatible: with no client change, every bank is a full bank and behaves exactly as it does today. **Do not add UI in this plan.**

## File Structure

| file | responsibility | task |
|---|---|---|
| `shared-fixtures/game-rules.json` | the contract all three implementations are held to | 1 |
| `server/src/engine/GameRules.ts` | `keepOptions`, `isValidKeep` — pure | 1 |
| `server/src/engine/GameRules.test.ts` | fixture-driven assertions | 1 |
| `server/src/wallet.ts` | `bankPot(userId, platform, keep)` | 2 |
| `server/src/wallet.test.ts` | wallet behaviour | 2 |
| `server/src/models/BankEvent.ts` | the `partial` flag | 3 |
| `server/src/stats.ts` | `bankDepths` filters to full banks | 3 |
| `server/src/stats.test.ts` | NERVE stays clean | 3 |
| `server/src/transports/socketAdapter.ts` | PWA `bank` payload | 4 |
| `server/src/routes/apiV1.ts` | Roblox `POST /bank` body | 5 |
| `roblox/src/shared/GameRules.luau` | the Luau mirror | 6 |
| `roblox/tests/GameRules.spec.luau` | same fixture, other runtime | 6 |

---

### Task 1: `keepOptions` in the shared rules

The one new rule. `keepOptions(pot)` returns every ladder value strictly below `pot`, ascending, starting at 0. A client renders the choices from it; the server validates against it. Defining it once and gating it on the fixture is what stops the three implementations drifting.

**Files:**
- Modify: `shared-fixtures/game-rules.json`
- Modify: `server/src/engine/GameRules.ts` (append after `nextStreak`, before the World Throw section)
- Test: `server/src/engine/GameRules.test.ts`

**Interfaces:**
- Consumes: nothing.
- Produces: `keepOptions(pot: number): number[]` and `isValidKeep(pot: number, keep: number): boolean`, both exported from `server/src/engine/GameRules.ts`.

- [ ] **Step 1: Add the fixture sections**

Add these two top-level keys to `shared-fixtures/game-rules.json`, as siblings of `matchups` / `potProgression` / `streakRules` / `worldThrowDerivation`:

```json
    "partialBank": [
        { "pot": 0, "keepOptions": [], "why": "nothing staked — there is nothing to drop" },
        { "pot": 1, "keepOptions": [0], "why": "the only move from the bottom rung is a full bank" },
        { "pot": 3, "keepOptions": [0, 1] },
        { "pot": 9, "keepOptions": [0, 1, 3] },
        { "pot": 27, "keepOptions": [0, 1, 3, 9] },
        { "pot": 81, "keepOptions": [0, 1, 3, 9, 27] },
        { "pot": 243, "keepOptions": [0, 1, 3, 9, 27, 81] }
    ],
    "partialBankRejects": [
        { "pot": 27, "keep": 27, "why": "keep must be STRICTLY below the pot — this is a no-op, not a bank" },
        { "pot": 27, "keep": 81, "why": "banking may never increase the pot" },
        { "pot": 27, "keep": 5, "why": "5 is not a rung of the 3^n ladder" },
        { "pot": 27, "keep": 13.5, "why": "no fractional points, ever" },
        { "pot": 27, "keep": -1, "why": "negative" },
        { "pot": 0, "keep": 0, "why": "nothing staked" }
    ],
```

- [ ] **Step 2: Write the failing test**

Append inside the existing `describe('GameRules (shared fixtures)')` block in `server/src/engine/GameRules.test.ts`:

```ts
    it.each(fixtures.partialBank)(
        'pot $pot may be dropped to $keepOptions',
        ({ pot, keepOptions: expected }) => {
            expect(keepOptions(pot)).toEqual(expected);
            for (const keep of expected) {
                expect(isValidKeep(pot, keep)).toBe(true);
            }
        }
    );

    it.each(fixtures.partialBankRejects)(
        'pot $pot rejects keep $keep — $why',
        ({ pot, keep }) => {
            expect(isValidKeep(pot, keep)).toBe(false);
        }
    );
```

And extend the import at the top of the same file:

```ts
import { calculateResult, nextPot, potDelta, nextStreak, keepOptions, isValidKeep, deriveWorldThrow, Throw, RoundResult } from './GameRules';
```

- [ ] **Step 3: Run test to verify it fails**

Run: `source ~/.nvm/nvm.sh && nvm use && cd server && npx vitest run src/engine/GameRules.test.ts`
Expected: FAIL — `keepOptions` and `isValidKeep` are not exported from `./GameRules`.

- [ ] **Step 4: Write minimal implementation**

Append to `server/src/engine/GameRules.ts`, immediately after `nextStreak`:

```ts
// PARTIAL BANKING: a pot may be dropped to a LOWER RUNG, banking the difference.
//
// WHY RUNGS AND NOT A SLIDER. A continuous fraction turns Bank-vs-Stake into an optimisation with
// a computable answer; three or four discrete choices keep it a judgement call. Rungs also mean
// every pot stays a power of three and every banked difference is an integer, so "never 13.5"
// holds by construction rather than by rounding (owner, 2026-08-26).
//
// Returns every ladder value strictly below `pot`, ascending, 0 first. 0 is the full bank, which
// is why `bankPot`'s default keep of 0 reproduces today's behaviour exactly.
export function keepOptions(pot: number): number[] {
    if (!Number.isFinite(pot) || pot <= 0) return [];
    const options = [0];
    // Walk the ladder 1, 3, 9, ... and stop before reaching the pot itself.
    for (let rung = 1; rung < pot; rung *= 3) options.push(rung);
    return options;
}

export function isValidKeep(pot: number, keep: number): boolean {
    if (!Number.isInteger(keep)) return false;
    return keepOptions(pot).includes(keep);
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `source ~/.nvm/nvm.sh && nvm use && cd server && npx vitest run src/engine/GameRules.test.ts`
Expected: PASS, including the seven `partialBank` rows and six `partialBankRejects` rows.

- [ ] **Step 6: Run the whole server suite**

Run: `source ~/.nvm/nvm.sh && nvm use && cd server && npm test`
Expected: PASS. Nothing else reads the new fixture sections yet, so no other test may change.

- [ ] **Step 7: Commit**

```bash
git add shared-fixtures/game-rules.json server/src/engine/GameRules.ts server/src/engine/GameRules.test.ts
git commit -m "feat(rules): keepOptions — the rungs a pot may be dropped to"
```

---

### Task 2: `bankPot` takes a `keep` amount

**Files:**
- Modify: `server/src/wallet.ts`
- Test: `server/src/wallet.test.ts`

**Interfaces:**
- Consumes: `isValidKeep(pot, keep)` from Task 1.
- Produces: `bankPot(userId: string, platform: 'pwa' | 'roblox', keep?: number): Promise<IUser | null>` — `keep` defaults to `0`. Returns `null` for nothing staked, a lost race, **or an invalid keep**.

- [ ] **Step 1: Write the failing tests**

Append to the existing top-level `describe` in `server/src/wallet.test.ts`:

```ts
    it('partial bank: drops 27 to 9, banks 18, and keeps stakingStreak alive', async () => {
        const u = await User.create({
            deviceId: 'devPartial1', totalPoints: 5, pointsAtStake: 27,
            stakingStreak: 3, currentStreak: 3, unresolvedWin: true,
        });
        const updated = await bankPot(u._id.toString(), 'pwa', 9);
        expect(updated).toMatchObject({
            totalPoints: 23,        // 5 + 18
            lifetimeBanked: 18,
            pointsAtStake: 9,       // still riding
            stakingStreak: 3,       // NOT zeroed — the pot did not reach zero
            currentStreak: 3,       // never touched by banking
            unresolvedWin: false,   // the player has decided
        });
    });

    it('partial bank down to zero behaves exactly like a full bank', async () => {
        const u = await User.create({
            deviceId: 'devPartial2', pointsAtStake: 9, stakingStreak: 2, currentStreak: 2,
        });
        const updated = await bankPot(u._id.toString(), 'pwa', 0);
        expect(updated).toMatchObject({ pointsAtStake: 0, stakingStreak: 0, currentStreak: 2 });
    });

    it('rejects a keep that is not a lower rung, leaving the wallet untouched', async () => {
        const u = await User.create({ deviceId: 'devPartial3', pointsAtStake: 27, stakingStreak: 3 });
        expect(await bankPot(u._id.toString(), 'pwa', 5)).toBeNull();
        expect(await bankPot(u._id.toString(), 'pwa', 27)).toBeNull();
        expect(await bankPot(u._id.toString(), 'pwa', 81)).toBeNull();
        const after = await User.findById(u._id);
        expect(after).toMatchObject({ pointsAtStake: 27, totalPoints: 0, stakingStreak: 3 });
    });

    it('writes a BankEvent marked partial, with the streak at the moment of banking', async () => {
        const u = await User.create({ deviceId: 'devPartial4', pointsAtStake: 27, stakingStreak: 3 });
        await bankPot(u._id.toString(), 'roblox', 9);
        const ev = await BankEvent.findOne({ userId: u._id });
        expect(ev).toMatchObject({ amount: 18, streakAtBank: 3, platform: 'roblox', partial: true });
    });

    it('a full bank is still recorded as not partial', async () => {
        const u = await User.create({ deviceId: 'devPartial5', pointsAtStake: 9, stakingStreak: 2 });
        await bankPot(u._id.toString(), 'pwa');
        const ev = await BankEvent.findOne({ userId: u._id });
        expect(ev).toMatchObject({ amount: 9, partial: false });
    });
```

If `BankEvent` is not imported at the top of `wallet.test.ts`, add `import BankEvent from './models/BankEvent';` — the existing tests assert on the user document only, so it may not be there yet.

- [ ] **Step 2: Run tests to verify they fail**

Run: `source ~/.nvm/nvm.sh && nvm use && cd server && npx vitest run src/wallet.test.ts`
Expected: FAIL — `bankPot` takes two arguments, so the third is ignored and `pointsAtStake` comes back `0` instead of `9`. The `partial` assertions fail because the field does not exist.

- [ ] **Step 3: Write the implementation**

Replace the body of `server/src/wallet.ts` with:

```ts
import User, { IUser } from './models/User';
import BankEvent from './models/BankEvent';
import { isValidKeep } from './engine/GameRules';

// Bank = move part or all of the at-stake pot into totalPoints. `keep` is what stays riding and
// must be a LOWER RUNG of the 3^n ladder (GameRules.keepOptions); 0 is the full bank, which is
// why every existing caller is correct unchanged.
//
// currentStreak (win streak) is NEVER reset by banking.
//
// ⚠ stakingStreak is zeroed only when the POT REACHES ZERO, not merely because a bank happened
// (owner ruling, 2026-08-26). A player who hedges down a rung still has money on the same run.
//
// Atomic: the filter guards against double-banking races.
export async function bankPot(
    userId: string,
    platform: 'pwa' | 'roblox',
    keep: number = 0
): Promise<IUser | null> {
    const user = await User.findById(userId);
    // null return is overloaded: nothing staked, an invalid keep, OR a lost concurrent-update
    // race; benign in single-process deployment.
    if (!user || user.pointsAtStake <= 0) return null;
    if (!isValidKeep(user.pointsAtStake, keep)) return null;

    const amount = user.pointsAtStake - keep;
    const streakAtBank = user.stakingStreak || 0;
    const partial = keep > 0;

    const updated = await User.findOneAndUpdate(
        { _id: user._id, pointsAtStake: user.pointsAtStake },
        {
            $inc: { totalPoints: amount, lifetimeBanked: amount },
            $set: {
                pointsAtStake: keep,
                stakingStreak: partial ? streakAtBank : 0,
                // "the last scored round was a WIN and the player has not banked since" — a
                // partial bank is a decision, so it resolves the win either way.
                unresolvedWin: false,
            },
        },
        { new: true }
    );

    // AFTER the atomic update, and only if it won the race — a bank that did not happen must
    // not leave an event behind. The reverse ordering would overstate earnings on every lost
    // race. A crash in this gap loses one event, which is the acceptable direction to fail.
    if (updated) {
        await BankEvent.create({ userId: user._id, amount, streakAtBank, platform, partial })
            .catch(err => console.error('Error writing BankEvent:', (err as Error).message));
    }

    return updated;
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `source ~/.nvm/nvm.sh && nvm use && cd server && npx vitest run src/wallet.test.ts`
Expected: PASS. The four pre-existing wallet tests must also still pass — they call `bankPot` with two arguments and exercise the `keep = 0` path.

- [ ] **Step 5: Commit**

```bash
git add server/src/wallet.ts server/src/wallet.test.ts
git commit -m "feat(wallet): bankPot takes a keep amount; stakingStreak survives a partial bank"
```

---

### Task 3: `BankEvent.partial`, and keeping the NERVE stat honest

⚠ **This is the task that exists for a reason a reviewer might not see.** `bankDepths` feeds the NERVE histogram on the 番付 room wall (`server/src/routes/statsV1.ts:170`) and a personal median (`:193`). Its purpose, in its own comment, is *"how deep a player rides before collecting"*. A partial bank writes `streakAtBank` too — so without a flag, a player who drops one rung at streak 6 records the same `6` as one who cashed out entirely at 6, and the histogram silently blends *"when do players stop"* with *"when do players hedge"*. No error, no failing test, just a stat that quietly becomes about something else.

**Files:**
- Modify: `server/src/models/BankEvent.ts`
- Modify: `server/src/stats.ts` (`bankDepths`, around line 102)
- Test: `server/src/stats.test.ts`

**Interfaces:**
- Consumes: `bankPot(..., keep)` from Task 2.
- Produces: `IBankEvent.partial: boolean` (default `false`); `bankDepths` unchanged in signature, changed in filter.

- [ ] **Step 1: Write the failing test**

Append to `server/src/stats.test.ts`:

```ts
describe('bankDepths excludes partial banks', () => {
    it('counts only full banks, so NERVE keeps measuring when players stop', async () => {
        const u = await User.create({ deviceId: 'nerve-1' });
        const w = { from: new Date(Date.now() - 60_000), to: new Date(Date.now() + 60_000) };
        await BankEvent.create({ userId: u._id, amount: 9, streakAtBank: 2, partial: false });
        await BankEvent.create({ userId: u._id, amount: 18, streakAtBank: 6, partial: true });
        await BankEvent.create({ userId: u._id, amount: 27, streakAtBank: 3, partial: false });

        expect((await bankDepths(w)).sort()).toEqual([2, 3]);
    });

    it('still counts a legacy row with no partial field', async () => {
        const u = await User.create({ deviceId: 'nerve-2' });
        const w = { from: new Date(Date.now() - 60_000), to: new Date(Date.now() + 60_000) };
        await BankEvent.collection.insertOne({
            userId: u._id, amount: 9, streakAtBank: 4, platform: 'pwa', timestamp: new Date(),
        });
        expect(await bankDepths(w)).toEqual([4]);
    });
});
```

`BankEvent`, `User` and `bankDepths` are all already imported in that file — add nothing.

- [ ] **Step 2: Run tests to verify they fail**

Run: `source ~/.nvm/nvm.sh && nvm use && cd server && npx vitest run src/stats.test.ts`
Expected: FAIL — the first test returns `[2, 3, 6]` because the partial row is still counted.

- [ ] **Step 3: Add the model field**

In `server/src/models/BankEvent.ts`, add to the `IBankEvent` interface after `streakAtBank`:

```ts
    partial: boolean;
```

and to the schema after the `streakAtBank` field:

```ts
    // ⚠ A PARTIAL BANK IS A DIFFERENT DECISION FROM A FULL ONE, and both write streakAtBank.
    // Without this flag `bankDepths` (the NERVE histogram) blends "when do players stop" with
    // "when do players hedge" — no error, no failing test, just a stat about something else.
    // Cheap now, impossible to reconstruct later: the rows would already be mixed.
    partial: { type: Boolean, default: false },
```

- [ ] **Step 4: Filter `bankDepths`**

In `server/src/stats.ts`, inside `bankDepths`, change the match object so it reads:

```ts
export async function bankDepths(w: Window, userId?: Types.ObjectId): Promise<number[]> {
    // ⚠ FULL BANKS ONLY. A partial bank is a hedge, not a decision to stop, and this stat is
    // about where players stop. `$ne: true` rather than `false` so rows written before the
    // field existed still count — they are all full banks by definition.
    const match: Record<string, unknown> = {
        timestamp: { $gte: w.from, $lt: w.to },
        partial: { $ne: true },
    };
    if (userId) match.userId = userId;
    const rows = await BankEvent.find(match).select('streakAtBank');
    return rows.map(r => r.streakAtBank ?? 0);
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `source ~/.nvm/nvm.sh && nvm use && cd server && npx vitest run src/stats.test.ts`
Expected: PASS, both new tests plus every pre-existing stats test.

- [ ] **Step 6: Confirm the earnings boards are deliberately unfiltered**

Read `heatBoard` and `biggestBanks` in `server/src/stats.ts` and `earningsInWindow` in `server/src/leaderboards.ts`. **They must NOT get the `partial` filter** — a partial bank is real earnings and belongs in every earnings figure. Only `bankDepths` filters. No code change in this step; it exists so the next person does not "fix" the inconsistency.

- [ ] **Step 7: Commit**

```bash
git add server/src/models/BankEvent.ts server/src/stats.ts server/src/stats.test.ts
git commit -m "feat(stats): BankEvent.partial, so NERVE keeps measuring where players stop"
```

---

### Task 4: The PWA transport passes `keep`

**Files:**
- Modify: `server/src/transports/socketAdapter.ts:375-389` (the `socket.on('bank')` handler)
- Test: `server/src/transports/socketAdapter.test.ts`

**Interfaces:**
- Consumes: `bankPot(userId, 'pwa', keep)` from Task 2.
- Produces: the `bank` socket event accepts an optional `{ keep?: number }` payload.

⚠ **There is an existing security test at `socketAdapter.test.ts:362` — *"banks the socket's own pot, whatever the payload asks for"* — which emits `bank` with a `deviceId` in the payload and asserts the victim's pot is untouched.** `deviceId` is a bearer credential on this transport and the payload must never be trusted for identity. Read `keep` from the payload and **nothing else**. Do not widen this handler's trust.

- [ ] **Step 1: Write the failing test**

Append immediately after the existing test *"bank moves pot to totalPoints over the socket"* (`socketAdapter.test.ts:284`), reusing that file's own `initPromise`, `client`, `claimDevice` and `waitFor` helpers. `User` is already imported at line 11 — add nothing.

```ts
    it('bank with a keep drops the pot to that rung over the socket', async () => {
        await initPromise;
        const devA = await claimDevice(client);
        await User.findOneAndUpdate({ deviceId: devA }, {
            $set: { totalPoints: 0, pointsAtStake: 27, stakingStreak: 3, currentStreak: 3 },
        });
        client.emit('sync-player');
        await waitFor(client, 'player-data');

        const updated = waitFor<any>(client, 'player-data');
        client.emit('bank', { keep: 9 });
        expect((await updated).user).toMatchObject({
            totalPoints: 18, pointsAtStake: 9, stakingStreak: 3, currentStreak: 3,
        });
    });

    it('bank with an invalid keep changes nothing', async () => {
        await initPromise;
        const devA = await claimDevice(client);
        await User.findOneAndUpdate({ deviceId: devA }, {
            $set: { totalPoints: 0, pointsAtStake: 27, stakingStreak: 3 },
        });

        client.emit('bank', { keep: 5 });
        // No player-data is emitted for a refused bank, so there is no event to await.
        await new Promise(r => setTimeout(r, 150));

        const after = await User.findOne({ deviceId: devA });
        expect(after!.pointsAtStake).toBe(27);
        expect(after!.totalPoints).toBe(0);
    });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `source ~/.nvm/nvm.sh && nvm use && cd server && npx vitest run src/transports/socketAdapter.test.ts`
Expected: FAIL — the first test gets `pointsAtStake: 0` and `totalPoints: 27`, because the handler ignores the payload and banks everything.

- [ ] **Step 3: Write the implementation**

Change the handler signature and the `bankPot` call in `server/src/transports/socketAdapter.ts`:

```ts
        // ⚠ THE PAYLOAD IS NOT A CREDENTIAL. deviceId is a bearer credential on this transport,
        // so identity comes from the SOCKET and `keep` is the only field read from the wire.
        // An invalid keep is rejected inside bankPot, which returns null and emits nothing.
        socket.on('bank', async (data?: { keep?: number }) => {
            const userId = (socket as any).userId;
            const deviceId = (socket as any).deviceId;
            if (!deviceId && !userId) return;
            try {
                const user = await resolveUser({ userId, deviceId });
                if (!user) return;
                const keep = Number(data?.keep ?? 0);
                const updated = await bankPot(user._id.toString(), 'pwa', keep);
                if (updated) {
                    socket.emit('player-data', { user: updated, history: await personalHistory(updated) });
                }
            } catch (err) {
                console.error('Error banking points:', (err as Error).message);
            }
        });
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `source ~/.nvm/nvm.sh && nvm use && cd server && npx vitest run src/transports/socketAdapter.test.ts`
Expected: PASS — including the pre-existing bank test (no payload) and the payload-is-not-a-credential test at line 362.

- [ ] **Step 5: Commit**

```bash
git add server/src/transports/socketAdapter.ts server/src/transports/socketAdapter.test.ts
git commit -m "feat(socket): bank accepts an optional keep, identity still from the socket"
```

---

### Task 5: The Roblox REST transport passes `keep`

**Files:**
- Modify: `server/src/routes/apiV1.ts:484-505` (`router.post('/bank')`)
- Test: `server/src/routes/apiV1.test.ts` (the `describe('POST /bank')` block at :402)

**Interfaces:**
- Consumes: `bankPot(userId, 'roblox', keep)` from Task 2.
- Produces: `POST /api/v1/bank` accepts `{ robloxUserId, keep? }`. An invalid keep returns `409 NOTHING_STAKED`, the same shape the route already uses for a refused bank.

- [ ] **Step 1: Write the failing test**

Append inside the existing `describe('POST /bank')` block in `server/src/routes/apiV1.test.ts` (:402), reusing that file's `request`, `makeApp`, `makeEngine`, `ResultsStore`, `User` and `API_KEY` — all already imported:

```ts
        it('banks down to a rung and keeps the rest riding', async () => {
            await User.create({
                robloxId: '78', identityTier: 'roblox', pointsAtStake: 27,
                stakingStreak: 3, currentStreak: 3,
            });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/bank').set('X-API-Key', API_KEY)
                .send({ robloxUserId: '78', keep: 9 }).expect(200);

            expect(res.body).toMatchObject({
                totalPoints: 18, pointsAtStake: 9, stakingStreak: 3, currentStreak: 3,
            });
        });

        it('refuses an invalid keep with 409 and changes nothing', async () => {
            const u = await User.create({
                robloxId: '79', identityTier: 'roblox', pointsAtStake: 27, stakingStreak: 3,
            });
            await request(makeApp(makeEngine(), new ResultsStore()))
                .post('/api/v1/bank').set('X-API-Key', API_KEY)
                .send({ robloxUserId: '79', keep: 5 }).expect(409);

            const after = await User.findById(u._id);
            expect(after!.pointsAtStake).toBe(27);
        });
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `source ~/.nvm/nvm.sh && nvm use && cd server && npx vitest run src/routes/apiV1.test.ts`
Expected: FAIL — the first test returns `pointsAtStake: 0`, `totalPoints: 27`; the second returns 200 rather than 409.

- [ ] **Step 3: Write the implementation**

In `server/src/routes/apiV1.ts`, change the `/bank` handler's body-reading and `bankPot` call:

```ts
    router.post('/bank', async (req, res) => {
        try {
            const robloxUserId = String(req.body?.robloxUserId ?? '');
            if (!robloxUserId) { res.status(400).json({ error: 'BAD_REQUEST' }); return; }
            // `keep` is what stays riding; absent means a full bank, which is what every client
            // shipped before partial banking sends. An invalid keep is rejected inside bankPot
            // and surfaces as the same 409 as "nothing staked" — from the caller's side both
            // mean "the bank you asked for did not happen".
            const keep = Number(req.body?.keep ?? 0);
            const user = await resolveUser({ robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            const updated = await bankPot(user._id.toString(), 'roblox', keep);
            if (!updated) { res.status(409).json({ error: 'NOTHING_STAKED' }); return; }
            res.json({
                totalPoints: updated.totalPoints,
                pointsAtStake: updated.pointsAtStake,
                stakingStreak: updated.stakingStreak,
                currentStreak: updated.currentStreak,
            });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `source ~/.nvm/nvm.sh && nvm use && cd server && npx vitest run src/routes/apiV1.test.ts`
Expected: PASS, including the two pre-existing bank tests at :403 and :413.

- [ ] **Step 5: Run the entire server suite**

Run: `source ~/.nvm/nvm.sh && nvm use && cd server && npm test`
Expected: PASS. Every test in the repo's server suite, not just the ones touched.

- [ ] **Step 6: Commit**

```bash
git add server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "feat(api): POST /bank accepts an optional keep"
```

---

### Task 6: The Luau mirror

`roblox/src/shared/GameRules.luau` mirrors `server/src/engine/GameRules.ts` and both are held to the same fixture, so drift fails CI rather than being a promise. The Roblox client will need `keepOptions` to render the choices; adding it now keeps the mirror complete even though no UI consumes it yet.

**Files:**
- Modify: `roblox/src/shared/GameRules.luau`
- Test: `roblox/tests/GameRules.spec.luau`

**Interfaces:**
- Consumes: the `partialBank` / `partialBankRejects` fixture sections from Task 1.
- Produces: `GameRules.keepOptions(pot: number): { number }` and `GameRules.isValidKeep(pot: number, keep: number): boolean`.

- [ ] **Step 1: Write the failing test**

Append inside the existing `describe("GameRules (shared fixtures)")` block in `roblox/tests/GameRules.spec.luau`:

```lua
    for _, row in fixtures.partialBank do
        test(`pot {row.pot} may be dropped to {#row.keepOptions} rung(s)`, function()
            local got = GameRules.keepOptions(row.pot)
            expect(#got).toBe(#row.keepOptions)
            for i, want in row.keepOptions do
                expect(got[i]).toBe(want)
            end
            for _, keep in row.keepOptions do
                expect(GameRules.isValidKeep(row.pot, keep)).toBe(true)
            end
        end)
    end

    for _, row in fixtures.partialBankRejects do
        test(`pot {row.pot} rejects keep {row.keep}`, function()
            expect(GameRules.isValidKeep(row.pot, row.keep)).toBe(false)
        end)
    end
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `attempt to call a nil value` on `GameRules.keepOptions`.

- [ ] **Step 3: Write the implementation**

Append to `roblox/src/shared/GameRules.luau`, immediately after `nextStreak` and before `return GameRules`:

```lua
-- PARTIAL BANKING: a pot may be dropped to a LOWER RUNG, banking the difference. Rungs rather
-- than a slider so every pot stays a power of three and every banked difference is an integer.
-- Returns every ladder value strictly below `pot`, ascending, 0 first; 0 is the full bank.
function GameRules.keepOptions(pot: number): { number }
	if pot ~= pot or pot == math.huge or pot <= 0 then
		return {}
	end
	local options = { 0 }
	local rung = 1
	while rung < pot do
		table.insert(options, rung)
		rung *= 3
	end
	return options
end

function GameRules.isValidKeep(pot: number, keep: number): boolean
	if keep % 1 ~= 0 then
		return false
	end
	for _, option in GameRules.keepOptions(pot) do
		if option == keep then
			return true
		end
	end
	return false
end
```

⚠ Luau has no `Number.isInteger`; `keep % 1 ~= 0` is the check, and it is what rejects the `13.5` fixture row. ⚠ `pot ~= pot` is the NaN test — Luau has no `isNaN`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd roblox && lune run tests/run`
Expected: PASS — the full suite, including the new rows.

- [ ] **Step 5: Lint at CI scope**

Run: `cd roblox && stylua --check src tests tools && selene src tools`
Expected: clean. ⚠ selene fails on warnings; the file uses tabs, matching the rest of `GameRules.luau`.

- [ ] **Step 6: Commit**

```bash
git add roblox/src/shared/GameRules.luau roblox/tests/GameRules.spec.luau
git commit -m "feat(roblox): mirror keepOptions, held to the same fixture"
```

---

## Done when

- [ ] `cd server && npm test` passes in full.
- [ ] `cd roblox && lune run tests/run` passes in full.
- [ ] `cd roblox && stylua --check src tests tools && selene src tools` is clean.
- [ ] A bank request with no `keep` behaves identically to before on both transports — verified by the pre-existing tests still passing untouched.
- [ ] `bankDepths` returns full banks only; `heatBoard`, `biggestBanks` and `earningsInWindow` still count every bank.
- [ ] ⚠ **`potDelta` / `PlayerRound.pointsDelta` were NOT changed.** Stated so nobody goes looking: a partial bank is a wallet action and writes no `PlayerRound` row, exactly like a full bank today, so `biggestRounds`, the forfeits sum at `stats.ts:91`, the PWA per-round banner and the big-wins feed all keep working untouched.

## What this does NOT do, and what comes next

- ⚠ **No client can ask for a partial bank yet.** Both transports accept `keep`; nothing sends it. This is the intended end state of this plan.
- **The client affordance needs a design pass first** — the control has not been specified, and the Roblox HUD needs the owner's eyes in Studio. That is design-thread work followed by main.
- ⚠ **Partial banking dims the proposed aura.** A player who hedges reaches smaller pots, so their peak pot is smaller, and the aura's proposed metric is the peak reached. Not a Bank-vs-Stake neutrality violation — nothing already achieved is removed — but the two features touch, and the aura's metric ruling should be made knowing it. See `docs/wiki/world/status-display.md`.
- **The tuning is unvalidated.** `f* = (bank ÷ pot + 1)/4` assumes p(win) ≈ 0.30, which is not true under TEST_MODE's fixed cycle. ⚠ That bounds the *tuning*, not the *mechanic* — the rules above are tested against constructed fixture cases, which is the right way to test them and does not need real crowds.
