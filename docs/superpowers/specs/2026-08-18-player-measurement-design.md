# Measuring the Best Roshambo Player — design

**Status:** proposed, 2026-08-18
**Governs:** the shared measurement basis for friends-&-family items **6 (rewards & flex)**
and **7 (statistics)**. Neither can be built without it: item 7 is "what can we measure and
report", item 6 is "what do we reward", and both are the same question asked twice.

**Prior art this rests on:** `docs/wiki/world/core-loop.md` (outcomes, pot, the points
fields), `docs/wiki/world/world-throw.md` (why crowd-reading is skill),
`docs/superpowers/specs/2026-08-16-stats-room-design.md` (the room and its walls).

---

## 1. The question

> How do we determine, on an ongoing basis, who is the best Roshambo player right now?

There is no single number, and the room already knows it — a 番付 is a sheet of ranked
registers, not a champion. But there IS a headline, and there are exactly three numbers
worth keeping.

## 2. What the game actually rewards — established by simulation, not argument

A first pass at this concluded that Bank-vs-Stake is not a skill, on the grounds that
staking is always +EV: at pot `P`, `3P·p_win + P·p_safe > P` for any player at or above
blind. **That conclusion was wrong**, and the error is worth recording because it is
seductive: the pot only becomes points when banked, so a player who always stakes realises
nothing. Expected value increases monotonically with how long you ride and therefore never
selects a stopping point. It is the St. Petersburg shape — expectation diverges while the
probability of realising anything collapses. **EV is the wrong objective function**, which
is precisely what makes stopping a real decision.

Monte Carlo over the real rules (pot ×3 per WIN since last loss-or-bank, SAFE preserves,
LOSS forfeits), 40,000 trials, 350-throw window. "Blind" is (1/3, 1/3, 1/3); "+N pts" adds
N points of win rate converted out of losses, holding SAFE at 1/3.

**(a) There is a correct place to stop, and it is deep.** Blind player, median points/throw:

| bank after | 1 win | 4 wins | 6 wins | 7 wins | 8 wins |
|---|---|---|---|---|---|
| median pts/throw | 0.33 | 0.62 | 1.39 | **2.08** | 0.00 |

Banking at 1 and banking at 7 differ by 6× on identical prediction ability. Banking at 8
returns nothing: 64% of those players bank zero across the whole window.

**(b) Stopping policy outweighs a read edge.** Over 350 throws, a **blind but bold** player
(banks at 6) out-earns a **skilled (+5 pts) but timid** one (banks at 1) **85% of the time** —
median 1.39 against 0.38. So points-per-throw is not noise, but ranked alone it mostly ranks
nerve.

**(c) The two compound, and this is the game's real depth.** Median points/throw:

| bank after | blind | +5 pts | +10 pts |
|---|---|---|---|
| 6 | 1.39 | 2.08 | 4.17 |
| 7 | **2.08** | 4.17 | 8.33 |
| 8 | 0.00 | **6.25** | 12.50 |
| 9 | 0.00 | 0.00 | **37.49** |

**The better you read the crowd, the deeper you can correctly ride.** Ride one step past your
actual read and you are zeroed; stop one step short and you leave most of it behind. Nothing
in the game currently measures this, and it is the most interesting thing in it.

**(d) The right depth also depends on session length.** Over a 30-throw sitting, riding deep
banks nothing and timid play wins. For an ambient game where a child plays twenty minutes,
banking early is genuinely correct — deep-ride glory is only available to long sessions. Any
copy that tells players to "hold out" is wrong for most of them.

**(e) Sample size is the binding constraint.** Probability a +5-pt player ranks above a blind
one, by win rate:

| throws | ≈ time | ranked correctly |
|---|---|---|
| 30 | 30 min | 60% — a coin flip |
| 60 | 1 hr | 67% |
| 350 | 5.8 hr | 89% |
| 1000 | 16.7 hr | 98% |

At 60 throws a **blind** player's observed win rate lands between 23% and 43% nine times in
ten. One lucky hour makes someone look like the best player alive.

**(f) The ×3 multiplier is correct and was checked, not assumed** (owner, 2026-08-18: keep it).
The neutral multiplier is `1/q` where `q = p_win/(p_win+p_loss)` — exactly **2** for a blind
player. Simulated median points/throw, blind, 350 throws:

| bank after | ×1.5 | ×2 | ×2.5 | ×3 | ×4 |
|---|---|---|---|---|---|
| 1 win | 0.33 | 0.33 | 0.33 | 0.33 | 0.33 |
| 5 wins | 0.06 | **0.18** | 0.45 | 0.93 | 2.93 |
| 7 wins | 0.03 | **0.18** | 0.70 | 2.08 | 11.70 |

At ×2 the column is flat: depth makes no difference and the Bank/Stake decision is deleted.
Below it, riding is a mistake. Raising it buys nothing structural — **the cliff does not move**
(40% of blind players bank zero at depth 7 and 64% at depth 8, identically at ×2, ×3 and ×4),
because the cliff is set by win/loss odds and session length, not by the payoff. ×4 only
inflates figures into `entryLine`'s left-truncation hazard.

