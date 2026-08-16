# Stats Room (番付) — Design

**Date:** 2026-08-16
**Status:** Draft — awaiting owner review
**Program:** friends-family baseline item 4 (`docs/wiki/program/item-4-merchant-row.md`)
**Foundations:** `docs/wiki/world/core-loop.md`, `docs/wiki/world/world-throw.md`

The excavated hall behind the Stats false front, what goes on its walls, and how the
game decides who is doing well. Terrain is bored and saved (2026-08-16): a 40.5 × 26
chamber, floor 114.00, ceiling 134.00, entered from the north at about x −28 through a
tunnel from the shop's rear doorway.

## 1. The premise this rests on

**The World Throw is the majority of player throws** ([[world-throw]]). Everything here
depends on that: it is what makes crowd-reading a skill rather than fortune, and what
makes a "best player" question answerable at all.

**Hard prerequisite.** The shipped server picks the World Throw at random (parked defect
(f)). Every skill-derived stat in §4 is meaningless until that is fixed. Records, Heat
and Volume stats (§4.1, §4.3) do not depend on it and can ship first.

## 2. Scope rulings (owner, 2026-08-16)

- **Personal-first.** The room reads the viewer. Your own standing greets you on entry;
  global rankings sit behind it.
- **Groups are affiliations, not voting blocs.** A group's ranking is the aggregate of
  its members' individual play. There is no coordinated throwing, and therefore no
  defection mechanic. Country (`User.country`) is the first free instance.
- **Abstention is normal play.** Players hang out socially and throw in perhaps a third
  of rounds, watching for a pattern first. Presence ≠ participation. Every rate stat is
  therefore **per throw**, never per round elapsed.
- **Long sessions are the goal**, not an edge case. The design should reward them.
- **Chaos is acceptable, mislabelling is not.** Round-to-round churn on short-window
  boards is wanted. Those boards are named as *form*, not *rank* (§3).
- **Seasons: space reserved, not built.** The room is carved rock, so wall allocation is
  cheap now and expensive later. No display is dark at launch (§6).
- **Edge is a parked candidate.** Not committed to until there is a real player base to
  judge it against.

## 3. Heat vs Rank — the naming rule

Two categories, physically distinct on the wall. This is what lets the room carry
volatile boards honestly.

| | 勢い **Heat** | 番付 **Rank** |
|---|---|---|
| Window | live / hour / day / week | season, career |
| Qualification | none | published minimum |
| Volatility | high, by design | slow |
| Claim | "who is on a tear right now" | "who has proven it" |
| Form | split-flap, clattering | printed sheet, name size = rank |

A lucky 30-round run may top Heat. It must never top Rank, and the wall must make the
difference legible without copy.

## 4. The stat taxonomy

Three kinds that behave differently statistically and must not be mixed on one board.

### 4.1 Records — discrete events, no sample-size problem

Short windows are legitimate and exciting. Ship first.

- **Longest win streak** — live / day / week / season / all-time. `currentStreak` is not
  reset by banking (`wallet.ts`), so cautious bankers and reckless riders compete
  equally. Per server and global.
- **Biggest pot banked** — distinct from `bestPot`, which records the largest pot ever
  *reached*. The gap between reached and kept is the story.
- **Biggest single round.**

### 4.2 Rates — need qualification, long windows only

A blind player wins 1/3 of rounds, so a win-rate claim needs sample. Standard error at
p = 1/3 is 0.4714/√n:

| To evidence an edge of | Throws required |
|---|---|
| +10 points (43%) | ~90 |
| +5 points (38%) | ~356 |
| +3 points (36%) | ~990 |

A round is exactly 60s, but at one-third participation those thresholds take three times
as long in wall-clock to accumulate. **Consequence: daily rate boards are noise and are
not built.** Weekly is the floor, with the qualification printed on the board itself
("qualified: 350+ throws this week").

- **Points earned per throw** — the owner's critical stat. Denominator is throws.
- **Capture rate** — banked ÷ (banked + forfeited). What fraction of everything you built
  did you keep. Needs a new `lifetimeForfeited` field.
- **Edge** = win rate − 33.3%. PARKED pending population data.

### 4.3 Volume — no qualification, rewards commitment

Labelled as commitment, not skill.

