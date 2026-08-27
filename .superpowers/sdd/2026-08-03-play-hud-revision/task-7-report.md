# Task 7 report — the player-state plate and the ledger door

**Current state as of this revision.** The plate's placement has changed twice since Task 7
first landed: right-margin-above-the-jump-button (Task 7) → the owner added a `≡` ledger door
because that placement made the plate inert (Task 7, same session, addendum) →
**the owner superseded the right-margin placement entirely** for a hidden bottom-row line
(Task 7A, this revision). This report describes the **current** implementation only; see
"History" at the bottom for what changed and why, condensed.

## What the plate is now

One line at the bottom of the throw cluster, left of the tape, normally hidden.

- **Geometry.** `AnchorPoint (1, 1)`. `Size = UDim2.fromOffset(0, TILE)` with
  `AutomaticSize = Enum.AutomaticSize.X` (height fixed to one tape tile, width grows to fit the
  text). `Position = UDim2.new(1 - JUMP_CLEARANCE, -(TAPE_W + LEDGER_GAP), 1, -EDGE)` — the
  same shared right reference (`1 - JUMP_CLEARANCE`) the throw cluster, the bank button and the
  ledger door all register to; `LEDGER_GAP` (8px) left of the tape's own left edge; bottom-
  aligned with the tape (`D = EDGE` from the gui's bottom, same as the tape). Because the anchor
  is the frame's right edge and `AutomaticSize` grows it leftward, a longer line (`×3  900`)
  never creeps toward the tape — the right edge is pinned regardless of content width.
- **Content.** One `TextLabel` (`plateLabel`), no separate streak/points labels any more:
  `900` normally, `×3  900` when a streak rides. No `UIStroke` on the label — contrast comes
  from the Frame's opaque `WASHI` backing, which does carry a `GOLD` stroke (allowed; it's a
  Frame, not a label).
- **Hidden by default.** `plate.Visible = false` at construction. Reveals only via `revealPlate()`.
- **Reveal triggers:** the ledger door's first tap (see below), and any change to
  `view.plate.points` or `view.plate.streak` between renders. The change-guard lives in
  `render()`, keyed on comparing against `lastPlatePoints`/`lastPlateStreak` from the *previous*
  render — **not** on `render()` running, which is a 10Hz repaint. `lastPlatePoints` starts at
  `nil` specifically so the very first render (nothing has "changed" yet) does not auto-reveal
  on HUD load.
- **Hold + fade.** `PLATE_HOLD = 2` seconds fully opaque, then `PLATE_FADE = 0.35` seconds
  fading out (`Enum.EasingStyle.Quad`, `EasingDirection.In`). The fade drives **three** tweens
  together — `plate.BackgroundTransparency`, `plateLabel.TextTransparency`,
  `plateStroke.Transparency` — all to `1`, so the backing and the stroke go with the text; a
  panel that stayed opaque while its number dissolved would be worse than either alone.
  `plate.Visible = false` only after the backing tween's `Completed` fires (checked below).
- **Re-revealing mid-hold or mid-fade** cancels the in-flight fade tweens and restores full
  opacity immediately, via a generation counter (`plateGen`) — the same pattern as
  `pressSeq`/`potPulse` elsewhere in this file. A stale `Completed` callback from a cancelled
  fade checks `gen == plateGen` and no-ops rather than hiding a plate a newer reveal just showed.
- **Day/night interaction.** The plate's resting (fully-revealed) `BackgroundTransparency` is
  no longer read live off the instance in `applyContrast()` (that property now spends most of
  its life at `1`/hidden or mid-tween, neither of which is the authored value the day/night pass
  needs). It's tracked in a separate `plateRestTransparency` local that `applyContrast()` updates
  every pass and `revealPlate()` reads back — so a reveal during full daylight uses the current
  lerped value, not a stale night-authored one.

## The ledger door — now two-stage

The `≡` button (`ledgerButton`) itself is unchanged from the earlier addendum (position,
size, styling, press feedback via `pressDepress`) — only its click handler changed:

```lua
ledgerButton.MouseButton1Click:Connect(function()
    if plateVisible then
        EventBus.OpenLedger:Fire()
    else
        revealPlate()
    end
end)
```

`plateVisible` is `true` from the instant `revealPlate()` runs until the fade's `Completed`
actually fires — **not a 2-second timer**. This was the coordinator's explicit requirement: a
tap landing at, say, 2.1s (mid-fade) must still open the ledger rather than silently doing
nothing, because a control that is still visible must still be answerable. A double-tap from
cold therefore: tap 1 reveals (`plateVisible` flips true immediately), tap 2 lands inside that
window and opens the ledger — nobody has to learn the two stages to reach it the obvious way.

**Single firer confirmed**: `grep -rn "EventBus.OpenLedger:Fire" src/client/` returns exactly
one hit, `HudController.client.luau:647` (this handler).

## `plateBottomOffset` and its tests — confirmed gone

