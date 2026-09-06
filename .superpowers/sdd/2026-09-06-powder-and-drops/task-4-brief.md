### Task 4: `powder/topup` and `fireworks/melt`; `powder` on the reads

**Files:**
- Modify: `server/src/routes/apiV1.ts` (`/economy` ~L320-348, `/fireworks` ~L350-368, new routes after `fireworks/spend`)
- Test: `server/src/routes/apiV1.test.ts` (inside `describe('fireworks', …)`)

**Interfaces:**
- `GET …/economy` and `GET …/fireworks` both add `powder: number`.
- `POST …/powder/topup { points }` → 400 `BAD_AMOUNT` unless a positive integer; 409 `INSUFFICIENT_POINTS` with `{ held }`; 200 `{ powder, totalPoints }`.
- `POST …/fireworks/melt { shellId, count }` → 400 `BAD_SHELL`; 400 `BAD_COUNT` unless a positive integer; 400 `POWDER_INELIGIBLE`; 409 `NONE_HELD` with `{ held }`; 200 `{ shellId, count: remaining, powder, credited }` where `credited = count * SHELL_PRICES[shellId]`.

- [ ] **Step 1: Write the failing tests**

```ts
        describe('powder (spec §7): points and shells flow IN, nothing flows out but fireworks', () => {
            it('economy and fireworks reads carry powder (default 0)', async () => {
                await User.create({ robloxId: '920' });
                const app = makeApp(makeEngine(), new ResultsStore());
                expect((await request(app).get('/api/v1/players/920/economy').set('X-API-Key', API_KEY).expect(200)).body.powder).toBe(0);
                expect((await request(app).get('/api/v1/players/920/fireworks').set('X-API-Key', API_KEY).expect(200)).body.powder).toBe(0);
            });

            it('topup moves points into powder, one way, atomically', async () => {
                await User.create({ robloxId: '921', totalPoints: 10 });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/921/powder/topup').set('X-API-Key', API_KEY).send({ points: 4 }).expect(200);
                expect(res.body).toEqual({ powder: 4, totalPoints: 6 });
                const after = await User.findOne({ robloxId: '921' });
                expect(after!.totalPoints).toBe(6);
                expect(after!.powder).toBe(4);
                expect(after!.lifetimeBanked ?? 0).toBe(0); // career earnings untouched
            });

            it('topup refuses more than the wallet holds, and moves nothing', async () => {
                await User.create({ robloxId: '922', totalPoints: 3 });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/922/powder/topup').set('X-API-Key', API_KEY).send({ points: 4 }).expect(409);
                expect(res.body).toEqual({ error: 'INSUFFICIENT_POINTS', held: 3 });
                const after = await User.findOne({ robloxId: '922' });
                expect([after!.totalPoints, after!.powder]).toEqual([3, 0]);
            });

            it('topup is ONE WAY: zero, negative, fractional and non-numeric amounts are refused', async () => {
                await User.create({ robloxId: '923', totalPoints: 10, powder: 10 });
                const app = makeApp(makeEngine(), new ResultsStore());
                for (const points of [0, -4, 2.5, 'lots', undefined]) {
                    const res = await request(app).post('/api/v1/players/923/powder/topup').set('X-API-Key', API_KEY).send({ points }).expect(400);
                    expect(res.body.error).toBe('BAD_AMOUNT');
                }
                const after = await User.findOne({ robloxId: '923' });
                expect([after!.totalPoints, after!.powder]).toEqual([10, 10]);
            });

            it('melt turns held shells into powder at list price, atomically', async () => {
                await User.create({ robloxId: '924', fireworks: { peony: 3 } });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/924/fireworks/melt').set('X-API-Key', API_KEY).send({ shellId: 'peony', count: 2 }).expect(200);
                expect(res.body).toEqual({ shellId: 'peony', count: 1, powder: 6, credited: 6 }); // peony is 3
                const after = await User.findOne({ robloxId: '924' });
                expect(after!.fireworks.get('peony')).toBe(1);
                expect(after!.powder).toBe(6);
                expect(after!.totalPoints).toBe(0); // never points
            });

            it('melt refuses more than held, bad counts, unknown shells — and moves nothing', async () => {
                await User.create({ robloxId: '925', fireworks: { peony: 1 } });
                const app = makeApp(makeEngine(), new ResultsStore());
                const post = (body: object) => request(app).post('/api/v1/players/925/fireworks/melt').set('X-API-Key', API_KEY).send(body);
                expect((await post({ shellId: 'peony', count: 2 }).expect(409)).body).toEqual({ error: 'NONE_HELD', held: 1 });
                expect((await post({ shellId: 'peony', count: 0 }).expect(400)).body.error).toBe('BAD_COUNT');
                expect((await post({ shellId: 'peony', count: 1.5 }).expect(400)).body.error).toBe('BAD_COUNT');
                expect((await post({ shellId: 'moonshot', count: 1 }).expect(400)).body.error).toBe('BAD_SHELL');
                const after = await User.findOne({ robloxId: '925' });
                expect([after!.fireworks.get('peony'), after!.powder]).toEqual([1, 0]);
            });

            it('CONCURRENT MELTS CANNOT OVER-CREDIT — one conditional update per melt', async () => {
                await User.create({ robloxId: '926', fireworks: { wa: 1 } });
                const app = makeApp(makeEngine(), new ResultsStore());
                const body = { shellId: 'wa', count: 1 };
                const [a, b] = await Promise.all([
                    request(app).post('/api/v1/players/926/fireworks/melt').set('X-API-Key', API_KEY).send(body),
                    request(app).post('/api/v1/players/926/fireworks/melt').set('X-API-Key', API_KEY).send(body),
                ]);
                expect([a.status, b.status].sort()).toEqual([200, 409]);
                const after = await User.findOne({ robloxId: '926' });
                expect([after!.fireworks.get('wa'), after!.powder]).toEqual([0, 5]); // wa is 5
            });
        });
```

