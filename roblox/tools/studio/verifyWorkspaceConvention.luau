--!strict
-- PRE-PUBLISH GATE. Run in Studio (Edit) via MCP execute_luau BEFORE publishing the
-- place. Verifies the workspace matches the Rojo/place-only convention
-- (spec 2026-07-08-roblox-workspace-organization). Requires RoshamboShared synced
-- (rojo serve connected, or the last sync applied). Returns true on PASS.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorkspaceConvention = require(ReplicatedStorage.RoshamboShared.WorkspaceConvention)

local stage = workspace:FindFirstChild("RoshamboStage")
local stageChildren = {}
if stage then
    for _, child in stage:GetChildren() do
        table.insert(stageChildren, child.Name)
    end
end
local canyonWorld = workspace:FindFirstChild("CanyonWorld")
local arena = canyonWorld and canyonWorld:FindFirstChild("Arena")

local ok, failures = WorkspaceConvention.check({
    stageChildren = stageChildren,
    hasCanyonWorld = canyonWorld ~= nil,
    hasArena = arena ~= nil,
    arenaCount = if arena then #arena:GetChildren() else 0,
})

if ok then
    print("[convention] PASS — workspace matches the Rojo/place-only convention.")
else
    warn("[convention] FAIL:")
    for _, f in failures do
        warn("  - " .. f)
    end
end
return ok
