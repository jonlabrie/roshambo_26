--!strict
-- Ishidōrō stone lantern: base / post / firebox / cap. ~5 studs tall.
local Spec = require("./Spec")

local StoneLantern = {}

function StoneLantern.build(palette: { [string]: { number } }, at: { number })
    local x, y, z = at[1], at[2], at[3]
    local stone = palette.gravel
    local glow = palette.gold
    return Spec.model("StoneLantern", {
        Spec.part("Base", {
            Size = { 2.2, 0.8, 2.2 },
            CFrame = Spec.cframe({ x, y + 0.4, z }),
            Color = stone,
            Material = "Slate",
        }),
        Spec.part("Post", {
            Size = { 0.9, 2.2, 0.9 },
            CFrame = Spec.cframe({ x, y + 1.9, z }),
            Color = stone,
            Material = "Slate",
        }),
        Spec.part("Firebox", {
            Size = { 1.6, 1.2, 1.6 },
            CFrame = Spec.cframe({ x, y + 3.6, z }),
            Color = glow,
            Material = "Neon",
            Transparency = 0.2,
            children = {
                {
                    name = "Glow",
                    className = "PointLight",
                    properties = { Brightness = 0.8, Range = 14, Color = { 0.9, 0.75, 0.45 } },
                },
            },
        }),
        Spec.part("Cap", {
            Size = { 2.6, 0.7, 2.6 },
            CFrame = Spec.cframe({ x, y + 4.55, z }),
            Color = stone,
            Material = "Slate",
        }),
    })
end

return StoneLantern