**Do not re-litigate this without new evidence.** The one real alternative, recorded so it is
not rediscovered: ×2 would make any gain from riding *pure* skill expression, since a blind
player is indifferent to depth. Declined because it makes the game's most dramatic mechanic
pointless for the majority, and for a twenty-minute session the ride is the fun.

## 3. The three numbers

| | definition | window | source | built? |
|---|---|---|---|---|
| **READ** | `WINs ÷ throws`. Baseline **33.3%** — a blind player's exact expectation. | rolling | `PlayerRound.playerResult` | **no** — `'WIN'` appears once in `stats.ts`, in `biggestRounds` |
| **YIELD** | `points banked ÷ throws` | rolling | `BankEvent.amount` ÷ `throwsInWindow` | yes — `playerRates.pointsPerThrow` |
| **NERVE** | median `streakAtBank` — how deep you typically ride before collecting | rolling | `BankEvent.streakAtBank` | recorded, never aggregated |

**YIELD is the headline; READ is the column beside it.** Yield is the only figure that
captures §2(c): a +10 player riding to 9 earns 37.5/throw where a blind player riding to 7
earns 2.1. Win rate renders that same gap as 43% against 33% and loses the story. A 番付 row
is therefore `rank · name · yield · read`, and a reader can see at a glance whether someone
is up there on skill or on nerve.

**Yield is a record, not an estimate.** As a measure of underlying skill it is noisy (71%
discrimination at 350 throws when riding to 6). As a statement of what a player achieved this
week it is exact. This distinction governs the labelling rule in §6.

**NERVE is deliberately NOT a leaderboard.** Ranking "who rides deepest" crowns the player who
rides past their own read and banks nothing — a losing strategy dressed as a win. It belongs
on the personal 札, and as a room-wide histogram of `streakAtBank` on the wall, which needs no
qualification and teaches the game better than copy would.

## 4. Qualification: 360 throws

**A player joins the rate boards at 360 throws inside the window.**

- `windows.ts` already derives the floor from win rate: standard error `0.4714/√n`, so
  separating a +5-point edge from luck takes ~356 throws. **360 is the next round number above
  the honest floor**, so the rule is not arbitrary.
- Rounds are `OPEN 51 + LOCK 2 + REVEAL 7 = 60s`, so **360 throws is exactly 360 minutes** —
  six hours of actually throwing, not of being logged in.
- It is a rule a player can hold: *"play six hours in a week and you are on the board."* This
  is the answer to "how long must I play before I appear on the leaderboards", and it should be
  **printed on the board**, not buried.

`QUALIFY.week` moves **350 → 360**. `month`/`career` stay at 1000.

Denominator is THROWS, never rounds elapsed — abstention is normal play, and a patient player
who throws in a fifth of rounds is playing well, not playing little.

## 5. Two gates, and both must hold

A rate register may only be shown when BOTH are true:

1. **The world is real.** `TEST_MODE` off AND ≥ `WORLD_THROW_MIN_PARTICIPANTS` (5) throwing.
   Under TEST_MODE the World Throw is a fixed R→P→S cycle, so READ measures nothing but who
   spotted the pattern. Both prod and dev run TEST_MODE today
   (`docs/wiki/world/world-throw.md`), so **this gate is currently CLOSED**.
2. **The player qualifies** — 360 throws in the window.

Gate 1 is not a display concern that can be waved through: with it closed, READ is actively
misleading rather than merely imprecise. Turning it off needs a crowd, and a synthetic crowd's
bots must have **readable patterns** or a random plurality reimplements the defect the majority
rule was built to fix.

## 6. The labelling rule

**Label a board by what it measures, not by what we wish it meant.**

`MOST POINTS PER THROW — THIS WEEK` is true. `BEST PLAYER` is not. Every rate board carries its
window, its qualification threshold, and — for READ — the baseline, as a printed line:

```
THE WORLD TAKES 33 IN 100
QUALIFIED AT 360 THROWS
```

## 7. What shows where

Existing boards (`roblox/src/shared/StatsRoomLayout.luau`) and what changes:

| board | site · wall | grid | today | after |
|---|---|---|---|---|
| `banzuke` | cavern · south | 10×26 | career standings | **the 番付**: `rank · name · yield · read`, qualified. Falls back to career standings with a printed line naming the 360 rule while nobody qualifies — so it is never empty. |
| `skill` | cavern · west | 8×22 | streak records | unchanged |
| `skillFuture` | cavern · west | 6×13 | **shuttered** | **the room's bank-depth histogram** — `streakAtBank` distribution. Needs neither gate: choosing when to bank is real player behaviour even under TEST_MODE. Opens when it ships. |
| `judgement` | cavern · east | 8×22 | biggest bank, biggest round | unchanged |
| `world` | cavern · north | 6×22 | heat / form | unchanged |
| `fuda` | vestibule · west | 16 cols | personal, with `142 / 350` | adds READ · YIELD · NERVE · **RANK**; progress becomes `142 / 360` |
| `summary` | vestibule · east | | last round | unchanged |

