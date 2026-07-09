--!strict
-- Baked surveyed sites for sub-project D materialization. Each site is Deck-anchored
-- (mountCF pos = deck floor-underside datum, rot = deck rotation) and carries a
-- survey-derived `maxSize` (the largest teahouse the perch's terrain supports on posts
-- with no void corners). Dynamic posts (PadPlanner/PadOps) build a stilt only where
-- terrain drops below the deck; embed corners bed into the slope.
--
-- Full canyon survey at the retuned sizes (L=1.6 / M=1.3, commit 0fbae1c) done 2026-07-08
-- via the draggable-marker clearing flow: veranda oriented to the view, terrain shaved or
-- the pad repositioned as needed, posts checked vs AccessKeepOut paths. All 14 perches
-- hold maxSize=L. Hands: left = {T03, T05, T06}; right = the rest. PadRef access-target
-- stubs live at Workspace.Sandbox.PadRefs. Near-wall T01/T03/T05/T07/T14 displayNames are
-- PLACEHOLDERS; far-wall T08-T13 likewise. Repositioned perches owe access rework (see the
-- SDD ledger's access-rework backlog).
return {
    ["T01"] = {
        id = "T01",
        displayName = "Near Perch 01",
        mountCF = { 39.6297, 200.6605, 129.2485, 0.9404, 0, 0.3401, 0, 1, 0, -0.3401, 0, 0.9404 },
        hand = "right",
        maxSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T02"] = {
        id = "T02",
        displayName = "Overlook",
        mountCF = { -140.6872, 172.1823, 68.644, 0.9754, 0, 0.2204, 0, 1, 0, -0.2204, 0, 0.9754 },
        hand = "right",
        maxSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T03"] = {
        id = "T03",
        displayName = "Near Perch 03",
        mountCF = { -191.558, 181.1997, 59.9253, 0.9195, 0, -0.3931, 0, 1, 0, 0.3931, 0, 0.9195 },
        hand = "left",
        maxSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T04"] = {
        id = "T04",
        displayName = "Creekside",
        mountCF = { -191.8544, 216.9268, 98.1871, 0.9634, 0, -0.268, 0, 1, 0, 0.268, 0, 0.9634 },
        hand = "right",
        maxSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T05"] = {
        id = "T05",
        displayName = "Near Perch 05",
        mountCF = { -314.8236, 219.2089, 92.2358, 0.9907, 0, -0.1363, 0, 1, 0, 0.1363, 0, 0.9907 },
        hand = "left",
        maxSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T06"] = {
        id = "T06",
        displayName = "Mossy Prow",
        mountCF = { -380.0815, 222.0902, 67.5655, 0.729, 0, -0.6845, 0, 1, 0, 0.6845, 0, 0.729 },
        hand = "left",
        maxSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T07"] = {
        id = "T07",
        displayName = "Near Perch 07",
        mountCF = { -291.6609, 189.1661, 39.564, 0.9652, 0, 0.2615, 0, 1, 0, -0.2615, 0, 0.9652 },
        hand = "right",
        maxSize = "L",
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
    ["T14"] = {
        id = "T14",
        displayName = "Near Perch 14",
        mountCF = { 110.5484, 188.3997, 104.4366, 0.9232, 0, 0.3843, 0, 1, 0, -0.3843, 0, 0.9232 },
        hand = "right",
        maxSize = "L",
        vacantForm = "dormant-structure",
    },
}
