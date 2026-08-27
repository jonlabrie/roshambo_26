# Play-HUD gate punch list — implementation report

Date: 2026-08-02 · Branch: `m4b-zendojo-art-pass`
Spec: `docs/superpowers/specs/2026-08-02-play-hud-design.md`

Five items from the owner's Studio gate. All five implemented. Both Roblox gates green
(`stylua --check src tests tools`, `selene src tools` — 0 warnings — and `lune run tests/run`,
879 passed / 0 failed; 3 new tests).

Files touched:

- `roblox/src/shared/HudLayout.luau` — the touch tier's numbers
- `roblox/src/shared/Glyphs.luau` — named the two glyph image layers
- `roblox/src/client/HudController.client.luau` — selection treatment, press feedback, touch tier
- `roblox/src/client/OnboardingController.client.luau` — card contrast, touch tier
- `roblox/src/client/TheaterController.client.luau` — the drum-rest gate
- `roblox/tests/HudLayout.spec.luau` — touch-tier derivations

---

## 1. Onboarding cards are too dark to read

Contrast raised on the card itself; no size change.

| Element | Before | After |
| --- | --- | --- |
| Card backing | `WASHI (26, 24, 28)` @ `BackgroundTransparency 0.08` | same colour @ **`0` (fully opaque)** |
| Card rim | `GOLD` 1px @ `Transparency 0.3` | `GOLD` **2px @ `0.1`** |
| Copy text | `INK_CREAM (240, 234, 216)`, 16px | **`CARD_COPY (252, 249, 242)`, 17px**, plus a `WASHI` `UIStroke` 2px @ `0.35` |
| Hint text | `GOLD (212, 176, 102)`, 11px, `TextTransparency 0.2` | **`CARD_HINT (238, 208, 142)`, 12px, `TextTransparency 0`** |

The hint stays a hint by being **smaller and gold**, not by being faded — 11px gold at 20% fade over
a dusk gorge was neither small-and-readable nor clearly subordinate; it was just dim. The copy's own
washi keyline is belt-and-braces: the `drum`-anchored card tracks a moving world object, so what
sits behind it is not fixed.

## 2 + 3. Selection treatment, and the "clicked twice" problem

### Colours and transparencies

All in `HudController.client.luau`, applied by the single new `paintThrows(pick, enabled)`
function — one place, so the optimistic press paint and the authoritative render can never
disagree about what "chosen" looks like.

**Chosen (cool and lit):**

| Property | Value |
| --- | --- |
| Button fill | `SEL_WASH (226, 238, 255)` @ `BackgroundTransparency 0` |
| Glyph core | `SEL_BLUE (74, 150, 255)` @ `ImageTransparency 0` |
| Glyph outline (keyline) | `SEL_INK (16, 44, 92)` |
| Rim `UIStroke` | `SEL_BLUE`, **Thickness 4**, `Transparency 0` |
| Halo (new sibling Frame, 7px bleed all round, 12px corner) | `SEL_HALO (120, 186, 255)` @ `BackgroundTransparency 0.55`, `ZIndex 0`, `Visible` only when chosen |

**Not chosen, while something is chosen (warm and faint):**

| Property | Value |
| --- | --- |
| Button fill | `WARM_FACE (104, 76, 40)` @ `BackgroundTransparency 0.55` |
| Glyph core | `WARM_GLYPH (226, 158, 62)` @ `ImageTransparency 0.5` |
| Glyph outline | `WARM_FACE` |
| Rim | `WARM_RIM (150, 108, 52)`, Thickness 1, `Transparency 0.55` |

**Throwable, nothing chosen** (unchanged): `IVORY` @ `0`, `INK` glyph @ `0`, `TAN_RIM` 2px @ `0.1`.
**Not throwable** (unchanged): `IVORY_DIM` @ `0.25`, glyph @ `0.45`, `TAN_RIM` 2px @ `0.1`.

The synthesis the two owner notes pointed at: the unchosen tiles **recede** (0.55 transparent on a
dark amber face — they nearly vanish) **and** carry the warm hue, and it is the warm/cool split
against the blue that makes the choice readable at a glance rather than three things being lit.

The halo is a **sibling** of the button at `ZIndex 0`, not a child: under the default `Sibling`
`ZIndexBehavior` a child always draws above its parent, so a child halo would have covered the
glyph. It is a `Frame` at its default `Active = false`. **`.Active = true` still appears exactly
once in the whole branch** (`LedgerController.client.luau:246`) — verified by grep after the change.

Glyph tinting needed `Glyphs.render` to name its two `ImageLabel`s (`Outline`, `Core`) so
`tintGlyph` addresses them by name rather than by `GetChildren()` order. Only `render` was changed;
`renderGroup`/`renderDay` are untouched, and `LanternController`'s index-based `imgs[2]` access is
unaffected.

### Is the stale-`canThrow` window real? — **No.**

Reasoning:

`canThrow` mirrors `HudModel.view(...).throwsEnabled`, which is
`phase == "ACTIVE" and secondsLeft > 0 and not fateBound and not pickedThisRound`. Each input:

