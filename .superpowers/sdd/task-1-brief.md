### Task 1: Express `/state` publishes phase durations

**Files:**
- Modify: `server/src/engine/RoundEngine.ts` (add `durationsMs()` after `snapshot()`, ~line 60)
- Modify: `server/src/routes/apiV1.ts` (the `/state` handler, ~line 19)
- Test: `server/src/routes/apiV1.test.ts` (the `GET /state` describe, ~line 43)

**Interfaces:**
- Produces: `GET /api/v1/state` body gains `durations: { activeMs: number, tallyMs: number, revealMs: number }`. `RoundEngine.durationsMs(): { activeMs, tallyMs, revealMs }`. Task 2's fake `/state` payloads mirror this shape.

- [ ] **Step 1: Write the failing test**

In `server/src/routes/apiV1.test.ts`, inside `describe('GET /state', ...)` add:

```ts
it('states its phase durations (round-metronome schedule source)', async () => {
    const res = await request(makeApp(makeEngine(), new ResultsStore()))
        .get('/api/v1/state').set('X-API-Key', API_KEY).expect(200);
    expect(res.body.durations).toEqual({ activeMs: 20000, tallyMs: 2000, revealMs: 3000 });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run (from `server/`): `npx vitest run src/routes/apiV1.test.ts -t "phase durations"`
Expected: FAIL — `expected undefined to deeply equal { activeMs: 20000, ... }`

- [ ] **Step 3: Implement**

In `server/src/engine/RoundEngine.ts`, after the `snapshot()` method:

```ts
    durationsMs(): { activeMs: number; tallyMs: number; revealMs: number } {
        return {
            activeMs: this.cfg.activeSeconds * 1000,
            tallyMs: this.cfg.tallySeconds * 1000,
            revealMs: this.cfg.revealSeconds * 1000,
        };
    }
```

In `server/src/routes/apiV1.ts`, add one field to the `/state` response object (after `serverTime: now,`):

```ts
            durations: engine.durationsMs(),
```

- [ ] **Step 4: Run the server suite**

Run: `npm test`
Expected: all Vitest suites PASS (13 files, 189+ tests).

- [ ] **Step 5: Commit**

```bash
git add server/src/engine/RoundEngine.ts server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "feat(server): /state publishes phase durations for the round metronome"
```

---

