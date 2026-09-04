### Task 6: The two proximity loops

**Files:**
- Modify: `roblox/src/client/ShopController.client.luau:433-458`
- Modify: `roblox/src/client/AccessGateController.client.luau:92-124`

**Interfaces:**
- Consumes: `AmbientBudget.step` from Task 1. Neither file needs `inRange`/`inView` — these are player-position tests, not camera-visibility ones.
- Produces: nothing.

Two small same-shape edits, batched. Both currently run a proximity test at full frame rate for a trigger a walking player takes a quarter-second to cross. **They do not get the same treatment**, and the difference is the point of this task.

- [ ] **Step 1: `ShopController` — convert wholesale**

Its loop is a pure inside/outside test with a state change; nothing interpolates. Add the `ReplicatedStorage` require for `AmbientBudget`, then wrap the existing body:

```lua
local inside = false
local acc = 0
local POLL = 0.25 -- matches TourBeamController; a threshold a walking player crosses in ~0.25s
RunService.Heartbeat:Connect(function(dt: number)
    local fire, nextAcc = AmbientBudget.step(acc, dt, POLL)
    acc = nextAcc
    if not fire then
        return
    end
    local char = player.Character
    local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
    local now = false
    if root then
        local p = root.Position
        local pos = { x = p.X, y = p.Y, z = p.Z }
        for _, entry in boxes do
            if ShopThreshold.isInside(pos, entry.box) then
                now = true
                break
            end
        end
    end
    if now ~= inside then
        inside = now
        if now then
            dismissed = false -- a fresh visit always opens
            paint()
        end
        setOpen(now)
    elseif inside and not dismissed and not gui.Enabled then
        setOpen(true)
    end
end)
```

- [ ] **Step 2: `AccessGateController` — split, do not convert**

⚠ **This loop must not be polled wholesale.** Its fade is frame-rate coupled — `pad.alpha += (target - pad.alpha) * math.clamp(dt * FADE_RATE, 0, 1)` — so a 4 Hz body turns a smooth reveal into four visible steps a second. That is a visual regression, which this plan's Global Constraints forbid. Throttle only the distance test; cache its answer on the pad; keep the fade on the real frame `dt`.

Add `near` to the pad entry built around `:79` (initialise it `false`, beside the existing `collidable = false`), and note that the `Pad` type declaration near the top of the file needs the same field. Then:

```lua
local acc = 0
local POLL = 0.25 -- the reveal radii are ~90 studs; a walking player cannot cross one in a tick
RunService.Heartbeat:Connect(function(dt: number)
    if #pads == 0 then
        return
    end
    -- The O(pads) distance test is the throttled half. The fade below is NOT: it integrates against
    -- the real frame dt, and stepping it four times a second is a visible regression.
    local fire, nextAcc = AmbientBudget.step(acc, dt, POLL)
    acc = nextAcc
    if fire then
        local char = localPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
        local pos = hrp and hrp.Position
        for _, pad in pads do
            local near = false
            if pos ~= nil then
                local dx = pos.X - pad.center.X
                local dz = pos.Z - pad.center.Z
                near = (dx * dx + dz * dz) <= (pad.radius * pad.radius)
            end
            pad.near = near
            -- collision snaps at the threshold (solid the instant you're in range); the visual fades.
            if near ~= pad.collidable then
                pad.collidable = near
                for _, part in pad.parts do
                    part.CanCollide = near
                end
            end
        end
    end
    for _, pad in pads do
        local target = if pad.near then SHOWN else 1
        if math.abs(pad.alpha - target) > 0.001 then
            pad.alpha += (target - pad.alpha) * math.clamp(dt * FADE_RATE, 0, 1)
            if math.abs(pad.alpha - target) <= 0.01 then
                pad.alpha = target
            end
            for _, part in pad.parts do
                part.Transparency = pad.alpha
            end
        end
    end
end)
```

- [ ] **Step 3: Gates and commit**

```bash
cd roblox && stylua src tests tools && selene src tools && lune run tests/run && rojo build -o /tmp/build.rbxl
git add roblox/src/client/ShopController.client.luau roblox/src/client/AccessGateController.client.luau
git commit -m "perf(client): proximity tests poll at 4Hz; the gate fade keeps its frame dt"
```

---

