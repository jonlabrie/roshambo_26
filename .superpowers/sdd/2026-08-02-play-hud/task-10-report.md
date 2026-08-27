# Task 10 report — `HudController`, and the retirement of the old UI

**Commits**

- `fe594fd` feat(roblox): HudController replaces the provisional play UI
- `7bd21a5` fix(roblox): one reveal toast, not two — and gate the distribution with it
  (self-review follow-up, see *Deviations* §2)

**Gates:** `stylua --check src tests tools` clean, `selene src tools` 0 errors / 0 warnings,
`lune run tests/run` 867 passed / 0 failed.

**Step 4 (Verify in Studio) was NOT run** — left to the controller per the standing rule that
Studio passes are batched by the controller, not taken by implementers.

---

## 1. What moved out of `main.client.luau` versus what was deleted

`main.client.luau` went from 654 lines to 261 and now contains **zero** `Instance.new` calls
(the only occurrence of the string is in the header comment explaining that).

### Moved (behaviour preserved)

| Thing | Where it went |
| --- | --- |
| `tape` / `badgeById` / `currentRoundId` / `revealedRoundId` | stayed in `main.client.luau` |
| `renderHistory`'s **spoiler gate** | `main.client.luau:visibleTape()` — the skip computation is character-for-character the old one; only the tail (painting tiles) became "return a list" |
| `pendingReveal` / `drumAtRest` / `maybeShowReveal` | stayed, unchanged in structure |
| the 3-second safety `task.delay` | stayed, unchanged (`REVEAL_SAFETY` names the 3) |
| the ivory→amber **ageing across the visible count** | `HudController:render` — presentation, so it followed the tiles |
| the ZenDojo palette constants | `HudController` |
| the reveal headline strings (WIN/SAFE/LOSS) | stayed in `main.client.luau`, now emitted as a `Toast` |
| the "TOO LATE" whiff notice | stayed, now a `Toast` |
| `EconomyController`'s `TickerMessage` output | now rendered by `HudController`'s toast (see §3) |

### Deleted

- Both `ScreenGui`s (`RoshamboUI`, `RoshamboPickHud`) and every widget under them: the onyx pick
  disc, the three ivory circular pick tiles with their emboss/highlight/glow layers, the 5-tile
  history strip and its caption, the status bar, the wallet label, the scrolling prose ticker and
  its `RenderStepped` scroll loop, the BANK button, the ACCEPT YOUR FATE button.
- The `GLYPH` / `BTN_GLYPH` Unicode tables and their `HIST_TEXT` / `BTN_TEXT` size tables. No
  Unicode stand-in remains in this file; all three glyphs render through `Glyphs.render`.
- The `PICK_BOX` / `PICK_CX` / `PICK_CY` / `BTN_SPOT` top-right layout math.
- The 0.25 s status-line text loop (replaced by the 0.1 s `HudState` publish loop).
- The `BankRequest` remote binding. Deliberate and called out in the file header: the persistent
  BANK button is gone and banking is one half of the RISK/BANK pair that resolves a win through
  `ResolveWin` (Task 11). Leaving the local bound but unused would also have failed `selene`.

### The wiring contract between the two files

`main.client.luau` fires `EventBus.HudState:Fire(inputs, aux)`:

- `inputs` — a `HudModel.Inputs`, exactly as the brief specifies.
- `aux` — `{ session = HudModel.Session, tape = { { worldThrow, result? } }, pick = string? }`.

`session` had to travel because the brief places it in the wiring while `HudModel.view` is called
by the renderer; `tape` and `pick` are the two render inputs `HudModel.Inputs` does not carry.
Putting them in a second argument keeps the first argument literally a `HudModel.Inputs`.
Picks come back on `EventBus.HudPick`; transient notices on `EventBus.Toast`.

---

## 2. The spoiler gate, and why it is still correct

The gate has two halves and both survived intact.

**Half one — hold the tape entry back.** `visibleTape()`:

```luau
local skip = 0
if currentRoundId and tape[1] and tape[1].id == currentRoundId and currentRoundId ~= revealedRoundId then
    skip = 1
end
```

