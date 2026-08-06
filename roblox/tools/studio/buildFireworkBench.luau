-- buildFireworkBench.luau — firework VFX + mobile perf bench (v2, 2026-08-05)
--
-- HOW TO RUN: paste this whole file into the Studio command bar (View -> Command Bar) in EDIT mode
-- and press Enter, then PUBLISH and open the place on the device. It reports its result ON SCREEN;
-- no developer console is needed. Re-running is idempotent.
--
-- HOW TO REMOVE: set REMOVE = true below, paste again, AND PUBLISH. Removal is a flag on this same
-- file precisely so it is never a thing you have to remember how to undo.
--
-- ============================== READ THIS BEFORE USING THE BENCH ==============================
-- THE BENCH IS THE MOST DANGEROUS CODE IN THE PLACE. Its v1 was left ENABLED in
-- StarterPlayerScripts of the PUBLISHED place. StarterPlayerScripts auto-runs for every client on
-- join and is invisible from the server, so nothing anyone normally checks would find it. It ran
-- for days, self-ramping toward 10 shells/sec for every player, and a full session was then spent
-- diagnosing "the world is too heavy" — measuring the harness, not the world. The owner found it,
-- not the tooling. See the perf-harness-contamination memory.
--
--   * PARK THE BENCH THE INSTANT ITS READING IS TAKEN. Not end of session. Not "before we ship".
--   * PUBLISHING WITH THE BENCH IN IS SHIPPING THE BENCH. Publishing is what puts it on a device;
--     it goes out to everyone who opens the experience.
--   * BEFORE BELIEVING ANY PERF REGRESSION, first enumerate what YOU put in the place.
--
-- Two mitigations are now built in so a forgotten bench is bounded rather than permanent:
--   (a) the run SELF-TERMINATES after the last ramp step (~2m40s) instead of ramping forever, and
--   (b) the script is named PERF_BENCH_REMOVE_ME so it is unmissable in the explorer.
-- ==============================================================================================
--
-- HARD LESSONS BAKED IN (2026-07-20 — see the roshambo-fireworks memory):
--   1. ParticleEmitter:Emit() does NOT replicate server->client. A server-created Trail/part shows
--      (property-driven), but a server :Emit() burst is invisible to clients. Fireworks MUST be
--      client-emitted -> the launcher is a LocalScript in StarterPlayerScripts (runs per client),
--      NOT a server Script. (This is also the correct production architecture: client-side VFX.)
--   2. A ParticleEmitter with Texture == "" renders NOTHING. Always set a texture. The built-in
--      sparkle below is soft/fuzzy; the real fix for crisp sparks is a custom round-dot upload
--      (lower overdraw too). <-- still open.
--   3. Fire NEAR the player. First pass hardcoded world-origin (0,6,0) and showed nothing because
--      the player was ~110 studs up the canyon. This version launches relative to LocalPlayer.
--   4. NEVER ADD A SECOND BloomEffect. v1 created `FireworkBloom` unconditionally and stacked it on
--      the shipped `Lighting.Bloom` — a doubled full-screen post pass for every player, and a
--      visual bug nobody attributed. This version REUSES any existing BloomEffect.
--   5. stylua and selene DO NOT SEE INSIDE the [==[ ]==] source string below. A duplicate local
--      once shipped through a clean lint. To check it, extract the string to a .luau and lint that.
--
-- MOBILE-PERF DESIGN: Trail ascent, ParticleEmitter :Emit burst, LightEmission=1 + ONE global Bloom
-- for glow (no per-shell lights), small sparks.
--
-- WHAT v2 FIXED, and why each mattered:
--   * ON-SCREEN READOUT. v1 printed the rate to the developer console — unreadable on a phone in
--     practice, so the one number the whole exercise existed to produce was never captured.
--   * A NO-SHELLS BASELINE ROW. The first step fires nothing, so the world's own cost is separated
--     from the fireworks' cost. Without it the two terms are conflated and neither is knowable.
--   * SELF-TERMINATION + a bounded step list, so a forgotten bench decays instead of ramping on.
--
-- MEASUREMENT PROTOCOL (all three matter; skipping any one invalidates the run):
--   1. Set graphics quality MANUALLY. On Automatic the client lowers quality as frames drop, which
--      is exactly what hides a knee — it will read clean all the way down.
--   2. Stand still, facing the shells, in the heaviest scene (the arena). Camera movement changes
--      what is on screen and the sampler cannot tell that from shell cost.
--   3. Do not touch the quality slider mid-run.
--
-- RESULT ON RECORD (2026-08-05): Samsung A13 (Helio G80), manual quality 5 and Automatic — ramped
-- to the 10 shells/sec floor, impacted but still usable. ~5x the iPhone 15 Pro's July run on a far
-- weaker device. NOTE WHAT THIS DOES NOT COVER: one launcher at the local player's feet. It does
-- not exercise the global concurrent-shell director, which is still the load-bearing piece for a
-- 50-player battle.

