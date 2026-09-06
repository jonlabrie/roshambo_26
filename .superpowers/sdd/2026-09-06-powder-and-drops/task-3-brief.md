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

