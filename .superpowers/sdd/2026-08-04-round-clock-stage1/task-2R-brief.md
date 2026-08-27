### Task 2R: The lockout instant comes from the timeline, not the poll

**Files:**
- Modify: `roblox/src/shared/RoundMetronome.luau` (one derived field)
- Modify: `roblox/tests/RoundMetronome.spec.luau`
- Modify: `roblox/src/server/RoundCoordinator.luau` (read the shared constant)
- Modify: `roblox/src/client/main.client.luau`

**Interfaces:**
- Consumes: `Reading.phase` / `Reading.secondsLeft` from Task 1.
- Produces:
  - `RoundMetronome.LOCKOUT_SECONDS` — the shared constant, moved out of `RoundCoordinator`
  - `Reading.lockoutIn: number` — seconds from `now` until this round's lockout; `0` once past it,
    and `0` in any phase but `ACTIVE`

**Context:** `RoundCoordinator` owns `LOCKOUT_BEFORE_END_MS = 2000` privately and sends the client a
`secondsToLockout` on each `RoundUpdate`. That arrival is the ~1s of poll lag. The timeline already
knows where the round's ACTIVE phase ends, so it can derive the same instant locally — but only if
both sides read the same constant.

**`secondsLeft()`'s MEANING DOES NOT CHANGE.** It is still seconds-to-lockout. This task changes
only where `lockoutAt` comes from, never what the number means. `HudModel` keeps using it for the
ring, `throwsEnabledFor` and `sendAtLockout` exactly as it does today.

- [ ] **Step 1: Write the failing tests**

Add to `roblox/tests/RoundMetronome.spec.luau`, reusing the 27s fixture from Task 1's block:

```lua
describe("RoundMetronome — the lockout, derived rather than delivered", function()
    test("the constant is here so the client and the game server cannot disagree", function()
        -- It lived privately in RoundCoordinator and reached the client only on a
        -- RoundUpdate, which is the ~1s of poll lag this stage removes. Two copies
        -- of a deadline is how they drift.
        expect(RoundMetronome.LOCKOUT_SECONDS).toBe(2)
    end)

    test("it counts down to the lockout, not to the end of ACTIVE", function()
        local m = m27()
        local roundStart = 1000 - 22
        -- ACTIVE is 20s and the lockout is 2s before its end, so the window is 18s.
        expect(m:read(roundStart).lockoutIn).toBeCloseTo(18, 0.001)
        expect(m:read(roundStart + 17).lockoutIn).toBeCloseTo(1, 0.001)
    end)

    test("it is zero THROUGH the lockout window, not negative", function()
        -- The throw gate is `> 0`. A negative here would read as "time remaining"
        -- to anything doing arithmetic on it, and would reopen throws that must
        -- stay shut.
        local m = m27()
        local roundStart = 1000 - 22
        expect(m:read(roundStart + 18).lockoutIn).toBe(0)
        expect(m:read(roundStart + 19).lockoutIn).toBe(0)
        expect(m:read(roundStart + 19.99).lockoutIn).toBe(0)
    end)

    test("it is zero outside ACTIVE", function()
        local m = m27()
        local roundStart = 1000 - 22
        expect(m:read(roundStart + 20).lockoutIn).toBe(0) -- TALLY
        expect(m:read(roundStart + 23).lockoutIn).toBe(0) -- REVEAL
    end)
end)
```

- [ ] **Step 2: Run and watch them fail**, then implement

`LOCKOUT_SECONDS = 2` on the module. In `read()`, derive from the values already in scope:

```lua
    -- The lockout instant, derived rather than delivered. Zero outside ACTIVE and zero
    -- THROUGH the window itself — never negative, because the throw gate is `> 0` and a
    -- negative would read as time remaining.
    local lockoutIn = 0
    if phase == "ACTIVE" then
        lockoutIn = math.max(0, (activeEnd - RoundMetronome.LOCKOUT_SECONDS) - elapsed)
    end
```

Return it on `Reading`. Do not recompute `elapsed`, `activeEnd` or `phase` — Task 1 put them in
scope.

- [ ] **Step 3: Point `RoundCoordinator` at the shared constant**

Replace its private `LOCKOUT_BEFORE_END_MS = 2000` with `RoundMetronome.LOCKOUT_SECONDS * 1000`,
requiring the module the way that file requires its other shared modules. The Roblox **server** and
the client now read one number.

Confirm `RoundCoordinator`'s existing tests still pass untouched. If it has none covering the
lockout, say so in your report rather than adding them here.

- [ ] **Step 4: Use the local lockout in the client**

In `main.client.luau`:

- build a `RoundMetronome` fed from `ReplicatedStorage:WaitForChild("RoundScheduleConfig")`,
  mirroring `HammerController.client.luau`'s reading of the same attributes and defaults
- pass **`workspace:GetServerTimeNow()`** to `read()` — the schedule is published on that timeline.
  Not `os.clock()`, not `tick()`
- derive `phase` and `lockoutAt` from the reading when one is available
- **fall back to exactly today's behaviour when `read()` returns `nil`** — the last `RoundUpdate` —
  so a client joining mid-round degrades to what it does now
- `RoundUpdate` remains authoritative for round identity, and corrects the phase when it disagrees

**Do not touch `secondsLeft()`'s formula or its meaning.** It stays `max(0, lockoutAt - now)`. The
only change is that `lockoutAt` may now come from the timeline.

Note the clock mismatch and handle it explicitly: `secondsLeft()` currently compares against
`os.clock()`. If `lockoutAt` becomes a `GetServerTimeNow` value, both sides of that subtraction must
be on the same timeline. Getting this wrong yields a countdown off by the server's uptime. State in
your report which timeline you settled on and why.

- [ ] **Step 5: The standing check**

No gate loads `main.client.luau`. Verify by reading, with line numbers:
1. every `Reading.X` read exists on what Task 1 and Step 2 return
2. `lockoutAt` and the value it is compared against are on the **same** clock
3. the nil-reading fallback is reachable — trace a client joining mid-round
4. `secondsLeft()`'s formula is unchanged
5. no new local used above its declaration

- [ ] **Step 6: Gates and commit**

```bash
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26/roblox
lune run tests/run && stylua --check src tests tools && selene src tools
cd /Users/jonlabrie/Desktop/ClaudeCode/Roshambo_26
git add roblox/src/shared/RoundMetronome.luau roblox/tests/RoundMetronome.spec.luau \
        roblox/src/server/RoundCoordinator.luau roblox/src/client/main.client.luau
git commit -m "feat(roblox): the lockout is derived from the timeline, not waited for"
```

---