- **Points earned in window** — needs the bank-event log (§5.1).
- **Throws made**, **rounds present**.

### 4.4 Participation — the novel axis

Enabled by §5.2. Selectivity is a style worth celebrating: a sniper throwing in 20% of
rounds at a 45% win rate is playing a different game from a grinder at 95% and 36%, and
both should be visible.

The room's most interesting display is **win rate plotted against participation rate
across the whole population** — the empirical answer to *does patience pay*. Nobody knows
yet, and it is unique to this game. It lives on the **West / Skill** wall (§6), not the
form guide — it is an argument about skill, not a record of the crowd.

## 5. Schema consequences

### 5.1 Bank events (REQUIRED for any windowed earnings)

Banking is currently a single atomic `$inc` on the User document (`server/src/wallet.ts`)
that writes no history. `lifetimeBanked` is a running total with no timestamps, and
`PlayerRound.pointsDelta` cannot substitute because on a WIN it records the new pot
rather than the increment (`GameRules.ts:18-24`). **"Points earned last week" is
uncomputable today.**

New collection, one row per bank: user, amount, streak length at bank, pot at bank,
timestamp, platform. Indexed on (user, timestamp).

### 5.2 Session presence (REQUIRED for any participation stat)

`PlayerRound` rows exist only when a player throws, so a player who watched 40 rounds and
threw 5 is indistinguishable from one who arrived for 5.

**Do not write a row per player per round** — at a thousand concurrents that is ~1.4M
writes a day. Record **session intervals** (join, leave, server id) instead; rounds-present
falls out of counting round timestamps inside those intervals. One row per session, exact,
and it retroactively enables every participation stat.

### 5.3 Forfeited points

`lifetimeForfeited`, incremented on LOSS by the pot lost. Required for capture rate.

### 5.4 Leaderboard basis — a correction, not an addition

`transports/socketAdapter.ts:193` and `routes/apiV1.ts:420` both sort by `totalPoints`,
which is a **spendable wallet** decremented by purchases. A player who spends on fireworks
or a teahouse falls down the board, penalising exactly the economy engagement the game
wants. **All standings move to `lifetimeBanked`.**

## 6. The room

Entry is from the north at ~x −28. Walls, 40.5 × 26, ceiling 20 studs clear.

| Where | Carries |
|---|---|
| Entry, flanking the tunnel | **Your 札** — personal slips, per-viewer |
| South (faces you on entry) | **番付 standings** — career now, seasonal later |
| West (longest wall) | **Skill** — rates, participation study |
| East | **Judgement / Risk** — capture rate, bank height |
| North, beside the exit | **The World** — form guide, read on the way out |
| High band, all four walls | **Round state** — timer and throws (§6.3) |

The form guide sits by the exit deliberately: it is the most *useful* surface in the room
and should be the last thing seen before returning to the arena.

### 6.1 Per-viewer displays

Already solved by the existing pattern. `BoardController.client.luau` is a client script
that parents a SurfaceGui straight to a world part (`gui.Parent = board`, line 56); client
instances do not replicate, so every player already sees a private copy. Per-player content
needs **no new mechanism** — only per-player data, which the `player-data` / `PlayerProfiles`
path already delivers. The formal alternative (SurfaceGui in `PlayerGui` with `Adornee`, as
`LanternController.client.luau:89` does for a BillboardGui) is only needed if a display must
survive part streaming or take input.

### 6.3 The round band — timer and throw display

**This is a requirement, not a convenience.** The room is buried under ~18 studs of rock,
out of sight and earshot of the arena. The taiko drum is the round's authoritative signal
([[round-and-hud]]: "the drum is authoritative"), and a player studying the form guide down
here cannot hear it. Without a round display, entering the Stats room means silently
dropping out of the game — which would make the most useful room in the world a trap.

**Form:** larger flap cells than the leaderboard rows (owner, 2026-08-16). Read at distance,
clatter on change — this is the one display whose *noise* is the point, since it has to pull
attention from a wall you are reading.

**Placement: a clerestory band, high on the walls, running continuously.** Visible from
anywhere in the room and from any wall you happen to be facing, and it costs no prime
display real estate. It also spends the vertical space the ceiling raise just created — the
hall is 20 studs clear, and the band lives in the top ~4 that nothing else wants.

**Content:**

