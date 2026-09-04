### Task 2: `ChochinSway` — path poles stop swaying, the rest get culled

**Files:**
- Modify: `roblox/src/client/ChochinSway.client.luau` (the whole file; it is 89 lines)

**Interfaces:**
- Consumes: `AmbientBudget.inRange`, `AmbientBudget.inView`, `AmbientBudget.step`, `AmbientBudget.DEFAULT` from Task 1.
- Produces: nothing other tasks consume. Tasks 3–5 copy this file's `cfg()` / camera-math shape, so get it right here.

**Context an implementer needs.** Three builders stamp the `ChochinSwing` tag: `tools/studio/buildChochinPole.luau` (the path poles, which hang their lantern from a `CrossArm` sibling), `buildTeahouseChochin.luau` and `buildHanabiyaChochin.luau` (which hang differently and have no arm). The owner's ruling is that **pole-hung lanterns do not sway at all** — measured, the effect is about an inch and a half of travel on a two-foot lantern over a seven-second cycle. The other two populations keep it. `hangPointFor` already distinguishes them, so it becomes the predicate; its hang-point derivation existed solely to make pole sway pivot correctly and dies with the population it served.

**Do not un-tag anything in the builders.** Those are Studio stamping tools; changing them would not touch lanterns already in the saved place. The split belongs in this file, where it is one predicate.

- [ ] **Step 1: Replace `hangPointFor` with the predicate**

Delete the whole `hangPointFor` function (lines 16–39, comment block included) and put this in its place:

```lua
-- ⚠ POLE-HUNG CHŌCHIN DO NOT SWAY (owner ruling, 2026-09-03). Measured, the effect was ~1.5 inches
-- of travel on a two-foot lantern over a seven-second cycle: legible at arm's length, under a pixel
-- past thirty feet, and a path is exactly where the player is moving. The path population is also
-- the large one (PathLanterns is 2,599 descendants). The teahouse and hanabiya chōchin -- seen from
-- a standstill on an engawa or in a doorway -- keep theirs.
--
-- A `CrossArm` sibling IS the discriminator: buildChochinPole stamps one, the teahouse and hanabiya
-- builders do not.
--
-- HISTORY, so nobody re-derives the bug if sway ever comes back to the poles: this used to derive
-- the hang point from the cross-arm rather than trust the stored WorldPivot, because the pivot is
-- place data and the geometry is builder data. When the poles were shortened, every already-stamped
-- lantern kept the taller pole's pivot and swung about a point 3.4 studs up in the air. That
-- derivation is gone with the sway it served; it is in git if it is ever needed again.
local function isPoleHung(m: Model): boolean
    local parent = m.Parent
    if parent == nil then
        return false
    end
    local arm = parent:FindFirstChild("CrossArm")
    return if arm then arm:IsA("BasePart") else false
end
```

- [ ] **Step 2: Skip pole lanterns at registration**

In `add`, replace the `local derived = hangPointFor(m) ... m.WorldPivot = derived` block (and its two-line comment about `WorldPivot` not moving geometry) with an early return, so the body becomes:

```lua
local function add(m: Instance)
    if not m:IsA("Model") then
        return
    end
    if isPoleHung(m) then
        return -- path poles never sway; see isPoleHung
    end
    for _, e in entries do
        if e.model == m then
            return
        end
    end
    local base = m:GetPivot()
    local p = base.Position
    local jitter = (math.floor(p.X) % 7) / 7 -- 0..1 per-site variation
    entries[#entries + 1] = {
        model = m,
        base = base,
        phase = (p.X * 0.13 + p.Z * 0.17) % (2 * math.pi), -- positional desync
        amp = AMP * (0.8 + 0.4 * jitter),
        speed = SPEED * (0.85 + 0.3 * jitter),
    }
end
```

The `isPoleHung` check goes **before** the duplicate scan so a pole lantern never enters `entries` by any path.

- [ ] **Step 3: Add the require and the live-tune config**

At the top, beside the existing service locals, add:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AmbientBudget = require(ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("AmbientBudget"))
```

⚠ Require through `ReplicatedStorage.RoshamboShared`, never a relative path — a client file that used a relative require here has broken before (`16331e6`).

Then, above the `Heartbeat` connection:

```lua
-- Live-tunable from Workspace attributes during a walk, defaults from the module -- the same
-- convention FoliageImpostorController uses for ImpostorCapFadeLo and its neighbours.
local function num(attr: string, default: number): number
    local v = workspace:GetAttribute(attr)
    return if typeof(v) == "number" then v else default
end

local function cfg(): AmbientBudget.Config
    local d = AmbientBudget.DEFAULT
    return {
        radius = num("AmbientRadius", d.radius),
        behindDot = num("AmbientBehindDot", d.behindDot),
        interval = if num("AmbientHz", 0) > 0 then 1 / num("AmbientHz", 0) else d.interval,
    }
end
```

- [ ] **Step 4: Replace the loop with the culled version**

Replace the `RunService.Heartbeat:Connect(...)` block at the end of the file with:

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
    for _, e in entries do
        local d = e.base.Position - camPos
        local distSq = d.X * d.X + d.Y * d.Y + d.Z * d.Z
        if not AmbientBudget.inRange(distSq, c) then
            continue
        end
        -- sqrt only for what survived the range test; see AmbientBudget.inRange
        local dist = math.sqrt(distSq)
        local fdot = if dist > 1e-3 then (d.X * look.X + d.Y * look.Y + d.Z * look.Z) / dist else 1
        if not AmbientBudget.inView(fdot, c) then
            continue
        end
        local a = e.amp * math.sin(t * e.speed + e.phase)
        local b = e.amp * 0.45 * math.sin(t * e.speed * 0.7 + e.phase * 1.3) -- subtle cross-axis drift
        e.model:PivotTo(e.base * CFrame.Angles(a, 0, b))
    end
end)
```

⚠ **Culling is free here and it is worth knowing why:** the pose is a pure function of `os.clock()`, not integrated state, so a lantern that comes back into view resumes at exactly the phase it would have had. Nothing to reset, no drift, no re-entry pop. Tasks 4 and 5 do **not** have this property and must not copy the pattern blindly.

- [ ] **Step 5: Update the file header**

The header still describes sway on "the hanging path chōchin". Rewrite the first paragraph to say the file animates the teahouse and hanabiya chōchin, that path poles are excluded by owner ruling, and that the swinging body carries the RoundLantern glyph (that clause is still true and still matters).

- [ ] **Step 6: Gates and commit**

```bash
cd roblox && stylua src tests tools && selene src tools && lune run tests/run && rojo build -o /tmp/build.rbxl
git add roblox/src/client/ChochinSway.client.luau
git commit -m "perf(client): path chochin stop swaying; the rest animate only in view"
```

---

