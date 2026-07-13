--!strict
-- Builds the whole hand-agnostic pad (deck slab + beam frame + engawa rail + terrain-dropped
-- posts) for a deck size, via injected ops (faked in Lune tests, real Roblox parts at runtime).
-- Requiring the pure planners/size math is fine (all Lune-loadable).
local PadPlanner = require("./PadPlanner")
local PadFrame = require("./PadFrame")
local SizeClasses = require("./SizeClasses")

local PadBuilder = {}

export type Ops = {
    raycastGround: (number, number) -> number?,
    buildPost: ({ number }, number) -> (),
    -- optional: true iff a post at (x, z) between topY and groundY would land on a keep-out
    -- path (AccessKeepOut). When provided, such posts are omitted and the deck cantilevers.
    blockedByPath: ((number, number, number, number) -> boolean)?,
}
-- The pad's outer edge, corner (x1,z1)->(x2,z2), with the inward unit normal (nx,nz) so the
-- railing seats its OUTER face flush to the deck edge (standing flush-outer-edges rule).
export type Edge = { x1: number, z1: number, x2: number, z2: number, nx: number, nz: number }
-- DeckOps adds the procedural deck geometry (Roblox parts) to the post ops. All coords are
-- LOCAL to the mount; the ops close over the mount CFrame (see PadOps.new).
export type DeckOps = Ops & {
    buildDeckSlab: (PadPlanner.Footprint) -> (),
    buildBeam: (PadFrame.Node, PadFrame.Node) -> (),
    buildRailing: (Edge) -> (),
}
export type Mount = { cframe: { number }, footprint: PadPlanner.Footprint }

-- Build the whole hand-agnostic pad for a deck size: symmetric slab, the 5-beam frame
-- (PadFrame), engawa railings on all 4 edges, and the 6 terrain-dropped posts. deckSize
-- sizes the FOOTPRINT (S/M/L via sqrt-area); railing height is FIXED in the ops (avatar
-- ergonomics), never scaled here. mountCF is the 12-number datum array (deck top = y=0).
-- Perimeter railing is built on all 4 edges for now; placement-driven openings (the open
-- engawa sides) arrive in Phase 3 when the building lands on the deck.
function PadBuilder.buildDeck(deckSize: string, mountCF: { number }, ops: DeckOps): Mount
    local fp = SizeClasses.deckFootprint(deckSize)
    ops.buildDeckSlab(fp)

    local nodes: { [string]: PadFrame.Node } = {}
    for _, n in PadFrame.nodes(fp) do
        nodes[n.id] = n
    end
    for _, beam in PadFrame.beams(fp) do
        ops.buildBeam(nodes[beam.from], nodes[beam.to])
    end

    local edges: { Edge } = {
        { x1 = fp.minX, z1 = fp.minZ, x2 = fp.maxX, z2 = fp.minZ, nx = 0, nz = 1 }, -- front (+Z inward)
        { x1 = fp.minX, z1 = fp.maxZ, x2 = fp.maxX, z2 = fp.maxZ, nx = 0, nz = -1 }, -- back
        { x1 = fp.minX, z1 = fp.minZ, x2 = fp.minX, z2 = fp.maxZ, nx = 1, nz = 0 }, -- left (+X inward)
        { x1 = fp.maxX, z1 = fp.minZ, x2 = fp.maxX, z2 = fp.maxZ, nx = -1, nz = 0 }, -- right
    }
    for _, edge in edges do
        ops.buildRailing(edge)
    end

    local support = PadPlanner.planSupport(fp, mountCF, ops.raycastGround, ops.blockedByPath)
    for _, post in support.posts do
        ops.buildPost(post.pos, post.height)
    end
    return { cframe = mountCF, footprint = fp }
end

return PadBuilder