- phase and seconds remaining (OPEN / LOCK / REVEAL)
- the World Throw, once revealed
- your own throw for the round, or its absence — per-viewer, on the same slips treatment as
  the personal 札 (§6.1), so a player can see at a glance that they have not thrown yet

**Constraint — it must not race the drum.** The existing ruling forbids wiring display
elements past the drum gate; the result splash, ring glyph and points plate have each done it
and been corrected. The band derives from the same `drumRest` cue the HUD uses, never from
the raw wire. A stats-room board that revealed the World Throw a beat before the arena did
would be the same defect in a new place.

### 6.2 Visual language, mapped to volatility

- **番付 printed sheet** — standings. Rank encoded by *calligraphy size*, as real banzuke do,
  so the wall reads as one image from the door. Regenerated on a slow cadence.
- **Split-flap kōsatsu** — Heat only: current leader, longest current streak, last-20 world
  throws. `FlapScheduler` is ready (drum now carries `-:/`, capped at 9 steps, `0b41f83`).
- **Personal 札 slips** — hanging wooden tags, per-viewer, paper-and-wood against stone so
  the room teaches "this one is yours" without copy.
- **Avatar plinths** — top three only.

**Blocker:** `BoardController` has no-opped since the jumbotron was removed (T23) — it
early-returns when `JumbotronBoard` is absent. Retargeting the renderer at kōsatsu boards is
real work standing between this spec and any visible display.

**Text budget.** `TextLabel.TextSize` is hard-capped at 100px and `TextScaled` does not
reliably scale up on a SurfaceGui; `BoardController` solves this with a small canvas stretched
across a large board. Leaderboard rows must use the same trick. Row counts need budgeting
against the project's measured perf floor — text is the expensive part.

## 7. Sequencing, by data maturity

| Ships first — works with 50 players | Waits for a population |
|---|---|
| Records (§4.1) | Edge (§4.2) |
| Heat boards (§3) | Participation-vs-winrate study (§4.4) |
| Volume (§4.3) | Qualified rate ladders, banzuke rank |

Neither column can start before §5.1 and §5.2 land, since both are pure data capture with no
display, and every stat downstream needs the history they begin accruing. **They should ship
before anything else, so history exists by the time the walls do.**

## 8. Seasons — reserved, not built

Structure, when it comes: **basho** (fixed season), **yūshō** (season champion on one legible
headline stat), **sanshō** (three named prizes for distinct virtues), and a **banzuke rank
that is sticky while scores reset** — so progression is legible across seasons without an
early adopter sitting on a lifetime total forever.

**Season length is deliberately undecided** — it should be set from observed play patterns,
not guessed.

**No display is dark at launch.** The banzuke wall carries the career ranking from day one on
`lifetimeBanked` and graduates to seasonal later — same wall, same form, no churn. Only the
champions archive and the three sanshō plaques have no content, and those are **shuttered or
furled**, not unlit: kōsatsu boards had shutters and a banzuke is a posted sheet, so a closed
one reads as intentional rather than broken. The archive's emptiness is a feature — a row of
mounts that visibly fills one champion at a time.

## 9. Non-goals

- The flex economy and what points buy. Out of scope here.
- Group creation, membership and invitation UX — groups appear only as a scoping dimension
  over stats.
- Fixing defect (f). Named as a prerequisite; specced and scheduled separately.
- "Sports book" framing. Barred as product usage (owner, 2026-08-15).

## 10. Open questions

1. Season length — deferred to observed play (§8).
2. Whether Edge survives contact with a real player base (§4.2).
3. Which single stat decides the yūshō. Season points earned is the legible candidate — it
   is understood without explanation, and because points exist only once banked it already
   folds in judgement — but it rewards volume, and play time varies enormously here in a way
   it does not in sumo, where everyone fights fifteen bouts. Deliberately left open.
4. ~~Can a player throw from inside the Stats room?~~ **RESOLVED (owner, 2026-08-16): yes.**
   The HUD is always visible, so the room is a study-AND-play space and needs no throw input of
   its own. The round band (§6.3) remains required — it tells a player studying a wall that a
   round is closing.
5. Whether the group scoping dimension ranks by sum (favours large groups) or by qualified
   average (favours small ones). Both are defensible; likely both, on separate columns.