local REMOVE = false -- set true + paste + PUBLISH to park the bench

local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local sps = StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts")
    or StarterPlayer:WaitForChild("StarterPlayerScripts")

local BENCH_NAME = "PERF_BENCH_REMOVE_ME"
local PARK_NAME = "FireworkBench_PARKED"

local function park()
    local parked = ServerStorage:FindFirstChild(PARK_NAME)
    if not parked then
        parked = Instance.new("Folder")
        parked.Name = PARK_NAME
        parked.Parent = ServerStorage
    end
    local found = {}
    -- every historical name this bench has shipped under
    for _, name in { BENCH_NAME, "FireworkLauncher" } do
        local ls = sps:FindFirstChild(name)
        if ls then
            ls.Enabled = false
            ls.Name = "PerfBench_LOCAL"
            local dup = parked:FindFirstChild(ls.Name)
            if dup then
                dup:Destroy()
            end
            ls.Parent = parked
            table.insert(found, name)
        end
    end
    local fb = Lighting:FindFirstChild("FireworkBloom")
    if fb then
        fb:Destroy()
        table.insert(found, "Lighting.FireworkBloom")
    end
    local runtime = workspace:FindFirstChild("FireworkBenchClient")
    if runtime then
        runtime:Destroy()
        table.insert(found, "Workspace.FireworkBenchClient")
    end
    return found
end

if REMOVE then
    local found = park()
    print(
        ("[FireworkBench] PARKED to ServerStorage.%s: %s. NOW PUBLISH — the live place keeps the bench until you do."):format(
            PARK_NAME,
            #found == 0 and "nothing found" or table.concat(found, ", ")
        )
    )
    return
end

park() -- idempotent: clear any prior copy before placing a fresh one

-- ONE global Bloom makes LightEmission sparks glow at fixed cost. REUSE the shipped one if present
-- (lesson 4) — a second BloomEffect is a doubled full-screen pass, not a brighter glow.
local bloom = Lighting:FindFirstChildOfClass("BloomEffect")
local madeBloom = false
if not bloom then
    bloom = Instance.new("BloomEffect")
    bloom.Name = "FireworkBloom"
    bloom.Intensity = 0.55
    bloom.Threshold = 0.9
    bloom.Size = 14
    bloom.Parent = Lighting
    madeBloom = true
end

