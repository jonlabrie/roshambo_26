---
shelf: world
updated: 2026-09-04
checked: 2026-08-27
---

# The World Throw

The premise of the game, and the thing every stat in the [[stats-room]] ultimately measures.
The mechanics it settles — outcomes, pot, banking, the points fields — are [[core-loop]].

## What it is

**The World Throw is the throw MOST players in the round made — the plurality of the tally,
which with three options is often not a majority.** Not random. "Majority" is the product
word and the patent's word; plurality is the implementation (§ As-built, and the claim-construction
question under § Patent basis). Corrected 2026-09-04: this line said "MAJORITY choice" for three
weeks after the page itself recorded that a true majority frequently does not exist.
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

⚠ **Not active in any deployed environment as of the date at the top of this page** — both
services run `TEST_MODE=true`, which keeps the deterministic R→P→S cycle. Since 2026-09-04 the
rule no longer needs a human crowd to be exercised: see § Synthetic crowd below. Whether dev
has been flipped is a live fact — query the service ([[deploy]]), do not trust this line.

## Synthetic crowd (built 2026-09-04)

Spec `docs/superpowers/specs/2026-09-04-synthetic-crowd-design.md`; plan
`docs/superpowers/plans/2026-09-04-synthetic-crowd.md`.

**What it is.** A tally crowd — bot throws that count toward the World Throw and appear in the
reveal's distribution, with no avatars. `RoundEngine` merges the bots' counts into the tally at
LOCK→REVEAL **before** `pickWorldThrow`, so the distribution on the card and the throw it
produced always agree; the per-participant `throws` map stays human-only, which is why bots
never reach settlement, `PlayerRound`, presence or any board. `Round.synthetic` records the
bot count; **`totalPlayers` is the size of the world (humans + bots)** — owner decision
2026-09-04, and the PLAYERS figure on the ledger and the stats board now means exactly that.

**Archetypes** (`server/src/engine/CrowdPolicies.ts`): `wsls` (win-stay / lose-shift-clockwise,
Wang–Xu–Zhou 2014), `counter`, `conform`, `rocky`, `random`, and the sim-only `second`. Each
is a distribution given a small memory, blended with uniform at a strength; the mix across
archetypes is the other dial. ⚠ **A hypothesis about a Roblox crowd, not a measurement.** The
recalibration path is the persisted `Round.distribution` minus the synthetic share (spec §8).

**Config** — `CROWD_SIZE` (0 = off), `CROWD_MIX` (`id:weight,…`), `CROWD_SEED`. Malformed
values refuse to boot. `CROWD_SIZE` under `TEST_MODE=true` is ignored with a warning. A
malformed `CROWD_MIX` or `CROWD_SEED` refuses to boot in **every** mode, `TEST_MODE` included —
so a typo cannot wait for flip day — except when the crowd is switched off outright, which is
`CROWD_SIZE` of zero and skips parsing entirely (ruling 2026-09-04). Read the
defaults from `DEFAULT_MIX` / `DEFAULT_STRENGTH` in `server/src/engine/SyntheticCrowd.ts`
rather than from here.

**The simulator** — `cd server && npm run sim -- --experiment readability|blind-spread|effective-n`.
Re-run it rather than quoting the numbers below; they are one seed on one day.

Readability at the settled default mix (`--rounds 20000 --seed 1`):

```
# readability  rounds=20000 crowd=30 strength=0.7 seed=1
# mix random:20,wsls:30,counter:10,conform:30,rocky:10

human     BEAT WORLD   ±95%    safe    loss    banked      max pot*
random         29.4%   0.6%   40.8%   29.7%    137781        19683
counter        42.2%   0.7%   51.9%    5.9% 6765376709498072000 1350851717672992000
conform         5.9%   0.3%   42.2%   51.9%        27            9
wsls           32.8%   0.7%   46.8%   20.4%  14348907      1594323
second         51.9%   0.7%    5.9%   42.2%    177147        19683
oracle         56.5%   0.7%   26.9%   16.6% 22876792454961 2541865828329
* max pot is measured AFTER each round's bank decision

world throw transitions (n=19999): same 42.2%  counter 51.9%  other 5.9%
(a blind world is 33/33/33; "counter" high means the crowd rotates the way everyone-counters predicts)
```

