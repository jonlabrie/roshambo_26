--!strict
-- Small posted timber viewing deck at the FarWall_11 hairpin (spec 2026-06-27).
-- A smaller/simpler sibling of Overlook: single slab on a post ring, KORAN railing on
-- the East+South edges, two lanterns, a threshold + timber step-downs at the West exit.
-- Pure & deterministic; post feet are baked from the recorded terrain survey.
local Spec = require("./Spec")

local SwitchbackDeck = {}

-- ===== constants (see plan Global Constraints) =====
local DECK_TOP = 138.8
local SLAB_T = 0.6
-- Position baked from the user's in-Studio placement (2026-06-27): center (159.7, -66.6),
-- out on the higher promontory shelf east of FW11; reached by extending the upper path.
local CX, CZ = 159.7, -66.6 -- deck center (x, z)
local DECK_W, DECK_D = 18, 15 -- size: X width, Z depth
local X0, X1 = CX - DECK_W / 2, CX + DECK_W / 2 -- West, South edges
local Z0, Z1 = CZ - DECK_D / 2, CZ + DECK_D / 2 -- North, East edges
local TIMBER = { 0.42, 0.31, 0.20 }

function SwitchbackDeck.build(_palette: any, _layout: any): Spec.PartSpec
    local kids: { Spec.PartSpec } = {}

    -- deck slab
    table.insert(
        kids,
        Spec.part("DeckSlab", {
            Size = { DECK_W, SLAB_T, DECK_D },
            CFrame = Spec.cframe({ CX, DECK_TOP - SLAB_T / 2, CZ }),
            Color = TIMBER,
            Material = "WoodPlanks",
        })
    )

    return Spec.model("SwitchbackDeck", kids)
end

return SwitchbackDeck
