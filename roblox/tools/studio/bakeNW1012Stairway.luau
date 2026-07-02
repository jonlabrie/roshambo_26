-- bakeNW1012Stairway.luau — one-shot survey for the NW1012 ishidan stairway.
-- Run in Studio (Edit) BEFORE the old NW1012Path is retired; paste the printed
-- literals into buildIshidanStairs.luau CONFIG and buildStairLandingPad.luau
-- CONFIG, and record them in the spec's As-built section.
-- Requires live: Workspace.NW1012Path.NW1012Timber_1..23,
-- Workspace.PathDraft.NW10Foot.Marker_1..3, Workspace.PathDraft.NearWall_10,
-- Workspace.RoshamboStage.Overlook (UpperDeck + NewelUpperDeck4).
-- Spec: docs/superpowers/specs/2026-07-01-zendojo-nw1012-ishidan-stairway-design.md
local out = {}
local function v3(v: Vector3): string
    return string.format("        { %.2f, %.2f, %.2f },", v.X, v.Y, v.Z)
end

local nw10 = workspace.PathDraft.NearWall_10.Position
local m1 = workspace.PathDraft.NW10Foot.Marker_1.Position
local m2 = workspace.PathDraft.NW10Foot.Marker_2.Position
local deck = workspace.RoshamboStage.Overlook.UpperDeck
local deckEdgeX = deck.Position.X - deck.Size.X / 2

-- Pad frame: the pad is rotated square to the stair's final heading and tucked
-- against the deck's west edge plane (X = deckEdgeX); ALL pad corners stay on
-- the outside of that plane (seam infill planks fill the oblique gap). The
-- stair's foot is the pad's uphill (stair-side) edge midpoint.
local h = (Vector3.new(nw10.X, 0, nw10.Z) - Vector3.new(m2.X, 0, m2.Z)).Unit
local p = Vector3.new(-h.Z, 0, h.X)
local newel = workspace.RoshamboStage.Overlook.NewelUpperDeck4.Position
if Vector3.new(newel.X - nw10.X, 0, newel.Z - nw10.Z):Dot(p) < 0 then
    p = -p -- +perp = uphill / lamp-newel side
end
local W, D, CLR = 7.5, 5.0, 0.1
local tEdge = (deckEdgeX - nw10.X) / h.X
local C = nw10 + h * tEdge
local cX = deckEdgeX - CLR - h.X * (D / 2) - math.abs(p.X) * (W / 2)
local center = C - h * ((C.X - cX) / h.X)
local foot = center - h * (D / 2)

table.insert(out, "control = {")
table.insert(out, "    -- stair foot = pad stair-side edge midpoint (pad top level)")
table.insert(out, v3(Vector3.new(foot.X, 113.3, foot.Z)))
table.insert(out, "    -- foot marker (terrain Y - 1; interior Y only shapes flight-boundary grades)")
table.insert(out, v3(Vector3.new(m1.X, m1.Y - 1.0, m1.Z)))
table.insert(out, "    -- old timber centers (tread grade)")
for i = 1, 23 do
    local t = workspace.NW1012Path:FindFirstChild("NW1012Timber_" .. i) :: BasePart
    table.insert(out, v3(Vector3.new(t.Position.X, t.Position.Y + t.Size.Y / 2, t.Position.Z)))
end
table.insert(out, "}")
table.insert(
    out,
    string.format(
        "PAD = { center = {%.2f, %.2f}, heading = {%.3f, %.3f}, perp = {%.3f, %.3f}, topY = %.2f,"
            .. " wCross = %.1f, dAlong = %.1f, deckEdgeX = %.1f, deckColor = {%d, %d, %d} }",
        center.X,
        center.Z,
        h.X,
        h.Z,
        p.X,
        p.Z,
        deck.Position.Y + deck.Size.Y / 2,
        W,
        D,
        deckEdgeX,
        math.floor(deck.Color.R * 255 + 0.5),
        math.floor(deck.Color.G * 255 + 0.5),
        math.floor(deck.Color.B * 255 + 0.5)
    )
)
print(table.concat(out, "\n"))
