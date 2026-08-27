### Task 3: Settlement increments the counters and sets the win gate

`settleRound` already does one `findByIdAndUpdate` per participant. Add `$inc` for the counters alongside the existing `$set`, and set `unresolvedWin` on a WIN.

**Files:**
- Modify: `server/src/engine/Settlement.ts:88-96`
- Test: extend `server/src/engine/Settlement.test.ts` (exists — read it first, match its style)

**Interfaces:**
- Consumes: `IUser` fields from Task 2.
- Produces: nothing new in `SettledPlayer` — the counters are read back via the profile route (Task 5).

- [ ] **Step 1: Write the failing test**

Add to `server/src/engine/Settlement.test.ts`. `buildCounterUpdate` is pure, so these cases need
no database — add `buildCounterUpdate` to that file's existing import from `./Settlement`.

```ts
describe('buildCounterUpdate', () => {
    it('counts a win, sets the gate, and tracks the biggest pot', () => {
        const u = buildCounterUpdate('R', 'WIN', 81);
        expect(u.$inc.roundsPlayed).toBe(1);
        expect(u.$inc.wins).toBe(1);
        expect(u.$inc.throwsR).toBe(1);
        expect(u.$set.unresolvedWin).toBe(true);
        expect(u.$max.bestPot).toBe(81);
    });

    it('a SAFE counts a round and a throw but sets no gate', () => {
        const u = buildCounterUpdate('P', 'SAFE', 27);
        expect(u.$inc.safes).toBe(1);
        expect(u.$inc.throwsP).toBe(1);
        expect(u.$set.unresolvedWin).toBe(false);
    });

    it('a LOSS clears the gate — there is nothing left to decide', () => {
        // the pot is forfeited, so a player cannot be left bound on a decision about zero
        const u = buildCounterUpdate('S', 'LOSS', 0);
        expect(u.$inc.losses).toBe(1);
        expect(u.$inc.throwsS).toBe(1);
        expect(u.$set.unresolvedWin).toBe(false);
    });

    it('proposes the new pot for bestPot and lets $max arbitrate', () => {
        // the builder never reads the stored best — it proposes, Mongo keeps the larger
        const u = buildCounterUpdate('R', 'WIN', 3);
        expect(u.$max.bestPot).toBe(3);
    });

    it('every round counts exactly one throw', () => {
        for (const t of ['R', 'P', 'S'] as const) {
            const u = buildCounterUpdate(t, 'SAFE', 0);
            const thrown = (u.$inc.throwsR ?? 0) + (u.$inc.throwsP ?? 0) + (u.$inc.throwsS ?? 0);
            expect(thrown).toBe(1);
        }
    });
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `npm test -- Settlement`
Expected: FAIL — `buildCounterUpdate` is not exported.

- [ ] **Step 3: Add the builder and wire it in**

Add to `Settlement.ts`, above `settleRound`:

```ts
// Counter/gate deltas for one settled participant. Extracted so the arithmetic is testable
// without a database. `newPot` is the post-round pot, proposed to $max — the builder never reads
// the stored bestPot, it just offers a candidate and lets Mongo keep the larger.
export function buildCounterUpdate(thrown: Throw, result: RoundResult, newPot: number) {
    const throwKey = ({ R: 'throwsR', P: 'throwsP', S: 'throwsS' } as const)[thrown];
    return {
        $inc: {
            roundsPlayed: 1,
            wins: result === 'WIN' ? 1 : 0,
            safes: result === 'SAFE' ? 1 : 0,
            losses: result === 'LOSS' ? 1 : 0,
            [throwKey]: 1,
        } as Record<string, number>,
        // A WIN binds the player until they answer RISK or BANK. A LOSS forfeits the pot, so
        // there is nothing to decide and the gate must NOT be left standing.
        $set: { unresolvedWin: result === 'WIN' },
        $max: { bestPot: newPot },
    };
}
```

Then, in `settleRound`, replace the existing `findByIdAndUpdate` call with:

```ts
                const counters = buildCounterUpdate(entry.throw, result, pot);
                const updated = (await User.findByIdAndUpdate(user._id, {
                    $set: {
                        pointsAtStake: pot,
                        currentStreak: streak,
                        stakingStreak: nextStreak(user.stakingStreak || 0, result),
                        bestStreak,
                        ...counters.$set,
                    },
                    $inc: counters.$inc,
                    $max: counters.$max,
                }, { new: true })) || user;
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `npm test` (whole suite — settlement is load-bearing; confirm nothing else regressed).
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add server/src/engine/Settlement.ts server/src/engine/Settlement.test.ts
git commit -m "feat(server): settlement increments ledger counters and sets the win gate"
```

---