The `POWDER_INELIGIBLE` branch cannot be exercised while the list is empty; add this test with `it.skip` and a comment "un-skip when the first ineligible shell exists", asserting 400 `POWDER_INELIGIBLE`.

- [ ] **Step 2: Run to verify it fails** — `npx vitest run src/routes/apiV1.test.ts -t "powder"` → 404s / missing fields.

- [ ] **Step 3: Implement**

`/economy`: add `powder: user.powder ?? 0,` to the response object. `/fireworks`: add `powder: user.powder ?? 0` to its `res.json`. Import `isPowderEligible` from `'../fireworks'`.

After `fireworks/spend`:

```ts
    // POINTS → POWDER, ONE WAY (spec 2026-09-05 §7, decision 10). The wallet is the durable
    // economy; powder buys only things that burn. Nothing anywhere moves powder back, and this
    // route refuses any amount that is not a positive integer so it cannot be run in reverse.
    router.post('/players/:robloxUserId/powder/topup', async (req, res) => {
        try {
            const points = req.body?.points;
            if (!Number.isInteger(points) || points <= 0) { res.status(400).json({ error: 'BAD_AMOUNT' }); return; }
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }
            const updated = await User.findOneAndUpdate(
                { _id: user._id, totalPoints: { $gte: points } },
                { $inc: { totalPoints: -points, powder: points } },
                { new: true }
            );
            if (!updated) { res.status(409).json({ error: 'INSUFFICIENT_POINTS', held: user.totalPoints }); return; }
            res.json({ powder: updated.powder, totalPoints: updated.totalPoints });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });

    // SHELLS → POWDER at list price (the Hanabiya melts them). Safe because powder cannot leave
    // the economy: a melted shell can only become another firework. Eligibility is the one gate —
    // rare/secret/special shells are outside powder in both directions.
    router.post('/players/:robloxUserId/fireworks/melt', async (req, res) => {
        try {
            const shellId = req.body?.shellId;
            const count = req.body?.count;
            if (typeof shellId !== 'string' || !SHELL_IDS.includes(shellId as never)) { res.status(400).json({ error: 'BAD_SHELL' }); return; }
            if (!Number.isInteger(count) || count <= 0) { res.status(400).json({ error: 'BAD_COUNT' }); return; }
            if (!isPowderEligible(shellId)) { res.status(400).json({ error: 'POWDER_INELIGIBLE' }); return; }
            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }
            const credited = count * SHELL_PRICES[shellId];
            const updated = await User.findOneAndUpdate(
                { _id: user._id, [`fireworks.${shellId}`]: { $gte: count } },
                { $inc: { [`fireworks.${shellId}`]: -count, powder: credited } },
                { new: true }
            );
            if (!updated) { res.status(409).json({ error: 'NONE_HELD', held: user.fireworks?.get(shellId) ?? 0 }); return; }
            res.json({ shellId, count: updated.fireworks.get(shellId) ?? 0, powder: updated.powder, credited });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });
```

- [ ] **Step 4: Run** — `npm test && npx tsc --noEmit` → PASS.

- [ ] **Step 5: Commit**

```bash
git add server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "feat(powder): topup (points -> powder, one way) and melt (shells -> powder at list price), both one conditional update; powder on the reads

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

