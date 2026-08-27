### Task 3: `HudLayout` — the new skeleton

The confirm strip's reserved row goes; the cluster reorders; the plate gets right-margin
constants.

**Files:**
- Modify: `roblox/src/shared/HudLayout.luau`
- Test: `roblox/tests/HudLayout.spec.luau` (create if absent)

**Interfaces:**
- Produces: `HudLayout.PLATE_ROW_H`, `HudLayout.PLATE_W`, `HudLayout.PLATE_JUMP_GAP`,
  `HudLayout.BANK_H`; `CLUSTER_TOP_FROM_BOTTOM` / `_TOUCH` re-derived without the confirm
  strip. `PLATE_H`, `PLATE_BOTTOM`, `CONFIRM_H`, `CONFIRM_GAP`, `SLOT_H`, `SLOT_GAP` are
  removed.

- [ ] **Step 1: Write the failing test**

Create `roblox/tests/HudLayout.spec.luau`:

```luau
--!strict
local harness = require("./harness")
local describe, test, expect = harness.describe, harness.test, harness.expect
local HudLayout = require("../src/shared/HudLayout")

describe("HudLayout — the cluster the onboarding band has to clear", function()
    test("the cluster is bank + throws + tape, and nothing else", function()
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM).toBe(
            HudLayout.EDGE + HudLayout.AREA_H + HudLayout.ROW_GAP + HudLayout.BANK_H
        )
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM_TOUCH).toBe(
            HudLayout.EDGE + HudLayout.AREA_H_TOUCH + HudLayout.ROW_GAP + HudLayout.BANK_H
        )
    end)

    test("the touch cluster is shorter than the pointer one", function()
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM_TOUCH < HudLayout.CLUSTER_TOP_FROM_BOTTOM).toBe(true)
    end)

    test("the confirm strip is gone", function()
        expect((HudLayout :: any).CONFIRM_H).toBe(nil)
        expect((HudLayout :: any).CONFIRM_GAP).toBe(nil)
    end)

    test("the plate no longer reserves a band at the top", function()
        expect((HudLayout :: any).PLATE_BOTTOM).toBe(nil)
    end)

    test("the touch throw target clears the 44px floor", function()
        expect(HudLayout.BTN_H_TOUCH >= 44).toBe(true)
    end)
end)

describe("HudLayout.plateBottomOffset — where the plate sits above the jump button", function()
    test("with no jump button it falls back to the screen edge", function()
        expect(HudLayout.plateBottomOffset(400, nil)).toBe(HudLayout.EDGE)
    end)

    test("it clears a measured button by PLATE_JUMP_GAP", function()
        -- gui bottom at y=400, jump button's top edge at y=310 -> 90 up from the bottom, plus
        -- the gap.
        expect(HudLayout.plateBottomOffset(400, 310)).toBe(90 + HudLayout.PLATE_JUMP_GAP)
    end)

    test("a button measured below the screen edge cannot push the plate off-screen", function()
        -- Defensive: AbsolutePosition is read live and can be stale or nonsense for a frame.
        expect(HudLayout.plateBottomOffset(400, 500)).toBe(HudLayout.EDGE)
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lune run tests/run`
Expected: FAIL — `BANK_H` is nil and `CONFIRM_H` is still present.

- [ ] **Step 3: Edit the module**

In `roblox/src/shared/HudLayout.luau`: delete `PLATE_H`, `PLATE_BOTTOM`, `CONFIRM_H`,
`CONFIRM_GAP`, and rename `SLOT_H`/`SLOT_GAP` to `BANK_H`/`BANK_GAP`. Add:

