# Player Measurement Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Compute and display READ, YIELD and NERVE, gated at 360 throws, so the Stats room can say who is playing best without lying about it.

**Architecture:** Three aggregations added to `server/src/stats.ts` over rows already written (`PlayerRound`, `BankEvent`) — no new capture, no schema change. They reach the Roblox client through the existing `/api/v1/stats` REST surface and `StatsData` socket push, and render on boards that already exist, through `StatsBoardModel`'s existing section/entry vocabulary.

**Tech Stack:** TypeScript + Mongoose + Vitest (server); Luau + the bespoke Lune harness (Roblox client). No new dependencies.

**Spec:** `docs/superpowers/specs/2026-08-18-player-measurement-design.md`

## Global Constraints

- **Every window in this plan is a ROLLING 7 DAYS**, `rollingWindow(now, WEEK_MS)` — never
  `calendarWeekUTC`. Owner, 2026-08-18: a rolling window rewards dropping in at any hour and
  lets a lucky streak count immediately, where a calendar boundary can wipe a run that started
  on the wrong evening. This **overrides the standing comment in `windows.ts`** ("RANK uses
  calendar windows"), which Task 1 corrects. The board and the 札 must use the SAME window, or
  a player qualifies on one surface and not the other.
- **A rate board must never render an unqualified player.** Qualification is `throws >= 360` inside the window. `QUALIFY.week` becomes 360; `month`/`career` stay 1000.
- **The READ column is withheld entirely while `TEST_MODE` is on.** Under TEST_MODE the World Throw is a fixed R→P→S cycle, so a win rate measures who spotted the pattern. This is an operational gate — a server flag on the wire — NOT a per-round one. Recording per-round derivation provenance is the honest long-term answer and belongs to the out-of-scope "make the world real" work; doing it here would mean a `Round` schema change and a per-row join. **Say so in the code comment**; do not silently simplify.
- **Never sum `PlayerRound.pointsDelta` for earnings.** On a WIN it records the new POT, not the gain. Earnings come from `BankEvent.amount`. The single exception already in the codebase is `forfeitsInWindow`, which filters to LOSS rows where the column *is* the forfeited pot.
- **Denominator is always THROWS, never rounds elapsed.** Abstention is normal play.
- **Label a board by what it measures.** `MOST POINTS PER THROW — THIS WEEK` is true; `BEST PLAYER` is not.
- **`StatsBoardModel` stays pure and requires nothing.** It keeps its own `DRUM` copy deliberately; do not "fix" that into a require.
- Luau: `stylua src tests tools` and `selene src tools` must pass (selene's scope excludes `tests`). Server: `npm test` in `server/`.
- Board geometry is **place-only**. Any change to `StatsRoomLayout` declarations needs `tools/studio/buildStatsBoards.luau` re-run in Studio and the place SAVED. That is an owner action, never `rojo build`.

---

## File Structure

| file | responsibility | change |
|---|---|---|
| `server/src/windows.ts` | time windows + qualification thresholds | `QUALIFY.week` 350 → 360 |
| `server/src/stats.ts` | all stats aggregations | + `winsInWindow`, `winRate` on `PlayerRates`, `bankDepths`, `median`, `depthHistogram`, `qualifiedBoard` |
| `server/src/routes/statsV1.ts` | REST surface for the room | `/player` gains `winRate` + `nerve`; new `/board` |
| `roblox/src/server/NetworkClient.luau` | the room's REST client | + `getStatsBoard` |
| `roblox/src/server/main.server.luau` | the 47s stats poll that feeds `StatsData` | + `filterBoard`, two fields |
| `roblox/src/shared/StatsBoardModel.luau` | pure board composition | + `banzukeSections`, `depthSections`; `fudaSections` gains three rows |
| `roblox/src/shared/StatsFixtures.luau` | Studio-testable seed data | fixtures for all of the above |
| `roblox/src/shared/StatsRoomLayout.luau` | board declarations | `skillFuture` un-shuttered |
| `roblox/src/client/StatsController.client.luau` | board → section wiring | `skillFuture` mapped |

---

### Task 1: READ — win rate, and the 360 floor

**Files:**
- Modify: `server/src/windows.ts`
- Modify: `server/src/stats.ts`
- Test: `server/src/stats.test.ts`, `server/src/windows.test.ts`

**Interfaces:**
- Produces: `winsInWindow(userId, w): Promise<number>`; `PlayerRates.winRate: number | null`
- Consumes: the existing `Window` type and `throwsInWindow`

- [ ] **Step 1: Write the failing tests**

In `server/src/stats.test.ts`:

```ts
describe('READ — win rate', () => {
    it('counts WIN rows against all throws in the window', async () => {
        const a = await User.create({ deviceId: 'a' });
        for (const r of ['WIN', 'WIN', 'SAFE', 'LOSS']) {
            await PlayerRound.create({ userId: a._id, playerThrow: 'R', playerResult: r, pointsDelta: 0, timestamp: at(12) });
        }
        expect(await winsInWindow(a._id, W)).toBe(2);
        const rates = await playerRates(a._id, W, 4);
        expect(rates.winRate).toBeCloseTo(0.5);
    });

    it('is null for an UNQUALIFIED player, because it is the figure a board ranks on', async () => {
        const a = await User.create({ deviceId: 'a' });
        await PlayerRound.create({ userId: a._id, playerThrow: 'R', playerResult: 'WIN', pointsDelta: 1, timestamp: at(12) });
        const rates = await playerRates(a._id, W, 360);
        expect(rates.qualified).toBe(false);
        expect(rates.winRate).toBeNull();
    });

    it('excludes rows outside the window', async () => {
        const a = await User.create({ deviceId: 'a' });
        await PlayerRound.create({ userId: a._id, playerThrow: 'R', playerResult: 'WIN', pointsDelta: 1, timestamp: at(9) });
        expect(await winsInWindow(a._id, W)).toBe(0);
    });
});
```

In `server/src/windows.test.ts`, replace the existing threshold assertion:

```ts
it('qualifies a week at 360 throws — six hours, and above the ~356 the maths needs', () => {
    expect(QUALIFY.week).toBe(360);
});
```

- [ ] **Step 2: Run them and watch them fail**

Run: `cd server && npx vitest run src/stats.test.ts src/windows.test.ts`
Expected: FAIL — `winsInWindow is not defined`, and `QUALIFY.week` is 350.

- [ ] **Step 3: Move the floor**

In `server/src/windows.ts`, change `week: 350` to:

```ts
    // 360, not the ~356 the standard error strictly needs: rounds are OPEN 51 + LOCK 2 +
    // REVEAL 7 = 60s exactly, so 360 throws is 360 MINUTES. "Play six hours in a week and you
    // are on the board" is a rule a player can hold, and it is printed on the board itself.
    week: 360,
```

- [ ] **Step 3b: Correct the window doctrine while you are in the file**

`windows.ts` says "RANK uses calendar windows — a standing has to name a period players can
agree on." The owner ruled otherwise on 2026-08-18. Replace that comment:

```ts
// RANK uses a ROLLING window (owner, 2026-08-18). The calendar argument was that a standing
// should name a period players agree on — but a Monday boundary wipes a run that started on
// Sunday evening, and it makes WHEN you play matter as much as how well. Rolling rewards
// dropping in at any hour and lets a hot streak count the moment it happens.
// `calendarDayUTC`/`calendarWeekUTC` stay: records boards still name a day.
```

- [ ] **Step 4: Add the query and the rate**

In `server/src/stats.ts`, beside `throwsInWindow`:

```ts
// READ — the one clean measure of crowd-reading, and the figure QUALIFY was derived for.
// A blind player wins exactly 1/3 of rounds, so anything above 0.333 is edge, and the crowd
// cannot all be above it: the winners in a round are precisely those who threw the counter to
// the plurality, which is by definition not the plurality.
export async function winsInWindow(userId: Types.ObjectId, w: Window): Promise<number> {
    return PlayerRound.countDocuments({
        userId,
        playerResult: 'WIN',
        timestamp: { $gte: w.from, $lt: w.to },
    });
}
```

Add `winRate: number | null;` to the `PlayerRates` interface, documented:

```ts
    // GATED ON `qualified`, like pointsPerThrow and unlike the volume figures: this is the
    // number a board ranks on, and at 60 throws a BLIND player's observed rate lands anywhere
    // between 23% and 43%. Null rather than a small-sample figure, so a caller cannot print it
    // by accident.
    winRate: number | null;
```

In `playerRates`, add `winsInWindow(userId, w)` to the existing `Promise.all`, and return:

```ts
        winRate: qualified && throws > 0 ? wins / throws : null,
```

- [ ] **Step 5: Run the tests and watch them pass**

Run: `cd server && npx vitest run src/stats.test.ts src/windows.test.ts`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add server/src/windows.ts server/src/stats.ts server/src/stats.test.ts server/src/windows.test.ts
git commit -m "feat(server): READ — win rate against the world, qualified at 360 throws"
```

---

### Task 2: NERVE — how deep the room rides

**Files:**
- Modify: `server/src/stats.ts`
- Test: `server/src/stats.test.ts`

**Interfaces:**
- Produces: `bankDepths(w, userId?): Promise<number[]>`, `median(xs): number | null`, `depthHistogram(xs, maxDepth): number[]`
- Consumes: `BankEvent.streakAtBank`

- [ ] **Step 1: Write the failing tests**

```ts
describe('NERVE — bank depth', () => {
    const bank = (u: any, streakAtBank: number, amount = 1) =>
        BankEvent.create({ userId: u._id, amount, streakAtBank, timestamp: at(12) });

    it('median of an odd sample is the middle value', async () => {
        const a = await User.create({ deviceId: 'a' });
        for (const d of [1, 5, 3]) await bank(a, d);
        expect(median(await bankDepths(W, a._id))).toBe(3);
    });

    it('median of an even sample is the midpoint', async () => {
        const a = await User.create({ deviceId: 'a' });
        for (const d of [2, 4]) await bank(a, d);
        expect(median(await bankDepths(W, a._id))).toBe(3);
    });

    it('is null when a player has banked nothing — never 0, which would read as "banks instantly"', async () => {
        const a = await User.create({ deviceId: 'a' });
        expect(median(await bankDepths(W, a._id))).toBeNull();
    });

    it('without a userId it covers the whole room', async () => {
        const a = await User.create({ deviceId: 'a' });
        const b = await User.create({ deviceId: 'b' });
        await bank(a, 1); await bank(b, 7);
        expect((await bankDepths(W)).length).toBe(2);
    });

    it('the histogram buckets by depth and folds everything deeper into the last bucket', () => {
        // index 0 is depth 1. maxDepth 5 means depths 6, 7, 9 all land in the final bucket.
        expect(depthHistogram([1, 1, 2, 6, 7, 9], 5)).toEqual([2, 1, 0, 0, 3]);
    });

    it('the histogram ignores a nonsense depth of 0 rather than crashing', () => {
        expect(depthHistogram([0, 1], 3)).toEqual([1, 0, 0]);
    });
});
```

- [ ] **Step 2: Run them and watch them fail**

Run: `cd server && npx vitest run src/stats.test.ts -t NERVE`
Expected: FAIL — `bankDepths is not defined`

- [ ] **Step 3: Implement**

In `server/src/stats.ts`:

```ts
// NERVE — how deep a player rides before collecting. `BankEvent.streakAtBank` was written for
// exactly this: "the whole bank-vs-stake story lives in the distribution of this number".
//
// NOT A LEADERBOARD, and the plan says so deliberately: ranking "who rides deepest" crowns the
// player who rides past their own read and banks nothing, which is a losing strategy wearing a
// winner's hat. This feeds a personal figure and a room-wide histogram, and neither is ranked.
export async function bankDepths(w: Window, userId?: Types.ObjectId): Promise<number[]> {
    const match: Record<string, unknown> = { timestamp: { $gte: w.from, $lt: w.to } };
    if (userId) match.userId = userId;
    const rows = await BankEvent.find(match).select('streakAtBank');
    return rows.map(r => r.streakAtBank ?? 0);
}

// Null, never 0, on an empty sample: a 0 here would render as "banks instantly", which is the
// opposite of "has never banked".
export function median(xs: number[]): number | null {
    if (xs.length === 0) return null;
    const s = [...xs].sort((a, b) => a - b);
    const m = s.length >> 1;
    return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}

// Index 0 is depth 1. Everything at or beyond `maxDepth` folds into the last bucket, because
// the tail is long and thin and a board has a fixed number of rows. Depths below 1 are dropped
// rather than clamped — a bank at streak 0 should not exist, and inventing a bucket for it
// would hide the bug if it ever did.
export function depthHistogram(xs: number[], maxDepth: number): number[] {
    const out = new Array(maxDepth).fill(0);
    for (const x of xs) {
        if (x < 1) continue;
        out[Math.min(maxDepth, Math.floor(x)) - 1] += 1;
    }
    return out;
}
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: `cd server && npx vitest run src/stats.test.ts -t NERVE`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add server/src/stats.ts server/src/stats.test.ts
git commit -m "feat(server): NERVE — the distribution of where players choose to stop"
```

---

### Task 3: The 番付 query

**Files:**
- Modify: `server/src/stats.ts`
- Test: `server/src/stats.test.ts`

**Interfaces:**
- Produces: `qualifiedBoard(w, minThrows, limit): Promise<BoardRow[]>` where
  `BoardRow = { userId, throws, wins, banked, pointsPerThrow, winRate }`
- Consumes: `PlayerRound`, `BankEvent`

- [ ] **Step 1: Write the failing tests**

```ts
describe('the 番付 — qualified board', () => {
    const throws = async (u: any, n: number, wins: number) => {
        for (let i = 0; i < n; i++) {
            await PlayerRound.create({
                userId: u._id, playerThrow: 'R',
                playerResult: i < wins ? 'WIN' : 'LOSS',
                pointsDelta: 0, timestamp: at(12),
            });
        }
    };

    it('ranks by points per throw, and carries win rate beside it', async () => {
        const a = await User.create({ deviceId: 'a' });
        const b = await User.create({ deviceId: 'b' });
        await throws(a, 10, 5); await BankEvent.create({ userId: a._id, amount: 20, streakAtBank: 2, timestamp: at(12) });
        await throws(b, 10, 3); await BankEvent.create({ userId: b._id, amount: 50, streakAtBank: 4, timestamp: at(12) });
        const rows = await qualifiedBoard(W, 10, 10);
        expect(rows.map(r => String(r.userId))).toEqual([String(b._id), String(a._id)]);
        expect(rows[0].pointsPerThrow).toBeCloseTo(5.0);
        expect(rows[1].winRate).toBeCloseTo(0.5);
    });

    it('excludes a player below the throw floor, however well they did', async () => {
        const a = await User.create({ deviceId: 'a' });
        await throws(a, 3, 3);
        await BankEvent.create({ userId: a._id, amount: 900, streakAtBank: 6, timestamp: at(12) });
        expect(await qualifiedBoard(W, 10, 10)).toEqual([]);
    });

    it('includes a qualified player who has banked nothing, at zero', async () => {
        const a = await User.create({ deviceId: 'a' });
        await throws(a, 10, 4);
        const rows = await qualifiedBoard(W, 10, 10);
        expect(rows).toHaveLength(1);
        expect(rows[0].pointsPerThrow).toBe(0);
        expect(rows[0].winRate).toBeCloseTo(0.4);
    });

    it('honours the limit', async () => {
        for (const d of ['a', 'b', 'c']) {
            const u = await User.create({ deviceId: d });
            await throws(u, 10, 5);
        }
        expect(await qualifiedBoard(W, 10, 2)).toHaveLength(2);
    });
});
```

- [ ] **Step 2: Run them and watch them fail**

Run: `cd server && npx vitest run src/stats.test.ts -t 番付`
Expected: FAIL — `qualifiedBoard is not defined`

- [ ] **Step 3: Implement**

```ts
export interface BoardRow {
    userId: Types.ObjectId;
    throws: number;
    wins: number;
    banked: number;
    pointsPerThrow: number;
    winRate: number;
}

// THE 番付. Two aggregations and an in-memory join rather than a $lookup: the qualified set is
// small by construction (360 throws is six hours of play), so the join is over tens of rows.
//
// Ranked on POINTS PER THROW, with WIN RATE carried beside it rather than blended in. Yield is
// the only figure that captures the compounding the spec measures -- a +10 player riding deep
// earns 37.5/throw where a blind player riding to 7 earns 2.1, a gap win rate renders as 43%
// against 33% -- and the read column is what tells a reader whether someone is up there on
// skill or on nerve. Blending them into one score would destroy exactly that.
export async function qualifiedBoard(w: Window, minThrows: number, limit: number): Promise<BoardRow[]> {
    const counts = await PlayerRound.aggregate([
        { $match: { timestamp: { $gte: w.from, $lt: w.to } } },
        {
            $group: {
                _id: '$userId',
                throws: { $sum: 1 },
                wins: { $sum: { $cond: [{ $eq: ['$playerResult', 'WIN'] }, 1, 0] } },
            },
        },
        { $match: { throws: { $gte: minThrows } } },
    ]);
    if (counts.length === 0) return [];

    const banks = await BankEvent.aggregate([
        { $match: { userId: { $in: counts.map(c => c._id) }, timestamp: { $gte: w.from, $lt: w.to } } },
        { $group: { _id: '$userId', banked: { $sum: '$amount' } } },
    ]);
    const bankedBy = new Map<string, number>(banks.map(b => [String(b._id), b.banked as number]));

    return counts
        .map(c => {
            // A qualified player who banked nothing belongs on the board at zero, not missing
            // from it: they threw the hours, and a board that silently drops them looks broken
            // to the one person guaranteed to be looking for their own name.
            const banked = bankedBy.get(String(c._id)) ?? 0;
            return {
                userId: c._id,
                throws: c.throws,
                wins: c.wins,
                banked,
                pointsPerThrow: banked / c.throws,
                winRate: c.wins / c.throws,
            };
        })
        .sort((a, b) => b.pointsPerThrow - a.pointsPerThrow || b.winRate - a.winRate)
        .slice(0, limit);
}
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: `cd server && npx vitest run src/stats.test.ts`
Expected: PASS (whole file, so Task 1 and 2 stay green)

- [ ] **Step 5: Commit**

```bash
git add server/src/stats.ts server/src/stats.test.ts
git commit -m "feat(server): the 番付 — qualified players ranked by yield, read beside it"
```

---

### Task 4: Put them on the wire

**Files:**
- Modify: `server/src/routes/statsV1.ts`
- Modify: `server/src/transports/socketAdapter.ts`
- Test: `server/src/routes/statsV1.test.ts`

**Interfaces:**
- Consumes: `qualifiedBoard`, `bankDepths`, `median`, `depthHistogram`, `playerRates` (Tasks 1–3)
- Produces: `GET /api/v1/stats/board` → `{ window, windowKind, minThrows, worldIsCrowd, rows: [{ displayName, pointsPerThrow, winRate, throws }], depths: number[] }`;
  `/player` gains `week.winRate` and `week.nerve`

- [ ] **Step 1: Write the failing test**

```ts
describe('GET /stats/board', () => {
    it('names users, withholds winRate while the world is a test cycle, and carries the floor', async () => {
        process.env.TEST_MODE = 'true';
        const a = await User.create({ deviceId: 'a', displayName: 'Ayaka', robloxId: '1' });
        for (let i = 0; i < 10; i++) {
            await PlayerRound.create({ userId: a._id, playerThrow: 'R', playerResult: 'WIN', pointsDelta: 1, timestamp: at(12) });
        }
        await BankEvent.create({ userId: a._id, amount: 30, streakAtBank: 3, timestamp: at(12) });
        const res = await request(app).get('/api/v1/stats/board?minThrows=10').set('X-API-Key', KEY);
        expect(res.status).toBe(200);
        expect(res.body.worldIsCrowd).toBe(false);
        expect(res.body.rows[0].displayName).toBe('Ayaka');
        expect(res.body.rows[0].pointsPerThrow).toBeCloseTo(3.0);
        expect(res.body.rows[0].winRate).toBeNull();
        expect(res.body.minThrows).toBe(360);
    });

    it('sends winRate once the world is the crowd', async () => {
        process.env.TEST_MODE = 'false';
        const a = await User.create({ deviceId: 'a', displayName: 'Ayaka', robloxId: '1' });
        for (let i = 0; i < 10; i++) {
            await PlayerRound.create({ userId: a._id, playerThrow: 'R', playerResult: i < 4 ? 'WIN' : 'LOSS', pointsDelta: 0, timestamp: at(12) });
        }
        const res = await request(app).get('/api/v1/stats/board?minThrows=10').set('X-API-Key', KEY);
        expect(res.body.worldIsCrowd).toBe(true);
        expect(res.body.rows[0].winRate).toBeCloseTo(0.4);
    });
});
```

Match the existing file's app/KEY setup; do not invent a new harness.

- [ ] **Step 2: Run it and watch it fail**

Run: `cd server && npx vitest run src/routes/statsV1.test.ts`
Expected: FAIL — 404 on `/stats/board`

- [ ] **Step 3: Add the route**

In `server/src/routes/statsV1.ts`:

```ts
    // THE READ GATE, AND WHY IT IS OPERATIONAL RATHER THAN PER-ROUND. Under TEST_MODE the World
    // Throw is a fixed R->P->S cycle, so a win rate measures who spotted the pattern and nothing
    // else -- actively misleading, not merely imprecise. The honest version records per-round
    // whether the throw was derived from the crowd or fell back, and that needs a `Round` schema
    // field plus a per-row join; it belongs to the "make the world real" work, which is out of
    // scope here (spec section 9). Until then this one flag withholds the column wholesale.
    const worldIsCrowd = () => process.env.TEST_MODE !== 'true';

    router.get('/board', async (req, res) => {
        try {
            const w = rollingWindow(new Date(), WEEK_MS);
            const minThrows = Number(req.query.minThrows) || QUALIFY.week;
            const rows = await qualifiedBoard(w, minThrows, 10);
            const names = await nameUsers(rows.map(r => r.userId));
            const open = worldIsCrowd();
            res.set('Cache-Control', 'public, max-age=30');
            res.json({
                window: { from: w.from, to: w.to },
                windowKind: 'calendar',
                minThrows: QUALIFY.week,
                worldIsCrowd: open,
                rows: rows.map(r => ({
                    displayName: names.get(String(r.userId)) ?? 'Anonymous',
                    pointsPerThrow: r.pointsPerThrow,
                    winRate: open ? r.winRate : null,
                    throws: r.throws,
                })),
                depths: depthHistogram(await bankDepths(w), 8),
            });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });
```

In the existing `/player/:robloxUserId` handler — **and change its `calendarWeekUTC(new Date())`
to `rollingWindow(new Date(), WEEK_MS)` in the same edit**, so the 札 and the board agree about
who is qualified — after `rates`:

```ts
            const nerve = median(await bankDepths(w, user._id));
            // ... then in the response body, replace `week: rates` with:
            week: { ...rates, winRate: worldIsCrowd() ? rates.winRate : null, nerve },
```

Add the imports (`qualifiedBoard`, `bankDepths`, `median`, `depthHistogram`, `nameUsers`).

- [ ] **Step 4: Run the tests and watch them pass**

Run: `cd server && npm test`
Expected: PASS, whole server suite

- [ ] **Step 5: Commit**

```bash
git add server/src/routes/statsV1.ts server/src/routes/statsV1.test.ts
git commit -m "feat(server): serve the banzuke, the depth histogram, and the read gate"
```

⚠ **Do NOT touch `socketAdapter.ts`'s `get-stats-surface`.** That is the PWA's path and it
never reaches the Stats room. The room's feed is REST, polled by the Roblox server — Task 5.

---

### Task 5: Feed the room

**Files:**
- Modify: `roblox/src/server/NetworkClient.luau`
- Modify: `roblox/src/server/main.server.luau`
- Test: `roblox/tests/NetworkClient.spec.luau`

**Interfaces:**
- Consumes: `GET /api/v1/stats/board` (Task 4)
- Produces: `lastStats.board` and `lastStats.depths` on the existing `StatsData` push

**Why this is its own task:** the walls do NOT read the socket. `StatsData` is assembled by a
47-second poll in `main.server.luau` that makes four REST reads through `NetworkClient`; the
`get-stats-surface` socket event belongs to the PWA. A board added to the socket payload would
render nowhere.

- [ ] **Step 1: Write the failing test**

Match the existing spec's injected-HttpService pattern:

```lua
test("getStatsBoard requests the board route", function()
    local seen
    local net = NetworkClient.new({
        http = { RequestAsync = function(_, opts)
            seen = opts.Url
            return { Success = true, StatusCode = 200, Body = '{"rows":[]}' }
        end },
        baseUrl = "http://x",
        apiKey = "k",
    })
    net:getStatsBoard()
    expect(string.find(seen, "/api/v1/stats/board", 1, true) ~= nil).toBe(true)
end)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `getStatsBoard` is nil

- [ ] **Step 3: Add the client method**

In `NetworkClient.luau`, beside `getStatsHeat`:

```lua
-- No window parameter: the board is the calendar week by definition, and the route decides.
-- Sending one would invite a caller to ask for a window the qualification floor was not
-- derived for.
function NetworkClient.getStatsBoard(self: any): Result
    return self:_request("GET", "/api/v1/stats/board")
end
```

- [ ] **Step 4: Add it to the poll**

In `main.server.luau`, beside `filterRecords`:

```lua
-- The board arrives already named and already gated by the server; the only thing to strip is
-- anything a client has no business holding. Kept as its own filter rather than folded into
-- filterRecords so a future field on either cannot silently ride along on the other.
local function filterBoard(board: any?): any?
    if not board then
        return board
    end
    local copy = table.clone(board)
    copy.rows = filterTop(board.rows)
    return copy
end
```

In the 47s poller, add the read and the two fields, following the existing nil-able pattern
exactly so one failing endpoint cannot blank the room:

```lua
        local board = net:getStatsBoard()
        -- ... inside the lastStats table:
            board = if board.ok then filterBoard(board.data) else (lastStats and lastStats.board),
            depths = if board.ok then board.data.depths else (lastStats and lastStats.depths),
```

⚠ **Keep the `task.wait(47)`.** The comment there explains it: 60s is exactly the round period,
so a 60s poll would alias with the round forever. Adding a fifth REST read does not change that.

- [ ] **Step 5: Run the tests and watch them pass**

Run: `cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools`
Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add roblox/src/server/NetworkClient.luau roblox/src/server/main.server.luau roblox/tests/NetworkClient.spec.luau
git commit -m "feat(roblox): the room's poll picks up the banzuke and the depth histogram"
```

---

### Task 6: Compose the boards

**Files:**
- Modify: `roblox/src/shared/StatsBoardModel.luau`
- Modify: `roblox/src/shared/StatsFixtures.luau`
- Test: `roblox/tests/StatsBoardModel.spec.luau`

**Interfaces:**
- Produces: `StatsBoardModel.banzukeSections(board, leaders)`, `StatsBoardModel.depthSections(depths)`; `fudaSections` gains READ/YIELD/NERVE rows
- Consumes: the `/board` shape from Task 4

- [ ] **Step 1: Write the failing tests**

```lua
describe("banzukeSections", function()
    local BOARD = {
        minThrows = 360,
        worldIsCrowd = true,
        rows = {
            { displayName = "AYAKA", pointsPerThrow = 2.41, winRate = 0.41, throws = 512 },
            { displayName = "KENJI", pointsPerThrow = 0.98, winRate = 0.36, throws = 402 },
        },
    }

    test("ranks by yield with the read beside it", function()
        -- Searches the composed block rather than a fixed row: which line an entry lands on is
        -- `compose`'s business and is covered by its own tests.
        local all = table.concat(StatsBoardModel.compose(StatsBoardModel.banzukeSections(BOARD, nil), { rows = 10, cols = 26 }), "\n")
        for _, want in { "AYAKA", "2.4", "41%", "KENJI" } do
            expect(string.find(all, want, 1, true) ~= nil).toBe(true)
        end
    end)

    test("prints the baseline, because a bare 41% means nothing to a first-time reader", function()
        local all = table.concat(StatsBoardModel.compose(StatsBoardModel.banzukeSections(BOARD, nil), { rows = 10, cols = 26 }), "\n")
        expect(string.find(all, "33 IN 100", 1, true) ~= nil).toBe(true)
    end)

    test("drops the baseline line with the column it explains", function()
        local closed = { minThrows = 360, worldIsCrowd = false, rows = { BOARD.rows[1] } }
        local all = table.concat(StatsBoardModel.compose(StatsBoardModel.banzukeSections(closed, nil), { rows = 10, cols = 26 }), "\n")
        expect(string.find(all, "33 IN 100", 1, true) == nil).toBe(true)
    end)

    test("withholds the read column entirely when the world is a test cycle", function()
        local closed = { minThrows = 360, worldIsCrowd = false, rows = { BOARD.rows[1] } }
        local line = StatsBoardModel.compose(StatsBoardModel.banzukeSections(closed, nil), { rows = 10, cols = 26 })[2]
        expect(string.find(line, "%%") == nil).toBe(true)
    end)

    test("falls back to career standings, naming the rule, when nobody qualifies", function()
        local empty = { minThrows = 360, worldIsCrowd = true, rows = {} }
        local lines = StatsBoardModel.compose(
            StatsBoardModel.banzukeSections(empty, { { displayName = "AYAKA", lifetimeBanked = 12480 } }),
            { rows = 10, cols = 26 }
        )
        local all = table.concat(lines, "\n")
        expect(string.find(all, "360", 1, true) ~= nil).toBe(true)
        expect(string.find(all, "AYAKA", 1, true) ~= nil).toBe(true)
    end)
end)

describe("depthSections", function()
    test("renders a bar per depth, scaled to the largest bucket", function()
        local lines = StatsBoardModel.compose(StatsBoardModel.depthSections({ 4, 8, 2, 0, 0, 0, 0, 0 }), { rows = 6, cols = 13 })
        expect(#lines).toBe(6)
        -- depth 2 is the tallest bucket, so its bar is the longest
        expect(#(lines[3]:gsub("[^#]", "")) >= #(lines[2]:gsub("[^#]", ""))).toBe(true)
    end)

    test("an empty room renders without dividing by zero", function()
        local lines = StatsBoardModel.compose(StatsBoardModel.depthSections({ 0, 0, 0 }), { rows = 6, cols = 13 })
        expect(#lines).toBe(6)
    end)
end)
```

- [ ] **Step 2: Run them and watch them fail**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `banzukeSections` is nil

- [ ] **Step 3: Implement**

Add to `StatsBoardModel`, reusing the existing `entryLine`/`labelLine`/`padRight`/`trunc` helpers — do not write new width maths.

⚠ **`pct` is a file-local and `fudaSections` uses it too**, so declare it up with the other
helpers near the top of the module, not immediately above `banzukeSections`. A local declared
below a use does not resolve.

```lua
-- A percentage as a whole number, or a blank when the read gate is closed. Blank, never "-":
-- a dash reads as "zero percent" on a board where every other row carries a figure.
local function pct(v: number?): string
    return if v == nil then "" else `{math.floor(v * 100 + 0.5)}%`
end

-- THE 番付. Ranked on yield; read carried beside it, never blended in.
function StatsBoardModel.banzukeSections(board: any?, leaders: { any }?): { Section }
    local b = board or {}
    local rows = b.rows or {}
    if #rows == 0 then
        -- NEVER EMPTY. Before anyone has thrown six hours the wall shows career standings and
        -- says what the ranking is waiting for, because a blank board reads as broken and the
        -- rule is the one thing a new player most wants to know.
        local entries: { Entry } = {}
        for _, l in leaders or {} do
            table.insert(entries, { name = l.displayName, figure = StatsBoardModel.figure(l.lifetimeBanked) })
        end
        return {
            { title = "CAREER BANKED", entries = entries },
            { title = `{b.minThrows or 360} THROWS PUTS YOU HERE`, entries = {} },
        }
    end
    local entries: { Entry } = {}
    for _, r in rows do
        local read = if b.worldIsCrowd then pct(r.winRate) else ""
        local yield = string.format("%.1f", r.pointsPerThrow or 0)
        table.insert(entries, { name = r.displayName, figure = if read == "" then yield else `{yield} {read}` })
    end
    -- THE BASELINE, PRINTED (spec section 6). "41%" means nothing to a reader who does not know
    -- that a blind player scores 33 -- and every reader is in that position the first time. A
    -- second section with no entries renders as a bare line under the ranking. Only when the
    -- read column is actually showing: without it the line explains a column that is not there.
    local sections = { { title = "POINTS PER THROW - 7 DAYS", entries = entries } }
    if b.worldIsCrowd then
        table.insert(sections, { title = "LUCK ALONE WINS 33 IN 100", entries = {} })
    end
    return sections
end

-- NERVE as a shape, not a ranking. Index 1 is depth 1; the last bucket is "this deep or more".
function StatsBoardModel.depthSections(depths: { number }?): { Section }
    local d = depths or {}
    local max = 0
    for _, n in d do
        max = math.max(max, n)
    end
    local entries: { Entry } = {}
    for i, n in d do
        -- Guard the empty room: with no banks at all every bar is zero-width, not an error.
        local bars = if max > 0 then math.floor(n / max * 5 + 0.5) else 0
        table.insert(entries, { name = tostring(i) .. string.rep("#", bars), figure = tostring(n) })
    end
    return { { title = "BANK AFTER", entries = entries } }
end
```

Extend `fudaSections` with three rows after `THROWS`, using the same `Entry` shape:

```lua
                { name = "BEAT WORLD", figure = if p.week and p.week.winRate then pct(p.week.winRate) else "-" },
                { name = "PER THROW", figure = if p.week and p.week.pointsPerThrow
                    then string.format("%.1f", p.week.pointsPerThrow) else "-" },
                { name = "YOU BANK AT", figure = if p.week and p.week.nerve
                    then StatsBoardModel.figure(p.week.nerve) else "-" },
```

Update `StatsFixtures.PERSONAL.week` to `minThrows = 360` and add `winRate = 0.41, pointsPerThrow = 2.41, nerve = 3`; add `StatsFixtures.STATS.board` and `.depths` matching Task 4's shape.

- [ ] **Step 4: Run the tests and watch them pass**

Run: `cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools`
Expected: PASS, 0 errors, 0 warnings

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/StatsBoardModel.luau roblox/src/shared/StatsFixtures.luau roblox/tests/StatsBoardModel.spec.luau
git commit -m "feat(roblox): the banzuke reads yield then read; the room's depth takes a wall"
```

---

### Task 7: Hang them on the walls

**Files:**
- Modify: `roblox/src/client/StatsController.client.luau`
- Modify: `roblox/src/shared/StatsRoomLayout.luau`
- Test: `roblox/tests/StatsRoomLayout.spec.luau`

**Interfaces:**
- Consumes: `banzukeSections`, `depthSections` (Task 5)

- [ ] **Step 1: Write the failing test**

```lua
test("skillFuture is no longer shuttered — it carries the room's bank depth", function()
    for _, b in StatsRoomLayout.boards() do
        if b.id == "skillFuture" then
            expect(b.shuttered).toBe(nil)
        end
    end
end)
```

- [ ] **Step 2: Run it and watch it fail**

Run: `cd roblox && lune run tests/run`
Expected: FAIL — `shuttered` is `true`

- [ ] **Step 3: Un-shutter and wire**

In `StatsRoomLayout.luau`, delete the `shuttered = true` line from the `skillFuture` declaration and replace its comment:

```lua
        -- Was shuttered while it waited for a population to rank. It now carries the room's
        -- bank-depth histogram, which needs no qualification at all -- choosing when to collect
        -- is real player behaviour even under TEST_MODE. 13 columns cannot hold a ranked line
        -- (`1. AYAKA   2.4 41%` needs ~18), which is why the 番付 took the 26-column south wall
        -- and the shape-of-the-room board took this one.
```

In `StatsController.client.luau`'s `linesFor`:

```lua
    elseif id == "banzuke" then
        return Model.compose(Model.banzukeSections(s and s.board, s and s.leaders), o)
    elseif id == "skillFuture" then
        return Model.compose(Model.depthSections(s and s.depths), o)
```

(replacing the existing `banzuke` branch, which called `standingsSections` — that function is now reached through `banzukeSections`' fallback and must NOT be deleted.)

- [ ] **Step 4: Run the tests and watch them pass**

Run: `cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add roblox/src/client/StatsController.client.luau roblox/src/shared/StatsRoomLayout.luau roblox/tests/StatsRoomLayout.spec.luau
git commit -m "feat(roblox): the banzuke takes the south wall, the shutter comes off the west"
```

---

## Studio gate — the owner looks

**Not a task. Requires the owner, and the place must be SAVED afterwards.**

`skillFuture` changing from shuttered to live is a geometry change, so
`roblox/tools/studio/buildStatsBoards.luau` must be re-run in Studio and the place saved —
`rojo build` would drop it. Set `StatsFixtures` on via the `StatsFixtures` Workspace attribute
to see populated boards without six hours of play.

What to look at:
1. **The 番付 on the south wall** — does `2.4 41%` in one column read, or do the two figures run together at 26 columns?
2. **The fallback** — with fixtures off, does "RANKED AT 360 THROWS/WK" read as an invitation rather than an error?
3. **The depth histogram** at 13 columns — do five `#` bars read as a shape from across the room, or does it want a real bar glyph?
4. **The 札** — three more rows on a 16-column slip; does it still read as a personal note rather than a spreadsheet?

⚠ Check `Workspace` → Attributes for a leftover `StatsFixtures` before judging anything as broken. A live-tuning attribute outlives the session and silently beats the default.
