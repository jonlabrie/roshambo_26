--!strict
-- Runtime `ops` adapter for B's PadBuilder (injected in main.server.luau). Factory:
-- raycastGround needs the datum-plane Y (from mountCF) as its ray origin and buildPost
-- needs a parent, so both are baked at construction. Productionized verbatim from the
-- throwaway tools/studio/buildPadDemo.luau. Roblox datatypes -> not Lune-testable.
local CollectionService = game:GetService("CollectionService")

local PadOps = {}

local BLACK = Color3.fromRGB(45, 48, 56)

function PadOps.new(mountCF: CFrame, parent: Instance)
    return {
        raycastGround = function(x: number, z: number): number?
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Include
            rp.FilterDescendantsInstances = { workspace.Terrain }
            local hit =
                workspace:Raycast(Vector3.new(x, mountCF.Position.Y + 250, z), Vector3.new(0, -350, 0), rp)
            return hit and hit.Position.Y or nil
        end,
        -- a post lands on a path if any AccessKeepOut-tagged part sits in its column
        -- (between the deck top and terrain); omit it and cantilever the deck over the path.
        blockedByPath = function(x: number, z: number, topY: number, groundY: number): boolean
            local tagged = CollectionService:GetTagged("AccessKeepOut")
            local span = topY - groundY
            if #tagged == 0 or span <= 0 then
                return false
            end
            local rp = RaycastParams.new()
            rp.FilterType = Enum.RaycastFilterType.Include
            rp.FilterDescendantsInstances = tagged
            local hit = workspace:Raycast(Vector3.new(x, topY + 1, z), Vector3.new(0, -(span + 2), 0), rp)
            return hit ~= nil
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
