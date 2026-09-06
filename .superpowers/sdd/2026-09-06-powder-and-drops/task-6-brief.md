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

