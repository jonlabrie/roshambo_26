---
shelf: world
updated: 2026-08-16
---

# The World Throw

The premise of the game, and the thing every stat in the [[stats-room]] ultimately measures.
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

## As-built

**The majority rule is implemented** (2026-08-16). `GameRules.deriveWorldThrow` derives the
World Throw from the round's own tally, wired at the composition root; `RoundEngine` already
handed the counts to `pickWorldThrow`, so nothing else had to change. Held to
`shared-fixtures/game-rules.json` (`worldThrowDerivation`), 9 cases.

**It is PLURALITY, not majority.** With three options a true majority (>50%) frequently does
not exist — R 40 / P 35 / S 25 has none — so the rule is argmax. "Majority" is the product
word; plurality is the implementation.

Two deliberate fallbacks to random:

- **A tie for top** picks randomly among the tied only — never a throw nobody made.
- **Below `WORLD_THROW_MIN_PARTICIPANTS` (default 5, env-tunable)** the crowd is too small to
  be a world. At small N a player's own throw is decisive: joining either side of a 2–2 split
  *creates* the plurality they needed to beat, so they can only draw. A solo player would set
  the World Throw single-handedly and be permanently SAFE.

⚠ **Not active in any deployed environment.** `apprunner.yaml` sets `TEST_MODE: "true"` for
prod, and `roshambo_server_dev` is likewise in TEST_MODE (owner, 2026-08-16) — both keep the
deterministic R→P→S cycle. The rule will not be exercised until TEST_MODE is turned off, which
needs a crowd: below 5 participants it falls back to random anyway. A synthetic crowd is the
likely route, and its bots must have READABLE PATTERNS — a uniformly random bot crowd produces
a random plurality and reimplements the old defect.
