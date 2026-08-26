# Juice vs Seniority — does seniority deserve its own carrier?

**Question** (owner, 2026-08-25, on watching the shipped aura): *"who cares about auras if only 2
or 3 are ever even visible on your server? We're either measuring the right thing badly, or
measuring the wrong thing."* Two candidates were named — **juice** (points on the line now) and
**seniority** (personal best win-streak, independent of betting).

**Verdict: NO. Seniority does not get a carrier.** It is already in grade, and grade already has an
answer. The owner's observation is correct and the arithmetic below confirms it exactly — but the
fault is in the *juice* half, not a missing seniority half. This document answers the seniority
question closed, and opens one owner decision on juice.

**Status:** design-thread recommendation. The seniority half is a closed argument. The juice half
is an OWNER DECISION and nothing should be built for it until it is ruled on — the aura is gated
(2026-08-26) and this proposes changing the number it reads.

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

## 4. Where the density problem actually lives: the aura is measuring the wrong number.

The owner offered two diagnoses. The second is the right one, and it is a juice problem.

⚠ **`currentStreak` is wrong in both directions, and the code says so plainly:**

- **Banking leaves it running.** `bank` sets `pointsAtStake: 0` and `stakingStreak: 0` and does not
  touch `currentStreak` (`server/src/wallet.ts:20`). A player who banks a 5-run has **zero on the
  line and a full-strength aura.** For a display whose stated subject is *juice*, that is backwards.
- **A SAFE kills it while the pot survives.** `nextPot` preserves the pot on SAFE
  (`GameRules.ts:11-16`); `nextStreak` returns 0 for anything but a WIN (`GameRules.ts:27-28`). A
  player sitting on a pot of 27 who matches the world **goes dark with 27 points still at risk.**

Both are exactly "measuring the right thing badly". The 2026-08-26 switch from `stakingStreak` to
`currentStreak` was made for a sound reason — *"banking is THE decision in Roshambo, and tying the
reward to not-banking punished the action the whole loop is built around"* — but it fixed the
incentive by picking a number that no longer describes exposure at all.

**`pointsAtStake` is the number the design has been reaching for.** It is the pot: the thing the
HUD already shows, the thing Bank-or-Stake is a decision *about*, and the only field that is
literally "points on the line right now".

**And it fixes the density for free, without touching the floor.** Steady state over
{pot = 0, pot > 0}: entered on a WIN (p ≈ 0.30), left on a LOSS (p ≈ 0.30) or a bank. Ignoring
banking that is π(pot > 0) ≈ 0.50; with realistic banking it stays comfortably above ~0.35.

| | glowing on 30 players | shape |
|---|---|---|
| `currentStreak ≥ 2` (today) | ~3 | flat — a lottery |
| `pointsAtStake > 0` | ~12–15 | a pyramid |

The pyramid is the part that matters. Depth decays by p(win)/(p(win)+p(loss)) ≈ 0.5 per 3ⁿ tier, so
of ~12 live pots roughly 6 sit at 1, 3 at 3, 1.5 at 9, under 1 at 27+. **Many faint, few blazing,
one spectacular** — the density curve a status effect wants, and it falls out of the pot ladder
rather than being tuned in. The tiers are also the game's own vocabulary: 1, 3, 9, 27, 81.

**It does not punish banking; it reframes what the glow means.** Under a pot reading the aura stops
being a reward for virtue and becomes a **public disclosure of exposure** — not *look how good I
am* but *look how much I have riding*. Banking then trades the glow for the points, which is
precisely the trade the game is built on, and the glow going out is the drama rather than a
penalty. A player who banks 81 in front of a crowd that could see the 81 has done something
legible; today they bank invisibly and keep glowing for a run that costs them nothing.

**Everything gated on 2026-08-26 survives.** The rendering does not change: embers from the feet,
`LockedToPart`, `emitRate` and `pulsePeriod` carrying the magnitude, fill as a faint floor, colour
third. Only the input changes — `AuraController.client.luau:321-322` reads `entry.currentStreak`
from the roster; it would read `entry.pointsAtStake` instead, and the optimistic local update at
:348 would call the already-mirrored `GameRules.nextPot` rather than incrementing by hand. Same
plumbing, one field, and the curve in `StreakAura.poseFor` re-domained from a 2..8 streak to a
1..81 pot (log₃, so each tier is one even step).

⚠ **This is a change to a feature the owner has already gated, so it is not mine to make.**

## 5. Where seniority's real deficit is — and it is private, not public

The argument for seniority that does survive is the one the log states: *"it is also the half that
answers 'why should a new player ever see one'"*. That instinct is right about a problem, but
misidentifies which one. `docs/wiki/world/familiars.md` already records it under **Still thin**:

> *"The progression is invisible to its owner — milestones are earned silently and grades change
> silently. Nothing announces a grade-up and nothing prints the grade."*

A player who hits `run.3` gets a milestone, possibly a grade, possibly a familiar unlock — **and is
told nothing.** That is the actual hole, and it is a *private acknowledgement* problem, not a
public display problem. Fixing it needs a grade-up moment and somewhere a player can read their own
standing; it needs no worn carrier, so it collides with none of the four rejections and none of the
culture constraint.

That work is the next item in the design thread's queue (*"grade has no public display"*), and this
document hands it a sharpened brief: **the first thing that item owes is the private half.**

## Owner decisions required

1. ⚠ **Re-key the aura from `currentStreak` to `pointsAtStake`?** Rendering unchanged; input and
   curve domain change. This supersedes the 2026-08-26 metric choice, so it needs an explicit
   ruling — not an inference from this document. If yes, it wants a spec and a plan before code.
2. If yes: does the floor stay at 2 (i.e. **pot ≥ 3**, hiding the one-win pot), or does **any live
   pot glow** (pot ≥ 1)? The 2026-08-25 ruling — *"let the kids dress up if they want"* — argues
   for pot ≥ 1, and the pyramid above assumes it. It is an access decision, as that ruling
   established, so it is the owner's.

## Not proposed

- **No seniority aura, no second aura, no second channel on the existing one.** Answered above.
- **No leader halo.** Still deferred on item 7's ranking basis, unchanged.
- **No change to the roster broadcast cadence.** It is already per-round for `currentStreak`; a
  pot field rides the same push.
- **No change to grade, milestones or the unlock model.** They already carry seniority correctly.

## Raw layer

`server/src/engine/Milestones.ts` (RUN_STEPS, gradeFor), `server/src/engine/GameRules.ts`
(nextPot, nextStreak), `server/src/wallet.ts` (bank), `roblox/src/shared/StreakAura.luau`,
`roblox/src/client/AuraController.client.luau`,
`docs/superpowers/specs/2026-08-25-streak-aura-design.md` (superseded on rarity, see §3),
`docs/wiki/log.md` 2026-08-25 / 2026-08-26 entries, `docs/wiki/world/core-loop.md`,
`docs/wiki/world/familiars.md`.
