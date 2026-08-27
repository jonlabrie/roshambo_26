# Task 9 report: The win gate on the Roblox server

## Summary

Implemented the server-authoritative win gate: a `WIN` binds a player (`unresolvedWin = true`)
until they answer RISK or BANK via the new `ResolveWin` remote; `SubmitPick` refuses throws while
bound. Also declared `SetHudPreference` (the shared remote for Task 12's escalation switch and
Task 13's beat-seen write) and added `NetworkClient:putHudPreference`, since this is the task that
owns `default.project.json`'s remotes folder.

## Files changed

- `roblox/default.project.json` — declared `ResolveWin` and `SetHudPreference` RemoteEvents,
  after `BankRequest`.
- `roblox/src/shared/PlayerProfiles.luau` — `Row` gains `unresolvedWin: boolean`; `applyServer`
  carries it through (`row.unresolvedWin or false`); `applyLocalResult` sets it optimistically
  (`result == "WIN"`).
- `roblox/src/server/NetworkClient.luau` — added `postResolveWin` (mirrors `postBank`) and
  `putHudPreference` (mirrors `setPreferences`).
- `roblox/src/server/main.server.luau` — declared the two new remotes; gated `SubmitPick` on
  `unresolvedWin`; added `ResolveWin` and `SetHudPreference` handlers; added `unresolvedWin` to
  `fireProfile`'s `ProfileUpdate` payload; threaded `unresolvedWin` through all four
  `profiles:applyServer` call sites (see below).
- `roblox/tests/PlayerProfiles.spec.luau` — extended (file already existed, broader coverage than
  the plan assumed — same situation Task 1 hit with `Glyphs.spec.luau`). Added the four win-gate
  tests from the brief verbatim, plus `unresolvedWin` fields to the pre-existing `SERVER_ROW` and
  `toEqual` fixtures so they stay accurate against the widened `Row` shape (see TDD evidence
  below — the old tests were not touched in intent, only widened to match the new field, since
  `toEqual` is a strict deep-equal in this harness and the field is now always present).
- `roblox/tests/NetworkClient.spec.luau` — added tests for `postResolveWin` and
  `putHudPreference`, mirroring the existing `postBank`/`setPreferences` blocks. Not required by
  the brief's Step 1 (which scoped TDD to `PlayerProfiles`), but added for parity: every other
  `NetworkClient` method in this file has direct coverage.

## TDD evidence (PlayerProfiles)

1. Added the four tests from the brief's Step 1 (plus widened the pre-existing fixtures — see
   above) to `roblox/tests/PlayerProfiles.spec.luau`.
2. Ran `lune run tests/run` before touching `PlayerProfiles.luau`. Failures matched the brief's
   prediction plus the fixture-widening fallout:

```
FAIL  PlayerProfiles > applyServer stores and get returns the wallet
      expected {...} to deep-equal {..., unresolvedWin=false}
FAIL  PlayerProfiles > local WIN grows the pot optimistically and bumps streaks
      expected {...} to deep-equal {..., unresolvedWin=true}
FAIL  PlayerProfiles > local SAFE preserves pot, resets streaks
      expected {...} to deep-equal {..., unresolvedWin=false}
FAIL  PlayerProfiles > local LOSS forfeits pot, resets streaks
      expected {...} to deep-equal {..., unresolvedWin=false}
FAIL  PlayerProfiles — the win gate > applyServer carries unresolvedWin
      expected nil to be true
FAIL  PlayerProfiles — the win gate > a local WIN raises the gate optimistically
      expected nil to be true
FAIL  PlayerProfiles — the win gate > a local LOSS clears it — nothing left to decide
      expected nil to be false
FAIL  PlayerProfiles — the win gate > a missing field defaults to unbound
      expected nil to be false
```

3. Implemented the `Row`/`applyServer`/`applyLocalResult` changes in `PlayerProfiles.luau`
   exactly as specified in the brief's Step 3.
4. Re-ran: all 8 `PlayerProfiles` tests pass; full suite `863 passed, 0 failed, 863 total` before
   the `NetworkClient` test additions, `867 passed, 0 failed, 867 total` after.

## `applyServer` call sites — what was passed for `unresolvedWin`

| Site (in `main.server.luau`) | Fed from | `unresolvedWin` passed |
|---|---|---|
| `onReconciled` callback (round-reconciliation loop, was `:309`, now `:316`) | `GET /instances/.../results` — round-result rows, **no** `unresolvedWin` field (confirmed by reading `server/src/routes/apiV1.ts:104-109`, which maps out `user` and returns only round-result fields) | Pass-through: `existing ~= nil and existing.unresolvedWin` where `existing = profiles:get(row.robloxUserId)` — the row's current cached value, not a default |
| `Players.PlayerAdded` join sync (was `:346`, now `:351`) | `GET /api/v1/players/:robloxUserId` — **does** carry `unresolvedWin` (confirmed: `buildProfilePayload` in `apiV1.ts:17-39` includes `unresolvedWin: user.unresolvedWin ?? false`) | `res.data.unresolvedWin` |
| `BankRequest` handler (was `:381`, now `:397`) | `POST /api/v1/bank` — **does not** carry `unresolvedWin` (confirmed: `apiV1.ts:326-331` response is `{ totalPoints, pointsAtStake, stakingStreak, currentStreak }` only) | Pass-through: `existing ~= nil and existing.unresolvedWin` where `existing = profiles:get(tostring(player.UserId))` |
| `ResolveWin` handler (new, `:412`) | `POST /api/v1/resolve-win` — **does** carry `unresolvedWin` (`apiV1.ts:351-357`) | `res.data.unresolvedWin` |

