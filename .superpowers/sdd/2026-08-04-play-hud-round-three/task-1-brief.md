### Task 1: The bank row gives back 6px

**Files:**
- Modify: `roblox/src/shared/HudLayout.luau:70-74`, `roblox/src/shared/HudLayout.luau:88-92`
- Modify: `roblox/src/client/HudController.client.luau:113` (locals), `:805` (bank position)
- Modify: `roblox/src/client/OnboardingController.client.luau:68-75`, `:203-215`, `:240-242`
- Test: `roblox/tests/HudLayout.spec.luau`

**Interfaces:**
- Consumes: nothing from other tasks.
- Produces: `HudLayout.BANK_H = 36`, `HudLayout.BANK_GAP = 8` as the *actual* gap above the throw cluster, and `CLUSTER_TOP_FROM_BOTTOM` / `CLUSTER_TOP_FROM_BOTTOM_TOUCH` derived with `BANK_GAP` instead of `ROW_GAP`. No other task reads these.

**Context:** The HUD already sits 6px off the screen's bottom edge (`EDGE_BOTTOM = 6` in `HudController`, and the `ScreenGui` leaves `IgnoreGuiInset` default so its bottom edge *is* the screen's). The only slack in the 134px phone stack is the bank button. Separately, `HudLayout.BANK_GAP = 8` was declared for the gap above the throw cluster but only `OnboardingController` ever read it — `HudController` and `CLUSTER_TOP_FROM_BOTTOM` both used `ROW_GAP` (10). This task makes the constant mean its name, which is worth 2 of the 6 pixels.

- [ ] **Step 1: Update the failing tests first**

In `roblox/tests/HudLayout.spec.luau`, three assertions derive the cluster with `ROW_GAP`. Change all three to `BANK_GAP`:

```lua
    test("the cluster is bank + throws + tape, and nothing else", function()
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM).toBe(
            HudLayout.EDGE + HudLayout.AREA_H + HudLayout.BANK_GAP + HudLayout.BANK_H
        )
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM_TOUCH).toBe(
            HudLayout.EDGE + HudLayout.AREA_H_TOUCH + HudLayout.BANK_GAP + HudLayout.BANK_H
        )
    end)
```

and in the later `describe("HudLayout — the ring beside the throw buttons", ...)` block:

```lua
    test("the cluster still covers bank + throws + tape", function()
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM).toBe(
            HudLayout.EDGE + HudLayout.AREA_H + HudLayout.BANK_GAP + HudLayout.BANK_H
        )
    end)
```

Then add a new test to the first `describe` block:

```lua
    test("BANK_GAP is the gap above the cluster, not a number nobody uses", function()
        -- It was declared for this gap and then only OnboardingController read it, while
        -- HudController and CLUSTER_TOP_FROM_BOTTOM both positioned the row with ROW_GAP. The
        -- two are different numbers, so the derivation above is what pins the repair: if a
        -- later edit puts ROW_GAP back, this fails.
        expect(HudLayout.BANK_GAP ~= HudLayout.ROW_GAP).toBe(true)
    end)

    test("the bank button stays comfortably hittable", function()
        -- The owner's ruling (spec §3): 36, not 32. Banking is the one irreversible action on
        -- this surface and a mis-tap costs real points. The throw buttons' 44px floor does not
        -- bind here — that floor is for the three targets hit every round under time pressure.
        expect(HudLayout.BANK_H).toBe(36)
    end)
```

The harness offers only `toBe`, `toBeCloseTo`, `toBeTruthy` and `toBeNil` — there is no `.never`
modifier, which is why the inequality is written out.

- [ ] **Step 2: Run the tests and watch them fail**

Run from `/Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox`: `lune run tests/run`
Expected: FAIL — `CLUSTER_TOP_FROM_BOTTOM` is still derived with `ROW_GAP`, and `BANK_H` is 40.

- [ ] **Step 3: Change HudLayout**

Replace `roblox/src/shared/HudLayout.luau:70-74` with:

