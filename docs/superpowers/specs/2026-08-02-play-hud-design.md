# Play HUD — minimal + maximal, with onboarding bones

**Date:** 2026-08-02
**Status:** Approved direction. Item 2 of the Friends & Family baseline
(`2026-07-30-friends-family-baseline-design.md`).
**Branch:** `m4b-zendojo-art-pass`

## Goal

Replace the provisional Roblox play UI with a designed, touch-first HUD system: a quiet
**minimal** state that suits an ambient hangout, a deliberate **maximal** mode for players who
want to study their numbers, and four onboarding beats that ride the same surface.

Along the way this fixes two defects found while surveying: the HUD, lanterns and arena boards
all render Unicode stand-ins instead of the real glyph assets, and the bank-or-ride decision has
no explicit representation in the game at all.

## What exists today

Three independently hand-built surfaces, none of which know about each other:

| Surface | Owner | Position |
| --- | --- | --- |
| `RoshamboPickHud` — onyx disc, three circular ivory pick tiles, 5-tile tape beneath | `main.client.luau:69–80` | top-right, `IgnoreGuiInset = true` |
| `RoshamboUI` — status bar, scrolling ticker, BANK, ACCEPT YOUR FATE | `main.client.luau` | bottom-centre, flanked |
| `TeahousePanel` — toggle → upgrade/display/access panel | `TeahouseController.client.luau:106` | bottom-right corner |

`main.client.luau` is ~654 lines interleaving layout, state, spoiler-gating and remote wiring.
There is no shared layout authority, so BANK (at `0.75, +8`) and the Teahouse toggle (at the
corner) are neighbours by accident.

### Defect 1 — the pick cluster is in the worst corner on the screen

`main.client.luau:66` records the reasoning: the cluster was moved to the true top-right,
past the reserved topbar band, to escape the movement thumbstick. That overshot. On mobile the
top band is the most contested real estate we have:

- **top-left** — the Roblox unibar, and the **chat window expanding down beneath it**. In a
  hangout this is open most of the time. It is the *worst* corner, not a safe one.
- **top-right** — the player list, expanding down. No `SetCoreGuiEnabled` call exists anywhere
  in `src/client/`, so `PlayerList` is fully on by default; adding leaderstats grows it.
- **top-centre** — genuinely free. Roblox claims nothing here.

It is also the farthest reach from either thumb, which matters most on the tablets we expect.

### Defect 2 — three surfaces render fake glyphs

`src/shared/Glyphs.luau` is the canonical set: SDF image assets rendered from the PWA's
`src/components/Symbols.tsx`, with day image layers (`renderDay`) and Neon night meshes
(`buildNightNeon`). **Only `DrumController` uses it.** These render text characters instead:

- `LanternController.client.luau:20` — `{ R = "○", P = "─", S = "∧" }`
- `BoardController.client.luau:28` — same
- `main.client.luau:53` — same, and `:58` uses `∨` for the pick buttons

Every lantern up both gorge walls, every arena board, and the HUD are showing typographic
approximations of assets we already own and ship. The PWA's `ScissorsIcon` is unambiguously
apex-**up** (`M6 15L12 9L18 15`), and the PWA governs, so the HUD's `∨` goes away. (The
drum's own caret/caron asymmetry is separate, intentional lore and is untouched.)

### Defect 3 — the wallet and the round are the same string

`main.client.luau:627` renders `PTS {n} · POT {n} · STREAK {n}`. Those are two different kinds
of number: POT and STREAK are volatile and decision-relevant; PTS is a slow wallet. Merging
them means neither gets emphasis when it matters.

## Design constraints

- **Night-first.** The arena is night-first with day as a short interlude. The HUD is designed
  against night; day must survive. Ivory tiles nearly vanish against a pale daytime canyon, so
  contrast is driven from `nightFactor` (see *Day/night*).
- **Roblox owns the corners.** Thumbstick bottom-left, jump bottom-right, chat top-left,
  player list top-right. We design in what's left.
- **Camera drag is the whole right side of the screen.** Every `TextButton`/`ImageButton` sinks
  touch and is a permanent hole in it. `Frame`/`TextLabel`/`ImageLabel` sink only when
  `Active = true`, which defaults to false.
  → **No information element is ever `Active`.** Tape, plate, status, timer, toasts all pass
  through. The interactive budget is three throw buttons plus a conditional pair of choice
  buttons, and nothing else.