- `roblox/src/shared/HudLayout.luau`: `HudLayout.PLATE_W`, `HudLayout.PLATE_ROW_H`,
  `HudLayout.PLATE_JUMP_GAP`, and the `HudLayout.plateBottomOffset` function are all deleted.
  Confirmed nothing else in `src/`/`tests/` referenced `PLATE_W`/`PLATE_ROW_H` before deleting
  (grepped first). The module's own header comment, which called out `plateBottomOffset` as the
  one deliberate function-shaped exception to "numbers only", is rewritten to say that
  exception is gone.
- `roblox/src/client/HudController.client.luau`: `jumpButton()`, `placePlate()`,
  `rewatchJump()`, `jumpWatch`, and every connection they owned (`gui`'s `AbsoluteSize` signal,
  `playerGui.ChildAdded`/`ChildRemoved` for `TouchGui`) are deleted. Nothing in this file reads
  `playerGui:FindFirstChild("TouchGui")` or anything under it any more.
- `roblox/tests/HudLayout.spec.luau`: the `describe("HudLayout.plateBottomOffset — where the
  plate sits above the jump button", ...)` block (3 tests: no-jump-button fallback,
  clears-by-`PLATE_JUMP_GAP`, clamped-if-measured-off-screen) is deleted. The
  "holds no Roblox globals" test, which had been loosened to allow `function` values
  specifically for `plateBottomOffset`, is tightened back to "numbers only" now that no function
  remains in the module.
- Confirmed by test count: `lune run tests/run` now reports **907 passed** vs. **910** before
  this revision — exactly the 3 deleted tests, nothing else moved.

## Reconciliation 1 — `HudLayout.X` reads vs. exports

Reads in `HudController.client.luau`:
```
JUMP_CLEARANCE, EDGE, BTN_H_TOUCH, BTN_H, TILE_TOUCH, TILE, ROW_GAP, AREA_H_TOUCH, AREA_H,
BANK_H, BTN_H_TOUCH (again, in LEDGER_SIZE)
```
Exports in `HudLayout.luau`:
```
JUMP_CLEARANCE, EDGE, TILE, ROW_GAP, BTN_H, THROW_TOUCH_SCALE, TAPE_TOUCH_SCALE, BTN_H_TOUCH,
TILE_TOUCH, BANK_H, BANK_GAP, AREA_H, AREA_H_TOUCH, CLUSTER_TOP_FROM_BOTTOM,
CLUSTER_TOP_FROM_BOTTOM_TOUCH
```
Every field read is exported. No dangling reference. No read of `PLATE_W`, `PLATE_ROW_H`,
`PLATE_JUMP_GAP`, or `plateBottomOffset` remains anywhere in the controller.

## Reconciliation 2 — `view.X` reads vs. `HudModel.View`

Reads in `HudController.client.luau`: `view.throwsEnabled`, `view.plate.points`,
`view.plate.streak`, `view.bankVisible`, `view.pot`, `view.potPulses`, `view.selected`,
`view.escalate`, `view.secondsLeft`.

`HudModel.view()`'s actual return (`HudModel.luau:168-184`): `plate { streak, points }`,
`throwsEnabled`, `bankVisible`, `pot`, `potPulses`, `escalate`, `secondsLeft`, `chosen`,
`switchPrompt`. **No `selected` field** — unchanged from the prior reconciliation pass.
`view.selected` (in `paintThrows(aux.pick or view.selected or pressedSym, ...)`) still resolves
to `nil` every call; this is pre-existing, untouched by Task 7A (that code path is Task 8's
scope — "SWITCH?, the selection light, and the confirm strip's removal"), and already flagged
in the surrounding comment as a deliberate stale-field bridge.

## Reconciliation 3 — `aux.X` reads vs. `main.client.luau`'s `publish()`

Reads: `aux.session`, `aux.pick`, `aux.tape`, `aux.timerKnown`. `publish()`'s actual fire
(`main.client.luau:230-236`) sends `{ session, tape, timerKnown }` — **no `pick` field**. Same
pre-existing staleness as `view.selected` above, same Task 8 scope, untouched here.

## Overlap arithmetic — plate vs. tape, the `≡`, and the timer hairline

All spans are pixel offsets: `D` = distance from the gui's bottom edge (larger = higher up);
`X` = distance left from the shared right reference `1 - JUMP_CLEARANCE` (larger magnitude =
further left/inboard).

**Desktop** (`TOUCH = false`): `BTN_H = 76`, `TILE = 34`, `TILE_GAP = 6`, `TAPE_W = 194`,
`AREA_W = 248`, `AREA_H = 120`, `LEDGER_SIZE = 40`, `LEDGER_GAP = 8`, `EDGE = 12`.

