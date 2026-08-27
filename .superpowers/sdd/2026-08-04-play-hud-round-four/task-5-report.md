# Task 5 report — the splash lands with the drum

Commit `0d3dec5e14bb2e2cb744a29e55c9941410a4a432`, on `m4b-zendojo-art-pass`. Not pushed.

## What changed, per file

### `roblox/src/shared/DrumStep.luau`
Added `DrumStep.SPLASH_LEAD_SECONDS = 0.7` after `SETTLE_SECONDS`, with the brief's comment
verbatim. Nothing else in the file moved: `STRIKE_SWING_SECONDS`, `SPIN_SECONDS`,
`GLIDE_SECONDS` and the derived `SETTLE_SECONDS` are byte-identical, so the server's round
scheduling is untouched. No Roblox globals introduced — the module stays Lune-testable.

### `roblox/tests/DrumStep.spec.luau`
Appended the new `describe("DrumStep.SPLASH_LEAD_SECONDS …")` block. The existing
`describe("DrumStep (12 faces)")` and `describe("DrumStep — the strike-to-rest timing")` blocks
are untouched.

**One test's model was corrected — see "Concerns" below.** Tests 1 and 3 are verbatim from the
brief. Test 2 keeps the brief's `> 0.8` threshold and its intent, but models the *actual* glide
rather than a bare smoothstep.

### `roblox/src/client/DrumController.client.luau`
- Beside `SPIN_SEC` / `GLIDE_SEC` (both of which already come from `DrumStep` — confirmed,
  lines 75-76): `SETTLING_S` (the clamped fraction) and the `settlingFired` latch.
- In the glide branch's `else` arm (still-travelling), **before** the `theta = …` assignment:
  the once-per-glide `EventBus.Cue:Fire({ kind = "drumSettling" })`.
- `settlingFired = false` at both glide-start points (see the trace below).
- `drumRest` is unchanged: same place, same condition, same payload.

### `roblox/src/client/main.client.luau`
- `local drumSettling` / `local splashDone` beside `drumAtRest`.
- New `maybeShowSplash()` immediately above `maybeShowReveal`.
- `maybeShowReveal` now calls `maybeShowSplash()` as its first line and no longer fires
  `EventBus.Splash`; the comment there now says the splash releases on the earlier gate and that
  this call is its fallback.
- `EventBus.Cue` handler split into `drumSettling` / `drumRest` arms; the `drumRest` arm sets
  `drumSettling = true` as well.
- The `REVEAL_SAFETY` fallback sets both flags.
- The `RoundUpdate` ACTIVE reset clears `drumSettling` and `splashDone` alongside `pendingReveal`
  and `drumAtRest`.
- Three comments that had become false were rewritten (the file header's "DRUM-REST SPOILER
  GATE … holds the tape tile and the headline"; the `pendingReveal` block comment's "The result
  splash AND the new tape tile wait for the drum to stop turning"; and the win-beat comment's
  "the splash fired below"). No behaviour in those edits.

### `roblox/src/client/EventBus.luau` — a fifth file, not in the brief's list
The `"Splash"` entry's comment asserted the event is "Fired from main.client.luau's
`maybeShowReveal` — the same drum-rest gate the tape tile and the headline already wait on".
That is now precisely the thing this task made untrue, and it is the comment a future reader
consults to learn when Splash fires. Updated to name `maybeShowSplash` and `drumSettling`.
Comment-only; included in the commit.

## Gate output

From `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox`:

```
$ lune run tests/run
982 passed, 0 failed, 982 total

$ stylua --check src tests tools
(no output — clean)

$ selene src tools
Results:
0 errors
0 warnings
0 parse errors
```

Before the constant existed, the new block failed as expected — `980 passed, 2 failed`, with
`attempt to compare number < nil` and `attempt to perform arithmetic (sub) on number and nil`.

## Step 6 — the standing check, item by item

Neither client file is loaded by any gate (`lune run tests/run` never loads a `.client.luau`;
selene does not resolve cross-module field types; stylua only formats). Verified by reading.

**1. `maybeShowSplash` is declared above `maybeShowReveal` and above the `EventBus.Cue` handler,
and below `wallet` and `pendingReveal`.**
Confirmed. `wallet` line 82 → `pendingReveal` line 305 → `drumSettling`/`splashDone` lines
323-324 → `maybeShowSplash` line 326 → `maybeShowReveal` line 345 → `EventBus.Cue.Event:Connect`
line 401. Every read inside `maybeShowSplash` resolves to a local already in scope; nothing
forward-references.