⚠ `skillFuture` is **13 columns wide**, which cannot hold a ranked line (`1. AYAKA   2.4 41%`
needs ~18). A histogram row (`1  ████ 34%` = 11) fits. This is why the histogram lives there and
the 番付 takes the 26-column south wall rather than the reserved panel.

`skillFuture` is shuttered rather than dark because a closed kōsatsu reads as intentional, and
it opens when the histogram ships. **The visible sign that the world became real is elsewhere:
the READ column appearing on the 番付**, which cannot render until gate 1 opens. That is the
moment worth staging, and it lands on the board a visitor faces on entry.

### Where you stand (owner, 2026-08-18)

A banzuke in sumo lists **everyone**, top to bottom. Ours is ten rows on a 26-column wall, so at
fifty players forty never see their own name — and the person who most wants to know where they
stand is precisely the one in eleventh place.

So the 札 carries `RANK 14 OF 22`: the player's position in the qualified field, and the size of
that field. It is on the slip rather than the wall because it is the one figure that is different
for every reader, and a per-viewer display needs no new mechanism — a client-built SurfaceGui is
already private to that client.

`of` counts the **qualified field only**, so it means the same thing the ranking does. An
unqualified player has **no rank at all** — null, rendered as a dash, never a 0. "You are 0th" is
worse than no answer, and the throws row directly above already says what is missing.

## 8. What is honest to reward (item 6)

The split falls straight out of §2(e): **exact facts are true at any sample size; rates lie
below 360 throws.**

**Milestone badges — honest today, work for ten players over a weekend. Earn-only.**
- First bank; pot reached 9 / 27 / 81 / 243
- Streak of 3 / 5 / 7
- Lifetime banked 100 / 1,000 / 10,000
- **360 throws in a week** — qualification is itself an achievement, and badging it makes the
  rule legible before a player has met it

**Rate titles — behind both gates in §5.** Top of the 番付 for a completed window. No title may
be awarded from an unqualified sample or a TEST_MODE world.

Every one of these derives from rows already written (`BankEvent`, `StreakEvent`,
`PlayerRound`, `User.lifetimeBanked`/`bestPot`). No new capture is required.

## 8a. This spec yields TWO implementation plans

They share this measurement basis and nothing else, and the second is worthless without the
first, so they are sequenced rather than parallel:

1. **Measurement and the walls (item 7).** READ and NERVE in `stats.ts`, `QUALIFY.week` → 360,
   the endpoint, the 番付's two columns, the histogram, the 札 additions.
2. **Milestone badges (item 6).** Awarded at settlement from rows plan 1 does not touch. Its
   *display* is out of scope here (see below), so this plan ends at "the badge is earned and
   persisted", not "the flag flies".

## 9. Out of scope

- **The flex rendering** — teahouse banner-pole flag, avatar ribbon/sash. Item 6's *display*
  layer is its own spec: it needs art, anchor slots and a catalog, and none of that is a
  measurement question.
- **The rotating avatar display** on the cavern's freed north-east wall — needs image assets;
  already carved out by the stats-room spec.
- **Making the world real** — turning off TEST_MODE and building a readable synthetic crowd is
  a prerequisite for gate 1 but is its own piece of work, with its own design questions (how
  many bots, what patterns, how legible).
- Season resets, decay, promotion/relegation between registers.
- **Tournament windows** — player- and group-created timed competitions to create and join
  (owner, 2026-08-18: "should be a thing, but beyond the scope here"). Recorded on the backlog.

## 10. Open questions

- ~~Which window does the 番付 rank?~~ **DECIDED (owner, 2026-08-18): a ROLLING 7 days.** The
  calendar week's advantage was a shared reset moment; the cost is that a Monday boundary wipes
  a run that started on Sunday evening, so *when* you play matters as much as how well.
  Rolling rewards dropping in at any hour and lets a hot streak count the moment it happens.
  This overrides the standing "RANK uses calendar windows" comment in `windows.ts`.
- **Does NERVE use median or mode of `streakAtBank`?** Median is stated above; mode may read
  better to a player ("you usually bank at 3"). Cheap to change; decide at the Studio gate.
- **What happens to a qualified player who stops playing?** They age out of a rolling window
  silently. Whether that needs saying on the board is undecided.

## 11. Raw layer

- Simulation: `p_safe` held at 1/3 throughout; skill modelled as win rate converted out of
  losses. 40,000 trials per cell, 350-throw window unless stated.
- Code touched by this design: `server/src/stats.ts` (add READ, add NERVE aggregation),
  `server/src/windows.ts` (`QUALIFY.week` 350→360), `server/src/routes/statsV1.ts`,
  `roblox/src/shared/StatsBoardModel.luau`, `roblox/src/shared/StatsRoomLayout.luau`,
  `roblox/src/client/StatsController.client.luau`
- Unchanged and load-bearing: `BankEvent.streakAtBank` — *"the whole bank-vs-stake story lives
  in the distribution of this number"*
