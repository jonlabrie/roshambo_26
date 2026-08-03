# Play HUD, round two — the ring, the splash, and getting out of the way

**Date:** 2026-08-03
**Status:** Approved direction. Follows `2026-08-03-play-hud-revision-design.md` after the
owner's fourth Studio gate ("a vast improvement over where we started earlier today").
**Branch:** `m4b-zendojo-art-pass`

## Goal

Seven changes from one Studio session. They share a theme: **the HUD should celebrate the
player's own outcome and otherwise get out of the way.**

| # | Change |
| --- | --- |
| 1 | The escalation countdown is halved and becomes dismissable |
| 2 | Results become a standalone splash, visible on any screen, optional |
| 3 | Round detail — crowd split, player count — moves to the top of the ledger |
| 4 | `SWITCH?` fills its button (an overlay, not a move) and expires in 1s |
| 5 | A PWA-style circular round timer replaces the bottom hairline |
| 6 | The wallet plate moves left of the ring and becomes tappable |
| 7 | With the hairline gone, the whole cluster moves down |

---

## §1 — The escalation countdown gets smaller and dismissable

The owner's reasoning is the governing constraint for this whole document:

> the worst thing that could happen is it gets thrown into a user's view in the middle of
> watching fireworks/relaxing.

Roshambo is an ambient hangout. Most people in the canyon at any moment are not playing.

- **Half the size.** The frame goes 154 → 77 tall and the count 84px → 42px. The prompt text
  drops 24px → 16px rather than to 12 — halving a 24px label makes it unreadable, and the
  point of the change is the *footprint*, not the type.
- **Dismissable.** Tapping it clears it for the rest of the round. It re-arms next round,
  subject to the existing uniform three-miss backoff.
- **Already optional.** `escalationPrompts` in the preferences footer governs it and needs no
  change.

Dismissing makes it a `TextButton`, which sinks input where a `Frame` did not. That is
accepted **because the element is transient and small**: it exists only in the last 5 seconds
of a round, only when armed, and dismissing it is the whole point. Everything else on this
surface stays `Active = false`.

A dismissal is not a decline. `declinedThisRound` means the player deliberately withdrew a
throw; dismissing the nag means "stop shouting", and both silence the prompt for the round, so
they share the same field.

## §2 — Results become a standalone splash

Today the result is one dense line in the transient toast: `🏆 WIN! World threw R — R 33% · P
33% · S 33%`. It carries four facts in one breath and celebrates none of them.

It becomes a **splash**: big, centred, and about the player.

| Result | Headline | Consequence line |
| --- | --- | --- |
| WIN | `YOU WIN!` | `×3 — pot is now 81` |
| SAFE | `SAFE` | `your pot survives, streak resets` |
| LOSS | `YOU LOSE` | `27 points forfeited` |

The headline carries the feeling; the consequence line teaches the rule. `SAFE` keeps the
game's own vocabulary rather than "TIE", because a match here is not nothing — the pot
survives and the streak resets, and a new player learns that from the line beneath.

**Visible on any screen.** It gets its own `ScreenGui` at `DisplayOrder 30`, above both
takeovers (20) and the minimal HUD (0). A result that lands while the ledger is open must
still be seen.

**Not interactive.** `Active = false`, no button, nothing to tap. A large sinking element in
the middle of the screen is the failure this branch has already hit twice — a card on the
movement thumbstick, and a panel leaking taps to live buttons beneath it. An accidental tap
that dropped the player into a movement-suspending takeover would be worse than the problem it
solved. The `≡` and the revealed plate are the doors.

**Optional**, as a second preference switch beside `escalationPrompts`. Two switches is what
the footer was built for. A settings *page* becomes warranted at four or more; it is not yet.

**Gated on the drum**, like everything else that names a result. `RevealTheater` lands ~3s
before the drum settles, so the splash fires on the `drumRest` cue with the same
`REVEAL_SAFETY` fallback the tape tile and the headline already use.

## §3 — Round detail moves to the top of the ledger

The crowd split and the player count leave the play screen. The owner:

> we focus on the player's outcome, celebrating that, and if they want more info they can
> click through to the ledger.

A **LAST ROUND** band goes at the top of the ledger, above the hero band: the world's throw,
the player's throw, their result, the crowd split as a three-way bar, and the number of players
in the round.

This is a strict improvement on the toast that carried it. A transient line nobody can re-read
becomes a panel that is still there thirty seconds later.

## §4 — `SWITCH?` fills its button, and expires in 1s

- **It stays an overlay, sized to the button exactly** — not `BTN_W - 8`, which on a phone left
  36px holding ~60px of text and rendered as roughly `WITC`. Filling the button gives the word
  the room it needs without moving anything.
- **`SWITCH_PROMPT_SECONDS` goes 4 → 1.** Four seconds was chosen when a prompt was the only
  thing on screen; in practice it lingers. Both outcomes of expiry are safe — expiring restores
  exactly the state before the stray tap — so a short fuse costs nothing.

**Covering the glyph beneath is correct, not a compromise.** An earlier draft of this section
moved the pill above the button so the player could "see what they are switching to". That
reasoning was wrong, and the owner caught it: **confirming a switch unlocks; it never selects
the button that was tapped.** So the glyph underneath is not a destination. Both unchosen
buttons are **proxies for switch-and-cancel**, and either one does the same thing. Revealing the
glyph would advertise a destination that does not exist — which is precisely the confusion the
one-gesture rule was designed to avoid.