```lua
-- The bank button's row, directly above the throw cluster. Reserved whether or not a pot is
-- riding: an onboarding card clamped into a band that ignored it would land on the button the
-- moment a first win put one there.
--
-- 36, down from 40 (owner's gate 2026-08-04, spec §3). The HUD is already 6px off the bottom
-- edge — that is the floor, not a thing to re-litigate — so the only slack in the stack is
-- here. NOT below 36: banking is the one irreversible action on this surface. The throw
-- buttons' 44px floor does not bind, because that floor was set for the three targets a player
-- hits every round under time pressure.
HudLayout.BANK_H = 36

-- BANK_GAP is now actually the gap. It was declared for it and then only OnboardingController
-- read it, while HudController and CLUSTER_TOP_FROM_BOTTOM positioned the row with ROW_GAP (10)
-- — so the constant named for this gap had never been this gap. All three read it now, and the
-- correction is worth 2 of the 6 pixels this round reclaims.
HudLayout.BANK_GAP = 8
```

Replace `roblox/src/shared/HudLayout.luau:88-92` with:

```lua
HudLayout.CLUSTER_TOP_FROM_BOTTOM = HudLayout.EDGE + HudLayout.AREA_H + HudLayout.BANK_GAP + HudLayout.BANK_H
HudLayout.CLUSTER_TOP_FROM_BOTTOM_TOUCH = HudLayout.EDGE
    + HudLayout.AREA_H_TOUCH
    + HudLayout.BANK_GAP
    + HudLayout.BANK_H
```

- [ ] **Step 4: Run the tests and watch them pass**

Run: `lune run tests/run`
Expected: PASS.

- [ ] **Step 5: Move the bank button in HudController**

Near `roblox/src/client/HudController.client.luau:113` (where `local RING_GAP = HudLayout.RING_GAP` sits), add:

```lua
local BANK_GAP = HudLayout.BANK_GAP
```

At `:805`, change the bank button's position from `ROW_GAP` to `BANK_GAP`:

```lua
bankButton.Position = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(EDGE_BOTTOM + AREA_H + BANK_GAP))
```

Confirm `ROW_GAP` still has at least one other code use in this file (it spaces the tape from the buttons). If it does not, delete the local — selene fails on unused variables.

- [ ] **Step 6: Route OnboardingController through CLUSTER_TOP_FROM_BOTTOM**

`OnboardingController` currently re-derives the whole stack by hand in three places — exactly the hand-copied arithmetic `HudLayout`'s own header (lines 5-10) was written to prevent.

**The declaration must move first.** `CLUSTER_TOP_FROM_BOTTOM` is declared at `:240-242`, *below* the `STATIC_ANCHORS` table at `:203-215` that will now read it. In Luau a forward reference resolves to a nil global rather than erroring, and `UDim2.new` on a nil would then fail at runtime in a file no test loads. Move the declaration (with its comment at `:233-239`) up to sit with the other layout locals after `:75`.

Then replace the three anchor offsets:

```lua
        offset = UDim2.new(1 - JUMP_CLEARANCE, 0, 1, -(CLUSTER_TOP_FROM_BOTTOM + BANK_GAP)),
```

`CLUSTER_TOP_FROM_BOTTOM` is the top of the bank button; `+ BANK_GAP` is the clearance above it — the same total as the old hand-derived expression, expressed once.

- [ ] **Step 7: Delete the locals that just became unused**

After Step 6, `EDGE`, `AREA_H`, `ROW_GAP` and `BANK_H` in `OnboardingController` have no remaining **code** uses (they appear only in comments at `:176`, `:230`, `:234`). Delete all four declarations at `:68-74`. Keep `BANK_GAP` and `JUMP_CLEARANCE`.

Update the comment at `:176` so it names what the code now reads (`CLUSTER_TOP_FROM_BOTTOM` and `BANK_GAP`) rather than the five constants it used to hand-add. A stale comment describing a derivation that no longer exists is the exact failure mode that cost this project a round already.

Verify with: `grep -n "\bEDGE\b\|\bAREA_H\b\|\bROW_GAP\b\|\bBANK_H\b" roblox/src/client/OnboardingController.client.luau` — every remaining hit must be inside a comment.

- [ ] **Step 8: Run every gate**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run
stylua --check src tests tools
selene src tools
```
Expected: tests pass, stylua clean, selene 0 warnings.

- [ ] **Step 9: Commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/HudLayout.luau roblox/tests/HudLayout.spec.luau \
        roblox/src/client/HudController.client.luau roblox/src/client/OnboardingController.client.luau
git commit -m "fix(roblox): BANK_GAP finally is the gap, and the bank row gives back 6px"
```

---

