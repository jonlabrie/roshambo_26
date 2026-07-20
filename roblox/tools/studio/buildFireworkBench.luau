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
-- for glow (no per-shell lights), small sparks. Tune the KNOBS in the LocalScript to stress-test
-- fill-rate on device (lower LAUNCH_INTERVAL / raise the counts until the phone's FPS drops).

local Lighting = game:GetService("Lighting")
local StarterPlayer = game:GetService("StarterPlayer")
local sps = StarterPlayer:FindFirstChildOfClass("StarterPlayerScripts") or StarterPlayer:WaitForChild("StarterPlayerScripts")

-- idempotent clean
local oldLS = sps:FindFirstChild("FireworkLauncher")
if oldLS then oldLS:Destroy() end
local oldBloom = Lighting:FindFirstChild("FireworkBloom")
if oldBloom then oldBloom:Destroy() end

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
-- CLIENT-side firework (Emit only renders where it's called). TUNE to stress-test mobile fill-rate:
local LAUNCH_INTERVAL = 2.8      -- seconds between shells (LOWER = more concurrent load)
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
task.spawn(function()
	while bench.Parent do
		task.wait(LAUNCH_INTERVAL)
		i += 1
		launch(order[(i % 2) + 1])
	end
end)
]==]
ls.Parent = sps

print("[FireworkBench] LocalScript placed in StarterPlayerScripts + Bloom in Lighting. Press Play (F5) to watch; publish to view on device.")
