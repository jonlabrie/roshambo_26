--!strict
-- Recreates the Water Striker art-pass MaterialVariants in MaterialService (place-state;
-- SAVE/PUBLISH the place after running). Textures are CC0 PBR scans from ambientCG,
-- downloaded, (Wood059 desaturated toward gray), uploaded to Roblox via the MCP
-- localhost pipeline on 2026-07-20; the uploaded asset ids are baked below so this
-- rebuilds the exact variants on a fresh place.
--
-- IMPORTANT: BaseMaterial MUST match the Material the builder parts set, or the variant
-- won't show (a part uses a variant only when Part.Material == Variant.BaseMaterial).
-- The builders also tint each variant via the part Color (see ZenDojo.palette). Idempotent.
--
-- Source materials: CypressWeathered=Wood059(gray), BronzePatina=Metal058C,
-- SlateTile=RoofingTiles013A, IronDark=Metal046B, MossyPaddle=Wood065.
local MaterialService = game:GetService("MaterialService")

local SPECS = {
    {
        name = "CypressWeathered", -- posts/beams/brackets/rafters/drum faces/wheel
        base = Enum.Material.Wood,
        tile = 3.0,
        color = "rbxassetid://96689185606096", -- Wood059 color, desaturated to gray
        normal = "rbxassetid://127741157162851",
        metal = "",
        rough = "rbxassetid://82147307124298",
    },
    {
        name = "BronzePatina", -- the bell (tinted deep green by the part Color)
        base = Enum.Material.Metal,
        tile = 2.0,
        color = "rbxassetid://86287559320779", -- Metal058C
        normal = "rbxassetid://97075268059902",
        metal = "rbxassetid://123874633909877",
        rough = "rbxassetid://102554125864758",
    },
    {
        name = "SlateTile", -- the hip roof
        base = Enum.Material.Slate,
        tile = 1.5,
        color = "rbxassetid://118941425684741", -- RoofingTiles013A (black kawara)
        normal = "rbxassetid://91580065572768",
        metal = "",
        rough = "rbxassetid://134921240678362",
    },
    {
        name = "IronDark", -- bands/collars/gears/shafts/chains
        base = Enum.Material.Metal,
        tile = 2.0,
        color = "rbxassetid://104237098027053", -- Metal046B
        normal = "rbxassetid://86505850196416",
        metal = "rbxassetid://100280794177458",
        rough = "rbxassetid://79120828877718",
    },
    {
        name = "MossyPaddle", -- the dipping waterwheel paddles
        base = Enum.Material.WoodPlanks,
        tile = 2.0,
        color = "rbxassetid://92805641992948", -- Wood065
        normal = "rbxassetid://136944578036476",
        metal = "",
        rough = "rbxassetid://126607739624439",
    },
}

for _, s in SPECS do
    local mv = MaterialService:FindFirstChild(s.name)
    if not mv or not mv:IsA("MaterialVariant") then
        mv = Instance.new("MaterialVariant")
        mv.Name = s.name
        mv.Parent = MaterialService
    end
    local v = mv :: MaterialVariant
    v.BaseMaterial = s.base
    v.StudsPerTile = s.tile
    v.ColorMap = s.color
    v.NormalMap = s.normal
    v.MetalnessMap = s.metal
    v.RoughnessMap = s.rough
end
return "materials ready"