## §5 — A circular round timer, from the PWA

`src/components/PieTimer.tsx` is the reference: a 54px ring, green until `timeLeft <= 4` then
red, the remaining seconds in the middle, swapping to the world-throw glyph on reveal.

**Roblox has no SVG**, so the sweep is a **segmented ring** — N wedges around a circle, lit
from the top clockwise in proportion to the time remaining. Which segments are lit for a given
fraction is pure arithmetic and belongs in a Lune-tested module; the controller only paints
what it is told. 36 segments at 10° reads as a ring at this size.

Carried over from the PWA: the count in the middle, the glyph swap on reveal, and green → red
as time runs short.

**The ring and the escalation prompt turn urgent at the SAME moment** (owner's ruling). Both read
`HudModel`'s `ESCALATE_AT`; the PWA's own 4s literal does not come across. A ring reddening one
second before or after the countdown appears would read as two separate alarms about the same
fact, which is worse than either alone. One threshold, one signal, expressed twice.

**The glyph swap obeys the spoiler gate.** The world throw appears only once the drum has
settled — the same `drumRest` cue that gates the tape tile, the splash and the headline.
Showing it early would give away the throw while the wheel is still turning, which is the one
thing that gate exists to prevent.

Where the countdown is unknown — the unsynced-clock path, where `secondsLeft` is a constant —
the ring shows no sweep at all rather than a full ring that never moves. `timerKnown` already
carries this.

## §6 — The wallet plate moves left and becomes a door

The ring takes the plate's slot, immediately left of the tape. The plate moves left of the
ring. Bottom row, left to right: **plate → ring → tape**.

The plate is **tappable again** when visible, opening the ledger. This is safe now in a way it
was not before: the reason it went inert was that it had moved into the strip Roblox uses for
camera drag, and it is no longer there. So the ledger has two doors — the `≡` (two-stage) and
the plate itself whenever it is showing. Tapping `≡` then the plate is the same two taps as
double-tapping `≡`, and either works.

## §7 — The hairline goes, and everything moves down

The ring makes the bottom timer bar redundant. It goes, and with it the reason for the cluster
to hold that much clearance from the bottom edge — the whole cluster moves down into the space
it vacates.

This is one constant, not a re-layout: everything below the plate is already derived from
`HudLayout.EDGE` and the cluster stack. The removed hairline was `TIMER_H` / `TIMER_H_HOT` plus
its own margin.

---

## Architecture

| File | Change |
| --- | --- |
| `roblox/src/shared/RingTimer.luau` *(new)* | pure: which segments are lit for a fraction, and the warning threshold |
| `roblox/src/shared/HudLayout.luau` | ring geometry; drop the hairline; re-derive the cluster |
| `roblox/src/shared/HudModel.luau` | `SWITCH_PROMPT_SECONDS` 4 → 1; dismissal folded into `declinedThisRound`; splash inputs |
| `roblox/src/client/HudController.client.luau` | the ring; plate moves + becomes a button; `SWITCH?` above; escalation halved + dismissable; hairline deleted |
| `roblox/src/client/SplashController.client.luau` *(new)* | the result splash, its own `ScreenGui` at `DisplayOrder 30` |
| `roblox/src/client/main.client.luau` | splash wiring on the `drumRest` gate; the round-detail payload for the ledger |
| `roblox/src/client/LedgerController.client.luau` | the LAST ROUND band; a second preference switch |
| `roblox/src/server/main.server.luau`, `server/src/…` | `resultSplash` preference, alongside `escalationPrompts` |

## Testing

Pure and Lune-tested: `RingTimer`'s segment arithmetic (0 lit at zero, all lit at full, monotonic,
never exceeding the count, and the warning threshold); `HudModel`'s 1-second prompt expiry;
dismissal silencing the escalation for the round without counting as a declined throw.

Server: the `resultSplash` preference round-trips through `PUT /players/:id/preferences-hud`
and appears in `buildProfilePayload`.

Not automatable, therefore the owner's gate: whether the ring reads as a ring at 54px with 36
segments; whether the splash is big enough to feel like a celebration and short enough not to
intrude; and whether the halved escalation still commands attention.

## Out of scope

- a settings **page** — two switches is what the footer was built for; revisit at four
- changing the PWA to match the Roblox threshold
- fireworks (baseline item 3)

## Decisions taken

1. **The splash is not interactive.** A large sinking element mid-screen is a failure this
   branch has already made twice; an accidental drop into a movement-suspending takeover is
   worse than the friction it would save.
2. **`SAFE` keeps its name**, with a consequence line to teach it. "TIE" would imply nothing
   happened, when the streak just reset.
3. **The escalation prompt may sink input**, uniquely on this surface, because dismissing it is
   the point and it is transient and small.
4. **The ring is segmented**, not an image or a mask — no assets, and the arithmetic is pure
   and therefore testable.
5. **The ring's glyph swap obeys the drum-rest gate**, like every other thing that names a
   result.
6. **The plate becomes a door again.** It went inert only because it was in the camera-drag
   strip, and it has left.
7. **The ring and the escalation share `ESCALATE_AT`.** One threshold expressed twice, never two
   alarms about the same fact.
8. **`SWITCH?` covers the glyph beneath it, deliberately.** Confirming a switch unlocks and never
   selects, so that glyph is not a destination — both unchosen buttons are switch-and-cancel
   proxies. Revealing it would advertise a destination that does not exist.
