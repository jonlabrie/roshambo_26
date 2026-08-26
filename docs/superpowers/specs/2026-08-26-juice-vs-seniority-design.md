# Juice vs Seniority — does seniority deserve its own carrier?

**Question** (owner, 2026-08-25, on watching the shipped aura): *"who cares about auras if only 2
or 3 are ever even visible on your server? We're either measuring the right thing badly, or
measuring the wrong thing."* Two candidates were named — **juice** (points on the line now) and
**seniority** (personal best win-streak, independent of betting).

**Verdict: NO. Seniority does not get a carrier.** It is already in grade, and grade already has an
answer. The owner's observation is correct and the arithmetic below confirms it exactly — but the
fault is in the *juice* half, not a missing seniority half.

⚠ **The juice half took a wrong turn first, and §4 is the part worth reading.** This document
originally proposed re-keying the aura to `pointsAtStake`; the owner rejected it on the spot
because a risk-level display **discourages play**. That rejection generalises into a standing rule
— *the aura must be neutral on Bank vs Stake* — which retires three metrics including the one
currently shipped, and it is the most transferable thing here.

**Status:** design-thread recommendation. §1–3 (seniority) is a closed argument. §4 is a recorded
owner rejection plus the rule it produced. §5 is a PROPOSAL and nothing should be built for it
until it is ruled on — the aura is gated (2026-08-26) and this changes the number it reads.

---

## 1. Seniority is not "closer to grade". It IS grade.

`bestStreak` is not merely a field that happens to be durable. It is already one of five milestone
families in the grade catalog:

```
const RUN_STEPS = [3, 5, 7, 10];
...RUN_STEPS.map(n => ({ id: `run.${n}`, earned: s => s.bestStreak >= n })),
```
`server/src/engine/Milestones.ts:31,39`

A milestone count drives `gradeFor` → grade index → band → the five familiars the unlock model
hands out. So a player's personal best win-streak **already flows into the one status channel the
project has decided on.** Giving it a second, independent carrier would mean the same `run.N`
events drive two displays that disagree — grade also counts `pot.*`, `career.*`, `first.*` and
`presence.qualified`, and a seniority glow would count none of them. Two rankings on one body, from
overlapping inputs, is worse than one.

This is the strongest form of the answer and it was available in the code the whole time: seniority
does not need a home, it has one.

## 2. Durability is the property that killed the last four designs — not Japan.

Four status displays were rejected between 2026-08-21 and 2026-08-25. It is tempting to read the
chain as ending on the culture constraint, but the culture ruling retired a *shape*; the failure
underneath is older and independent.

| rejected | stated reason | the property that actually failed |
|---|---|---|
| plumage band on the familiar | too small to read at arena distance | legibility |
| worn sashimono | *"a bit on the nose for an experience meant to be social"* | **durable rank, worn by everyone** |
| HUD sashimono | the martial read is in the shape | same, relocated |
| worn crest | ⚠ the avatar travels into a Chinese-themed area | culture |

The 2026-08-25 ruling that resolved it says why: *"A badge everyone must wear is a ranking; a rare
thing you may choose is a flex. Same information, opposite social feel — and it is why every worn
answer failed."*

⚠ **A seniority aura is a durable rank worn by everyone.** It is the sashimono's failure mode in a
culture-neutral wrapper. The shipped aura escapes that rule only because it is transient live state
— it comes and goes, so it reads as *what you are doing*, not *what you are*. Make its input
monotonic and it stops being an event and becomes a stripe.

**The visibility toggle does not rescue this.** `StreakAura.VISIBILITY` already offers
HIDDEN/FRIENDS/PUBLIC, so a seniority aura could be switched off — but opt-OUT is not opt-IN. Under
a rank, a low-seniority player chooses between displaying a low rank and conspicuously hiding, and
both read as low. Under the unlock model they simply fly the starter bird, which is the neutral
default everyone starts from. **Unlocks have a dignified floor; ranks do not**, and a hangout needs
the floor more than it needs the ceiling.

## 3. The density arithmetic — the owner's "2 or 3" is exact, and seniority is bimodal.

Derived, not measured (⚠ nothing about streaks is measurable today: both prod and dev run TEST_MODE,
so the World Throw is a fixed R→P→S cycle and outcomes reward memorising it). Under the shipped
plurality rule with roughly uniform play, the argmax bucket is by construction the largest, so it
takes ~38–40% (those players go SAFE) and WIN and LOSS split the remainder at **p ≈ 0.30** each.

**What the aura shows today** — `currentStreak >= 2` (`StreakAura.luau:22`):

