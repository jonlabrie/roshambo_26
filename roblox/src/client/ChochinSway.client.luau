--!strict
-- Gentle pendulum sway for the teahouse and hanabiya chōchin. Each lantern's "Swing" sub-model
-- (tagged "ChochinSwing") rocks a few degrees on a slow sine, desynced per-site so a row of them
-- drifts independently — as if in a light breeze. Path-pole chōchin are excluded by owner ruling
-- (2026-09-03, see isPoleHung below) and never enter this system. Pure cosmetic; the swinging body
-- carries the RoundLantern glyph, which rides along.
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AmbientBudget = require(ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("AmbientBudget"))
local AmbientConfig = require(script.Parent:WaitForChild("AmbientConfig"))

local TAG = "ChochinSwing"
local AMP = math.rad(3.2) -- peak sway angle
local SPEED = 0.9 -- base angular frequency (rad/s) — period ~7s

type Entry = { model: Model, base: CFrame, phase: number, amp: number, speed: number }
local entries: { Entry } = {}

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

local acc = 0
RunService.Heartbeat:Connect(function(dt: number)
    local c = AmbientConfig.get()
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
