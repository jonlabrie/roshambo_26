# Play HUD revision — the switch mechanic, the wallet glance, and parking the fates

**Date:** 2026-08-03
**Status:** Approved direction. Revises `2026-08-02-play-hud-design.md` (item 2 of the
Friends & Family baseline) after the owner's third Studio gate.
**Branch:** `m4b-zendojo-art-pass`

## Goal

Replace the throw-confirmation system with a **choose-then-switch** interaction, move the
player-state display out of the middle of the mobile view, make the transient messages
readable, make the teahouse panel dismissable, and **park the fates system**.

Everything here comes from a single Studio session on a phone. Four of the five items are
defects in work shipped yesterday; the fifth (fates) is a design the owner has withdrawn.

## Why the confirmation was unsound

Yesterday's design asked for a second tap to throw when a pot was riding, and — because a
missed second tap must never cost a round — threw the selection anyway at the lockout
(`HudModel.autoCommit`). The owner's ruling:

> if we ask players to confirm a throw, and they don't, then the throw happens anyway,
> we've screwed up.

That is correct and it is not fixable by tuning. A confirmation whose unanswered state is
"yes" is not a confirmation; it is a delay with a misleading label. Either the throw is
withheld — which costs the round the design was built to protect — or the prompt is a lie.
The whole construction goes.

What survives is the *problem* it was aiming at: a mis-tap should not silently commit a
throw the player didn't mean. The new mechanic solves that by making the **mis-tap
recoverable** rather than by making the correct tap harder.

---

## §1 — The throw interaction

### The rule

One tap chooses. The chosen glyph lights and pulses blue; the other two darken almost out.
**At that point the throw is chosen** — there is no second tap, no pending state, no prompt.

Changing your mind goes through the two glyphs you *didn't* pick:

- Tapping either other glyph raises a **`SWITCH?`** prompt over **that** button.
- Tapping that same button again returns **all three glyphs to available, with nothing
  chosen**.
- From there the player either chooses again, or walks away — which is how you back
  entirely out of a round.

Confirming a switch **does not select the button you tapped**. It unlocks. That is
deliberate: it is the only reason a back-out exists at all, and a confirm-that-also-selects
would make backing out impossible without a fourth gesture.

### State

Per round the client holds three things:

| Field | Meaning |
| --- | --- |
| `chosen: string?` | the glyph the player has chosen |
| `switchPrompt: string?` | the glyph currently showing `SWITCH?` |
| `sent: boolean` | whether the pick has gone over the wire this round |

Invariant: `switchPrompt ~= nil` implies `chosen ~= nil` and `switchPrompt ~= chosen`.
A prompt is always a question *about an existing choice*, raised over a *different* glyph.

### `HudModel.tapAction(inputs, symbol)`

Evaluated top to bottom; first match wins.

| Condition | Action | Resulting state |
| --- | --- | --- |
| round cannot take a throw | `ignore` | unchanged |
| `chosen == nil` | `choose` | `chosen = symbol`, `switchPrompt = nil` |
| `symbol == chosen` | `ignore` | unchanged |
| `symbol == switchPrompt` | `clear` | `chosen = nil`, `switchPrompt = nil` |
| otherwise | `prompt` | `chosen` unchanged, `switchPrompt = symbol` |

`HudModel.applyTap(state, action, symbol)` is the single pure function that maps an action
to the next state, exactly as it is today — the controller calls it rather than assigning
the fields inline, so the table above is enforced in one place and pinned by an exhaustive
test.

**Tapping the lit glyph does nothing.** There is exactly one gesture that undoes a choice
(the switch path), so there is exactly one thing to learn. A lit glyph that also un-chose on
tap would give the same button two meanings depending on invisible state.

**A prompt moves.** Chose ROCK, tapped PAPER, then tap SCISSORS: the prompt leaves PAPER and
appears over SCISSORS. Two prompts are never on screen at once.

### The prompt expires

`SWITCH_PROMPT_SECONDS = 4`. An unanswered prompt clears itself and leaves `chosen`
untouched. It also clears when the round ends or when any other glyph is tapped.

A prompt is a question, and an unanswered question must not sit on the screen indefinitely
— but note that its expiry is *safe in both directions*: expiring restores exactly the
state before the stray tap, and answering it only ever unlocks. Neither outcome can throw
anything.

### The round stays open to taps

Throws are accepted for as long as the choice can still be **honoured** — which is not the whole
of `ACTIVE`. It ends when the pick goes on the wire, roughly the last half-second:

```luau
inputs.phase == "ACTIVE" and inputs.secondsLeft > 0 and not inputs.sent
```

**The `not inputs.sent` clause is load-bearing. Do not remove it.** An earlier draft of this spec
said taps stay live for the whole of `ACTIVE`, on the reasoning that a closed round is what made
back-out impossible. That was right about the old confirm mechanic and wrong here, and the gap it
left was found during implementation: `sendAtLockout` fires at `secondsLeft <= 0.5` while taps
stayed live to `0`, leaving a **400–500ms window in which a player could double-tap another glyph,
watch all three light up, and believe they had withdrawn — while the server already held their
throw.** Precisely the dishonesty this whole feature exists to prevent.

The window is structural, not a slip: the half-second of slack exists so the pick reaches the
server before the lockout, so there will always be a period where the throw is on the wire and
the round has not visibly ended. The only honest resolution is that **once sent, the round is
closed to that player** — and because `throwsEnabledFor` drives both `tapAction` and
`view.throwsEnabled`, the buttons dim and the player *sees* it close.

Owner-visible consequence, accepted: the throw buttons go dark for the last ~0.5s of every round.
19.5 of 20 seconds remain changeable.

### When the pick goes over the wire

**Once per round, at the lockout.** `SubmitPick` fires when `secondsLeft <= SEND_AT` with
`SEND_AT = 0.5`, if and only if `chosen ~= nil` and `sent == false`.

`secondsLeft` is `secondsToLockout` (`RoundCoordinator:_lockoutAtMs`, `T₀−2s`), so zero *is*
the lockout. Half a second is the slack for the client → `SubmitPick` →
`RoundCoordinator:submitPick` → `ThrowBuffer` trip, which the buffer's own lockout-triggered
flush then carries.

If the round leaves `ACTIVE` with `chosen` set and unsent, send it once anyway. The server
may answer `PICKS_CLOSED` and the whiff toast then says so honestly; trying and being told
beats never trying. (This is yesterday's `autoCommit` mechanism, unchanged — what changes is
that it is now the *only* send path rather than a rescue for a missed confirmation.)

**Why not send on the first tap.** Back-out has to actually withdraw the throw or it is a
lie, and `ThrowBuffer` is upsert-only — there is no removal in the buffer, in the delta, or
in `POST /api/v1/throws`. Holding the pick client-side makes back-out honest with no
protocol change at all. The cost is that a client which disconnects between choosing and the
lockout throws nothing, which is the correct reading of that situation anyway.

### Escalation

`armed` keys off `chosen == nil` rather than `pickedThisRound`; the uniform three-miss
backoff is unchanged.

One addition: **backing out silences escalation for the rest of that round.** A player who
deliberately withdrew has answered the question `CHOOSE A THROW` is asking, and re-nagging
them is exactly wrong. A `declinedThisRound` flag is set by `clear` and cleared at round end.

The round still counts as a **miss** for the backoff — they did not throw — so three
consecutive back-outs also reach silence.

### What this deletes

- the confirm strip and its reserved row (`HudLayout.CONFIRM_H`, `CONFIRM_GAP`)
- `TAP AGAIN TO THROW`, the `Don't ask again` checkbox
- the `confirmThrows` preference: the ledger footer switch, the client field, the
  `PUT /players/:id/preferences-hud` key, and its slot in `buildProfilePayload`.
  The Mongo field on `User` **stays** — dropping it would need a migration and buys
  nothing. The footer goes from two switches to one (`escalationPrompts`).
- `HudModel.confirmRequired`, and the `confirmPending` / `releasable` view fields

---

## §2 — Layout

### The player-state plate moves to the bottom row, and is normally hidden

**Superseded the right-margin placement (owner, mid-implementation).** The plate does not go
into the jump/camera strip at all. It becomes a **single line at the bottom of the cluster,
below the hamburger and to the left of the tape**, exactly as tall as a tape tile so the bottom
row reads as one band.

- **normally hidden.** Points are not a thing you need at a glance; a riding pot is, and that
  already has its own always-visible `BANK n POINTS` button.
- **revealed by a single tap of the hamburger**, and by any change in the point total or the
  streak length (see below)
- **holds for 2 seconds, then fades**
- **a second tap of the hamburger while it is visible opens the ledger**

The window for that second tap lasts as long as **anything is on screen** — the hold plus the
fade — not exactly 2s. A control that is still visible must still be answerable; the alternative
is a UI inviting a gesture it will not honour, which is the same defect the post-send throw
window turned out to be.

