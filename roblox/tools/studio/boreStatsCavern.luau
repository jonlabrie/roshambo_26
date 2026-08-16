--!strict
-- MCP/Edit: the STATS CAVERN (番付) — the tunnel and chamber bored into the hill behind
-- MachiyaStats' rear doorway, 2026-08-16. Paste/run in Studio (Edit datamodel).
--
-- MODE = "VERIFY" (the default) only MEASURES and reports. It never writes terrain.
-- MODE = "BORE" re-cuts from scratch and is DESTRUCTIVE.
--
-- WHY THE DEFAULT IS VERIFY (destructive-bake-guard discipline): the bore shipped, the
-- place was saved, and the OWNER THEN HAND-SHAPED the terrain around the tunnel mouth.
-- Re-running the bore would silently destroy that. This file's job is to record the
-- surveyed geometry and to let anyone re-measure the as-built; cutting again is an
-- explicit, deliberate act.
local MODE: "VERIFY" | "BORE" = "VERIFY"

-- ============================================================================
-- SURVEYED CONSTANTS (all measured live in the place, not assumed)
-- ============================================================================
-- The doorway the tunnel must meet, read off MachiyaStats itself:
local SILL = 113.30 -- FloorSlab top; the tunnel floor lands here
local DOOR_X = -28.92 -- clear opening x[-31.92,-25.92], 6.0 wide
local DOOR_HEAD = 120.10 -- RearDoorLintel underside
local LINTEL_TOP = 120.60 -- the tunnel roof is pinned here at the mouth
local WALL_OUTER_Z = 42.93 -- rear wall outer face

-- The roof overhang that caps how high the hillside may go near the mouth. RoofSouth's
-- LOWEST CORNER, computed from its 8 corners (NOT Position.Y - Size.Y/2 — the part is
-- rotated, and the naive form reads ~2 studs high).
local EAVE_Z, EAVE_Y, EAVE_SLOPE = 44.03, 127.20, 0.835

-- Owner-dragged route markers (Workspace.PathDraft.StatsCavern), XZ only — the bore
-- ignores their Y, which is just a terrain-surface handle so they stay grabbable.
local ROUTE = {
    { -28.92, 44.93 },
    { -28.92, 48.00 },
    { -28.40, 52.00 },
    { -28.00, 56.00 },
    { -28.00, 60.00 },
    { -28.00, 63.00 }, -- carried on to meet the chamber
}

-- Chamber. The owner dragged four corners into an irregular quad; the BOUNDING BOX was
-- taken (stated default, owner did not ask for the quad). Then, 2026-08-16, the owner
-- asked to double the floor area by pushing the WEST wall west: -37.99 -> -58.
local ROOM_X_W, ROOM_X_E = -58.00, -17.83
local ROOM_Z_N, ROOM_Z_S = 62.00, 85.22
local FLOOR_BOTTOM = 112.30 -- carve 1 below the sill; voxel aliasing lands the floor ~114
local ROOM_ROOF = 135.0 -- aliases down to a measured 134.00
local MIN_ROOF = 129.0 -- never LOWER the ceiling below what the first cut gave
local MIN_CAP = 11.0 -- ceiling never comes closer than this to the hillside above
local BORE_W = 8.0 -- ~6-7 net after aliasing, matching the 6.0 door

-- The berm. There was NO ROCK to bore through: natural grade behind the rear door
-- topped out at 120.29 — the door head exactly — so the first ~8 studs would have been
-- an open trench. The hillside was RAISED, threading the eave.
local BERM_X_W, BERM_X_E = -35.5, -23.5
local BERM_BASE = 118.0

-- ============================================================================
local T = workspace.Terrain
local rc = RaycastParams.new()
rc.FilterType = Enum.RaycastFilterType.Include
rc.FilterDescendantsInstances = { T }

local function surf(x: number, z: number): number?
    local h = workspace:Raycast(Vector3.new(x, 700, z), Vector3.new(0, -1400, 0), rc)
    return h and h.Position.Y or nil
end
local function probe(x: number, z: number): (number?, number?)
    local d = workspace:Raycast(Vector3.new(x, 117, z), Vector3.new(0, -40, 0), rc)
    local u = workspace:Raycast(Vector3.new(x, 117, z), Vector3.new(0, 60, 0), rc)
    return d and d.Position.Y or nil, u and u.Position.Y or nil
