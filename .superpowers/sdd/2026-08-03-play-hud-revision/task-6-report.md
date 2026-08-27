# Task 6 report: `HudController` — tape/button swap and the bank button

## What changed

`roblox/src/client/HudController.client.luau` only.

### Step 1 — tape moved below the throw row, buttons anchored to the top

- `tapeRow`: `AnchorPoint (1,1)`, `Position UDim2.fromScale(1, 1)` (was `(1,0)` / `fromScale(1,0)`).
  Its parent `throwArea` is unchanged (`AnchorPoint (1,1)`, bottom-right of the gui, size
  `AREA_W x AREA_H`), so the tape now hugs `throwArea`'s bottom edge instead of its top.
- Each throw button: `AnchorPoint (0,0)`, `Position UDim2.fromOffset((i-1)*(BTN_W+BTN_GAP), 0)`
  (was `AnchorPoint (0,1)` / `Position (..., 1, 0)`), so the row now hangs from `throwArea`'s
  top edge.
- Each halo: `AnchorPoint (0,0)`, `Position UDim2.fromOffset((i-1)*(BTN_W+BTN_GAP) - HALO_BLEED,
  -HALO_BLEED)` (was `AnchorPoint (0,1)` / positive `HALO_BLEED` on the y-offset side).

Geometry check (`AREA_H = BTN_H + ROW_GAP + TILE` from `HudLayout`): buttons occupy
`throwArea` y ∈ `[0, BTN_H]`; tape occupies y ∈ `[AREA_H - TILE, AREA_H]`. The gap between them
is `AREA_H - TILE - BTN_H = ROW_GAP` exactly — the stack still matches the reserved height, no
drift.

Halo bleed check on all four sides, per button: halo left = button left − `HALO_BLEED`; halo top
= button top (0) − `HALO_BLEED`; halo right = button right + `HALO_BLEED`; halo bottom = button
bottom (`BTN_H`) + `HALO_BLEED`. All four confirmed exactly `HALO_BLEED` (7px) outside the
button on the new top-anchored geometry — same bleed as before, just flipped vertically with the
anchor.

I also switched both `UDim2.new(0, x, 0, 0)`-style calls to `UDim2.fromOffset` (selene's own
suggestion — the pre-flip forms had a non-zero scale component on one axis so didn't trigger the
lint; the post-flip forms are offset-only on both axes and did).

### Step 2 — slot replaced with one bank button

Deleted: `slotRow` (Frame), `potGroup` (Frame), `bankButton`'s old home inside it, `potDisc`
(Frame, the red disc), `potFigure` (TextLabel), `fateButton` (TextButton + its `Cue` connection),
and `setSlot` (the `kind`-dispatch function + its `pulse` tween state).

Added, verbatim from the brief: a single `bankButton` (`TextButton`, name `"Bank"`) parented
directly to `gui`, plus `setBank(visible, pot, pulses)` replacing `setSlot`. Geometry:

- `AnchorPoint (1, 1)`
- `Position UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(EDGE + AREA_H + ROW_GAP))` — same formula the
  old `slotRow` used, so the button sits exactly where the slot used to, directly above the throw
  cluster.
