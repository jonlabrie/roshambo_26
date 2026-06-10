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

function TerraceDressing.build(palette: { [string]: { number } }, L: any)
    local children = {}
    for ti, tier in L.tiers do
        local r = tier.radius - 4
        for i = 1, 8 do
            local a = (i - 0.5) * math.pi / 4
            local x, z = r * math.cos(a), r * math.sin(a)
            -- keep the sandō/entrance gap clear at −Z (a ≈ 3π/2), and skip features
            if math.abs(a - 1.5 * math.pi) > 0.35 and not blocked(x, z, L) then
                local lantern = StoneLantern.build(palette, { x, tier.height, z })
                lantern.name = `Lantern_{ti}_{i}`
                table.insert(children, lantern)
            end
        end
        for i = 1, 6 do
            local a = i * math.pi / 3 + 0.26
            local cx, cz = (r - 5) * math.cos(a), (r - 5) * math.sin(a)
            if not blocked(cx, cz, L) then
                table.insert(
                    children,
                    Spec.part(`Table_{ti}_{i}`, {
                        Size = { 3, 0.9, 3 },
                        CFrame = Spec.cframe({ cx, tier.height + 0.45, cz }),
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
                                { cx + off[1], tier.height + 0.25, cz + off[2] },
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