- Tape (`tapeRow`): `D ∈ [12, 46]` (`EDGE` to `EDGE+TILE`), `X ∈ [-194, 0]` (left edge at
  `-TAPE_W` from the shared reference, since `tapeRow` sits at `throwArea`'s own right edge).
- Plate: `D ∈ [12, 46]` (bottom-aligned with the tape, same `TILE` height), right edge
  `X = -202` (`-(TAPE_W + LEDGER_GAP) = -(194+8)`).
  **Plate vs. tape**: right edge (`-202`) sits exactly `LEDGER_GAP` (8px) left of the tape's
  left edge (`-194`) — **no overlap**, by construction (same `D`-range, but disjoint `X`).
- Ledger door (`≡`): `D ∈ [56, 96]` (`56 = EDGE+AREA_H-BTN_H = 12+120-76`; `96 = 56+LEDGER_SIZE`).
  **Plate vs. `≡`**: plate's top `D` is `46`; ledger's bottom `D` is `56` — a **10px gap**,
  disjoint regardless of `X`. (This 10px is exactly `ROW_GAP`, algebraically: ledger-bottom
  `D = EDGE+ROW_GAP+TILE`, plate-top `D = EDGE+TILE`; the difference is `ROW_GAP` in both
  tiers, since `ROW_GAP` isn't touch-scaled.)
- Timer hairline: `D ∈ [0, 7]` (hot) / `[0, 3]` (cold), full gui width.
  **Plate vs. timer**: timer's max `D` is `7`; plate's min `D` is `12` — a **5px gap**, no
  overlap.

**Touch** (`TOUCH = true`): `BTN_H = 44`, `TILE = 24` (`round(34*0.7)`), `TILE_GAP = 4`,
`TAPE_W = 136`, `AREA_W = 148`, `AREA_H = 78`, `LEDGER_SIZE = 44`, `LEDGER_GAP = 8`, `EDGE = 12`.

- Tape: `D ∈ [12, 36]`, `X ∈ [-136, 0]`.
- Plate: `D ∈ [12, 36]`, right edge `X = -144` (`-(136+8)`).
  **Plate vs. tape**: `8px` gap (`-144` to `-136`) — **no overlap**.
- Ledger door: `D ∈ [46, 90]` (`46 = 12+78-44`; `90 = 46+44` — `LEDGER_SIZE` equals `BTN_H` on
  touch, so the door spans the button row's full height here).
  **Plate vs. `≡`**: plate top `D=36`, ledger bottom `D=46` — **10px gap** (same `ROW_GAP`
  identity as desktop) — no overlap.
- Timer: `D ∈ [0, 7]`. **Plate vs. timer**: `5px` gap — no overlap.

Both tiers: plate never overlaps the tape (8px), the `≡` (10px), or the timer (5px). The
plate/ledger gap is exactly `ROW_GAP` in both tiers by construction, not by coincidence — it
falls out of the ledger door's bottom edge and the plate/tape's shared top edge both being
defined in terms of `EDGE + TILE` plus or minus `ROW_GAP`.

(Not asked for, but checked as a sanity pass: the plate also stays well clear of the bank
button in both tiers — bank's minimum `D` is `142` desktop / `100` touch, far above the plate's
maximum `D` of `46`/`36`.)

## Gates

- `stylua --check src tests tools` — clean (one auto-format needed after the initial write,
  then clean).
- `selene src tools` — 0 errors, 0 warnings, 0 parse errors (one warning fixed along the way:
  `plateLabel.Size = UDim2.new(0, 0, 1, 0)` simplified to `UDim2.fromScale(0, 1)`, selene fails
  the build on warnings per the project's own gate).
- `lune run tests/run` — **907 passed, 0 failed** (910 before this revision, minus the 3 deleted
  `plateBottomOffset` tests; unrelated `HandlerQueue.spec` queue-full/handler-error `[WARN]`
  lines are pre-existing chaos-test noise, not failures).

## Explicitly not touched (Task 7B, separate)

The figures are still shown as plain integers — no counting/rolling animation. `RollingNumber`
and its wiring into the plate/bank-button figures are Task 7B, a separate pure module, landing
after this.

## History (condensed; see git log for the full record)

1. **Task 7** (commit `df7bb80`): plate → right margin above the jump button, measured at
   runtime via `HudLayout.plateBottomOffset`. This made the plate a pure `Frame`/`TextLabel`
   display (previously it had been a `TextButton` that opened the ledger), which silently broke
   the ledger's only entry point — flagged in the report rather than silently patched over,
   per that task's explicit instruction to report rather than invent a fix.
2. **Same-session addendum** (commit `781eb41`): owner ruled the plate should stay inert; added
   a dedicated `≡` button (`ledgerButton`) as the ledger's new, sole door. Single-stage at that
   point — every tap fired `EventBus.OpenLedger` directly.
3. **This revision (Task 7A)**: owner superseded the right-margin placement entirely — the
   plate moves to the bottom row, becomes normally-hidden with a reveal/hold/fade cycle, and the
   `≡` becomes two-stage (reveal, then open) so it still doubles as the plate's own trigger.
   `HudLayout.plateBottomOffset` and the whole jump-button measurement are deleted; nothing in
   the HUD is positioned against Roblox-owned geometry any longer.