- `Size UDim2.fromOffset(BANK_W, HudLayout.BANK_H)` — `BANK_W = 150` (added beside the other width
  constants, replacing the old `BANK_W = 128` that belonged to the disc-plus-button pair, per the
  brief's instruction), `HudLayout.BANK_H = 40`.
- `BackgroundColor3 = POT_RED`, `Text = ""` (filled per-render as `` `BANK {pot} POINTS` ``),
  `Visible = false` until the first render.

`POT_RED` was already in the palette (line 55, originally the disc's colour, annotated "the pot
disc; deeper than LOSS_RED so it reads as a seal") and is now reused by the button — no new
colour constant needed. `LOSS_RED` stays; it's still used by the tape's LOSS badge and the
escalating timer hairline.

The old `SLOT_H`/`SLOT_GAP`/`DISC`/`FATE_W` local constants (all sourced from now-deleted
`HudLayout.SLOT_H`/`SLOT_GAP`) lost every consumer except one: `confirmStrip.Position`, which is
explicitly Task 8's territory. Per the task framing (fix only the named subset, leave the rest
for later tasks), I kept `local SLOT_H = HudLayout.SLOT_H` alive (now dead-reading a field
`HudLayout` no longer exports, same category of leftover breakage as `PLATE_H`) so `confirmStrip`
still type/scope-checks, but removed `SLOT_GAP`, `DISC` and `FATE_W`, which had zero remaining
readers — selene's `unused_variable` check is a hard gate (`selene ... --max-warnings 0`-equivalent
via "fails on warnings"), so orphaned locals had to go.

### Step 3 — `render()`