- **`phase`** — `main.client.luau`'s `RoundUpdate` handler assigns `phase` and calls `publish()`
  **synchronously in the same handler**. There is no path where the client knows the round is
  ACTIVE and has not published it.
- **`fateBound`** — set in the `RevealTheater` handler and cleared in `FateResolved`, each followed
  immediately by `publish()`. Same story.
- **`pickedThisRound`** — set by the HUD's own `HudPick` handler, published immediately. Its
  false-refusal direction is *intended* (one tap throws; the second is meant to be ignored).
- **`secondsLeft`** — the only genuinely time-derived input, re-derived at the 10Hz `publish()`
  heartbeat. Its staleness is ≤100ms and it errs **permissive** (`canThrow` stays true for up to
  100ms *past* the local lockout), not restrictive. Nothing there swallows a legal press.

`EventBus.HudState` is a `BindableEvent` and therefore deferred, so `render` (and with it
`canThrow`) lags a `publish()` by a resumption point — sub-frame. That is not a window a human tap
can fall into.

**So the "click twice" report is not a stale-flag bug.** The likely cause is the one the fix
addresses: the throw buttons carry `AutoButtonColor = false` and had **no press feedback at all**,
while roughly a fifth of every round (TALLY 2s + REVEAL 3s out of ~25s) sits in a window where
`canThrow` is legitimately false. A perfectly good tap landing there produced literally nothing on
screen, so the natural response is to tap again. Nothing was changed about when a press is accepted.

**A third hypothesis worth the owner checking in Studio:** an onboarding card is itself a
full-surface `TextButton` at `DisplayOrder 10` whose only job is to be dismissed. If one ever
overlapped a throw button, the first tap would dismiss the card and the second would throw — which
is *exactly* "click twice, and nothing indicates it". The safe band is supposed to make that
impossible and now follows the touch tier too (item 4), but it is the one remaining mechanism that
would produce the symptom verbatim.

### What was added

- **`MouseButton1Down` → `depress(tile)`** on **every** press, accepted or refused: a `UIScale`
  tween to `0.93` over 60ms and back over 140ms. `UIScale` specifically, because it is the one
  property `render` never writes, so the 10Hz repaint cannot fight the tween mid-flight.
- **Accepted presses additionally light immediately**: `pressedSym` is set and `paintThrows` runs
  right there, before `SubmitPick` leaves the client. `render` prefers `aux.pick` and falls back to
  `pressedSym`, so a finger held down for longer than one 10Hz tick does not flicker the selection
  off. A press that never became a click (finger slid off) is released after 0.5s by a
  sequence-guarded `task.delay`, and the next render tells the truth.
- No confirm step. `MouseButton1Click` still fires `HudPick` on the first tap.

## 4. Mobile size tier

Detection: `UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled`, evaluated in
**both controllers** (never in `HudLayout`, which stays plain numbers and Lune-safe — the test
asserting "no Roblox globals, plain numbers only" still passes). The numbers live in `HudLayout` so
the two files cannot drift.

| | Desktop | Touch |
| --- | --- | --- |
| Throw button | 76 × 76 | **38 × 38** |
| Throw button gap | 10 | 8 |
| Throw cluster width | 248 | 130 |
| Tape tile | 34 | **24** |
| Tape tile gap / badge dot | 6 / 9 | 4 / 7 |
| `AREA_H` (tape + gap + buttons) | 120 | **72** |
| `CLUSTER_TOP_FROM_BOTTOM` | 182 | **134** |

### ⚠ Resulting touch-target size — **38 × 38 px**

Implemented as asked (50% **linear**). Flagging, not overriding: 38pt is **below the ~44pt
touch-target floor** that both the Apple HIG and the programme's own "touch-first, chunky targets"
brief call for, and these are the buttons a kid is meant to hit reliably on a phone while the round
clock runs. If it feels fiddly on a real device, the single lever is
`HudLayout.THROW_TOUCH_SCALE` — `0.6` gives 46 × 46 and everything else (cluster width, safe band,
onboarding clamp) re-derives from it with no other edit.

The tape at 24px is read, never touched, so no floor applies to it.

Two cosmetic consequences of the narrower cluster, both harmless (nothing clips —
`ClipsDescendants` is false throughout) and both flagged for the Studio look:

- the tape row (5 × 24 + 4 × 4 = 136) is 6px wider than the button row (130), so it overhangs 6px to
  the **left**, away from the jump button;
- the slot's `BANK THESE` (128) + pot disc (40) also extend left past the button row. Everything
  stays right-aligned with the cluster's right edge and inboard of the jump button. The slot was
  deliberately **not** shrunk — the owner asked only for the throw buttons and the tape, and
  `BANK THESE` is exactly the chunky target the brief wants.

### The onboarding safe band follows — confirmed