- **Movement is de-emphasised, never disabled.** You explore Roshambo; you do not mash movement.
  The bottom-left corner stays empty and unpaired so the thumbstick reads as a utility rather
  than half of a twin-pole control scheme. Roblox's default `DynamicThumbstick` is already the
  quiet one — confirm the place has not been switched to `ClassicThumbstick`.
- **Correspondence with the PWA is wanted**, not avoided. Rectangular throw buttons in a row,
  square tape tiles, the same glyphs.

## Minimal — the hangout default

Three elements, none of them a persistent extra button.

**Player-state plate — top-centre.** `STREAK · POT · POINTS` in one plate, in the one band
Roblox does not claim. Non-interactive except as the single entry point to maximal (see below),
so it never fights chat or the player list. This replaces both the old wallet string and the
status bar.

**Throw area — bottom-right, inboard of the jump button.** Three rectangular throw buttons in a
row, tape **above** them (five square tiles, newest left, ageing ivory→amber, with a corner dot
for the personal WIN/SAFE/LOSS result). Buttons stay closest to the bottom edge where the thumb
rests; the tape is read, never touched. Clear of the thumbstick, clear of jump.

**Round timer — a hairline along the bottom edge**, depleting. Full width, non-interactive,
readable from anywhere, competing with nothing. See *Escalation*.

Everything else that is currently persistent — the pot/streak bar, the BANK button, the prose
ticker — either folds into the above or becomes transient. **Minimal shows nothing that is not
either always true or currently happening.**

## The win-bound rule

This is a **rules change**, not only a layout change, and it is the core of the design.

### Today

`main.server.luau:361` rejects a pick only when `fates:isBound(...)` — the LOSS → "accept your
fate" gate. Riding is *implicit*: after a win the pot simply stays staked unless the player
presses BANK. There is no explicit RISK action anywhere in the codebase.

### Designed

A WIN **binds** the player until they answer. While bound they cannot throw. The choice —
**RISK IT** or **BANK n** — is painted **over the throw buttons at half height**, with the throw
glyphs dimmed and still visible beneath. The locked state is therefore self-explaining: nobody
wonders why a throw will not take, because the reason is sitting on top of it.

This is the `FateRegistry` pattern again, and the symmetry is deliberate:

- **LOSS** binds you to accept your fate.
- **WIN** binds you to ride it or take it.

**There is no default and no expiry.** If the round ends unanswered, the player stays bound —
across rounds, across sessions, across a week. They have a choice to make. This is safe: a
player who does not throw is not scored at all, so the pot is untouched and *"rounds skippable
without penalty"* holds. It also gives us a re-engagement hook we did not have — a returning
player is met with their own unanswered decision.

### Server slice

`unresolvedWin` is **not** derivable from `pointsAtStake > 0`: after choosing RISK the pot still
rides, so that value is identical in both bound and unbound states. It needs its own field.

- `User.ts` gains `unresolvedWin: boolean` (default false). Set at settlement on a `WIN`,
  cleared by either resolution. Persisting it on the profile makes it survive rejoin for free.
- A new resolve action. Today only `BankRequest` exists; add `RiskRequest`, or a single
  `ResolveWin` remote taking `"risk" | "bank"`. **Decision: one `ResolveWin` remote** — it makes
  the two outcomes symmetric and impossible to leave half-wired.
- `SubmitPick.OnServerEvent` gains an `unresolvedWin` gate beside the existing `fates:isBound`
  check.
- The gate is **server-authoritative**. The client dims and overlays, but the server is what
  actually refuses the pick.

### Scope note

Roblox and PWA economies are split by policy. This rule is **Roblox-only**; the PWA's implicit
ride is unchanged.

## Escalation

The bottom hairline is quiet by default. Under **5 seconds remaining**, it turns red and
thickens, and a large non-interactive count with `CHOOSE A THROW` appears centred on screen.

It is a label, not a button, so it costs nothing in camera surface.

**It must be gated, or it becomes a nag.** Roshambo is ambient: a player chatting on their deck
with no intention of throwing would otherwise get a five-second red alarm every single minute,
forever, turning the calmest part of the game into an alarm clock. The escalation fires only
when **all** of these hold:

1. The player *can* throw — not fate-bound, not win-bound. (A bound player cannot act on
   "choose a throw", so escalating at them is pure noise.)
2. The player has **not** already picked this round.
3. The player is in the game — **threw in the previous round, or has a pot riding**.

