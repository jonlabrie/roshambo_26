# Task 3R report — throws open late, never early

Status: **complete**. Gates green, tree otherwise clean. One file changed,
`roblox/src/client/main.client.luau`, **58 insertions / 3 deletions** — of which the executable
change is six lines.

## Gate output

```
$ cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
$ lune run tests/run
998 passed, 0 failed, 998 total      (unchanged — no suite loads a .client.luau)
$ stylua --check src tests tools
(no output — clean)
$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

The two `[QUEUE]`/`[WARN]` lines above the tally are `HandlerQueue.spec`'s own deliberate
`boom`/queue-full fixtures printing to stdout, present before this change.

## Step 1: the condition

A new pure function, `throwPhase()`, declared immediately above `buildInputs` (its only caller) and
well below the three locals it reads (`phase`, `serverPhase`, `localPhase`, declared at :166-:171):

```lua
local function throwPhase(): string
    if localPhase == "ACTIVE" and serverPhase ~= "ACTIVE" then
        return serverPhase
    end
    return phase
end
```

`buildInputs` now passes `phase = throwPhase()` instead of `phase = phase`. That is the whole diff
apart from ~50 lines of comment and a three-line amendment to the `serverPhase` header comment
(:158, which previously listed two jobs for that local and now lists three).

**What the gate actually is, stated as a set.** `phase` is `localPhase or serverPhase`, so
`throwPhase() == "ACTIVE"` holds exactly when

> `serverPhase == "ACTIVE"` **and** `localPhase` is either `"ACTIVE"` or `nil`.

Two things follow, and both matter more than the code:

1. It is **the pre-77c2775 open condition (`serverPhase == "ACTIVE"`) intersected with the
   timeline's agreement**. A strict subset. Throws can therefore never open *earlier* than they did
   before the timeline existed — the property the task asked for, and it holds by construction
   rather than by case analysis.
2. Disagreement in **either** direction fails shut: timeline ahead (`localPhase` ACTIVE, server not)
   and timeline behind (`localPhase` TALLY/REVEAL, server ACTIVE — that one already failed shut
   because `phase` takes `localPhase` when it exists; the new branch is only needed for the ahead
   case).

**Why not compare round ids.** The brief says "confirmed the same round". I used the phase report
rather than an id, deliberately:

- `RoundMetronome.Reading` (`src/shared/RoundMetronome.luau:30-40`) carries **no round id at all**.
  Adding one is a shared-module change and this task's file list is one client file.
- The other candidate, `RoundScheduleConfig`'s `RoundId` attribute, is written by the *same*
  `RoundCoordinator._apply` tick that fires `onRound` → RoundUpdate. It is not an independent
  witness. Worse, an attribute and a RemoteEvent have **no replication ordering** (the standing
  lesson from the B3 back-door bug), so comparing them would manufacture disagreement rather than
  detect it — and disagreement now means throws stay shut, so a spurious mismatch costs the player
  real throwing time.
- `serverPhase == "ACTIVE"` is per-round by construction: it is set from the very RoundUpdate whose
  ACTIVE branch resets `chosen`/`sent`/`declinedThisRound`. Agreement therefore means *that reset
  has already run*, which is precisely the fact the gate needs.
- "Both say ACTIVE" cannot name two different rounds: that needs the timeline to be a whole 27s
  period out, and `RoundMetronome.setSchedule` **hard re-anchors** past `SLEW_TOLERANCE` (2s) on
  every round's publish, so the sustained error is bounded at 2s.

The condition is commented with all of the above at :396-:434, including an explicit "this will
look redundant — simplifying it to `return phase` restores the swallow, and no automated gate in
this repo will catch it."

## Step 2: the six cases

Round shape throughout: ACTIVE 20s / TALLY 2s / REVEAL 5s, lockout 2s before ACTIVE ends (18s of
throwing). T₀ = the instant the server's ACTIVE opens; δ = the poll's notice delay, 0–1.25s.

### 1. local ACTIVE, RoundUpdate confirms the same round → **open**

`localPhase = "ACTIVE"`, `serverPhase = "ACTIVE"`. The branch needs `serverPhase ~= "ACTIVE"`, so it
does not fire; `throwPhase()` returns `phase`, which is `"ACTIVE"`. `secondsLeft()` (untouched)
sees the global `phase == "ACTIVE"` and returns `max(0, lockoutAt - os.clock())` > 0.
`HudModel.throwsEnabledFor` → true. `tapAction` returns "choose"; HudController's `canThrow` is
true, so the press paints its optimistic light and `MouseButton1Click` fires `EventBus.HudPick`.
Identical in every respect to the state after 77c2775.

### 2. local ACTIVE, RoundUpdate still on the previous round → **shut**

`localPhase = "ACTIVE"`, `serverPhase = "REVEAL"` (the previous round's last report — the reset has
not run, so `chosen`/`sent` still hold last round's values). The branch fires and returns
`"REVEAL"`. `throwsEnabledFor`'s `inputs.phase == "ACTIVE"` is false → `tapAction` returns
"ignore" and `view.throwsEnabled` is false.

The refusal is **visible, not silent**, and that is worth stating: HudController mirrors
`view.throwsEnabled` into `canThrow`, and `canThrow == false` makes `MouseButton1Down` return
before `paintThrows` (`HudController.client.luau:944-947`) and `MouseButton1Click` return before
firing `HudPick` (`:967-971`). The glyph is dim, it does not light, and nothing is written into
`chosen` for the reset to erase. That is the exact fault this task closes: previously the tap was
*accepted* (`chosen = sym`, glyph lit, `publish()`), and then the RoundUpdate ACTIVE branch's
`chosen = nil` erased it a fraction of a second later — a lit glyph going dark with no explanation
and nothing on the wire.

Note the countdown is unaffected: the global `phase` is still `"ACTIVE"`, so `secondsLeft()` is
already ticking down the real window. Only the gate is shut.

### 3. local ACTIVE early by 500ms → **opens 500ms late, never early**

- T₀−0.5: the timeline flips. `localPhase = "ACTIVE"`, `serverPhase = "REVEAL"` → case 2 → shut.
- T₀: the server's round opens. Still shut — the client has not been told yet, and it does not
  guess.
- T₀+δ: RoundUpdate lands. The ACTIVE branch resets `chosen`/`sent`/`declinedThisRound`, sets
  `roundCouldThrow`, calls `refreshClock()`, sets `serverPhase = "ACTIVE"` and `phase = "ACTIVE"`.
  Now both agree → case 1 → **open**.

Throws open at T₀+δ. Relative to the local timeline they are 0.5+δ late; relative to the server they
are δ late; they are **never open before T₀**. The player loses δ of an 18s window (invisible) and
cannot lose a tap (not invisible).

The same arithmetic with the timeline 500ms *behind* gives: server opens T₀, RoundUpdate at T₀+δ but
`localPhase` is still `"REVEAL"` so `phase` is `"REVEAL"` and throws stay shut until T₀+0.5.
Also late, also safe.

### 4. no schedule at all → **identical to today**

`metronome:read()` returns nil while `_periodSec`/`_strikeAt` are unset — a client that just joined,
or one whose `RoundScheduleConfig` never replicates. Then `localPhase = nil` and
`phase = serverPhase`. `throwPhase()`'s branch tests `localPhase == "ACTIVE"`; `nil ~= "ACTIVE"`, so
it does not fire and the function returns `phase`, i.e. `serverPhase` — the last RoundUpdate's
phase, unmodified. `lockoutAt` is meanwhile filled from the poll's `secondsToLockout` by the
`localPhase == nil` fallback at the RoundUpdate handler. That is the pre-77c2775 file, poll lag and
all.

This also covers the join state before the first RoundUpdate: `serverPhase = ""` → shut, exactly as
today.

### 5. the lockout arrives → **closes, unchanged**

Closing is `secondsLeft() == 0`, and `secondsLeft()` is byte-identical to before this task —
`math.max(0, lockoutAt - os.clock())`, still seconds-to-lockout, still reading the global `phase`
and not `throwPhase()`. `throwsEnabledFor`'s `secondsLeft > 0` goes false at the lockout instant
and throws close there.

`throwPhase()` is not involved at the lockout at all: the lockout is 18s into the round, by which
time `serverPhase == "ACTIVE"` has been true for ~18−δ seconds, so the function takes its identity
branch and returns `phase` exactly as the unmodified code did. The gate's only reachable window is
the *start* of the round.

(Second-order: if the timeline runs ahead and flips ACTIVE→TALLY before the server does, the global
`phase` becomes `"TALLY"` and `secondsLeft()` returns 0 — but the lockout shut throws 2s earlier, so
nothing observable changes.)

### 6. `sendAtLockout` still fires inside the server's window → **the pick reaches the wire**

This is the one that was broken in 582abfe, so it is argued in three parts rather than asserted.

**(a) The gate cannot withhold a send. This is structural, not circumstantial.** Read
`HudModel.sendAtLockout` (`src/shared/HudModel.luau:151-163`) as a function of `phase` alone,
holding `chosen`, `sent` and `secondsLeft` fixed:

| phase | result |
|---|---|
| any, when `chosen == nil or sent` | `nil` — phase never consulted |
| `"ACTIVE"`, `secondsLeft > 0.5` | `nil` |
| `"ACTIVE"`, `secondsLeft <= 0.5` | `chosen` |
| anything else | `chosen` |

So `f(non-ACTIVE) = chosen`, which is a superset of `f("ACTIVE") ∈ {nil, chosen}`. Now the shape of
`throwPhase()`: it returns either `phase` unchanged, or `serverPhase` — and it returns `serverPhase`
only inside a branch whose guard is `serverPhase ~= "ACTIVE"`. **Its output is therefore either
`phase` or a non-ACTIVE string; it can never turn a non-ACTIVE `phase` into `"ACTIVE"`, and it can
never turn `"ACTIVE"` into `"ACTIVE"`-with-different-meaning.** The only substitution it makes is
ACTIVE → non-ACTIVE, and by the table that can only turn a `nil` into the pick — never the pick into
a `nil`.

**The send is unreachable from this change in the suppressing direction.** No sequence of clock
error, schedule loss or poll delay can make this gate hold a pick back, because there is no path
through `sendAtLockout` where a non-ACTIVE phase returns less than an ACTIVE one.

**(b) The normal round, traced.** Throws opened at T₀+δ with both sources agreeing. The player taps
at T₀+4: `tapAction` → "choose", `chosen = "ROCK"`, `sent = false`. Nothing goes to the server —
the pick is held, which is the entire reason the lockout send exists.

From T₀+δ to the end of the server's ACTIVE, `serverPhase == "ACTIVE"`, so `throwPhase()` takes its
identity branch on every one of the ~180 heartbeat ticks in between; `inputs.phase` is `"ACTIVE"`
throughout, exactly as it was before this task. `secondsLeft()` counts the untouched
`lockoutAt - os.clock()` down, and `lockoutAt` is `os.clock() + reading.lockoutIn` where `lockoutIn`
reaches 0 at ACTIVE_END − `RoundMetronome.LOCKOUT_SECONDS` — the same instant
`RoundCoordinator._lockoutAtMs` names, since 77c2775 gave both sides one constant.

At `secondsLeft <= 0.5`, i.e. T₀+17.5 — **1.5s before the server's own lockout at T₀+18** — the
10Hz heartbeat's `HudModel.sendAtLockout(buildInputs())` returns `"ROCK"`, `sendPick` sets
`sent = true` and fires `SubmitPick`. `RoundCoordinator:submitPick` sees `_phase == "ACTIVE"` and
`_picksClosed == false` and accepts; `ThrowBuffer`'s own lockout flush carries it to
`POST /api/v1/throws`. **The pick reaches the wire, inside the server's window.**

**(c) Can the shut window ever contain an unsent pick?** — the question that decides whether (a)'s
"sends earlier" direction is ever exercised. The shut window is
`localPhase == "ACTIVE" and serverPhase ~= "ACTIVE"`, which sits *before* this round's ACTIVE reset,
so `chosen`/`sent` still hold the **previous** round's values. A previous-round pick is always
already sent by then:

- a tap requires `throwsEnabledFor`, hence `secondsLeft > 0`, so the last possible tap lands at
  `secondsLeft ∈ (0, 0.5]`;
- the very next 100ms tick has `secondsLeft <= 0.5` → sends;
- past the lockout `secondsLeft` is 0 → sends; past the phase boundary `phase ~= "ACTIVE"` → sends.

So entering the shut window, either `chosen == nil` (the player did not pick) or `sent == true` (it
already went). `sendAtLockout` returns `nil` on both, and the substituted phase changes nothing at
all. The "flushes earlier" behaviour from (a) exists as the safe direction, not as live behaviour;
the only way to reach it is a heartbeat that stopped running, in which case nothing in this file
works anyway.

## What was checked against the "do not break" list

| constraint | check |
|---|---|
| `secondsLeft()` formula and meaning | not in the diff. `git diff` shows the only executable change is `phase = phase` → `phase = throwPhase()` plus the new function. `secondsLeft()` still reads the **global** `phase`, not the gated one, and still returns `math.max(0, lockoutAt - os.clock())`. |
| `sendAtLockout` still reaches the wire | case 6(a) — structurally impossible to suppress; 6(b) traced end to end. |
| lockout behaviour unchanged | case 5. `lockoutAt` is not assigned anywhere in this diff. |
| every local above its first use | `throwPhase` declared at :434, used once at :453. It reads `phase` (:166), `serverPhase` (:167), `localPhase` (:171) — all far above. |
| no `Active` assignment; `undoPill` untouched | neither string appears in the diff; `grep` for `Active` in this file finds only the `"ACTIVE"` phase literals. |
| selene warnings | 0 warnings, 0 errors. |

## Concerns

1. **The ring now appears when throws do, not up to a poll earlier.** `buildInputs()` is also what
   goes out on `EventBus.HudState`, and HudController latches the ring's span on `inputs.phase`
   (`HudController.client.luau:1680-1691`) — so the gated phase gates the ring too. Traced: at
   T₀+δ, `lastPhase ~= inputs.phase` resets `span` to 0, then `span = max(0, secondsLeft)` ≈ 17.4,
   and the ring starts full (digits read `ceil(17.4)` = **18**) and depletes correctly to the
   lockout. Nothing breaks, and the ring and the glyphs now light together rather than the ring
   running while the glyphs are dark. But it *is* a partial walk-back of Task 2R's "the ring appears
   the instant ACTIVE opens" — it now appears the instant the round is *confirmed*. Still no worse
   than pre-77c2775 (same timing, better number). **Decoupling the two needs a second field on
   `HudModel.Inputs` and a HudController edit; both are outside this task's one-file scope, and it
   should be its own diff if the owner wants the ring back on the timeline.**

2. **Worst-case throwing time lost is δ + the timeline's error**, i.e. up to ~1.25s of poll plus up
   to 2s of un-slewed schedule error, out of 18s. It cannot cost a whole round: `serverPhase ==
   "ACTIVE"` alone was the pre-77c2775 open condition and it is still necessary and (with a nil
   `localPhase`) sufficient, and the metronome hard re-anchors past 2s so `localPhase` cannot be
   wrong for a whole ACTIVE window.

3. **A LATE local timeline can still send the held pick after the server's lockout.** `lockoutAt`
   is derived from the timeline, so if the timeline runs behind, `secondsLeft <= 0.5` is reached
   after the server has closed picks and `SubmitPick` is refused — the pick is lost and `sent` is
   already true. This arrived with 77c2775, is bounded by the 2s `SLEW_TOLERANCE` re-anchor, and is
   **neither improved nor worsened** by this task (the gate cannot affect when `secondsLeft`
   reaches 0.5). Closing it means clamping `lockoutAt` against the poll's `secondsToLockout`, which
   touches `lockoutAt` — out of scope here, and worth its own decision.

4. **Nothing here is verifiable by an automated gate.** No suite loads a `.client.luau`; selene does
   not resolve cross-module field types; stylua only formats. The 998 green tests are unchanged
   because they cannot see this file. Reading was the gate, and the owner's Studio gate is the real
   one. Its acceptance test is one sentence: **tap a glyph the instant the ring reappears — the tap
   must either register and survive into the round, or be refused by a visibly dim glyph. It must
   never light and then go dark.**
