# Task 8 report: `resultSplash`, the second preference

**Status:** complete.

**Commit:** `ad735af` — "feat: the result splash is a preference, not a fixture"

**Suites:**
- `server/`: `npm test` — 211 passed (13 files), up from 210 (one new independence test).
- `roblox/`: `lune run tests/run` — 949 passed, 0 failed (unchanged count — main.server.luau/
  main.client.luau are runtime-only, not exercised by the Lune harness).
- `stylua --check src tests tools` — clean. `selene src tools` — 0 errors, 0 warnings.

**All six seams carry `resultSplash`:**
1. `server/src/models/User.ts` — `resultSplash: { type: Boolean, default: true }` (+ IUser field,
   + `models.test.ts` default assertion).
2. `server/src/routes/apiV1.ts` — `buildProfilePayload` ships `resultSplash ?? true`; the PUT
   accepts `req.body.resultSplash` into `set` and echoes it in the response.
3. `roblox/src/server/main.server.luau` — `HudPrefs` type, `prefsFor`'s default row,
   `prefsFromProfile`, `fireProfile`'s payload, and `SetHudPreference`'s merge-clone-overwrite logic
   all carry `resultSplash` beside `escalationPrompts`.
4. `roblox/src/client/main.client.luau` — local `resultSplash` (default true), applied from
   `EventBus.HudPreference` and from `ProfileUpdate`, included in `publishLedger()`.
5. `roblox/src/client/LedgerController.client.luau` — `makePrefSwitch`'s `column` argument restored
   (`PREF_COL_W`, columns 0/1); second switch `resultSplashSwitch` built, painted, click-handled,
   and read from `LedgerState`.
6. `roblox/src/client/SplashController.client.luau` — new `EventBus.LedgerState` subscription sets a
   local `resultSplash` (default true); `EventBus.Splash`'s handler returns early when it is false.

**Independent round-trip trace:**
Toggle `resultSplash` off in the ledger footer → `EventBus.HudPreference:Fire({resultSplash=false})`
(body carries only the changed key) → `main.client.luau` updates its local `resultSplash` and
forwards the same partial body to `SetHudPreference:FireServer` → server's handler clones
`prefsFor(uid)` and overwrites only `resultSplash`, leaving the cloned `escalationPrompts` intact →
`net:putHudPreference` PUTs `{resultSplash:false}` only, so Mongo's `$set` never touches
`escalationPrompts` → next `fireProfile` (any ProfileUpdate — reveal, ledger refresh, or a revert)
reads `prefsFor(uid)` and emits **both** keys, `escalationPrompts:true, resultSplash:false` →
client's `ProfileUpdate` handler sets both locals independently and calls `publishLedger()`, which
fires `LedgerState` with both → `LedgerController` paints both switches correctly (escalation ON,
splash OFF) and `SplashController` — which never reads `escalationPrompts` at all — stops showing
splashes. The reverse (toggling `escalationPrompts`) is symmetric. Verified in code for every hop;
server-side independence is also asserted by
`apiV1.test.ts`'s "sets resultSplash independently of escalationPrompts" (mirrors the retired
`confirmThrows` test) and the existing "sets escalationPrompts" test now asserts the full
`{escalationPrompts, resultSplash, seenBeats}` response shape.

**Concerns:** none. `main.client.luau` still has no `Instance.new`; no `UIStroke` was added to a
`TextLabel` (SplashController's stroke stays on the `backing` Frame, unchanged).

## Follow-up: merge rule extracted to a testable module

**Commit:** `dea15b8` — "fix(roblox): extract HudPrefs.merge so the two-key merge rule is testable"

Reviewer's adversarial check: replacing `SetHudPreference`'s merge base with a hardcoded
`{escalationPrompts=true, resultSplash=true}` literal (discarding `current`, the exact
one-switch-resets-the-other bug) passed both suites unchanged, because the merge lived inline in
`main.server.luau` — a Roblox-runtime file Lune never loads.

Fix: new `roblox/src/shared/HudPrefs.luau` (pure, no Roblox globals) exporting `DEFAULTS`,
`merge(current, patch)` (new table, only boolean-valued keys present in `patch` overwrite
`current`; never mutates `current`), and `fromProfile(data)` (the `~= false` defaulting).
`roblox/tests/HudPrefs.spec.luau` written first (red — module didn't exist), 9 tests covering the
sabotage case, its mirror, empty-patch no-op, non-boolean-ignored, no-mutation, and
`fromProfile`'s defaulting. `main.server.luau`'s `prefsFor`, the two `prefsFromProfile` call
sites, and the `SetHudPreference` merge now all call the module.

**Sabotage re-run:** reverting `merge` to the current-discarding literal failed 4 of 958 Luau
tests (954 passed); reverted back to 958/958.

**Suites after the fix:** `roblox/`: `lune run tests/run` — 958 passed, 0 failed (949 + 9 new);
`stylua --check src tests tools` clean; `selene src tools` — 0 errors, 0 warnings. `server/`:
`npm test` — 211 passed, unchanged (this fix is Roblox-only).
