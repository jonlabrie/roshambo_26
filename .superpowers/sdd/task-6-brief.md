### Task 6: gongStrike leaves the choreography; drum spins until the data lands

**Files:**
- Modify: `roblox/src/shared/ChoreographyMachine.luau` (revealCues seed list, ~line 28)
- Modify: `roblox/tests/ChoreographyMachine.spec.luau` (~line 50 kinds assertion; scan the file for other gongStrike expectations)
- Modify: `roblox/src/client/DrumController.client.luau` (gongHit handler ~line 209; spin→glide gate ~line 146)

**Interfaces:**
- Consumes: `gongHit` cue (unchanged, from Task 5's swing contact).
- Produces: `revealCues` no longer emits `gongStrike` (Hammer self-times). Drum behavior: spins on every `gongHit`; glides only once `latestWorldThrow` is present (or a 6 s stall cap), landing that throw; clears the stored throw on use.

- [ ] **Step 1: Update the choreography spec expectation (failing test first)**

In `roblox/tests/ChoreographyMachine.spec.luau` line ~50:

```lua
        expect(kinds).toEqual({ "drumrollStop", "basinErupt", "heroTileLand" })
```

Scan the rest of the spec for `gongStrike` and remove/renumber any other occurrence. Run `lune run tests/run` — expect this spec to FAIL against the unmodified module.

- [ ] **Step 2: Remove the cue**

In `roblox/src/shared/ChoreographyMachine.luau`, the seed list becomes:

```lua
        {
            { atMs = 0, idx = 1, kind = "drumrollStop" },
            { atMs = 0, idx = 2, kind = "basinErupt" },
            { atMs = 0, idx = 3, kind = "heroTileLand", worldThrow = reveal.worldThrow },
        }
```

(`gongStrike` is self-timed by HammerController since Task 5.) Run `lune run tests/run` — green.

- [ ] **Step 3: Drum — spin always, glide on data**

In `roblox/src/client/DrumController.client.luau`:

Near `local latestWorldThrow: string? = nil` add:

```lua
local lastLandedThrow: string? = nil
local STALL_MAX = 6 -- s past min spin to wait for the reveal before settling anyway
```

The gongHit handler loses its no-data bail (the strike is now scheduled; data may
still be in flight — that's the point):

```lua
EventBus.Cue.Event:Connect(function(cue)
    if cue.kind == "gongHit" then
        omega = (stage:GetAttribute("DrumKick") :: number) or DRUM_KICK
        spinUntil = os.clock() + SPIN_SEC
        strikeT0 = os.clock()
        mode = "spin"
        -- the dowel smacks the paddle: fast 90° to rest PARALLEL to the log
        kickState = "flick"
        kickBase = kickAngle
        kickTarget = kickAngle + math.pi / 2
        kickDur = KICK_FLICK_DUR
        kickT0 = os.clock()
    end
end)
```

In the Heartbeat's spin branch, the glide gate waits for the data (consume-on-use;
the one RevealTheater arrival between strikes is this round's by construction):

```lua
    if mode == "spin" then
        theta -= omega * _dt
        local haveThrow = latestWorldThrow ~= nil
        if os.clock() >= spinUntil and (haveThrow or os.clock() >= spinUntil + STALL_MAX) then
            local throw = latestWorldThrow or lastLandedThrow or "R"
            lastLandedThrow = throw
            latestWorldThrow = nil
            landTheta = landTargetFor(throw, omega * GLIDE_SEC / 2)
            glideP0 = theta
            glideD = theta - landTheta
            glideT0 = os.clock()
            mode = "glide"
        end
        applyTheta()
```

(The existing stuck-guard in the `RoundUpdate` handler stays as the final backstop.)

- [ ] **Step 4: Verify + lint**

Run: `lune run tests/run && stylua --check src tests tools && selene src tools`
Expected: green.

- [ ] **Step 5: Commit**

```bash
git add roblox/src/shared/ChoreographyMachine.luau roblox/tests/ChoreographyMachine.spec.luau roblox/src/client/DrumController.client.luau
git commit -m "feat(roblox): strike self-timed — choreography drops gongStrike; drum spins until the reveal lands"
```

---

