### Task 5: The hairline and the hamburger go, the cluster moves down, the plate becomes a door

**Files:** Modify `roblox/src/client/HudController.client.luau`.

- [ ] **Step 1: Delete the hairline**

Remove the `timer` Frame, `TIMER_H`, `TIMER_H_HOT`, and the whole block in `render` that sizes and
colours it. `span` **stays** — the ring uses it.

- [ ] **Step 2: Move the cluster down**

With the hairline gone the cluster no longer needs to clear it. This is one constant: everything
below already derives from `HudLayout.EDGE`. Introduce a **bottom** margin distinct from the
side margin, and use it for the cluster's vertical anchor only:

```luau
-- The hairline used to occupy the bottom edge and everything was held above it. It is gone (the
-- ring replaced it), so the cluster drops into the space it left. Deliberately a SEPARATE
-- constant from EDGE rather than a smaller EDGE: the side margins are unchanged, and a shared
-- constant would move them too.
local EDGE_BOTTOM = 6
```

Apply it to the plate, the ring, the tape/throw area and the bank button's vertical positions.
`HudLayout.CLUSTER_TOP_FROM_BOTTOM` still uses `EDGE`, which now over-reserves by
`EDGE - EDGE_BOTTOM` — that is **fine and deliberate**: the onboarding band erring high keeps
cards further from live buttons. Note it in a comment so it does not read as a bug.

- [ ] **Step 3: The plate becomes a door**

Change `plate` from a `Frame` to a `TextButton` (`AutoButtonColor = false`, `Text = ""`). **It does
not move horizontally** — it keeps its slot left of the tape, since the ring never entered that
row. Only its vertical anchor changes, to `EDGE_BOTTOM`.

```luau
-- TAPPABLE AGAIN, and it is safe now in a way it was not before. The plate went inert because it
-- had moved into the strip Roblox uses for camera drag, where a sinking element is a permanent
-- hole. It is in the bottom row now. So the ledger has two doors — the hamburger and the plate
-- whenever it is showing — and tapping the hamburger then the plate is the same two taps as
-- double-tapping the hamburger.
plate.MouseButton1Click:Connect(function()
    if plateVisible then
        EventBus.OpenLedger:Fire()
    end
end)
```

The `plateVisible` guard matters: the plate is `Visible = false` most of the time, and a hidden
button cannot be clicked — but the guard also covers the fade, where it is still technically
visible while on its way out.

- [ ] **Step 3b: Delete the hamburger**

Remove `ledgerButton`, its three bar Frames, and `LEDGER_SIZE`, `LEDGER_GAP`, `LEDGER_BAR_H`,
`LEDGER_BAR_GAP`, `LEDGER_BAR_INSET`, `LEDGER_BARS_H`. Its handlers moved to the ring in Task 4.

`LEDGER_GAP` is read by the plate's old position — that read is already gone, replaced by
`RING_GAP` in Task 4. Confirm before deleting; selene will catch an orphan but not a missing one.

```luau
-- The hamburger is gone (spec §6). Roblox's own unibar already owns that glyph top-left, so a
-- second one bottom-right read as either the same menu or a broken copy — ours was the fake one.
-- The ring inherited the gesture: it IS the round, and since the LAST ROUND band the ledger is
-- the round's detail.
```

- [ ] **Step 3c: Repoint an onboarding beat at the ring**

A ring that looks like a readout does not invite a tap. In `roblox/src/shared/OnboardingBeats.luau`,
repoint the beat that currently anchors at `wallet` so its copy teaches the gesture — something to
the effect of "Tap the clock for your points. Tap again for everything." Fire it where it is
already fired; do not add a new event.

Update `roblox/tests/OnboardingBeats.spec.luau` accordingly, and confirm the anchor still resolves
in `OnboardingController`'s `STATIC_ANCHORS`. Write the test first and watch it fail.

- [ ] **Step 4: Verify and commit**

Run the standing check. State the bottom row's full horizontal arithmetic at both tiers —
plate, ring, tape — and confirm no overlap and nothing pushed off the left edge on a 320px-wide
viewport. Confirm `EventBus.OpenLedger:Fire` occurs **exactly twice** in `src/client/` — the ring
and the plate — and that both are guarded. Confirm no `LEDGER_*` constant and no `ledgerButton`
survives.

```bash
cd roblox && stylua src tests tools && selene src tools
git commit -am "feat(roblox): the wallet is a door again, and the bar is gone"
```

---