**2. `settlingFired` is reset on every path that starts a glide. Name them.**
There are exactly two, and both are covered:
- `DrumController.client.luau:164` — in the spin branch, alongside `glideT0 = os.clock()`,
  immediately before `mode = "glide"`. This is the only assignment of `mode = "glide"` in the
  file (grepped).
- `DrumController.client.luau:234` — in the `gongHit` cue handler, alongside
  `spinUntil = os.clock() + SPIN_SEC` and immediately before `mode = "spin"`. This is the only
  assignment of `mode = "spin"` in the file.

The second one is what makes the cue per-round rather than per-session. It is not redundant with
the first: the third path that ends a glide is `RoundUpdate`'s stall guard, which force-lands the
drum (`mode = "hold"`) *without* passing through the spin branch and without firing `drumRest`.
After that path, `settlingFired` may be left `true`; the `gongHit` reset is what clears it before
the next glide. With only the first reset, that sequence would silently disable the cue for the
rest of the session.

**3. The `drumSettling` cue fires exactly once per round: trace glide → rest → respin.**

- **Strike.** `gongHit` → `settlingFired = false`, `mode = "spin"`, `spinUntil = now + 1.0`.
- **Spin.** The `spin` branch never touches `settlingFired` and never fires the cue.
- **Glide start.** Once the world throw has arrived and `SPIN_SEC` has elapsed:
  `settlingFired = false` (already false — harmless), `glideT0 = now`, `mode = "glide"`. Note the
  glide *cannot* begin before `latestWorldThrow` is set (or `STALL_MAX` expires), and
  `RevealTheater` and `RevealResult` are fired from the same server loop iteration
  (`main.server.luau` lines 340-361) — so on the normal path `pendingReveal` is always populated
  before `drumSettling` can fire.
- **Glide, s < 0.65.** `not settlingFired` is true but `s >= SETTLING_S` is false. No fire.
- **Glide, first tick with 0.65 ≤ s < 1.** `settlingFired = true`, cue fires. **Fire #1.**
- **Glide, remaining ticks.** `not settlingFired` is now false. No further fire. At ~60Hz there
  are roughly 42 such ticks in the remaining 0.7s, all suppressed by the latch.
- **s ≥ 1.** Control takes the *other* arm of the branch — the settling check lives in the `else`
  arm only — so it cannot fire at or past rest. `drumRest` fires, `mode = "hold"`.
