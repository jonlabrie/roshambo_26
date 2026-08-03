# Play HUD — minimal + maximal, with onboarding bones

**Date:** 2026-08-02
**Status:** Approved direction. Item 2 of the Friends & Family baseline
(`2026-07-30-friends-family-baseline-design.md`).
**Branch:** `m4b-zendojo-art-pass`

## Goal

Replace the provisional Roblox play UI with a designed, touch-first HUD system: a quiet
**minimal** state that suits an ambient hangout, a deliberate **maximal** mode for players who
want to study their numbers, and four onboarding beats that ride the same surface.

Along the way this fixes defects found while surveying: the HUD and the canyon lanterns render
Unicode stand-ins instead of the real glyph assets, unbanked points have no persistent
representation, and the wallet and the round share one string.

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
  → **No information element is ever `Active`.** Tape, plate, status, timer, toasts and the pot
  disc all pass through. The interactive budget is three throw buttons, the plate (the door to
  maximal), and one conditional button in the slot above the throws — **BANK THESE** while a pot
  exists, **ACCEPT YOUR FATE** while fate-bound, never both. Nothing else.
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

## The pot indicator — banking, riding, and Roblox's gambling line

**Revised 2026-08-02, mid-implementation, by owner ruling.** The first design blocked the player
after a WIN until they answered **RISK IT** or **BANK n**. That is now withdrawn. What follows
replaced it, and the reasoning matters more than the mechanic.

### Why the RISK button was wrong

Roblox proscribes simulated gambling, and this experience is kid-first, so the line matters more
than usual. The mechanic was never a wager — a player can only ever choose whether to **collect**
winnings or keep playing; they cannot take points they own and stake them on an outcome. That
distinction is load-bearing and was already in the design.

But a button reading **RISK IT** dresses a collect-or-continue choice in wager language. It made
the game *look* like the thing the mechanic carefully is not. The owner's instinct was that the
two buttons made the "superposition" of unbanked points explicit; the conclusion was that a
persistent indicator does that better, without ever asking the player to *stake* anything.

(Design reasoning only. Roblox's community standards shift and must be checked against the live
policy before shipping — this document is not an authority on them.)

### The mechanic

- Whenever `pointsAtStake > 0`, a **pot indicator** sits directly above the throw row: the figure
  in a red disc, pulsing while the win is unacknowledged, with a **BANK THESE** button beside it.
- **Throwing again is riding.** No button says so. Playing on is the most natural possible
  expression of "let it ride", and it needs no wager vocabulary.
- **Banking is always available** while a pot exists. There is no state in which a player has
  unbanked points and no way to collect them.
- **Nothing blocks a throw.** The `SubmitPick` win-gate is removed.

### What `unresolvedWin` means now

It survives, with a narrower job: **"the last scored round was a WIN and the player has not banked
since."** It drives the *pulse*, nothing else. It is maintained entirely by the server —
`Settlement` sets it on a WIN and clears it on SAFE/LOSS, `bankPot` clears it — so no client
action is needed to resolve it, and throwing again clears it naturally at the next settlement.

Because it persists on the profile, a player who wins and leaves returns to a still-pulsing pot.
That is the re-engagement hook the blocking design was reaching for, without the block.

### What this removes

`POST /resolve-win` and `wallet.resolveWin` collapse back into the pre-existing `/bank`, which
already clears the flag and accrues `lifetimeBanked`. The `ResolveWin` remote,
`NetworkClient.postResolveWin`, the server handler and the `SubmitPick` gate all come out.
`BankRequest` — which existed all along — carries banking again.

Retained from that work: `unresolvedWin` on the profile, `Settlement` maintaining it, `bankPot`
clearing it, `lifetimeBanked`, all nine counters, and `PlayerProfiles.unresolvedWin`.

### The fate prompt shares the slot

A LOSS forfeits the pot, so `pointsAtStake` is **always 0 while a player is fate-bound**. The pot
indicator and the fate prompt can therefore never be on screen together, and they share one slot
above the throw row:

| State | Slot shows |
| --- | --- |
| `pointsAtStake > 0` | pot disc + **BANK THESE** |
| fate-bound (after a LOSS) | **ACCEPT YOUR FATE** |
| neither | nothing |

This restores the affordance that the old `AcceptFate` button provided and that the first
revision of this spec dropped by omission. **The fate gate itself is unchanged** — `FateRegistry`
still refuses picks server-side until the fate resolves. Only the win gate is withdrawn.

## Escalation

The bottom hairline is quiet by default. Under **5 seconds remaining**, it turns red and
thickens, and a large non-interactive count with `CHOOSE A THROW` appears centred on screen.

It is a label, not a button, so it costs nothing in camera surface.

**It must be gated, or it becomes a nag.** Roshambo is ambient: a player chatting on their deck
with no intention of throwing would otherwise get a five-second red alarm every single minute,
forever, turning the calmest part of the game into an alarm clock.

The escalation is **armed** when all of these hold:

1. The player *can* throw — not fate-bound, not win-bound. (A bound player cannot act on
   "choose a throw", so escalating at them is pure noise.)
