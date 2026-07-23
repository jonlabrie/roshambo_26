--!strict
-- The eight great dragon kings (八大龍王, Hachidai Ryūō) carved as pierced ranma on the
-- mawari-dōrō lantern's 8 shade-panel openings. Each has two Roblox image assets baked from a
-- Marigold normal+shading pair via tools/glyphs/{relief_marigold,pierce}.cjs (T=45 pierce):
--   normal  → SurfaceAppearance.NormalMap
--   pierced → SurfaceAppearance.ColorMap  (weathered-cypress × AO, alpha-cut voids; Transparency)
-- Consumed by tools/studio/buildRanmaCarvings.luau (bakes assets/meshes/RanmaCarvings.rbxm).
-- Source Marigold pairs live in the user's reference folder (eight_dragon_kings/<Name>).
local DragonKings = {}

export type Dragon = { name: string, normal: string, pierced: string }

DragonKings.ASSETS = {
    Nanda = {
        name = "Nanda",
        normal = "rbxassetid://138076733705219",
        pierced = "rbxassetid://94938052156081",
    },
    Upananda = {
        name = "Upananda",
        normal = "rbxassetid://92424286688223",
        pierced = "rbxassetid://103147334577833",
    },
    Sagara = {
        name = "Sagara",
        normal = "rbxassetid://82854469289249", -- v2 (head regen 2026-07-22)
        pierced = "rbxassetid://126874855515512",
    },
    Vasuki = {
        name = "Vasuki",
        normal = "rbxassetid://102918673625575",
        pierced = "rbxassetid://115092310989766",
    },
    Takshaka = {
        name = "Takshaka",
        normal = "rbxassetid://121735697769309",
        pierced = "rbxassetid://128096975924524",
    },
    Anavatapta = {
        name = "Anavatapta",
        normal = "rbxassetid://120396529915065",
        pierced = "rbxassetid://96668720693029",
    },
    Manasvin = {
        name = "Manasvin",
        normal = "rbxassetid://84953931626839", -- v2 (head regen 2026-07-22)
        pierced = "rbxassetid://117439303532703",
    },
    Utpalaka = {
        name = "Utpalaka",
        normal = "rbxassetid://133499635292704",
        pierced = "rbxassetid://105426174736333",
    },
} :: { [string]: Dragon }

-- The 8 shade panels (ShadePanel1..8) at these off-cardinal facet dirs. The canonical order
-- Nanda→Upananda→Sagara→Vasuki→Takshaka→Anavatapta→Manasvin→Utpalaka is laid onto the panels
-- STARTING AT PANEL 4 and wrapping 4,5,6,7,8,1,2,3 — so Nanda/Upananda land on panels 4 & 5,
-- flanking the +Z throw-display window (user placement, 2026-07-22).
DragonKings.PANEL_DIRS = { 30, 60, 120, 150, 210, 240, 300, 330 }
DragonKings.DRAGON_FOR_PANEL = {
    "Anavatapta", -- panel 1 (30°)
    "Manasvin", -- panel 2 (60°)
    "Utpalaka", -- panel 3 (120°)
    "Nanda", -- panel 4 (150°) — flanks +Z window
    "Upananda", -- panel 5 (210°) — flanks +Z window
    "Sagara", -- panel 6 (240°)
    "Vasuki", -- panel 7 (300°)
    "Takshaka", -- panel 8 (330°)
}

-- Marigold source aspect (W:H); carvings preserve this (no stretch).
DragonKings.ASPECT = 0.756

return DragonKings