- **Hold.** The heartbeat body runs neither branch. No fire.
- **Respin (next round's `gongHit`).** `settlingFired = false`. The cycle repeats: exactly one
  `drumSettling` per glide, and exactly one glide per round.

On the client side, `splashDone` gives a second, independent per-round latch, so even a duplicated
cue could not double-fire the splash; and `splashDone` is cleared only by `RoundUpdate`'s ACTIVE
transition, so a `drumSettling` followed by `drumRest` in the *same* round produces one splash,
not two.

**4. `EventBus.Splash:Fire` appears exactly once in the file.**
Confirmed — `main.client.luau:337`, inside `maybeShowSplash`. The old occurrence in
`maybeShowReveal` was deleted, not copied. (`grep -n "Splash" main.client.luau` otherwise returns
only the `resultSplash` preference and comments.)

**5. The tape badge, `lastRound`, `revealedWorldThrow` and the `EventBus.Onboard:Fire("win", …)`
beat are all still behind `drumAtRest` — none of them moved.**
Confirmed. All four sit inside `maybeShowReveal` *after* the `if not drumAtRest then return end`
guard (line 347): `lastRound` at 356, `badgeById[p.roundId]` at 366, `revealedRoundId` at 368,
`revealedWorldThrow` at 369, the win beat at 386-388. `pendingReveal = nil` also stays there, at
352 — `maybeShowSplash` only *reads* the record and never consumes it, which is what lets the tape
still find it 0.7s later. `visibleTape`'s gating on `revealedRoundId` is untouched.

**6. Every new local is declared before first use.**
Confirmed. `main.client.luau`: `drumSettling` and `splashDone` (323-324) precede their first read
at 327; `maybeShowSplash` (326) precedes its first call at 346. `DrumController.client.luau`:
`SETTLING_S` and `settlingFired` (79-80) precede the heartbeat connection at 157 and the cue
handler at 229; `SETTLING_S` is derived from `GLIDE_SEC` (76) and `DrumStep` (14), both above it.

## The extra check the brief did not ask for: does `wallet` hold the right values?

`maybeShowSplash` reads `wallet.currentStreak` and `wallet.pointsAtStake`. Verified rather than
assumed:

`main.server.luau`'s `onReveal` (lines 347-362) fires `RevealResult:FireClient(player, …)` and
then `fireProfile(player, "local")` for each player inside one loop iteration — same tick. The
client's `RevealResult` handler sets `pendingReveal`; the `ProfileUpdate` handler captures
`pendingReveal.forfeited` from the *pre*-reveal pot and then overwrites `wallet` with the
post-reveal figures. Both land at reveal time, which is at minimum the whole glide (2.0s) ahead of
`drumSettling` and 2.7s ahead of `drumRest`. So the splash reads exactly the values it read
before — just 0.7s earlier.

The one thing that can write `wallet` inside the new 0.7s window is a bank landing there. That
window existed before this change too (it was simply the last 0.7s before `drumRest`), so this is
not a regression, and a bank in that sliver is only reachable by tapping BANK on an unresolved win
from a *previous* round.

## Concerns

**1. The brief's Step 1 test contradicts its Step 3 constant. I kept the constant and corrected
the test's model.** Written exactly as the brief gives it, test 2 fails at
`SPLASH_LEAD_SECONDS = 0.7`:

```
s = (2.0 - 0.7) / 2.0 = 0.65
3s² − 2s³ = 0.718        → not > 0.8
```

The brief's own "~88%" is not reachable from a bare smoothstep at any lead near 0.7 (88% needs
s ≈ 0.79, i.e. a lead of 0.42s). But the drum's glide is **not** a bare smoothstep — it is a
Hermite that carries the spin's velocity into the deceleration
(`DrumController.client.luau:181-183`):

```
θ = θ₀ − D·(3s² − 2s³) − ω·G·(s³ − 2s² + s)
```

With that second term the brief's figure is right. Travel `D` is chosen by `landTargetFor` as the
first detent at least `ω·G/2` below current θ, with detents every π/2, so
`D ∈ [ω·G/2, ω·G/2 + π/2)`. At `s = 0.65`, `ω = DRUM_KICK = 4`, `G = 2`:

| case | D | fraction travelled at the splash |
|---|---|---|
| smallest D (best) | 4.000 | **0.878** — the brief's "~88%" |
| largest D (worst) | 5.571 | **0.833** |

So `0.7` is correct, `> 0.8` is correct, and the *derivation in the test* was the incomplete part.
I kept both the constant and the threshold and rewrote the test to compute the real curve at the
worst-case `D`, with a comment explaining why the bare smoothstep reads only 72% and would
mislead anyone retuning the lead. Test 3 (the choreography is unchanged) and test 1 are verbatim.

The cost: test 2 now hardcodes `ω = 4` (DrumController's `DRUM_KICK` default) in a `src/shared`
spec, so retuning the kick — or the live `DrumKick` attribute diverging far from 4 — would make
this test's arithmetic describe a drum that no longer exists. It is commented as such. The
alternative was a test asserting something false about the machine, which seemed worse. **Flagging
for the owner: if you would rather have 0.42s (a true 88% on the smoothstep alone) than 0.7s, the
constant is the only thing that needs to change** — but 0.7 / 2.75s is what the brief's context,
its constant, and its Studio-gate checklist all say, and the real drum backs it.

**2. Nothing here is provable by an automated gate.** The 982-test suite loads `DrumStep` only.
The behaviour that matters — a cue crossing `EventBus` from a `.client.luau` to another
`.client.luau` at the right instant — is verified in this report by reading, and needs the owner's
Studio pass. The specific things to watch: does the splash land *with* the drum rather than while
it is visibly still turning, and does it still appear on the second and third rounds of a session
(the two latch resets are exactly what would fail silently there).

**3. The `drumSettling` kind is inert in every other listener.** Checked all five other
`EventBus.Cue.Event` handlers (`BellSoundController`, `DrumController`, `FateController`,
`LanternController`, `TheaterController`) — every one guards on `cue.kind` before touching any
other field, so the new kind cannot reach code that would misread it. In particular
`TheaterController` and `LanternController` still wait on `drumRest`, unchanged.
