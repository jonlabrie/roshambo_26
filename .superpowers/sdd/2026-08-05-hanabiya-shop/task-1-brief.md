### Task 1: The catalog carries shell and mortar prices

Closes spec §6a. `EconomyState.catalog` sends `PRICES` from `economy.ts`; `SHELL_PRICES` and `MORTAR_PRICES` live in `fireworks.ts` and reach nobody, so a panel would have to hardcode them.

**Files:**
- Modify: `server/src/routes/apiV1.ts` (the `/economy` route's `catalog` field, ~line 226)
- Test: `server/src/routes/apiV1.test.ts`

**Interfaces:**
- Consumes: `SHELL_PRICES`, `MORTAR_PRICES` from `server/src/fireworks.ts`.
- Produces: `GET /api/v1/players/:id/economy` → `catalog.fireworks: Record<string, number>` and `catalog.mortars: Record<string, number>`.

- [ ] **Step 1: Write the failing test**

Add inside the existing `describe('fireworks', ...)` block in `server/src/routes/apiV1.test.ts`:

```typescript
        it('the economy catalog carries shell and mortar prices', async () => {
            // Without this the shop panel has to hardcode prices, which is the defect class
            // this project has already hit three times: a number authoritative on the server,
            // re-derived client-side, going stale.
            await User.create({ robloxId: '907', totalPoints: 0 });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/players/907/economy')
                .set('X-API-Key', API_KEY)
                .expect(200);
            expect(res.body.catalog.fireworks).toEqual({
                firecracker: 1,
                peony: 3,
                willow: 4,
                ishibana: 6,
            });
            expect(res.body.catalog.mortars).toEqual({
                'mortar:S': 40,
                'mortar:M': 250,
                'mortar:L': 1000,
            });
        });

        it('every sellable shell has a catalogued price', async () => {
            // The gate that matters: a shell added to SHELL_IDS but not to the payload would
            // render in the shop with a blank price.
            await User.create({ robloxId: '908', totalPoints: 0 });
            const res = await request(makeApp(makeEngine(), new ResultsStore()))
                .get('/api/v1/players/908/economy')
                .set('X-API-Key', API_KEY)
                .expect(200);
            for (const id of SHELL_IDS) {
                expect(typeof res.body.catalog.fireworks[id]).toBe('number');
            }
        });
```

Add `SHELL_IDS` to the file's imports from `../fireworks` (the file already imports nothing from it; add a new import line beside the others at the top):

```typescript
import { SHELL_IDS } from '../fireworks';
```

- [ ] **Step 2: Run the tests to verify they fail**

Run from `server/`: `npx vitest run src/routes/apiV1.test.ts`

Expected: FAIL — `catalog.fireworks` is `undefined`.

- [ ] **Step 3: Extend the payload**

In `server/src/routes/apiV1.ts`, add to the imports beside the existing `fireworks` import:

```typescript
import { shellStates, SHELL_IDS, LaunchContext, SHELL_PRICES, MORTAR_PRICES } from '../fireworks';
```

(That line already exists importing the first three — replace it with this one rather than adding a second import from the same module.)

Then in the `/players/:robloxUserId/economy` route, replace `catalog: PRICES,` with:

```typescript
                // The client is told PRICES, never requirements. Shells and mortars live in
                // fireworks.ts rather than economy.ts, so they have to be spliced in here — the
                // alternative is a second copy of every price in the Roblox client.
                catalog: { ...PRICES, fireworks: SHELL_PRICES, mortars: MORTAR_PRICES },
```

- [ ] **Step 4: Run the tests to verify they pass**

Run from `server/`: `npx vitest run src/routes/apiV1.test.ts`

Expected: PASS.

- [ ] **Step 5: Verify the gate by mutation**

Temporarily delete the `ishibana: 6,` line from `SHELL_PRICES` in `server/src/fireworks.ts` and re-run.

Expected: the "every sellable shell has a catalogued price" test FAILS. If it passes, the gate is decoration. **Restore the line before continuing.**

- [ ] **Step 6: Run the full suite and commit**

```bash
cd server && npm test && npm run build && cd ..
git add server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "feat(server): the economy catalog carries shell and mortar prices"
```

---

