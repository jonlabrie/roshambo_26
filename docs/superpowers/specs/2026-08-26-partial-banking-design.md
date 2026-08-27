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
- ⚠ **p_w = 0.30 is derived, not observed.** Under TEST_MODE's fixed R→P→S cycle it is not 0.30 for
  anyone who has spotted the cycle, so the *tuning* numbers here are unvalidated. **This does NOT
  make the mechanic untestable** — see §5.

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

## 5. ⚠ TEST_MODE IS A TEST AFFORDANCE, NOT A BLOCKER — a correction

⚠ **This document, and three others, cited TEST_MODE as though it made partial banking
untestable. That was wrong, and the owner corrected it:** *"how am I meant to test functionality of
win-streaks in a non-deterministic system without having to wait for said streaks to fall out of the
randomized sky?"*

Exactly right, and it inverts the claim. **Two different questions were being collapsed into one:**

| question | what it needs | status |
|---|---|---|
| **does it work?** — the pot math, the rung snap, the streak rules, the row writes | **DETERMINISTIC outcomes**, so any streak can be constructed on demand | ⚠ TEST_MODE is the RIGHT tool, not an obstacle |
| **is it tuned right?** — is p_w really 0.30, does the ratio bite | real crowds, 10+ players | not ready, and not the question |
| **do players use it?** | shipping to friends & family | a product question, not a test |

**A randomised World Throw would make the first question HARDER**, not easier — testing a 4-streak
would mean waiting for one to occur by chance, which is precisely the wrong way to test a
deterministic rule. The fixture-driven suites (`shared-fixtures/game-rules.json`, gating three
implementations) are the same principle already in force: **rules are tested against constructed
cases, never against sampled play.**

**So the correct statement is narrow:** the *numbers* in §2 cannot be validated until the plurality
rule is live and crowds are real. The *mechanic* can be built and tested today, TDD as usual, and
its tests belong in the fixture rather than in a play session either way.

## 6. What actually depends on `BankEvent` and `pointsDelta`

The owner asked, having ruled on the first open question: *"Not sure about BankEvent vs. bankDepths
because I'm not sure what relies on them. Same for potDelta."* Traced:

### `stakingStreak` — RULED, and it is clean

Owner: *"we don't zero stakingStreak if the pot isn't zeroed."* So the condition moves from *"a bank
happened"* to *"the pot reached zero"*, which makes a full bank behave exactly as today and needs no
special case for the partial one. `currentStreak` is untouched either way, as it is now.

⚠ One consequence to note rather than fix: a player can hold a long `stakingStreak` while having
hedged down to a pot of 1. `stakingStreak` is not displayed anywhere today — the aura reads
`currentStreak` — so this is an analytics nuance, and §6's `partial` flag is what keeps it from
becoming a reporting error.

### `BankEvent` — ONE REAL CASUALTY, and it is a shipped display

`BankEvent` has five consumers:

| consumer | what it does | affected by partial banks? |
|---|---|---|
| `stats.heatBoard` | sums `amount` over a window — the earnings board | **no** — a partial bank is real earnings |
| `leaderboards.earningsInWindow` | same sum, per player | **no** |
| `stats.biggestBanks` | records board, shows `amount` + `streakAtBank` | mild — a partial bank is a smaller amount, so it self-sorts |
| `stats.bankDepths` → `depthHistogram` | ⚠ **the NERVE stat** | ⚠ **YES — this is the one** |
| `StatsFixtures.luau` | Roblox test fixtures | fixture update only |

⚠ **`bankDepths` is NERVE, and it is on the wall in the 番付 room** — a room-wide histogram
(`statsV1.ts:170`) and a personal median (`:193`). Its own comment states the intent: *"how deep a
player rides before collecting… the whole bank-vs-stake story lives in the distribution of this
number."*

**A partial bank writes `streakAtBank` too, and it means something different.** A player who drops
one rung at streak 6 and keeps riding records the same `6` as a player who cashed out entirely at
streak 6 — but one of them quit and the other hedged. The histogram would silently blend *"when do
players stop"* with *"when do players hedge"*, and NERVE would stop measuring what its comment says
it measures. **No error, no test failure, just a stat that quietly becomes about something else.**

**Fix: one boolean.** `BankEvent.partial`, and `bankDepths` filters to full banks. Cheap now,
impossible to reconstruct later — the rows would already be mixed and indistinguishable, exactly the
retroactive-gap shape as the missing `PurchaseEvent`.

### `pointsDelta` — needs NOTHING, and this document overstated it

⚠ **A partial bank is a WALLET action, not a round outcome.** Banking today writes a `BankEvent`
and no `PlayerRound` row (`wallet.ts`), and a partial bank is the same shape. Settlement keeps
computing `potDelta(pointsAtStake, result)` from whatever the pot is at that moment, so:

- **`stats.biggestRounds`** (WIN rows, "the pot reached") — still exactly correct.
- **`stats.ts:91` forfeits** (the one place the column may be summed, over LOSS rows) — still
  correct: it reports what was actually lost, which a hedger has made smaller on purpose.
- **PWA per-round banner** (`VideoArena`, `ArenaVisuals`, `RiveArena`, `useGameLoop.ts:368`) and the
  `socketAdapter` big-wins feed — unaffected.

**So the third open question dissolves.** The only nuance worth stating: a player who hedges reaches
smaller pots thereafter, so their peaks are smaller. ⚠ **That couples partial banking to the aura**,
whose proposed metric is the peak pot reached — hedging dims you. It does **not** violate the
Bank-vs-Stake neutrality rule, because nothing already achieved is taken away; it only means future
peaks come slower, which is equally true of full banking. Worth knowing before ruling on either
feature, since the two now touch.

## Raw layer

`server/src/engine/GameRules.ts` (nextPot, potDelta), `server/src/wallet.ts` (bank),
`server/src/models/BankEvent.ts`, `server/src/stats.ts` (bankDepths, livePots),
`docs/wiki/world/core-loop.md`, `docs/wiki/world/world-throw.md`,
`docs/superpowers/specs/2026-08-26-multi-hand-splitting-design.md` (§5a named partial banking as the
cheaper door), `docs/superpowers/specs/2026-08-26-juice-vs-seniority-design.md`.
