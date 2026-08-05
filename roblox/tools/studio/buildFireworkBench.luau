-- buildFireworkBench.luau — small firework VFX bench (2026-07-20, Roshambo Lens-B prototype)
--
-- HOW TO RUN: paste this whole file into the Studio command bar (View -> Command Bar) in EDIT mode
-- and press Enter. It places a LocalScript + a global Bloom but does NOT fire yet. Then press Play
-- (F5) to watch (fires near the local player). Publish the place to view on an iPhone. Re-running is
-- idempotent. REMOVE: delete StarterPlayer.StarterPlayerScripts.FireworkLauncher + Lighting.FireworkBloom.
--
-- HARD LESSONS BAKED IN (learned building this, 2026-07-20 — see the roshambo-fireworks memory):
--   1. ParticleEmitter:Emit() does NOT replicate server->client. A server-created Trail/part shows
--      (property-driven), but a server :Emit() burst is invisible to clients. Fireworks MUST be
--      client-emitted -> the launcher is a LocalScript in StarterPlayerScripts (runs per client),
--      NOT a server Script. (This is also the correct production architecture: client-side VFX.)
--   2. A ParticleEmitter with Texture == "" renders NOTHING. Always set a texture. The built-in
--      sparkle below is soft/fuzzy; the real fix for crisp sparks is a custom round-dot upload
--      (lower overdraw too). <-- next-session TODO.
--   3. Fire NEAR the player. First pass hardcoded world-origin (0,6,0) and showed nothing because
--      the player was ~110 studs up the canyon. This version launches relative to LocalPlayer.
--
-- MOBILE-PERF DESIGN: Trail ascent, ParticleEmitter :Emit burst, LightEmission=1 + ONE global Bloom
-- for glow (no per-shell lights), small sparks.
--
-- IT RAMPS ITSELF. Publish ONCE and run it: the launch rate starts easy and shortens every 15s,
-- printing each new rate to the developer console. Watch the in-app Performance Stats and note the
-- shells/sec at which sustained FPS crosses 30 — that is the number the fireworks director's budget
-- is derived from. No edit-publish-retry cycle, and the ramp is identical on every device, so a
-- second phone is directly comparable to the first.

local Lighting = game:GetService("Lighting")
local StarterPlayer = game:GetService("StarterPlayer")
local sps = StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts")
    or StarterPlayer:WaitForChild("StarterPlayerScripts")

-- idempotent clean
local oldLS = sps:FindFirstChild("FireworkLauncher")
if oldLS then
    oldLS:Destroy()
end
local oldBloom = Lighting:FindFirstChild("FireworkBloom")
if oldBloom then
    oldBloom:Destroy()
end

-- ONE global Bloom (gentle) makes LightEmission sparks glow at fixed cost; no per-shell lights.
local bloom = Instance.new("BloomEffect")
bloom.Name = "FireworkBloom"
bloom.Intensity = 0.55
bloom.Threshold = 0.9
bloom.Size = 14
bloom.Parent = Lighting

