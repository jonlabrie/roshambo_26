### Task 4: The reserve endpoint and its NetworkClient call

**Files:**
- Modify: `server/src/routes/apiV1.ts` (add the route directly after `POST /players/:robloxUserId/fireworks/spend`, ~line 393)
- Test: `server/src/routes/apiV1.test.ts` (append inside `describe('fireworks', …)`)
- Modify: `roblox/src/server/NetworkClient.luau` (after `getFireworks`, ~line 215)
- Test: `roblox/tests/NetworkClient.spec.luau` (append one test, following the file's existing pattern for asserting method/path/body of a call)

**Interfaces:**
- Consumes: Task 1's `validateShow`, `tallyShells`, `shellMortar`, `DECK_STAGE`, `Cue`; the route file's existing `resolveUser`, `User`, `SHELL_IDS`.
- Produces:
  - `POST /api/v1/players/:robloxUserId/shows/reserve` body `{ show: { stageId, fuel, cues, title? } }`
    - 400 `{ error: 'BAD_SHOW' }` when `show` is not an object
    - 400 `{ error: 'FUEL_UNSUPPORTED' }` for any fuel other than `'inventory'`
    - 400 `{ error: 'BAD_STAGE' }` unless `stageId === 'deck:<robloxUserId of the path>'`
    - 400 `{ error: <ShowError>, cue? }` when validation fails
    - 409 `{ error: 'MORTAR_MISSING', slot }` when a cue's mortar slot names a tier the player does not own
    - 409 `{ error: 'INSUFFICIENT', needed: {shellId: n}, held: {shellId: n} }` when the atomic debit matches nothing
    - 200 `{ reservationId, stageId, cues, debited: {shellId: n}, remaining: {shellId: n} }`
  - `NetworkClient.postShowReserve(self, robloxUserId: string, show: any): Result` → `POST /api/v1/players/{id}/shows/reserve` with body `{ show = show }`

- [ ] **Step 1: Write the failing route tests**

Append inside `describe('fireworks', …)` in `server/src/routes/apiV1.test.ts`:

```ts
        describe('POST /players/:id/shows/reserve — a show debits everything up front, or nothing', () => {
            const show = (cues: object[], extra: object = {}) => ({
                show: { stageId: 'deck:910', fuel: 'inventory', cues, ...extra },
            });

            it('debits every shell a valid show needs in one step and reports what is left', async () => {
                await User.create({ robloxId: '910', mortars: ['mortar:S', 'mortar:M'], fireworks: { firecracker: 3, peony: 2, wa: 1 } });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/910/shows/reserve')
                    .set('X-API-Key', API_KEY)
                    .send(show([
                        { t_ms: 0, slot: 'hand', shellId: 'firecracker' },
                        { t_ms: 1000, slot: 'mortar:S', shellId: 'peony' },
                        { t_ms: 1000, slot: 'mortar:M', shellId: 'wa' },
                        { t_ms: 2000, slot: 'hand', shellId: 'firecracker' },
                    ]))
                    .expect(200);
                expect(res.body.reservationId).toMatch(/^[a-z0-9]{6,}$/);
                expect(res.body.stageId).toBe('deck:910');
                expect(res.body.debited).toEqual({ firecracker: 2, peony: 1, wa: 1 });
                expect(res.body.remaining).toEqual({ firecracker: 1, peony: 1, wa: 0 });
                const after = await User.findOne({ robloxId: '910' });
                expect(after!.fireworks.get('firecracker')).toBe(1);
                expect(after!.fireworks.get('wa')).toBe(0);
            });

            it('INSUFFICIENT debits nothing — all or nothing', async () => {
                await User.create({ robloxId: '911', mortars: ['mortar:S'], fireworks: { firecracker: 5, peony: 1 } });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/911/shows/reserve')
                    .set('X-API-Key', API_KEY)
                    .send({ show: { stageId: 'deck:911', fuel: 'inventory', cues: [
                        { t_ms: 0, slot: 'hand', shellId: 'firecracker' },
                        { t_ms: 500, slot: 'mortar:S', shellId: 'peony' },
                        { t_ms: 1000, slot: 'mortar:S', shellId: 'peony' },
                    ] } })
                    .expect(409);
                expect(res.body).toEqual({ error: 'INSUFFICIENT', needed: { firecracker: 1, peony: 2 }, held: { firecracker: 5, peony: 1 } });
                const after = await User.findOne({ robloxId: '911' });
                expect(after!.fireworks.get('firecracker')).toBe(5); // the firecracker was NOT taken
                expect(after!.fireworks.get('peony')).toBe(1);
            });

            it('refuses a mortar slot for a tier the player does not own, before debiting', async () => {
                await User.create({ robloxId: '912', mortars: ['mortar:S'], fireworks: { firecracker: 1, willow: 1 } });
                const res = await request(makeApp(makeEngine(), new ResultsStore()))
                    .post('/api/v1/players/912/shows/reserve')
                    .set('X-API-Key', API_KEY)
                    .send({ show: { stageId: 'deck:912', fuel: 'inventory', cues: [
                        { t_ms: 0, slot: 'hand', shellId: 'firecracker' },
                        { t_ms: 500, slot: 'mortar:M', shellId: 'willow' },
                    ] } })
                    .expect(409);
                expect(res.body).toEqual({ error: 'MORTAR_MISSING', slot: 'mortar:M' });
                const after = await User.findOne({ robloxId: '912' });
                expect(after!.fireworks.get('firecracker')).toBe(1);
            });

            it('refuses powder fuel, other stages, malformed shows and invalid cues with the validator code', async () => {
                await User.create({ robloxId: '913', fireworks: { firecracker: 1 } });
                const app = makeApp(makeEngine(), new ResultsStore());
                const post = (body: object) => request(app).post('/api/v1/players/913/shows/reserve').set('X-API-Key', API_KEY).send(body);
                expect((await post({ show: { stageId: 'deck:913', fuel: 'powder', cues: [{ t_ms: 0, slot: 'hand', shellId: 'firecracker' }] } }).expect(400)).body.error).toBe('FUEL_UNSUPPORTED');
                expect((await post({ show: { stageId: 'rooftop', fuel: 'inventory', cues: [{ t_ms: 0, slot: 'hand', shellId: 'firecracker' }] } }).expect(400)).body.error).toBe('BAD_STAGE');
                expect((await post({ show: { stageId: 'deck:999', fuel: 'inventory', cues: [{ t_ms: 0, slot: 'hand', shellId: 'firecracker' }] } }).expect(400)).body.error).toBe('BAD_STAGE');
                expect((await post({}).expect(400)).body.error).toBe('BAD_SHOW');
                const bad = (await post({ show: { stageId: 'deck:913', fuel: 'inventory', cues: [{ t_ms: 0, slot: 'hand', shellId: 'peony' }] } }).expect(400)).body;
                expect(bad).toEqual({ error: 'TIER_MISMATCH', cue: 0 });
                const after = await User.findOne({ robloxId: '913' });
                expect(after!.fireworks.get('firecracker')).toBe(1);
            });

            it('CONCURRENT RESERVES CANNOT OVERSPEND — one conditional update per reservation', async () => {
                await User.create({ robloxId: '914', fireworks: { firecracker: 1 } });
                const app = makeApp(makeEngine(), new ResultsStore());
                const body = { show: { stageId: 'deck:914', fuel: 'inventory', cues: [{ t_ms: 0, slot: 'hand', shellId: 'firecracker' }] } };
                const [a, b] = await Promise.all([
                    request(app).post('/api/v1/players/914/shows/reserve').set('X-API-Key', API_KEY).send(body),
                    request(app).post('/api/v1/players/914/shows/reserve').set('X-API-Key', API_KEY).send(body),
                ]);
                expect([a.status, b.status].sort()).toEqual([200, 409]);
                const after = await User.findOne({ robloxId: '914' });
                expect(after!.fireworks.get('firecracker')).toBe(0);
            });
        });
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd server && npx vitest run src/routes/apiV1.test.ts -t "shows/reserve"`
Expected: FAIL with 404s (route absent).

- [ ] **Step 3: Write the route**

Add to the imports at the top of `server/src/routes/apiV1.ts`:

```ts
import { validateShow, tallyShells, shellMortar, DECK_STAGE, Cue } from '../shows';
```

Insert after the `fireworks/spend` route:

```ts
    // A SHOW IS RESERVED BEFORE IT PLAYS (spec 2026-09-05-fireworks-show-system-design §2.1).
    // Everything the show needs is debited in ONE conditional update, so a show that cannot be
    // fully paid takes nothing — the same all-or-nothing the single-shell spend gets from its
    // conditional $inc, extended to a whole tally. Inventory fuel only here; powder is sub-project A.
    // Players may only reserve for their OWN deck (spec §3, decision 4); stations and the rooftop
    // arrive with consoles and tickets in sub-project C.
    router.post('/players/:robloxUserId/shows/reserve', async (req, res) => {
        try {
            const show = req.body?.show;
            if (typeof show !== 'object' || show === null) { res.status(400).json({ error: 'BAD_SHOW' }); return; }
            if (show.fuel !== 'inventory') { res.status(400).json({ error: 'FUEL_UNSUPPORTED' }); return; }
            if (show.stageId !== `deck:${req.params.robloxUserId}`) { res.status(400).json({ error: 'BAD_STAGE' }); return; }
            const check = validateShow(show.cues, DECK_STAGE);
            if (!check.ok) { res.status(400).json(check.cue === undefined ? { error: check.error } : { error: check.error, cue: check.cue }); return; }
            const cues = show.cues as Cue[];

            const user = await resolveUser({ robloxUserId: req.params.robloxUserId });
            if (!user) { res.status(404).json({ error: 'RESOLVE_FAILED' }); return; }

            // Gear is personal: a mortar slot in the show must be a tier this player owns. Checked
            // before the debit so a show that could never launch muzzle-true takes no shells.
            const owned = new Set(user.mortars ?? []);
            for (const c of cues) {
                if (c.slot.startsWith('mortar:') && !owned.has(c.slot)) {
                    res.status(409).json({ error: 'MORTAR_MISSING', slot: c.slot });
                    return;
                }
            }

            const needed = tallyShells(cues);
            const filter: Record<string, unknown> = { _id: user._id };
            const inc: Record<string, number> = {};
            for (const [id, n] of Object.entries(needed)) {
                filter[`fireworks.${id}`] = { $gte: n };
                inc[`fireworks.${id}`] = -n;
            }
            const updated = await User.findOneAndUpdate(filter, { $inc: inc }, { new: true });
            if (!updated) {
                const held: Record<string, number> = {};
                for (const id of Object.keys(needed)) held[id] = user.fireworks?.get(id) ?? 0;
                res.status(409).json({ error: 'INSUFFICIENT', needed, held });
                return;
            }
            const remaining: Record<string, number> = {};
            for (const id of Object.keys(needed)) remaining[id] = updated.fireworks.get(id) ?? 0;
            res.json({
                reservationId: Math.random().toString(36).slice(2, 12),
                stageId: show.stageId,
                cues,
                debited: needed,
                remaining,
            });
        } catch (err) {
            res.status(500).json({ error: (err as Error).message });
        }
    });
```

`shellMortar` is imported for the reviewer's benefit only if used; if the implementation above does not need it, drop it from the import (unused imports are not a type error here, but keep the import list honest).

- [ ] **Step 4: Run the route tests, then the whole server suite**

Run: `cd server && npx vitest run src/routes/apiV1.test.ts -t "shows/reserve" && npm test && npx tsc --noEmit`
Expected: PASS. If a route-count or mount-order test exists and fails because a route was added, read that test — it binds to `mountRoutes`, not to a count — and fix only if it genuinely asserts something this route breaks.

- [ ] **Step 5: Write the failing NetworkClient test**

`roblox/tests/NetworkClient.spec.luau` builds fakes with its local `makeDeps(script, opts)`, which returns `f` with `f.deps` (a full `Deps`) and `f.calls` (each `{ method, url, headers, body }`), and constructs clients as `NetworkClient.new(CONFIG, f.deps)`. Append, in that shape (copy the exact `Resp` script entry form the `postThrows` test uses for a 200 with a JSON body):

```lua
describe("NetworkClient.postShowReserve", function()
    test("POSTs the show under { show = ... } to the player's reserve route", function()
        local f = makeDeps({ { ok = true, statusCode = 200, body = '{"reservationId":"abc"}' } })
        local net = NetworkClient.new(CONFIG, f.deps)
        local show = { stageId = "deck:77", fuel = "inventory", cues = { { t_ms = 0, slot = "hand", shellId = "firecracker" } } }
        local res = net:postShowReserve("77", show)
        expect(res.ok).toBe(true)
        expect(res.data.reservationId).toBe("abc")
        expect(f.calls[1].method).toBe("POST")
        expect(f.calls[1].url).toBe("http://x/api/v1/players/77/shows/reserve")
        expect(f.calls[1].headers["Content-Type"]).toBe("application/json")
        expect(serde.decode("json", f.calls[1].body :: string).show.stageId).toBe("deck:77")
    end)
end)
```

- [ ] **Step 6: Run to verify it fails, implement, run again**

Run: `cd roblox && lune run tests/run 2>&1 | tail -3` — expected: the new test fails (`postShowReserve` is nil).

Add after `getFireworks` in `roblox/src/server/NetworkClient.luau`:

```lua
function NetworkClient.postShowReserve(self: any, robloxUserId: string, show: any): Result
    return self:_request("POST", `/api/v1/players/{robloxUserId}/shows/reserve`, { show = show })
end
```

Run: `cd roblox && lune run tests/run 2>&1 | tail -3 && stylua --check src tests tools && selene src tools` — expected: green and clean.

- [ ] **Step 7: Commit**

```bash
git add server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts roblox/src/server/NetworkClient.luau roblox/tests/NetworkClient.spec.luau
git commit -m "feat(shows): POST /shows/reserve debits a whole show in one conditional update, or nothing; NetworkClient.postShowReserve

Co-Authored-By: Claude Fable 5.1 <noreply@anthropic.com>"
```

---

