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

local function add(m: Instance)
    if not m:IsA("Model") then
        return
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
