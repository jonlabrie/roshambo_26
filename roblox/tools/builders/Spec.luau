--!strict
-- Part-spec helpers. A spec is a plain table that genmodels.luau converts to
-- Rojo model.json. Rotations: identity, or named axis helpers below.
local Spec = {}

export type PartSpec = {
    name: string,
    className: string,
    properties: { [string]: any },
    children: { PartSpec }?,
}

local IDENTITY = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
-- cylinder axis is +X; these re-aim it:
local CYL_VERTICAL = { 0, -1, 0, 1, 0, 0, 0, 0, 1 } -- axis → Y
local CYL_ALONG_Z = { 0, 0, 1, 0, 1, 0, -1, 0, 0 } -- axis → Z

function Spec.cframe(pos: { number }, rot: { number }?): { number }
    local r = rot or IDENTITY
    return { pos[1], pos[2], pos[3], r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8], r[9] }
end

Spec.ROT = { IDENTITY = IDENTITY, CYL_VERTICAL = CYL_VERTICAL, CYL_ALONG_Z = CYL_ALONG_Z }

function Spec.part(name: string, props: { [string]: any }): PartSpec
    local kids = props.children
    local properties: { [string]: any } = { Anchored = true }
    for k, v in props do
        if k ~= "children" then
            properties[k] = v
        end
    end
    return { name = name, className = "Part", properties = properties, children = kids }
end

function Spec.model(name: string, children: { PartSpec }): PartSpec
    return { name = name, className = "Model", properties = {}, children = children }
end

-- A cylinder (long axis = local X) spanning points a→b: returns midpoint pos,
-- length, and a row-major rotation matrix aligning local X with (b-a).
function Spec.segment(a: { number }, b: { number }): ({ number }, number, { number })
    local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
    local len = math.sqrt(dx * dx + dy * dy + dz * dz)
    local ux, uy, uz = dx / len, dy / len, dz / len -- local X (long axis)
    local rx, ry, rz = 0, 1, 0 -- up reference
    if math.abs(uy) > 0.99 then
        rx, ry, rz = 1, 0, 0
    end
    local d = rx * ux + ry * uy + rz * uz
    local yx, yy, yz = rx - d * ux, ry - d * uy, rz - d * uz
    local yl = math.sqrt(yx * yx + yy * yy + yz * yz)
    yx, yy, yz = yx / yl, yy / yl, yz / yl
    local zx, zy, zz = uy * yz - uz * yy, uz * yx - ux * yz, ux * yy - uy * yx -- u × y
    local rot = { ux, yx, zx, uy, yy, zy, uz, yz, zz } -- columns = X(u), Y, Z
    local pos = { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2, (a[3] + b[3]) / 2 }
    return pos, len, rot
end

function Spec.yaw(deg: number): { number }
    local a = math.rad(deg)
    local c, s = math.cos(a), math.sin(a)
    return { c, 0, s, 0, 1, 0, -s, 0, c }
end

-- Rotation about world-Y through the origin. Row-major 3x3 (matches Spec.cframe).
function Spec.rotYMat(deg: number): { number }
    local a = math.rad(deg)
    local c, s = math.cos(a), math.sin(a)
    return { c, 0, s, 0, 1, 0, -s, 0, c }
end

-- Rotate a point about world-Y through the origin.
function Spec.rotY(p: { number }, deg: number): { number }
    local a = math.rad(deg)
    local c, s = math.cos(a), math.sin(a)
    return { p[1] * c + p[3] * s, p[2], -p[1] * s + p[3] * c }
end

-- Row-major 3x3 multiply (a * b).
function Spec.matMul(a: { number }, b: { number }): { number }
    local r = {}
    for row = 0, 2 do
        for col = 0, 2 do
            local s = 0
            for k = 0, 2 do
                s += a[row * 3 + k + 1] * b[k * 3 + col + 1]
            end
            r[row * 3 + col + 1] = s
        end
    end
    return r
end

return Spec