Content is one line, right-aligned against the tape's left edge, content-sized so it reserves no
dead space: `900` normally, `×3  900` when a streak is riding.

This kills the jump-button measurement entirely. `HudLayout.plateBottomOffset` loses its only
caller and goes, with its tests — the plate no longer sits anywhere near anything Roblox owns.

### Numbers count rather than jump

Every figure the HUD shows for the wallet **animates to its new value** rather than snapping:
the point total, the streak, and the pot on the bank button. Roughly half a second, decelerating.

The reason this is worth building rather than decoration: **banking becomes legible as a
transfer.** Press `BANK 27 POINTS` and the button's figure runs down to zero while the balance
below runs up by the same amount. Nothing has to say what banking did; the two numbers say it by
moving in opposite directions at the same moment.

It falls out of one rule — *animate any change* — rather than a special case, because a bank
lands as a single `ProfileUpdate` carrying both the emptied pot and the raised total. Two other
cases come free and read correctly:

- a **LOSS** drains the pot to zero with the balance untouched — a forfeit, visibly not a
  transfer
- a **WIN** triples the pot in place

Two consequences the implementation has to honour:

1. **The bank button must survive its own count-down.** Its visibility follows the *displayed*
   figure, not the model's — `bankVisible` goes false the instant the pot is zero, so a button
   that hid on the model would take the animation off screen before anyone saw it.
2. **The animation is keyed on the target changing, not on `render` running.** `render` is a
   10Hz repaint; restarting the count every tick would freeze every number at its first frame.
   This is exactly how the bank pulse failed earlier in this branch.

### The right margin, and why it isn't

Recorded because the reasoning still holds and the constants it produced are being deleted.

The plate was going to sit in the right margin above the jump button. **Above, not below**:
Roblox's default `TouchJump` sizes that button 70px on screens ≤500px tall and positions it
`UDim2.new(1, -(size*1.5-10), 1, -size-20)`, leaving roughly **20px** beneath it on a landscape
phone — and on iOS that 20px is the home indicator. A tablet has ~90px there, which is what made
"below" look viable; phone-first, it is not.

That placement also had the plate **measure** the jump button rather than predict it, since
those numbers are Roblox's current defaults rather than a contract.

None of it survives: the plate is in the bottom row now and touches nothing Roblox owns.
`HudLayout.PLATE_JUMP_GAP` and `HudLayout.plateBottomOffset` are deleted with their tests. The
lesson worth keeping is the general one — **anything positioned against something the platform
owns must measure it, not encode its arithmetic.** Nothing in the HUD does that any more.

### The ledger needs its own door

Moving the plate broke something the design had been quietly relying on. **A tap on the plate
was the only way to open the ledger** — deliberately, so that the maximal panel cost no
persistent button anywhere on screen (`LedgerController`'s own header comment says exactly
this). The plate was "the only interactive information element in the whole design".

The premise for putting it in the jump/camera strip was that it holds no interactive elements.
That premise was wrong about the plate as it existed, and taking it at face value left
`EventBus.OpenLedger` with two listeners and **zero firing sites** — the ledger unreachable, and
with it MY TEAHOUSE, the preferences footer and every lifetime statistic.

The owner's ruling: **the plate becomes genuinely inert, and a small dedicated icon opens the
ledger.** The alternative — keeping the plate tappable — would have put a sinking rectangle in
the camera-drag strip, which is the one thing that strip cannot host.

- a `≡` button, square, sized to the same touch floor as a throw button
- inboard of the throw cluster, bottom-aligned with the throw button row so it sits at the same
  reach as the throws
- it is the fourth and last interactive element in the minimal HUD, after the three throws and
  the bank button

This concedes the "no persistent button" principle that deleted the teahouse toggle. It is
conceded knowingly: that toggle was removed because it *collided* with the throw row on a narrow
viewport, not because a button was unaffordable. This one is placed against the cluster rather
than into a corner, so it moves with the cluster and cannot collide with it.

**The button is two-stage**, and the plate's reveal is its first stage:

| Tap | State | Result |
| --- | --- | --- |
| 1st | nothing visible | reveal the points line; hold 2s, then fade |
| 2nd | line still visible (hold **or** fade) | open the ledger |
| 1st | line faded out | reveal again — the count restarts |

A double-tap from cold therefore opens the ledger, because the first tap reveals and the second
lands inside the window. Nobody has to learn the two stages to reach the ledger the obvious way.

