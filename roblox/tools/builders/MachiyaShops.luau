--!strict
-- Per-shop spec tables for the Machiya archetype (design spec
-- docs/superpowers/specs/2026-08-15-machiya-row-design.md). EVERY envelope here is
-- the OWNER'S, measured from a holdout/massing block in Studio and read back as
-- literals. Do not re-derive them from anything.
local MachiyaShops = {}

export type Shop = {
    name: string,
    envelope: { x0: number, x1: number, z0: number, z1: number, floorY: number },
    yaw: number,
    frontage: "open" | "koshi",
    interior: "full" | "shallow" | "none",
    storeys: { ground: number, upper: number }?,
    identity: { [string]: any }?,
}

-- 花火屋 — measured from the holdout the owner placed 2026-08-05; front deepened
-- z44 -> z36 at the owner's direction 2026-08-13. See Machiya.luau's history notes.
MachiyaShops.hanabiya = {
    name = "Hanabiya",
    envelope = { x0 = -1.67, x1 = 16.26, z0 = 36.00, z1 = 52.00, floorY = 113.10 },
    yaw = 0,
    frontage = "open",
    interior = "full",
} :: Shop

-- ===== 2026-08-15 survey — merchant row =====
-- Read live from game.ServerStorage.Sandbox_PARKED.MerchantMassing (Studio MCP,
-- datamodel Edit). Envelope x0/x1/z0/z1 = pivot +/- GetExtentsSize()/2 in the
-- LOCAL frame (yaw applied separately by shop.yaw, per Machiya.luau's final rotation
-- pass — Task 3). floorY probes: 8-point footing ring (4 corners + 4 edge
-- midpoints), raycast from pivotY+40 straight down 80 studs, RaycastParams
-- Include-filtered to workspace.Terrain only. North (-Z, lower world Z) is the
-- FRONTAGE/promenade side in every south-row shell, matching 花火屋's Z0; south
-- (+Z) runs into the terrain cut, same as 花火屋's "back is fixed" note — so
-- floorY is taken from the FRONT probes only (NW/NE/N_mid), the highest of the
-- three, which is what keeps a raised slab from dipping below its own street
-- edge. Back-probe scatter is real canyon grade into the cut, not a floor
-- disagreement, and is NOT averaged into floorY.
--
-- ENVELOPE DEPTH TENSION (flagged, not resolved here): every one of these massing
-- blocks is 13.24 studs deep in z, the same depth 花火屋's own holdout sibling
-- was before the owner deepened its envelope to 16 (z44->z36, 2026-08-13, "the
-- shop held about three people"). The archetype wants frontage clearance +
-- COUNTER_STANDOFF (4.4) + working room behind the counter; at 13.24 these three
-- envelopes read just as tight as 花火屋's pre-gate one did. Recorded here as the
-- owner's literal measurement, not re-derived — the owner corrects it at the gate
-- if it should deepen the same way.

-- Machiya_1 -> APPAREL. pivot(-10.06,120.91,41.85) size(24.72,17.92,13.24) yawDeg
-- 0.00. Footing ring (Terrain-filtered raycast, all hit Sand):
--   NW(-22.42,35.23) 113.30  NE(2.30,35.23) 112.53  N_mid(-10.06,35.23) 112.97
--   SW(-22.42,48.48) 121.08  SE(2.30,48.48) 111.82  S_mid(-10.06,48.48) 115.46
--   W_mid(-22.42,41.85) 115.22  E_mid(2.30,41.85) 112.31
-- Front spread (NW/NE/N_mid) 0.77 studs -- consistent, no concern. floorY = the
-- front's highest hit, 113.30 -- reads on the same promenade grade as 花火屋's
-- 113.10. Back spread is 9.26 (111.82 to 121.08): the south edge climbs into the
-- terrain cut, unevenly -- matches the pattern, not treated as a floor problem.
MachiyaShops.apparel = {
    name = "MachiyaApparel",
    envelope = { x0 = -22.42, x1 = 2.30, z0 = 35.23, z1 = 48.48, floorY = 113.30 },
    yaw = 0,
    frontage = "open",
    interior = "shallow",
} :: Shop

-- Machiya_4 -> ACCESSORIES. pivot(24.34,119.59,42.96) size(16.63,14.92,13.24)
-- yawDeg 0.00. Footing ring (Sand on the front/sides, Slate on the back):
--   NW(16.02,36.34) 112.03  NE(32.65,36.34) 113.14  N_mid(24.34,36.34) 113.21
--   SW(16.02,49.59) 111.59  SE(32.65,49.59) 114.99  S_mid(24.34,49.59) 120.24
--   W_mid(16.02,42.96) 112.29  E_mid(32.65,42.96) 113.94
-- Front spread 1.18 studs -- under the 1.5 flag threshold but the widest of the
-- three shells; recorded, not smoothed. floorY = the front's highest hit, 113.21.
-- Back spread 8.65 (111.59 to 120.24), again reading as the cut, not the floor.
MachiyaShops.accessories = {
    name = "MachiyaAccessories",
    envelope = { x0 = 16.02, x1 = 32.65, z0 = 36.34, z1 = 49.58, floorY = 113.21 },
    yaw = 0,
    frontage = "open",
    interior = "shallow",
} :: Shop

-- Machiya_East -> SPORTS BOOK FRONTAGE. pivot(74.27,119.42,47.58)
-- size(21.40,15.92,13.24) yawDeg -0.20 (within the +/-1 deg tolerance, treated as
-- 0 -- Machiya.luau's local frame is already the world frame here). Footing ring
-- (front is a Sand/Slate mix, no longer a clean grade):
--   NW(63.59,40.92) 109.74  NE(84.99,40.99) 103.41  N_mid(74.29,40.96) 106.63
--   SW(63.55,54.16) 119.73  SE(84.95,54.24) 109.21  S_mid(74.25,54.20) 114.08
--   W_mid(63.57,47.54) 115.16  E_mid(84.97,47.62) 106.03
-- *** CONCERN: front spread (NW/NE/N_mid) is 6.32 studs (103.41 to 109.74) --
-- well past the 1.5-stud flag threshold. This is not the flat promenade grade
-- the other two shells sit on; the ground under this footprint is genuinely
-- uneven, west-to-east as well as north-to-south (W_mid 115.16 vs E_mid 106.03).
-- floorY is set to the front's highest hit, 109.74, by the same rule as the other
-- two shells, but this site's terrain needs the owner's eye before a shell is
-- built here -- NOT resolved with invented terracing. ***
-- *** CONCERN: the envelope's AABB (x[63.57,84.97] y[111.46,127.38] z[40.96,54.20])
-- intersects 18 existing Overlook parts (UpperDeck, GirderUpperDeckX3, and 16
-- railing/barrier pieces) -- workspace:GetPartBoundsInBox around the envelope,
-- Include-filtered to workspace.RoshamboStage.Overlook. The design spec calls for
-- this shell's future interior to bore under the western Overlook, so SOME
-- proximity is intended, but a literal collision with the Overlook's built upper
-- deck is a siting problem for the shell itself, not just its future cavern. The
-- nearest Overlook part strictly outside (west of) the envelope's x0 is
-- RailNUpperDeckB3, east face x=62.27, a 1.30-stud gap. ***
MachiyaShops.sportsbook = {
    name = "MachiyaEast",
    envelope = { x0 = 63.57, x1 = 84.97, z0 = 40.96, z1 = 54.20, floorY = 109.74 },
    yaw = 0,
    frontage = "koshi",
    interior = "none",
} :: Shop

-- ===== chayaSurvey — record for Task 7 (Chaya.luau), not a Shop table =====
-- Machiya_2 -> RIVERSIDE CHAYA. pivot(-57.37,118.44,14.92) size(14.40,14.92,13.24)
-- yawDeg -97.00 -- FAR past the +/-1 deg tolerance. Task 7 must use the LOCAL
-- frame (envelope measured around the pivot in the block's own rotated axes) and
-- set shop.yaw = -97.00; Machiya.luau's yaw pass (Task 3) applies it, the same
-- way it will for any other rotated shell. World-frame AABB, for reference only
-- (NOT the envelope to build from): x[-64.57,-50.17] z[8.30,21.54].
-- Footing ring (world-frame corners/edges of the AABB, Sand/Grass/Slate mixed):
--   NW(-49.92,8.58) 112.59  NE(-51.67,22.87) 118.99  SW(-63.06,6.97) 115.56
--   SE(-64.82,21.26) 124.66  N_mid(-50.79,15.73) 113.45  S_mid(-63.94,14.11) 120.28
--   W_mid(-56.49,7.77) 112.87  E_mid(-58.24,22.07) 117.86
-- Spread across all 8 is 12.07 studs (112.59 to 124.66) -- unsurprising for an AABB
-- ring probed against a block that's actually rotated 97 deg; Task 7 should re-probe
-- in the block's own local frame rather than trust these axis-aligned points.
--
-- DockDeck -> chaya's companion deck. pivot(-44.00,112.20,-12.00)
-- size(14.00,0.80,10.00) yawDeg 0.00. Footing ring: all 8 points hit
-- Enum.Material.Water at Y 109.92, flat (spread 0.00) -- the deck sits over the
-- river, as its name and the design spec both say; there is no dry terrain under
-- its footprint to found on, only the water surface. Envelope (world frame, yaw
-- 0): x0=-51.00, x1=-37.00, z0=-17.00, z1=-7.00.
return MachiyaShops
