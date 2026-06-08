--!strict
-- Jumbotron frame: dark lacquered wood border with a gold inner trim lip
-- (spec §4.1 — "dark lacquered frame with gold trim"). Wraps the JumbotronBoard
-- part read from ArenaLayout; the SurfaceGui faces stay clear (frame bars sit
-- outside the board rectangle, depth straddling both faces).
local Spec = require("./Spec")

local JumbotronFrame = {}

local LACQUER = { 0.09, 0.06, 0.06 } -- near-black lacquer with a warm red undertone
local GOLD = { 0.83, 0.69, 0.40 }

function JumbotronFrame.build(L: any)
    local bx, by = L.jumbotron.pos[1], L.jumbotron.pos[2]
    local w, h = L.jumbotron.size[1], L.jumbotron.size[2]
    local bar = 5 -- frame bar width
    local depth = 4 -- straddles the board (board thickness 1) on both faces
    local outerW = w + bar * 2
    local children = {
        Spec.part("FrameTop", {
            Size = { outerW, bar, depth },
            CFrame = Spec.cframe({ bx, by + h / 2 + bar / 2, 0 }),
            Color = LACQUER,
            Material = "WoodPlanks",
        }),
        Spec.part("FrameBottom", {
            Size = { outerW, bar, depth },
            CFrame = Spec.cframe({ bx, by - h / 2 - bar / 2, 0 }),
            Color = LACQUER,
            Material = "WoodPlanks",
        }),
        Spec.part("FrameLeft", {
            Size = { bar, h, depth },
            CFrame = Spec.cframe({ bx - w / 2 - bar / 2, by, 0 }),
            Color = LACQUER,
            Material = "WoodPlanks",
        }),
        Spec.part("FrameRight", {
            Size = { bar, h, depth },
            CFrame = Spec.cframe({ bx + w / 2 + bar / 2, by, 0 }),
            Color = LACQUER,
            Material = "WoodPlanks",
        }),
    }
    -- gold inner trim lip: thin bars hugging the board edge, proud of the lacquer
    local lip = 0.8
    local trim = {
        { { w + lip * 2, lip, depth + 0.6 }, { bx, by + h / 2 + lip / 2, 0 } }, -- top
        { { w + lip * 2, lip, depth + 0.6 }, { bx, by - h / 2 - lip / 2, 0 } }, -- bottom
        { { lip, h, depth + 0.6 }, { bx - w / 2 - lip / 2, by, 0 } }, -- left
        { { lip, h, depth + 0.6 }, { bx + w / 2 + lip / 2, by, 0 } }, -- right
    }
    for i, t in trim do
        table.insert(
            children,
            Spec.part(`Trim{i}`, {
                Size = t[1],
                CFrame = Spec.cframe(t[2]),
                Color = GOLD,
                Material = "Metal",
            })
        )
    end
    return Spec.model("JumbotronFrame", children)
end

return JumbotronFrame