local ls = Instance.new("LocalScript")
ls.Name = "FireworkLauncher"
ls.Source = [==[
-- CLIENT-side firework (Emit only renders where it's called).
--
-- SELF-RAMPING: this bench does NOT need to be re-published to try a different rate. It starts at
-- RAMP_START seconds between shells and shortens the interval every RAMP_EVERY seconds until it
-- reaches RAMP_FLOOR, printing the current rate as it goes. Publish ONCE, open on the device, turn
-- on the in-app Performance Stats, and note the shells/sec at which sustained FPS crosses 30.
--
-- Why a ramp rather than a ladder of publishes: hand-stepping finds "the rung where it broke",
-- which is a lower bound with an unknown gap beneath it. A continuous ramp finds the knee, and it
-- is identical every run, so a second device is directly comparable to the first.
local RAMP_START = 3.0           -- seconds between shells at the easy end
local RAMP_FLOOR = 0.10          -- fastest rate the ramp will reach (10 shells/sec)
local RAMP_EVERY = 15            -- seconds at each rate before shortening
local RAMP_FACTOR = 0.75         -- each step multiplies the interval by this
local SPARK = "rbxasset://textures/particles/sparkles_main.dds" -- placeholder; swap a crisp round-dot upload

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local bench = Instance.new("Folder")
bench.Name = "FireworkBenchClient"
bench.Parent = Workspace

local function playerPos()
	local plr = Players.LocalPlayer
	local hrp = plr and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if hrp then return hrp.Position end
	local cam = Workspace.CurrentCamera
	return cam and cam.CFrame.Position or Vector3.new(0, 6, 0)
end

local function seq(a) return NumberSequence.new(a) end

local function emitter(parent, color, tail, sizeSeq, life, speed, accel, drag)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SPARK
	e.LightEmission, e.LightInfluence = 1, 0
	e.Color = ColorSequence.new(color, tail)
	e.Size = sizeSeq
	e.Transparency = seq({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.15), NumberSequenceKeypoint.new(1, 1) })
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
	Color3.fromRGB(255, 90, 80), Color3.fromRGB(90, 170, 255), Color3.fromRGB(120, 255, 140),
	Color3.fromRGB(255, 210, 90), Color3.fromRGB(230, 120, 255),
}
local PRESETS = {
	peony = {
		main = 520, glitter = 180,
		colorFn = function(hue) return hue, Color3.fromRGB(255, 240, 200) end,
		size = seq({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.7, 0.32), NumberSequenceKeypoint.new(1, 0) }),
		life = NumberRange.new(2.0, 2.9), speed = NumberRange.new(32, 46), accel = Vector3.new(0, -28, 0), drag = 2.5,
	},
	willow = {
		main = 380, glitter = 140,
		colorFn = function(_) return Color3.fromRGB(255, 214, 120), Color3.fromRGB(180, 40, 20) end,
		size = seq({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.85, 0.3), NumberSequenceKeypoint.new(1, 0) }),
		life = NumberRange.new(3.0, 3.9), speed = NumberRange.new(14, 22), accel = Vector3.new(0, -16, 0), drag = 1.8,
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
	emitter(part, Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 255, 255),
		seq({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 0) }), NumberRange.new(0.16, 0.16),
		NumberRange.new(0, 0), Vector3.new(), 0):Emit(1)
	-- main burst
	local c, t = P.colorFn(hue)
	emitter(part, c, t, P.size, P.life, P.speed, P.accel, P.drag):Emit(P.main)
	-- glitter / crackle
	emitter(part, Color3.fromRGB(255, 240, 210), Color3.fromRGB(255, 180, 90),
		seq({ NumberSequenceKeypoint.new(0, 0.16), NumberSequenceKeypoint.new(1, 0) }), NumberRange.new(0.3, 1.3),
		NumberRange.new(10, 26), Vector3.new(0, -20, 0), 3):Emit(P.glitter)
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
	local a0 = Instance.new("Attachment"); a0.Position = Vector3.new(0, -0.3, 0); a0.Parent = shell
	local a1 = Instance.new("Attachment"); a1.Position = Vector3.new(0, 0.3, 0); a1.Parent = shell
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1, tr.Lifetime, tr.LightEmission = a0, a1, 0.4, 1
	tr.Color = ColorSequence.new(hue)
	tr.WidthScale = seq({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
	tr.Transparency = seq({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	tr.Parent = shell
	shell.Parent = bench
	local rise = TweenService:Create(shell, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(apex) })
	rise:Play()
	rise.Completed:Connect(function()
		breakShell(apex, presetName, hue)
		shell:Destroy()
	end)
end

local order = { "peony", "willow" }
local i = 0
task.wait(1) -- let the character spawn
launch("peony")

-- THE RAMP. Two loops: one fires at the current interval, the other shortens it on a timer. The
-- rate is printed to the developer console (three-dot menu -> Developer Console on mobile) so the
-- number can be read off the device rather than guessed from a stopwatch.
local interval = RAMP_START
task.spawn(function()
	while bench.Parent do
		task.wait(RAMP_EVERY)
		if interval <= RAMP_FLOOR then
			print(string.format("[FireworkBench] FLOOR reached: %.2fs (%.1f shells/sec) — holding", interval, 1 / interval))
			break
		end
		interval = math.max(RAMP_FLOOR, interval * RAMP_FACTOR)
		print(string.format("[FireworkBench] now %.2fs between shells (%.1f shells/sec)", interval, 1 / interval))
	end
end)

task.spawn(function()
	while bench.Parent do
		task.wait(interval)
		i += 1
		launch(order[(i % 2) + 1])
	end
end)
]==]
ls.Parent = sps

print(
    "[FireworkBench] LocalScript placed in StarterPlayerScripts + Bloom in Lighting. Press Play (F5) to watch; publish to view on device."
)
