# Final fix wave — whole-branch review

Applied all 6 fixes from the final whole-branch review of the 14-task play-HUD revision.

## FIX 1 — `SWITCH?` clipped on phones

`switchPill.Size` widened from `BTN_W - 8` to `BTN_W` (flush with the button, not inset), and
`switchLabel` got `TextScaled = true` plus a `UITextSizeConstraint(MaxTextSize = 13)`, mirroring
`bankButton`'s pattern.

Why widening was needed in addition to `TextScaled`: at the old 36px pill width, scaling "SWITCH?"
(measured ~57–64px unscaled at 13px GothamBold, ratio ≈4.4–4.9 px-width per px-size) down to fit
would land around 7.5–8px — below the ~9px legibility floor. At the new 44px (full `BTN_W` on
touch), the same math lands the scaled text at ~9–10px, and the pill is exactly as wide as the
button beneath it (never wider) at both tiers (desktop: `BTN_W = 76`, comfortably fits 13px
unscaled, so the constraint there is a no-op ceiling as before).

## FIX 2 — escalation overlay vs. bank button collision

Replaced the static `UDim2.fromScale(0.5, 0.42)` Y position with a dynamic clamp
(`updateEscalationPosition`, `HudController.client.luau`), run once at startup and on every
`gui:GetPropertyChangedSignal("AbsoluteSize")` change (Roblox handles the `IgnoreGuiInset` topbar
exclusion automatically, so `gui.AbsoluteSize.Y` already is the safe-area `H`).

```
resting = 0.42 * H
clamped = H - CLUSTER_TOP_FROM_BOTTOM - MARGIN - ESCALATION_H / 2
Y = min(resting, clamped)
```

`CLUSTER_TOP_FROM_BOTTOM` is tier-selected (`CLUSTER_TOP_FROM_BOTTOM_TOUCH` on touch), `MARGIN =
ROW_GAP = 10`, `ESCALATION_H = 154`.

**Arithmetic, H = 354 (844×390 phone, touch tier):**
- `CLUSTER_TOP_FROM_BOTTOM_TOUCH = EDGE(12) + AREA_H_TOUCH(78) + ROW_GAP(10) + BANK_H(40) = 140`
- `resting = 0.42 * 354 = 148.68`
- `clamped = 354 - 140 - 10 - 77 = 127`
- `Y = min(148.68, 127) = 127` → escalation spans `[50, 204]`
- bank button spans `[214, 254]` (top edge `= H - 140 = 214`)
- gap = `214 - 204 = 10px` — **no overlap**, exactly `MARGIN`.

**Arithmetic, H = 1044 (tall screen):**
- `resting = 0.42 * 1044 = 438.48`
- `clamped = 1044 - 140 - 10 - 77 = 817`
- `Y = min(438.48, 817) = 438.48` (clamp does not bind) → escalation spans `[361.48, 515.48]`
- bank top edge `= 1044 - 140 = 904`
- gap = `904 - 515.48 = 388.52px` — **no overlap**, and behavior matches the original 0.42 fraction
  on tall screens (unclamped).

## FIX 3 — false "plate is the door" premise in three headers

Rewrote the stale header claims in:
- `LedgerController.client.luau:8-10` — names the `≡` ledger door as entry, explains the plate
  moved into the bottom row as a pure display (must stay `Active = false`).
- `TeahouseController.client.luau:108-109` — same correction; the ledger is still the door into
  the teahouse panel, but the ledger itself is now reached via `≡`, not the plate.
- `Takeover.luau:35-37` — fixed both the false claim (plate is the door) and the false file
  reference (there is no `EventBus.OpenLedger` connection in this file; it's
  `LedgerController.client.luau:782`).

## FIX 4 — stale comments (batch)

- `HudController.client.luau` (press-hold comment) — `main.client sets \`myPick\`` → `` `chosen` ``.
- `Takeover.luau:35-37` — fixed as part of FIX 3 (same lines).
- `main.client.luau` (beat 4 bank-toast comment) — corrected geography: card shows at the
  `wallet` anchor (same as `throwArea`/`potIndicator`, above the bank+throws+tape cluster); toast
  is top-centre. No longer claims they share a screen region.
- `HudLayout.luau:5` — "the tape+throw cluster and the one slot" → "...and the bank button".
- `EffectRegistry.luau` — "breaks the test above" → "breaks the test in
  `tests/EffectSelector.spec.luau`".

## FIX 5 — `SEND_AT` ceiling pinned

Added to `tests/HudModel.spec.luau` (in the `sendAtLockout` describe block):

```lua
test("still holds just above the send boundary", function()
    expect(HudModel.sendAtLockout(inputs({ chosen = "R", secondsLeft = 0.6 }))).toBe(nil)
end)
```

**Mutation check**: changed `SEND_AT` from `0.5` to `1.0` in `src/shared/HudModel.luau`, ran
`lune run tests/run` → **923 passed, 1 failed** (exactly the new test:
`expected R to be nil`). Reverted `SEND_AT` to `0.5`; suite is back to 924/924 green.

## FIX 6 — optimistic press paint on a SWITCH? tap

Added a `chosenSym: string?` mirror of `view.chosen` (analogous to the existing `canThrow`
mirror), set every `render()`. The `MouseButton1Down` handler now returns before setting
`pressedSym`/painting when `chosenSym ~= nil` — i.e. when the tap would only raise a SWITCH?
prompt, not choose a glyph. `depress()` (the scale-tween press feedback) still fires
unconditionally, so every tap still visibly does something.

Deliberately did not reach for `HudModel.tapAction` (per the review's instruction) — the
controller doesn't hold a full `Inputs`, and building a partial one would duplicate a rule that
belongs in the model.

## Do-not-change verified

Added a one-line comment at `HudModel.luau:51` (the `bankVisible` field) explaining nothing
renders it directly and that `HudController`'s `pot > 0 or displayedPot > 0` extension is correct
layering, not dead-code drift — left the field itself untouched.

## Gate results

- `roblox/`: `lune run tests/run` → **924 passed, 0 failed** (923 + 1 new)
- `roblox/`: `stylua --check src tests tools` → clean (ran `stylua src tests tools` once to
  reformat the new `CLUSTER_TOP_FROM_BOTTOM` line, then check passed)
- `roblox/`: `selene src tools` → 0 errors, 0 warnings, 0 parse errors
- `server/`: `npm test` → **210 passed** (13 test files)

## Files touched

- `roblox/src/client/HudController.client.luau` (Fixes 1, 2, 4, 6)
- `roblox/src/client/LedgerController.client.luau` (Fix 3)
- `roblox/src/client/TeahouseController.client.luau` (Fix 3)
- `roblox/src/client/Takeover.luau` (Fixes 3, 4)
- `roblox/src/client/main.client.luau` (Fix 4)
- `roblox/src/shared/HudLayout.luau` (Fix 4)
- `roblox/src/shared/EffectRegistry.luau` (Fix 4)
- `roblox/src/shared/HudModel.luau` (Fix 5 mutation-tested via `SEND_AT`; do-not-change comment)
- `roblox/tests/HudModel.spec.luau` (Fix 5, new test)
