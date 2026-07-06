--!strict
-- Baked surveyed PadSpec(s) for sub-project D materialization. mountCF is in
-- CFrame:GetComponents order (pos + row-major rotation); the datum plane is the
-- structure's floor-underside (probe Deck/EngawaF/Table, never the buried pivot).
-- footprint is the teahouse-1story prefab's frame extents (shared by all
-- teahouse-1story pads). id/vacantForm are carried for D.2 (the registry + the
-- vacant-state applier).
--
-- cliff-proof: the empty promontory shelf (gapB, ~ -60,105) reused verbatim from
-- the A<->B proof (tools/studio/padSites.luau). Verified 2026-07-06 via MCP: all
-- 6 support posts hit terrain (back short, front long over the drop). D.1's static
-- materialization stands one persisted teahouse here.
--
-- cliff-proof-2: the LARGE pad (footprint 2x base, fits size class L). A shelf
-- ~73 studs from cliff-proof at datum 240; MCP-verified 6/6 for the 2x-base
-- footprint on 2026-07-06 (D.3). Registered first so a joiner claims it with L;
-- cliff-proof (the small base-footprint pad) stays dormant at S.
return {
    ["cliff-proof"] = {
        id = "cliff-proof",
        mountCF = { -60, 274, 105, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        hand = "right",
        footprint = { minX = -7.40, maxX = 15.00, minZ = -11.70, maxZ = 4.32 },
        vacantForm = "dormant-structure",
    },
    ["cliff-proof-2"] = {
        id = "cliff-proof-2",
        mountCF = { -130, 240, 125, 1, 0, 0, 0, 1, 0, 0, 0, 1 },
        hand = "right",
        footprint = { minX = -14.80, maxX = 30.00, minZ = -23.40, maxZ = 8.64 },
        vacantForm = "dormant-structure",
    },
}