Identical predicate to the old `renderHistory`. If the newest authoritative tape entry is the
round our own drum is still spinning on, it is skipped and the list starts one entry later. The
only change is the consumer: instead of writing into five tile widgets it returns the visible
entries (already resolved to `{ worldThrow, result }`), and `HudController` paints exactly what it
is given. The renderer has no access to `currentRoundId` or `revealedRoundId`, so it *cannot*
re-derive or accidentally bypass the gate — which is stronger than before.

**Half two — hold the headline back.** `maybeShowReveal()` still only fires when
`pendingReveal and drumAtRest`, still clears `pendingReveal` first, still sets `badgeById` and
`revealedRoundId` before republishing, and is still called from three places with the same
meanings: the `drumRest` cue, `RevealResult` (no-op unless the drum is already at rest), and the
3-second safety delay whose guard is the unchanged `pendingReveal.headline == headline` identity
check.

`RoundUpdate`'s ACTIVE branch still clears `pendingReveal` and `drumAtRest` for the respin.

**One leak was closed, not opened.** The old code called
`tickerSay("World threw {x} — R n% · P n% · S n%")` *outside* the gate, immediately on
`RevealResult`. That line names the world throw, so it spoiled the wheel while it was still
turning — the slow scroll of the ticker was the only thing hiding it. That text is now folded into
the gated headline (`7bd21a5`), so nothing that names the world throw is released before the drum
settles.

---

## 3. Every element created, with its `Active` state

The file carries the non-negotiable comment at the top, verbatim from the brief.

| Element | Class | `Active` | Sinks touch? |
| --- | --- | --- | --- |
| `RoshamboHud` | ScreenGui | n/a | no |
| `Plate` | **TextButton** | n/a (a button always sinks) | **yes — by design** |
| `Plate/{STREAK,POT,POINTS}` holder | Frame | false (default) | no |
| `…/Caption`, `…/Value` (×3 each) | TextLabel | false (default) | no |
| `ThrowArea` | Frame | false (default) | no |
| `ThrowArea/Tape` | Frame | false (default) | no |
| `Tape/T1..T5` | Frame | false (default) | no |
| `T*/Badge` | Frame | false (default) | no |
| `T*/GlyphBox` + 3 × `Glyph` (Frame) + 6 × ImageLabel | Frame / ImageLabel | false (default) | no |
| `ThrowArea/{R,P,S}` | **TextButton** ×3 | n/a | **yes — the interactive budget** |
| each button's `GlyphBox` + `Glyph` + 2 ImageLabels | Frame / ImageLabel | false (default) | no |
| `RoundTimer` | Frame | false (default) | no |
| `Escalation` | TextLabel | **explicitly `false`** + comment | no |
| `Toast` | TextLabel | false (default) | no |
| UICorner / UIStroke / UIPadding helpers | non-GuiObject | n/a | no |

**Interactive total: four — the plate and the three throw buttons.** Exactly the budget the plan
allows for this task (the two choice buttons are Task 11's).

**Did anything that was `Active = false` become a button?** One thing, and it is the design's
explicit exception: the old wallet `TextLabel` (`PTS n · POT n · STREAK n`) is now the plate, a
`TextButton`, because the plate is the single entry point to the maximal ledger and the spec
requires maximal to add no new persistent button anywhere. Nothing else crossed that line; the
tape tiles, which were `Frame`s before, are still `Frame`s.

### Layout, and the jump-button clearance

- Plate: `AnchorPoint (0.5, 0)`, `Position UDim2.new(0.5, 0, 0, 12)`, on the default
  (inset-respecting) ScreenGui so it sits under Roblox's topbar band, in the one region Roblox
  claims nothing in.
- Throw area: `AnchorPoint (1, 1)`, `Position UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -12)` with
  `JUMP_CLEARANCE = 0.15` **in scale, not pixels**, per the dispatch — no pixel offsets were
  hand-tuned against a desktop viewport. Tape row above, three 76 px buttons below.
- Timer: a 3 px `Frame` hairline pinned to the bottom edge, width scaled to `secondsLeft` over the
  largest countdown seen since ACTIVE opened (the round's span is not on the wire, so it is
  measured rather than assumed).
- Escalation and toast use scale widths so they do not overflow a small phone.

---

## 4. Deviations and judgment calls (all disclosed)

1. **The escalation label was built, minimally.** The dispatch says not to build Task 11–14
   features and names "escalation render" among them; the brief's Step 2 lists Escalation in the
   Task 10 layout. I followed the brief and shipped *only* what it describes — one large centred
   `TextLabel`, `Active = false`, visible on `view.escalate`. None of Task 11's elaboration (the
   red thickening hairline, the separate count treatment) is present. Task 11 extends a stub
   rather than finding an empty screen.
