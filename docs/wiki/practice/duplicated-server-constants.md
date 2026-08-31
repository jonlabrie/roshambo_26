---
shelf: practice
updated: 2026-08-27
checked: 2026-08-31
---

# Duplicated Server Constants

Recurring defect class: a number authoritative on the server, re-derived or written
down client-side, goes stale when the server moves. Suspect it FIRST when a display is
wrong but the underlying number is right.

## Three instances of one bug shape (2026-08-05)

All exposed by the round changing from 27s to 60s ([[round-and-hud]]). None were
introduced by that change — it just moved the numbers far enough that the errors
stopped being subtle.

| where | what it duplicated | how it failed |
| --- | --- | --- |
| `src/hooks/useGameLoop.ts` result overlay | a literal `5000` for REVEAL's length | went stale twice as REVEAL went 3s → 5s → 7s; its own comment recorded the first drift |
| `src/App.tsx` `totalTime={20}` | the OPEN phase's length | `progress = timeLeft / totalTime` exceeded 1, so `strokeDashoffset` went negative for the first 31s of every round |
| `HudController` ring span | OPEN's length, *measured* as `math.max(span, secondsLeft)` | a joining player's FIRST sample IS the maximum, so the ring read 100% full however little of the round was left |

**The fix is the same every time: put the number on the wire and read it.** `revealMs`
and `openMs` ride the PWA's `init` payload; the Roblox ring takes `aux.openSeconds`
from `RoundScheduleConfig.OpenSec`, which `main.client` was already reading for the
metronome. Keep the old derivation as a *fallback* for the pre-replication window —
that costs nothing and is strictly no worse than what was there.

## The diagnostic signature

**A display is wrong while the underlying number is right.** The owner's report was
exactly this: "starts at 100 percent full no matter how many seconds are left — the
seconds are displayed correctly." Digits print the raw value; the ring divides by a
*second, duplicated* value. Whenever those two disagree, look for the denominator, not
the source.

## Why it keeps happening here

The comment above the ring's span said **"the round's full span is not on the wire"** —
true when written, falsified later, and nobody re-checks a premise stated as fact.
Watch for that shape: a comment that justifies a client-side derivation by asserting
the value is unavailable. When the wire gains the field, the derivation becomes a
latent bug and its own comment is what hides it.

Compounding it: no test harness loads a `.client.luau` and the PWA had no tests, so
every one of these is invisible to CI — see [[visible-is-not-pixels]]. Only someone
looking at the screen finds them.

## The sweep (run 2026-08-05 — don't re-run speculatively)

Found **one serious gap and four benign mirrors**, so the sweep was worth doing but
the well is now mostly dry.

**Closed:** the game's rules existed in three implementations and only two were gated.
`server/src/engine/GameRules.ts` (authoritative) and `roblox/src/shared/GameRules.luau`
both ran `shared-fixtures/game-rules.json`; the PWA's copy was inline in
`useGameLoop.ts` with no test, because the frontend had no test runner at all. Now
`src/lib/gameRules.ts` + vitest, same fixtures, and the hook calls the module instead
of restating the rules — a test guarding an extracted copy while the shipping code
keeps its own inline version guards nothing.

⚠ **The three mirrors are gated, but they are not identical, and that is deliberate.** Partial
banking (2026-08-27) added `keepOptions` / `isValidKeep` to the server and the Luau mirror but
NOT to `src/lib/gameRules.ts`. The PWA's copy exists to compute a round outcome the server has
not sent yet; choosing a rung is a UI affordance, and no client can ask for a partial bank yet.
The fixture still gates all three on every rule they share — `partialBank` is simply a section
the PWA's suite does not enumerate. **Revisit when the PWA gets a partial-bank control**, and
until then do not read "three implementations" as "three identical implementations".

**Left alone, all correct as of the sweep:** `MAX_DECORATIONS = 24`
(`DecorationCatalog.luau`), `MAX_INVITED = 50` (`main.server.luau`),
`DecorationCatalog.ORDER` vs `PRICES.decoration`'s keys, and the access-mode strings
in `AccessPolicy.luau`. All are re-enforced server-side (`loadout.ts`, `economy.ts`),
so drift is a confusing UI, never a bypass — and the two numeric ones carry "mirrors
economy.ts" comments, which is probably why they have stayed right.

**Verify a new fixture gate by MUTATION, not by a green run.** Flipping one entry of
`BEATS` must fail; if it does not, the gate is decorative. Same lesson as
[[visible-is-not-pixels]].

**vitest at the repo root MUST stay scoped** (`include: ['src/**/*.test.ts']` in
`vite.config.ts`). Unscoped it discovers `server/`'s suite, tries to boot a MongoDB
memory server, and fails eight healthy test files.
