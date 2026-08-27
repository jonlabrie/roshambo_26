# Task 5 — Sequence the beat

**Status: complete.** `roblox/src/client/main.client.luau` only (plus the `aux` contract comment in
`HudController.client.luau`). Gates: 984 Luau tests pass, `stylua --check src tests tools` clean,
`selene src tools` 0 errors / 0 warnings.

## What changed

`RevealBeat` is now required by `main.client.luau`. Three new locals sit together in one commented
block, declared immediately after `revealedWorldThrow` — which is above `publish()` (needs
`worldThrowFading`), above `maybeShowReveal` and above the `RoundUpdate` handler, so every local is
above its first use:

```lua
local beatGen = 0
local worldThrowFading = false
local beatInFlight: { roundId: string?, result: string? }? = nil
local function landTape() ... end
```

`landTape()` is the tape half of the reveal, and the *only* writer of `badgeById[roundId]` and
`revealedRoundId`. It reads the flight record and clears it, which is what makes it idempotent: the
beat's own scheduled landing and a collapse racing it can never both emit the tile, and neither can
skip it.

At drum rest, `maybeShowReveal` keeps immediate: `lastRound`, `revealedWorldThrow = p.worldThrow`,
the first-win onboarding beat, the splash, `publish()`, `publishLedger()`. It now also opens the
beat — `landTape()` (defensive, see below), `beatGen += 1`, `local gen = beatGen`, `beatInFlight =
{ p.roundId, p.result }` — and schedules two `task.delay`s, each returning early when `gen ~=
beatGen`:

- `HOLD_SECONDS` (2.0): `worldThrowFading = true`; `publish()`.
- `TAPE_DELAY_SECONDS` (2.4): `landTape()`; `revealedWorldThrow = nil`; `worldThrowFading = false`;
  `publish()`.

`publish()`'s `aux` gained `worldThrowFading = worldThrowFading` beside `worldThrow`. Until this
commit the fade branch in `HudController.setRingGlyph` was dead code; it is live now.

The `RoundUpdate` ACTIVE branch collapses the beat, in this order, replacing the bare
`revealedWorldThrow = nil`:

```lua
landTape()               -- release the tile NOW; no-op if the beat already landed it
revealedWorldThrow = nil
worldThrowFading = false
beatGen += 1             -- the pending task.delays now find a stale gen and do nothing
```

Nothing between those lines yields, so the order is a reading order rather than a race. The collapse
does **not** read `pendingReveal` — `maybeShowReveal` nils it when the beat starts, so a collapse
that reached back for it would find nil and drop the tile silently.

The defensive `landTape()` at the top of the beat covers the one case the collapse cannot: a second
reveal delivered with no ACTIVE in between would overwrite `beatInFlight` on the next line. Nothing
should be able to do that (`drumAtRest` is only re-armed at ACTIVE), but a dropped tile is the one
failure here that never repairs itself, so it costs a line and buys the invariant outright.

Three stale comments were corrected rather than left to mislead: the header's description of the
drum-rest gate, `visibleTape`'s (its *test* is unchanged — `currentRoundId ~= revealedRoundId` —
but what it now holds the tile back for is the beat, not the spin), and `lastRound`'s reference to
"the badge below", which no longer sits below it.

## The `aux` contract comment

Updated at the top of **both** files. `main.client.luau`'s was two fields stale — it named neither
`profileSeen` (shipped rounds ago) nor `worldThrowFading`. Both now read the same shape, and
HudController's spells out the timing so a reader of either file learns that the newest tape tile
arrives a beat *after* `worldThrow` does, not with it.

## The trace — the tape tile is emitted exactly once on every path

Round N. `landTape()` is the sole emitter, and it can only emit when `beatInFlight` is non-nil,
which it sets to nil as it emits.

1. **Normal completion.** t=0 drum rest: flight record set, glyph shows opaque, splash fires; the
   tile is still withheld by `visibleTape` because `revealedRoundId` is still N−1. t=2.0: fade flag
   set, HudController tweens `GroupTransparency` to 1 over 0.4s. t=2.4: `landTape()` emits (badge +
   `revealedRoundId = N`), record cleared, glyph cleared. The later ACTIVE calls `landTape()` on a
   nil record → returns. **Emitted once, at 2.4s.**
2. **Collapse before the fade starts** (ACTIVE at t < 2.0). `landTape()` emits at once; ring
   cleared; `beatGen` bumped. The HOLD delay at 2.0 finds a stale `gen` and returns without setting
   the fade flag over the new round; the TAPE delay at 2.4 finds a stale `gen` and does not emit.
   **Emitted once, at the collapse.**
3. **Collapse mid-fade** (2.0 ≤ t < 2.4). The fade flag was already set and a tween is running.
   `landTape()` emits at once. Clearing `revealedWorldThrow` makes the next `publish()` call
   `setRingGlyph(nil, false)`, which cancels the tween and hides the group; the next beat sets
   `GroupTransparency = 0` explicitly, so a half-faded group cannot persist into it. The TAPE delay
   returns on the stale `gen`. **Emitted once, at the collapse.**
4. **Collapse after the tape already landed** (t ≥ 2.4). The record is already nil, so the
   collapse's `landTape()` returns immediately — no second write to `badgeById` or
   `revealedRoundId`. **Emitted once, at 2.4s.**
5. **Dropped `drumRest`, released by `REVEAL_SAFETY`.** The safety delay still guards on
   `pendingReveal.roundId == roundId`, sets `drumAtRest = true` and calls `maybeShowReveal`, which
   opens the beat exactly as at a real rest — just with a later origin, and every step still
   measured from that origin, so nothing reflects the world throw before the release. On the
   measured timings the beat still completes normally: the reveal remotes land ~3s before the drum
   settles, so `REVEAL_SAFETY` (3s) fires within ~0.2s of where the real rest would have been,
   leaving the ~3.8s runway and the beat finishing with ~1.4s to spare. If the release ever came
   later than that, the next ACTIVE collapses it and path 2/3 applies. **Emitted once, either at
   2.4s after the release or at the collapse — never both, because the flight record gates it.**

One pre-existing path, unchanged by this task and worth stating so it is not mistaken for a
regression: if ACTIVE arrives *before* the safety fires, the ACTIVE branch nils `pendingReveal`, the
safety's guard fails, and no beat ever starts — so `beatInFlight` is nil and the collapse's
`landTape()` is a no-op. That round gets no personal badge, but no hole appears in the tape: the
world-throw entry itself is server-carried, and `visibleTape`'s skip has already stopped applying to
it (its id is no longer `currentRoundId`). This client simply never revealed that round at all —
no glyph and no splash either — so the missing badge is consistent with what the player saw.

## What no gate can check

The glyph appearing at all. `Visible = true` is not pixels, and that substitution already let this
exact glyph be reported as working while invisible. Nothing here is verifiable by any automated
gate; the owner's Studio gate is the only real check. What needs eyes is in the brief's closing
section — chiefly whether a cream R/P/S actually shows on the dark disc, whether 2s reads as a
hold, and whether the tape tile lands as a separate beat afterwards.
