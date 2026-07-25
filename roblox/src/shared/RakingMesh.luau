--!strict
-- Concentric ripple-ridge geometry for the raked-sand rings around zen-garden
-- boulder islands. PURE: emits a vertex/normal/triangle description; the runtime
-- (a client controller) assembles it into an EditableMesh (EditableMesh isn't
-- available under Lune, and server-created EditableMesh parts don't replicate —
-- see the glyph/river lessons).
--
-- Local frame: XZ plane (Y up), centred on the island. Each concentric ring is a
-- triangular ridge cross-section — inner foot at y=0, crest at y=amplitude, outer
-- foot at y=0 — swept around `segments` points.

local RakingMesh = {}

export type Geom = {
    footprintR: number,
    maxR: number,
    pitch: number?,
    amplitude: number?,
    ridgeW: number?,
}

export type Tri = { number } -- {i1, i2, i3} 1-based into verts
export type Mesh = {
    verts: { { number } }, -- {x, y, z} local-space positions
    normals: { { number } }, -- one per vert
    tris: { Tri },
}

local DEFAULT_PITCH = 0.8
local DEFAULT_AMPLITUDE = 0.15
local DEFAULT_RIDGE_W = 0.5

-- Ring center radii: first at footprintR + pitch/2, stepping by pitch, kept while
-- the ridge's outer foot still fits inside maxR.
function RakingMesh.ringRadii(g: Geom): { number }
    local pitch = g.pitch or DEFAULT_PITCH
    local ridgeW = g.ridgeW or DEFAULT_RIDGE_W
    local radii: { number } = {}
    local r = g.footprintR + pitch / 2
    while r + ridgeW / 2 <= g.maxR do
        table.insert(radii, r)
        r += pitch
    end
    return radii
end

function RakingMesh.build(g: Geom, segments: number): Mesh
    local amplitude = g.amplitude or DEFAULT_AMPLITUDE
    local ridgeW = g.ridgeW or DEFAULT_RIDGE_W
    local radii = RakingMesh.ringRadii(g)

    local verts: { { number } } = {}
    local normals: { { number } } = {}
    local tris: { Tri } = {}

    -- ridge-face normal blend: unit vectors tilted between radial-out and up
    local hyp = math.sqrt(amplitude ^ 2 + (ridgeW / 2) ^ 2)
    local a = amplitude / hyp
    local b = (ridgeW / 2) / hyp

    -- per ring: 3 circles (inner foot, crest, outer foot), `segments` verts each,
    -- laid out contiguously so ring base index + circle offset + segment gives
    -- the vert index.
    for _, r in radii do
        for k = 1, segments do
            local theta = (k - 1) * 2 * math.pi / segments
            local cosT, sinT = math.cos(theta), math.sin(theta)

            -- inner foot
            table.insert(verts, { (r - ridgeW / 2) * cosT, 0, (r - ridgeW / 2) * sinT })
            table.insert(normals, { -cosT * a, b, -sinT * a })

            -- crest
            table.insert(verts, { r * cosT, amplitude, r * sinT })
            table.insert(normals, { 0, 1, 0 })

            -- outer foot
            table.insert(verts, { (r + ridgeW / 2) * cosT, 0, (r + ridgeW / 2) * sinT })
            table.insert(normals, { cosT * a, b, sinT * a })
        end
    end

    local function innerIdx(ring: number, k: number): number
        return (ring - 1) * segments * 3 + (k - 1) * 3 + 1
    end
    local function crestIdx(ring: number, k: number): number
        return (ring - 1) * segments * 3 + (k - 1) * 3 + 2
    end
    local function outerIdx(ring: number, k: number): number
        return (ring - 1) * segments * 3 + (k - 1) * 3 + 3
    end

    for ring = 1, #radii do
        for k = 1, segments do
            local k2 = (k % segments) + 1

            -- inner -> crest strip (faces up/inward-facing-out): wind so normal
            -- points +Y-ish, matching the inner-foot/crest normals above.
            table.insert(tris, { innerIdx(ring, k), innerIdx(ring, k2), crestIdx(ring, k2) })
            table.insert(tris, { innerIdx(ring, k), crestIdx(ring, k2), crestIdx(ring, k) })

            -- crest -> outer strip
            table.insert(tris, { crestIdx(ring, k), outerIdx(ring, k2), outerIdx(ring, k) })
            table.insert(tris, { crestIdx(ring, k), crestIdx(ring, k2), outerIdx(ring, k2) })
        end
    end

    return { verts = verts, normals = normals, tris = tris }
end

return RakingMesh