The `banked` and `max pot` figures for `counter` are past 2^53 and are float approximations
printed as digits, not exact counts — a 52% SAFE rate lets its ratio-banked pot compound almost
without bound in the sim, so read that row as an order of magnitude and nothing finer.

Blind-field spread (`--experiment blind-spread --rounds 360 --seed 1`):

```
# blind-spread  rounds=360 crowd=30 strength=0.7 seed=1
# mix random:20,wsls:30,counter:10,conform:30,rocky:10

20 blind players, bank at 9, 20 runs of 360 rounds
max ÷ median banked: mean 1.43  worst 1.66
per run: 1.57 1.29 1.40 1.66 1.38 1.60 1.50 1.50 1.39 1.40 1.33 1.38 1.38 1.47 1.33 1.29 1.60 1.42 1.29 1.50
```

Effective N (`--experiment effective-n --rounds 5000 --seed 1`):

```
# effective-n  rounds=5000 crowd=30 strength=0.7 seed=1
# mix random:20,wsls:30,counter:10,conform:30,rocky:10

crowd   counter BEAT WORLD   ±95%
    5                13.5%   0.9%
    7                27.1%   1.2%
   10                35.8%   1.3%
   15                28.2%   1.2%
   20                39.7%   1.4%
   30                44.4%   1.4%
   50                48.2%   1.4%
  100                51.7%   1.4%
(where the rate stops moving, the human's own throw has stopped moving the plurality)
```

**How the mix was settled, and against which targets.** Pre-registered before tuning (spec §2):
a simple teachable rule beats the crowd clearly (**BEAT WORLD ≥ 45%**), nothing non-oracle
exceeds **~60%**, and a blind human sits near chance. All three hold at seeds 1–3 — the best
teachable rule (`second`, counter-the-counter) runs 51.4–52.4% across them, and nothing but
`oracle` goes near 60%.

- ⚠ **The blind band is 29–34%, widened from "≈33%" by ruling 2026-09-04**, and the settled
  mix's 29.4% is inside it. A blind human's own throw is inside the tally it is judged
  against, so it drags the plurality toward itself; once the best rule is held under 60% the
  plurality margins are narrow enough that the blind rate sits near 29.5% *whatever* the mix —
  probed across ~40 mix cells and it did not move. The `random` row is a null hypothesis, not a
  design target, and treating it as one would have meant loosening the ceiling that matters.
- **Why the pre-tuning default (`wsls:35,counter:20,conform:15,rocky:10,random:20`) was too
  readable:** `wsls`'s lose-shift is *clockwise*, which lands on the counter-throw — so `wsls`
  and `counter` pull the world the same way and their signals compound. Raising `conform`
  rather than adding `random` was the fix: it opposes the rotation instead of blurring it.
- Consequence, and expected: `conform` is now a near-dead rule (~6% BEAT WORLD). It only wins
  on the rare "other" rotation, which the transitions line puts at ~6%.

**Pre-registered Q1** (owner decision 2026-09-04): one person, ~20 rounds on dev against the
default crowd with the last-five HUD; **≥ 45% BEAT WORLD** reads as "crowd-reading is a skill
here"; a rate down in the blind band (29–34%, above) means the crowd is too noisy or the HUD
shows the wrong thing. Result: not yet run.

Read a ~42% result as progress, not failure. At the settled mix the naive HUD reading —
`counter`, throw what beats the last World Throw — scores ~42.2%, just under the 45% line; the
rule that clears it is `second`, throw what the last World Throw *beat*, i.e. counter the
counter. A first-time human will almost certainly try `counter` first, so ~42% means they found
the first rule and not yet the second, and the question Q1 actually asks is whether the second
one is findable.