### The pot becomes one button

The slot above the throw row carries a single button reading **`BANK 27 POINTS`**, visible
only while `pot > 0`, pulsing while `unresolvedWin`. The separate red disc and the generic
`BANK THESE` button merge into it — the figure belongs *in* the control that acts on it.

### The tape moves below the buttons

Cluster, top to bottom: **bank button → throw row → tape**. With the confirm strip gone the
cluster is shorter overall, and `HudLayout.CLUSTER_TOP_FROM_BOTTOM` (which is the only thing
keeping onboarding cards off the live buttons) re-derives from the new stack.

```
┌──────────────────────────────────────┐
│                                      │
│                                      │
│              [ BANK 27 POINTS ]  ⬆   │
│              [ R ][ P ][ S ]         │
│              [ ▫ ▫ ▫ ▫ ▫ ]     ×3    │
│                                900   │
│══════════════════════════════════════│
└──────────────────────────────────────┘
```

### Selection emphasis

Carried forward from yesterday's gate and pushed further, since it now does more work:
the chosen glyph is blue, at full opacity, haloed, and **pulsing**; the other two are
dimmed and warmed until they nearly disappear. A button carrying a `SWITCH?` prompt lifts
out of the dimmed state while its prompt is up, so it is visibly the thing being asked
about.

---

## §3 — Contrast comes from a backing, never from an outline

### The defect

The owner could read the ledger, `TAP AGAIN TO THROW` and the round results, but not the
transient messages. That partition is exact, and it is not about colour:

| Readable | Stroke on a **container** |
| --- | --- |
| ledger panel, cards, switches | `stroke(panel, …)`, `stroke(card, …)` |
| confirm strip | `stroke(confirmStrip, …)` |

| Unreadable | Stroke on the **TextLabel itself** |
| --- | --- |
| onboarding copy | `OnboardingController:151` — 2px on 17px text |
| escalation count | `HudController:730` — 3px |
| escalation prompt | `HudController:744` — 2px |

A `UIStroke` parented to a `TextLabel` outlines **every glyph**. At 2–3px on 12–17px type the
outline approaches the stem width: the counters in *a*, *e*, *o* fill in and adjacent glyphs
merge. Near-black outline on cream text is a dark smear — "unreadable" at the large end and
"missing text" at the small end, which is both symptoms the owner reported.

I added those strokes yesterday as belt-and-braces over an *already opaque* card. They were
never load-bearing.

### The rule

**Text contrast comes from an opaque backing behind the text. `UIStroke` goes on frames and
buttons, never on a `TextLabel`.**

Applied:

- **onboarding copy** — remove the stroke; the card is already opaque `WASHI` with
  near-white copy (~18:1)
- **escalation overlay** — remove both strokes; the count and prompt gain a rounded opaque
  `WASHI` backing plate, which they never had (they floated over open canyon)
- **toast** — `BackgroundTransparency` 0.3 → 0.05, and it moves to top-centre at `EDGE`,
  the band the plate has just vacated
- **the wallet plate** — gets a low-opacity backing plate of its own rather than bare text over
  the canyon, and its fade takes that backing and its stroke along with the text

---

## §4 — The teahouse becomes a takeover

### The defect

`TeahouseController.client.luau:121` fixes the panel at `PANEL_W, PANEL_H = 340, 520`, and
`:155` positions the ✕ at `viewportHeight − (PANEL_BOTTOM + PANEL_H) + CLOSE_INSET`
= `viewportHeight − 572`.

On a landscape phone (~400px tall) that is **about 170px above the top of the screen**.
There is no clamp anywhere in that path, so it is unconditional: the ✕ is off-screen and
most of the 520px panel is too. The owner's report — opens over the play screen, cannot be
dismissed — is exactly this arithmetic.

### The fix

The teahouse becomes a **takeover on the ledger's pattern**, which is the pattern that
doesn't have this bug:

- viewport-relative panel (`UDim2.new(1, -2*EDGE, 1, -2*EDGE)`), so it cannot exceed the
  screen at any size
- ✕ **inside** the panel's own header, positioned against the panel rather than against a
  fixed offset from the viewport edge
- movement suspended while open, restored on close
- its own `DisplayOrder`, above the HUD (the teahouse GUI currently has none, i.e. 0 —
  the same layer as the minimal HUD)

