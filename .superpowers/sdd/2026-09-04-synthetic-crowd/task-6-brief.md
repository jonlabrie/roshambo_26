### Task 6: Settlement, the Round document, and everything that carries a round

**Files:**
- Modify: `server/src/engine/Settlement.ts` (`GlobalResult` ~line 10-16, `RoundToSettle` ~line 32-38, top of `settleRound` ~line 75-83)
- Modify: `server/src/models/Round.ts`
- Modify: `server/src/engine/ResultsStore.test.ts:6` (helper literal)
- Modify: `server/src/index.ts` (~line 110-113, the tape seed)
- Test: `server/src/engine/Settlement.test.ts` (append to the `settleRound` describe)

**Interfaces:**
- Consumes: Task 5's `RoundClosedEvent.crowdCounts`.
- Produces: `GlobalResult.synthetic: number` (required — every producer must say); `RoundToSettle.crowdCounts?: Record<Throw, number>`; `IRound.synthetic: number` with schema `default: 0`.

- [ ] **Step 1: Write the failing test**

Append inside `describe('settleRound', …)` in `server/src/engine/Settlement.test.ts`:

```ts
    describe('the synthetic crowd is part of the world, never a participant (spec §3, §4)', () => {
        it('totalPlayers counts humans + bots, synthetic records the bots, and only humans settle', async () => {
            await User.create({ deviceId: 'devA' });
            const { round, players } = await settleRound({
                roundId: 'r-crowd',
                worldThrow: 'R',
                counts: { R: 21, P: 6, S: 4 },          // 1 human (P) + 30 bots
                crowdCounts: { R: 21, P: 5, S: 4 },
                throws: throwsMap([
                    ['pwa:devA', { throw: 'P', seq: 1, platform: 'pwa', deviceId: 'devA' }],
                ]),
                timestamp: new Date(),
            });
            expect(round).toMatchObject({ totalPlayers: 31, synthetic: 30, distribution: { R: 68, P: 19, S: 13 } });
            expect(players).toHaveLength(1);
            expect(players[0]).toMatchObject({ key: 'pwa:devA', result: 'WIN' });
            expect(await PlayerRound.countDocuments({ roundId: 'r-crowd' })).toBe(1);
            expect(await User.countDocuments()).toBe(1);
            const saved = await Round.findOne({ id: 'r-crowd' }).lean();
            expect(saved).toMatchObject({ totalPlayers: 31, synthetic: 30 });
        });

        it('without crowdCounts, synthetic is 0 and totalPlayers is the humans, as before', async () => {
            const { round } = await settleRound({
                roundId: 'r-plain',
                worldThrow: 'R',
                counts: { R: 0, P: 2, S: 0 },
                throws: throwsMap([
                    ['pwa:x', { throw: 'P', seq: 1, platform: 'pwa', deviceId: 'x' }],
                    ['pwa:y', { throw: 'P', seq: 1, platform: 'pwa', deviceId: 'y' }],
                ]),
                timestamp: new Date(),
            });
            expect(round).toMatchObject({ totalPlayers: 2, synthetic: 0 });
        });
    });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `npx vitest run src/engine/Settlement.test.ts`
Expected: the two new tests FAIL (`totalPlayers: 1`, `synthetic` undefined). TypeScript may also complain about `crowdCounts` — that is the same failure.

- [ ] **Step 3: Write minimal implementation**

`server/src/engine/Settlement.ts` — `GlobalResult`:

```ts
export interface GlobalResult {
    id: string;
    worldThrow: Throw;
    distribution: { R: number; P: number; S: number };
    totalPlayers: number; // the size of the WORLD the player faced: humans + synthetic (spec §3)
    synthetic: number;    // how many of those were bots; humans = totalPlayers - synthetic
    timestamp: Date;
}
```

`RoundToSettle`:

```ts
export interface RoundToSettle {
    roundId: string;
    worldThrow: Throw;
    counts: Record<Throw, number>;        // human + crowd
    crowdCounts?: Record<Throw, number>;  // the crowd's share; absent/zeros when there is none
    throws: Map<string, ThrowEntry>;      // humans only
    timestamp: Date;
}
```

Top of `settleRound`:

```ts
export async function settleRound(data: RoundToSettle): Promise<{ round: GlobalResult; players: SettledPlayer[] }> {
    // sum(counts), not throws.size: the two were equal until the crowd existed. The
    // distribution and the player count must describe the same world (spec §3).
    const totalPlayers = data.counts.R + data.counts.P + data.counts.S;
    const crowd = data.crowdCounts ?? { R: 0, P: 0, S: 0 };
    const synthetic = crowd.R + crowd.P + crowd.S;
    const round: GlobalResult = {
        id: data.roundId,
        worldThrow: data.worldThrow,
        distribution: buildDistribution(data.counts, totalPlayers),
        totalPlayers,
        synthetic,
        timestamp: data.timestamp,
    };
```

`server/src/models/Round.ts` — interface and schema:

```ts
    totalPlayers: number; // humans + synthetic
    synthetic: number;    // bot count; default 0 keeps every historical row honest
```

```ts
    totalPlayers: { type: Number, default: 0 },
    synthetic: { type: Number, default: 0 },
```

`server/src/engine/ResultsStore.test.ts:6` helper — add the field:

```ts
    return { id, worldThrow: 'R', distribution: { R: 100, P: 0, S: 0 }, totalPlayers: 1, synthetic: 0, timestamp: new Date() };
```

`server/src/index.ts` tape seed (~line 110):

```ts
        store.seed(lastRounds.map(r => ({
            id: r.id, worldThrow: r.worldThrow as Throw, distribution: r.distribution,
            totalPlayers: r.totalPlayers, synthetic: r.synthetic ?? 0, timestamp: r.timestamp,
        })));
```

- [ ] **Step 4: Run the whole suite and the type-check**

Run: `npm test && npx tsc --noEmit`
Expected: PASS, no type errors. If `tsc` reports another `GlobalResult` literal missing `synthetic`, add `synthetic: 0` there — the field is required precisely so producers cannot forget it.

- [ ] **Step 5: Commit**

```bash
git add src/engine/Settlement.ts src/engine/Settlement.test.ts src/models/Round.ts src/engine/ResultsStore.test.ts src/index.ts
git commit -m "feat(settlement): totalPlayers is the size of the world; Round.synthetic records the bots in it

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

