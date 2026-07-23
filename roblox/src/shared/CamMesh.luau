--!strict
-- Smooth snail-cam mesh geometry, generated from CamProfile samples. PURE: emits a
-- vertex/normal/triangle description; the runtime (HammerController) assembles it
-- into an EditableMesh client-side (EditableMesh isn't available under Lune, and
-- server-created EditableMesh parts don't replicate — see the glyph/river lessons).
--
-- The cam lives in the part's LOCAL frame (CreateMeshPartAsync does not recentre —
-- build in local space, verts centred on the axle): local X = the axle, the spiral
-- in the local Y-Z plane, angle 0 = +Y (the cliff/peak, matching the controller's
-- anchor convention). Solid extrusion: top/bottom spiral faces (flat ±X normals),
-- a smooth-shaded rim wall following the flank, and the radial cliff face.
local CamProfile = require("./CamProfile")

local CamMesh = {}

export type Tri = { number } -- {i1, i2, i3} 1-based into verts
export type Mesh = {
    verts: { { number } }, -- {x, y, z} local-space positions
    normals: { { number } }, -- one per vert (rim verts get radial smooth normals)
    tris: { Tri },
}

-- Build the closed polar polygon: flank samples (descending local angle, ascending
-- radius) plus an inner cliff-foot point that drops the profile back to the hub.
local function polygon(g: CamProfile.Geom, n: number): { { number } }
    local pts = {}
    for _, s in CamProfile.samples(g, n) do
        table.insert(pts, { deg = s.deg, r = s.r })
    end
    -- cliff foot: straight radial drop at the release azimuth down to near the hub
    table.insert(pts, { deg = pts[#pts].deg - 0.5, r = math.max(g.gapZ * 0.55, 1.2) })
    return pts
end

function CamMesh.build(g: CamProfile.Geom, n: number, halfWidth: number): Mesh
    local pts = polygon(g, n)
    local verts: { { number } } = {}
    local normals: { { number } } = {}
    local tris: { Tri } = {}
    -- vertex layout: 1 = top centre, 2 = bottom centre, then per point k:
    -- top ring = 2 + 2k-1, bottom ring = 2 + 2k
    table.insert(verts, { halfWidth, 0, 0 })
    table.insert(normals, { 1, 0, 0 })
    table.insert(verts, { -halfWidth, 0, 0 })
    table.insert(normals, { -1, 0, 0 })
    for _, p in pts do
        local a = math.rad(p.deg)
        local y, z = math.cos(a) * p.r, math.sin(a) * p.r
        table.insert(verts, { halfWidth, y, z })
        table.insert(normals, { 0, math.cos(a), math.sin(a) }) -- smooth radial (rim)
        table.insert(verts, { -halfWidth, y, z })
        table.insert(normals, { 0, math.cos(a), math.sin(a) })
    end
    local function topIdx(k: number): number
        return 2 + 2 * k - 1
    end
    local function botIdx(k: number): number
        return 2 + 2 * k
    end
    local m = #pts
    for k = 1, m do
        local k2 = (k % m) + 1
        -- top fan (viewed from +X: wind so the face points +X)
        table.insert(tris, { 1, topIdx(k2), topIdx(k) })
        -- bottom fan (points -X)
        table.insert(tris, { 2, botIdx(k), botIdx(k2) })
        -- rim wall quad (outward)
        table.insert(tris, { topIdx(k), topIdx(k2), botIdx(k2) })
        table.insert(tris, { topIdx(k), botIdx(k2), botIdx(k) })
    end
    return { verts = verts, normals = normals, tris = tris }
end

return CamMesh