**The suspension is extracted, not copied.** `LedgerController:74–150` is ~70 lines of
hardened work: it prefers `PlayerModule:GetControls()`, falls back to `WalkSpeed`, warns on
each failure path, and **latches which mechanism it suspended with** so a late-resolving
`PlayerModule` cannot strand a player at `WalkSpeed 0` forever. Duplicating that into a
second takeover would duplicate the bug surface too, and the two panels can now be open in
sequence — a copy would let one restore what the other suspended. It moves to a shared
client module owning a single suspend/restore pair with a reference count, and both
takeovers call it.

Only one takeover is open at a time. `MY TEAHOUSE` in the ledger header closes the ledger
and opens the teahouse; the teahouse's ✕ returns to **play**, not to the ledger — dismissing
a screen should end the detour, not step back through it.

---

## §5 — Parking the fates

The owner's ruling: the idea is flawed, and the rock drop, the avatar grow and
`ACCEPT YOUR FATE` don't work. All three go quiet. The **animation machinery stays** —
celebration effects will be built on it.

### What stops

| Where | Change |
| --- | --- |
| `main.server.luau:429` | drop `fates:begin(userId)` on LOSS |
| `main.server.luau:422–428` | drop the delayed `applyGrow` on WIN; delete `applyGrow` and `growDelaySeconds` |
| `EffectRegistry.LOSS` | `{ byThrow = { … } }` → `{}` |
| `HudModel` | `fateBound` and the `slot` tenant go; the slot is the bank button or nothing |
| `main.client.luau` | stop flipping to `ACCEPT YOUR FATE`; stop clearing the pick on a fate |

`EffectRegistry.LOSS = {}` is the whole park for the client visuals. `EffectSelector.select`
returns `nil` for an empty pool, so no `fate*` effect ever reaches
`FateController:135`'s guard, and **`FateController` needs no edit at all** — it simply
never receives a flight. `WIN`, `SAFE`, `BANK` and `REVEAL` effects are untouched and keep
firing.

### What stays

- `FateRegistry` + its tests, and the `fates:isBound` gate in `SubmitPick` — now always
  false. It is one table lookup and it is the seam anything like this re-enters through.
- the `FateResolved` remote in `default.project.json` — removing it is a contract change
  for no gain
- `DoomEscalation`, `ChoreographyMachine`, `EffectSelector`, `TheaterController`,
  `FateController` and all their tests. `EffectSelector`'s `byThrow` branch is exercised by
  its own spec against a fixture registry, not the real one, so parking `LOSS` leaves no
  untested code.

### When celebrations return

The reusable lesson from yesterday's reveal-timing fix is **fire on the drum, not on the
wire**: `RevealTheater` lands ~3s before the drum settles, so anything triggered on the
remote is early. The recipe is `DrumStep.SETTLE_SECONDS` plus the server's
`StrikeAtServerTime` attribute, clamped by `TallySec` so it fails late and never early —
that is what `growDelaySeconds` did, and it is recorded here because the function itself is
being deleted.

Server-side visuals also need `applyGrow`'s constraint: **Humanoid scale replicates
server→client only**, so an avatar effect triggered on the client is visible to nobody but
its owner.

---

## Architecture

| File | Change |
| --- | --- |
| `roblox/src/shared/HudModel.luau` | `chosen`/`switchPrompt` state machine; drop `confirmRequired`, `fateBound`, `slot` |
| `roblox/src/shared/HudLayout.luau` | drop `CONFIRM_*` and the jump-button measurement; re-derive the cluster |
| `roblox/src/shared/EffectRegistry.luau` | `LOSS = {}` |
| `roblox/src/client/HudController.client.luau` | plate → bottom row + hide/reveal; `≡` door; bank button; tape below; `SWITCH?`; counting; strokes off text |
| `roblox/src/client/main.client.luau` | hold the pick to the lockout; `declinedThisRound`; drop the fate branches |
| `roblox/src/client/OnboardingController.client.luau` | stroke off the copy; safe band re-derives |
| `roblox/src/client/TeahouseController.client.luau` | takeover panel, header ✕, movement suspension |
| `roblox/src/client/Takeover.luau` *(new)* | the extracted suspend/restore pair, reference-counted |
| `roblox/src/client/LedgerController.client.luau` | footer drops to one switch; teahouse handoff closes the ledger; suspension moves out |
| `roblox/src/server/main.server.luau` | drop `fates:begin`, `applyGrow`, `growDelaySeconds` |
| `server/src/routes/apiV1.ts` | retire `confirmThrows` from the preference route and the profile payload |

`HudModel` and `HudLayout` stay pure and Lune-testable: no Roblox globals, dependency-injected,
never `require` each other.

