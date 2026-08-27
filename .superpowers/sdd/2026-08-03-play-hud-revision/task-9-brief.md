### Task 9: Contrast — strokes off text, and the toast

Read the spec's §3 before starting.

**Files:**
- Modify: `roblox/src/client/HudController.client.luau`
- Modify: `roblox/src/client/OnboardingController.client.luau`

- [ ] **Step 1: Give the escalation overlay a backing**

The count and the prompt float over open canyon with no backing at all — the strokes were
standing in for one. Replace them with the real thing:

```luau
escalation.BackgroundColor3 = WASHI
escalation.BackgroundTransparency = 0.1
corner(escalation, 10)
```

and add a `UIPadding` of 12 on all four sides so the text does not touch the backing's edge.

- [ ] **Step 2: Remove every stroke on a TextLabel**

Delete these three lines:

```luau
stroke(escalationCount, WASHI, 3, 0.15)
stroke(escalationPrompt, WASHI, 2, 0.2)
```
(`HudController`, and note there is one `stroke(escalationPrompt, WASHI, 2, 0.2)` at :744)

and in `OnboardingController`, the whole `do … end` block that parents a `UIStroke` to
`copyLabel`, replacing it with a comment:

```luau
-- NO UIStroke ON THE COPY. A stroke parented to a TextLabel outlines every GLYPH: at 2px on
-- 17px type the outline approaches the stem width, the counters in a/e/o fill in, and adjacent
-- glyphs merge into a smear. That is what made these cards unreadable. The card's backing is
-- already opaque WASHI under near-white copy (~18:1) and needs no help.
```

- [ ] **Step 3: Fix the toast**

The plate has vacated top-centre, so the toast takes the band and stops being translucent:

```luau
toast.Position = UDim2.new(0.5, 0, 0, EDGE)
toast.BackgroundTransparency = 0.05
```

- [ ] **Step 4: Prove the rule holds file-wide**

```bash
cd roblox && grep -n "stroke(.*Label\|stroke(.*Count\|stroke(.*Prompt\|stroke(.*Hint\|stroke(.*Copy\|stroke(.*Text" src/client/*.luau
```
Expected: no matches. Then check for the raw form:

```bash
grep -n -B4 "UIStroke" src/client/OnboardingController.client.luau
```
Expected: the only `UIStroke` is the one parented to `card` (a TextButton acting as the
backing), never to `copyLabel` or `hintLabel`.

- [ ] **Step 5: Format, lint, commit**

```bash
cd roblox && stylua src tests tools && selene src tools
git add roblox/src/client/HudController.client.luau roblox/src/client/OnboardingController.client.luau
git commit -m "fix(roblox): an outline on 17px type is a smear, not contrast"
```

---

