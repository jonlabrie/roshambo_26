--!strict
-- Baked surveyed sites for sub-project D materialization. Each site is Deck-anchored
-- (mountCF pos = deck floor-underside datum, rot = deck rotation) and carries a
-- survey-derived `maxSize` (the largest teahouse the perch's terrain supports on posts
-- with no void corners). Dynamic posts (PadPlanner/PadOps) build a stilt only where
-- terrain drops below the deck; embed corners bed into the slope. Captured 2026-07-07
-- via MCP from the real legacy perches; supersedes the D.1-D.3 cliff-proof synthetic pads.
--
-- Current survey maxSize: T02=L, T06=M, T04=S (all clearable to L via a later terrain cut).
return {
    ["T02"] = {
        id = "T02",
        displayName = "Overlook",
        mountCF = { -142.2818, 173.0035, 70.2984, 0.9754, 0, 0.2204, 0, 1, 0, -0.2204, 0, 0.9754 },
        hand = "right",
        maxSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T06"] = {
        id = "T06",
        displayName = "Mossy Prow",
        mountCF = { -381.7, 222.9114, 65, 0.6, 0, -0.8, 0, 1, 0, 0.8, 0, 0.6 },
        hand = "right",
        maxSize = "M",
        vacantForm = "dormant-structure",
    },
    ["T04"] = {
        id = "T04",
        displayName = "Creekside",
        mountCF = { -190.7751, 217.7481, 94.3078, 0.9634, 0, -0.268, 0, 1, 0, 0.268, 0, 0.9634 },
        hand = "right",
        maxSize = "S",
        vacantForm = "dormant-structure",
    },
}