> P(streak ≥ 2) = p² ≈ **0.09**. On a 30-player server: **2.7 players glowing.**

That is not an impression the owner formed on a thin sample. It is the design's own number, and it
is what they counted.

**What a seniority threshold would show.** Expected rounds to a first N-run at p = 0.30 is
(1 − pᴺ) / (pᴺ(1 − p)), and a round is ~60s:

| threshold | expected rounds | ≈ play time | who displays it |
|---|---|---|---|
| bestStreak ≥ 3 | ~51 | ~50 min | **nearly everyone who returns** |
| bestStreak ≥ 5 | ~590 | ~10 hours | **almost nobody in friends & family** |

⚠ **Seniority has no usable middle.** It goes from a uniform everyone wears to a lottery almost
nobody holds, across one step — and the two thresholds bracketing that gap are `run.3` and `run.5`,
the milestones that already exist. A signal everyone displays carries no information; that is the
same failure as one nobody displays, arrived at from the other side. The rarity complaint would be
*inverted*, not solved.

## 4. `pointsAtStake` is NOT the number — and the rule that says why

⚠ **REJECTED BY THE OWNER, 2026-08-26, and the rejection is more important than the proposal was.**
This document first argued for re-keying the aura to `pointsAtStake` on density grounds. Owner:
*"pointsAtStake is NOT the number; I don't want to lean into 'current risk level' being what kids
are relying on for flex because it DISCOURAGES PLAY. If you get to an impressive AURA level, why
risk it, and why bank it?"*

Correct, and the failure is worse than stated. **Rounds are skippable and unthrown players are
never settled** — `settleRound` iterates `data.throws` only (`server/src/engine/Settlement.ts:89`),
so a player who stops throwing keeps their pot, their streak and their aura indefinitely. Under a
pot-keyed aura the glow-optimal strategy is therefore: reach a deep pot, then **stop playing**.
Every available action dims you — bank clears the pot, a loss clears the pot — and the only move
that never dims you is leaving the game. An aura that pays people to go idle in the arena is a
worse outcome than an aura almost nobody can display.

### ⚠ THE STANDING RULE: THE AURA MUST BE NEUTRAL ON BANK vs STAKE

Bank-or-Stake is the only real decision in Roshambo (`docs/wiki/world/core-loop.md`). **Any metric that either branch
of that decision changes puts a thumb on the scale of the choice the game exists to pose.** Three
instances of the same error, now:

| metric | what it pays you to do | verdict |
|---|---|---|
| `stakingStreak` | never bank | dropped 2026-08-26 — *"banking is THE decision"* |
| `pointsAtStake` | never bank **and never throw** | dropped 2026-08-26, this document |
| `currentStreak` (shipped) | never throw once you are glowing | ⚠ see below — the same trap, weaker |

**Test every future proposal against both branches before anything else.** If banking lowers it,
it discourages banking. If losing lowers it, it discourages throwing — because not throwing is
always available and always safe. A metric must be untouched by both.

### ⚠ This indicts the shipped aura too, and that is a finding, not a footnote

`currentStreak` is decision-neutral on banking — which is exactly why 2026-08-26 chose it, and that
part was right. But it is **not** neutral on throwing. A player glowing at a 6-streak preserves that
glow forever by not throwing, and any throw risks it. The trap is weaker than the pot version (a
streak is not visibly money, and the aura is rare enough that few players are ever in the trap) but
it is the same shape, and it is live in the gated build. Not urgent; worth knowing before the next
change to that file.

## 5. What a safe metric has to look like

The constraint set is now tight enough to be generative. A carrier must be:

1. **Decision-neutral** — unchanged by banking, unchanged by losing (§4).
2. **Dense, with a gradient** — a meaningful share of the arena lit, most faintly, few brightly.
   This is the owner's original complaint and it is unanswered by everything so far.
3. **Not a rank** — not monotonic-and-durable, or it becomes the badge that failed four times (§2).
4. **Reachable tonight** — a new player must be able to have one, or the display is tenure.

Constraints 1 and 3 look contradictory and that is the whole difficulty. Anything that can go DOWN
creates a hold trap; anything that cannot go down is a rank. **The way out is a metric that decays
with TIME rather than with outcomes** — earned by acting, lost by not acting. That inverts the trap:
standing still is what dims you, and playing is the only thing that keeps you lit.

### Recommended: the decaying peak — *how hot you have been running*

⚠ **Not a "session" peak.** This document first called it that, and the name was wrong in a way
that mattered — see "What counts as recently" below and
`docs/superpowers/specs/2026-08-26-time-windowed-values-design.md` §3a. There is no session
boundary anywhere in this design.

