--!strict
-- Tier dressing: ishidōrō lantern rings, cushion clusters, low tea tables on each
-- terrace. Skips the creek channel, koi pond, content pads, and the sandō gap.
local Spec = require("./Spec")
local StoneLantern = require("./StoneLantern")

local TerraceDressing = {}

local CK_DIRX, CK_DIRZ = -0.8387, -0.5446 -- creek drive line (driveYaw 237°)

-- true where dressing must NOT go: in/near the creek, koi pond, or a content pad.
local function blocked(x: number, z: number, L: any): boolean
    if math.abs(x * CK_DIRZ - z * CK_DIRX) < 8 then -- creek channel
        return true
    end
    local k = L.koiPond.pos
    if math.sqrt((x - k[1]) ^ 2 + (z - k[3]) ^ 2) < L.koiPond.radius + 5 then
        return true
    end
    for _, p in L.promontories do
        if math.sqrt((x - p.pos[1]) ^ 2 + (z - p.pos[3]) ^ 2) < 12 then
            return true
        end
    end
    for _, t in L.teahouses do
        if math.sqrt((x - t.pos[1]) ^ 2 + (z - t.pos[3]) ^ 2) < 12 then
            return true
        end
    end
    return false
end

-- WALL_RUN mirrors buildTerrain: each tier's wall ramps over this many studs just
-- inside the NEXT tier's radius. So a tier's flat plateau runs from its own radius
-- out to (nextTier.radius - WALL_RUN); the last tier's runs out toward the rim.
local WALL_RUN = 7
-- Roblox smooth terrain renders the grass top ~2 studs proud of the heightfield
-- value, so props placed at the nominal tier.height bury their base. Lift dressing
-- by GROUND_LIFT so it rests ON the visible surface. (Tune if terrain Y changes.)
local GROUND_LIFT = 2

function TerraceDressing.build(palette: { [string]: { number } }, L: any)
    local children = {}
    for ti, tier in L.tiers do
        -- centre of this tier's flat plateau, where the ground really sits at
        -- tier.height — placing at tier.radius-4 dropped items onto the inner wall.
        local nextWall = if L.tiers[ti + 1] then L.tiers[ti + 1].radius - WALL_RUN else tier.radius + 8
        local r = (tier.radius + nextWall) / 2
        local gy = tier.height + GROUND_LIFT -- ground the dressing rests on
        for i = 1, 8 do
            local a = (i - 0.5) * math.pi / 4
            local x, z = r * math.cos(a), r * math.sin(a)
            -- keep the sandō/entrance gap clear at −Z (a ≈ 3π/2), and skip features
            if math.abs(a - 1.5 * math.pi) > 0.35 and not blocked(x, z, L) then
                local lantern = StoneLantern.build(palette, { x, gy, z })
                lantern.name = `Lantern_{ti}_{i}`
                table.insert(children, lantern)
            end
        end
        for i = 1, 6 do
            local a = i * math.pi / 3 + 0.26
            local cx, cz = r * math.cos(a), r * math.sin(a)
            if not blocked(cx, cz, L) then
                table.insert(
                    children,
                    Spec.part(`Table_{ti}_{i}`, {
                        Size = { 3, 0.9, 3 },
                        CFrame = Spec.cframe({ cx, gy + 0.45, cz }),
                        Color = palette.ink,
                        Material = "Wood",
                    })
                )
                for ci, off in { { 2.6, 0 }, { -2.6, 0 }, { 0, 2.6 }, { 0, -2.6 } } do
                    table.insert(
                        children,
                        Spec.part(`Cushion_{ti}_{i}_{ci}`, {
                            Size = { 0.5, 1.8, 1.8 },
                            Shape = "Cylinder",
                            CFrame = Spec.cframe(
                                { cx + off[1], gy + 0.25, cz + off[2] },
                                Spec.ROT.CYL_VERTICAL
                            ),
                            Color = if ci % 2 == 0 then palette.vermilion else palette.ivory,
                            Material = "Fabric",
                        })
                    )
                end
            end
        end
    end
    return Spec.model("TerraceDressing", children)
end

return TerraceDressing