2. **Two reveal toasts collapsed to one** (`7bd21a5`). Porting the status line and the ticker
   across verbatim produced two 4-second toasts back to back — a third of the round occupied by a
   surface that is supposed to be transient. They are now one line, which also put the
   distribution behind the spoiler gate (§2).
3. **`TickerMessage` is rendered by the toast.** `EconomyController` still fires it with a real
   player-facing notice ("Earn n more pts to claim a teahouse…"), and its only other renderer,
   `BoardController`, early-returns because the jumbotron no longer exists. Without this bridge
   that message would have gone nowhere. One `Connect` line, commented.
4. **`escalationPrompts` is hard-defaulted to `true`.** `ProfileUpdate` does not carry it — the
   server has the field and the `SetHudPreference` remote, but the payload builder in
   `main.server.luau` was not in this task's file list. Commented at the declaration. Task 12
   wires the ledger's switch and will need that field added to `fireProfile`.
5. **`couldThrow` is sticky across the round.** Set at ACTIVE open to `not (fateBound or
   unresolvedWin)` and raised to true by the 0.1 s loop at any moment in the round the player was
   unbound. A player who was free to throw at any point in a round did not have the round taken
   from them, so it counts as a miss; a player bound for the whole round carries their count
   forward untouched, which is what `HudModel.onRoundEnded` is documented to want.
6. **Unsynced-clock fallback.** When `secondsToLockout` arrives `nil` (the round clock has not
   synced), the old HUD still let the player throw. `HudModel.throwsEnabled` requires
   `secondsLeft > 0`, so reporting 0 would have silently locked those players out. The wiring
   reports a nominal 30 s instead: throws stay enabled and, being above the 5 s threshold, the
   escalation stays quiet. Commented at the constant.

## 5. Concerns for the controller / owner

1. **ACCEPT YOUR FATE has no affordance any more.** The button was one of the deleted widgets and
   neither the spec nor the plan gives it a home in the new HUD (the interactive budget is
   explicit: three throws, two choice buttons, the plate). A fate-bound player is not stranded —
   `FateController` resolves the flight on *contact* as well as on acceptance, so the doom simply
   catches them, and their throws are visibly dimmed meanwhile. But "accept it or be caught" is
   now only "be caught", and the old status line's "FACE YOUR FATE" text is gone with it. I did
   not add a replacement notice because the honest wording ("you lost") would itself spoil the
   drum. `FateController`'s `cue.kind == "acceptFate"` branch is left in place as the hook a
   future affordance would fire. **Worth an owner decision.**
2. **There is no way to bank between this commit and Task 11.** Expected — the BANK button folds
   into the RISK/BANK overlay — but the two tasks should land close together, and a Studio pass on
   Task 10 alone will find banking missing.
3. **Every offset here is provisional.** `JUMP_CLEARANCE = 0.15`, the 76 px buttons, the 34 px
   tape tiles and the 300 px plate were chosen to be *safe*, not final; Task 15's emulator sweep
   is where they get settled against real aspect ratios.
4. **The HUD publishes at 10 Hz.** Each publish allocates two small tables and repaints ~20
   properties. Cheap, and the depleting hairline needs the cadence, but it is a per-frame-ish cost
   that did not exist before (the old status loop ran at 4 Hz).