`OnboardingController` reads `AREA_H_TOUCH` / `CLUSTER_TOP_FROM_BOTTOM_TOUCH` from the same switch,
which feeds both `STATIC_ANCHORS.throwArea` / `.potIndicator` (the card's static offset above the
cluster) and `safeYBounds`'s `maxY` (the clamp the drum-tracked card runs through). The band's
bottom bound moves up from 182 to 134 with the cluster, i.e. the dead zone **shrinks by exactly the
48px the cluster lost** — the card sits closer to the controls but never on them, and the usable
band gets 48px *larger*, not smaller. Two new tests assert the derivation
(`AREA_H_TOUCH`, `CLUSTER_TOP_FROM_BOTTOM_TOUCH`) rather than a literal, so a future tweak to
`BTN_H` or `THROW_TOUCH_SCALE` cannot re-freeze one of them, and the short-landscape-phone test now
checks the touch band as well.

## 5. Reveal choreography fires ~3s before the drum shows the result

`TheaterController` now holds the reveal in `pendingReveal` and builds the cue schedule on the
`drumRest` cue — the same pattern `main.client.luau` and `LanternController` already use.

- **Offsets stay relative.** `Choreo.revealCues` is called *at flush time*, not at arrival time, so
  every `atMs` is measured from the start of the choreography and the whole sequence simply starts
  later with its internal timing intact. Nothing is subtracted or rebased.
- **A dropped `drumRest` cannot strand it.** `REVEAL_SAFETY = 3` seconds, mirroring
  `main.client.luau`, with an identity guard (`if pendingReveal == reveal`) so an older round's
  timer can never flush a newer round's payload.
- **`RoundUpdate` ACTIVE resets `drumAtRest` but deliberately does *not* clear `pendingReveal`.**
  REVEAL is ~3s and so is the safety, so that boundary and that timer race; clearing would
  occasionally drop a round's choreography entirely, which is the one outcome worse than playing it
  late. The safety always consumes the pending reveal within 3s, so there is nothing to clear that
  will not have cleared itself.

### ⚠ The owner's specific example — the avatar grow — is **server-side and NOT fixed by this**

`TheaterController` only plays the petals and the umbrella. The avatar scale-up is
`applyGrow(player)` in **`roblox/src/server/main.server.luau:357`**, called from the `onReveal`
callback in the same loop that fires `RevealTheater` — so it starts growing at the instant the
reveal is sent, ~3s before the drum settles, exactly as the owner described. Fixing it means
changing server code (its natural shape is a `task.delay` around the `applyGrow` call, since the
server cannot know any individual client's drum state), which is outside this pass's stated scope
and is the owner's call. **This is the top item to decide on next** — with this pass landed, the
petals now arrive at the right moment while the grow still arrives early, which is arguably a
*worse* read than both being early together.

### Other `RevealTheater` consumers — what I found

Five client consumers plus the server producer:

| Consumer | Verdict |
| --- | --- |
| `TheaterController.client.luau:95` | **Was premature — fixed this pass.** |
| `LanternController.client.luau:214` | Already gated on `drumRest`. Correct. |
| `DrumController.client.luau:196` | Correct by design — it *is* the drum; it needs `worldThrow` early to have something to land on. |
| `main.client.luau:328` | **Premature, real spoiler, NOT fixed** (see below). |
| `BoardController.client.luau:160` | Premature in principle — `setRow(6, "WORLD THREW ○")` the instant the reveal lands. **Currently dormant**: the controller early-returns when `Workspace.RoshamboStage.JumbotronBoard` is absent, and the jumbotron was removed in the display redesign (T23). Whoever retargets it to the kōsatsu boards must gate it on `drumRest` at the same time. |
| `server/main.server.luau:357` (`applyGrow`) | **Premature, real spoiler, NOT fixed** — see above. |

**`main.client.luau:328` in detail.** Its `RevealTheater` handler sets `fateBound = true` on a LOSS
and calls `publish()` immediately. `HudModel.view` turns `fateBound` into `slot = "fate"`, so the
HUD flips to **ACCEPT YOUR FATE while the drum is still turning** — an unambiguous "you lost" three
seconds before the wheel says so, and the loss implies which throw beat yours. This is the same
class of bug as item 5 and lives in the file that already owns the drum-rest gate
(`pendingReveal` / `maybeShowReveal`), so the fix is small — but it is a HUD-state change with its
own edge cases (the server's throw gate for fate-bound players is *not* client-timed, so deferring
the visual does not defer the gate), and per the brief I have left it for the owner to call. The
whiff toast in the same handler is fine — "TOO LATE" reveals nothing about the world throw.

---

## Self-review notes

- `.Active = true` count across the branch is still exactly 1 (`LedgerController:246`). The new
  halo Frames and the new `UIScale`/`UIStroke` instances sink no input.
- Every glyph still renders through `Glyphs`; no Unicode character was introduced. (`GLYPH` in
  `BoardController` is pre-existing and untouched.)
- `src/shared/HudLayout.luau` still holds only plain numbers and no Roblox globals; the guard test
  that iterates it still passes. `src/shared/Glyphs.luau` keeps every `Instance.new` inside a
  function, so it stays Lune-safe.
- `shared-fixtures/game-rules.json`, both `GameRules`, `DayNightLockT` and `PreNightTestLockT` were
  not touched. No `.rbxl`/`.rbxlx` committed.
- Studio verification is the controller's; nothing here has been looked at in-engine.
