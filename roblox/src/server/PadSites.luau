--!strict
-- Baked surveyed sites for sub-project D materialization. Each perch authors a deck PIVOT per
-- size in `deckPlacements` (12-number row-major array, y = deck-top datum, view-oriented); the
-- deck is positioned to touch that perch's access and extend toward the view, and a smaller deck
-- sits further back (toward access) than a larger one. `maxSize` = the largest teahouse the perch
-- supports. The teahouse is centered on the deck (SiteCoordinator), so there is no per-pad
-- teahouse placement. Hands (legacy note): left = {T03,T05,T06}. PadRef stubs at Workspace.Sandbox.PadRefs.
--
-- 2026-07-13 PER-SIZE SURVEY: S/M/L deck placements surveyed per perch via the draggable-slab flow
-- (workspace.DeckSurvey), each dragged to touch access + face the view; rotation + deck-top Y locked
-- to the perch's L datum. Replaces the single migrated mountCF. T01 realigned during the survey.
return {
    ["T01"] = {
        id = "T01",
        displayName = "Near Perch 01",
        deckPlacements = {
            S = { 40.0861, 200.6605, 128.2457, 0.9999, 0, 0.0122, 0, 1, 0, -0.0122, 0, 0.9999 },
            M = { 41.8898, 200.6605, 126.793, 0.9999, 0, 0.0122, 0, 1, 0, -0.0122, 0, 0.9999 },
            L = { 43.4997, 200.6605, 125.732, 0.9999, 0, 0.0122, 0, 1, 0, -0.0122, 0, 0.9999 },
        },
        maxSize = "L",
        deckSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T02"] = {
        id = "T02",
        displayName = "Overlook",
        deckPlacements = {
            S = { -135.4744, 172.1823, 64.1289, 0.9754, 0, 0.2204, 0, 1, 0, -0.2204, 0, 0.9754 },
            M = { -135.7834, 172.1823, 62.7616, 0.9754, 0, 0.2204, 0, 1, 0, -0.2204, 0, 0.9754 },
            L = { -136.0583, 172.1823, 61.5449, 0.9754, 0, 0.2204, 0, 1, 0, -0.2204, 0, 0.9754 },
        },
        maxSize = "L",
        deckSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T03"] = {
        id = "T03",
        displayName = "Near Perch 03",
        deckPlacements = {
            S = { -199.0058, 181.1997, 53.1111, 0.9195, 0, -0.3931, 0, 1, 0, 0.3931, 0, 0.9195 },
            M = { -196.8759, 181.1997, 52.7722, 0.9195, 0, -0.3931, 0, 1, 0, 0.3931, 0, 0.9195 },
            L = { -194.8277, 181.1997, 52.1066, 0.9195, 0, -0.3931, 0, 1, 0, 0.3931, 0, 0.9195 },
        },
        maxSize = "L",
        deckSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T04"] = {
        id = "T04",
        displayName = "Creekside",
        deckPlacements = {
            S = { -181.8065, 216.9268, 97.604, 0.9634, 0, -0.268, 0, 1, 0, 0.268, 0, 0.9634 },
            M = { -183.2312, 216.9268, 95.9259, 0.9634, 0, -0.268, 0, 1, 0, 0.268, 0, 0.9634 },
            L = { -184.4144, 216.9268, 94.1288, 0.9634, 0, -0.268, 0, 1, 0, 0.268, 0, 0.9634 },
        },
        maxSize = "L",
        deckSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T05"] = {
        id = "T05",
        displayName = "Near Perch 05",
        deckPlacements = {
            S = { -320.3918, 219.2089, 88.1002, 0.9907, 0, -0.1363, 0, 1, 0, 0.1363, 0, 0.9907 },
            M = { -320.2121, 219.2089, 86.7938, 0.9907, 0, -0.1363, 0, 1, 0, 0.1363, 0, 0.9907 },
            L = { -320.0421, 219.2089, 85.5581, 0.9907, 0, -0.1363, 0, 1, 0, 0.1363, 0, 0.9907 },
        },
        maxSize = "L",
        deckSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T06"] = {
        id = "T06",
        displayName = "Mossy Prow",
        deckPlacements = {
            S = { -384.7391, 222.0902, 58.6128, 0.729, 0, -0.6845, 0, 1, 0, 0.6845, 0, 0.729 },
            M = { -382.4513, 222.0902, 58.8384, 0.729, 0, -0.6845, 0, 1, 0, 0.6845, 0, 0.729 },
            L = { -380.4722, 222.0902, 59.0996, 0.729, 0, -0.6845, 0, 1, 0, 0.6845, 0, 0.729 },
        },
        maxSize = "L",
        deckSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T07"] = {
        id = "T07",
        displayName = "Near Perch 07",
        deckPlacements = {
            S = { -289.9896, 189.1661, 35.6528, 0.9652, 0, 0.2615, 0, 1, 0, -0.2615, 0, 0.9652 },
            M = { -288.5948, 189.1661, 33.8226, 0.9652, 0, 0.2615, 0, 1, 0, -0.2615, 0, 0.9652 },
            L = { -287.3365, 189.1661, 32.2755, 0.9652, 0, 0.2615, 0, 1, 0, -0.2615, 0, 0.9652 },
        },
        maxSize = "L",
        deckSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T08"] = {
        id = "T08",
        displayName = "Far Perch 08",
        deckPlacements = {
            S = { -341.3561, 220.6116, -85.0112, -1, 0, 0, 0, 1, 0, 0, 0, -1 },
            M = { -343.1784, 220.6116, -83.6094, -1, 0, 0, 0, 1, 0, 0, 0, -1 },
            L = { -344.8, 220.6116, -81.9452, -1, 0, 0, 0, 1, 0, 0, 0, -1 },
        },
        maxSize = "L",
        deckSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T09"] = {
        id = "T09",
        displayName = "Far Perch 09",
        deckPlacements = {
            S = { -279.5944, 202.7953, -52.1994, -1, 0, 0.003, 0, 1, 0, -0.003, 0, -1 },
            M = { -281.4223, 202.7953, -50.7233, -1, 0, 0.003, 0, 1, 0, -0.003, 0, -1 },
            L = { -283.0475, 202.7953, -49.5605, -1, 0, 0.003, 0, 1, 0, -0.003, 0, -1 },
        },
        maxSize = "L",
        deckSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T10"] = {
        id = "T10",
        displayName = "Far Perch 10",
        deckPlacements = {
            S = { -193.5909, 208.955, -89.0703, -0.9331, 0, -0.3595, 0, 1, 0, 0.3595, 0, -0.9331 },
            M = { -191.3566, 208.955, -88.3398, -0.9331, 0, -0.3595, 0, 1, 0, 0.3595, 0, -0.9331 },
            L = { -189.4249, 208.955, -87.8364, -0.9331, 0, -0.3595, 0, 1, 0, 0.3595, 0, -0.9331 },
        },
        maxSize = "L",
        deckSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T11"] = {
        id = "T11",
        displayName = "Far Perch 11",
        deckPlacements = {
            S = { -191.5149, 176.4412, -48.2723, -0.7158, 0, -0.6983, 0, 1, 0, 0.6983, 0, -0.7158 },
            M = { -192.8193, 176.4412, -46.9999, -0.7158, 0, -0.6983, 0, 1, 0, 0.6983, 0, -0.7158 },
            L = { -193.9792, 176.4412, -45.8683, -0.7158, 0, -0.6983, 0, 1, 0, 0.6983, 0, -0.7158 },
        },
        maxSize = "L",
        deckSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T12"] = {
        id = "T12",
        displayName = "Far Perch 12",
        deckPlacements = {
            S = { -127.1848, 156.8501, -50.8059, -0.9602, 0, -0.2793, 0, 1, 0, 0.2793, 0, -0.9602 },
            M = { -126.8165, 156.8501, -49.54, -0.9602, 0, -0.2793, 0, 1, 0, 0.2793, 0, -0.9602 },
            L = { -126.4689, 156.8501, -48.3449, -0.9602, 0, -0.2793, 0, 1, 0, 0.2793, 0, -0.9602 },
        },
        maxSize = "L",
        deckSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T13"] = {
        id = "T13",
        displayName = "Far Perch 13",
        deckPlacements = {
            S = { -3.4682, 198.2727, -138.9271, -0.9939, 0, -0.1104, 0, 1, 0, 0.1104, 0, -0.9939 },
            M = { -1.578, 198.2727, -138.4159, -0.9939, 0, -0.1104, 0, 1, 0, 0.1104, 0, -0.9939 },
            L = { 0.1093, 198.2727, -137.9141, -0.9939, 0, -0.1104, 0, 1, 0, 0.1104, 0, -0.9939 },
        },
        maxSize = "L",
        deckSize = "L",
        vacantForm = "dormant-structure",
    },
    ["T14"] = {
        id = "T14",
        displayName = "Near Perch 14",
        deckPlacements = {
            S = { 111.6993, 188.3997, 100.3418, 0.9232, 0, 0.3843, 0, 1, 0, -0.3843, 0, 0.9232 },
            M = { 112.843, 188.3997, 98.3474, 0.9232, 0, 0.3843, 0, 1, 0, -0.3843, 0, 0.9232 },
            L = { 113.8926, 188.3997, 96.6495, 0.9232, 0, 0.3843, 0, 1, 0, -0.3843, 0, 0.9232 },
        },
        maxSize = "L",
        deckSize = "L",
        vacantForm = "dormant-structure",
    },
}
