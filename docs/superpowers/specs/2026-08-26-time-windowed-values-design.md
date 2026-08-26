# Time-windowed values — what the backend already supports

**Question** (owner, 2026-08-26): *"do we have the backend support to enable it? Decaying anything
over time is an important unlock, even for e.g. totalPoints (per month/day/week leaderboards)."*

**Answer: yes, and most of it is already shipped.** Windowed leaderboards are a parameter away, not
a project. The decaying aura needs no new collection and no new stored field. There is exactly one
quantity that cannot be windowed today, and it is not the one named.

⚠ **But they are TWO different mechanisms, and the question treats them as one.** Separating them
is most of the answer, because their costs differ by orders of magnitude.

| | windowed aggregation | continuous decay |
|---|---|---|
| example | "points banked this week" | the aura fading over an evening |
| what it is | a **query over event rows** | a **display transform on one value** |
| when it runs | on request — a board is opened | every frame, on every client, for every player |
| what it needs | an event collection with a timestamp + index | a value, a timestamp, and arithmetic |
| status | **built** | **needs a value pushed; the maths is client-side** |

A board can afford a Mongo aggregation. **An aura cannot** — 50 clients reading 50 other players
continuously is not a query workload, and any design that reaches for one is wrong. That is the
whole reason the two need separating.

---

## 1. Windowed aggregation — already built, and better than asked for

`server/src/windows.ts` is a whole time vocabulary, and it is thought through:

- `Window` is **half-open `[from, to)`**, adopted repo-wide, so an event on a boundary lands in
  exactly one window rather than both.
- ⚠ **All calendar windows are UTC, deliberately** — *"players span the world and share one World
  Throw, so a board whose day boundary depends on the viewer would rank the same two players
  differently for each of them."*
- `rollingWindow(now, ms)` plus `calendarDayUTC` / `calendarWeekUTC`, and `HOUR_MS` / `DAY_MS` /
  `WEEK_MS`.
- `QUALIFY` — the minimum-sample floors, with the statistics written out.

**So "per day/week/month" is an argument, not a feature.** `rollingWindow(now, DAY_MS)`,
`rollingWindow(now, 30 * DAY_MS)`. Every stats function in `server/src/stats.ts` already takes a
`Window` as its first parameter.

⚠ **And the earnings board the question is asking for already exists.** `stats.heatBoard(w, limit,
userIds?)` groups `BankEvent` by user and sums `amount` over the window. That is "points earned this
day / week / month", ranked. Its own comment states the intent — *"HEAT — who is on a tear right
now… a newcomer must be able to top it while ranking nowhere all-time. It is FORM, not standing."*
It even takes an optional `userIds` to make the board **local to one Roblox instance**, by ranking
only the people currently present.

What is windowable today, and by what:

| quantity | event row | function |
|---|---|---|
| points banked | `BankEvent` | `heatBoard` |
| completed streaks | `StreakEvent` | `longestStreaks` |
| throws / wins / forfeits | `PlayerRound` | `throwsInWindow`, `winsInWindow`, `forfeitsInWindow` |
| biggest pot reached | `PlayerRound.pointsDelta` | `biggestRounds` |
| bank depth distribution | `BankEvent.streakAtBank` | `bankDepths`, `depthHistogram` |
| playtime / presence | `Session` | — |
| rate boards, qualified | `PlayerRound` | `qualifiedBoard`, `playerRates`, `playerStanding` |

## 2. ⚠ `totalPoints` is the one thing that CANNOT be windowed — and that is already settled

Two separate reasons, both load-bearing:

**It has no history.** `totalPoints` is a running balance. Nothing records when it changed, so
"totalPoints last week" is not a query that can be written — the number simply does not exist.
`BankEvent`'s own header says so, and says it is why the collection was created:

> *"The wallet's own counters (totalPoints, lifetimeBanked) are running totals with no timestamps,
> so without this collection 'points earned last week' cannot be answered at all."*

**And it is the wrong basis anyway.** `docs/wiki/world/core-loop.md` carries the standing warning:
*"Do not rank players by `totalPoints`. It is a wallet, decremented by purchases, so a player who
spends on fireworks or a teahouse falls down the board."*

**So the windowed earnings board is `BankEvent.amount` summed — which is `heatBoard`, which is
shipped.** The question has already been asked and answered in this repo; the answer was to build
the event collection, and it was built.

### ⚠ THE GENERAL RULE, and it is the transferable part

> **To window a quantity you need an EVENT ROW, not a counter.** A counter can only ever answer
> "now". Every windowed number in this repo is backed by a timestamped, indexed collection, and
> every quantity lacking one is unanswerable over time — permanently and retroactively, because the
> history was never written.

