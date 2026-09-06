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

-- `rootOffset` is filled lazily the first time the server's weld shows up as a PrimaryPart; nil
-- means "not welded yet", which is also the signal to use the PivotTo path.
type Entry = {
    model: Model,
    base: CFrame,
    phase: number,
    amp: number,
    speed: number,
    rootOffset: CFrame?,
}
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
-- ⚠ AND IT MUST BE RE-TESTED EVERY TICK, NOT ONCE AT REGISTRATION. `PathLanterns` sits under
-- `CanyonWorld.Paths`, which `main.server.luau` leaves unpersisted so it streams normally -- and
-- under StreamingEnabled a Model tag-replicates BEFORE its siblings arrive. Asking for `CrossArm`
-- at registration therefore usually asks too early, gets nil, and files a path lantern as a swayer
-- for the rest of the session. That is exactly what shipped on 2026-09-04: the owner reported every
-- path lantern still swaying in the published place, while an Edit-mode check said all 38 were
-- excluded -- because Edit has no streaming and everything is already loaded, so that check could
-- only ever pass. `FoliageImpostorController`'s header carries the same warning for the same reason
-- ("models tag-replicate before their parts"); this file was written against that pattern and
-- missed its point. Resolve live; the check is one FindFirstChild against at most a few dozen
-- entries, which is nothing beside the PivotTo it decides.
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
    -- A cheap early-out for the case where the arm HAS already streamed in. A `false` here means
    -- "not known to be pole-hung yet", never "confirmed free to sway" -- the loop re-tests and
    -- evicts. See the warning on isPoleHung.
    if isPoleHung(m) then
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
    -- ⚠ BACKWARDS, because pole lanterns are evicted from this list as their CrossArm streams in
    -- and removing during a forward walk would skip the next entry. Most evictions happen in the
    -- first seconds after join, but a lantern that streams out and back is re-added by the tag
    -- signal and must be caught again -- so this runs for the life of the session, not just once.
    for i = #entries, 1, -1 do
        local e = entries[i]
        if isPoleHung(e.model) then
            table.remove(entries, i)
            continue
        end
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
        local swung = e.base * CFrame.Angles(a, 0, b)
        -- ONE WRITE when the server has welded this lantern into an assembly, ~58 when it has not.
        -- `PrimaryPart` is the server's signal that the weld happened (AssemblyWeld.bindModel sets
        -- it); resolved live rather than cached at registration, because the model replicates
        -- before that property does and a lantern that streams in unwelded must pick the fast path
        -- up when it lands.
        --
        -- ⚠ THE FALLBACK IS NOT DEAD CODE. PivotTo is correct precisely while PrimaryPart is nil,
        -- i.e. while nothing is welded. Once parts ARE welded and unanchored, writing all of their
        -- CFrames individually fights the constraints, so the two paths must never be mixed.
        local root = e.model.PrimaryPart
        if root then
            -- The root's offset FROM THE PIVOT is invariant under PivotTo, so it can be taken at
            -- any pose and cached -- reading it from the model's CURRENT pivot rather than from
            -- `base` is what makes that true. Deriving it from `base` and the live root CFrame
            -- instead would be self-referential: the root has already been swung.
            local off = e.rootOffset
            if off == nil then
                off = e.model:GetPivot():ToObjectSpace(root.CFrame)
                e.rootOffset = off
            end
            root.CFrame = swung * (off :: CFrame)
        else
            e.model:PivotTo(swung)
        end
    end
end)
