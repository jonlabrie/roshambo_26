--!strict
-- Pure site-fit geometry for the D.6 perch survey (Lune-tested). Footprints and
-- keep-outs are yaw-oriented rectangles in world XZ. Basic ops only (no trig) so
-- output is CPU-arch-stable. Nothing consumes this yet — the Studio survey (a later
-- increment) produces the keep-outs and calls spacingMax / isLevel / normalizeYaw.
local SizeClasses = require("./SizeClasses")

local PadSiteFit = {}

export type Point = { number } -- {x, z}
export type OBB = { Point } -- 4 corners, consistent winding

-- world XZ of local (lx, lz) under the 12-number mountCF (world = R*local + pos)
local function xz(cf: { number }, lx: number, lz: number): Point
    return {
        cf[1] + cf[4] * lx + cf[6] * lz,
        cf[3] + cf[10] * lx + cf[12] * lz,
    }
end

function PadSiteFit.footprintOBB(footprint: SizeClasses.Footprint, mountCF: { number }): OBB
    local f = footprint
    return {
        xz(mountCF, f.minX, f.minZ),
        xz(mountCF, f.maxX, f.minZ),
        xz(mountCF, f.maxX, f.maxZ),
        xz(mountCF, f.minX, f.maxZ),
    }
end

-- the 2 unique edge normals of a rectangle (opposite edges are parallel)
local function axesOf(box: OBB): { Point }
    local out: { Point } = {}
    for i = 1, 2 do
        local a, b = box[i], box[i % 4 + 1]
        out[i] = { -(b[2] - a[2]), b[1] - a[1] } -- normal of edge a->b
    end
    return out
end

local function separated(a: OBB, b: OBB, axis: Point): boolean
    local amn, amx, bmn, bmx
    for _, p in a do
        local d = p[1] * axis[1] + p[2] * axis[2]
        amn = if amn == nil or d < amn then d else amn
        amx = if amx == nil or d > amx then d else amx
    end
    for _, p in b do
        local d = p[1] * axis[1] + p[2] * axis[2]
        bmn = if bmn == nil or d < bmn then d else bmn
        bmx = if bmx == nil or d > bmx then d else bmx
    end
    return (amx :: number) < (bmn :: number) or (bmx :: number) < (amn :: number)
end

function PadSiteFit.overlaps(a: OBB, b: OBB): boolean
    for _, axis in axesOf(a) do
        if separated(a, b, axis) then
            return false
        end
    end
    for _, axis in axesOf(b) do
        if separated(a, b, axis) then
            return false
        end
    end
    return true
end

function PadSiteFit.spacingMax(mountCF: { number }, keepOuts: { OBB }): string?
    for _, size in SizeClasses.order do
        local obb = PadSiteFit.footprintOBB(SizeClasses.footprintFor(size), mountCF)
        local clear = true
        for _, k in keepOuts do
            if PadSiteFit.overlaps(obb, k) then
                clear = false
                break
            end
        end
        if clear then
            return size
        end
    end
    return nil
end

function PadSiteFit.isLevel(mountCF: { number }, tol: number): boolean
    return math.abs(mountCF[7]) < tol and math.abs(mountCF[9]) < tol and math.abs(mountCF[8] - 1) < tol
end

function PadSiteFit.normalizeYaw(mountCF: { number }): { number }
    -- project the mount's local-X world image onto XZ, renormalize (sqrt/div, no trig),
    -- rebuild a pure-yaw orthonormal rotation: X=(ex,0,ez), Y=(0,1,0), Z = X x Y = (-ez,0,ex).
    local fx, fz = mountCF[4], mountCF[10]
    local len = math.sqrt(fx * fx + fz * fz)
    local ex, ez = fx / len, fz / len
    return {
        mountCF[1],
        mountCF[2],
        mountCF[3],
        ex,
        0,
        -ez,
        0,
        1,
        0,
        ez,
        0,
        ex,
    }
end

function PadSiteFit.resolveMaxSize(a: string, b: string): string
    return if SizeClasses.rank[a] <= SizeClasses.rank[b] then a else b
end

return PadSiteFit
