# Task 3 report — the counters leave the heartbeat

One file changed: `roblox/src/client/HudController.client.luau`.

## What changed

**Step 1 — per-leg duration.**
- `Counter` gained `duration: number` with the brief's comment verbatim (file lines 240–243).
- `newCounter` initialises it to `RollingNumber.MIN_DURATION`; the return table was expanded to
  multi-line (stylua's own choice at that width), lines 245–253.
- `tickCounter` sets `c.duration = RollingNumber.durationFor(target - c.from)` inside the
  target-changed branch (line 256), and the elapsed-fraction line now divides by `c.duration`
  (line 259). The assignment sits AFTER `c.from = c.displayed`, so the delta measured is the
  actual leg about to be travelled, not the stale one.

**Step 2 — the paint extracted, plus the per-frame driver.**
- `local RunService = game:GetService("RunService")` added at line 42, alphabetically between
  `ReplicatedStorage` (41) and `TweenService` (43).
- The whole block from the brief inserted immediately after `setBank`'s `end` and before the
  "hamburger is gone" note: target mirrors (924–925), `countersAnimating` (927–929),
  `paintCounters` (938–953), the `RenderStepped` connection (964–968). Ordering inside the
  connection is `if countersAnimating() then paintCounters() end` — test before paint, as
  instructed, so the frame that lands the exact value still paints.

**Step 3 — render rewired.** The inline `tickCounter`/`plateLabel.Text`/`setBank` block became the
five lines at 1386–1390. `bankArmed = view.pot > 0` and its comment are untouched at 1391–1394.

**Comments preserved, not deleted.** Both comments that explained the inline block moved up:
- The "label shows the DISPLAYED figures … streak counts down rather than vanishing" paragraph is
  now the tail of `paintCounters`'s own header (lines 934–936).
- The bank-visibility paragraph is now inside `paintCounters` above the pot tick (944–949),
  rewritten to the brief's wording and with the `RollingNumber.valueAt` exact-`from`-at-`t=0`
  citation from the original kept.
- The counting-section header (211–224) had two now-false claims and was corrected in place: it
  pointed at "`render`, below, where all three counters are ticked from the one `view`" (now
  `paintCounters`), and said `tickCounter` is called at 10Hz (now: 10Hz from `render` AND frame
  rate from the driver). Its warning about restarting the count every call is unchanged and is
  more load-bearing now than it was.

Nothing's `Active` was touched; `undoPill` remains `Active = false` (never assigned; a Frame's
default, as the comment at its declaration insists).

## Gate output

```
979 passed, 0 failed, 979 total     (lune run tests/run)
stylua --check src tests tools      -> clean
selene src tools                    -> 0 errors, 0 warnings, 0 parse errors
```

As the task framing warned, none of these load a `.client.luau`, so the standing check below is
the real gate.

## Standing check, item by item

1. **`paintCounters` declared after everything it uses, before `render` calls it.**
   - `tickCounter` — 251
   - `pointsCounter` / `streakCounter` / `potCounter` — 270 / 271 / 272
   - `plateLabel` — 348 (`Instance.new`)
   - `setBank` — 895
   - `paintCounters` — **938**
   - `render` — 1369, its `paintCounters()` call — **1390**
   Every dependency is above 938; the only call site outside the module body is below it.
2. **Target mirrors above `paintCounters`.** `counterPoints, counterStreak, counterPot` — 924;
   `counterPulses` — 925. Both above 938. `countersAnimating` (927) also precedes its use at 965.
3. **`RunService` required** — line 42.
4. **No reference to the deleted constant.** Two greps:
   - `grep -rn "RollingNumber\." src tests` returns only `MIN_DURATION`, `MAX_DURATION`,
     `SCALE_CAP`, `durationFor`, `valueAt` (plus one occurrence inside a comment at
     `HudController.client.luau:949` citing `RollingNumber.valueAt`). No `DURATION` bare.
   - `grep -rnF 'RollingNumber.DURATION' src tests` → **no output, exit 1**.
   In `HudController.client.luau` the surviving references are exactly lines 247
   (`RollingNumber.MIN_DURATION`), 256 (`durationFor`) and 260 (`valueAt`).