That makes the capability question a **checklist rather than an architecture**: for any quantity
someone wants windowed, does an event row exist? If yes it is a parameter. If no it is a new
collection, and ⚠ **the gap is retroactive** — the day you add the row is the earliest date any
window can start.

### The one real gap: spending

**Purchases have no event row.** `server/src/routes/store.ts:49` does `req.user.totalPoints -=
character.price` and writes nothing else. There is no `PurchaseEvent` model. So:

- "what did players spend on this week" — **unanswerable**, and will stay unanswerable for every
  day that passes before a row exists.
- sinks cannot be measured against sources, so the economy has a faucet with a meter
  (`BankEvent`) and a drain without one.

⚠ **This matters before the fireworks catalog, not after.** That item is next in the design queue
and is the first thing that will make spending interesting to measure. A `PurchaseEvent`
(`userId, sku, price, platform, timestamp`, indexed `{userId, timestamp}` and `{timestamp}`) is a
direct copy of `BankEvent` and should land before the catalog does, so the catalog's first week is
measurable. **Not proposed as part of the aura work** — flagged here because it is the answer to
the general question the owner asked, and it is cheap now and impossible to backfill later.

## 3. Continuous decay — and the aura is cheaper than this document first priced it

The juice/seniority spec previously said the decaying peak *"is NOT free, unlike seniority"* and
would need a stored `potPeak` / `potPeakAt` pair. **That over-priced it. Corrected there and here:**

⚠ **The peak is already in the data, and the reason is a documented trap turned inside out.**
`core-loop.md` warns that `PlayerRound.pointsDelta` on a WIN records **the new pot value, not the
increment** — which is why *summing* the column overstates earnings badly. But that is exactly the
property that makes **`$max` over the column correct**: the largest WIN delta in a window *is* the
highest pot reached in that window. The shape that breaks one aggregation is the right shape for
this one. `stats.biggestRounds` already runs it globally; a per-player version is a `$group` with
`$max`, over the existing `{ userId: 1, timestamp: -1 }` index.

So: **no new collection, no new stored field, no schema change.**

### The live path, and why it needs no query at all

```
join        → ONE $max aggregation over PlayerRound in the window → seed potPeak / potPeakAt
settlement  → the server already computes nextPot per player; if it beats the peak, raise it
roster push → potPeak + potPeakAt ride the per-round broadcast that already carries currentStreak
client      → heat = f(potPeak, now − potPeakAt), pure arithmetic, every frame, no traffic
```

⚠ **Aggregate at JOIN, never at settlement.** This is an existing standing rule, not a new one:
`presence.qualified` is awarded on the join call for exactly this reason — *"it needs a 7-day throw
count and settling a round must not run a per-player aggregation for every participant"*
(`docs/wiki/world/familiars.md`). One aggregation per join is cheap; one per participant per round
is 1,440 rounds a day multiplied by the room.

**The decay itself belongs in `shared/`, beside `StreakAura`.** It is a pure function of
`(peak, elapsed)`, which makes it Lune-testable — and ⚠ it must name no Roblox type, the rule that
`Kamon` and `StreakAura` both carry in their headers.

**In-memory or persisted?** In-memory per instance is the cheapest thing that works, and the seed
aggregation on join is what makes it survive a rejoin or a hop between PWA and Roblox. Only add
stored fields if a measured need appears. Recommended: **do not store it.**

### 3a. ⚠ "Session" was the wrong word — there is no boundary, only a half-life

Owner, 2026-08-26: *"what's a session? Just the time from login? Or can it extend over multiple
play sessions?"* The question exposes a bad name. The juice spec said **"decaying session peak"**
while describing a mechanism with no session in it. Three different things were being conflated:

| model | rule | behaviour |
|---|---|---|
| **login session** | resets at logout | a hard boundary |
| **rolling window** | `max` over `[now − W, now]` | a hard **cliff** — the peak vanishes in one frame when it ages out |
| **decay** | `heat = f(peak, now − peakAt)` | a continuous fade, no boundary at all |

**The login session is decisively wrong**, and `server/src/models/Session.ts` is what settles it. A
`Session` row is scoped by **`platform` AND `instanceId`**, and it is closed at `lastSeenAt` by a
stale sweep when a process dies. So under a session-scoped display:

- ⚠ **A Roblox server hop zeroes your glow.** New `instanceId`, new session. So does walking from
  the PWA into Roblox.
- ⚠ **A dropped phone connection zeroes it.** The program bar is kid-first on phones, and a status
  display destroyed by a network blip is broken rather than strict.
