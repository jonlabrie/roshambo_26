# Play HUD — round four design

**Date:** 2026-08-04
**Amends** `2026-08-04-play-hud-round-three-design.md`. Round three's Studio gate passed with four
notes; this is those four.
**Gate:** owner's Studio session, 2026-08-04 afternoon.

1. The ring's digits sit a touch low.
2. The result splash takes a long time to appear after the round closes.
3. Banking a large pot transfers it almost instantly. It should feel like a payoff.
4. The UNDO overlay's near-black fill is jarring and out of palette.

---

## §0 Invariants this round must not break

Carried from earlier rounds; every task inherits them.

- **`Active` discipline.** `TextButton`/`ImageButton` always sink touch; `Frame`/`TextLabel` only
  when `Active = true`. `undoPill` is a `Frame` covering a live `TextButton` and **must stay
  `Active = false`** — the tap that answers the prompt is delivered to the button underneath.
  §4 repaints it and must not touch that.
- **No `UIStroke` on a `TextLabel`.** Contrast comes from an opaque backing. §3's festive treatment
  puts its stroke on the **plate**, never on `plateLabel`.
- **Pure `src/shared` modules** hold the arithmetic: DI, no Roblox globals, Lune-testable.
  `RollingNumber` and `DrumStep` both keep that property through this round.
- **No gate can see any of this.** `lune run tests/run` never loads a `.client.luau`; `selene` does
  not resolve cross-module field types. Reconcile every cross-module read by hand; confirm every
  local is declared before first use.
- **The drum's choreography is signed off** (`zendojo-bell-engine`). §2 does not retime it.

---

## §1 The ring's digits are optically low

**Cause, not a nudge for its own sake.** `ringCount` fills `ringDisc` and Roblox centres the
**line box** — which reserves descender space. Digits have no descenders, so a vertically centred
box always seats them low by roughly half a descender. Every countdown this HUD will ever show is
digits, so the correction is unconditional.

`ringCount` gains `AnchorPoint = (0.5, 0.5)` and `Position = UDim2.new(0.5, 0, 0.5, -NUDGE)`,
where:

```
NUDGE = math.max(1, math.round(ringCount.TextSize * 0.06))
```

→ **2px desktop** (34), **1px touch** (20). Derived rather than a literal pair so a future TextSize
change carries its own correction.

**The world-throw glyph does NOT move.** `glyphBox(ringDisc, 0.82)` holds geometric artwork that is
already centred correctly; only the text label is mis-seated. Nudging the glyph would introduce the
defect this fixes.

---

## §2 The splash lands *with* the drum instead of after it

### The delay is not the splash

`SplashController` shows on the `drumRest` cue with no delay of its own. The wait is the drum's:

| | |
| --- | --- |
| `STRIKE_SWING_SECONDS` | 0.45 |
| `SPIN_SECONDS` | 1.00 |
| `GLIDE_SECONDS` | 2.00 |
| **`SETTLE_SECONDS`** | **3.45** |

The gate exists so the result is not announced before the drum has shown the world's throw.

### The change

`DrumController` fires a **new cue, `drumSettling`**, once per glide, and the splash gates on that
instead of on `drumRest`.

