# Final fix wave — the reveal beat

THE RULE (owner, 2026-08-04): the drum is authoritative, and must be fully at rest before the
world throw is reflected anywhere else.

## 1. The safety fallback beat the drum on every round

### What was wrong

`main.client.luau` held the round's result until the `drumRest` cue, with a fallback so a dropped
cue could not strand it:

```lua
local REVEAL_SAFETY = 3
...
task.delay(REVEAL_SAFETY, function() drumAtRest = true; maybeShowReveal() end)
```

armed from **`RevealResult` arriving**. Two independent problems:

* **3 is unrelated to the choreography.** The drum rests `DrumStep.SETTLE_SECONDS` (3.45s) after the
  strike. 3 and 3.45 are the same order of magnitude, so the two were racing by construction.
* **`RevealResult` arriving is not the strike.** `RoundCoordinator:_fetchRevealIfDue` accepts
  `state.phase == "TALLY"` as well as `"REVEAL"`, and the strike is scheduled at ACTIVE-end +
  TallySec — so the reveal can land a full tally *before* the strike. The fallback's clock started
  before the drum's did.

Instrumented live, the fallback won on **three consecutive rounds**: `RevealResult` at t=8.28s, ring
glyph at t=11.31s = 8.28 + 3.00 + one frame. The glyph and the result splash were appearing while
the drum was still visibly gliding onto its detent.

### The new timing, derived

Everything the drum does is measured from `gongHit`, which `HammerController` fires at the END of
the shu-moku's swing (`DrumStep.STRIKE_SWING_SECONDS` after the scheduled strike instant). From
`gongHit`, `DrumController`:

| leg | source | seconds |
|---|---|---|
| spin (`spinUntil = os.clock() + SPIN_SEC`) | `DrumStep.SPIN_SECONDS` | 1.00 |
| stall — only if the World Throw has not arrived by `spinUntil` | `STALL_MAX` | 0.00 or up to 6.00 |
| glide, `drumRest` fires at its end | `DrumStep.GLIDE_SECONDS` | 2.00 |

So the real rest is **gongHit + 3.00s** normally and **gongHit + 9.00s** in the stall.

The fallback is now armed on `gongHit` and sized in `DrumStep`, next to the choreography:

```lua
DrumStep.STALL_MAX_SECONDS = 6                        -- moved out of DrumController
DrumStep.SAFETY_MARGIN_SECONDS = 0.5
DrumStep.SAFETY_AFTER_STRIKE_SECONDS = SETTLE_SECONDS + SAFETY_MARGIN_SECONDS            -- 3.95
DrumStep.SAFETY_AFTER_STRIKE_STALLED_SECONDS = SAFETY_AFTER_STRIKE_SECONDS + STALL_MAX   -- 9.95
```

Headroom is **0.95s in both cases**: 0.5s explicit margin, plus 0.45s free because measuring
`SETTLE_SECONDS` from `gongHit` re-counts the swing that has already happened — an error in the safe
direction, and the reason the margin is deliberately not tuned finer.

### Choosing the window without always paying for the stall

Always using 9.95s would be safe but useless: at revealSeconds 5 the next ACTIVE arrives ~5.8s after
the strike, and ACTIVE clears `pendingReveal`, so a 9.95s fallback could never fire in time to
release anything. The fallback would satisfy THE RULE by never working.

`DrumController`'s stall condition is exactly "no World Throw in hand at the end of the spin", and it
reads that throw off the **`RevealTheater` remote**. `main.client.luau` already receives the same
remote on the same client, so it sets `worldThrowInHand` there — this is not a guess at
`DrumController`'s state, it is the same event feeding the same conclusion in two files. At
`gongHit`:

```lua
armRevealSafety(if worldThrowInHand then REVEAL_SAFETY else REVEAL_SAFETY_STALLED)
```

Both flags (`worldThrowInHand`, `strikeSeen`) are per-round and reset when ACTIVE reopens, matching
`DrumController` consuming its throw on landing.

Against the instrumented round: gongHit ≈ 10.5s, real rest ≈ 13.5s, fallback ≈ 14.5s, next ACTIVE
≈ 16.3s. The fallback sits behind the drum and still inside the gap.

### If `gongHit` itself is missed

Then nothing arms, and the result would sit in `pendingReveal` until ACTIVE swept it away unseen. So
the `RevealResult` handler keeps a backstop, but only when no strike has been seen this round:

```lua
if not strikeSeen then
    task.delay(strikeLeadSeconds(), function()
        if strikeSeen then return end   -- merely late; its own window owns the round
        ... release ...
    end)
end
```

