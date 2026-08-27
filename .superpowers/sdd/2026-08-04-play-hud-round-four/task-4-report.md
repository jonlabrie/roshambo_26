# Task 4 report — the payoff draws the eye, and the plate outlives it

One file changed: `roblox/src/client/HudController.client.luau`. Two commits.

- `27f29b1` — feat(roblox): the plate lifts while the balance climbs (Piece 1)
- `f92685a` — fix(roblox): the plate outlives the count it exists to show (Piece 2)

## Piece 1 — the festive treatment

**`setCelebrating` (lines 388–431).** The brief's function, with the two corrections applied and one
placement change.

- **Correction 1 applied.** The released transparency is `PLATE_STROKE_REST_TRANSPARENCY` (declared
  at 385), not the literal `0.35` the brief showed.
- **Correction 2 checked.** The plate's label has no separate named rest colour: `plateLabel` is
  constructed with `plateLabel.TextColor3 = INK_CREAM` (line 356) and `applyContrast` never touches
  it — it adjusts `plate.BackgroundTransparency` and the tape tile rims only. So `INK_CREAM` **is**
  the named rest colour, and referencing it is not a hardcoded literal. Left as the brief had it.
- **Three more constants named**, for the same drift reason correction 1 exists:
  `PLATE_STROKE_LIT_TRANSPARENCY = 0`, `PLATE_STROKE_LIT_THICKNESS = 2`,
  `PLATE_STROKE_REST_THICKNESS = 1`. The lit transparency is now read from two sites (the tween and
  `revealPlate`), and the rest thickness has to keep agreeing with the construction call
  `stroke(plate, GOLD, 1, 0.35)` at line 333.
- **The latch is present and unchanged in substance**: `if active == celebrating then return end`
  before anything is tweened. Both `TweenService:Create` calls are below it.
- **The stroke stays on `plate`.** `plateStroke` is the `UIStroke` on the `TextButton`; `plateLabel`
  gains nothing. `setCelebrating` touches `plateLabel.TextColor3` only.
- **stylua reformatting note.** Written as the brief had it, stylua (column_width 110) broke the
  first `TweenService:Create` into a chained-call form across six lines because the goal table's
  first entry sat at 104 columns. The goal table is now hoisted into a `local rim` if-expression and
  the call fits on one line. Behaviour identical; it is a formatting accommodation only.

**Placement: declared at 388, beside the plate's other visual state, not immediately above
`paintCounters` as the brief directs.** This is the one deliberate deviation, and it is forced by a
defect the brief's placement would have left in:

> `revealPlate` writes `plateStroke.Transparency = PLATE_STROKE_REST_TRANSPARENCY` directly. A
> re-reveal lands mid-count on every subsequent bank of a streak (`render`'s change-guard fires on
> the same tick the points target moves). By then the 0.15s celebrate tween has long completed, and
> `setCelebrating(true)` returns early on the latch — so nothing is running to re-raise the rim. The
> plate would have dropped to a hairline for the whole of its second count and stayed there.

`revealPlate` therefore reads `celebrating` (lines 520–525):

```lua
    plateStroke.Transparency = if celebrating
        then PLATE_STROKE_LIT_TRANSPARENCY
        else PLATE_STROKE_REST_TRANSPARENCY
```

which requires `celebrating` to be declared above `revealPlate` (513). `setCelebrating`'s
dependencies all resolve above 388: `TweenService` (43), `INK_CREAM` (59), `GOLD` (64), `plateStroke`
(333), `plateLabel` (351), `PLATE_STROKE_REST_TRANSPARENCY` (385). Its only call site is 1042, well
below.

**The drive (line 1042).** `setCelebrating(pointsCounter.startedAt ~= nil)` as the last statement of
`paintCounters`, with the brief's comment.

## Piece 2 — the plate must outlive its own count

**`PLATE_READ_BEAT = 0.6` and `plateHoldSeconds` (lines 476–507)**, immediately above `revealPlate`:

```lua
local function plateHoldSeconds(): number
    local startedAt = pointsCounter.startedAt
    if startedAt == nil then
        return PLATE_HOLD -- nothing counting: a streak tick, or a figure that has already settled
    end
    local remaining = math.max(pointsCounter.duration - (os.clock() - startedAt), 0)
    return math.max(PLATE_HOLD, remaining + PLATE_READ_BEAT)
end
```

