--!strict
-- Baked surveyed sites for sub-project D materialization. Each site is Deck-anchored
-- (mountCF pos = deck floor-underside datum, rot = deck rotation) and carries a
-- survey-derived `maxSize` (the largest teahouse the perch's terrain supports on posts
-- with no void corners). Dynamic posts (PadPlanner/PadOps) build a stilt only where
-- terrain drops below the deck; embed corners bed into the slope. Captured 2026-07-07
-- via MCP from the real legacy perches; supersedes the D.1-D.3 cliff-proof synthetic pads.
--
-- Near-wall (OLD 2.0/1.5-scale survey): T02=L, T06=M, T04=S — due for re-survey at the
-- retuned sizes (L=1.6/M=1.3, commit retune 2026-07-08).
-- Far-wall (2026-07-08 survey at retuned L=1.6, via the draggable-marker clearing flow):
-- T08-T13 all maxSize=L, hand=right; PadRef stubs live at Workspace.Sandbox.PadRefs.
-- displayNames T08-T13 are PLACEHOLDERS (rename later).
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
    ["T08"] = {
        id = "T08",
        displayName = "Far Perch 08",
        mountCF = { -338.7201, 220.6116, -87.8492, -1.0, 0, 0, 0, 1, 0, 0, 0, -1.0 },
        hand = "right",
        maxSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T09"] = {
        id = "T09",
        displayName = "Far Perch 09",
        mountCF = { -276.9496, 202.7953, -55.446, -1.0, 0, 0.003, 0, 1, 0, -0.003, 0, -1.0 },
        hand = "right",
        maxSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T10"] = {
        id = "T10",
        displayName = "Far Perch 10",
        mountCF = { -185.8742, 208.955, -95.5316, -0.9331, 0, -0.3595, 0, 1, 0, 0.3595, 0, -0.9331 },
        hand = "right",
        maxSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T11"] = {
        id = "T11",
        displayName = "Far Perch 11",
        mountCF = { -192.0705, 176.4412, -52.6185, -0.7158, 0, -0.6983, 0, 1, 0, 0.6983, 0, -0.7158 },
        hand = "right",
        maxSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T12"] = {
        id = "T12",
        displayName = "Far Perch 12",
        mountCF = { -122.2799, 156.8501, -55.7121, -0.9602, 0, -0.2793, 0, 1, 0, 0.2793, 0, -0.9602 },
        hand = "right",
        maxSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T13"] = {
        id = "T13",
        displayName = "Far Perch 13",
        mountCF = { 5.5001, 198.2727, -144.4534, -0.9939, 0, -0.1104, 0, 1, 0, 0.1104, 0, -0.9939 },
        hand = "right",
        maxSize = "L",
        vacantForm = "dormant-structure",
    },
}