- `cellValue.pot.Text = tostring(view.plate.pot)` deleted (per the brief's ambiguity note 3);
  `cellValue.streak`/`cellValue.points` lines untouched (Task 7).
- `potFigure.Text = ...` deleted (the instance is gone).
- `setSlot(view.slot, view.potPulses)` → `setBank(view.bankVisible, view.pot, view.potPulses)`.
- Deleted the confirm strip's render block: `confirmStrip.Visible = view.confirmPending or
  view.releasable` and its `if view.releasable then ... else ... end` (per the resolved
  ambiguity — both fields are gone from `HudModel.View`, so this was a guaranteed
  `Visible = nil` runtime error). `confirmStrip` itself, `dontAsk`, `confirmHint`, `CONFIRM_COPY`,
  `HINT_W`, and all their construction, stay in place, unused and permanently hidden
  (`Visible = false`, never flipped) until Task 8. `RELEASE_COPY` and `HINT_W_WIDE` — whose only
  reader was the deleted `if view.releasable` branch — were removed as dead code (unused-variable
  gate), with a comment pointing at Task 8 for their reintroduction.
- Left untouched (per the brief): `paintThrows(aux.pick or view.selected or pressedSym, ...)`
  (Task 8), the `escalationCount`/`escalationPrompt` strokes and the toast (Task 9), `PLATE_H`
  and the `cellValue` plate construction (Task 7).

### Incidental comment fixes

Two stale doc comments directly contradicted code I was changing and would have broken the
required `setSlot` grep check, so I updated them: the file-header note ("tape ABOVE the buttons" →
"BELOW"; "EXACTLY ONE slot button (see `setSlot`)" → "the one bank button (see `setBank`)") and
the per-halo loop comment ("the one slot button" → "the one bank button"). No behavioural change.

## Verify

- `grep -n "potDisc\|potGroup\|fateButton\|setSlot\|view.slot\|slotRow" src/client/HudController.client.luau` → no matches.
- `grep -n "confirmPending\|releasable" src/client/HudController.client.luau` → no matches.
- `stylua --check src tests tools` → clean.
- `selene src tools` → 0 errors, 0 warnings (baseline before this task was also 0/0; my edits
  introduced two `roblox_manual_fromscale_or_fromoffset` warnings via the anchor flip and two
  `unused_variable` warnings via the orphaned confirm-release constants — both fixed, see above).
- `lune run tests/run` → 910 passed, 0 failed (the `[WARN] QUEUE ...` lines are expected output
  from an existing `HandlerQueue.spec` error-path test, not a new failure).

## Left broken on purpose (owned by later tasks)

- `local PLATE_W, PLATE_H = 300, HudLayout.PLATE_H` and the top-centre `plate`/`cellValue`
  construction — Task 7.
- `paintThrows(aux.pick or view.selected or pressedSym, ...)` — `aux.pick`/`view.selected` no
  longer exist on their respective types — Task 8.
- `confirmStrip` construction (position still reads the now-dead-but-kept `SLOT_H`/`CONFIRM_H`/
  `CONFIRM_GAP`) — Task 8.
- `stroke(escalationCount, ...)` / `stroke(escalationPrompt, ...)` (UIStroke on TextLabels) and
  the toast's transparency/position — Task 9.

None of these are reachable through anything Task 6 touches (the bank button, the tape/button
swap) — they were already broken before this task and selene doesn't catch them (it doesn't
type-check field access through `require`d modules), which is why the gates above pass cleanly
despite them still being present.

## Commit

`feat(roblox): the pot says what banking it is worth, on the button that does it`

## Addendum: Critical-defect fix (post-review, same task)

The coordinator caught that the file above could not load in Studio: four locals read
`HudLayout` fields Task 3 deleted (`PLATE_H`, `SLOT_H`, `CONFIRM_H`, `CONFIRM_GAP`), each landing
in a `UDim2`/arithmetic expression that turns a `nil` into a hard error the moment the script
runs — invisible to Lune (never loads `.client.luau`), selene (doesn't type-check `require`d
field access) or stylua (formatting only). Fixed directly, no re-litigating scope:

1. **Deleted the confirm strip entirely** — instance, `confirmHint`, `dontAsk`/`dontAskBox`/
   `dontAskLabel`, the `dontAsk` click handler, and every constant whose last reader was inside
   it (`CONFIRM_H`, `CONFIRM_GAP`, `CONFIRM_W`, `CONFIRM_PAD`, `CONFIRM_BOX`, `CONFIRM_COPY`,
   `HINT_W`, and the now-pointless `SLOT_H`). Its render block was already gone from Step 3, so
   nothing was left referencing these instances — Task 8 now verifies the absence instead of
   deleting them.
2. **`PLATE_H`** is now a literal `46` (was `HudLayout.PLATE_H`), with a `TEMPORARY (Task 6 →
   Task 7)` comment explaining why and pointing at `HudLayout.PLATE_ROW_H` as the eventual
   replacement. `PLATE_W` unaffected.
3. Tightened one nearby comment (`render()`'s `view.selected` note) that referenced "the strip
   below," which no longer exists — comment-only, no logic change.

### Field sweep (step 3 of the coordinator's ask)

`HudLayout.X` reads remaining in `HudController.client.luau`:
`JUMP_CLEARANCE, EDGE, BTN_H_TOUCH, BTN_H, TILE_TOUCH, ROW_GAP, AREA_H_TOUCH, AREA_H, BANK_H`

`HudLayout` exports today:
`JUMP_CLEARANCE, EDGE, TILE, ROW_GAP, BTN_H, THROW_TOUCH_SCALE, TAPE_TOUCH_SCALE, BTN_H_TOUCH, TILE_TOUCH, PLATE_W, PLATE_ROW_H, PLATE_JUMP_GAP, BANK_H, BANK_GAP, AREA_H, AREA_H_TOUCH, CLUSTER_TOP_FROM_BOTTOM, CLUSTER_TOP_FROM_BOTTOM_TOUCH`

Every field on the left appears on the right — no remaining `HudLayout.X` read resolves to nil.

`view.`/`aux.` sweep: `view.slot` and `view.plate.pot` (this task's scope) were already gone from
an earlier pass. `aux.pick` and `view.selected` (lines in `render()`, the optimistic-pick
fallback) still read fields that no longer exist on `HudModel`'s types — left alone per the
coordinator's instruction, since both degrade to `nil` rather than erroring, and rewiring them is
Task 8's job.

### Re-verified gates

- `stylua --check src tests tools` → clean
- `selene src tools` → 0 errors, 0 warnings
- `lune run tests/run` → 910 passed, 0 failed
- Both original grep checks (`potDisc|potGroup|fateButton|setSlot|view.slot|slotRow` and
  `confirmPending|releasable`) still return no matches, plus a new sweep for
  `confirmstrip|confirmhint|dontask|SLOT_H|SLOT_GAP|CONFIRM_` (case-insensitive) → no matches.
