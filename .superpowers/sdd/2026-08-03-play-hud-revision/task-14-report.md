# Task 14 report — retire `confirmThrows`

**Status:** Complete.

**Scope note:** the brief listed 4 files, but `confirmThrows` was also live in
`roblox/src/server/main.server.luau` (HudPrefs type, prefsFor/prefsFromProfile defaults,
fireProfile payload, SetHudPreference handler) — required to satisfy the grep gate, so it
was cleaned too.

**Commit SHA:** (see below, committed after this report was written)

**Server suite:** `npm test` — 210/210 passed (13 files). TDD: added a failing pair in
`apiV1.test.ts` (5 failures observed pre-fix), then made them pass by deleting
`confirmThrows` from `buildProfilePayload`, the PUT accepted-keys block, and the PUT
response. Also updated 4 pre-existing assertions that expected the retired field.
`server/src/models/User.ts` and its `models.test.ts` were left untouched (schema field
stays inert, per instructions).

**Roblox suite:** `lune run tests/run` — 923/923 passed. `stylua --check src tests tools` —
clean. `selene src tools` — 0 errors/warnings (this also confirms no unused locals/requires
survived the deletions).

**Single-switch layout decision:** the footer's `makePrefSwitch` was column-indexed
(`x = column * PREF_COL_W`, left-anchored at x=0). With `confirmSwitch` gone, I removed the
`column` parameter and re-anchored the remaining label+switch block from the footer's
horizontal centre (`UDim2.new(0.5, -PREF_BLOCK_W/2, ...)`), so the pair reads as one
centred unit at any footer width rather than a control stranded in the left half.

**Switch trace (escalationPrompts, unaffected by this task but verified intact):**
tap → `LedgerController` toggles local state, paints, fires
`EventBus.HudPreference{escalationPrompts}` → `main.client.luau` applies it locally and
`SetHudPreference:FireServer` → `main.server.luau` merges into `hudPrefs` and
`net:putHudPreference` → `apiV1.ts` PUT persists and echoes → on success the local/server
state already matches (optimistic); on failure the server reverts and re-fires
`ProfileUpdate` → `main.client.luau` updates `escalationPrompts` and calls `publishLedger()`
→ `EventBus.LedgerState` → `LedgerController` repaints via `paintSwitch()`. Confirmed by
code read, not a live Studio session.

**Grep result:**
```
grep -rn "confirmThrows" roblox/src server/src
```
Matches: `server/src/models/User.ts` (field kept, per instructions), `server/src/models/models.test.ts`
(pre-existing test of that untouched schema field), and `server/src/routes/apiV1.test.ts`
(this task's new/updated tests, which necessarily name the retired key to test its
retirement, e.g. `describe('... — confirmThrows is retired')`). No occurrences remain in
any production code path (`roblox/src`, `server/src/routes/apiV1.ts`,
`server/src/routes/*.ts` other than the test file).

**Concerns:** none outstanding. The stricter literal reading of the grep gate ("only
User.ts") is unsatisfiable simultaneously with Step 1's requirement that the new tests name
`confirmThrows` — I judged the test-file matches as intended and documented them rather than
obscuring the string.