local ls = Instance.new("LocalScript")
ls.Name = BENCH_NAME
ls.Source = [==[
-- FIREWORK PERF BENCH v2 — SELF-TERMINATING, ON-SCREEN READOUT.
-- Reads its own result on the device: no developer console needed. Step 0 fires NOTHING, so the
-- first row is the clean world's baseline; every later row is that baseline plus a known shell rate.
-- It STOPS on its own after the last step and leaves the table on screen to be screenshotted.

local STEP_SECONDS = 10 -- seconds held at each rate
local RAMP_START = 3.0 -- seconds between shells at the easy end
local RAMP_FLOOR = 0.10 -- 10 shells/sec
local RAMP_FACTOR = 0.70
local KNEE_FPS = 30 -- the threshold we are hunting
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local bench = Instance.new("Folder")
bench.Name = "FireworkBenchClient"
bench.Parent = Workspace

---------------------------------------------------------------- readout
local gui = Instance.new("ScreenGui")
gui.Name = "PerfBenchHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
-- ZIndexBehavior defaults to Global, under which a child does NOT draw above its parent.
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(300, 400)
panel.Position = UDim2.fromOffset(8, 8)
panel.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel = 0
panel.Parent = gui
Instance.new("UICorner").Parent = panel

local head = Instance.new("TextLabel")
head.Size = UDim2.new(1, -12, 0, 64)
head.Position = UDim2.fromOffset(6, 4)
head.BackgroundTransparency = 1
head.TextColor3 = Color3.fromRGB(255, 255, 255)
head.Font = Enum.Font.GothamBold
head.TextSize = 26
head.TextXAlignment = Enum.TextXAlignment.Left
head.TextYAlignment = Enum.TextYAlignment.Top
head.Text = "starting..."
head.Parent = panel

local list = Instance.new("Frame")
list.Size = UDim2.new(1, -12, 1, -74)
list.Position = UDim2.fromOffset(6, 70)
list.BackgroundTransparency = 1
list.Parent = panel
local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 1)
layout.Parent = list

local rowN = 0
local function addRow(text, color)
	rowN += 1
	local l = Instance.new("TextLabel")
	l.LayoutOrder = rowN
	l.Size = UDim2.new(1, 0, 0, 20)
	l.BackgroundTransparency = 1
	l.TextColor3 = color or Color3.fromRGB(210, 210, 210)
	l.Font = Enum.Font.Code
	l.TextSize = 16
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Text = text
	l.Parent = list
end

---------------------------------------------------------------- fps sampling
local frames, accum, worst = 0, 0, math.huge
RunService.RenderStepped:Connect(function(dt)
	frames += 1
	accum += dt
	local fps = 1 / math.max(dt, 1e-6)
	if fps < worst then
		worst = fps
	end
end)
local function resetSample()
	frames, accum, worst = 0, 0, math.huge
end
local function readSample()
	if frames == 0 or accum <= 0 then
		return 0, 0
	end
	return frames / accum, worst
end

---------------------------------------------------------------- shells
local function playerPos()
	local plr = Players.LocalPlayer
	local hrp = plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if hrp then
		return hrp.Position
	end
	local cam = Workspace.CurrentCamera
	return cam and cam.CFrame.Position or Vector3.new(0, 6, 0)
end
local function seq(a)
	return NumberSequence.new(a)
end
local function emitter(parent, color, tail, sizeSeq, life, speed, accel, drag)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	e.LightEmission, e.LightInfluence = 1, 0
	e.Color = ColorSequence.new(color, tail)
	e.Size = sizeSeq
	e.Transparency = seq({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.15),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = life
	e.Speed = speed
	e.SpreadAngle = Vector2.new(360, 360)
	e.Acceleration = accel
	e.Drag = drag
	e.Rate = 0
	e.Parent = parent
	return e
end
local PALETTE = {
	Color3.fromRGB(255, 90, 80),
	Color3.fromRGB(90, 170, 255),
	Color3.fromRGB(120, 255, 140),
	Color3.fromRGB(255, 210, 90),
	Color3.fromRGB(230, 120, 255),
}
local PRESETS = {
	peony = {
		main = 520,
		glitter = 180,
		colorFn = function(hue)
			return hue, Color3.fromRGB(255, 240, 200)
		end,
		size = seq({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(0.7, 0.32),
			NumberSequenceKeypoint.new(1, 0),
		}),
		life = NumberRange.new(2.0, 2.9),
		speed = NumberRange.new(32, 46),
		accel = Vector3.new(0, -28, 0),
		drag = 2.5,
	},
	willow = {
		main = 380,
		glitter = 140,
		colorFn = function(_)
			return Color3.fromRGB(255, 214, 120), Color3.fromRGB(180, 40, 20)
		end,
		size = seq({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(0.85, 0.3),
			NumberSequenceKeypoint.new(1, 0),
		}),
		life = NumberRange.new(3.0, 3.9),
		speed = NumberRange.new(14, 22),
		accel = Vector3.new(0, -16, 0),
		drag = 1.8,
	},
}
local function breakShell(pos, presetName, hue)
	local P = PRESETS[presetName]
	local part = Instance.new("Part")
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.Transparency = 1
	part.CFrame = CFrame.new(pos)
	part.Parent = bench
	-- flash core (one bright pop)
	emitter(
		part,
		Color3.fromRGB(255, 255, 255),
		Color3.fromRGB(255, 255, 255),
		seq({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 0) }),
		NumberRange.new(0.16, 0.16),
		NumberRange.new(0, 0),
		Vector3.new(),
		0
	):Emit(1)
	-- main burst
	local c, t = P.colorFn(hue)
	emitter(part, c, t, P.size, P.life, P.speed, P.accel, P.drag):Emit(P.main)
	-- glitter / crackle
	emitter(
		part,
		Color3.fromRGB(255, 240, 210),
		Color3.fromRGB(255, 180, 90),
		seq({ NumberSequenceKeypoint.new(0, 0.16), NumberSequenceKeypoint.new(1, 0) }),
		NumberRange.new(0.3, 1.3),
		NumberRange.new(10, 26),
		Vector3.new(0, -20, 0),
		3
	):Emit(P.glitter)
	Debris:AddItem(part, 4.5)
end
local function launch(presetName)
	local hue = PALETTE[math.random(1, #PALETTE)]
	local origin = playerPos() + Vector3.new(math.random(-18, 18), -4, math.random(-18, 18))
	local apex = origin + Vector3.new(math.random(-10, 10), math.random(40, 56), math.random(-10, 10))
	local shell = Instance.new("Part")
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.new(0.5, 0.5, 0.5)
	shell.Color, shell.Material, shell.Transparency = hue, Enum.Material.Neon, 0.1
	shell.Anchored, shell.CanCollide, shell.CanQuery, shell.CanTouch = true, false, false, false
	shell.CFrame = CFrame.new(origin)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, -0.3, 0)
	a0.Parent = shell
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, 0.3, 0)
	a1.Parent = shell
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1, tr.Lifetime, tr.LightEmission = a0, a1, 0.4, 1
	tr.Color = ColorSequence.new(hue)
	tr.WidthScale = seq({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	tr.Transparency = seq({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	tr.Parent = shell
	shell.Parent = bench
	local rise = TweenService:Create(
		shell,
		TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = CFrame.new(apex) }
	)
	rise:Play()
	rise.Completed:Connect(function()
		breakShell(apex, presetName, hue)
		shell:Destroy()
	end)
end

---------------------------------------------------------------- the run
local interval = nil -- nil == baseline step, fire nothing
local running = true
local order, i = { "peony", "willow" }, 0

task.spawn(function()
	while running do
		if interval then
			task.wait(interval)
			i += 1
			launch(order[(i % 2) + 1])
		else
			task.wait(0.2)
		end
	end
end)

task.spawn(function()
	while running do
		task.wait(0.25)
		local fps = readSample()
		head.Text = string.format(
			"%.0f fps\n%s",
			fps,
			interval and string.format("%.1f shells/sec", 1 / interval) or "BASELINE - no shells"
		)
	end
end)

task.wait(3) -- let the character spawn and the world stream in

local knee = nil
-- The baseline step is `false`, NOT nil. `table.insert(steps, nil)` is a silent no-op in Luau
-- (it assigns t[#t+1] = nil), which dropped the baseline row entirely on the 2026-08-05 A13 run —
-- the one number that run existed to capture. A false sentinel survives the array; nil does not.
local steps = { false }
do
	local iv = RAMP_START
	while true do
		table.insert(steps, iv)
		if iv <= RAMP_FLOOR then
			break
		end
		iv = math.max(RAMP_FLOOR, iv * RAMP_FACTOR)
	end
end

for _, step in ipairs(steps) do
	local iv = step or nil -- unwrap the false sentinel back to nil ("fire nothing")
	interval = iv
	task.wait(1.0) -- let the new rate reach steady state before sampling
	resetSample()
	task.wait(STEP_SECONDS)
	local avg, low = readSample()
	local label = iv and string.format("%4.1f/s", 1 / iv) or "  base"
	local color = Color3.fromRGB(150, 230, 150)
	if avg < KNEE_FPS then
		color = Color3.fromRGB(255, 120, 120)
		if not knee and iv then
			knee = 1 / iv
		end
	elseif avg < KNEE_FPS + 15 then
		color = Color3.fromRGB(255, 220, 120)
	end
	addRow(string.format("%s  avg %4.1f  min %4.1f", label, avg, low), color)
	print(string.format("[Bench] %s avg=%.1f min=%.1f", label, avg, low))
end

running = false
interval = nil
head.Text = knee and string.format("DONE\nknee: %.1f shells/sec", knee) or "DONE\nnever dropped below 30"
addRow("-- bench stopped --", Color3.fromRGB(160, 160, 255))
addRow("REMOVE PERF_BENCH_REMOVE_ME", Color3.fromRGB(255, 160, 160))
]==]
ls.Parent = sps

print(
    ("[FireworkBench] %s placed in StarterPlayerScripts (bloom: %s). Press Play (F5) to watch, or PUBLISH to measure on a device. Result prints ON SCREEN. SET REMOVE = true AND PUBLISH WHEN THE READING IS TAKEN."):format(
        BENCH_NAME,
        madeBloom and "created FireworkBloom" or ("reused existing " .. bloom.Name)
    )
)
