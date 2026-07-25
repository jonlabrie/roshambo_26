--!strict
-- Solid scalloped ripple disc for the karesansui boulder islands (v2). PURE:
-- emits a vertex/normal/triangle description; KaresansuiController assembles it
-- into an EditableMesh client-side (the CamMesh pattern).
--
-- v1 emitted separate ridge rings with gaps — the field's linear furrow texture
-- showed through and produced moire against the circles (gate finding). v2 is a
-- CONTINUOUS annular surface (vinyl-record scallops): valley at the stone edge,
-- alternating crests every pitch/2 radially, ending on a valley at the rim — the
-- field is fully covered under the disc. Bands are FLAT-SHADED (duplicated verts,
-- one hard normal per band) so every crest is a crisp V like the field's furrows.
-- Local space, centred on the island, XZ plane, valleys at y=0.
local RakingMesh = {}

export type Geom = {
    footprintR: number,
    maxR: number,
    pitch: number?, -- crest-to-crest spacing (radial)
    amplitude: number?, -- crest height above the valleys
    soft: number?, -- 0 = hard-faceted V crests, 1 = fully smooth; the happy medium
    -- lives between (band-edge normals blend toward their neighbour band's)
}

export type Sample = { r: number, h: number }

export type Tri = { number }
export type Mesh = {
    verts: { { number } },
    normals: { { number } },
    tris: { Tri },
}

-- Radial cross-section: samples every pitch/2 from the stone edge outward,
-- heights alternating valley (0) / crest (amplitude); trimmed to end on a valley.
function RakingMesh.profile(g: Geom): { Sample }
    local pitch = g.pitch or 0.35
    local amp = g.amplitude or 0.12
    local out: { Sample } = {}
    local k = 0
    while true do
        local r = g.footprintR + k * pitch / 2
        if r > g.maxR + 1e-9 then
            break
        end
        table.insert(out, { r = r, h = if k % 2 == 1 then amp else 0 })
        k += 1
    end
    if #out % 2 == 0 then
        table.remove(out) -- odd count = valley at both ends
    end
    return out
end

function RakingMesh.build(g: Geom, segments: number): Mesh
    local prof = RakingMesh.profile(g)
    local soft = g.soft or 0
    local verts: { { number } } = {}
    local normals: { { number } } = {}
    local tris: { Tri } = {}
    -- per-band flat normals in the radial plane: {nr, ny}
    local bandN: { { number } } = {}
    for b = 1, #prof - 1 do
        local a, c = prof[b], prof[b + 1]
        local dr, dh = c.r - a.r, c.h - a.h
        local len = math.sqrt(dr * dr + dh * dh)
        table.insert(bandN, { -dh / len, dr / len })
    end
    -- edge normal = band normal blended `soft` of the way toward the smoothed
    -- (neighbour-averaged) normal at that profile sample
    local function edgeN(b: number, sampleBand: number): (number, number)
        local own = bandN[b]
        local nb = bandN[sampleBand] or own
        local sr, sy = own[1] + nb[1], own[2] + nb[2]
        local sl = math.sqrt(sr * sr + sy * sy)
        sr, sy = sr / sl, sy / sl
        local r = own[1] + (sr - own[1]) * soft
        local y = own[2] + (sy - own[2]) * soft
        local l = math.sqrt(r * r + y * y)
        return r / l, y / l
    end
    for b = 1, #prof - 1 do
        local a, c = prof[b], prof[b + 1]
        local inR, inY = edgeN(b, b - 1) -- inner edge blends toward the previous band
        local outR, outY = edgeN(b, b + 1) -- outer edge blends toward the next band
        local base = #verts
        for s = 0, segments - 1 do
            local th = (s / segments) * 2 * math.pi
            local cs, sn = math.cos(th), math.sin(th)
            table.insert(verts, { cs * a.r, a.h, sn * a.r })
            table.insert(normals, { cs * inR, inY, sn * inR })
            table.insert(verts, { cs * c.r, c.h, sn * c.r })
            table.insert(normals, { cs * outR, outY, sn * outR })
        end
        for s = 0, segments - 1 do
            local s2 = (s + 1) % segments
            local i0 = base + s * 2 + 1
            local o0 = base + s * 2 + 2
            local i1 = base + s2 * 2 + 1
            local o1 = base + s2 * 2 + 2
            -- wound so faces point up/outward (verified: +Y cross components)
            table.insert(tris, { i0, o1, o0 })
            table.insert(tris, { i0, i1, o1 })
        end
    end
    return { verts = verts, normals = normals, tris = tris }
end

return RakingMesh
