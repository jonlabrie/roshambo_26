# Task 7B report — numbers count rather than jump

## What was built

**`roblox/src/shared/RollingNumber.luau`** (new) — pure module, no Roblox globals, requires
nothing. `RollingNumber.DURATION = 0.5` (roughly half a second, decelerating, per spec).
`RollingNumber.valueAt(from, to, t): number` — `t` is elapsed fraction, clamps to `[0, 1]`
rather than extrapolating, eases out via quadratic `1 - (1-t)^2` (monotonic and bounded to
exactly `[0, 1]` over `t ∈ [0, 1]`, so the interpolated value can never overshoot `to` by
construction — not a spring, nothing that could ring past the target), and rounds to an
integer with `math.round`. Endpoints are exact: at `t = 0`, `easeOut(0) = 0` so the result is
`from + 0` before rounding; at `t ≥ 1` (clamped), `easeOut(1) = 1` so the result is
`from + (to - from) = to` before rounding — both exact under IEEE754 since multiplying by 0 or
1 introduces no error, and rounding an already-integer value returns it unchanged.

**`roblox/tests/RollingNumber.spec.luau`** (new) — written and run to confirm failure (module
didn't exist yet: `error requiring module "../src/shared/RollingNumber"`) before implementing.
12 tests: `t=0`/`t=1` pinned exactly (ascending and descending pairs), `t` beyond `[0,1]` clamps
both directions, never-overshoots ascending and descending, monotonic ascending and descending
(40 samples each), `from == to` constant across 7 values including negative/large `t`, always-
integer over both directions, and `DURATION` is a positive number.

**`roblox/src/client/HudController.client.luau`** (modified):

- New `Counter` type + `newCounter`/`tickCounter` (before the plate section): `tickCounter(c,
  target)` only resets `c.from`/`c.startedAt` when `target ~= c.target` — i.e., keyed on the
  target actually changing, not on how often it's called. `c.from` is set from `c.displayed`
  (the currently-shown value), not from the old target, so a second change mid-count continues
  from where the number visibly is rather than snapping back. Once `t >= 1`, `startedAt` clears
  to `nil` so further calls at the same target are free (no tween restarted, no state churn) —
  this is the same failure class the bank pulse hit earlier in this branch, avoided the same way
  `setBank`'s own pulse guard avoids it.
- Three counters: `pointsCounter`, `streakCounter`, `potCounter`.
- `render()`: `plateLabel.Text` now built from `tickCounter(pointsCounter, view.plate.points)`
  and `tickCounter(streakCounter, view.plate.streak)` — the *displayed* figures, not the
  model's. The streak's "×N" segment condition (`displayedStreak > 0`) also uses the displayed
  value, so a streak reset to 0 counts down in view instead of vanishing on the tick it resets.
  The reveal change-guard (7A) still compares the *model* values
  (`view.plate.points`/`streak` against `lastPlatePoints`/`lastPlateStreak`), which is correct
  and untouched — the reveal is about a real wallet event happening, not about per-tick display
  churn during a count.
- `render()`: `setBank(view.pot > 0 or displayedPot > 0, displayedPot, view.potPulses)` replaces
  `setBank(view.bankVisible, view.pot, view.potPulses)`. Visibility now follows the *displayed*
  pot, with `view.pot > 0` included so the button appears on the very first tick a pot exists
  even though the display itself still reads exactly `0` for that one frame
  (`RollingNumber.valueAt`'s `t=0 → from` guarantee).
- `setBank`'s doc comment updated to record that `pulses` (`view.potPulses`) is still model-
  driven, and why that's correct rather than a gap — see the pulse analysis below.

## Step 3 in detail — the bank button surviving its own count-down

`view.bankVisible` is no longer read in `render()` at all. The new condition,
`view.pot > 0 or displayedPot > 0`:

- **Pot appearing** (a first win, `pointsAtStake` `0 → n`): `view.pot = n > 0` makes the button
  visible on the very same tick, even though `displayedPot` is still `0` for that one frame —
  the OR-clause covers the gap the `t=0` exactness would otherwise open.
- **Pot draining** (a bank or a loss, `pointsAtStake` `n → 0`): `view.pot` becomes `0`
  *instantly*, but `displayedPot` is still counting down from `n`, so `displayedPot > 0` keeps
  the button visible for the full 0.5s count. The button hides only on the tick `displayedPot`
  actually reaches `0` — exactly the requirement, and exactly why the model's `bankVisible` was
  wrong to drive this: it would have hidden the button before the count anyone was meant to see
  had even started.

**The pulse guard.** `potPulses` (`view.potPulses`) is still **model**-driven, deliberately not
switched to a displayed-based signal — and I traced why that's correct rather than a gap the
coordinator's message was warning about: `HudModel.view` computes
`potPulses = inputs.pointsAtStake > 0 and inputs.unresolvedWin`, so the moment `pointsAtStake`
drops to `0` (a bank or a loss), `potPulses` goes `false` on that *exact* same tick — before the
display has counted down at all. `setBank`'s own guard is `want = visible and pulses`, so `want`
already goes `false` at the instant the model changes, regardless of how long `visible` stays
`true` afterward for the count-down. A button lingering at a nonzero *displayed* pot during a
bank/loss drain is therefore never left pulsing — `pulses` dropped out from under it on the same
tick the model changed, not on whatever tick the display later catches up. No fight between the
two properties: `BackgroundTransparency` (pulse) and `Text` (count) are driven by genuinely
independent signals that happen to both derive from the same `ProfileUpdate`, and the guard that
already existed (`want == pulsing` early-return) needed no change.

## The plate's reveal vs. the count — checked, no conflict

`RollingNumber.DURATION = 0.5` vs. `PLATE_HOLD = 2` (`HudController.client.luau`): **the count
finishes in a fifth of the hold window**, 1.5s before any fade could begin. A reveal and a count
always start on the same render tick (both are triggered by the same model-value change), so the
line is always still fully opaque — never mid-fade — by the time the number finishes moving.
If a second wallet change lands mid-hold, `revealPlate()` resets the full 2s hold again (per
7A), so the 0.5s count is comfortably inside whatever hold window is currently active; the two
mechanisms never race.

## The three scenarios, traced end to end

All three are driven by the exact same `ProfileUpdate` → `publish()` → `HudModel.view()` →
`render()` path, with no special-casing for "this one's a bank" anywhere in `HudController` —
confirming the design's core claim ("it falls out of one rule").

- **BANK** (pot 27 → 0, points 900 → 927, streak unchanged): `potCounter` counts **down**
  27→0 while `pointsCounter` counts **up** 900→927, both over the same 0.5s from the same
  `ProfileUpdate` — the pot figure drains on the bank button while the balance climbs on the
  plate line, in opposite directions at the same moment. The plate reveals (points changed).
  The bank button stays visible through the full drain, not pulsing (`unresolvedWin` already
  cleared), and hides the instant `displayedPot` hits exactly `0`.
- **LOSS** (pot 27 → 0 forfeited, points unchanged, streak N → 0): `potCounter` counts down
  27→0 exactly as in a bank — the button drains and disappears the same way — but
  `pointsCounter`'s target is unchanged, so the balance never moves: no transfer, a pure
  forfeit, visibly distinct from the bank case by what *doesn't* animate. `streakCounter`
  counts down N→0 in the plate's "×N" segment (reveals the plate if the streak was nonzero),
  which then drops off the line once it reaches 0.
- **WIN** (pot triples in place, e.g. 9 → 27, or 0 → 1 on a first win; points unchanged;
  streak N → N+1): `potCounter` counts **up** on the bank button while the balance stays put
  (the winnings are still at stake, not banked) — the pulse (`unresolvedWin = true`) runs
  concurrently with the count, on the independent `BackgroundTransparency` property. The plate
  reveals and `streakCounter` counts up by one.

## Reconciliation — `HudLayout.X` and `view.X`

**`HudLayout.X`**: unchanged from the 7A pass — this task added no new `HudLayout` reads.
Reads: `JUMP_CLEARANCE, EDGE, BTN_H_TOUCH, BTN_H, TILE_TOUCH, TILE, ROW_GAP, AREA_H_TOUCH,
AREA_H, BANK_H` (all exported; verified by grep pair, all resolve).

**`view.X`**: `view.throwsEnabled`, `view.plate.points`, `view.plate.streak`, `view.pot`
(now read twice — inside the `tickCounter` call and again in the `view.pot > 0 or ...`
visibility check), `view.potPulses`, `view.selected` (pre-existing stale field, unchanged,
still Task 8's scope — degrades to `nil`, not an error), `view.escalate`, `view.secondsLeft`.
`view.bankVisible` is **no longer read** — deliberately, replaced by the displayed-based check
above; it's still exported by `HudModel.view()` (unused fields aren't an error). All reads
resolve against `HudModel.View`'s actual shape (`plate{streak,points}`, `throwsEnabled`,
`bankVisible`, `pot`, `potPulses`, `escalate`, `secondsLeft`, `chosen`, `switchPrompt`).

## Gates

- `stylua --check src tests tools` — clean.
- `selene src tools` — 0 errors, 0 warnings, 0 parse errors.
- `lune run tests/run` — **919 passed, 0 failed** (907 before this task, +12 for
  `RollingNumber.spec.luau`; unrelated `HandlerQueue.spec` `[WARN]` queue-full/handler-error
  lines are pre-existing chaos-test noise, not failures).
