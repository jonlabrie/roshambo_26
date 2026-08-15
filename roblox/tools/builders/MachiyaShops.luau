--!strict
-- Per-shop spec tables for the Machiya archetype (design spec
-- docs/superpowers/specs/2026-08-15-machiya-row-design.md). EVERY envelope here is
-- the OWNER'S, measured from a holdout/massing block in Studio and read back as
-- literals. Do not re-derive them from anything.
local MachiyaShops = {}

export type Shop = {
    name: string,
    envelope: { x0: number, x1: number, z0: number, z1: number, floorY: number },
    yaw: number,
    frontage: "open" | "koshi",
    interior: "full" | "shallow" | "none",
    storeys: { ground: number, upper: number }?,
    identity: { [string]: any }?,
}

-- 花火屋 — measured from the holdout the owner placed 2026-08-05; front deepened
-- z44 -> z36 at the owner's direction 2026-08-13. See Machiya.luau's history notes.
MachiyaShops.hanabiya = {
    name = "Hanabiya",
    envelope = { x0 = -1.67, x1 = 16.26, z0 = 36.00, z1 = 52.00, floorY = 113.10 },
    yaw = 0,
    frontage = "open",
    interior = "full",
} :: Shop

return MachiyaShops
