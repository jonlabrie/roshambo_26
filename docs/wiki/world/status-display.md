---
shelf: world
updated: 2026-08-27
checked: 2026-08-31
---

# Status Display — the three clocks

What a player wears, glows with, or is otherwise seen to have earned. The bird itself is
[[familiars]]; the economy those numbers come from is [[core-loop]]. This page is the
architecture that sits over both, decided across 2026-08-21 → 2026-08-26 after **five**
carriers were designed and rejected.

## The three clocks

Owner, 2026-08-26: *"the Aura/grades/whatever need to show **current skill/luck**,
**longer-term success**, and **levels earned and held forever**."*

⚠ **THIS IS THE ORGANISING FACT, and every failed design failed by ignoring it.** Three
different things on three different clocks, and each needs its own carrier:

| clock | shows | carrier | state |
|---|---|---|---|
| **now** — minutes to hours | current skill / luck | the **aura** | built, gated 2026-08-26; metric under revision |
| **lately** — days to weeks | longer-term success | **nothing** | ⚠ no carrier exists |
| **forever** — monotonic | levels earned and held | **grade → the five familiar unlocks** | decided; no display, no announcement |

**The middle clock is the real gap**, and nobody was designing it. Every rejected carrier was
trying to put *forever* on a body — and forever already belongs to the unlocks — while *lately*
sat unclaimed. ⚠ Its data is **already computed**: `stats.heatBoard` is points banked over a
rolling window, per player, optionally scoped to the players present in one instance. It exists
as a board and has no presence on or around the player.

**And *forever* is settled but silent.** Grade is earned, banded and unlocked, and nothing
announces a grade-up or prints the grade ([[familiars]], *Still thin*). The **private**
acknowledgement is owed before anyone designs where strangers read it.

## Seniority does not get its own carrier

`bestStreak` — a personal best win-streak, independent of betting — was raised as a second aura
alongside "juice". **Ruled out, 2026-08-26.** Three reasons, in order of force:

1. ⚠ **It is already grade.** `bestStreak` drives the `run.3/5/7/10` milestone family
   (`server/src/engine/Milestones.ts`), which feeds grade → band → unlocks. A second carrier
   would render overlapping inputs as two disagreeing rankings on one body.
2. **Durable + monotonic = a rank**, which is what killed four designs below. The visibility
   toggle does not rescue it: opt-out is not opt-in, and a low-ranked player choosing between
   displaying low and conspicuously hiding reads low either way. **Unlocks have a dignified
   floor; ranks do not.**
3. **No usable middle.** At p(win) ≈ 0.30 a `bestStreak ≥ 3` is ~50 minutes of play — nearly
   everyone — and `≥ 5` is ~10 hours — almost nobody. The rarity complaint would invert, not
   resolve.

## ⚠ THE STANDING RULE FOR ANY LIVE METRIC

> **A carrier must be neutral on Bank vs Stake, and must never reward being present without
> playing.**

Bank-or-Stake is the only real decision in Roshambo, so **any metric either branch changes puts
a thumb on the scale of the choice the game exists to pose.** Four metrics have now been tested
against it:

| metric | pays you to | verdict |
|---|---|---|
| `stakingStreak` | never bank | rejected 2026-08-26 — *"banking is THE decision"* |
| `pointsAtStake` | never bank **and never throw** | rejected 2026-08-26 — an unthrown player is never settled (`Settlement.ts`), so the glow-optimal move is to reach a deep pot and stop playing |
| `currentStreak` | never throw once glowing | ⚠ shipped, and carries the same trap weakly |
| decay per **throw** | stop throwing once above what your pot can reach | rejected before building |

⚠ **"Pays you to stay online" is NOT the objection.** Owner, 2026-08-26: on Roblox, *"paying
players to stay in the game, return to it often, etc. — is a core Roblox game development
strategy."* Rewarding **presence** is the business model. Rewarding **presence without play** —
a lit-up player who never throws again — is the failure. RPS here is the **ambient** game:
players socialise and throw occasionally, like a zombie game where the zombies wander past.
Design for that player.

## The aura

Gated 2026-08-26 (*"Aura is reading fine"*). Embers from the feet, `LockedToPart`, with **rate
and pulse tempo** carrying the magnitude — ⚠ **not brightness**, which is only readable
comparatively and so fails when one player is glowing alone. Two versions were rejected first;
`roblox/src/shared/StreakAura.luau` carries why.

**Its metric is under revision** — `currentStreak` is neutral on banking but not on throwing.
The proposed replacement is a **decaying peak**: *how hot you have been running*, being the
highest pot you have **reached** recently, fading.

⚠ **NOT a "session" peak — there is no boundary anywhere in it.** A `Session` row is scoped by
`platform` AND `instanceId` and is swept closed at `lastSeenAt`, so a session boundary would
zero a player's glow on a server hop, on a walk from PWA into Roblox, or on a dropped phone
connection — and would pay players not to log off. A rolling-window `max` is correct arithmetic
and a terrible animation: the peak vanishes between two frames when it ages out. So: **pure
decay, with a window used only to seed at join.**

The rules, as ruled:

- ⚠ **`>=`, not `>`.** Matching your current value resets the clock. Otherwise hitting 27 at
  2pm and 27 again at 2:30pm never restarts it and the second run counts for nothing. **Repeating
  your level holds it indefinitely** — which is what carries the ambient player.
