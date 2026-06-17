--!strict
-- Continuously spins the waterwheels. The creek always flows, so the wheels never
-- stop — they kept turning through the round before, then froze on the lockout
-- "ratchet", which read wrong (a live stream with stalled wheels). The striker's
-- draw/latch is driven by the clock (HammerCurve), not the wheel's real rotation,
-- so the two are decoupled and the wheels just turn forever.
local RunService = game:GetService("RunService")

local stage = workspace:WaitForChild("RoshamboStage")
local rig = stage:WaitForChild("Waterwheel")

-- Asakura cluster: spin every Wheel{n} about its own axle, with its paddles.
type Spin = { part: BasePart, hub: CFrame, paddles: { BasePart }, offsets: { CFrame } }
local spins: { Spin } = {}
for _, child in rig:GetChildren() do
    local wi = child.Name:match("^Wheel(%d+)$")
    if wi then
        local wheel = child :: BasePart
        local s: Spin = { part = wheel, hub = wheel.CFrame, paddles = {}, offsets = {} }
        for _, p in rig:GetChildren() do
            if p.Name:match(`^Paddle{wi}_%d+$`) then
                table.insert(s.paddles, p :: BasePart)
                table.insert(s.offsets, wheel.CFrame:ToObjectSpace((p :: BasePart).CFrame))
            end
        end
        table.insert(spins, s)
    end
end

-- Undershot: the lower paddles churn through the river current at the waterline.
local driver = rig:FindFirstChild("Wheel1") :: BasePart?
local fall = Instance.new("ParticleEmitter")
fall.Color = ColorSequence.new(Color3.fromRGB(210, 222, 228))
fall.Size = NumberSequence.new(0.5, 1.1)
fall.Transparency = NumberSequence.new(0.5)
fall.Lifetime = NumberRange.new(0.3, 0.5)
fall.Rate = 30 -- churning spray where the paddles meet the current
fall.Speed = NumberRange.new(3, 5)
fall.SpreadAngle = Vector2.new(40, 40)
if driver then
    local sink = Instance.new("Attachment")
    sink.Position = Vector3.new(0, -driver.Size.Y / 2, 0) -- the wheel bottom
    sink.Parent = driver
    fall.Parent = sink
end

local angle = 0
local FALLBACK_OMEGA = 0.5 -- rad/s until HammerController publishes the real shaft rate (signed for WHEEL_DIR below)
local WHEEL_DIR = -1 -- maps the published shaft ω onto the wheel's local axle (live-tunable "WheelDir")

RunService.Heartbeat:Connect(function(dt)
    -- The wheel IS the driver gear's shaft, so it turns at the EXACT angular velocity the
    -- bell-engine drive publishes ("DriveOmega", rad/s about Z) — matched rate + direction,
    -- not a free constant that out-runs the gears. WHEEL_DIR corrects the wheel's local axle
    -- orientation; flip it (or "DriverDir") live to fix the spin direction.
    local driveOmega = (stage:GetAttribute("DriveOmega") :: number) or FALLBACK_OMEGA
    local wheelDir = (stage:GetAttribute("WheelDir") :: number) or WHEEL_DIR
    angle += dt * driveOmega * wheelDir
    for _, s in spins do
        local spun = s.hub * CFrame.Angles(angle, 0, 0)
        s.part.CFrame = spun
        for i, p in s.paddles do
            p.CFrame = spun * s.offsets[i]
        end
    end
end)
