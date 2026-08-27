# Task 7 report

**Status:** Complete.

## Gates
- `stylua --check src tests tools` — clean (after auto-format; also fixed 3 selene warnings by hand)
- `selene src tools` — 0 errors, 0 warnings
- `lune run tests/run` — 949 passed, 0 failed (matches baseline; no controller in this task is
  test-covered, consistent with the brief's "no gate loads these files")

## `default.project.json`
Checked, did not assume: `StarterPlayerScripts.RoshamboClient` maps to `{ "$path": "src/client" }`
— a whole-directory `$path`, not a per-file listing. `SplashController.client.luau` is picked up
automatically; no project-file edit needed.

## `forfeited`
Available, via the same trick as `bankedNow`, but read from a different remote than the brief's
draft snippet implied. Server-side (`main.server.luau`'s `onReveal`), for a participating player,
`RevealResult:FireClient` fires and then — same tick, no yield — `fireProfile(player, "local")`
fires `ProfileUpdate`. Both are ordered, reliable RemoteEvent sends to the same client, so
`RevealResult` always lands first. So: the `RevealResult` handler stashes `roundId`/`result` into
`pendingReveal` as before; the `ProfileUpdate` handler, at its very top (mirroring `bankedNow`'s
own "read before overwrite" line), checks `p.source == "local" and pendingReveal and
pendingReveal.result == "LOSS"` and if so captures `wallet.pointsAtStake` — the PRE-reveal pot —
into `pendingReveal.forfeited` before overwriting the wallet. `maybeShowReveal` (the drum-rest
gate, ~3s later) reads `pendingReveal.forfeited` when it fires `EventBus.Splash`. `SplashController`
still defends against it being nil (`type(body.forfeited) == "number"`) and falls back to "your pot
is forfeited" with no figure, per the brief's "wrong number is worse than missing" instruction —
belt-and-braces should the ordering assumption ever not hold, though nothing in this codebase's
existing patterns (e.g. `RevealTheater` landing before the drum settles) suggests it wouldn't.

## Toast / data-flow
Removed `RevealResult`'s toast-headline construction (WIN/SAFE/LOSS emoji lines + the `R/P/S %`
distribution) entirely — no toast fires for a result any more. `r.distribution` and `r.totalPlayers`
are still captured into `pendingReveal` (new fields, currently unread by anything) with a comment
flagging them for Task 9's ledger LAST ROUND band, so the crowd-split/player-count data the old
toast carried is not orphaned. Whiff ("TOO LATE") and bank ("BANKED n") toasts are untouched.

## Splash gating (verified by reading, not by a gate)
- Fired only from `main.client.luau`'s `maybeShowReveal`, inside the `if p.result then` branch —
  never from the `RevealResult` handler directly.
- Cannot appear for a round the player didn't throw: `p.result` is nil whenever `reveal.results`
  has no entry for the player — confirmed in `RoundCoordinator.luau`, which excludes whiffed userIds
  from `results` entirely (`if not self._whiffed[userId] then results[userId] = ...`), and a
  spectator's `mine` is nil server-side the same way.
- `DisplayOrder = 30`, above the ledger/teahouse takeovers (20) and the minimal HUD (0).
- Nothing in `SplashController.client.luau` is a `TextButton`/has `MouseButton*`/sets `Active = true`
  (grepped) or puts a `UIStroke` on either `TextLabel` (only the backing `Frame` has one).
- Every local is declared before first use (top-to-bottom: constants → gui/backing/labels →
  fade-generation state → `copyFor` → the `EventBus.Splash` connection).

## Concerns
None. The one soft assumption (RemoteEvent fire-order preservation for two events queued in the
same server frame) is a very standard Roblox networking guarantee, and this codebase already leans
on it elsewhere (e.g. `RevealTheater` before `RevealResult`, both per-frame ordered fires).

## Coordinator review follow-up (same commit as the fixes)

1. **`0 points forfeited` taught nothing.** `copyFor`'s LOSS branch now has three cases, not two:
   `forfeited > 0` → `"{n} points forfeited"`; `forfeited == 0` → `"nothing was riding on that
   one"` (kept distinct from the nil case — zero is a KNOWN fact, nil is "unknown"); `forfeited ==
   nil` → the original figure-less `"your pot is forfeited"` fallback. Kept separate rather than
   folded, per the coordinator's "your call."
2. **`×{streak}` read as a multiplier.** Changed to `streak ×{streak} — pot is now {pot}`.
3. Added a comment at the `Onboard:Fire("win", ...)` call in `main.client.luau` explaining the
   splash and the win beat are deliberately NOT deduped (different regions, complementary
   copy, non-Active splash) — distinct from the bank case, which needed dedup because the toast
   and the card said the same sentence in the same place.

Gates re-run after the fix: stylua clean, selene 0/0/0, lune 949/0/949 (unchanged).