I read `server/src/routes/apiV1.ts` directly (not just the task-9 brief's context) to verify which
responses actually carry the field before writing each site, per the brief's warning #2 — the
`/bank` and `/instances/.../results` endpoints were the two that don't.

## Line-number drift from the brief

The brief was written against 2026-08-02 line numbers `:309`, `:346`, `:381`. Current file had
already grown (an unrelated `OnboardingBeats` commit landed between the brief being written and
this task starting); actual pre-edit lines were `:309` (unchanged), `:346`→ correct, `:381`→
correct — verified by reading each site directly rather than trusting the numbers, per warning #3.
Also note the brief's own two prior-app anchors (`SubmitPick` gate at `:365`, `applyServer` sites
at `:309`/`:346`/`:381`) matched what I found in the file before editing, so no drift actually
occurred this time — but I verified rather than assumed.

## Verification run (roblox/)

```
lune run tests/run                       -> 867 passed, 0 failed, 867 total
stylua --check src tests tools           -> initially 1 diff (test file formatting), fixed with
                                             `stylua src tests tools`, re-checked clean
selene src tools                          -> 0 errors, 0 warnings, 0 parse errors
```

## Self-review (fresh eyes)

- **Completeness**: all six brief steps done — remote declarations, `PlayerProfiles` extension,
  `NetworkClient` methods, `SubmitPick` gate, `ResolveWin`/`SetHudPreference` handlers,
  `fireProfile` payload, all four `applyServer` sites.
- **`HandlerQueue` usage**: `ResolveWin` reuses `handlerQueue:run` (serialises with `BankRequest`
  for the same player, per brief warning #5); `SetHudPreference` deliberately does not.
- **`SubmitPick` gate placement**: added after the existing `FATE_BOUND` check, before
  `coordinator:submitPick`, matching the brief's snippet and the file's existing pattern of
  early-return rejections with a `[PICK] ... rejected: REASON` log line.
- **YAGNI**: did not add a client-side handler for `ResolveWin`/`FateResolved`-style UI — that's
  explicitly Task 11's job (client dimming/painting) and Task 12/13 own `SetHudPreference`'s two
  senders. This task only had to make the gate real server-side and expose the two RPCs.
- **Test honesty**: the `NetworkClient` tests I added weren't demanded by the brief's TDD scope,
  but I wrote them fully spec'd (asserting method, URL, decoded request body, and both a success
  and a 400 fail-fast path) rather than smoke tests, matching the existing file's rigor.
- **Risk considered and rejected**: `SetHudPreference` is fire-and-forget (`task.spawn`, no
  `handlerQueue`, no response handling) exactly as the brief specifies — a dropped preference
  write is low-stakes and retried on the next toggle/beat, unlike money-moving writes.
- **Nothing found that needed a follow-up flag.**

## Fix round 1 (review finding)

**Finding (verbatim, from the updated brief):** the `ResolveWin` handler's `if res.ok then ... end`
had no `else` branch. Because `onReconciled` deliberately passes `unresolvedWin` through (correctly
— confirmed above) and `applyLocalResult` can never run for a gated player (they cannot throw), a
successful `postResolveWin` is the *only* in-session path that clears the gate. A failed request
(timeout, 500 `RESOLVE_FAILED`, dropped connection) left the player gated with nothing logged —
an undiagnosable lockout, recoverable only if Task 11's client happens to leave the overlay up for
a retry. The `PlayerAdded` sync handler right above already had the right shape
(`warn(\`[PROFILE] sync failed for {player.UserId}: {res.error or res.status}\`)`); `ResolveWin`
was missing its counterpart.

Two related findings were reviewed and explicitly **not** changed, per the coordinator's
instruction (both are logged as accepted/self-healing, not defects):
1. The gate fails *open* on a cache miss (`if prof and prof.unresolvedWin` — a nil `prof` does not
   block the throw). Intentional: a failed join-sync must not brick a session, and `Settlement.ts`
   rewrites the flag on the next settled round.
2. Local-reveal/server-settlement divergence (client shows SAFE/LOSS, backend settled a WIN) skips
   the prompt for one round and self-heals on reconciliation — inherent to the
   reveal-then-reconcile architecture, not something this task can or should fix.

**Fix applied** (`roblox/src/server/main.server.luau`, `ResolveWin.OnServerEvent` handler): added
an `else` branch that warns with the player name, the attempted choice, and the error/status:

```luau
        else
            -- A successful postResolveWin is the ONLY in-session path that clears the gate:
            -- onReconciled deliberately passes unresolvedWin through, and applyLocalResult
            -- cannot run for a gated player because they cannot throw. So a dropped request
            -- here leaves the player unable to play, and a silent failure makes that lockout
            -- undiagnosable. Mirrors the [PROFILE] sync warn above.
            warn(`[RESOLVE] {player.Name} failed ({choice}): {res.error or res.status}`)
        end
```

`BankRequest` was left exactly as-is (same silent shape, but not self-locking — changing it would
be scope creep per the coordinator's explicit instruction).

**Covering tests / gates re-run** (`roblox/`):

```
$ lune run tests/run
867 passed, 0 failed, 867 total

$ stylua --check src tests tools && selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

No new test was added for this specific `else` branch — it's a `warn()` call with no observable
state change that `PlayerProfiles`/`NetworkClient` unit tests can assert on, and there is no
existing integration harness in this suite that fakes `main.server.luau`'s remote wiring end-to-end
(none of the other handlers' warn-on-failure branches — e.g. `[PROFILE] sync failed`,
`[B2] purchase ... failed`, `[AC] setAccess ... failed` — have dedicated tests either; they're
covered by the same full suite run above staying green, i.e. by not breaking anything, not by
directly exercising the failure path). Flagging this rather than claiming coverage I don't have.

**Commit:** `bc0abcc` fix(roblox): warn on a failed ResolveWin — the only in-session unbinding path
