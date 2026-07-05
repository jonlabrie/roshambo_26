--!strict
-- Thin applier: plans the cliff support (PadPlanner) using the injected ground raycast,
-- builds each post via the injected ops, and returns the mount that A's StructureBuilder
-- consumes. ops is faked in tests (Lune) and implemented for real in the Studio demo /
-- runtime. Requiring the pure planner is fine (Lune-loadable).
local PadPlanner = require("./PadPlanner")

local PadBuilder = {}

export type PadSpec = { mountCF: { number }, hand: string, footprint: PadPlanner.Footprint }
export type Ops = {
    raycastGround: (number, number) -> number?,
    buildPost: ({ number }, number) -> (),
}
export type Mount = { cframe: { number }, hand: string, footprint: PadPlanner.Footprint }

function PadBuilder.build(padSpec: PadSpec, ops: Ops): Mount
    local support = PadPlanner.planSupport(padSpec.footprint, padSpec.mountCF, ops.raycastGround)
    for _, post in support.posts do
        ops.buildPost(post.pos, post.height)
    end
    return { cframe = padSpec.mountCF, hand = padSpec.hand, footprint = padSpec.footprint }
end

return PadBuilder