Someone who has not thrown in ten minutes gets silence. Someone mid-streak about to let it lapse
gets the alarm. Proximity to the arena was considered as the third signal and rejected: it is
wrong for anyone watching from a teahouse deck.

## Maximal — "the ledger"

Explicitly **not social, not ambient**. A mode, not a HUD state: it takes over the screen.

**Entry** is tapping the player-state plate — the only interactive thing in minimal besides the
throws, so no new persistent button is added anywhere. **Exit** is a large ✕, tapping outside the
panel, or Roblox's back gesture.

**Movement is suspended while it is open.** We are on a canyon of cliff edges and switchbacks,
and reading statistics while a thumb drifts on the stick is how someone walks off the FW11 deck.
The header states this in plain text — it is a promise, not an apology, and it is the clearest
signal that this is a mode.

Four blocks:

1. **Hero band** — `STREAK · POT · POINTS`, and the number minimal cannot afford:
   **"A WIN HERE PAYS n"**. That is the whole bank-or-ride decision as one figure, and it is
   free — pot ×3, derived client-side from the mirrored `GameRules`. If the player is win-bound,
   RISK/BANK appears here too, so opening the ledger to *think about* the decision does not force
   them to close it to *make* it.
2. **Lifetime** — banked total, rounds thrown, win rate, best streak, biggest pot, and a
   WIN/SAFE/LOSS bar.
3. **Your throws** — the player's own R/P/S distribution. Three counters, and the only statistic
   that says something about the player rather than their score. If scope is cut, keep this one.
4. **Feed** — timestamped scrollback of announcements and personal history.

### Where the ticker went

The F&F spec put the scrolling ticker in maximal. That is wrong if maximal is a deliberate
takeover — announcements would only be seen by someone who chose to open a stats screen.
Instead: **transient toasts in minimal** for interrupt-worthy events, **full scrollback in
maximal**. Ambient stays calm and nothing is lost.

### Counters this needs

The profile currently holds only `totalPoints`, `bestStreak`, `currentStreak`, `stakingStreak`,
`pointsAtStake`. Four numbers do not justify taking over a screen. Add, each a single increment
at settlement in `Settlement.ts`:

`roundsPlayed`, `wins`, `safes`, `losses`, `lifetimeBanked`, `bestPot`, `throwsR`, `throwsP`,
`throwsS`.

Item 7 (Statistics) does aggregation and the global/social view. **Item 2 builds the surface and
the plumbing only.** No leaderboard here — that is the Statistics room, by design.

### Size tiers

Three columns is a landscape-tablet layout. On a landscape phone the columns become too narrow
and the feed should collapse to a tab rather than a column. The F&F spec anticipated size tiers
"may fall out of the design" — this is where they fall out, and it is the only place they do.

## Onboarding

Four beats, **each fired by the event it explains** rather than queued at join. Nothing fires
until the thing actually happens, so a guided first-timer is never reading ahead of themselves.

| # | Trigger | Copy | Points at |
| --- | --- | --- | --- |
| 1 | First join, in the arena | "The drum throws every minute. Beat it." | the drum |
| 2 | First time the throws unlock | "Tap a throw." | the throw area |
| 3 | First win | "You won. Take it, or ride it — a win triples your pot." | the RISK/BANK overlay |
| 4 | First bank | "Banked. That's yours to keep." | the player-state plate |

Each is dismissable and shown once. `seenBeats: string[]` on the profile, checked server-side.

There is deliberately **no beat about movement or exploration** — consistent with
de-emphasising movement, and the owner is narrating anyway. These are bones, not a tutorial.

## Architecture

Follow the pattern `TeahouseController` already proves: a **pure, Lune-tested view-model module
in `src/shared`**, with a thin dumb renderer in `src/client`. The play HUD's current failure is
exactly the absence of that split.

New pure modules (no Roblox globals, dependency-injected, Lune-testable):

- **`src/shared/HudModel.luau`** — given round phase, seconds remaining, profile
  (`pointsAtStake`, `currentStreak`, `totalPoints`, `unresolvedWin`), fate-bound state and
  last-round participation, returns the minimal view model: what the plate shows, whether the
  throws are enabled, whether the choice overlay is up, whether the escalation fires.
  **The escalation gate lives here and is fully unit-tested** — it is the rule most likely to be
  got subtly wrong, and the most annoying if it is.
- **`src/shared/LedgerModel.luau`** — the maximal view model: derived win rate, pays-next,
  distribution percentages, WIN/SAFE/LOSS bar proportions. Pure arithmetic over the counters.
