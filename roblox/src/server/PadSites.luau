--!strict
-- Baked surveyed sites for sub-project D materialization. mountCF pos = the deck CENTER
-- (symmetric pad, y = deck-top datum), rot = deck rotation; each carries a survey-derived
-- `maxSize` (the largest teahouse the perch's terrain supports on posts with no void
-- corners). Dynamic posts (PadPlanner/PadOps) build a stilt only where terrain drops below
-- the deck; embed corners bed into the slope.
--
-- Full canyon survey at the retuned sizes (L=1.6 / M=1.3, commit 0fbae1c) done 2026-07-08
-- via the draggable-marker clearing flow: veranda oriented to the view, terrain shaved or
-- the pad repositioned as needed, posts checked vs AccessKeepOut paths. All 14 perches
-- hold maxSize=L. Hands: left = {T03, T05, T06}; right = the rest. PadRef access-target
-- stubs live at Workspace.Sandbox.PadRefs. Near-wall T01/T03/T05/T07/T14 displayNames are
-- PLACEHOLDERS; far-wall T08-T13 likewise. Repositioned perches owe access rework (see the
-- SDD ledger's access-rework backlog).
--
-- 2026-07-12 RE-BAKE (pad/deck separation, Piece A): mountCF pos moved from the legacy
-- off-center build datum to the deck CENTER (= each PadRef_Txx.Pad center), so the new
-- symmetric procedural deck seats on the surveyed pad / access. Only X,Z changed; Y, rot,
-- hand, maxSize, names unchanged. Shift was a uniform ~8.5 studs (T11 ~7.0).
--
-- 2026-07-12 Task 9/12: each perch carries `deckSize` (= maxSize) and a default `placement`
-- { offset, facing }. `hand` (left = T03/T05/T06) was removed in the Task 12 cleanup, and its
-- successor field (a per-side shoji-wrap hint) was retired in SP1 Task 4, superseded by
-- wallBays. offset/facing are a uniform starting default (slight back-tuck so the veranda
-- fronts the view); refined per-perch in a later polish pass.
return {
    ["T01"] = {
        id = "T01",
        displayName = "Near Perch 01",
        mountCF = { 43.339, 200.6605, 121.6285, 0.9404, 0, 0.3401, 0, 1, 0, -0.3401, 0, 0.9404 },
        maxSize = "L",
        deckSize = "L",
        placement = { offset = { 0, 3 }, facing = "N" },
        vacantForm = "dormant-structure",
    },
    ["T02"] = {
        id = "T02",
        displayName = "Overlook",
        mountCF = { -136.0583, 172.1823, 61.5449, 0.9754, 0, 0.2204, 0, 1, 0, -0.2204, 0, 0.9754 },
        maxSize = "L",
        deckSize = "L",
        placement = { offset = { 0, 3 }, facing = "N" },
        vacantForm = "dormant-structure",
    },
    ["T03"] = {
        id = "T03",
        displayName = "Near Perch 03",
        mountCF = { -194.8277, 181.1997, 52.1066, 0.9195, 0, -0.3931, 0, 1, 0, 0.3931, 0, 0.9195 },
        maxSize = "L",
        deckSize = "L",
        placement = { offset = { 0, 3 }, facing = "N" },
        vacantForm = "dormant-structure",
    },
    ["T04"] = {
        id = "T04",
        displayName = "Creekside",
        mountCF = { -184.4144, 216.9268, 94.1288, 0.9634, 0, -0.268, 0, 1, 0, 0.268, 0, 0.9634 },
        maxSize = "L",
        deckSize = "L",
        placement = { offset = { 0, 3 }, facing = "N" },
        vacantForm = "dormant-structure",
    },
    ["T05"] = {
        id = "T05",
        displayName = "Near Perch 05",
        mountCF = { -320.0421, 219.2089, 85.5581, 0.9907, 0, -0.1363, 0, 1, 0, 0.1363, 0, 0.9907 },
        maxSize = "L",
        deckSize = "L",
        placement = { offset = { 0, 3 }, facing = "N" },
        vacantForm = "dormant-structure",
    },
    ["T06"] = {
        id = "T06",
        displayName = "Mossy Prow",
        mountCF = { -380.4722, 222.0902, 59.0996, 0.729, 0, -0.6845, 0, 1, 0, 0.6845, 0, 0.729 },
        maxSize = "L",
        deckSize = "L",
        placement = { offset = { 0, 3 }, facing = "N" },
        vacantForm = "dormant-structure",
    },
    ["T07"] = {
        id = "T07",
        displayName = "Near Perch 07",
        mountCF = { -287.3365, 189.1661, 32.2755, 0.9652, 0, 0.2615, 0, 1, 0, -0.2615, 0, 0.9652 },
        maxSize = "L",
        deckSize = "L",
        placement = { offset = { 0, 3 }, facing = "N" },
        vacantForm = "dormant-structure",
    },
    ["T08"] = {
        id = "T08",
        displayName = "Far Perch 08",
        mountCF = { -344.8, 220.6116, -81.9452, -1.0, 0, 0, 0, 1, 0, 0, 0, -1.0 },
        maxSize = "L",
        deckSize = "L",
        placement = { offset = { 0, 3 }, facing = "N" },
        vacantForm = "dormant-structure",
    },
    ["T09"] = {
        id = "T09",
        displayName = "Far Perch 09",
        mountCF = { -283.0475, 202.7953, -49.5605, -1.0, 0, 0.003, 0, 1, 0, -0.003, 0, -1.0 },
        maxSize = "L",
        deckSize = "L",
        placement = { offset = { 0, 3 }, facing = "N" },
        vacantForm = "dormant-structure",
    },
    ["T10"] = {
        id = "T10",
        displayName = "Far Perch 10",
        mountCF = { -189.4249, 208.955, -87.8364, -0.9331, 0, -0.3595, 0, 1, 0, 0.3595, 0, -0.9331 },
        maxSize = "L",
        deckSize = "L",
        placement = { offset = { 0, 3 }, facing = "N" },
        vacantForm = "dormant-structure",
    },
    ["T11"] = {
        id = "T11",
        displayName = "Far Perch 11",
        mountCF = { -193.9792, 176.4412, -45.8683, -0.7158, 0, -0.6983, 0, 1, 0, 0.6983, 0, -0.7158 },
        maxSize = "L",
        deckSize = "L",
        placement = { offset = { 0, 3 }, facing = "N" },
        vacantForm = "dormant-structure",
    },
    ["T12"] = {
        id = "T12",
        displayName = "Far Perch 12",
        mountCF = { -126.4689, 156.8501, -48.3449, -0.9602, 0, -0.2793, 0, 1, 0, 0.2793, 0, -0.9602 },
        maxSize = "L",
        deckSize = "L",
        placement = { offset = { 0, 3 }, facing = "N" },
        vacantForm = "dormant-structure",
    },
    ["T13"] = {
        id = "T13",
        displayName = "Far Perch 13",
        mountCF = { 0.1093, 198.2727, -137.9141, -0.9939, 0, -0.1104, 0, 1, 0, 0.1104, 0, -0.9939 },
        maxSize = "L",
        deckSize = "L",
        placement = { offset = { 0, 3 }, facing = "N" },
        vacantForm = "dormant-structure",
    },
    ["T14"] = {
        id = "T14",
        displayName = "Near Perch 14",
        mountCF = { 113.8926, 188.3997, 96.6495, 0.9232, 0, 0.3843, 0, 1, 0, -0.3843, 0, 0.9232 },
        maxSize = "L",
        deckSize = "L",
        placement = { offset = { 0, 3 }, facing = "N" },
        vacantForm = "dormant-structure",
    },
}
