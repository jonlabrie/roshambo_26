--!strict
-- Renders the themed privacy perimeter for teahouse access control (2026-07-19; proximity reveal
-- 2026-07-20). The server pushes AccessBlocked with, for every occupied pad THIS client is blocked
-- from, the four sealing-wall specs (cframe + size) plus the deck centre + revealRadius (invite
-- lists never reach the client). We build client-LOCAL parts (created on the client, so they collide
-- with the local character without any collision group) and, each frame, reveal + solidify a pad's
-- walls only while the local player is within revealRadius of that deck — so a blocked player isn't
-- surrounded by red walls across the whole map, and isn't obstructed walking past. The server region
-- backstop remains the always-on hard authority (this layer is the near-field warning + soft stop).
-- A re-push fully rebuilds; a pad no longer present (owner left, or we became allowed) loses its
-- perimeter. Placeholder noren art -> themed art pass later.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local localPlayer = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local AccessBlocked = remotes:WaitForChild("AccessBlocked") :: RemoteEvent
local AmbientBudget = require(ReplicatedStorage:WaitForChild("RoshamboShared"):WaitForChild("AmbientBudget"))

-- A client-only container under workspace. A part created with Instance.new ON THE CLIENT and
-- parented to workspace exists only in THIS client's world (never replicated to the server or other
-- players) and DOES simulate locally — so it collides with the local character and no one else's.
-- (A PlayerGui parent would NOT simulate physics; it must be workspace.)
local folder = Instance.new("Folder")
folder.Name = "AccessGates"
folder.Parent = workspace

local NOREN = Color3.fromRGB(120, 40, 45) -- placeholder curtain color
local SHOWN = 0.35 -- transparency when fully revealed
local FADE_RATE = 8 -- transparency lerp speed (~0.2s fade in/out)

type Pad = {
    parts: { Part },
    center: Vector3,
    radius: number,
    alpha: number,
    collidable: boolean,
    near: boolean,
}
local pads: { Pad } = {}

-- Built hidden + inert; the proximity loop turns it solid/visible when the player is near.
local function buildGate(spec: any): Part?
    if typeof(spec) ~= "table" or typeof(spec.cframe) ~= "table" or typeof(spec.size) ~= "table" then
        return nil
    end
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = false -- toggled on near the deck
    part.CanQuery = false
    part.CanTouch = false
    part.Transparency = 1 -- hidden until near
    part.Color = NOREN
    part.Material = Enum.Material.Fabric
    part.Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
    part.CFrame = CFrame.new(table.unpack(spec.cframe))
    return part
end

local function rebuild(blocked: any)
    for _, c in folder:GetChildren() do
        c:Destroy()
    end
    table.clear(pads)
    if typeof(blocked) ~= "table" then
        return
    end
    for _, entry in blocked do
        if
            typeof(entry) == "table"
            and typeof(entry.gates) == "table"
            and typeof(entry.center) == "table"
            and typeof(entry.revealRadius) == "number"
        then
            local padFolder = Instance.new("Folder")
            padFolder.Name = tostring(entry.padId)
            padFolder.Parent = folder
            local parts: { Part } = {}
            for _, gspec in entry.gates do
                local gate = buildGate(gspec)
                if gate then
                    gate.Parent = padFolder
                    table.insert(parts, gate)
                end
            end
            table.insert(pads, {
                parts = parts,
                center = Vector3.new(entry.center[1], entry.center[2], entry.center[3]),
                radius = entry.revealRadius,
                alpha = 1,
                collidable = false,
                near = false,
            })
        end
    end
end

-- Proximity reveal: planar (X/Z) distance from the deck centre, so an elevated deck approached from
-- a lower path still reveals correctly.
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
            -- collision snaps at the threshold (solid within a poll of entering range, not the
            -- instant you're in range -- this block is throttled); the visual fades.
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

AccessBlocked.OnClientEvent:Connect(function(p)
    if typeof(p) == "table" then
        rebuild(p.blocked)
    end
end)
