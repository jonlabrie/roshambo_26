### Task 3: `HudLayout` — the ring's slot, and the hairline's absence

**Files:** Modify `roblox/src/shared/HudLayout.luau`, `roblox/tests/HudLayout.spec.luau`.

**Interfaces:**
- Produces: `RING_D` (54), `RING_D_TOUCH`, `RING_THICKNESS` (4), `RING_GAP` (8).
  `CLUSTER_TOP_FROM_BOTTOM` re-derives with the bottom row's height now set by the ring rather
  than the tape, if the ring is taller.

- [ ] **Step 1: Write the failing test**

```luau
describe("HudLayout — the ring shares the bottom row with the tape", function()
    test("the ring is exactly a throw button at both tiers", function()
        -- It is a target now, not a readout. Sizing it to the tape would make the ledger's only
        -- door smaller than every other control on the surface.
        expect(HudLayout.RING_D).toBe(HudLayout.BTN_H)
        expect(HudLayout.RING_D_TOUCH).toBe(HudLayout.BTN_H_TOUCH)
        expect(HudLayout.RING_D_TOUCH >= 44).toBe(true)
    end)

    test("the stroke scales with the ring and never vanishes", function()
        expect(HudLayout.RING_THICKNESS >= 3).toBe(true)
        expect(HudLayout.RING_THICKNESS_TOUCH >= 3).toBe(true)
        expect(HudLayout.RING_THICKNESS > HudLayout.RING_THICKNESS_TOUCH).toBe(true)
    end)

    test("the bottom row is as tall as its tallest occupant", function()
        -- The tape and the ring sit side by side. A row derived from the tape alone would let a
        -- taller ring hang out of the cluster the onboarding band is clamped against.
        expect(HudLayout.BOTTOM_ROW_H).toBe(math.max(HudLayout.TILE, HudLayout.RING_D))
        expect(HudLayout.BOTTOM_ROW_H_TOUCH).toBe(math.max(HudLayout.TILE_TOUCH, HudLayout.RING_D_TOUCH))
    end)

    test("AREA_H is buttons + gap + the bottom row", function()
        expect(HudLayout.AREA_H).toBe(HudLayout.BTN_H + HudLayout.ROW_GAP + HudLayout.BOTTOM_ROW_H)
        expect(HudLayout.AREA_H_TOUCH).toBe(
            HudLayout.BTN_H_TOUCH + HudLayout.ROW_GAP + HudLayout.BOTTOM_ROW_H_TOUCH
        )
    end)

    test("the cluster still covers bank + throws + bottom row", function()
        expect(HudLayout.CLUSTER_TOP_FROM_BOTTOM).toBe(
            HudLayout.EDGE + HudLayout.AREA_H + HudLayout.ROW_GAP + HudLayout.BANK_H
        )
    end)

    test("the touch throw target still clears the 44px floor", function()
        expect(HudLayout.BTN_H_TOUCH >= 44).toBe(true)
    end)
end)
```

- [ ] **Step 2: Run to verify failure**

Expect FAIL — `RING_D` and `BOTTOM_ROW_H` are nil.

- [ ] **Step 3: Implement**

```luau
-- ===== The round-timer ring (spec §5) =====
-- A PWA-style circular timer replaces the bottom hairline. It shares the bottom row with the
-- tape, sitting between the tape and the wallet plate.
--
-- 54px is the PWA's own diameter (src/components/PieTimer.tsx). The touch tier scales it by the
-- same factor the tape uses — it is read, never touched, so no 44px target floor applies.
-- SIZED TO A THROW BUTTON, not to the tape. The PWA's 54px was the right reference while this
-- was a readout; it stopped being one when it became the ledger's door, and an interactive target
-- should be sized like the other interactive targets. 44px on touch is also exactly the
-- touch-target floor the throw buttons adopted.
HudLayout.RING_D = HudLayout.BTN_H
HudLayout.RING_D_TOUCH = HudLayout.BTN_H_TOUCH

-- Proportional, so a 76px ring is not a hairline circle. 7.5% is the PWA's own ratio (4px on 54),
-- floored at 3 so the touch tier keeps a visible stroke.
HudLayout.RING_THICKNESS = math.max(3, math.round(HudLayout.RING_D * 0.075))
HudLayout.RING_THICKNESS_TOUCH = math.max(3, math.round(HudLayout.RING_D_TOUCH * 0.075))
HudLayout.RING_GAP = 8 -- ring <-> tape, and ring <-> plate

-- The bottom row is as tall as its TALLEST occupant, not as tall as the tape. The ring is taller
-- than a tape tile at both tiers, and a row derived from the tape alone would let it hang below
-- the cluster the onboarding safe band is clamped against — putting a card over it.
HudLayout.BOTTOM_ROW_H = math.max(HudLayout.TILE, HudLayout.RING_D)
HudLayout.BOTTOM_ROW_H_TOUCH = math.max(HudLayout.TILE_TOUCH, HudLayout.RING_D_TOUCH)
```

Re-derive `AREA_H` / `AREA_H_TOUCH` from `BOTTOM_ROW_H` instead of `TILE`, and update their
comment: the bottom row now holds the plate, the ring and the tape.

Update the module header: the hairline is gone (the ring replaced it), so "the toast/timer sizes"
in the paragraph about file-local numbers should no longer mention a timer.

- [ ] **Step 4: Verify pass**

Run `lune run tests/run`. `HudController` is not compiled by Lune, so its stale reads do not fail
here — Tasks 4–6 fix them.

- [ ] **Step 5: Format, lint, commit**

```bash
cd roblox && stylua src tests tools && selene src tools
git add roblox/src/shared/HudLayout.luau roblox/tests/HudLayout.spec.luau
git commit -m "feat(roblox): the bottom row is as tall as the ring, not the tape"
```

---

