### Task 6: The escalation halves and learns to be dismissed; `SWITCH?` fills its button

**Files:** Modify `roblox/src/client/HudController.client.luau`.

- [ ] **Step 1: Halve the escalation**

`ESCALATION_H` 154 → 77. `escalationCount.TextSize` 84 → 42 and its height 92 → 46.
`escalationPrompt.TextSize` 24 → **16, not 12** — the point of the change is the footprint, not
the type, and halving a 24px label makes it unreadable. Its height 30 → 20.

**Re-check the padding arithmetic.** The frame carries 12px of `UIPadding` on all four sides and
its height must absorb that: content = `ESCALATION_H - 24`, and the two labels plus their gap must
fit inside it. Task 9 of the previous branch shipped exactly this bug — padding added to a
fixed-height frame stacked its own labels. **State the arithmetic in your report.**

Then **re-check the clamp against the bank button.** The overlay is clamped so its bottom edge
never passes `CLUSTER_TOP_FROM_BOTTOM + margin`; halving its height changes where its centre
lands. Confirm no overlap at `H = 354` and `H = 1044`.

- [ ] **Step 2: Make it dismissable**

`escalation` becomes a `TextButton` (`AutoButtonColor = false`, `Text = ""`), and its click fires
a new `EventBus.DismissEscalation`. Add that name to `EventBus.luau`'s list.

```luau
-- THE ONE SINKING ELEMENT that is not a control. Everything else on this surface stays
-- Active = false, because every sinking pixel is a permanent hole in the camera-drag surface.
-- This is the exception the owner asked for: "the worst thing that could happen is it gets
-- thrown into a user's view in the middle of watching fireworks." It is small, it exists only in
-- the last few seconds of a round and only when armed, and dismissing it is the entire point.
```

In `main.client.luau`, listen and set `declinedThisRound = true`, then `publish()`. **Do not add
a new field** — dismissing and backing out mean the same thing to the escalation rule, and the
spec says so.

- [ ] **Step 3: `SWITCH?` fills its button**

`switchPill.Size` is already `UDim2.fromOffset(BTN_W, 24)` — confirm it, and confirm the label
carries `TextScaled` plus a `UITextSizeConstraint`. If the pill is still `BTN_W - 8` anywhere,
fix it. **Do not move the pill above the button.** Add:

```luau
-- IT COVERS THE GLYPH, ON PURPOSE. Confirming a switch UNLOCKS; it never selects the button that
-- was tapped. So the glyph underneath is not a destination — both unchosen buttons are proxies
-- for switch-and-cancel, and either does the same thing. Revealing it would advertise a
-- destination that does not exist.
```

- [ ] **Step 4: Verify and commit**

Run the standing check. Report the escalation's padding arithmetic and its clearance from the
bank button at both viewport heights.

```bash
cd roblox && stylua src tests tools && selene src tools
git commit -am "feat(roblox): the nag gets smaller and takes an answer"
```

---