end
local function xAt(z: number): number
    if z <= ROUTE[1][2] then
        return ROUTE[1][1]
    end
    for i = 1, #ROUTE - 1 do
        if z <= ROUTE[i + 1][2] then
            local t = (z - ROUTE[i][2]) / (ROUTE[i + 1][2] - ROUTE[i][2])
            return ROUTE[i][1] + t * (ROUTE[i + 1][1] - ROUTE[i][1])
        end
    end
    return ROUTE[#ROUTE][1]
end
-- Roof: pinned to the top of the lintel at the mouth so the tunnel meets the door
-- without a step, then ramping to full height once there is rock overhead.
local function roofAt(z: number): number
    return math.min(124.3, LINTEL_TOP + math.max(0, z - 44.5) * 0.85)
end
local function bermTop(z: number): number
    if z <= 44.3 then
        return 125.0
    end
    return math.min(125.0 + (z - 44.3) * 0.96, 129.5)
end
local function eaveCeil(z: number): number
    return math.min(125.2 + math.max(0, EAVE_Z - z) * EAVE_SLOPE, 127.0)
end

local out: { string } = {}
local function say(s: string)
    table.insert(out, s)
end

if MODE == "VERIFY" then
    say("STATS CAVERN — as-built verify (no terrain written)")
    say(
        ("  DOORWAY it must meet: x %.2f, rear wall face z %.2f, sill %.2f, head %.2f (%.2f clear)"):format(
            DOOR_X,
            WALL_OUTER_Z,
            SILL,
            DOOR_HEAD,
            DOOR_HEAD - SILL
        )
    )
    local tf1, tf2, tmin, breach = 1e9, -1e9, 1e9, 0
    for z = 43, 61, 0.5 do
        local f, c = probe(xAt(z), z)
        if not c then
            breach += 1
        end
        if f then
            tf1, tf2 = math.min(tf1, f), math.max(tf2, f)
        end
        if f and c then
            tmin = math.min(tmin, c - f)
        end
    end
    say(
        ("  TUNNEL floor %.2f..%.2f | min clear %.2f (must not undercut the door's %.2f) | breaches %d"):format(
            tf1,
            tf2,
            tmin,
            DOOR_HEAD - SILL,
            breach
        )
    )

    local fmin, fmax, capmin = 1e9, -1e9, 1e9
    local minx, maxx, minz, maxz = 1e9, -1e9, 1e9, -1e9
    for x = -62, -14, 1 do
        for z = 58, 90, 1 do
            local inTunnel = x > -33.5 and x < -23.5 and z < 62
            if not inTunnel then
                local f, c = probe(x, z)
                if f and c and (c - f) >= 10 then
                    minx, maxx = math.min(minx, x), math.max(maxx, x)
                    minz, maxz = math.min(minz, z), math.max(maxz, z)
                    fmin, fmax = math.min(fmin, f), math.max(fmax, f)
                    local s = surf(x, z)
                    if s then
                        capmin = math.min(capmin, s - c)
                    end
                end
            end
        end
    end
    say(
        ("  CHAMBER x[%.1f,%.1f] %.1f wide | z[%.1f,%.1f] %.1f deep | floor %.2f..%.2f"):format(
            minx,
            maxx,
            maxx - minx,
            minz,
            maxz,
            maxz - minz,
            fmin,
            fmax
        )
    )
    -- Extents come from a `clear >= 10` filter, so measuring min-clear over THAT set is
    -- self-referential and always reports ~10. Re-measure over an inset interior instead,
    -- which is also what a player actually walks in.
    local icl, icap, ifl1, ifl2 = 1e9, 1e9, 1e9, -1e9
    for x = minx + 3, maxx - 3, 1 do
        for z = minz + 3, maxz - 3, 1 do
            local f, c = probe(x, z)
            if f and c then
                icl = math.min(icl, c - f)
                ifl1, ifl2 = math.min(ifl1, f), math.max(ifl2, f)
                local s = surf(x, z)
                if s then
                    icap = math.min(icap, s - c)
                end
            end
        end
    end
    say(
        ("  INTERIOR (3 studs inset): floor %.2f..%.2f | min clear %.2f | thinnest cap %.2f"):format(
            ifl1,
            ifl2,
            icl,
            icap
        )
    )
    say(
        ("  (boundary-inclusive figures: floor %.2f..%.2f, cap %.2f — walls curving in, not defects)"):format(
            fmin,
            fmax,
            capmin
        )
    )

    local worst = -1e9
    for z = 40, EAVE_Z, 0.25 do
        for x = -34.42, -23.42, 0.5 do
            local s = surf(x, z)
            if s and s > worst then
                worst = s
            end
        end
    end
    say(
        ("  EAVE clearance: highest terrain %.2f vs RoofSouth lowest corner %.2f -> %+.2f"):format(
            worst,
            EAVE_Y,
            EAVE_Y - worst
        )
    )
    say("")
    say("  expected as-built (2026-08-16): tunnel clear >= 7.6, chamber 40.5 x 26.0,")
    say("  floor 114.00, ceiling 134.00, cap >= 13.8, eave clearance positive, 0 breaches.")
    return table.concat(out, "\n")
end

-- ============================================================================
-- BORE (destructive). Refuses if the chamber already exists.
-- ============================================================================
do
    local _, c = probe(-38, 74)
    if c then
        return "REFUSING: the chamber already exists, and the owner hand-shaped terrain at the mouth "
            .. "after it was cut. Restore from a ServerStorage snapshot first if you really mean to re-bore."
    end
end

local snapR = Region3.new(Vector3.new(-64, 96, 36), Vector3.new(-12, 184, 96)):ExpandToGrid(4)
local mn, mx = snapR.CFrame.Position - snapR.Size / 2, snapR.CFrame.Position + snapR.Size / 2
local snap = T:CopyRegion(
    Region3int16.new(
        Vector3int16.new(mn.X / 4, mn.Y / 4, mn.Z / 4),
        Vector3int16.new(mx.X / 4, mx.Y / 4, mx.Z / 4)
    )
)
snap.Name = "StatsCavern_PreBore"
snap.Parent = game:GetService("ServerStorage")

-- 1. BERM. Thin slices with the top computed at EACH slice's own z. A flat-topped box
--    5 deep over a ramping target overshoots by the ramp's rise across the box.
for z = 44.5, 51.0, 0.5 do
    local top = bermTop(z)
    T:FillBlock(
        CFrame.new((BERM_X_W + BERM_X_E) / 2, (top + BERM_BASE) / 2, z),
        Vector3.new(BERM_X_E - BERM_X_W, top - BERM_BASE, 2),
        Enum.Material.Slate
    )
    T:FillBlock(
        CFrame.new((BERM_X_W + BERM_X_E) / 2, top - 1.5, z),
        Vector3.new(BERM_X_E - BERM_X_W, 3, 2),
        Enum.Material.Ground
    )
end
-- 2. EAVE TRIM: follow the sloping roof underside so the berm never touches it.
for z = 39.0, 44.35, 0.25 do
    T:FillBlock(CFrame.new(-29.0, eaveCeil(z) + 12, z), Vector3.new(15, 24, 1.5), Enum.Material.Air)
end
-- 3. TUNNEL.
for z = 43.0, 63.0, 0.5 do
    local top = roofAt(z)
    T:FillBlock(
        CFrame.new(xAt(z), (top + FLOOR_BOTTOM) / 2, z),
        Vector3.new(BORE_W, top - FLOOR_BOTTOM, 4),
        Enum.Material.Air
    )
end
-- 4. CHAMBER. Carve 1.5 PROUD of the intended wall: boundary boxes have no successor to
--    overlap with, so the finished wall erodes ~1.5 inward from the carve edge.
local cx = (ROOM_X_W - 1.5 + ROOM_X_E) / 2
local cw = ROOM_X_E - (ROOM_X_W - 1.5)
for z = ROOM_Z_N - 0.5, ROOM_Z_S + 0.5, 1.5 do
    T:FillBlock(
        CFrame.new(cx, (ROOM_ROOF + FLOOR_BOTTOM) / 2, z),
        Vector3.new(cw, ROOM_ROOF - FLOOR_BOTTOM, 5),
        Enum.Material.Air
    )
end
-- 5. CEILING, per tile, never closer than MIN_CAP to the hillside. Holds a flat 134
--    everywhere the rock allows and steps down only at the thin north-east entry corner.
for z = ROOM_Z_N - 0.5, ROOM_Z_S + 0.5, 1.5 do
    for xc = ROOM_X_W - 1.5 + 4.5, ROOM_X_E - 4.5 + 0.01, 6.0 do
        local ms = 1e9
        for x = xc - 4.5, xc + 4.5, 1.5 do
            for zz = z - 2.5, z + 2.5, 1.5 do
                local s = surf(x, zz)
                if s and s < ms then
                    ms = s
                end
            end
        end
        local roof = math.clamp(math.min(ROOM_ROOF, ms - MIN_CAP), MIN_ROOF, ROOM_ROOF)
        T:FillBlock(
            CFrame.new(xc, (roof + FLOOR_BOTTOM) / 2, z),
            Vector3.new(9, roof - FLOOR_BOTTOM, 5),
            Enum.Material.Air
        )
    end
end

return "BORED. Snapshot at ServerStorage.StatsCavern_PreBore. NOTE: terrain writes are NOT "
    .. 'visible to raycasts within this same execution — re-run with MODE = "VERIFY" to measure.'
