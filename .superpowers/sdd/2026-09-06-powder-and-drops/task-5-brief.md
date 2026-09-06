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

