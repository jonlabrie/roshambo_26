---
shelf: world
updated: 2026-08-16
checked: 2026-08-31
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

The game implements **US 8,025,570 B2** — "Massively multiplayer game method and system",
inventor **Jon Edgar Labrie**, filed 2004-02-23, granted 2011-09-27. Google Patents lists it
as active, expiring **2027-12-11** (⚠ from Google Patents, not verified against USPTO).

**What the claims actually cover.** The claim is broad in most respects: it recites selecting
an item from a set by three or more players, transmitting to a server, the server designating
an item "based on all the selected items received", and a *generic cyclic dominance rule-set*
over an ordered set {X1…Xn} — so it is not limited to rock-paper-scissors, nor to three
options. That breadth is the patent's strength.

⚠ **The narrow part is how the item is designated, and it says MAJORITY.** Both independent
claims — **1 and 6** — close with the same limitation:

> "wherein the designated item is the item selected by a **majority of players**"

**The specification offers no alternative method.** Checked 2026-08-16 for the language that
would open it up ("alternatively", "in another embodiment", "predetermined criteria", "other
methods", "not limited to") anywhere near the designation step: there is none. Every passage
reinforces the one method — *"The option chosen by the majority of players is called the
'Majority' throw."*

**"Plurality" appears in the patent only as the term of art for "more than one"** — "a
plurality of edge server devices", "a plurality of devices". It is never used to mean "the
most votes".

**The tension this creates with the implementation.** [[core-loop]] designates by PLURALITY
(argmax), because with three options a strict majority (>50%) frequently does not exist —
roughly uniform play puts each option near 33%. Under a literal reading of claim 1 the server
would have nothing to designate in most rounds. That cuts both ways: it is a genuine question
mark over whether the claims cover the shipped product, and it is simultaneously the strongest
argument for construing "majority" broadly, since a construction that renders the invention
inoperable most of the time is disfavoured.

**⚠ OPEN — needs a patent attorney, not an engineering judgement.** Claim construction is a
legal question and this underpins the product's exclusivity. Facts worth putting in front of
counsel, all of which bound the options:

- A **broadening reissue** must be filed within two years of grant (35 U.S.C. §251); grant was
  2011-09-27, so that window closed in 2013.
- A **continuation** requires a pending parent application.
- Expiry is ~16 months out as of 2026-08, which bounds what this is worth spending on.

**Do not quietly align the code to a guess.** `GameRules.deriveWorldThrow` is one pure
function with fixture cases, so the designation rule is cheap to change once there is advice.
Changing it on an engineering hunch would be worse than leaving it.

Full text: `https://patents.google.com/patent/US8025570B2/en`. One formula in the rendered
claim ("0<p<(n+½)") looks garbled in transit and should be read from the original before
anyone relies on it.

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
