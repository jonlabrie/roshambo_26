---
shelf: world
updated: 2026-08-16
---

# The World Throw

The premise of the game, and the thing every stat in the Stats room ultimately measures.
The mechanics it settles — outcomes, pot, banking, the points fields — are [[core-loop]].

## What it is

**The World Throw is the MAJORITY choice of the players in the round.** Not random.
Roshambo is "you against the world" — a single player versus the aggregate crowd — and
that framing is the product. Owner, 2026-08-16: *"we have to successfully embody 'the
majority' as a worthwhile opponent or we'll fail entirely."*

Consequences that follow, and that any design must respect:

- **Reading the crowd is genuine skill**, exactly as reading an opponent is skill in
  two-player RPS after several throws. Outcomes are not fortune.
- **This is why the HUD shows the last five rounds.** If the World Throw were random
  that history would be information-free. It is shown because it is *predictive*.
  See [[round-and-hud]].
- **Throwing the majority is SAFE** (pot preserved, streaks reset), so conforming to the
  crowd is a hedge and defecting from it is the play for gain. Conformity vs
  contrarianism is therefore a real, measurable player style, not a flavour label.
- Perfect collective prediction is self-defeating: if everyone counters last round's
  majority, that counter *becomes* the majority. The equilibrium rotates, which is a
  Keynesian-beauty-contest depth-of-reasoning game.

## Patent basis

The game implements **US 8,025,570 B2**, a patent **owned by the owner (Jon Labrie)**,
which confers roughly a year of exclusivity as of 2026-08. This is load-bearing for
product strategy, not trivia. Full text:
`https://ppubs.uspto.gov/api/patents/html/US-8025570-B2?source=USPAT` (the owner's link
carried a request token that will expire).

## As-built ⚠ diverges from the premise

The shipped server does **not** implement the majority rule yet — see the divergence
logged in [[parked-defects]]. `server/src/engine/RoundEngine.ts` picks the World Throw
randomly, and `TEST_MODE=true` substitutes a deterministic R→P→S cycle (the dev and
demo behaviour today, including playroshambo.com). `Round.distribution` already persists
the per-round R/P/S split, so the majority is recorded every round — the rule simply is
not read from it.

Treat the majority rule as the design truth and the random pick as an unfinished
implementation, NOT as "the code is the source of truth" on this point.