**AMENDED 2026-08-04 (owner's ruling), and the amendment is the interesting part.** The cue first
fired at a fixed `SPLASH_LEAD_SECONDS = 0.7`, sized against the criterion *the drum has covered
>80% of its travel*. Review showed that criterion measures the wrong thing. What matters is not
how far the drum has come but **whether the correct symbol is in the window**, and those diverge:

| | residual angle | still turning at |
| --- | --- | --- |
| best-case landing | 28.1° | 80°/s |
| worst-case landing | 53.4° | 142°/s |

Facets sit 30° apart and each carries a *different* symbol, so at a 0.7s lead the window is showing
a neighbouring throw for a further 0.19–0.34s. On a LOSS the splash names the outcome while the
drum still reads something else — precisely the spoiler the gate exists to prevent.

Nor does a shorter constant rescue it: at 0.50s the worst case is still 28.4°, a full facet off. A
*fixed* lead safe in every case is ≈0.36s, which barely improves on 3.45s at all. **The trade is
unwinnable with a constant, because the residual depends on the travel the lander happens to pick.**

So the cue triggers on the **residual angle** rather than the clock. `DrumStep` gains the glide's
residual as pure arithmetic, plus the threshold:

```luau
DrumStep.SPLASH_RESIDUAL_RADIANS  -- half a facet
function DrumStep.glideResidual(d, omega, s)
```

The glide is a **Hermite**, not a bare smoothstep — it carries the spin's exit velocity, which is
why the earlier smoothstep-only estimate read 72% where the real curve reads 83–88%:

```
residual(s) = d·(1 − (3s² − 2s³)) − ω·GLIDE_SECONDS·(s³ − 2s² + s)
```

The cue fires the first frame the residual falls within half a facet. That yields a **variable
0.36–0.53s lead** — the splash lands around 2.9–3.1s, correct on every landing rather than on the
lucky ones. It is also the only formulation that survives a retune of the drum's kick velocity: a
constant lead silently becomes wrong, and no test can catch it because the kick is overridable at
runtime by a stage attribute.

`SPLASH_LEAD_SECONDS` is deleted. A fixed lead that is right for one landing and wrong for the next
is worse than no constant at all.

### What moves and what does not

- **The splash moves.** It is the player's own result and it is what the owner is waiting for.
- **The tape tile does NOT move.** It stays on `drumRest`. The tape is the record of the *world's*
  throw — the actual spoiler — and it has no urgency. The resulting sequence is better than either
  alone: your outcome first, then the world's mark goes onto the tape as the drum stops.
- `LanternController` and `TheaterController` keep their own `drumRest` holds, untouched.

### The dropped-cue fallback

`main.client.luau`'s `REVEAL_SAFETY = 3` fallback must now cover **both** gates. `drumSettling` is
one more cue that can be dropped, and a splash that never appears is worse than one that appears
early. The fallback fires each pending part exactly once, whichever gate it was waiting on.

**`SETTLE_SECONDS` keeps its current value and its current derivation.** The server reads it to time
round scheduling; this round changes when a client *reacts*, not how long the drum takes.

---

## §3 Banking is a payoff, not a transfer

Three separate defects sit behind "it transferred very quickly". All three must be fixed or the
feature gets worse, not better.

### 3a. The duration is flat

`RollingNumber.DURATION = 0.5` regardless of amount. One point and two thousand take the same
half-second. It becomes a function of the distance travelled:

```luau
RollingNumber.MIN_DURATION = 0.4
RollingNumber.MAX_DURATION = 2.5
RollingNumber.SCALE_CAP = 10000

function RollingNumber.durationFor(delta: number): number
```

A **logarithmic** curve — `MIN + (MAX − MIN) * log(1 + |delta|) / log(1 + SCALE_CAP)`, clamped —
because it flattens on its own, so no pot however large can run away with the screen:

| points | duration |
| --- | --- |
| 1 | 0.56s |
| 30 | 1.18s |
| 300 | 1.70s |
| 3000 | 2.23s |
| 10000+ | 2.50s (the ceiling) |

`|delta|` — the magnitude, so a count *down* takes exactly as long as the matching count up. The
bank button draining and the balance filling are one event and must finish together.

`RollingNumber.DURATION` is deleted. Every caller derives its own.

### 3b. The easing is backwards for a payoff

The current quadratic ease-out is fast-then-slow: at 2.2s, three quarters of the points land in the
first half and the rest crawl. A payoff winds up, races, then settles. **Smoothstep**
(`t²(3 − 2t)`) does exactly that, and preserves every guarantee the current tests assert —
monotonic, bounded to [0,1], exact at both endpoints, no overshoot.

### 3c. 10Hz is not enough frames to count with

`render` is driven by `main.client.luau`'s 10Hz heartbeat. Today's 0.5s count is 5 frames — coarse,
but over too quickly to read as anything. **A 2.2s count at 10Hz is ~22 visible steps: a number
lurching, not counting.** Stretching the duration without fixing this makes the problem the owner
reported *worse*.

While any counter is mid-count, it is driven from `RunService.RenderStepped` and repaints its own
label. `render` keeps sole ownership of the **targets**; the per-frame driver only advances `t`
toward a target already set. `tickCounter` is keyed on the target *changing*, so re-invoking it with
the current target is a safe no-op re-key that only advances the clock — the property that already
lets a 10Hz repaint call it harmlessly.

The connection stays live and does nothing when every counter has settled (`startedAt == nil`),
which is the overwhelming majority of the time.

### 3d. The festive treatment

While the points figure is counting, the plate is decorated to pull the eye to it:

- a `GOLD` `UIStroke` on the **plate** (never on `plateLabel` — see §0), fading in over ~0.15s
- `plateLabel.TextColor3` lifts to `GOLD` for the duration, easing back to `INK_CREAM` as it settles

**The plate only.** The bank button's own figure is *draining* to zero, and a number counting down
to nothing should not celebrate. The destination gets the emphasis; the source just empties.

The plate's existing reveal-and-fade behaviour is unchanged — it already reveals on any change to
points or streak, which is exactly when this fires. The stroke and the colour must both be fully
released when the count settles, including when a second bank interrupts one already running.

---

## §4 The UNDO overlay comes into the palette

`WASHI` (26, 24, 28) is the HUD's dark, but opaque at full-button size over a cream throw button it
reads as a hole punched in the HUD rather than a card laid on it.

| | from | to |
| --- | --- | --- |
| `undoPill.BackgroundColor3` | `WASHI` | **`IVORY`** (244, 238, 222) |
| `undoLabel.TextColor3` | `INK_CREAM` | **`INK`** (60, 45, 28) |
| stroke | `SEL_BLUE`, 2px | **unchanged** |

Cream-on-ink with a cool rim is the HUD's own washi idiom, and the blue rim is what keeps it from
reading as an ordinary available tile. `Active` is not touched. Size, corner radius, `ZIndex`,
`TextScaled`, `MaxTextSize` and `GothamBold` are all unchanged.

---

## §5 Risks

- **§3c is the one that decides whether §3 works at all.** A longer count on a 10Hz repaint is a
  visibly worse HUD than the one the owner reported. No test can see it.
- **§3d must release its decoration on every exit path**, including a second bank landing mid-count
  and the plate fading out under a still-running count. A stuck gold stroke is permanent.
- **§2 adds a cue that can be dropped.** The `REVEAL_SAFETY` fallback has to cover the new gate as
  well as the old one, and must fire each part exactly once.
- **§1 must not move the world-throw glyph** — it is correctly centred today.
- `RollingNumber.DURATION`'s deletion touches every caller. The pot, the points and the streak all
  read it.
