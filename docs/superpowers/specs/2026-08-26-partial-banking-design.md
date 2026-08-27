# Partial banking — the math, and what it does to the decision

**Question** (owner, 2026-08-26): *"partial banking is interesting, I think, if it doesn't break the
math. Does some mathematically ideal strategy fall out of it? Is sticking with the clean 3ⁿ choice
the best strategy for a player? I wouldn't let them split a point — 14 or 13 banked, never 13.5 —
but I like the idea of letting players manage risk at a more granular level."*

**Short answers, in order:**

1. **The math does not break.** Nothing in the engine requires a pot to be a power of three.
2. ⚠ **Yes, an ideal strategy falls out — but it is a RATIO, not a constant, and that is what saves
   the mechanic.** `f* = (bank ÷ pot + 1) / 4`.
3. ⚠ **And it has a consequence worth the whole document: once your bank is 3× your pot, riding the
   WHOLE pot is optimal.** The dramatic play stays correct for exactly the players most likely to
   make it.
4. **Recommended shape: bank down to a lower rung.** Keeps 3ⁿ exact, keeps integers, stays a
   judgement call.

---

## 1. Does the math break? No.

`nextPot` is `currentPot * 3` with a `0 → 1` special case (`GameRules.ts:11-16`), which is correct
for any integer. `bestPot` milestones test `bestPot >= n`, fine for arbitrary values. The aura's
tier is `log₃(pot)`, continuous already. **The 3ⁿ ladder is a property of the DEFAULT PATH — never
partial-banking — not an invariant anything depends on.**

The real cost of arbitrary pots is legibility, not arithmetic: `27 → 81` reads instantly and
`47 → 141` does not, on a phone, for a kid. §4 keeps the ladder for that reason alone.

## 2. The ideal strategy, derived

Riding a fraction `f` of pot `P` with bank `B`, one round:

| | wealth after | prob |
|---|---|---|
| WIN | `B + P + 2fP` | p_w ≈ 0.30 |
| SAFE | `B + P` | p_s ≈ 0.40 |
| LOSS | `B + P − fP` | p_l ≈ 0.30 |

⚠ **Under pure EV, partial banking changes nothing.** `EV = P(2p_w − p_l) = +0.30P`, linear in the
amount risked, so a risk-neutral player rides everything — which is already the EV-optimal play
today. **EV never says bank, with or without this feature.** Banking is a risk decision; that is why
the game works.

Under **log utility** — the standard model of a risk-averse player — maximise
`p_w·ln(B+P+2fP) + p_s·ln(B+P) + p_l·ln(B+P−fP)`:

```
f* = (B + P)(2p_w − p_l) / (2P(p_w + p_l))     →  at p_w = p_l:   f* = (b + 1) / 4,  b = B/P
```

Verified numerically:

| bank ÷ pot | optimal fraction of the pot to keep riding |
|---|---|
| 0 | 0.25 |
| 0.5 | 0.375 |
| 1 | 0.50 |
| 2 | 0.75 |
| **3 or more** | **1.00 — ride it all** |

### ⚠ Why the ratio is the good news

Had the answer been a constant — *"always ride 25%"* — the mechanic would be dead on arrival. A
single publishable number **solves** a decision that today has no correct answer, and Bank-vs-Stake
is valuable precisely because it depends on a risk tolerance and a crowd read that no wiki can hold
for you.

It is not a constant. Three properties follow, and all three are healthy:

- **It moves with the player's own position**, changing every round as the pot grows and the bank
  fills. There is a formula, but no answer to memorise.
- **The optimum is flat near the top.** At `b=0`, riding a third scores 0.0316 against the optimal
  0.0353 — 89% of the benefit from a coarse, obvious choice. **Being roughly right is nearly as good
  as being exactly right**, so play does not reward calculator work.
- ⚠ **Ride-everything becomes optimal at `b ≥ 3`.** A player with a healthy bank and a modest pot
  *should* send it. So the mechanic does not make the dramatic play wrong — it makes it **earned**,
  and produces a genuine arc: **hedge while you are poor, send it once you are established.**

### The honest caveats

