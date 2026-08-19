--!strict
-- Gentle pendulum sway for the hanging path chōchin. Each lantern's "Swing" sub-model
-- (tagged "ChochinSwing", pivoted at its cross-arm hang point) rocks a few degrees on a
-- slow sine, desynced per-site so a row of them drifts independently — as if in a light
-- breeze. Pure cosmetic; the swinging body carries the RoundLantern glyph, which rides along.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local TAG = "ChochinSwing"
local AMP = math.rad(3.2) -- peak sway angle
local SPEED = 0.9 -- base angular frequency (rad/s) — period ~7s

type Entry = { model: Model, base: CFrame, phase: number, amp: number, speed: number }
local entries: { Entry } = {}

-- ⚠ THE HANG POINT IS DERIVED FROM THE CROSS-ARM, NOT READ FROM THE STORED PIVOT.
--
-- `buildChochinPole` sets `swing.WorldPivot` to the hang point when it stamps a lantern, and that
-- was trusted here. But the pivot is PLACE DATA and the geometry is BUILDER data, so the two drift
-- the moment the builder changes: the poles were shortened (`armY = base.Y + poleH - 0.5`) and
-- every already-stamped lantern kept the pivot the taller pole had given it -- 3.4 studs up in the
-- air. They then swung about a point ABOVE the crosspiece instead of hanging from it, which at
-- AMP reads as the chochin floating a couple of inches off the end of the arm.
--
-- Deriving it from the sibling `CrossArm` makes that class of drift impossible: the arm IS what
-- the lantern hangs from, so a resize moves both together by construction. Falls back to the
-- stored pivot when there is no arm -- the teahouse and hanabiya chochin hang differently.
local function hangPointFor(m: Model): CFrame?
    local arm = m.Parent and m.Parent:FindFirstChild("CrossArm")
    if not (arm and arm:IsA("BasePart")) then
        return nil
    end
    local centre = m:GetBoundingBox().Position
    -- the cross-arm's long axis is local X; the lantern hangs from whichever end it sits under
    local a = (arm.CFrame * CFrame.new(arm.Size.X / 2, 0, 0)).Position
    local b = (arm.CFrame * CFrame.new(-arm.Size.X / 2, 0, 0)).Position
    local far = if (a - centre).Magnitude < (b - centre).Magnitude then a else b
    return CFrame.new(far)
end

local function add(m: Instance)
    if not m:IsA("Model") then
        return
    end
    for _, e in entries do
        if e.model == m then
            return
        end
    end
    -- Setting WorldPivot does NOT move geometry -- it only says what the model turns about, which
    -- is exactly what the PivotTo below needs to be right.
    local derived = hangPointFor(m)
    if derived then
        m.WorldPivot = derived
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

for _, m in CollectionService:GetTagged(TAG) do
    add(m)
end
CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(m)
    for i, e in entries do
        if e.model == m then
            table.remove(entries, i)
            break
        end
    end
end)

RunService.Heartbeat:Connect(function()
    local t = os.clock()
    for _, e in entries do
        local a = e.amp * math.sin(t * e.speed + e.phase)
        local b = e.amp * 0.45 * math.sin(t * e.speed * 0.7 + e.phase * 1.3) -- subtle cross-axis drift
        e.model:PivotTo(e.base * CFrame.Angles(a, 0, b))
    end
end)
