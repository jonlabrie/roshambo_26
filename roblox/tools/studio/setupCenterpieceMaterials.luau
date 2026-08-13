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
        tile = 10.0, -- in-place tuned to 10 (was 3.0; the 3.0 tiled too densely on the big members)
        color = "rbxassetid://96689185606096", -- Wood059 desaturated to gray (unrotated: grain runs vertically on the round logs)
        normal = "rbxassetid://127741157162851",
        metal = "",
        rough = "rbxassetid://82147307124298",
    },
    {
        name = "CypressVertical", -- FLAT vertical members (ranma frame verticals): same Wood059
        base = Enum.Material.Wood, -- gray, but the source maps are ROTATED 90° so the world-space
        tile = 10.0, -- (matches CypressWeathered) grain runs UP the tall bars instead of across a
        color = "rbxassetid://116981498078199", -- flat vertical face). Round logs already read vertical,
        normal = "rbxassetid://74665893433549", -- so they stay CypressWeathered; only flat verticals use this.
        metal = "",
        rough = "rbxassetid://87803454128649",
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
    {
        name = "HempRope", -- shu-moku hanger ropes
        base = Enum.Material.Fabric,
        tile = 1.0, -- tune at the live gate; world-space projection (rotate maps 90° like CypressVertical if the strands read sideways on the vertical drops)
        color = "rbxassetid://96470016324117", -- ambientCG Rope001 (uploaded 2026-07-23)
        normal = "rbxassetid://108776054419159", -- NormalGL
        metal = "rbxassetid://103690182987939",
        rough = "rbxassetid://140223765351870",
    },
    {
        name = "HempRopeFine", -- small rope details (whipping rings): same maps, fine tile
        base = Enum.Material.Fabric,
        tile = 0.4,
        color = "rbxassetid://96470016324117",
        normal = "rbxassetid://108776054419159",
        metal = "rbxassetid://103690182987939",
        rough = "rbxassetid://140223765351870",
    },
    {
        -- 花火屋's noren. BORROWED MAPS, HONESTLY: these are the Rope001 set again, run at a
        -- quarter of HempRopeFine's pitch so the strands stop reading as cord and start reading
        -- as a coarse woven textile. It is a stand-in — the right fix is a cloth scan uploaded
        -- like the others — and the thing to judge is whether it reads as WEAVE or as ROPE at
        -- the distance you actually see the shopfront from.
        name = "NorenCloth",
        base = Enum.Material.Fabric,
        tile = 0.1,
        color = "rbxassetid://96470016324117",
        normal = "rbxassetid://108776054419159",
        metal = "rbxassetid://103690182987939",
        rough = "rbxassetid://140223765351870",
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