- ⚠ **Compare the DECAYED values, never the raw ones**, or a stale 27 blocks a fresh 3 forever
  and it is a session peak by the back door.
- **Decay is wall-clock, one rung of the 3ⁿ ladder per period** — proposed at **2 hours**, so a
  tier-4 peak (pot 27) runs 8 hours. Linear on the tier, not exponential on the pot: exponential
  never reaches zero and needs an arbitrary dark-floor bolted on, and a rung-per-period is a rule
  a player can hold.
- ⚠ **A WIN BUYS BACK TIME**, capped at the tier the best pot justifies. Time takes rungs away;
  wins give them back. This is what lets an occasional thrower stay lit without paying anyone to
  stop throwing.
- ⚠ **The peak needs no new storage.** `PlayerRound.pointsDelta` on a WIN records the **new pot
  value**, so a `$max` over it in a window *is* the peak — the documented trap that makes summing
  the column wrong is what makes maxing it right. Aggregate once **at join**, never at
  settlement ([[familiars]], the `presence.qualified` rule).
- The floor is **2** — an access decision, not a tuning number. Owner: *"let the kids dress up if
  they want."*

## The five rejected carriers

Recorded so none is re-raised. ⚠ **Three separate reasons**, and conflating them has already
caused one design to be re-proposed:

| rejected | when | the property that failed |
|---|---|---|
| plumage band on the familiar | 2026-08-21 | legibility — a 7-inch bird cannot carry status at arena distance |
| worn sashimono | 2026-08-25 | **a durable rank worn by everyone**; *"a bit on the nose for an experience meant to be social"* |
| HUD sashimono | 2026-08-25 | the martial read is in the shape, so relocating it changed nothing |
| any worn crest | 2026-08-25 | **culture** — see below |
| a seniority aura | 2026-08-26 | durability again, in a culture-neutral wrapper |

⚠ **A CHINESE-THEMED AREA IS PLANNED AND THE AVATAR TRAVELS.** Architecture may be culturally
specific — that is the point of an area. Anything worn or carried may not. This retired worn
crests, the sashimono in every form, and the `kamon` as a personal mark; `KamonDraw` stays for
the teahouse nobori, which do not travel.

⚠ **The resolution that made status work is that it is OPT-IN.** Grade's reward is the
**unlock** — five familiars become *available to choose* as a player progresses — so you signal
status by flying a rare bird you could only have earned, and you are free not to. *A badge
everyone must wear is a ranking; a rare thing you may choose is a flex.* The deliberate cost:
**a 5th dan flying an uguisu reads as ungraded.**

## Under evaluation, not decided

Two mechanics that would change what the clocks measure. Both are analysed in full.
⚠ **Partial banking is no longer merely evaluated — its SERVER HALF SHIPPED 2026-08-27.**

- **Partial banking** — bank down to a lower rung, pocketing the difference. ⚠ The math does not
  break (nothing requires a pot to be a power of three), and the risk-optimal play is
  `f* = (bank ÷ pot + 1)/4` — **a ratio, not a constant**, which is what keeps it a judgement
  call. At bank ≥ 3× pot, riding the whole pot is optimal, so the dramatic play becomes *earned*
  rather than wrong. **Ruled 2026-08-26, BUILT 2026-08-27:** a partial bank does **not** zero
  `stakingStreak` — the condition is now *"the pot reached zero"* rather than *"a bank happened"*,
  so a full bank behaves as before. `GameRules.keepOptions` gates the rungs, `bankPot` takes a
  `keep` defaulting to 0, and both transports accept it. ⚠ **Nothing can ask for it yet** — the
  client affordance is undesigned, which is why this stays under evaluation for the CLOCKS even
  though the mechanic exists. The `bankDepths` hazard below was fixed in the same change:
  `BankEvent.partial` now exists and the NERVE histogram filters to full banks, so the rows were
  never mixed. Spec:
  `docs/superpowers/specs/2026-08-26-partial-banking-design.md`.
- **Multi-hand splitting** — set aside by the owner 2026-08-26, *"impractical for now"*. ⚠ The
  finding worth keeping: **parking is a free option** that dominates both Bank and Stake, so it
  removes the game's only dilemma, and `stats.livePots` would go permanently quiet because nobody
  would ever hold a big pot at risk. Spec:
  `docs/superpowers/specs/2026-08-26-multi-hand-splitting-design.md`.

## Raw layer

`roblox/src/shared/StreakAura.luau`, `roblox/src/client/AuraController.client.luau`,
`server/src/engine/Milestones.ts`, `server/src/engine/GameRules.ts`,
`server/src/engine/Settlement.ts`, `server/src/wallet.ts`, `server/src/windows.ts`,
`server/src/stats.ts`, `server/src/models/Session.ts`, `server/src/models/PlayerRound.ts`.
Specs: `docs/superpowers/specs/2026-08-25-streak-aura-design.md` (superseded on rarity),
`2026-08-26-juice-vs-seniority-design.md`, `2026-08-26-time-windowed-values-design.md`,
`2026-08-26-partial-banking-design.md`, `2026-08-26-multi-hand-splitting-design.md`.