`revealPlate` now calls `task.delay(plateHoldSeconds(), function() startPlateFade(gen) end)` — the
`gen` generation mechanism is untouched, same `task.delay`, same closure, same cancellation.

**`render` reordered (1464–1484).** The counter-target assignments and `paintCounters()` now run
*before* the reveal change-guard, which moved down with `lastPlatePoints`/`lastPlateStreak` intact.
Nothing between them has a dependency in either direction (`counterPoints = view.plate.points` does
not read `lastPlatePoints`). Comment added at the guard explaining that the ordering is now
load-bearing. `bankArmed = view.pot > 0` and its comment are unchanged, just separated by a blank
line.

**No duplicated delta arithmetic.** `plateHoldSeconds` reads `pointsCounter.duration`, the value
`tickCounter` already fixed for this leg from `RollingNumber.durationFor(target - c.from)`. There is
one call to `durationFor` in the file.

**Two comments corrected in place** rather than left false: the plate's section header (283–285,
"holds for PLATE_HOLD" → "holds for at least PLATE_HOLD"), and a new note above `PLATE_HOLD` itself
(299–300) recording that it is now a floor and that every count took half a second when it was
chosen.

## The arithmetic

`RollingNumber.durationFor` evaluated directly under Lune (throwaway script, deleted):

| bank | count duration | hold | on screen (hold + PLATE_FADE) |
|---|---|---|---|
| 1 | 0.558 | 2.000 | 2.350 |
| 27 | 1.160 | 2.000 | 2.350 |
| 79 | 1.399 | 2.000 | 2.350 |
| 81 | 1.405 | 2.005 | 2.355 |
| 243 | 1.653 | 2.253 | 2.603 |
| 729 | 1.903 | 2.503 | 2.853 |
| 2187 | 2.154 | 2.754 | 3.104 |
| **6561** | **2.404** | **3.004** | **3.354** |

**6561, the worst case, worked:** the count runs 2.404s; the hold is
`max(2, 2.404 + 0.6) = 3.004s`; the fade then takes 0.35s. The final total sits on screen at full
opacity for **0.600s** after it lands, and remains legible through a further 0.35s of fade. Before
this change the hold was 2.000s flat — the fade began 0.404s *before* the number arrived, and the
plate was fully transparent 0.05s before the count finished. (The task brief estimated the 6561
count at 2.35s; measured it is 2.404s, so the seam was slightly wider than described.)

**The threshold where behaviour changes at all is 80 points** (`duration > 1.4`). Pots are powers of
three, so the first pot that extends the hold is **81**, and it extends it by 5 milliseconds. The
first perceptible extension is 243 (+0.25s). Everything at or below 27 — and every streak tick, and
every 1-point move — holds for exactly 2.000s, byte-identical to today.

## The five release paths, walked by reading