- ⚠ **And it re-creates the trap we just spent two rulings removing.** If the glow dies at logout,
  the game pays you to stay logged in — the same shape as *never bank* and *never throw*, aimed at
  children this time. Any hard boundary makes crossing it costly, and therefore makes not crossing
  it rational.

**The rolling window is also wrong, but only visually.** A `max` over a window is correct
arithmetic and a terrible animation: the moment the 27 ages past `W`, the glow drops to nothing
between two frames. A status effect that vanishes instantly reads as a bug, not as a decision.

**So: pure decay, and the window survives only as the seed at join.**

```
join   → the best pot in the last W, AND its timestamp  → seed (peak, peakAt)
         (sort pointsDelta desc, limit 1 — not a bare $max, because the TIMESTAMP is needed)
win    → given a new pot P: if f(P, 0) > f(peak, now − peakAt), replace with (P, now)
render → heat = f(peak, now − peakAt), every frame, pure arithmetic, no traffic
```

⚠ **The replace rule matters and is easy to get wrong.** It is NOT "keep the larger pot" — a stale
27 must eventually yield to a fresh 3, or the display is a session peak again by the back door.
Compare the two *decayed* values, never the raw ones. That comparison is the pure function, and it
is what the Lune test should pin.

**Which answers the owner's question directly: it extends across play sessions, and it needs no
concept of one.** Come back after a coffee and you are still faintly lit; come back tomorrow and
you are dark. Nothing resets, nothing has an edge to fall off, and no boundary is worth gaming.

**The half-life is the density dial.** Too short and it collapses back into the live pot — sparse,
which was the original complaint. Too long and everyone is lit, it saturates, and it becomes tenure
— which is the rank failure from §2 of the juice spec. A round is 60s and an evening's play is
tens of minutes, so **~20 minutes is offered as a starting point to argue down from**, in the spirit
of every other number on this project: a peak from half an hour ago at half strength, from an hour
ago at a quarter, gone by morning. ⚠ **It wants watching in play. Do not settle it in a document.**

**One semantic worth stating before it surprises someone:** a `$max` over the window measures the
peak *reached within that window*. A player who won up to 27 just before the window opened and has
held it since shows a lower peak than the pot they are actually sitting on. That is the honest
reading of "how hot have you been running lately" and should not be patched — but it is a real
difference from "the pot you hold", and someone will notice it and file it as a bug.

## 4. ⚠ The cost of the capability nobody has priced: retention

No collection in `server/src/models/` has a TTL index. Rounds are 60s exactly, so **1,440 rounds a
day**:

| collection | rows/day at 50 concurrent throwers | rows/year |
|---|---|---|
| `PlayerRound` | ~72,000 | ~26 M |
| `Round` | 1,440 | ~526 K |
| `BankEvent` / `StreakEvent` | far fewer | — |

The windowed *queries* stay fast — every one of them is an indexed range scan, and a range does not
care how much history sits behind it. What grows without bound is **storage and index size**, which
is an Atlas tier question rather than a latency one.

Not urgent at friends-and-family scale, and ⚠ **not a reason to delete anything**: `Round`'s
per-round `distribution` is what makes retrospective crowd-reading analysis possible for every round
ever played, which is a deliberate asset. Flagged because the owner is about to lean on this
capability, and because the honest answer to *"can we window everything"* is **yes, and the bill is
the history you must keep to do it.**

## Summary

| the owner asked | answer |
|---|---|
| backend support for a decaying aura? | **Yes, and cheaper than priced** — the peak is a `$max` over existing indexed data; no schema change |
| per day/week/month leaderboards? | **Already built** — `windows.ts` + `stats.heatBoard`; the period is an argument |
| on `totalPoints`? | ⚠ **No, and it should not be** — no history, and it is a wallet. Use `BankEvent.amount`; that is what it exists for |
| is decay a general unlock? | **Yes, gated on one rule**: a quantity is windowable iff it has an event row. Checklist, not architecture |
| anything missing? | ⚠ **Spending.** No `PurchaseEvent`; the gap is retroactive, and the fireworks catalog is next |

## Raw layer

`server/src/windows.ts`, `server/src/stats.ts` (heatBoard, biggestRounds, livePots, qualifiedBoard),
`server/src/models/BankEvent.ts`, `server/src/models/PlayerRound.ts`, `server/src/models/User.ts`,
`server/src/engine/Settlement.ts`, `server/src/routes/store.ts`,
`docs/wiki/world/core-loop.md` (the `pointsDelta` trap, the `totalPoints` warning),
`docs/wiki/world/familiars.md` (aggregate-at-join), `docs/wiki/world/stats-room.md`,
`docs/superpowers/specs/2026-08-26-juice-vs-seniority-design.md`.
