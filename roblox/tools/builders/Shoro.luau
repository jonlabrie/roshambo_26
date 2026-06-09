--!strict
-- Timber shōrō (bell pavilion) standing over the basin.
local Spec = require("./Spec")

local Shoro = {}

function Shoro.build(palette: { [string]: { number } }, L: any)
    local s = L.pavilion.postSpacing / 2
    local roofY = L.pavilion.roofHeight
    local timber = palette.timber
    local ink = palette.ink
    local children = {}
    -- The pavilion is centred at the origin, so yaw it about world-Y to clear the
    -- gantry: rotate every part's position AND orientation by L.pavilion.yaw.
    local yaw = L.pavilion.yaw or 0
    local function place(pos: { number }, rot: { number }?): { number }
        return Spec.cframe(Spec.rotY(pos, yaw), Spec.matMul(Spec.rotYMat(yaw), rot or Spec.ROT.IDENTITY))
    end
    local corners = { { s, s }, { s, -s }, { -s, s }, { -s, -s } }
    for i, c in corners do
        table.insert(
            children,
            Spec.part(`Plinth{i}`, {
                Size = { 2.4, 1.2, 2.4 },
                CFrame = place({ c[1], 0.6, c[2] }),
                Color = palette.gravel,
                Material = "Slate",
            })
        )
        table.insert(
            children,
            Spec.part(`Post{i}`, {
                Size = { 1.4, roofY - 1.2, 1.4 },
                CFrame = place({ c[1], 1.2 + (roofY - 1.2) / 2, c[2] }),
                Color = timber,
                Material = "Wood",
            })
        )
    end
    for i, z in { s, -s } do
        table.insert(
            children,
            Spec.part(`RingBeamX{i}`, {
                Size = { 2 * s + 2.4, 1.2, 1.4 },
                CFrame = place({ 0, roofY - 0.6, z }),
                Color = timber,
                Material = "Wood",
            })
        )
    end
    for i, x in { s, -s } do
        table.insert(
            children,
            Spec.part(`RingBeamZ{i}`, {
                Size = { 1.4, 1.2, 2 * s + 2.4 },
                CFrame = place({ x, roofY - 0.6, 0 }),
                Color = timber,
                Material = "Wood",
            })
        )
    end
    table.insert(
        children,
        Spec.part("BellBeam", {
            Size = { 2.2, 1.8, 2 * s + 2.4 },
            CFrame = place({ 0, roofY - 1.8, 0 }),
            Color = timber,
            Material = "Wood",
        })
    )
    local roofHalf = s + 4
    local pitch = 2.25 -- halved 2026-06-08: the roof slab read too thick under the drum
    local wedges = {
        { rot = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }, pos = { 0, roofY + pitch / 2, roofHalf / 2 } },
        { rot = { -1, 0, 0, 0, 1, 0, 0, 0, -1 }, pos = { 0, roofY + pitch / 2, -roofHalf / 2 } },
        { rot = { 0, 0, 1, 0, 1, 0, -1, 0, 0 }, pos = { roofHalf / 2, roofY + pitch / 2, 0 } },
        { rot = { 0, 0, -1, 0, 1, 0, 1, 0, 0 }, pos = { -roofHalf / 2, roofY + pitch / 2, 0 } },
    }
    for i, w in wedges do
        table.insert(children, {
            name = `RoofWedge{i}`,
            className = "WedgePart",
            properties = {
                Anchored = true,
                Size = { 2 * roofHalf, pitch, roofHalf },
                CFrame = place(w.pos, w.rot),
                Color = ink,
                Material = "Slate",
            },
        })
    end
    table.insert(
        children,
        Spec.part("Finial", {
            Size = { 1, 2.2, 1 },
            CFrame = place({ 0, roofY + pitch + 1.1, 0 }),
            Color = palette.gold,
            Material = "Metal",
        })
    )
    return Spec.model("Shoro", children)
end

return Shoro
