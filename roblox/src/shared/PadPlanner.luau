--!strict
-- Cliff-pad support planner: given the structure's frame footprint, the datum-plane
-- placement, and an injected ground-height function, emit the support-post specs the
-- PadBuilder materializes. Pure (Lune-tested); the ground lookup is a raycast at runtime
-- and a fake in tests. CFrames are 12-number arrays (Spec.cframe order); world = pos + R*local.
local PadPlanner = {}

export type Footprint = { minX: number, maxX: number, minZ: number, maxZ: number }
export type Post = { pos: { number }, height: number }
export type Support = { posts: { Post }, omitted: { string } }

local PH = 0.6 -- half of the 1.2-stud post (outer corner flush to the footprint corner)
local EMBED = 1.0 -- studs the post foot sinks into terrain

local function xf(cf: { number }, lx: number, ly: number, lz: number): { number }
    return {
        cf[1] + cf[4] * lx + cf[5] * ly + cf[6] * lz,
        cf[2] + cf[7] * lx + cf[8] * ly + cf[9] * lz,
        cf[3] + cf[10] * lx + cf[11] * ly + cf[12] * lz,
    }
end

function PadPlanner.planSupport(
    footprint: Footprint,
    mountCF: { number },
    groundAt: (number, number) -> number?
): Support
    local cx = (footprint.minX + footprint.maxX) / 2
    local layout = {
        { "FL", footprint.minX + PH, footprint.minZ + PH },
        { "FR", footprint.maxX - PH, footprint.minZ + PH },
        { "BL", footprint.minX + PH, footprint.maxZ - PH },
        { "BR", footprint.maxX - PH, footprint.maxZ - PH },
        { "MF", cx, footprint.minZ + PH },
        { "MB", cx, footprint.maxZ - PH },
    }
    local posts: { Post } = {}
    local omitted: { string } = {}
    for _, p in layout do
        local top = xf(mountCF, p[2] :: number, 0, p[3] :: number)
        local groundY = groundAt(top[1], top[3])
        if groundY == nil then
            table.insert(omitted, p[1] :: string)
        else
            local foot = groundY - EMBED
            table.insert(posts, {
                pos = { top[1], (top[2] + foot) / 2, top[3] },
                height = top[2] - foot,
            })
        end
    end
    return { posts = posts, omitted = omitted }
end

return PadPlanner
