# Play HUD revision — the switch mechanic, the right margin, and parking the fates

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

Throws are accepted for the whole of `ACTIVE`, up to `secondsLeft <= 0`. There is no longer
any "you have committed, so the round is closed to you" state — that state is what made
back-out impossible, and back-out is now the point.

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

### The player-state plate moves to the right margin

Top-centre put it in the middle of a phone's view. It moves to the **right margin, above the
jump button** — the strip Roblox claims for jump and camera drag, which a display with no
interactive elements can safely occupy. `Active` stays `false` on every part of it, so
camera drags pass straight through.

- inside the `JUMP_CLEARANCE` (0.15) column, `EDGE` from the right edge
- **points always**, in cream
- **streak only when non-zero**, above the points, in gold, as `×3`
- **the pot never appears here** — it has its own control (below)

Its height follows its contents: one row when the streak is zero, two when it isn't.

**Above, not below.** Roblox's default `TouchJump` sizes the button 70px on screens ≤500px
tall and positions it `UDim2.new(1, -(size*1.5-10), 1, -size-20)`, which leaves roughly
**20px** between its lower edge and the bottom of the screen — and on iOS that 20px is the
home indicator. On a tablet the button sits higher and there is ~90px below it, which is why
"below" looked viable. Phone-first, it is not. Above the button there is ~300px at every
size.

**The plate measures the button rather than predicting it.** The numbers above are Roblox's
current defaults, not a contract: they differ by screen size, they have changed before, and
nothing stops them changing again. So the plate reads
`PlayerGui.TouchGui.TouchControlFrame.JumpButton` at runtime and sits `PLATE_JUMP_GAP = 10`
above its measured top edge, re-deriving when that button resizes or the viewport changes.

If `TouchGui` is absent — desktop, where there is no jump button at all — the plate falls
back to the bottom-right corner at `EDGE`, which is free on that platform. This is the only
placement in the HUD that depends on something Roblox owns, so it is the one placement that
must not hard-code Roblox's arithmetic.

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
- **the new right-margin plate** — gets a low-opacity backing plate of its own rather than
  bare text over the canyon

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
| `roblox/src/shared/HudLayout.luau` | drop `CONFIRM_*`; re-derive the cluster; right-margin plate geometry |
| `roblox/src/shared/EffectRegistry.luau` | `LOSS = {}` |
| `roblox/src/client/HudController.client.luau` | plate → right margin; bank button; tape below; `SWITCH?`; strokes off text |
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

Also tested: the plate falls back to the bottom-right corner when no jump button is found,
and re-derives its position when the measured button moves or resizes.

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
7. **The plate goes in the jump/camera strip, above the jump button**, and measures that
   button at runtime rather than predicting where Roblox put it. A display with no
   interactive elements is the one thing that can safely live in that strip; below the
   button there is only ~20px on a phone.
8. **The pot leaves the plate entirely** and becomes `BANK n POINTS`.
9. **`UIStroke` never goes on a `TextLabel`.** Contrast comes from a backing.
10. **The teahouse becomes a takeover**, and its ✕ returns to play.
11. **Fates are parked at `EffectRegistry.LOSS`**, one data change, machinery intact.

## Open

Nothing. All three judgement calls were confirmed by the owner before the plan was written:
tapping the lit glyph does nothing, the prompt expires after 4s, and the plate sits above
the jump button.