5. **`render` no longer paints directly.** `grep -n "plateLabel.Text\|setBank(" ` finds
   `plateLabel.Text` only at 343 (the initial `"0"` at construction) and 941 (inside
   `paintCounters`); `setBank(` is called only at 952, inside `paintCounters`. Neither appears
   anywhere in `render`'s body (1369–end).

## `setBank` under frame-rate calls — verdict: the guard holds

Read in full at 895–919. Its body in order:

```lua
bankButton.Visible = visible
if visible then bankButton.Text = `BANK {pot} POINTS` end
local want = visible and pulses
if want == pulsing then return end     -- <- the guard, BEFORE any tween is touched
pulsing = want
if potPulse then potPulse:Cancel() ... end
if want then ...Create(...):Play() ... end
```

The guard is positioned correctly for this change: it returns **before** `potPulse:Cancel()` and
before any `TweenService:Create`. So a frame-rate call whose `(visible, pulses)` pair is unchanged
touches the tween not at all. The only per-call work is two plain property writes (`Visible`,
`Text`) — assignments, not animations, and re-writing an unchanged value on a Roblox instance is
idempotent and fires no `Changed`.

The one case worth checking is the bank itself, because that is precisely when this function will
now be called at 60Hz rather than 10Hz: on the tick the bank lands, the model's `potPulses` goes
false (it is gated on `pointsAtStake > 0`) at the same instant `view.pot` goes 0. `want` flips
false exactly once, on the first `render` after the bank; the tween is cancelled once and
`BackgroundTransparency` restored once. Every subsequent frame of the ~2.2s drain — all of which
now run through the `RenderStepped` driver with `counterPulses` frozen at `false` and `visible`
still true — hits `want == pulsing` and returns immediately. There is no per-frame cancel/restart
anywhere in the new path.

Note also that `counterPulses` is only ever written by `render`, so the driver cannot introduce a
pulse-state change of its own between heartbeats; it re-passes whatever `render` last decided.
This is the property that makes the guard sufficient rather than merely lucky.

**Conclusion: no workaround was needed and none was applied.** The failure mode the constraint
warned about (the `setBank` pulse regression earlier in this branch) does not recur, because that
bug was a cancel-and-restart placed *above* a guard, and this one is below it.

## Concerns

1. **`plateLabel.Text` now churns at frame rate during a count.** It is a single string assignment
   per frame on one TextLabel with `AutomaticSize.X` + `TextScaled` + two `UISizeConstraint`s, so
   each write triggers a text re-measure and possibly a font-size re-solve. That is ordinary UI
   cost for ~2.2s at most, and only while counting — but it is the one genuinely new per-frame
   expense in this change, and it is worth a glance on a low-end handset during the owner's gate.
2. **`RenderStepped` fires only when a render frame is produced.** That is correct here (this is
   purely visual and there is nothing to advance when nothing is drawn), and `tickCounter` derives
   `t` from `os.clock()` rather than accumulating deltas, so a stalled or throttled client resumes
   at the right point on the curve rather than replaying the count. No drift risk.
3. **Nothing automated covers any of this.** `tickCounter`, `paintCounters` and the driver live in
   a `.client.luau` that no harness loads. The per-leg duration arithmetic is exercised indirectly
   through `RollingNumber`'s own 979-test suite, but the wiring — that `duration` is set on the
   right side of the `from` assignment, that the driver's ordering lands the final frame — is
   verified by reading only. Extracting `Counter`/`tickCounter` into a shared, testable module is
   the obvious follow-up if this area keeps growing.
4. The pot's count-down and the points' count-up now share a duration only incidentally: both are
   driven by `durationFor` on their own deltas, which are equal in magnitude for a bank, so they
   finish together. If a future change ever makes the balance move by something other than the
   pot's exact amount, they will visibly desynchronise. `RollingNumber`'s own header already flags
   the sign-independence that makes this work; nothing here needs to change today.
