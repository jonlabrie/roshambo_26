--!strict
-- Runtime `ops` adapter for B's PadBuilder (injected in main.server.luau). Factory:
-- raycastGround needs the datum-plane Y (from mountCF) as its ray origin and buildPost
-- needs a parent, so both are baked at construction. Productionized verbatim from the
-- throwaway tools/studio/buildPadDemo.luau. Roblox datatypes -> not Lune-testable.
local PadOps = {}

local BLACK = Color3.fromRGB(45, 48, 56)

function PadOps.new(mountCF: CFrame, parent: Instance)
    return {
        raycastGround = function(x: number, z: number): number?
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Include
            rp.FilterDescendantsInstances = { workspace.Terrain }
            local hit =
                workspace:Raycast(Vector3.new(x, mountCF.Position.Y + 4, z), Vector3.new(0, -600, 0), rp)
            return hit and hit.Position.Y or nil
        end,
        buildPost = function(pos: { number }, height: number)
            local p = Instance.new("Part")
            p.Name, p.Anchored, p.CanCollide, p.CastShadow = "PadPost", true, false, false
            p.Size = Vector3.new(1.2, height, 1.2)
            p.Color = BLACK
            p.Material = Enum.Material.Wood
            p.CFrame = CFrame.new(pos[1], pos[2], pos[3])
            p.Parent = parent
        end,
    }
end

return PadOps