**The highest pot you have REACHED recently, fading over time.** Not the pot you hold — the pot you
got to.

| constraint | how it holds |
|---|---|
| decision-neutral | ⚠ **banking does not touch it and neither does losing.** You reached 27; that happened. Whether you then banked it or rode it into the ground is the aura's business not at all — which is exactly right, because that is the player's decision to make unpressured. |
| no hold trap | only winning raises it; only **time** lowers it. Going idle fades you out. |
| dense, with a gradient | it retains through losses, so it is strictly denser than the live pot — and it inherits the 3ⁿ ladder, so many players sit at 1–3 and a 27 is rare and unmistakable. |
| not a rank | it is gone by tomorrow. A veteran and a newcomer both start the evening dark. |
| reachable tonight | ⚠ this is the honest answer to *"why should a new player ever see one"* — better than seniority's, because the newcomer does not merely see one, they can **have** one within the hour. |

And it is a flex in the word's real sense: *"I hit 27 tonight"* is something another player would
want. Scale the glow steeply — log₃, so each 3ⁿ tier is one even step — so a pot of 1 barely
registers and a deep run is unmistakable. A presence indicator is not a flex; a magnitude is.

**⚠ The cost — CORRECTED 2026-08-26; this document over-priced it.** It first said the peak was
"NOT free, unlike seniority" and would need a stored `potPeak` / `potPeakAt` pair. It does not.
`PlayerRound.pointsDelta` on a WIN already records the **new pot value**, so a `$max` over that
column in a window *is* the peak — the documented trap that makes summing the column wrong is
exactly what makes maxing it right. No new collection, no schema change: one aggregation on the
join call (the `presence.qualified` rule), the running peak raised from the `nextPot` that
settlement already computes, and both values riding the roster push that already carries
`currentStreak`. Full working, and the general capability behind it:
`docs/superpowers/specs/2026-08-26-time-windowed-values-design.md`.

**What is unchanged either way:** the rendering gated on 2026-08-26 — embers from the feet,
`LockedToPart`, `emitRate` and `pulsePeriod` carrying the magnitude, fill a faint floor, colour
third. Every proposal here changes the input number and nothing else.

### Considered and rejected

- **Recent points banked (decaying).** Fails constraint 1 from the other side: banking is the only
  way to raise it, so it pays you to bank early and often. An opposite thumb is still a thumb.
- **Rounds thrown recently.** Decision-neutral and dense, but it measures attendance. Nobody flexes
  showing up.
- **Keeping `currentStreak` and lowering the floor further.** The floor is already 2; the density is
  intrinsic to the metric (§3), and floor 1 means "won last round" — a third of the arena, flat, no
  gradient, and the hold trap gets more common rather than less.

## Owner decisions required

1. ⚠ **Is the decaying peak the right shape** — *how hot you have been running* rather than
   *what you have on the line*? This is the open question, and the one thing this document should
   not decide alone.
2. If yes: the **half-life**. It sets how much of the arena is lit at once, so it is the density
   dial — long enough that a good run still shows when you walk up to someone, short enough that it
   cannot be hoarded. **~20 minutes is offered as a starting point to argue down from, not a spec.**
   It wants watching in play, not arguing in a document.
3. If yes: does it need the floor ruling at all? *"Let the kids dress up if they want"*
   (2026-08-25) argues every reached pot glows faintly, with the magnitude doing the work.

## Not proposed

- **No seniority aura, no second aura, no second channel on the existing one.** Answered in §1–3.
- **No leader halo.** Still deferred on item 7's ranking basis, unchanged.
- **No change to grade, milestones or the unlock model.** They already carry seniority correctly.
- **No fix to the shipped aura's own hold trap on its own.** Recorded in §4; it rides whatever
  decision comes out of this, rather than becoming a separate change.

## Raw layer

`server/src/engine/Milestones.ts` (RUN_STEPS, gradeFor), `server/src/engine/GameRules.ts`
(nextPot, nextStreak), `server/src/engine/Settlement.ts` (settleRound, bestPot `$max`),
`server/src/wallet.ts` (bank), `roblox/src/shared/StreakAura.luau`,
`roblox/src/client/AuraController.client.luau`,
`docs/superpowers/specs/2026-08-25-streak-aura-design.md` (superseded on rarity, see §3),
`docs/wiki/log.md` 2026-08-25 / 2026-08-26 entries, `docs/wiki/world/core-loop.md`,
`docs/wiki/world/familiars.md`.
