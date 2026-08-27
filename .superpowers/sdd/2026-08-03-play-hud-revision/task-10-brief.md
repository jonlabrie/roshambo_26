### Task 10: `OnboardingController` — the safe band re-derives

**Files:**
- Modify: `roblox/src/client/OnboardingController.client.luau`
- Modify: `roblox/src/shared/OnboardingBeats.luau` (anchor rename only)
- Test: `roblox/tests/OnboardingBeats.spec.luau`

**Interfaces:**
- Consumes: `HudLayout.CLUSTER_TOP_FROM_BOTTOM(_TOUCH)`, `BANK_H`, `BANK_GAP`.
- Produces: `OnboardingBeats` anchor `plate` → `wallet` (it no longer points at a top-centre
  plate).

- [ ] **Step 1: Write the failing test**

In `roblox/tests/OnboardingBeats.spec.luau` add:

```luau
describe("OnboardingBeats — anchors match what the HUD actually builds", function()
    test("no beat anchors to a plate that has left the top band", function()
        for _, beat in OnboardingBeats.BEATS do
            expect(beat.anchor ~= "plate").toBe(true)
        end
    end)

    test("every anchor is one the controller knows", function()
        local known = { drum = true, throwArea = true, potIndicator = true, wallet = true }
        for _, beat in OnboardingBeats.BEATS do
            expect(known[beat.anchor] == true).toBe(true)
        end
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lune run tests/run`
Expected: FAIL — a beat still anchors to `plate`.

- [ ] **Step 3: Rename the anchor**

In `roblox/src/shared/OnboardingBeats.luau`, change the `plate` anchor to `wallet` on whichever
beats use it, and update the module comment naming the four anchors.

- [ ] **Step 4: Re-derive the band and move the anchors**

In `OnboardingController`, replace the `PLATE_BOTTOM` constant and its use:

```luau
-- The band a card must stay inside. The plate has LEFT the top (it is in the right margin
-- now), so the only thing to clear up there is the toast, which sits at EDGE and grows
-- downward with AutomaticSize. TOAST_BAND is a reservation for it, not a measurement — a card
-- landing on a transient notice hides exactly the line that explains what just happened.
local TOAST_BAND = 64
```
```luau
    local minY = TOAST_BAND + SAFE_MARGIN + cardH
    local maxY = math.max(minY, canvas.Y - CLUSTER_TOP_FROM_BOTTOM - SAFE_MARGIN)
```

In `STATIC_ANCHORS`, replace the `plate` entry with a `wallet` entry pointing at the new
right-margin plate, and update the `throwArea` / `potIndicator` offsets for the new stack
(`SLOT_H`/`SLOT_GAP` are now `BANK_H`/`BANK_GAP`):

```luau
    -- Both sit ABOVE the whole cluster, so neither can ever cover a live button.
    throwArea = {
        point = Vector2.new(1, 1),
        offset = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(EDGE + AREA_H + ROW_GAP + BANK_H + BANK_GAP)),
        width = CARD_W,
    },
    potIndicator = {
        point = Vector2.new(1, 1),
        offset = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(EDGE + AREA_H + ROW_GAP + BANK_H + BANK_GAP)),
        width = CARD_W,
    },
    -- The wallet card points at the right-margin plate, so it is anchored to the right edge
    -- and clamped by the same band as everything else.
    wallet = {
        point = Vector2.new(1, 1),
        offset = UDim2.new(1, -EDGE, 1, -(EDGE + AREA_H + ROW_GAP + BANK_H + BANK_GAP)),
        width = CARD_W,
    },
```

Update `STATIC_ANCHORS[beat.anchor] or STATIC_ANCHORS.plate` to fall back to
`STATIC_ANCHORS.throwArea`.

- [ ] **Step 5: Run and commit**

Run: `lune run tests/run` — expect PASS.

```bash
cd roblox && stylua src tests tools && selene src tools
grep -n "PLATE_BOTTOM\|SLOT_H\|SLOT_GAP\|STATIC_ANCHORS.plate" src/client/OnboardingController.client.luau
```
Expected: no matches.

```bash
git add roblox/src/shared/OnboardingBeats.luau roblox/src/client/OnboardingController.client.luau roblox/tests/OnboardingBeats.spec.luau
git commit -m "fix(roblox): onboarding clears the toast, not a plate that has moved away"
```

---

