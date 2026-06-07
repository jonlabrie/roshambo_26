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
    props.children = nil
    local properties: { [string]: any } = { Anchored = true }
    for k, v in props do
        properties[k] = v
    end
    return { name = name, className = "Part", properties = properties, children = kids }
end

function Spec.model(name: string, children: { PartSpec }): PartSpec
    return { name = name, className = "Model", properties = {}, children = children }
end

function Spec.yaw(deg: number): { number }
    local a = math.rad(deg)
    local c, s = math.cos(a), math.sin(a)
    return { c, 0, s, 0, 1, 0, -s, 0, c }
end

return Spec
