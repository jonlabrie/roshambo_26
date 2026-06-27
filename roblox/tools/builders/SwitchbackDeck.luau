--!strict
-- Small posted timber viewing deck at the FarWall_11 hairpin (spec 2026-06-27).
-- A smaller/simpler sibling of Overlook: single slab on a post ring, KORAN railing on
-- the East+South edges, two lanterns, a threshold + timber step-downs at the West exit.
-- Pure & deterministic; post feet are baked from the recorded terrain survey.
local Spec = require("./Spec")

local SwitchbackDeck = {}

-- ===== constants (see plan Global Constraints) =====
local DECK_TOP = 138.0
local SLAB_T = 0.6
local X0, X1 = 124, 136 -- West, South edges
local Z0, Z1 = -76, -66 -- North, East edges
local TIMBER = { 0.42, 0.31, 0.20 }

function SwitchbackDeck.build(_palette: any, _layout: any): Spec.PartSpec
    local kids: { Spec.PartSpec } = {}

    -- deck slab
    table.insert(
        kids,
        Spec.part("DeckSlab", {
            Size = { X1 - X0, SLAB_T, Z1 - Z0 },
            CFrame = Spec.cframe({ (X0 + X1) / 2, DECK_TOP - SLAB_T / 2, (Z0 + Z1) / 2 }),
            Color = TIMBER,
            Material = "WoodPlanks",
        })
    )

    return Spec.model("SwitchbackDeck", kids)
end

return SwitchbackDeck
