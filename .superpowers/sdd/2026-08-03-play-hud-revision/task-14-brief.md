### Task 14: Retire `confirmThrows`

**Files:**
- Modify: `roblox/src/client/LedgerController.client.luau`
- Modify: `roblox/src/client/main.client.luau`
- Modify: `server/src/routes/apiV1.ts`
- Test: `server/src/routes/apiV1.test.ts`

- [ ] **Step 1: Write the failing server test**

In `server/src/routes/apiV1.test.ts`, add:

```ts
describe('PUT /players/:id/preferences-hud — confirmThrows is retired', () => {
    it('ignores a confirmThrows key rather than persisting it', async () => {
        const res = await request(app)
            .put(`/api/v1/players/${robloxId}/preferences-hud`)
            .set('X-API-Key', API_KEY)
            .send({ confirmThrows: false, escalationPrompts: false });
        expect(res.status).toBe(200);
        expect(res.body).not.toHaveProperty('confirmThrows');
        expect(res.body.escalationPrompts).toBe(false);
    });

    it('does not ship confirmThrows in the profile payload', async () => {
        const res = await request(app)
            .get(`/api/v1/players/${robloxId}`)
            .set('X-API-Key', API_KEY);
        expect(res.body).not.toHaveProperty('confirmThrows');
    });
});
```

Match the existing file's setup helpers rather than the placeholder names above — read the
tests already in it and reuse their app/auth/fixture scaffolding.

- [ ] **Step 2: Run to verify it fails**

Run from `server/`: `npm test`
Expected: FAIL — `confirmThrows` is present in both payloads.

- [ ] **Step 3: Retire it server-side**

In `server/src/routes/apiV1.ts` delete line 26 (`confirmThrows: user.confirmThrows ?? true`),
the `if (typeof req.body?.confirmThrows === 'boolean')` block at :140–141, and
`confirmThrows: s.confirmThrows ?? true` at :158.

**Leave `server/src/models/User.ts` alone.** The Mongo field stays — dropping it needs a
migration and buys nothing, and a defaulted field nobody reads is inert.

- [ ] **Step 4: Retire it client-side**

In `LedgerController`: delete `confirmSwitch` and its construction, `local confirmThrows = true`,
the `paintOne(confirmSwitch, confirmThrows)` line, the `confirmSwitch` click handler, and the
`state.confirmThrows` branch in the `LedgerState` handler. The footer is now one switch —
check the two-column layout still reads with a single occupant and centre it if not.

In `main.client.luau`: delete `local confirmThrows = true`, the `body.confirmThrows` branch in
the `HudPreference` handler, the `p.confirmThrows` branch in `ProfileUpdate`, and
`confirmThrows = confirmThrows` from `publishLedger`.

- [ ] **Step 5: Run both suites and commit**

```bash
cd server && npm test
cd ../roblox && lune run tests/run && stylua src tests tools && selene src tools
grep -rn "confirmThrows" src/ ../server/src/routes/
```
Expected: no matches outside `server/src/models/User.ts`.

```bash
git add roblox/src/client/LedgerController.client.luau roblox/src/client/main.client.luau server/src/routes/apiV1.ts server/src/routes/apiV1.test.ts
git commit -m "refactor: retire the preference that guarded a confirmation that no longer exists"
```

---

## Final verification

Before the branch is done, from the repo root:

```bash
cd roblox && lune run tests/run && stylua --check src tests tools && selene src tools
cd ../server && npm test
cd .. && git status --porcelain
```

All four must be clean. Then push — the App Runner dev service auto-deploys the working
branch, so Studio picks up the server half a few minutes later.

## The owner's Studio gate

Nothing in this plan can verify:

1. whether the dimmed unchosen glyphs read as "almost disappeared" at 0.75/0.7
2. whether `SWITCH?` is legible at 13px on a 44px button
3. whether the plate clears the jump button on a real phone (it measures, but the measurement
   is only as good as `TouchControlFrame` being where we look for it)
4. whether one switch alone reads correctly in the preferences footer

---

## AMENDMENT (2026-08-03, mid-execution) — the plate moves again, and numbers count

The owner superseded the right-margin placement after Task 7 had landed, and added a behaviour
the plan did not have. Task 7's committed work (`df7bb80`, `781eb41`) is partly superseded:
the ledger `≡` button **stays**, the plate's inertness **stays**, its placement and the whole
jump-button measurement **go**.

Spec: `2026-08-03-play-hud-revision-design.md` §2, sections "The player-state plate moves to the
bottom row, and is normally hidden" and "Numbers count rather than jump".