`strikeLeadSeconds()` = `TallySec` (read live off `RoundScheduleConfig` via `FindFirstChild`, never
`WaitForChild`, so the HUD cannot block on the arena's config folder; default 2) +
`STRIKE_SWING_SECONDS` + 1s slack for the client's phase-poll lag ≈ 3.45s. That is the longest a
legitimate `gongHit` can still be ahead of a reveal that has already arrived, so it can only conclude
"lost" after "late" has been ruled out — and it re-checks `strikeSeen` when it fires, so a strike
that shows up inside the window hands the round back to the strike-armed timer.

Releasing there does not break THE RULE: a strike that never came means a drum that never spun and
never will, so there is no turning drum left to spoil.

Stale timers cannot release a newer round early — each captures `currentRoundId` at arming time and
only fires if `pendingReveal.roundId` still matches (`_roundId` on the server changes at the round
boundary, so TALLY/REVEAL of round N still report N).

## 2. RevealBeat's runway comment

The old comment claimed `RUNWAY_SECONDS` was measured — "the drum rests ~3.2s into the gap". It was
measuring the fallback, not `drumRest`. Rewritten to state only what is known: the nominal
arithmetic (rest at 5.45s into a 7s gap → 1.55s runway), the observed phase lag (TALLY 8.13s →
ACTIVE 14.34s = a 6.21s observed gap against 5s nominal, at revealSeconds 3), and that the true
post-rest runway **has not been measured at either reveal length** because every observed round
released early through the fallback. Kept as a literal at 3.8 with an explicit instruction to
re-measure at the Studio gate now that item 1 has landed. The `RevealBeat.spec` comment that
repeated the same false derivation was corrected too; no timing changed.

## 3–5. The minor items

* `src/hooks/useGameLoop.ts` — result-overlay `setTimeout` 3000 → 5000, with a comment naming
  `revealSeconds` in `server/src/index.ts` as the value it tracks and noting that a
  `grep revealSeconds` cannot reach this file.
* `HammerController.client.luau` — `revealSec` fallback 3 → 5, commented as mirroring the server's
  configured durations.
* `BoardController.client.luau` — comment only, no rewiring: records THE RULE, that this handler
  would name the throw ~3s before the drum stops, that it is dead only because `JumbotronBoard` is
  gone, and that retargeting it to the kōsatsu as written resurrects the spoiler. Points at
  `LanternController` / `TheaterController` (both gate on `drumRest`) as the pattern.

## Gates

From `roblox/`:

* `lune run tests/run` — **986 passed, 0 failed** (was 982; 4 new assertions on the safety windows)
* `stylua --check src tests tools` — clean
* `selene src tools` — 0 errors, 0 warnings, 0 parse errors

From the repo root (Node 24.12.0 via nvm):

* `npm run lint` — clean (ran the full frontend lint, not just tsc)

## Concerns

1. **`TheaterController.client.luau` has the identical defect and was out of scope.** Line 100:
   `local REVEAL_SAFETY = 3`, armed from `RevealTheater` arriving (line 154) — earlier still than
   main.client's was, since `RevealTheater` and `RevealResult` land together. The arena choreography
   is very likely firing ahead of the drum on every round for the same reason the glyph was. It
   should take the same `gongHit`-armed `DrumStep` windows; I did not touch it because item 1 named
   only `main.client.luau`.
2. **The stall path still shows no result.** If the drum stalls, it does not rest until ~9s after the
   strike, which is past the next ACTIVE — and ACTIVE clears `pendingReveal` and collapses the beat.
   So a stalled round is dropped rather than shown. That is pre-existing and is the correct reading
   of THE RULE (the drum itself has not rested in time either), but it means the 9.95s window is a
   guard, not a working release path.
3. **`RUNWAY_SECONDS = 3.8` is probably too generous.** Nominal is 1.55s; with the observed lag
   perhaps ~2.7s. `TAPE_DELAY_SECONDS` is 2.4s. If the Studio measurement comes in under that, the
   beat has to shorten and `RevealBeat.spec`'s "with headroom" assertion goes with it.
4. `HammerController` also defaults `PeriodSec` to 25 (line ~216) where the server now runs
   20+2+5 = 27. Same class of staleness as item 4 but not named in it, so left alone.

---

# Follow-up wave — concerns 1 and 4, promoted in scope

## A. The same bug in TheaterController

`TheaterController.client.luau` carried `REVEAL_SAFETY = 3` armed from `RevealTheater` **arriving** —
the identical defect, gating the arena-wide choreography (petals, umbrella) rather than the HUD. Its
own ACTIVE comment already half-knew: "REVEAL is ~3s and so is the safety below, so this boundary
and that timer race". It raced the drum too, and by the measurement behind the first wave it was
winning routinely.

### Timing used

The same `DrumStep` constants added in the first wave — no new ones:

* **`SAFETY_AFTER_STRIKE_SECONDS` = 3.95s** from `gongHit` (SETTLE 3.45 + MARGIN 0.5) when the World
  Throw was in hand at the strike.
* **`SAFETY_AFTER_STRIKE_STALLED_SECONDS` = 9.95s** from `gongHit` when it was not, covering
  `STALL_MAX`.

Both are armed as `t0 + window - os.clock()` where `t0` is the recorded strike, **not** as a fresh
delay from the arming call — a reveal that lands after the strike has already burned part of the
window, and restarting the clock would push the safety out by however late the reveal was.

### Keeping the identity comparison

The strike alone cannot arm anything, because at `gongHit` the payload may not exist yet and there
would be no identity to capture. So `armSafety()` is called from **both** the strike and the reveal
and arms only once both are in hand — whichever arrives second does the arming, the first call is a
no-op. That keeps `pendingReveal == reveal` verbatim, so an older round's timer still cannot flush a
newer round's payload, and it does it without inventing a generation counter.

`strikeStalled` is captured **at the strike** (`pendingReveal == nil`), not at arm time: a reveal
that arrives after the strike means the drum really did stall, and reading the flag later would say
the opposite.

### Both stated properties preserved

* *Never plays is worse than plays early* — a dropped `drumRest` still releases, via the window
  above; and a **missed `gongHit`** (which would otherwise arm nothing at all) is covered by a
  backstop in the `RevealTheater` handler, armed only when no strike has been seen, at
  `strikeLeadSeconds()` ≈ 3.45s, re-checking `strikeAt` when it fires so a merely-late strike hands
  the round back to the real window.
* *Identity comparison* — unchanged in both the safety and the backstop.

### The ACTIVE comment

Rewritten. `pendingReveal` is still deliberately not cleared, but the old reason is gone: the safety
no longer runs on a REVEAL-length clock racing the boundary — it runs from the strike and normally
lands ~6.4s into a 7s gap, comfortably inside it. What survives is the stalled window: when the
World Throw is late the drum itself does not rest until after the boundary, so the safety cannot
either, and clearing would drop that round's choreography outright.

### Duplication, as instructed

`strikeLeadSeconds()`, `STRIKE_LEAD_SLACK` and the strike/stall tracking are a deliberate ~15-line
duplicate of `main.client.luau`'s, with comments in both files pointing at the other. Extracting a
shared client module was explicitly out of scope for a fix wave. **If a third consumer ever wants
this, that is the moment to extract it** — `LanternController` gates on `drumRest` today but has no
safety at all, so it is the likely third.

## B. HammerController's stale defaults

`PeriodSec` defaulted to **25** against a 20 + 2 + 5 = **27s** round, and it divides the strike's
schedule fraction, so a stale value skewed where the strike landed until the first attributes
replicated. Rather than writing 27 (which rots the same way), the period default is now **derived**
from the three phase defaults: `activeSec + tallySec + revealSec`.

Swept the rest of the file: the other defaults are `ActiveSec or 20` (×2) and `TallySec or 2` (×2),
both of which match `server/src/index.ts`, and `RevealSec or 5` fixed in the first wave. Nothing else
in `roblox/src/client` or `roblox/src/server` carries a phase-duration default.

## Gates (follow-up wave)

* `lune run tests/run` — 986 passed, 0 failed
* `stylua --check src tests tools` — clean
* `selene src tools` — 0 errors, 0 warnings, 0 parse errors

No frontend files touched in this wave.

## Concerns (follow-up wave)

1. **The stall predicate is one notch coarser than DrumController's, in both files.** That controller
   does not commit to stalling until `strike + SPIN_SECONDS`; both consumers decide at the strike
   itself. A World Throw landing in that 1s sliver is treated as a stall and gets the 9.95s window
   instead of 3.95s — safe (never early), but that round's safety then lands after ACTIVE and does
   nothing. Sharpening both to `throwAt > strikeAt + SPIN_SECONDS` is a small, exact improvement and
   the natural thing to fold in if this is touched again.
2. **Still unverified in Studio.** No gate loads either client file; all four changed client paths
   (`main.client`, `TheaterController`, `HammerController`, `BoardController`) were reviewed by
   reading. The Studio gate that re-measures `RUNWAY_SECONDS` should also confirm the petals now fire
   after the drum settles, not during the glide.
