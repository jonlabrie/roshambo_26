# Final Fixes Report — Structure Builder Code Review

## Changes Made

### Fix 1: Datum Assertion in captureTeahouseBase.luau

**File:** `roblox/tools/studio/captureTeahouseBase.luau`

Added an assertion in the `capture()` function (between the y0 loop and the `local posW` calculation) that validates no geometry exists below the datum (Y0). This assertion proves the core contract between the capture script and the pad: the teahouse structure must not include any parts extending below the datum underside.

**Code inserted:**
```lua
local below = {}
for _, p in m:GetDescendants() do
    if p:IsA("BasePart") then
        local lb = piv:ToObjectSpace(p.CFrame).Position.Y - p.Size.Y / 2
        if lb < y0 - 0.01 then
            table.insert(below, p.Name)
        end
    end
end
assert(#below == 0, "parts below the datum (Y0) are the pad's job: " .. table.concat(below, ","))
```

This is a Studio-only script (not executed by Lune tests) — it serves as a static record change and validation.

### Fix 2: Non-Contiguous ShojiBays Test in StructurePlanner.spec.luau

**File:** `roblox/tests/StructurePlanner.spec.luau`

Appended a new test that validates texture resolution correctly indexes shoji bays by bay **value** (not array position). The test uses non-contiguous bay indices `{2, 4}` to prove the indexing logic distinguishes between the two approaches. Uses real catalog asset IDs: `shoji.crane` (rbxassetid://102000000001) and `shoji.plain` (rbxassetid://0).

**Test added:**
```lua
test("textures: non-contiguous shojiBays index by bay value, not array position", function()
    local manifest = { roles = {}, shojiBays = { 2, 4 }, hasTatami = false, flagMounts = {} }
    local loadout = { baseStyle = "teahouse-1story", shoji = { [2] = "shoji.crane", [4] = "shoji.plain" } }
    local plan = Planner.plan(loadout, baseMount(), manifest, Catalog)
    expect(plan.textures).toEqual({
        { target = "ShojiBay:2", assetId = "rbxassetid://102000000001" },
        { target = "ShojiBay:4", assetId = "rbxassetid://0" },
    })
end)
```

## Test Verification

Command: `cd roblox && lune run tests/run`

Result: **261 passed, 0 failed, 261 total**
- Previous suite: 260 tests
- New test count: 1
- Status: ✓ All passing

## Commit

Both files committed together:
- `roblox/tools/studio/captureTeahouseBase.luau`
- `roblox/tests/StructurePlanner.spec.luau`

Commit message: "fix(roblox): capture datum assertion + non-contiguous shojiBays test (final-review minors)"
