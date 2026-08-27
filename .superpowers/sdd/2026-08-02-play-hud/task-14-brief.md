### Task 14: Day/night contrast for the HUD

Night is the authored state. As day comes up, ivory tiles lose contrast against a pale canyon.

**Files:**
- Modify: `roblox/src/client/HudController.client.luau`

**Interfaces:**
- Consumes: `EventBus.DayNight` and `DayNightConfig.CurrentNightFactor`, exactly as
  `WaterVfxDayNight.client.luau:152-160` does.

- [ ] **Step 1: Subscribe**

Copy the dual-subscription pattern from `WaterVfxDayNight` verbatim — the EventBus channel *and*
the attribute-changed signal, because a controller can start after the last fire.

- [ ] **Step 2: Apply the treatment**

As `nightFactor` falls toward day, darken the plate backing and deepen the tile rims.

```luau
-- Lerp toward a target, never scale. VfxNightDim's lesson: an authored value of zero cannot be
-- moved by multiplication, so a "scale the contrast" approach silently does nothing wherever
-- the authored value happens to be 0.
```

Capture authored values once, on an attribute, so repeated applies never compound — same rule as
`WaterVfxDayNight:68-75`.

- [ ] **Step 3: Verify in Studio**

`DayNightLockT` is pinned at 0.40 for the owner's dusk look. **Do not change it.** To test day,
read the current value, set it temporarily, and restore it before committing. Confirm the HUD is
legible at 0.0, 0.19, 0.40 and 1.0.

- [ ] **Step 4: Run the gates and commit**

```bash
git diff -- roblox/src/shared/DayNight.luau  # MUST be empty — the lock is not ours to change
stylua --check src tests tools && selene src tools
git add roblox/src/client/HudController.client.luau
git commit -m "feat(roblox): HUD contrast tracks nightFactor so day stays legible"
```

---

