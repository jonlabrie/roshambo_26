### Task 3: `NorenSway` — cull by panel

**Files:**
- Modify: `roblox/src/client/NorenSway.client.luau:81-96`

**Interfaces:**
- Consumes: `AmbientBudget` as in Task 2, including the identical `num`/`cfg` helpers.
- Produces: nothing.

Each panel already caches `panel.hinge` (a `Vector3`), so the cull anchor is in hand with no instance read. The pose is a pure function of `os.clock()`, so culling is free for the same reason it is in Task 2.

- [ ] **Step 1: Add the require and config**

Add the same `ReplicatedStorage` require and the same `num` / `cfg` helpers as Task 2, Step 3 (copy them verbatim — two small local functions in two files is cheaper than a shared client module neither can test).

- [ ] **Step 2: Replace the loop**

```lua
local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
    local c = cfg()
    local fire, nextAcc = AmbientBudget.step(acc, dt, c.interval)
    acc = nextAcc
    if not fire then
        return
    end
    local cam = workspace.CurrentCamera
    if cam == nil then
        return
    end
    local camCF = cam.CFrame
    local camPos, look = camCF.Position, camCF.LookVector
    local t = os.clock()
    for _, panel in panels do
        local d = panel.hinge - camPos
        local distSq = d.X * d.X + d.Y * d.Y + d.Z * d.Z
        if not AmbientBudget.inRange(distSq, c) then
            continue
        end
        local dist = math.sqrt(distSq)
        local fdot = if dist > 1e-3 then (d.X * look.X + d.Y * look.Y + d.Z * look.Z) / dist else 1
        if not AmbientBudget.inView(fdot, c) then
            continue
        end
        -- Walk the chain from the rail: each segment hangs off the bottom of the one above, so
        -- the panel stays joined no matter how far any single joint bends.
        local pos = panel.hinge
        for i, s in panel.segs do
            local ax = s.rest * (1 + SWAY * math.sin(t * SPEED + panel.phase + i * LAG))
            local az = s.rest * CROSS * math.sin(t * SPEED * 0.7 + panel.phase * 1.3 + i * LAG)
            local dir = CFrame.Angles(ax, 0, az)
            local drop = dir:VectorToWorldSpace(Vector3.new(0, -s.h, 0))
            s.part.CFrame = CFrame.new(pos + drop * 0.5) * dir
            pos += drop
        end
    end
end)
```

- [ ] **Step 3: Gates and commit**

```bash
cd roblox && stylua src tests tools && selene src tools && lune run tests/run && rojo build -o /tmp/build.rbxl
git add roblox/src/client/NorenSway.client.luau
git commit -m "perf(client): noren stir only for panels the camera can see"
```

---