## Testing

Luau (`lune run tests/run`), all in `HudModel.spec.luau` unless noted:

- `tapAction` — the full five-row table above, every state × every symbol
- `applyTap` — exhaustive over the four actions, asserting `clear` empties **both** fields
  and `prompt` leaves `chosen` untouched
- the invariant: no reachable tap sequence produces `switchPrompt ~= nil` with
  `chosen == nil`, or `switchPrompt == chosen`
- prompt expiry leaves `chosen` untouched
- send-at-lockout: fires once at `secondsLeft <= 0.5`, never twice, never with
  `chosen == nil`; fires once on leaving `ACTIVE` unsent
- escalation: `armed` off `chosen`; `declinedThisRound` silences; a back-out still counts a
  miss
- `EffectSelector.spec.luau` — unchanged, still covers `byThrow` via its fixture registry
- a fixture assertion that `EffectRegistry.LOSS` selects to `nil`, so re-enabling fates is a
  deliberate act that breaks a test rather than a silent one

Server (`server/ npm test`): `confirmThrows` no longer accepted by the preference route and
no longer present in `buildProfilePayload`.

`RollingNumber`: `t = 0` returns exactly `from` and `t >= 1` exactly `to` (an off-by-one at the
end leaves a permanently wrong total on screen), never overshoots, monotonic, counts down as
correctly as up, and clamps outside `[0, 1]`.

`sendAtLockout` is pinned from BOTH sides — that it sends at `0.5` and that it does NOT at `0.6`.
Without the upper bound, `SEND_AT` could be changed to anything up to 4.9 with the suite still
green, and that constant governs how long backing out stays honest.

Not automatable, and therefore the owner's Studio gate: whether the dimmed glyphs read as
"almost disappeared", and whether `SWITCH?` is legible at its size.

## Out of scope

- `NARROW_PX = 900` stays untuned
- the ledger's scroll window on a landscape phone
- `BoardController`'s dormant premature-fire (the jumbotron is not in
  `default.project.json`)
- `DayNightLockT` stays pinned at 0.40 — that is baseline item 8
- fireworks (baseline item 3)

## Decisions taken

1. **Confirmation is deleted, not fixed.** A prompt whose unanswered state is "yes" is not
   a prompt.
2. **Confirming a switch unlocks, it does not select.** This is what makes backing out of a
   round possible.
3. **Tapping the lit glyph does nothing.** One gesture undoes a choice.
4. **The prompt expires after 4s.** Both outcomes of expiry are safe.
5. **The pick is held client-side until the T₀−2s flush.** Back-out must be honest, and
   `ThrowBuffer` has no removal.
6. **A back-out silences escalation for that round but still counts as a miss.**
7. ~~**The plate goes in the jump/camera strip, above the jump button**, measuring it at
   runtime.~~ **SUPERSEDED by #13** — the plate never went there. The measuring machinery and
   its tests were deleted; nothing in the HUD is now positioned against geometry Roblox owns.
8. **The pot leaves the plate entirely** and becomes `BANK n POINTS`.
9. **`UIStroke` never goes on a `TextLabel`.** Contrast comes from a backing.
10. **The teahouse becomes a takeover**, and its ✕ returns to play.
11. **Fates are parked at `EffectRegistry.LOSS`**, one data change, machinery intact.
12. **The ledger gets a dedicated `≡` button** and the plate becomes genuinely inert. Found only
    when the plate moved: it had been the ledger's only door, and this spec's own premise —
    "there are no interactive elements in this display" — was false about the thing it described.
13. **The plate leaves the jump strip for the bottom row, and is normally hidden**, revealed by
    the `≡` button's first tap or by any change in points or streak. The `≡` is two-stage: a
    second tap while the line shows opens the ledger.
14. **Wallet figures count rather than jump.** One rule — animate any change — makes banking
    legible as a transfer, the pot draining into the balance, with no copy to explain it.

## Open

No open decisions. What remains is the owner's eye, on things no amount of reading settles:

- whether the dimmed unchosen glyphs read as "almost disappeared"
- `SWITCH?` legibility on a phone, where the pill is 36px wide
- the plate's nested `AutomaticSize.X` — an auto-sized Frame holding a scale-sized auto-width
  label plus padding — sizing to its text rather than collapsing to its padding
- the `≡` two-stage gesture from cold, especially a second tap landing mid-**fade**
- whether the bank drain and the balance rise read as one transfer at 0.5s
