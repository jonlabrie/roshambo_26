### Task 4: `WheelController` — keep the integration, cull the writes

**Files:**
- Modify: `roblox/src/client/WheelController.client.luau:142-176`

**Interfaces:**
- Consumes: `AmbientBudget` as in Task 2.
- Produces: nothing.

⚠ **This file is not `ChochinSway`.** `angle` is **integrated** (`angle += dt * driveOmega * wheelDir`), so freezing it while the player looks away brings the wheel back at the wrong phase. Two rules follow, and both matter:

1. `angle` advances **every frame**, culled or not. It is one multiply-add.
2. The paddle-strike boundary block runs **every frame** too, and `lastStrike[side]` is **always** updated. Only the `b:Emit(3)` call is gated. Letting `k` advance without updating `lastStrike` would fire a splash on re-entry for a strike nobody saw.

- [ ] **Step 1: Add the require and config**

Same `ReplicatedStorage` require and the same `num` / `cfg` helpers as Task 2, Step 3.

- [ ] **Step 2: Replace the loop**

```lua
local angle = 0
local FALLBACK_OMEGA = 0.5 -- rad/s until HammerController publishes the real shaft rate (signed for WHEEL_DIR below)
local WHEEL_DIR = -1 -- maps the published shaft ω onto the wheel's local axle (live-tunable "WheelDir")
local lastStrike: { number } = { math.huge, math.huge } -- per-side paddle-boundary counters
local acc = 0

-- Range/view for the wheel itself, anchored on the first spin group's hub.
local function drawable(c: AmbientBudget.Config): boolean
    if #spins == 0 then
        return false
    end
    local cam = workspace.CurrentCamera
    if cam == nil then
        return false
    end
    local camCF = cam.CFrame
    local d = spins[1].hub.Position - camCF.Position
    local distSq = d.X * d.X + d.Y * d.Y + d.Z * d.Z
    if not AmbientBudget.inRange(distSq, c) then
        return false
    end
    local dist = math.sqrt(distSq)
    local look = camCF.LookVector
    local fdot = if dist > 1e-3 then (d.X * look.X + d.Y * look.Y + d.Z * look.Z) / dist else 1
    return AmbientBudget.inView(fdot, c)
end

RunService.Heartbeat:Connect(function(dt)
    -- The wheel IS the driver gear's shaft, so it turns at the EXACT angular velocity the
    -- bell-engine drive publishes ("DriveOmega", rad/s about Z) — matched rate + direction,
    -- not a free constant that out-runs the gears. WHEEL_DIR corrects the wheel's local axle
    -- orientation; flip it (or "DriverDir") live to fix the spin direction.
    local driveOmega = (stage:GetAttribute("DriveOmega") :: number) or FALLBACK_OMEGA
    local wheelDir = (stage:GetAttribute("WheelDir") :: number) or WHEEL_DIR
    -- ⚠ INTEGRATED, so it advances EVERY frame whether or not the wheel is drawn. Freezing it while
    -- the player looks away would bring the wheel back at a stale phase.
    angle += dt * driveOmega * wheelDir

    local c = cfg()
    local fire, nextAcc = AmbientBudget.step(acc, dt, c.interval)
    acc = nextAcc
    local visible = drawable(c)
    if fire and visible then
        for _, s in spins do
            local spun = s.hub * CFrame.Angles(angle, 0, 0)
            s.part.CFrame = spun
            for i, p in s.paddles do
                p.CFrame = spun * s.offsets[i]
            end
        end
    end
    -- splash when a paddle strikes the waterline: one boundary per 2π/paddleCount of
    -- rotation; the two sides (enter/exit) are offset half a bay so they alternate.
    --
    -- ⚠ RUNS EVERY FRAME AND ALWAYS UPDATES lastStrike, even when culled. Only the Emit is gated:
    -- skipping the bookkeeping would bank a boundary and splash on re-entry for a strike the player
    -- never saw.
    if paddleCount > 0 then
        local spacing = 2 * math.pi / paddleCount
        for side, b in bursts do
            local k = math.floor((angle + (side - 1) * spacing / 2) / spacing)
            if k ~= lastStrike[side] then
                if lastStrike[side] ~= math.huge and visible then
                    b:Emit(3)
                end
                lastStrike[side] = k
            end
        end
    end
end)
```

- [ ] **Step 3: Gates and commit**

```bash
cd roblox && stylua src tests tools && selene src tools && lune run tests/run && rojo build -o /tmp/build.rbxl
git add roblox/src/client/WheelController.client.luau
git commit -m "perf(client): waterwheel keeps turning, only draws when it is on screen"
```

---

