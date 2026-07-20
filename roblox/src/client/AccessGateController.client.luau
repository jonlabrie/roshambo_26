--!strict
-- Renders the themed privacy gates for teahouse access control (2026-07-19). The server pushes
-- AccessBlocked with the exact gate specs (cframe + size) for every occupied pad THIS client is
-- blocked from (invite lists never reach the client). We build client-LOCAL parts (created on the
-- client, so they collide with the local character without any collision group) at those specs.
-- A re-push fully rebuilds; a pad no longer present (owner left, or we became allowed) loses its
-- gate. Placeholder noren art -> themed art pass later.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local remotes = ReplicatedStorage:WaitForChild("RoshamboRemotes")
local AccessBlocked = remotes:WaitForChild("AccessBlocked") :: RemoteEvent

-- A client-only container under workspace. A part created with Instance.new ON THE CLIENT and
-- parented to workspace exists only in THIS client's world (never replicated to the server or other
-- players) and DOES simulate locally — so it collides with the local character and no one else's.
-- (A PlayerGui parent would NOT simulate physics; it must be workspace.)
local folder = Instance.new("Folder")
folder.Name = "AccessGates"
folder.Parent = workspace

local NOREN = Color3.fromRGB(120, 40, 45) -- placeholder curtain color

local function buildGate(spec: any): Part?
    if typeof(spec) ~= "table" or typeof(spec.cframe) ~= "table" or typeof(spec.size) ~= "table" then
        return nil
    end
    local part = Instance.new("Part")
    part.Anchored = true
    part.CanCollide = true -- solid to the local character (client physics)
    part.CanQuery = false
    part.CanTouch = false
    part.Transparency = 0.35
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
    if typeof(blocked) ~= "table" then
        return
    end
    for _, entry in blocked do
        if typeof(entry) == "table" and typeof(entry.gates) == "table" then
            local padFolder = Instance.new("Folder")
            padFolder.Name = tostring(entry.padId)
            padFolder.Parent = folder
            for _, gspec in entry.gates do
                local gate = buildGate(gspec)
                if gate then
                    gate.Parent = padFolder
                end
            end
        end
    end
end

AccessBlocked.OnClientEvent:Connect(function(p)
    if typeof(p) == "table" then
        rebuild(p.blocked)
    end
end)