```luau
-- ===== The player-state plate, now in the right margin =====
-- It moved out of top-centre because that band is the middle of a phone's view. It lives in
-- the strip Roblox claims for jump and camera drag — the one place a display with NO
-- interactive elements can safely go, since nothing in it is Active and every drag passes
-- straight through.
--
-- ABOVE the jump button, not below. Roblox's default TouchJump leaves roughly 20px between
-- that button's lower edge and the bottom of the screen on a phone, and on iOS that 20px is
-- the home indicator. Above it there is ~300px at every size.
--
-- These are the plate's own dimensions only. WHERE it sits vertically is not a constant:
-- HudController measures the real jump button and sits PLATE_JUMP_GAP above it, because the
-- numbers above are Roblox's current defaults rather than a contract.
HudLayout.PLATE_W = 92
HudLayout.PLATE_ROW_H = 22
HudLayout.PLATE_JUMP_GAP = 10

-- The one derivation in this module, rather than a bare constant, because it is the only
-- placement in the HUD that depends on something ROBLOX owns — and therefore the only one that
-- has to survive being wrong about it. Pure arithmetic, so the fallback and the clamp are
-- covered by the Lune suite; HudController does nothing but feed it two measurements.
--
--   guiBottomY : the HUD canvas's own bottom edge, in absolute screen Y
--   jumpTopY   : the jump button's top edge in the same space, or nil when there is no such
--                button (desktop), where the bottom-right corner is free anyway
function HudLayout.plateBottomOffset(guiBottomY: number, jumpTopY: number?): number
    if jumpTopY == nil then
        return HudLayout.EDGE
    end
    -- max, not a bare subtraction: AbsolutePosition is read live and can be stale for a frame
    -- after a viewport change, and a negative offset would put the plate off the bottom.
    return math.max(HudLayout.EDGE, guiBottomY - jumpTopY + HudLayout.PLATE_JUMP_GAP)
end

-- The bank button's row, directly above the throw cluster. Reserved whether or not a pot is
-- riding: an onboarding card clamped into a band that ignored it would land on the button the
-- moment a first win put one there.
HudLayout.BANK_H = 40
HudLayout.BANK_GAP = 8
```

Rewrite the cluster derivation. `AREA_H` is unchanged in value — the tape and buttons simply
swap order within it — but the comment must say so:

```luau
-- The tape+buttons cluster's own height, per tier. The TAPE IS BELOW THE BUTTONS now (owner's
-- ruling); the height is unchanged because the same two rows and one gap are in it either way.
HudLayout.AREA_H = HudLayout.BTN_H + HudLayout.ROW_GAP + HudLayout.TILE
HudLayout.AREA_H_TOUCH = HudLayout.BTN_H_TOUCH + HudLayout.ROW_GAP + HudLayout.TILE_TOUCH

-- Where the bank+throws+tape cluster's footprint begins, measured UP from the bottom edge.
-- The bank row counts whether or not its button is visible, exactly as the old slot did.
-- There is no PLATE_BOTTOM counterpart any more: the plate has left the top band entirely, so
-- the only thing an onboarding card has to clear up there is the toast (see
-- OnboardingController).
HudLayout.CLUSTER_TOP_FROM_BOTTOM = HudLayout.EDGE
    + HudLayout.AREA_H
    + HudLayout.ROW_GAP
    + HudLayout.BANK_H
HudLayout.CLUSTER_TOP_FROM_BOTTOM_TOUCH = HudLayout.EDGE
    + HudLayout.AREA_H_TOUCH
    + HudLayout.ROW_GAP
    + HudLayout.BANK_H
```

Update the module header: the paragraph explaining why `AREA_H` is shared stays; the
`CONFIRM_H` paragraph goes. The closing line currently reads "No Roblox globals: **plain
numbers only**" — `plateBottomOffset` makes that false, so amend it to "No Roblox globals:
numbers, and pure arithmetic over them", and say why the one function is here (it is the only
placement that depends on something Roblox owns, so it is the one that has to be tested).

- [ ] **Step 4: Run to verify it passes**

Run: `lune run tests/run`
Expected: `HudLayout.spec` PASSES. `HudController` and `OnboardingController` are not compiled
by the Lune suite, so their stale references do not fail here — Tasks 6–10 fix them.

- [ ] **Step 5: Format, lint, commit**

```bash
cd roblox && stylua src tests tools && selene src tools
git add roblox/src/shared/HudLayout.luau roblox/tests/HudLayout.spec.luau
git commit -m "feat(roblox): the tape goes under the buttons and the confirm row goes away"
```

---

