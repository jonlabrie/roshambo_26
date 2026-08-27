### Task 13: Park the fates

**Files:**
- Modify: `roblox/src/shared/EffectRegistry.luau`
- Modify: `roblox/src/server/main.server.luau`
- Test: `roblox/tests/EffectSelector.spec.luau`

- [ ] **Step 1: Write the failing test**

In `roblox/tests/EffectSelector.spec.luau`, add a block that reads the REAL registry (the
existing tests use a fixture, and must keep doing so):

```luau
local EffectRegistry = require("../src/shared/EffectRegistry")

describe("EffectRegistry — fates are parked", function()
    test("LOSS selects to nothing, for every world throw", function()
        local selector = EffectSelector.new(EffectRegistry, { random = function()
            return 0
        end })
        for _, w in { "R", "P", "S" } do
            expect(selector:select("LOSS", { worldThrow = w })).toBe(nil)
        end
    end)

    test("the celebrations are untouched", function()
        local selector = EffectSelector.new(EffectRegistry, { random = function()
            return 0
        end })
        for _, slot in { "REVEAL", "WIN", "SAFE", "BANK" } do
            expect(selector:select(slot, {}) ~= nil).toBe(true)
        end
    end)
end)
```

- [ ] **Step 2: Run to verify it fails**

Run: `lune run tests/run`
Expected: FAIL — `LOSS` returns `fateBoulder`/`fatePaper`/`fateShears`.

- [ ] **Step 3: Park the registry**

```luau
    -- PARKED 2026-08-03. LOSS used to select fateBoulder/fatePaper/fateShears, which
    -- FateController turned into a rock chasing the player. The owner withdrew the idea; the
    -- machinery stays because celebration effects will be built on it.
    --
    -- THIS EMPTY POOL IS THE WHOLE PARK for the client visuals: EffectSelector returns nil for
    -- an empty pool, so no `fate*` effect ever reaches FateController's cue guard and that file
    -- needs no edit at all. Re-enabling fates means putting the byThrow table back — a
    -- deliberate act that breaks the test above rather than a silent one.
    LOSS = {},
```

- [ ] **Step 4: Stop the server driving it**

In `roblox/src/server/main.server.luau`, delete `applyGrow` and `growDelaySeconds` entirely,
and replace the per-player reveal branch with:

```luau
                if mine then
                    profiles:applyLocalResult(userId, mine.result)
                    pushStats(player)
                    fireProfile(player, "local")
                end
```

Delete the now-unused `local growIn = growDelaySeconds()` line above the loop, the
`fates:begin(userId)` call, and any `TweenService` / `DrumStep` require that has no other
user. **Check each before deleting** — selene fails on an unused require, and it fails just as
hard on a deleted one that was still needed:

```bash
cd roblox && grep -n "TweenService\|DrumStep\|fates:" src/server/main.server.luau
```

Keep `FateRegistry`, `local fates = FateRegistry.new()` and the `fates:isBound` gate in
`SubmitPick`, and mark the seam:

```luau
    -- PARKED, not removed. Nothing calls fates:begin any more (see the reveal handler), so this
    -- is always false — it is one table lookup and it is the seam anything like this re-enters
    -- through. FateRegistry and its tests are intact.
    if fates:isBound(tostring(player.UserId)) then
```

- [ ] **Step 5: Record the timing recipe before it is deleted**

`growDelaySeconds` held the reveal-timing lesson. Add it above the `onReveal` handler:

```luau
        -- WHEN CELEBRATIONS COME BACK, FIRE THEM ON THE DRUM, NOT ON THE WIRE. RevealTheater
        -- lands ~3s before the drum settles, so anything triggered on the remote is early. The
        -- recipe the deleted applyGrow used: delay by
        -- math.clamp(StrikeAtServerTime - workspace:GetServerTimeNow() + DrumStep.SETTLE_SECONDS,
        -- 0, DrumStep.SETTLE_SECONDS + TallySec) — clamped so it fails late, never early.
        --
        -- And it has to be SERVER-side: Humanoid scale replicates server->client only, so an
        -- avatar effect triggered on the client is visible to nobody but its owner.
        onReveal = function(reveal)
```

- [ ] **Step 6: Make the client's header note true**

`main.client.luau:12` carries a note written in Task 5 saying fates are only HALF parked — that
the rock drop, the avatar grow and the server's fate gate are still live. **This task is what
makes them not live**, so the note is now wrong in the other direction. Replace it with:

```luau
-- FATES ARE PARKED (2026-08-03). The rock drop, the avatar grow and ACCEPT YOUR FATE are all
-- off: the client stopped surfacing the wait (Task 5) and the server stopped summoning it
-- (Task 13, at EffectRegistry.LOSS and the reveal handler). A LOSS now simply forfeits the pot
-- and says so on the drum.
--
-- The machinery underneath (ChoreographyMachine, EffectSelector, TheaterController) is intact by
-- design and keeps driving the WIN, SAFE and BANK effects. See the spec's §5 for the seam.
```

The two-commit split is deliberate and the note has to track it. A comment claiming a feature is
off while half of it still runs is worse than no comment — it is the one thing a reader trusts
without checking.

- [ ] **Step 7: Run and commit**

Run: `lune run tests/run` — expect PASS.

```bash
cd roblox && stylua src tests tools && selene src tools
git add roblox/src/shared/EffectRegistry.luau roblox/src/server/main.server.luau roblox/src/client/main.client.luau roblox/tests/EffectSelector.spec.luau
git commit -m "feat(roblox): park the fates at the one line that summons them"
```

---