- **`src/shared/OnboardingBeats.luau`** — the beat machine: given `seenBeats` and an event,
  returns the beat to show or nil.

New client renderers:

- **`src/client/HudController.client.luau`** — minimal, rendering `HudModel`.
- **`src/client/LedgerController.client.luau`** — maximal, rendering `LedgerModel`.

`main.client.luau` **is retained, reduced to remote wiring and event fan-out only** — it keeps
the `RoundUpdate` / `RevealResult` / `ProfileUpdate` / `RevealTheater` / `FateResolved`
subscriptions and the drum-rest spoiler gate, and publishes them onto `EventBus` for the two
controllers to render. All `Instance.new` UI construction leaves it. Keeping it as the wiring
seam avoids re-deriving the spoiler-gating logic, which is subtle and correct today.

**All glyph rendering goes through `Glyphs.render`** — never a text character, anywhere.

The lantern and board glyph fixes are the same one-line substitution in
`LanternController.client.luau` and `BoardController.client.luau`. They are independent of the
HUD work and can land first.

## Day/night

The HUD subscribes to `nightFactor` the way `YamadoroDayNight`, `PaperLanternDayNight` and
`WaterVfxDayNight` already do — `EventBus.DayNight` plus the `DayNightConfig.CurrentNightFactor`
attribute, capturing authored values once so repeated applies never compound.

Night is the authored state. As day comes up, ivory tiles lose contrast against a pale canyon,
so the treatment darkens the plate behind them and deepens the tile rim. Following
`VfxNightDim`'s lesson: values that must move from an authored zero have to be **lerped toward a
target**, never scaled.

`DayNightLockT` is currently pinned at `0.40` (dusk) by the owner's choice, with
`PreNightTestLockT = 0.19` holding the original. **It must be cleared before any publish** — this
is already tracked as item 8.

## Testing

- `HudModel`, `LedgerModel` and `OnboardingBeats` are pure and get full Lune coverage via
  `lune run tests/run`. The escalation gate gets explicit cases for each of its three conditions
  and their combinations.
- `GameRules` fixtures in `shared-fixtures/game-rules.json` are untouched — pot progression is
  unchanged. Only *who may throw* changes.
- Server: the `unresolvedWin` gate and the `ResolveWin` route get Vitest coverage in `server/`,
  including the "bound across rejoin" case.
- Gates as always: `stylua --check src tools tests && selene src tools`, `lune run tests/run`,
  `npm test` in `server/`.

## Out of scope

- The PWA (its implicit ride is unchanged).
- Leaderboards, global statistics, aggregation — item 7.
- Milestone badges, flex surfaces — item 6.
- Rehoming the Teahouse toggle. It stays where it is; the new HUD simply no longer collides with
  it. Folding it into a coherent whole belongs with merchant row (item 4).
- Low-end Android performance floor.

## Decisions taken

Recorded because several were close calls, and one reversed mid-discussion.

1. **Buttons bottom-right, inboard of jump; tape above them.** Rejected: top-right (contested
   and unreachable), bottom-centre (worst tablet reach, blocks the down-canyon sightline),
   split across both corners (welds a lit block onto the thumbstick).
2. **A tall corner stack was rejected on movement grounds.** A mass opposite the thumbstick
   builds the twin-pole silhouette of an action game and promotes movement to half the control
   scheme. A low band does not.
3. **Camera rotation does not decide the corner.** Once information is non-`Active`, the dead
   zone is nearly identical in every layout. What it decides is the three rules under
   *Design constraints*.
4. **The wallet chip was moved out of the top-left and then removed entirely.** It was placed
   there on the conventional-currency-corner argument, which was wrong for a social experience —
   chat sits on it. POINTS lives in the top-centre plate instead.
5. **The win-bound state never expires and has no default.** Explicit owner decision.
6. **Overlay at half height**, not full — the dimmed glyphs underneath are what make the lock
   self-explaining.
7. **One `ResolveWin` remote** rather than a separate `RiskRequest`.

## To confirm at spec review

- **The escalation gate.** Its three conditions are designed above but were proposed, not
  ratified. Condition 3 in particular ("threw last round, or has a pot riding") is a judgement
  call about how loudly an ambient game may ask for attention.
- **Feed contents in v1.** Personal-only is cheap; mixing in server events ("kaz_9 banked 243")
  needs a modest event stream and could defer to item 6.