- ⚠ **Log utility is a model, not a fact about children.** Kids are thrill-seekers, not utility
  maximisers. What is robust is the *direction* — more wealth relative to pot → ride more — not the
  exact number.
- ⚠ **The model breaks at the origin.** At `B = 0` it scores riding everything as −∞, because
  `ln(0)` treats a lost pot as ruin. There is no ruin here: throwing is free, rounds are skippable,
  and a player at zero simply plays on. Treat the `b = 0` row as directional only.
- ⚠ **None of this is measurable today.** TEST_MODE runs a fixed R→P→S cycle in both prod and dev,
  so p_w is not 0.30 for anyone who has spotted the cycle. Do not validate any of this in play until
  the plurality rule is actually live.

## 3. What it costs the game

**The pot ladder flattens.** Riding `f` of `P` and winning leaves `3fP`, so the pot only grows when
`f > 1/3`. Under the risk-optimal play of a poor player (`f = 0.25`) **the pot shrinks even on a
win** — 27 becomes 20.25 riding. Deep pots stop occurring for exactly the cautious players, and the
deep pot is what `livePots` and the aura are built around.

This is real but bounded, and §2's `b ≥ 3` result is why: as players accumulate, they move back
toward riding it all, and the deep pots return. **The mechanic makes big pots a late-game
phenomenon rather than abolishing them.** That is a change in the shape of the arc, and it should be
an explicit choice rather than a discovery.

**And it is one more thing to teach.** Onboarding is already deferred and already carries a layout
defect; the bar is *kid-first on phones*. §4 is chosen to keep the teaching cost to one sentence.

## 4. ⚠ RECOMMENDED SHAPE: bank down to a lower rung

Not a slider. **A pot may be dropped to any lower rung of the ladder, with the difference banked.**

| from a pot of 27 | ride | bank | f |
|---|---|---|---|
| ride it out | 27 | 0 | 1 |
| **drop one rung** | 9 | 18 | 1/3 |
| drop two | 3 | 24 | 1/9 |
| drop three | 1 | 26 | 1/27 |
| bank it | 0 | 27 | 0 |

Why this shape:

- ⚠ **Every pot stays a power of three.** The owner's math concern is answered by construction, not
  by rounding: `27 → 9 → 27 → 81` all read cleanly, and the HUD's ×3 stays legible.
- **Integers throughout** — 18 and 9, never 13.5. The owner's rule holds automatically, since every
  difference of two powers of three is an integer.
- **It is a judgement call, not an optimisation.** Three or four discrete options against a
  continuous optimum that moves with your bank — there is nothing to fine-tune, and §2 shows the
  coarse choice captures ~89% of the benefit anyway.
- **One sentence to teach:** *"drop a level, pocket the difference."*
- **It covers the useful range.** `f ∈ {1, 1/3, 1/9, …}` against an optimum spanning 0.25 → 1.00:
  poor players reach for a third, rich players ride it out, and both are close to right.

**What it needs before it could be planned** — flagged, not resolved:

- ⚠ **`stakingStreak` vs the pot after a partial bank.** `bank()` currently zeroes `pointsAtStake`
  and `stakingStreak` together (`wallet.ts:20`). A partial bank leaves a live pot, so what happens
  to the streak is a real ruling — and `currentStreak` (which the shipped aura reads) must not be
  touched either way.
- **`BankEvent` gains a partial flag**, or the bank-depth distribution — the whole Bank-vs-Stake
  story, per `bankDepths` — quietly starts mixing two different decisions.
- **`potDelta` semantics.** Already documented as recording the new pot on a WIN rather than the
  increment; a partial bank is a third kind of pot movement and needs its own row shape or it will
  corrupt earnings analysis the way summing `pointsDelta` already would.

## Raw layer

`server/src/engine/GameRules.ts` (nextPot, potDelta), `server/src/wallet.ts` (bank),
`server/src/models/BankEvent.ts`, `server/src/stats.ts` (bankDepths, livePots),
`docs/wiki/world/core-loop.md`, `docs/wiki/world/world-throw.md`,
`docs/superpowers/specs/2026-08-26-multi-hand-splitting-design.md` (§5a named partial banking as the
cheaper door), `docs/superpowers/specs/2026-08-26-juice-vs-seniority-design.md`.
