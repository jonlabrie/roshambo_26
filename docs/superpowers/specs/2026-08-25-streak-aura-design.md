# Streak Aura — design

**Goal:** a mobile, culture-neutral, self-limiting way for a player to flex what they are doing
*right now* — a whole-body glow whose strength tracks the pot they currently have at risk.

**Status:** spec only. Not planned, not built.

## Why this shape, and not the four things it replaces

The ruling chain matters, because each rejected answer failed for a reason this one has to respect.

| rejected | when | why |
|---|---|---|
| plumage band on the familiar | 2026-08-21 | a 7-inch bird cannot carry status at arena distance |
| worn sashimono | 2026-08-25 | *"a bit on the nose for an experience meant to be social"* |
| HUD sashimono | 2026-08-25 | the martial read is in the SHAPE, so it follows the banner into the HUD |
| any worn crest | 2026-08-25 | ⚠ a Chinese-themed area is planned; the avatar travels, so it must stay culture-neutral |

And the positive constraint from the same conversation: **it cannot depend on owning a teahouse**
(owner: *"let's not assume everyone has a teahouse"*), so a mobile channel is required rather than
optional.

⚠ **This spec does NOT display grade.** Grade's reward is the unlock — the five familiars become
*available to choose* as a player progresses, so status is signalled by flying a rare bird and is
opt-in. A player at 5th dan flying an uguisu reads as ungraded, and that is deliberate. What this
spec displays is live state, which is a different clock.

## What it shows

**`stakingStreak`, not `currentStreak`.** Banking resets `stakingStreak` and leaves `currentStreak`
alone (`server/src/wallet.ts`), so `stakingStreak` is exactly "the run I still have money on". A
cautious banker has a long `currentStreak` and no exposure; the aura should say *risk*, not
*history*.

**Rarity is automatic, and it is the whole reason this works where a banner did not.** Roughly a
third of players win any given round, so a 3-streak is about 1 in 27 and a 5-streak about 1 in 240.
Most of the arena is dark most of the time, and the display is scarce precisely when it is
impressive. A banner glowed on everyone at once; this glows on almost no one.

## Measured engine facts

Measured 2026-08-25 in the live place, not assumed:

| | |
|---|---|
| Highlight cap | **255 per client** (raised from the old 31). 50 players fits comfortably. |
| overflow behaviour | ⚠ **silent** — 300 Highlights created, zero warnings. Exceeding the cap fails invisibly. |
| create 50 | 3.09 ms |
| destroy 50 | 0.49 ms |
| toggle 100 `Enabled` flips | **0.12 ms** |

⚠ **POOL, NEVER CHURN.** Per operation, toggling `Enabled` is ~50× cheaper than creating, and
Roblox documents that adding/removing a Highlight triggers a geometry rebuild with attendant
frame spikes. A streak aura flicks on and off constantly by nature — every SAFE and LOSS ends one.
So: one Highlight per tracked player, created once, `Enabled` toggled thereafter.

⚠ Highlights **not** under Workspace still count toward the cap, so a parked pool is not free. Bound
the pool by present players.

## Rendering

- One `Highlight` per player in the roster, adorned to their `Character`, created on join and
  destroyed on leave. Client-side only, like `BirdController` — ⚠ server-built parts are subject to
  `StreamingEnabled` and never reach the screen (learned the hard way, 2026-08-25).
- `Enabled = stakingStreak >= AURA_MIN_STREAK`.
- Re-adorn on `CharacterAdded`; a respawn replaces the Character and orphans the adornee.

**Channels, in priority order.** ⚠ Colour must not be the primary channel — colourblind players
lose it entirely, and the program bar is kid-first on phones:

1. **`FillTransparency`** — the strength of the body glow. Primary; scales with streak.
2. **`OutlineTransparency`** — a rim that tightens as the streak deepens. Secondary.
3. **`FillColor`** — warm to hot across the range. Tertiary, decorative, never load-bearing.

Suggested steps (to be gated visually, not argued in a document):

| stakingStreak | fill | outline | colour |
|---|---|---|---|
| 0–2 | off | off | — |
| 3 | 0.85 | 0.6 | warm amber |
| 4 | 0.75 | 0.45 | amber |
| 5 | 0.65 | 0.3 | orange |
| 6+ | 0.55 | 0.15 | hot |

`AURA_MIN_STREAK = 3`. Below that it would be common enough to be noise, which is the failure mode
being designed against.

## The one real dependency

⚠ **The client cannot see anyone else's streak today.** `familiarRoster` carries `grade`,
`gradeName` and `band` only (`main.server.luau:508`); `currentStreak` and `stakingStreak` go to
`profiles:applyServer`, which is per-player. So this needs `stakingStreak` added to the roster
payload and pushed on settlement.

That is a small change with two consequences worth stating:

- the roster broadcast becomes **per-round** rather than per-join/per-grade-change, since streaks
  change every round. Check the push sites (`main.server.luau:513, 719, 899`) before assuming
  cadence is free.
- everyone's live streak becomes public to every client. That is consistent with the 番付 room,
  which already shows live pots and runs, so it is not a new disclosure — but it is a disclosure.

## Risks and open questions

- ⚠ **TEST_MODE makes streaks meaningless.** Both prod and dev run the deterministic R→P→S cycle,
  so a streak currently rewards memorising the cycle rather than reading the crowd. The aura will
  look best exactly when it means least. Not blocking — but do not read early sessions as evidence
  the signal is meaningful.
- **Performance at 50 players is unmeasured.** The cap is fine and toggling is cheap; what is not
  known is the cost of ~10 simultaneously *enabled* Highlights on the A13, which is the device that
  governs the floor. Measure before widening the thresholds.
- **Does the aura fight the familiar?** The bird already reacts to a single round (rises on a win,
  sinks on a loss). The aura is a different clock — what survives across rounds — so they should
  complement. Verify by watching both during a real streak.
- **Whose aura shows?** Simplest is everyone including yourself. A first-person player never sees
  their own body, so consider whether the owner's own aura needs any other confirmation.

## Out of scope

**The leader halo is deferred, and the reason is not effort.** Item 7's standings board still ranks
on points-per-throw behind a floor derived for win rate, and the parked note records that twenty
*identical blind* players over 360 throws produce a winner earning 2.5× the median **by chance
alone**. A quiet board showing a noisy ranking is survivable; a glowing crown on that player's head
broadcasts noise as achievement, and they will believe it. Fix the ranking basis first — it is
already the named first thing to pick up when item 7 is revisited.
