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
local MAXPOST = 80 -- max stilt length; deeper ground reads as void (over-gorge)

local function xf(cf: { number }, lx: number, ly: number, lz: number): { number }
    return {
        cf[1] + cf[4] * lx + cf[5] * ly + cf[6] * lz,
        cf[2] + cf[7] * lx + cf[8] * ly + cf[9] * lz,
        cf[3] + cf[10] * lx + cf[11] * ly + cf[12] * lz,
    }
end

-- `blocked(worldX, worldZ, topY, groundY)` (optional): true iff a post at that corner
-- would land on a keep-out (a walkable AccessKeepOut path below the deck). Such a post is
-- omitted and the deck cantilevers there, exactly like a post over a void. Injected so the
-- module stays pure: the runtime implements it as a raycast against tagged path geometry;
-- tests pass a fake. Nil => no path omission (terrain-only planning).
function PadPlanner.planSupport(
    footprint: Footprint,
    mountCF: { number },
    groundAt: (number, number) -> number?,
    blocked: ((number, number, number, number) -> boolean)?
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
        -- build a post only where terrain sits BELOW the datum within reach (normal);
        -- omit corners embedded in the slope (ground >= datum) or over a void (nil / deeper than MAXPOST).
        if groundY == nil or groundY >= top[2] or (top[2] - groundY) > MAXPOST then
            table.insert(omitted, p[1] :: string)
        else
            -- groundY is a number here. Also omit a post that would land on a keep-out path
            -- (deck cantilevers over it) — same result as a void, so nest it to keep the two
            -- omit-reasons in distinct if-statements.
            if blocked ~= nil and blocked(top[1], top[3], top[2], groundY) then
                table.insert(omitted, p[1] :: string)
            else
                local foot = groundY - EMBED
                table.insert(posts, { pos = { top[1], (top[2] + foot) / 2, top[3] }, height = top[2] - foot })
            end
        end
    end
    return { posts = posts, omitted = omitted }
end

return PadPlanner
