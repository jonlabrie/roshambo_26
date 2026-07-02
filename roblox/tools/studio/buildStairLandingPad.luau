-- buildStairLandingPad.luau — angled landing pad ("section of deck squared up to
-- the path") receiving the NW1012 ishidan stairway at the Overlook's lamp-newel
-- corner. Rotated to the stair's final heading; joins the deck's west edge plane
-- with an oblique seam filled by heading-parallel planks (per-plank length cut to
-- the plane — real decking reads). Overlook vocabulary: WoodPlanks slab, 1.5-sq
-- posts (terrain-surveyed feet), KŌRAN rail with BLACK top cap (deck style since
-- 519c963) on the downhill/open edges only. Idempotent: destroys + rebuilds.
-- Frame BAKED from bakeNW1012Stairway.luau (2026-07-02) — no live marker reads.
-- Spec: docs/superpowers/specs/2026-07-01-zendojo-nw1012-ishidan-stairway-design.md
local PAD = {
    center = { 52.71, 41.86 },
    heading = { 0.823, -0.569 }, -- unit XZ, stair travel direction (into the deck)
    perp = { 0.569, 0.823 }, -- unit XZ, +perp = uphill / lamp-newel side
    topY = 113.3,
    wCross = 7.5,
    dAlong = 5.0,
    deckEdgeX = 57.0,
    deckColor = Color3.fromRGB(107, 79, 51),
}
local OUT_NAME = "OverlookStairPad"

local h = Vector3.new(PAD.heading[1], 0, PAD.heading[2])
local p = Vector3.new(PAD.perp[1], 0, PAD.perp[2])
local C = Vector3.new(PAD.center[1], 0, PAD.center[2])
local topY = PAD.topY
local halfW, halfD = PAD.wCross / 2, PAD.dAlong / 2

local parentModel = workspace.RoshamboStage
local old = parentModel:FindFirstChild(OUT_NAME)
if old then
    old:Destroy()
end
local model = Instance.new("Model")
model.Name = OUT_NAME
model.Parent = parentModel

local function part(name: string, size: Vector3, cf: CFrame, material: Enum.Material, color: Color3): Part
    local q = Instance.new("Part")
    q.Name = name
    q.Anchored = true
    q.Size = size
    q.CFrame = cf
    q.Material = material
    q.Color = color
    q.TopSurface = Enum.SurfaceType.Smooth
    q.BottomSurface = Enum.SurfaceType.Smooth
    q.Parent = model
    return q
end

-- pad frame CFrame helper: X = perp (cross), Z-ish = heading
local function padCf(alongH: number, alongP: number, y: number): CFrame
    local pos = C + h * alongH + p * alongP
    return CFrame.fromMatrix(Vector3.new(pos.X, y, pos.Z), p, Vector3.yAxis)
end

-- terrain raycast for post feet
local rcParams = RaycastParams.new()
rcParams.FilterType = Enum.RaycastFilterType.Include
rcParams.FilterDescendantsInstances = { workspace.Terrain }
local function groundY(alongH: number, alongP: number): number
    -- cast from WELL above: a ray that starts under the smooth-terrain surface
    -- (mesher bulge) returns nil instead of hitting it (bit us 2026-07-02)
    local q = C + h * alongH + p * alongP
    local hit = workspace:Raycast(Vector3.new(q.X, topY + 12, q.Z), Vector3.new(0, -60, 0), rcParams)
    return hit and hit.Position.Y or topY - 8
end

---------------------------------------------------------------- slab
part(
    "Slab",
    Vector3.new(PAD.wCross, 0.6, PAD.dAlong),
    padCf(0, 0, topY - 0.3),
    Enum.Material.WoodPlanks,
    PAD.deckColor
)

---------------------------------------------------------------- seam infill planks
-- planks run along +heading from the slab's deck-side edge to the plane X = deckEdgeX
local PLANK_W = 1.07 -- 7 planks across 7.5
local nPlanks = 7
for k = 1, nPlanks do
    local ck = -halfW + PLANK_W * (k - 0.5)
    local edge = C + h * halfD + p * ck -- slab deck-side edge at this cross offset
    -- key the length to the plank's FAR +perp corner (not its centerline) so no
    -- corner crosses the deck plane and z-fights the deck top
    local len = (PAD.deckEdgeX - 0.05 - edge.X - (PLANK_W / 2) * p.X) / h.X
    if len > 0.15 then
        part(
            "SeamPlank_" .. k,
            Vector3.new(PLANK_W - 0.03, 0.6, len),
            padCf(halfD + len / 2, ck, topY - 0.3),
            Enum.Material.WoodPlanks,
            PAD.deckColor
        )
    end
end

---------------------------------------------------------------- girders
part(
    "GirderP1",
    Vector3.new(1.2, 0.825, PAD.dAlong),
    padCf(0, halfW - 0.6, topY - 0.6 - 0.4125),
    Enum.Material.Wood,
    PAD.deckColor
)
part(
    "GirderP2",
    Vector3.new(1.2, 0.825, PAD.dAlong),
    padCf(0, -(halfW - 0.6), topY - 0.6 - 0.4125),
    Enum.Material.Wood,
    PAD.deckColor
)
part(
    "GirderX",
    Vector3.new(PAD.wCross, 0.825, 1.2),
    padCf(0, 0, topY - 0.6 - 0.4125),
    Enum.Material.Wood,
    PAD.deckColor
)

---------------------------------------------------------------- posts (1.5 sq, outer faces flush with slab edges)
local POST = 1.5
local postSpots = {
    { -halfD + POST / 2, halfW - POST / 2, "PostA" }, -- outer uphill corner (stair side)
    { -halfD + POST / 2, -(halfW - POST / 2), "PostB" }, -- outer downhill corner
    { halfD - POST / 2, -(halfW - POST / 2), "PostC" }, -- deck-side downhill corner
}
for _, s in postSpots do
    local gy = groundY(s[1], s[2])
    local hgt = (topY - 0.6) - (gy - 1)
    part(
        s[3],
        Vector3.new(POST, hgt, POST),
        padCf(s[1], s[2], gy - 1 + hgt / 2),
        Enum.Material.Wood,
        PAD.deckColor
    )
end

-- (KŌRAN railing + fall barrier removed at the 2026-07-02 gate: "ugly and
-- unneeded" — the pad is a low landing beside grade, not an exposed deck edge.)

---------------------------------------------------------------- seam wedges
-- Each plank's far end is a square cut keyed to its +perp corner, which leaves a
-- plan-view right triangle (legs: plank width along perp × plankW·p.X/h.X along
-- heading) between the plank end and the deck plane. Fill each with a WedgePart
-- turned so its triangular cross-section lies horizontal: frame (X=down, Y=perp,
-- Z=-heading) is right-handed and puts the wedge's right-angle edge at the
-- plank's -perp end corner with the hypotenuse along the deck plane.
local GAP_H = PLANK_W * p.X / h.X -- heading-leg of the triangle
for k = 1, nPlanks do
    local ck = -halfW + PLANK_W * (k - 0.5)
    local edge = C + h * halfD + p * ck
    local len = (PAD.deckEdgeX - 0.05 - edge.X - (PLANK_W / 2) * p.X) / h.X
    if len > 0.15 then
        local wedge = Instance.new("WedgePart")
        wedge.Name = "SeamWedge_" .. k
        wedge.Anchored = true
        wedge.Material = Enum.Material.WoodPlanks
        wedge.Color = PAD.deckColor
        wedge.Size = Vector3.new(0.6, PLANK_W - 0.03, GAP_H)
        local pos = C + h * (halfD + len + GAP_H / 2) + p * ck
        wedge.CFrame = CFrame.fromMatrix(Vector3.new(pos.X, topY - 0.3, pos.Z), Vector3.new(0, -1, 0), p, -h)
        wedge.TopSurface = Enum.SurfaceType.Smooth
        wedge.BottomSurface = Enum.SurfaceType.Smooth
        wedge.Parent = model
    end
end

print(("OverlookStairPad built: %d parts"):format(#model:GetChildren()))