2. The player has **not** already picked this round.
3. **Their preference allows it** (see *Preferences*, default on).
4. Any one of: they **have not yet thrown this session** (a new arrival, who needs the prompt
   most), they **threw in the previous round**, or they **have a pot riding**.

And it **disarms after three consecutive missed rounds**, whichever condition armed it. It
re-arms the moment they throw again.

A round only counts as *missed* if the player **could** have thrown and did not. Rounds spent
win-bound or fate-bound are not misses — they were not ignoring anything, they were prevented.

The effect: a new arrival is prompted, a mid-streak player about to let it lapse is prompted, and
anyone who has settled into hanging out goes quiet within three minutes and stays quiet. Nobody
is nagged and nobody is silently surprised.

Session-scoped state (has-thrown-yet, consecutive-misses) lives **client-side in `HudModel`** and
resets on rejoin, which is correct — a returning player is a new arrival and is armed again.
Only the preference persists.

Proximity to the arena was considered as an arming signal and rejected: it is wrong for anyone
watching from a teahouse deck.

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
4. **Feed** — timestamped scrollback. **Personal-only in v1**: your own banks, streaks, results
   and milestones passed. This is data the client already receives, so it costs nothing. Social
   lines ("kaz_9 banked 243", "mochi claimed the switchback perch") need a server-side event
   stream and join later with item 6, which builds one anyway.

...and a fifth element that is not a block:

5. **Preferences footer** — a thin row along the bottom of the panel. It carries one switch in
   v1 (*escalation prompts on/off*) and is sized to take later preferences — toast verbosity,
   audio, and so on — without ever needing a second takeover surface. Persisted on the profile
   alongside `padPreferences`.

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

Twelve profile fields in total across this spec: those nine, plus `unresolvedWin`, `seenBeats`
and `escalationPrompts`. All three of these server slices were confirmed as belonging in item 2 —
without the gate the RISK/BANK overlay has nothing behind it, without the counters the ledger
shows four numbers, and without `seenBeats` onboarding cannot fire once.

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
  (`pointsAtStake`, `currentStreak`, `totalPoints`, `unresolvedWin`, `escalationPrompts`),
  fate-bound state, and its own consecutive-miss counter, returns the minimal view model: what
  the plate shows, whether the throws are enabled, what occupies the slot above them (pot,
  fate prompt or nothing) and whether the pot pulses, and whether the escalation fires.
  **The escalation arm/disarm rule lives here and is fully unit-tested** — four arming
  conditions, a three-miss backoff, and a definition of "missed" that excludes bound rounds. It
  is the rule most likely to be got subtly wrong and the most annoying if it is.
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
  `lune run tests/run`. The escalation rule gets explicit cases for each arming condition, the
  preference switch, the three-miss backoff, re-arming after a throw, and the "bound rounds are
  not misses" carve-out — including a bound player who stays bound for many rounds and must
  still be armed the moment they resolve and throw.
- `GameRules` fixtures in `shared-fixtures/game-rules.json` are untouched — pot progression is
  unchanged. Only *who may throw* changes.
- Server: `unresolvedWin` is maintained solely by `Settlement` (set on WIN, cleared on
  SAFE/LOSS) and by `bankPot` (cleared on bank). Both get Vitest coverage. No client action
  resolves it, so there is no route to test for it.
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
5. ~~**The win-bound state never expires and has no default.**~~ **WITHDRAWN** — see below.
6. ~~**Overlay at half height**~~ / 7. ~~**One `ResolveWin` remote**~~ — **WITHDRAWN** with it.
   The blocking RISK/BANK overlay was built, reviewed and green before being replaced. It was
   withdrawn not because it failed but because **"RISK IT" is wager language on a mechanic that
   is deliberately not a wager**, and Roblox proscribes simulated gambling in a kid-first
   experience. A persistent pot indicator makes the same point — these points are not yours yet
   — while framing the action as *collecting winnings*, which is what it actually is. Riding
   became implicit again: you ride by throwing. See *The pot indicator*.
   The removal also restored bank-at-will, which the blocking design had quietly taken away, and
   gave the orphaned ACCEPT YOUR FATE prompt a home.
8. **The escalation arms for new arrivals and backs off after three missed rounds**, and is
   player-switchable. Owner decision, and a better rule than any of the three offered: arming on
   "pot riding" alone would have excluded the new player who needs the prompt most, while arming
   on "anyone who can throw" would have nagged everyone forever. The backoff is what makes it
   safe to arm generously.
9. **Feed is personal-only in v1.** Social lines wait for item 6's event stream.
10. **A preferences footer in maximal**, rather than a mute affordance on the alarm itself
    (which could only ever turn the thing off, never back on) or a separate settings panel
    (a second takeover surface for one boolean). The footer is sized for later preferences.
11. **All three server slices stay in item 2** — the gate, the counters and `seenBeats`.

## Open

Nothing blocking. Two things deliberately deferred:

- **Social feed lines** — item 6, which builds the event stream this needs.
- **Folding the Teahouse toggle into the HUD** — item 4, with merchant row.