**1. A count completes.** `RunService.RenderStepped` (1054) tests `countersAnimating()` **before**
calling `paintCounters()` — confirmed unchanged at 1055–1056, this is what Task 3 wrote and I did not
restructure it. On the frame where `t >= 1`, `countersAnimating()` is still true (it reads the
`startedAt` fields from *before* this frame's tick), so the handler enters; `tickCounter` at 1025
writes the exact target and sets `pointsCounter.startedAt = nil` (line 262); `setCelebrating(false)`
at 1042 then runs in that same invocation, tweening the rim back to
`PLATE_STROKE_REST_TRANSPARENCY`/thickness 1 and the figure back to `INK_CREAM` over 0.15s. ✔ Released.

**2. A second bank interrupts one already running.** `tickCounter`'s target-changed branch (252–257)
sets `c.from = c.displayed` — the count continues from the figure on screen, no snap-back — then a
fresh `startedAt` and a fresh `duration` for the new leg. `startedAt` is non-nil across the seam, so
`setCelebrating(true)` hits the latch and returns before touching a tween. **No tween restart.** ✔
The rim stays lit continuously rather than re-animating.

**3. The plate fades out while a count is running.** *After this task this can no longer happen for
a points count* — that is Piece 2's whole point. It can still happen for a count the hold does not
cover: a streak-only reveal (points settled, hold 2.000s) whose streak counter is still ticking, or
a ring-tap reveal. In those cases the two systems do not fight: `startPlateFade` tweens
`plateStroke.Transparency` toward 1 while `setCelebrating` is not running any tween of its own
(`celebrating` is false for a streak-only move — it is keyed on the points counter alone). If a
points count *did* start mid-fade, `render`'s change-guard fires on the same tick and `revealPlate`
cancels the fade first (`cancelPlateFade()` at 516) before restoring opacity — and it now restores
to the **lit** value if `celebrating` is already true. The release still runs when the count later
settles either way, because `paintCounters` is driven by the counters, not by the plate's visibility;
`render` also calls it at 10Hz unconditionally, so even a stalled `RenderStepped` cannot strand the
decoration. ✔

**4. A loss.** On a loss the pot is forfeited and `view.plate.points` does not move, so
`counterPoints` is unchanged, `tickCounter`'s target-changed branch never fires, `pointsCounter.startedAt`
stays `nil`, and `setCelebrating(false)` is what runs. The pot counter drains to zero and the streak
counter counts down — both animate, both drive the `RenderStepped` handler, and neither lights the
plate. ✔ Confirmed by reading 1042: the argument is `pointsCounter.startedAt`, not
`countersAnimating()`.

**5 (added). A second bank landing mid-count: decoration and fade timer.**
- *Decoration*: latched true throughout, per path 2. One thing had to be fixed for this to hold —
  `revealPlate` fires on the same tick and writes `plateStroke.Transparency` directly; before the
  Piece 1 placement change that write was unconditionally the rest value, with no tween left running
  to undo it. It now writes the lit value while `celebrating`. Thickness is never written by
  `revealPlate`, so it stays at 2. ✔
- *Fade timer*: `revealPlate` increments `plateGen`, so the delayed `startPlateFade(gen)` armed by
  the first bank finds `gen ~= plateGen` and returns — the old fade is dead, not merely cancelled.
  The new `task.delay` is sized from the **new** leg: `remaining` is measured from the freshly
  written `startedAt`/`duration`, so it is the full new duration, not the stale remainder. Hold
  extends. ✔ It cannot truncate: `plateHoldSeconds` is floored at `PLATE_HOLD` and the arithmetic is
  `max`, never `min`.
- *Ordering check that makes this true*: the arming now happens after `paintCounters()`, so the
  re-key has already run when `plateHoldSeconds` reads the counter. Had it stayed above,
  `revealPlate` would have sized the second bank's hold from the **first** bank's leg — for a
  losing-then-winning sequence of different magnitudes that is simply the wrong number.

## Gate output

```
lune run tests/run              979 passed, 0 failed, 979 total
stylua --check src tests tools  clean
selene src tools                0 errors, 0 warnings, 0 parse errors
```

Run after each commit. As the task framing states, none of these loads a `.client.luau`; the reading
above is the actual gate.

## Concerns

1. **`PLATE_READ_BEAT = 0.6` is a judgement, not a measurement.** It is the window in which the
   landed total sits at full opacity before the fade starts. 0.6s is roughly a comfortable glance and
   comfortably outlasts the 0.15s celebrate-release tween, so the rim has visibly settled before the
   plate begins to go. If the owner wants longer at the gate it is a one-constant change.
2. **A 6561 bank now occupies the plate for 3.35s.** That is the intent, but it is 1s longer than
   anything on this surface has held before. Worth watching at the owner's gate that it does not read
   as stuck.
3. **`celebrating` is not released when the plate hides.** If a points count were somehow abandoned
   without ever reaching `t >= 1` (which requires both `render` and `RenderStepped` to stop for that
   client), `celebrating` would stay true and the next reveal would show a gold plate. Both drivers
   would have to be dead for this, at which point the HUD is not updating at all — I judged a defensive
   release not worth the extra state. Flagging it because it is the one way the latch can lie.
4. **`revealPlate` now depends on `celebrating`, and `plateHoldSeconds` on `pointsCounter`.** The
   plate's reveal logic and the counting system were previously independent; they are coupled now in
   two places. Both couplings are one-directional (the plate reads the counter, never the reverse) and
   both are commented at the site, but it is a new edge in this file's dependency graph.
5. **Nothing automated covers any of this**, as with Task 3. `plateHoldSeconds` is the one piece here
   that is pure arithmetic over two numbers and would be trivially testable if `Counter`/`tickCounter`
   ever moved into a shared module — the follow-up Task 3's report already recommends.

---

# Review round 1 — four items

Commit `8db4177`. Same file, no others.

## 1. IMPORTANT — the plate celebrated a points DECREASE

Confirmed as described. `paintCounters`' predicate keyed on `pointsCounter.startedAt ~= nil`, which
is true for either direction, and `tickCounter` re-keys on any target change. A purchase debits the
balance, arrives on the next reconciliation, and the plate lit gold while the figure counted down.

Fixed at the call site:

```lua
    local pointsRising = pointsCounter.target > pointsCounter.from
    setCelebrating(pointsCounter.startedAt ~= nil and pointsRising)
```

`from` is set to `c.displayed` at the moment of the re-key, so the comparison is against the figure
actually on screen, not a stale origin — an interrupted count that reverses direction mid-flight is
judged on its *current* leg, which is the right answer. A ten-line comment above it names purchases
(teahouse, deck upgrade, portal, decoration) as the case and states explicitly that this must not be
simplified back to "the counter is moving".

`plateHoldSeconds` is untouched and stays direction-blind, as directed: a decrease still reveals and
still gets the extended hold to read the new balance.

## 2. The one-frame rim pop on the FIRST bank

**Approach taken: keep a handle and check `PlaybackState`. I did not cancel.**

Why: cancelling would have to happen on the rim tween only, since the label's colour tween is a
separate `TweenService:Create` on a different instance — so a cancel-and-set would leave the rim
snapped and the figure still easing, two halves of one gesture out of step. Worse, the case that
needs handling is precisely the one where the tween is mid-flight *and travelling to the correct
value already*: on the first bank, `paintCounters` started the lift microseconds earlier in this
same `render`, aimed at lit, which is where the reveal wants the rim. There is nothing to correct.
Skipping the write is not just cheaper than cancelling, it is the more accurate description of what
should happen — the reveal has no opinion about a rim someone else is currently animating.

```lua
    local rimTween = celebrateRim
    if rimTween == nil or rimTween.PlaybackState ~= Enum.PlaybackState.Playing then
        plateStroke.Transparency = if celebrating
            then PLATE_STROKE_LIT_TRANSPARENCY
            else PLATE_STROKE_REST_TRANSPARENCY
    end
```

`celebrateRim: Tween?` is stored in `setCelebrating` (line 440 / 454), above `revealPlate` (538).
The three cases are enumerated in a comment at the site.

One consequence worth recording, because it is the case the skip has to survive: if a points count
starts while the plate is mid-fade, `setCelebrating` runs first (inside `paintCounters`) and its rim
tween captures the mid-fade transparency as its start value; TweenService cancels the older fade
tween on that same property automatically, and `cancelPlateFade()` a few lines later is then a
no-op for it. So the rim eases from wherever the fade left it up to lit — continuous, no snap. The
fade's `Completed` handler is gen-guarded and `plateGen` is incremented at the top of `revealPlate`,
so nothing stale hides the plate. That handler is on `bgTween`, not the stroke tween, so the
auto-cancel does not reach it at all.

## 3. The construction site hardcoded what the constants named

`PLATE_STROKE_REST_TRANSPARENCY` (0.35) and `PLATE_STROKE_REST_THICKNESS` (1) moved to lines 334–335,
above the plate's construction, and the call is now:

```lua
local plateStroke = stroke(plate, GOLD, PLATE_STROKE_REST_THICKNESS, PLATE_STROKE_REST_TRANSPARENCY)
```

The comment that used to justify the constants now says the true thing: the weight the plate is
*built* at and the weight it *settles back to* are one value. The old comment at the former
declaration site was split — the half about `plateRestTransparency` (the BACKING, which is not a
constant because `applyContrast` lerps it) stayed where it belongs, rewritten to point at the rim's
pair above rather than describing it.

No behaviour change: the literals it replaced were 1 and 0.35, identical.

## 4. The join-time count from zero

`seedCounter` added beside `newCounter`/`tickCounter` (line 277):

```lua
local function seedCounter(c: Counter, value: number)
    c.displayed = value
    c.target = value
    c.from = value
    c.startedAt = nil
end
```

Called once, in `render`, on the same `lastPlatePoints == nil` test the reveal guard already uses —
read *before* the guard writes it, so there is no second flag to keep in step and no new state:

```lua
    if lastPlatePoints == nil then
        seedCounter(pointsCounter, counterPoints)
        seedCounter(streakCounter, counterStreak)
        seedCounter(potCounter, counterPot)
    end
    paintCounters()
```

All three, not just points: a player rejoining with a live pot had the same problem on the bank
button. `paintCounters` then finds `target == c.target` for each, skips the re-key, and takes the
`else` branch (`c.displayed = c.target`) — the figures are simply correct on frame one. `duration`
is left at `RollingNumber.MIN_DURATION` and is never read while `startedAt` is nil.

## The six release paths, re-walked

**1. A count completes.** Unchanged by this round. Driver still check-then-paint (`countersAnimating()`
before `paintCounters()`); `tickCounter` clears `startedAt`; `setCelebrating(false)` runs in the same
invocation. The added `pointsRising` term cannot keep it lit — `and` short-circuits on the nil
`startedAt` regardless of direction. ✔

**2. A second bank interrupts one already running.** `from = displayed` and `target` = the new,
larger balance, so `pointsRising` is true across the seam; `startedAt` non-nil; `setCelebrating(true)`
hits the latch and returns before touching a tween. Still no restart. ✔ The rim is now also correct
through this seam without the pop — see path 5.

**3. The plate fades out while a count is running.** As before, this cannot happen for a points
count. For a streak-only or ring-tap reveal whose hold is 2.000s, `celebrating` is false throughout
(the predicate is points-only, now points-and-rising), so no rim tween exists and `revealPlate`'s
write is taken normally. If a points count starts mid-fade, the sequence in item 2 above applies. ✔

**4. A loss.** `view.plate.points` does not move, so no re-key, `startedAt` stays nil, and
`pointsRising` compares `target > from` on a settled counter where they are equal — false. Two
independent reasons not to celebrate now. ✔

**5. A second bank landing mid-count.** Decoration latched true throughout. The fade timer is re-armed
by generation from the new leg — unchanged. What changed is the rim write: the celebrate tween
finished ~0.15s into the first count, so on the second bank `celebrateRim.PlaybackState` is
`Completed`, the guard lets the write through, and it writes **lit** because `celebrating` is true.
The rim holds. On the FIRST bank the same tween is `Playing` and the write is skipped, so the rim
swells in once, cleanly, instead of flashing bright for a frame first. ✔

**6 (new). A points DECREASE.** A purchase settles and the balance drops, say 900 → 400.
- *Reveal*: `render`'s change-guard tests `view.plate.points ~= lastPlatePoints` — direction-blind, so
  it fires and `revealPlate()` runs. The plate shows. ✔
- *Hold*: `plateHoldSeconds` reads `pointsCounter.duration`, which `tickCounter` computed as
  `durationFor(400 - 900)` — `durationFor` takes `math.abs`, so a 500-point drop counts for the same
  1.79s a 500-point gain would, and the hold is `max(2, 1.79 + 0.6) = 2.39s`. The player gets the
  full beat to read the new balance. ✔
- *Gold*: `pointsCounter.target (400) > pointsCounter.from (900)` is **false**, so
  `setCelebrating(false)` is what runs for every frame of the drop. If the plate happened to be lit
  from a bank a moment earlier, the latch sees the change and releases it. The rim stays at
  `PLATE_STROKE_REST_TRANSPARENCY`/thickness 1 and the figure stays `INK_CREAM`. ✔ **Reveals, holds,
  does not celebrate.**

## Gate output (round 1)

```
lune run tests/run              979 passed, 0 failed, 979 total
stylua --check src tests tools  clean
selene src tools                0 errors, 0 warnings, 0 parse errors
```

## Constraints re-verified

- Latch intact: `if active == celebrating then return end` is still the first statement of
  `setCelebrating`, above every `TweenService:Create`.
- Driver still check-then-paint at 1054–1058.
- No `UIStroke` on `plateLabel`; the only stroke touched is `plateStroke`, on the `plate` TextButton.
- `Active` is assigned at four pre-existing sites (1175, 1231, 1363, 1376); this round touched none of
  them, and `undoPill` still has no assignment anywhere in the file.
- Declaration order: `seedCounter` 277 → used 1519; `PLATE_STROKE_REST_*` 334–335 → used 359;
  `celebrateRim` 440 → read 557; `plateHoldSeconds` 525 → called 564.
- `gen` generation counter in `revealPlate`/`startPlateFade` unchanged.

## New concern

`revealPlate` now reads a tween's `PlaybackState`, which is the first place in this file where a
reveal's correctness depends on the *timing* of something else rather than only on latched state. It
holds because `paintCounters` always runs before the reveal guard within a single `render` (Piece 2
made that ordering explicit and load-bearing for a different reason), so the "tween is Playing" case
is exactly the first frame of a count and nothing else. If those two are ever separated again, this
guard becomes wrong in a way no gate will catch.
