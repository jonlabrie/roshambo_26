# Task 8 report

**Status:** Complete. **Commit:** `7e7ee3f88186e8ae49153d781d9d9c6ff1c76e63`

**Gates:** `lune run tests/run` → 919 passed, 0 failed (919 total). `stylua --check src tests tools` → clean. `selene src tools` → 0 errors, 0 warnings (one warning found and fixed: `UDim2.new` with all-offset args → `UDim2.fromOffset` in `setSwitchPrompt`).

**`HudLayout.X` reconciliation:** every read (`JUMP_CLEARANCE`, `EDGE`, `BTN_H_TOUCH`, `BTN_H`, `TILE_TOUCH`, `TILE`, `ROW_GAP`, `AREA_H_TOUCH`, `AREA_H`, `BANK_H`) matches a `HudLayout.X =` definition; none of these lines were touched by this task.

**`view.X`/`aux.X` reconciliation:** `view.{throwsEnabled, plate.points, plate.streak, pot, potPulses, chosen, switchPrompt, escalate, secondsLeft}` — all in `HudModel.View`. `aux.{session, tape, timerKnown}` — matches `publish()`'s payload exactly; no other `aux.` field is read anywhere in the file.

**`aux.pick` / `view.selected`:** both gone — confirmed by grep, zero matches.

**What changed:** built `switchPill`/`switchLabel`/`setSwitchPrompt` (pill positioned at `y = BTN_H / 2`, over the top-anchored button row); `paintThrows` gained a third `prompted` param that lifts that button out of the dimmed state (opaque ivory, blue rim) and deepened the unchosen treatment to `BackgroundTransparency = 0.75` / `fadeGlyph(..., 0.7)`; added idempotent `setChosenPulse` (guarded on symbol change, mirrors `setBank`'s pulse guard); `render` now drives selection off `view.chosen or pressedSym` and calls the two new setters. Optimistic press call updated to `paintThrows(sym, canThrow, nil)`.

**Bug found and fixed beyond the brief:** the brief's Step 4 code (`chosenPulse = TweenService:Create(...)\n(chosenPulse :: Tween):Play()`) is Lua's classic ambiguous-syntax trap — a line starting with `(` right after a line ending in `)` parses as a chained call on the *previous expression's result*, silently becoming `Create(...)(chosenPulse):Play()` (calling the Tween as a function). stylua's diff caught it by proposing to merge the lines. Rewrote using the same assign-then-`:Play()` pattern already used by `setBank`'s pot pulse, avoiding the cast entirely.

**Pill/tape/bank overlap arithmetic:** touch tier — `BTN_H=44`, pill spans y∈[10,34] (12px half-height around `BTN_H/2=22`), button occupies [0,44], tape starts at `BTN_H+ROW_GAP=54` (20px clear). Non-touch — `BTN_H=76`, pill spans y∈[26,50], tape starts at 86 (36px clear). The bank button sits entirely above `throwArea`'s top edge (y<0 in that frame's local space) at both tiers, so the pill — confined to the button's own bounds — never approaches it.

**Concerns:** none outstanding.
