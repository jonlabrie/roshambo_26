### Task 4: Resolving a win — RISK or BANK

One route for both outcomes, so the two can never be left half-wired. Banking must also clear the gate, including the defensive case where there is nothing to bank — a player stuck bound forever is the worst failure mode this design has.

**Files:**
- Modify: `server/src/wallet.ts:6-17`
- Modify: `server/src/routes/apiV1.ts` (add route after the existing `/bank`)
- Test: extend `server/src/wallet.test.ts` (exists — read it first, match its style)

**Interfaces:**
- Produces: `POST /api/v1/resolve-win`, body `{ robloxUserId: string, choice: 'risk' | 'bank' }`,
  responding `{ totalPoints, pointsAtStake, stakingStreak, currentStreak, unresolvedWin }`.
- Produces: `resolveWin(userId: string, choice: 'risk' | 'bank'): Promise<IUser | null>` in `wallet.ts`.

- [ ] **Step 1: Write the failing test**

Add to `server/src/wallet.test.ts`, reusing its `connectTestDb` / `clearTestDb` /
`disconnectTestDb` hooks and its `User.create(...)` fixture style. Add `resolveWin` to the
existing `from './wallet'` import.

```ts
describe('resolveWin', () => {
    beforeAll(connectTestDb);
    afterAll(disconnectTestDb);
    beforeEach(clearTestDb);

    it('RISK clears the gate and leaves the pot riding', async () => {
        const u = await User.create({ deviceId: 'devR', totalPoints: 0, pointsAtStake: 27,
            stakingStreak: 3, currentStreak: 3, unresolvedWin: true });
        const after = await resolveWin(u._id.toString(), 'risk');
        expect(after).toMatchObject({ unresolvedWin: false, pointsAtStake: 27, totalPoints: 0 });
    });

    it('BANK clears the gate and moves the pot into the wallet', async () => {
        const u = await User.create({ deviceId: 'devB', totalPoints: 0, pointsAtStake: 27,
            stakingStreak: 3, currentStreak: 3, unresolvedWin: true });
        const after = await resolveWin(u._id.toString(), 'bank');
        expect(after).toMatchObject({ unresolvedWin: false, pointsAtStake: 0, totalPoints: 27 });
    });

    it('BANK also records lifetimeBanked', async () => {
        const u = await User.create({ deviceId: 'devL', pointsAtStake: 27, unresolvedWin: true,
            lifetimeBanked: 100 });
        const after = await resolveWin(u._id.toString(), 'bank');
        expect(after!.lifetimeBanked).toBe(127);
    });

    it('BANK with nothing staked still clears the gate', async () => {
        // Should be unreachable (a WIN always leaves a pot >= 1), but if it ever happened the
        // player would be bound forever with no way to throw again. Never strand them.
        const u = await User.create({ deviceId: 'devZ', pointsAtStake: 0, unresolvedWin: true });
        const after = await resolveWin(u._id.toString(), 'bank');
        expect(after!.unresolvedWin).toBe(false);
    });

    it('is idempotent — a double-tap does not bank twice', async () => {
        const u = await User.create({ deviceId: 'devD', totalPoints: 0, pointsAtStake: 27,
            unresolvedWin: true });
        await resolveWin(u._id.toString(), 'bank');
        await resolveWin(u._id.toString(), 'bank');
        const after = await User.findById(u._id);
        expect(after!.totalPoints).toBe(27); // not 54
        expect(after!.unresolvedWin).toBe(false);
    });

    it('RISK when not bound is a no-op, not an error', async () => {
        const u = await User.create({ deviceId: 'devN', pointsAtStake: 9, unresolvedWin: false });
        await resolveWin(u._id.toString(), 'risk');
        const after = await User.findById(u._id);
        expect(after!.pointsAtStake).toBe(9);
    });
});
```

- [ ] **Step 2: Run it to verify it fails**

Run: `npm test -- wallet`
Expected: FAIL — `resolveWin` is not exported from `wallet.ts`.

- [ ] **Step 3: Implement `resolveWin`**

First extend `bankPot`'s update so banking clears the gate **and** records the lifetime total the
ledger reports. One edit, replacing the existing update document:

```ts
        {
            $inc: { totalPoints: user.pointsAtStake, lifetimeBanked: user.pointsAtStake },
            $set: { pointsAtStake: 0, stakingStreak: 0, unresolvedWin: false },
        },
```

Then add below it:

```ts
// Answer an outstanding WIN. RISK leaves the pot staked and only lifts the gate; BANK banks and
// lifts it. Both are conditional on unresolvedWin so a double-tap cannot double-bank.
export async function resolveWin(userId: string, choice: 'risk' | 'bank'): Promise<IUser | null> {
    if (choice === 'risk') {
        return User.findOneAndUpdate(
            { _id: userId, unresolvedWin: true },
            { $set: { unresolvedWin: false } },
            { new: true }
        );
    }
    const banked = await bankPot(userId);
    if (banked) return banked;
    // Nothing was staked (should be unreachable after a WIN). Clear the gate regardless —
    // leaving it set would lock the player out of throwing permanently.
    return User.findOneAndUpdate(
        { _id: userId, unresolvedWin: true },
        { $set: { unresolvedWin: false } },
        { new: true }
    );
}
```

Also add `lifetimeBanked` tracking to `bankPot`'s `$inc` so the ledger's "Banked" figure is real:

```ts
        { $inc: { totalPoints: user.pointsAtStake, lifetimeBanked: user.pointsAtStake }, ... },
```

- [ ] **Step 4: Add the route**

In `apiV1.ts`, immediately after the existing `/bank` route:

```ts
    router.post('/resolve-win', async (req, res) => {
        try {
            const robloxUserId = String(req.body?.robloxUserId ?? '');
            const choice = req.body?.choice;
            if (!robloxUserId || (choice !== 'risk' && choice !== 'bank')) {
                res.status(400).json({ error: 'BAD_REQUEST' });
                return;
            }
            const user = await resolveUser({ robloxUserId });
            if (!user) { res.status(500).json({ error: 'RESOLVE_FAILED' }); return; }
            const updated = await resolveWin(user._id.toString(), choice);
            // A null here means the player was not bound — already resolved, or a duplicate tap.
            // That is not an error; echo current state so the client converges either way.
            const state = updated ?? user;
            res.json({
                totalPoints: state.totalPoints,
                pointsAtStake: state.pointsAtStake,
                stakingStreak: state.stakingStreak,
                currentStreak: state.currentStreak,
                unresolvedWin: state.unresolvedWin ?? false,
            });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });
```

Update the import at the top: `import { bankPot, resolveWin } from '../wallet';`

- [ ] **Step 5: Run the tests**

Run: `npm test` → PASS.

- [ ] **Step 6: Commit**

```bash
git add server/src/wallet.ts server/src/routes/apiV1.ts server/src/wallet.test.ts
git commit -m "feat(server): POST /resolve-win — RISK or BANK answers an outstanding win"
```

---

