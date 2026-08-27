# Multi-hand splitting — evaluated and rejected

**Proposal** (owner, 2026-08-26): up to 3 "working hands", not unlike splitting aces in blackjack.
A player who reaches a 3- or 4-streak may **park** that hand — leaving it unexposed — and start
building a new one with fresh throws, choosing each round which hand to aim at, and holding the big
one back for a round they feel lucky. The glow would show the longest hand.

**Verdict: NO.** The owner asked for brutal honesty rather than support, so, plainly: this is not a
tuning risk or a complexity concern. **It structurally removes the Bank-vs-Stake dilemma, which is
the only decision Roshambo has.** Two things in it are genuinely right and both are already served
elsewhere; they are in §5.

---

## 1. First, the fact that makes staking a risk decision rather than an EV decision

With p(win) ≈ p(loss) ≈ 0.30 under the plurality rule, exposing a pot of P for one round:

```
EV = 0.30·(+2P)  +  0.40·(0)  +  0.30·(−P)  =  +0.30P
```

⚠ **Staking is always positive-EV, and the EV is LINEAR IN THE POT.** It is positive whenever
2·p(win) > p(loss), which holds for any roughly symmetric crowd. So a risk-neutral player would
*never* bank and would always expose their largest pot.

**Banking is therefore not an EV decision — it is a risk-management decision**, and the game works
because a human holding 27 points does not feel risk-neutral. That tension is the product. Every
consequence below follows from it.

## 2. The mechanical objection: PARKING IS A FREE OPTION

Bank-or-Stake is a dilemma *only because there is no third choice*:

| | keeps the pot | risk-free | can still grow |
|---|---|---|---|
| **Bank** | no — converts it | yes | no |
| **Stake** | yes | no | yes |
| **Park** | **yes** | **yes** | **yes** |

⚠ **Park dominates both existing options on every axis**, at no cost. The only thing banking still
offers over parking is spendability, which is not urgent for a player who is not currently shopping.
A player never has to resolve the dilemma again: they park at whatever number makes them nervous and
go grind a fresh hand.

**The predicted equilibrium, stated so it can be checked rather than argued:**

1. Build a hand to the depth that starts to feel frightening — 27 for most people.
2. Park it. Zero risk, still growable later.
3. Repeat until all 3 slots hold parked pots.
4. Bank one to free a slot. Repeat forever.

**That converts Roshambo from a press-your-luck game into an accumulation game.** Press-your-luck —
blackjack, Deal or No Deal, Balatro's blinds — depends entirely on the moment you *cannot avoid*
choosing. Remove that moment and the genre goes with it.

⚠ **And it has a concrete, checkable casualty: `stats.livePots` goes permanently quiet.** That board
exists for exactly one reason, in its own words — *"someone is holding 243 points right now and has
to decide… a streak says how far someone has come, a pot says what they stand to lose, and the
second is the one with a decision attached."* Under parking, **nobody is ever holding a big pot at
risk**, because the rational move is to park it the moment it gets interesting. The single loudest
number in the game stops occurring.

## 3. Why the blackjack analogy does not carry

Splitting aces works because of four properties, and Roshambo has none of them:

| blackjack | Roshambo |
|---|---|
| you hold **two cards** — real objects to separate | one throw per round; there is nothing to split |
| each split hand draws **independently** | ⚠ **there is ONE World Throw, shared by every hand and every player** |
| splitting **costs a second bet** — exposure doubles | parking costs nothing |
| a decision at a known moment under known odds | persistent state you sit on indefinitely |

The second row is the deepest. A split in blackjack is meaningful because the two hands receive
different cards. Here, any two hands resolved in the same round resolve against the *same* World
Throw — so "which hand do I aim at" carries **no information the player can act on**. It is not a
read, not a bluff, not a tell. It is pure risk allocation, and §1 shows the risk-neutral answer is
always "the biggest", so the mechanic only ever engages risk aversion. In practice everyone parks.

### ⚠ And the obvious "improvement" is mathematically catastrophic

The natural next proposal is to let a player throw at all three hands each round with different
throws. **Do not.** With three options and three hands, R/P/S across them guarantees **exactly one
WIN, one SAFE and one LOSS every single round, deterministically.** All variance and all skill
vanish; the game becomes an annuity. The three-outcome structure is only a game because a player
gets one throw.

It also breaks a settlement invariant: `Settlement.ts` states *"each resolved user appears at most
once per round"*, and the engine collects one seq-guarded upsert per player. Multi-throw is not a
feature addition there; it is a rewrite of the round contract.

## 4. Secondary costs, which would matter even if §2 did not

- **The glow becomes a static badge again.** If it shows the best parked hand, it displays a number
  held at will, at no risk, indefinitely — monotonic and durable, which is the rank failure that
  killed four designs (juice spec §2). Four turns of aura design would be undone by the feature it
  is meant to decorate.
- **A target selection per throw**, inside a 51s OPEN window, on a phone, for a kid-first product.
- **Onboarding**, already deferred with a known layout defect, would have to teach a three-pot model
  before a player has understood one pot.
- **Every points surface** — HUD, stats room, the 番付 boards, `livePots`, `bestPot` — currently
  assumes one pot per player.

## 5. What is genuinely right in it — and where each part is already served

Two real insights, and neither needs this mechanic.

**(a) Confidence-weighted bet sizing is a real missing dimension.** If crowd-reading is genuine
skill then a player's confidence varies round to round, and being able to size exposure to
confidence is a legitimate, deep mechanic. This is the strongest argument for the proposal and it
should not be dismissed.

But **Bank-vs-Stake already is that mechanic**, in coarse form: bank when unsure, ride when
confident. Multi-hand adds granularity at the cost of §2. ⚠ **If the goal is finer sizing, PARTIAL
BANKING is the cheaper shape** — bank half, ride the rest — because it keeps the cost of safety
intact (you give up growth on what you took) instead of offering safety for free. It has its own
problem — it breaks the clean 3ⁿ ladder — and deserves its own evaluation rather than a mention
here. **Named as the better door, not as a recommendation.**

**(b) "A big run should leave something behind" is correct — and the decaying peak already does it.**
The emotional pull of parking is that building to 27 and losing it in one round leaves nothing to
show. That instinct is right, and it is exactly what the decaying peak was designed for: the peak
you *reached* persists after the pot dies, cannot be taken by a loss, and is refreshed by matching
it. **The display already grants what parking was reaching for, and it grants it without touching
the rules.**

## 6. If it is pursued anyway, the one thing that must change

Every workable variant prices the option, because a free option is the whole defect:

- parking forfeits a fraction of the pot, or
- parked hands decay, or
- a parked hand must eventually be thrown at and cannot be banked directly.

Each restores a cost to safety. Each also adds a rule to a game whose bar is *kid-first on phones,
hangout is the product* — to buy a dimension that §5(a) says is already present in cruder form.
⚠ **That trade is the whole decision, and it should be made explicitly rather than discovered after
the HUD has been rebuilt for three pots.**

## Raw layer

`server/src/engine/GameRules.ts` (nextPot, the 3ⁿ ladder), `server/src/engine/Settlement.ts`
(one row per player per round), `server/src/wallet.ts` (bank), `server/src/stats.ts` (livePots and
its rationale), `docs/wiki/world/core-loop.md` (Bank vs Stake), `docs/wiki/world/world-throw.md`
(one shared World Throw), `docs/wiki/program/friends-family-baseline.md` (the bar),
`docs/superpowers/specs/2026-08-26-juice-vs-seniority-design.md`,
`docs/superpowers/specs/2026-08-26-time-windowed-values-design.md`.
