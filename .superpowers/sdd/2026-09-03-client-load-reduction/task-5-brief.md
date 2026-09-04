### Task 5: `HammerController` — split timing from rendering

**Files:**
- Modify: `roblox/src/client/HammerController.client.luau:355-377`, `:398-452`, `:457`

**Interfaces:**
- Consumes: `AmbientBudget` as in Task 2.
- Produces: continues to write the `DriveOmega` attribute on `RoshamboStage`, which Task 4's `WheelController` reads every frame. That write must not become conditional.

⚠ **The middle loop (`:398`) is load-bearing. It must keep running every frame.** It is not decorative:

- it detects the bell strike via `metronome:strikesBetween(lastMetroNow, nowSt)`, using `lastMetroNow` as the previous sample — throttle it and the bonshō is late, cull it and the bell goes silent;
- it publishes `DriveOmega`, which `WheelController` reads as its rate;
- it carries the self-healing backstop for a dropped `RoundUpdate` broadcast (the machine must never stop);
- it retries `captureSpinners()` until parts replicate.

So this is a **split**, not a gate. The timing half is a metronome read, a comparison and an attribute write — a handful of scalar operations, and it stays unconditional. The three spinner write loops are the expensive half and get the cull.

`arm` (`rig:WaitForChild("ShuMoku") :: BasePart`, declared at `:46`) is the shared cull anchor for all three loops — it is the machine's own moving part and is in scope at every site.

- [ ] **Step 1: Add the require, config and shared anchor**

Add the same `ReplicatedStorage` require and `num` / `cfg` helpers as Task 2, Step 3, plus:

```lua
-- All three loops below animate one machine, so they share one cull anchor: the shu-moku itself.
local function machineDrawable(c: AmbientBudget.Config): boolean
    local cam = workspace.CurrentCamera
    if cam == nil then
        return false
    end
    local camCF = cam.CFrame
    local d = arm.Position - camCF.Position
    local distSq = d.X * d.X + d.Y * d.Y + d.Z * d.Z
    if not AmbientBudget.inRange(distSq, c) then
        return false
    end
    local dist = math.sqrt(distSq)
    local look = camCF.LookVector
    local fdot = if dist > 1e-3 then (d.X * look.X + d.Y * look.Y + d.Z * look.Z) / dist else 1
    return AmbientBudget.inView(fdot, c)
end
```

- [ ] **Step 2: Gate the draw loop (`:355`)**

Declare `local drawAcc = 0` immediately above the connection, change the callback signature to `function(dt: number)`, and make the gate the **first** thing in the body — before the `DrawHold` attribute read, so a culled machine does no work at all:

```lua
local drawAcc = 0
RunService.Heartbeat:Connect(function(dt: number)
    local c = cfg()
    local fire, nextAcc = AmbientBudget.step(drawAcc, dt, c.interval)
    drawAcc = nextAcc
    if not (fire and machineDrawable(c)) then
        return
    end
    -- DRAW HOLD (tuning): while the "DrawHold" attribute is set, pin the log at FULL draw
    -- (p=1, the top of its travel) and ignore the strike — so we can park the dowel at its
    -- pullback-top position and aim the cam's high point at it.
    local hold = stage:GetAttribute("DrawHold")
    if striking and not hold then
        return
    end
    -- ... the rest of the existing body is unchanged ...
end)
```

The draw pose is derived from `r.drawP`, a pure function of the metronome's schedule, so it resumes at the correct position on re-entry with nothing to reset.

⚠ Note that this loop is safe to gate **only** because it does nothing but pose `arm`. It reads `striking`, it never writes it — the loop in Step 3 owns that flag. Confirm that is still true before gating; if this loop has gained a write to shared state, it needs the same split treatment as Step 3 instead.

- [ ] **Step 3: Split the cam/driver/jack loop (`:398`)**

⚠ **`DriveOmega` is currently written on the LAST line of this loop, after the three write loops. It must move above the gate.** If it stays below, the waterwheel falls back to `FALLBACK_OMEGA` every time the player looks away and the two machines silently desynchronise. `driverDir` is read once and used by both halves, so it is hoisted with it.

Replace the entire connection with this. Everything above the gate is the existing code in its existing order, with the `driverDir` read and the `DriveOmega` write lifted to the end of that half:

```lua
local spinAcc = 0
RunService.Heartbeat:Connect(function(dt: number)
    if #camSpinners == 0 then
        captureSpinners() -- parts hadn't replicated at init; keep trying until they do
    end
    local nowSt = workspace:GetServerTimeNow()
    local r = metronome:read(nowSt)
    if r == nil then
        return
    end
    if lastMetroNow and not striking and metronome:strikesBetween(lastMetroNow, nowSt) > 0 then
        strike(r.prevStrikeAt)
    end
    lastMetroNow = nowSt
    -- Self-timed backstop: RoundUpdate("OPEN") normally clears `striking`, but a
    -- dropped broadcast must not freeze the machine (spec: it never stops). Clear once
    -- the next round's ramp is underway — drawP has wrapped low — never mid-REVEAL
    -- (releasing early would slam the log back to near-full draw before the wrap).
    if striking and anchorAt and nowSt - anchorAt > 2 and r.drawP < 0.5 then
        striking = false
    end
    -- Turn WITH the metronome's own camAngle (0 at each strike), offset by the
    -- geometric anchor pinned at the last release.
    local camNet
    if anchorNet then
        camNet = anchorNet + CAM_DIR * r.camAngle
    else
        camNet = CAM_DIR * r.camAngle
    end
    local driverDir = (stage:GetAttribute("DriverDir") :: number) or DRIVER_DIR
    -- Published for WheelController, which LOCKS the wheel to this shaft (matched rate + direction).
    stage:SetAttribute("DriveOmega", driverDir * CAM_DIR * r.omega * REDUCTION) -- rad/s about Z

    -- ⚠ EVERYTHING ABOVE THIS LINE RUNS EVERY FRAME AND MUST KEEP DOING SO. Strike detection reads
    -- lastMetroNow as its previous sample, so throttling it makes the bonshō late and culling it
    -- silences the bell; the backstop above keeps the machine from freezing on a dropped broadcast;
    -- and WheelController reads DriveOmega as its rate every frame. Only the CFrame writes below are
    -- worth culling, and they are also the only expensive part of this loop.
    local c = cfg()
    local fire, nextAcc = AmbientBudget.step(spinAcc, dt, c.interval)
    spinAcc = nextAcc
    if not (fire and machineDrawable(c)) then
        return
    end
    local rot = CFrame.Angles(camNet, 0, 0)
    for _, s in camSpinners do
        s.part.CFrame = s.pivotCF * rot * s.pivotCF:Inverse() * s.restCF
    end
    -- Driver gear + main shaft are CO-AXIAL with the waterwheel (one N-S shaft), so they
    -- turn at the cam rate × REDUCTION.
    local drot = CFrame.Angles(0, 0, driverDir * camNet * REDUCTION)
    for _, s in driverSpinners do
        s.part.CFrame = s.pivotCF * drot * s.pivotCF:Inverse() * s.restCF
    end
    -- Jack shaft: 1:1 off the main shaft through the corner bevel, spun about world Y.
    local jackDir = (stage:GetAttribute("JackDir") :: number) or JACK_DIR
    local jrot = CFrame.Angles(0, jackDir * driverDir * camNet * REDUCTION * LANTERN_RATIO, 0)
    for _, s in jackSpinners do
        s.part.CFrame = s.pivotCF * jrot * s.pivotCF:Inverse() * s.restCF
    end
end)
```

Diff this against the original before committing: the only intended changes are the added `dt` parameter, the hoisted `driverDir` and `DriveOmega`, and the inserted gate. If anything else moved, the timing half has been disturbed.

- [ ] **Step 4: Gate the suspension loop (`:457`)**

`RunService.Heartbeat:Connect(updateSuspension)` becomes:

```lua
local suspAcc = 0
RunService.Heartbeat:Connect(function(dt: number)
    local c = cfg()
    local fire, nextAcc = AmbientBudget.step(suspAcc, dt, c.interval)
    suspAcc = nextAcc
    -- updateSuspension recomputes chains and dowels from the log's LIVE CFrame every time, so it
    -- self-corrects on its first frame back and needs no reset after a cull.
    if fire and machineDrawable(c) then
        updateSuspension()
    end
end)
```

- [ ] **Step 5: Verify the bell still rings when you look away**

This one cannot be caught by the test suite. In Studio, Play, walk the avatar behind the drum so the machine is out of view, and confirm from the console/audio that the bonshō still strikes on schedule and that `RoshamboStage`'s `DriveOmega` attribute keeps changing in the Explorer. If either stops, the split is wrong — the timing half has been caught by the gate.

- [ ] **Step 6: Gates and commit**

```bash
cd roblox && stylua src tests tools && selene src tools && lune run tests/run && rojo build -o /tmp/build.rbxl
git add roblox/src/client/HammerController.client.luau
git commit -m "perf(client): bell engine splits timing from rendering; only the CFrames are culled"
```

---

