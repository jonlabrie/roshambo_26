--!strict
local harness = require("./harness")
local Chaya = require("../tools/builders/Chaya")
local ZenDojo = require("../src/shared/themes/ZenDojo")
local ArenaLayout = require("../tools/builders/ArenaLayout")
local describe, test, expect = harness.describe, harness.test, harness.expect

local m = Chaya.build(ZenDojo.palette, ArenaLayout)

-- Every BasePart in the tree. A node with no CFrame is not one: the chōchin carries
-- SurfaceGuis and their labels for its glyph plates, and those have neither size nor
-- position to reason about.
local function allParts(node: any, out: { any }?): { any }
    local acc = out or {}
    for _, c in node.children or {} do
        if c.className ~= "Model" and c.properties and c.properties.CFrame and c.properties.Size then
            table.insert(acc, c)
        end
        allParts(c, acc)
    end
    return acc
end

local function find(node: any, name: string): any
    for _, c in node.children or {} do
        if c.name == name then
            return c
        end
        local deeper = find(c, name)
        if deeper then
            return deeper
        end
    end
    return nil
end

local function findPrefix(node: any, prefix: string): { any }
    local hits = {}
    for _, p in allParts(node) do
        if (p.name :: string):sub(1, #prefix) == prefix then
            table.insert(hits, p)
        end
    end
    return hits
end

-- Axis-aligned bounds. The chaya is built in world coordinates at yaw 0 (its front faces
-- north, which is -Z here), so a part's own size IS its extent -- except the roof planes,
-- which are pitched about X and are excluded wherever that would matter.
local function bounds(p: any): (number, number, number, number, number, number)
    local cf, s = p.properties.CFrame, p.properties.Size
    -- ORIENTED, not naive. Half this model is rotated: the posts are stood-up cylinders whose
    -- long axis is their local X, the sudare lies along Z, the verge rolls run up the roof
    -- pitch at an angle that is no axis at all. Reading Size straight off gives a post a
    -- third-of-a-stud head and a ten-stud girth. Each world extent is the row of the rotation
    -- matrix dotted with the half-size, absolute — the standard box-AABB.
    local hx, hy, hz = s[1] / 2, s[2] / 2, s[3] / 2
    local ex = math.abs(cf[4]) * hx + math.abs(cf[5]) * hy + math.abs(cf[6]) * hz
    local ey = math.abs(cf[7]) * hx + math.abs(cf[8]) * hy + math.abs(cf[9]) * hz
    local ez = math.abs(cf[10]) * hx + math.abs(cf[11]) * hy + math.abs(cf[12]) * hz
    return cf[1] - ex, cf[1] + ex, cf[2] - ey, cf[2] + ey, cf[3] - ez, cf[3] + ez
end

local function intersects(a: any, b: any): boolean
    local ax0, ax1, ay0, ay1, az0, az1 = bounds(a)
    local bx0, bx1, by0, by1, bz0, bz1 = bounds(b)
    return ax0 < bx1 and bx0 < ax1 and ay0 < by1 and by0 < ay1 and az0 < bz1 and bz0 < az1
end

describe("Chaya — the round posts the owner asked for", function()
    test("EVERY support post is a cylinder, not a box", function()
        -- Owner's one style note, 2026-08-17: "all deck/chaya floor support posts should be
        -- round, not square." A box post is the default a builder falls into, so this is
        -- pinned rather than trusted.
        local posts = findPrefix(m, "Post")
        expect(#posts >= 12).toBe(true) -- 12 under the dock, 6 under the chaya
        for _, p in posts do
            expect(p.properties.Shape).toBe("Cylinder")
        end
    end)

    test("and every one of them stands UP", function()
        -- A Roblox cylinder's long axis is local X. Left at identity it lies on its side,
        -- which is a log, not a post -- so the vertical aim is part of "round".
        for _, p in findPrefix(m, "Post") do
            local cf = p.properties.CFrame
            -- CYL_VERTICAL = { 0,-1,0, 1,0,0, 0,0,1 }: local X aims at world +Y
            expect(cf[4]).toBe(0)
            expect(cf[5]).toBe(-1)
            expect(cf[7]).toBe(1)
        end
    end)

    test("a post is as wide as it is deep — round in plan, not an oval", function()
        for _, p in findPrefix(m, "Post") do
            local s = p.properties.Size
            expect(math.abs(s[2] - s[3]) < 0.001).toBe(true)
        end
    end)
end)

describe("Chaya — the counter splits the floor", function()
    test("keeper behind, customers in front", function()
        local counter = find(m, "CounterTop")
        local slot = find(m, "ChayaKeeperSlot")
        local bench = find(m, "Bench")
        expect(counter ~= nil).toBe(true)
        expect(slot ~= nil).toBe(true)
        expect(bench ~= nil).toBe(true)
        -- The chaya faces NORTH (-Z): the water and the dock are at lower z, the bank at
        -- higher z. So the keeper's side is the +Z side of the counter and the customers'
        -- side is -Z, and the bench sits with its back to the bank looking out over the water.
        local _, _, _, _, cz0, cz1 = bounds(counter)
        local _, _, _, _, sz0, _ = bounds(slot)
        local _, _, _, _, _, bz1 = bounds(bench)
        expect(sz0 >= cz1).toBe(true) -- slot begins at or behind the counter's back face
        expect(bz1 <= cz0).toBe(true) -- bench ends at or in front of its front face
    end)

    test("the keeper's slot is a place a person fits, and nothing is standing in it", function()
        local slot = find(m, "ChayaKeeperSlot")
        local s = slot.properties.Size
        -- Across is the measurement that matters: an avatar is about two studs wide and one
        -- deep, and the strip behind a yatai counter is narrow by design (the counter moved
        -- two studs south at the owner's look, 2026-08-17).
        expect(s[1] >= 3.5).toBe(true)
        expect(s[3] >= 1.6).toBe(true)
        expect(s[2] >= 6.0).toBe(true) -- head height, in studs-as-feet
        expect(slot.properties.Transparency).toBe(1)
        expect(slot.properties.CanCollide).toBe(false)
        expect(slot.properties.CanQuery).toBe(false)
        for _, p in allParts(m) do
            local n = p.name :: string
            -- The roof planes are PITCHED, so an axis-aligned box round one overstates its
            -- extent by more than a stud; headroom under them is checked on its own below.
            local pitched = n:sub(1, 6) == "Thatch" or n:sub(1, 6) == "Rafter" or n:sub(1, 5) == "Ridge"
            if n ~= "ChayaKeeperSlot" and not pitched then
                expect(intersects(p, slot)).toBe(false)
            end
        end
    end)

    test("the roof clears the keeper's head at the back of the slot", function()
        -- The slot's far corner is where the roof is lowest over it. Computed from the
        -- builder's own pitch rather than a literal, so a re-pitched roof re-checks itself.
        local slot = find(m, "ChayaKeeperSlot")
        local _, _, _, sy1, _, sz1 = bounds(slot)
        expect(Chaya.roofUndersideAt(sz1) > sy1).toBe(true)
    end)

    test("the gear is a step and a reach from the slot, not across the room", function()
        local slot = find(m, "ChayaKeeperSlot")
        local cf = slot.properties.CFrame
        for _, name in { "Brazier", "Kettle", "CaddyShelf" } do
            local g = find(m, name)
            expect(g ~= nil).toBe(true)
            local dx = g.properties.CFrame[1] - cf[1]
            local dz = g.properties.CFrame[3] - cf[3]
            expect(math.sqrt(dx * dx + dz * dz) <= 6).toBe(true)
        end
    end)
end)

describe("Chaya — somewhere to sit, and somewhere to be served", function()
    -- Owner, 2026-08-17: "could someone actually sit and be served in that spot? Feels like
    -- it's tight for a customer." They could not. The bench faced the river with its back
    -- six inches off a 36-inch counter -- standing-service height -- so the keeper would have
    -- been serving over the back of a sitter's head. The answer is both seats, each honest
    -- about its job: stools pulled up to the counter, and the endai bench out at the rail.

    test("three round stools stand at the counter, at stool height", function()
        local stools = findPrefix(m, "Stool")
        expect(#stools).toBe(3)
        local floorTop = select(4, bounds(find(m, "ChayaBoard_1")))
        for _, s in stools do
            expect(s.properties.Shape).toBe("Cylinder")
            local _, _, _, y1 = bounds(s)
            local h = y1 - floorTop
            -- 2 studs is 24 inches against a 36-inch counter: a foot of reach, which is what
            -- a counter stool is. An 18-inch bench seat at the same counter is not.
            expect(h >= 1.8 and h <= 2.2).toBe(true)
        end
    end)

    test("a stool is close enough to the counter to be served at", function()
        local counterFront = select(5, bounds(find(m, "CounterTop")))
        for _, s in findPrefix(m, "Stool") do
            local _, _, _, _, _, sz1 = bounds(s)
            expect(counterFront - sz1 <= 0.8).toBe(true)
        end
    end)

    test("the bench is out at the rail, facing the water, clear of everything", function()
        local bench = find(m, "Bench")
        local _, _, _, _, bz0, bz1 = bounds(bench)
        local rail = find(m, "FrontRail")
        local _, _, _, _, _, rz1 = bounds(rail)
        expect(bz0 > rz1).toBe(true) -- inboard of the front rail
        for _, s in findPrefix(m, "Stool") do
            expect(intersects(bench, s)).toBe(false)
        end
        for _, p in findPrefix(m, "PostChaya") do
            expect(intersects(bench, p)).toBe(false) -- it used to run through the middle post
        end
    end)

    test("nobody sits on a cushion that is under the furniture", function()
        for _, c in findPrefix(m, "Cushion") do
            expect(intersects(c, find(m, "Bench"))).toBe(false)
            for _, s in findPrefix(m, "Stool") do
                expect(intersects(c, s)).toBe(false)
            end
        end
    end)
end)

describe("Chaya — the thatch is bundled, not cut", function()
    test("every edge of the roof is rolled", function()
        -- Owner, 2026-08-17: "it would be nice if we could round the edges somehow, right now
        -- it reads as a block of thatch." A Roblox part is a box, so the roll is real
        -- geometry: a bundle along each eave and each verge, which is how a thatcher finishes
        -- an edge anyway.
        expect(#findPrefix(m, "EaveRoll") == 2).toBe(true)
        expect(#findPrefix(m, "VergeRoll") == 4).toBe(true)
        for _, r in findPrefix(m, "EaveRoll") do
            expect(r.properties.Shape).toBe("Cylinder")
            expect(r.properties.MaterialVariant).toBe("Thatch")
        end
        for _, r in findPrefix(m, "VergeRoll") do
            expect(r.properties.Shape).toBe("Cylinder")
            expect(r.properties.MaterialVariant).toBe("Thatch")
        end
    end)

    test("the rolls wrap the roof's edge rather than hanging off its underside", function()
        -- Owner, 2026-08-17: "their centerlines appear to be aligned with the bottom edges of
        -- the thatched roof." They were -- the rolls were placed at the slab's bottom face,
        -- so each read as a pipe stuck under the eave instead of as the edge of the thatch
        -- itself. A roll's centreline belongs on the slab's own mid-plane, which is what the
        -- eave and ridge heights ARE by construction.
        -- and NO LIP: a roll that stands proud of the roof's top face reads as a rim running
        -- round the building rather than as the edge of the thatch itself.
        for _, r in findPrefix(m, "EaveRoll") do
            local _, _, y0, y1, z0, z1 = bounds(r)
            local mid = (y0 + y1) / 2
            expect(mid < Chaya.EAVE_Y).toBe(true) -- dropped below the slab's centreline
            expect(mid > Chaya.EAVE_Y - 0.4).toBe(true) -- but still ON the edge, not under it
            expect(y1 <= Chaya.roofTopAt((z0 + z1) / 2) + 0.01).toBe(true)
        end
        for _, r in findPrefix(m, "VergeRoll") do
            local _, _, y0, y1 = bounds(r)
            local mid = (Chaya.EAVE_Y + Chaya.RIDGE_Y) / 2
            expect(math.abs((y0 + y1) / 2 - mid) < 0.35).toBe(true)
        end
    end)

    test("the rolls meet at the corners on their OUTSIDE faces, not their centres", function()
        -- They used to stop on each other's centrelines, which leaves a quarter-round notch
        -- at every corner of the roof -- the one place the eye goes to read the silhouette.
        local ex0, ex1 = math.huge, -math.huge
        for _, r in findPrefix(m, "EaveRoll") do
            local x0, x1 = bounds(r)
            ex0, ex1 = math.min(ex0, x0), math.max(ex1, x1)
        end
        for _, r in findPrefix(m, "VergeRoll") do
            local x0, x1 = bounds(r)
            -- the eave run reaches the verge roll's far side, so the corner is filled
            expect(x0 >= ex0 - 0.01 and x1 <= ex1 + 0.01).toBe(true)
        end
        -- On the slope axis it is the other way about: the verge DIES INTO the eave roll. It
        -- must reach the eave roll's centreline -- short of that leaves the notch -- and must
        -- not poke out past its surface, which is the wonk that overshooting produced.
        local eaves = findPrefix(m, "EaveRoll")
        for _, r in findPrefix(m, "VergeRoll") do
            local _, _, _, _, vz0, vz1 = bounds(r)
            local ok = false
            for _, e in eaves do
                local _, _, _, _, ez0, ez1 = bounds(e)
                local axis = (ez0 + ez1) / 2
                if vz0 <= axis + 0.01 and vz0 >= ez0 - 0.01 then
                    ok = true -- north corner: reaches the axis, stays inside the surface
                elseif vz1 >= axis - 0.01 and vz1 <= ez1 + 0.01 then
                    ok = true -- south corner, same test mirrored
                end
            end
            expect(ok).toBe(true)
        end
    end)

    test("the eave rolls sit on the eave lines, not somewhere near them", function()
        local zs = {}
        for _, r in findPrefix(m, "EaveRoll") do
            local _, _, _, _, z0, z1 = bounds(r)
            table.insert(zs, (z0 + z1) / 2)
        end
        table.sort(zs)
        expect(math.abs(zs[1] - Chaya.ROOF_Z0) < 0.3).toBe(true)
        expect(math.abs(zs[2] - (2 * Chaya.RIDGE_Z - Chaya.ROOF_Z0)) < 0.3).toBe(true)
    end)
end)

describe("Chaya — the dock it is butted against", function()
    test("deck boards end on the frame, never past it", function()
        local frameW = find(m, "DockFrameWest")
        local frameE = find(m, "DockFrameEast")
        local frameN = find(m, "DockFrameNorth")
        local frameS = find(m, "DockFrameSouth")
        expect(frameW ~= nil and frameE ~= nil and frameN ~= nil and frameS ~= nil).toBe(true)
        local x0 = select(1, bounds(frameW))
        local x1 = select(2, bounds(frameE))
        local z0 = select(5, bounds(frameN))
        local z1 = select(6, bounds(frameS))
        local boards = findPrefix(m, "DockBoard")
        expect(#boards > 0).toBe(true)
        for _, b in boards do
            local bx0, bx1, _, _, bz0, bz1 = bounds(b)
            expect(bx0 >= x0 - 0.001 and bx1 <= x1 + 0.001).toBe(true)
            expect(bz0 >= z0 - 0.001 and bz1 <= z1 + 0.001).toBe(true)
        end
    end)

    test("every dock post reaches the bed it was probed on", function()
        -- Surveyed 2026-08-17: the river surface reads 109.92 and the bed 101.7-102.0 under
        -- the north rows, shelving up to 108.5 at the east bank. A post that stops short of
        -- its own probe hangs in the water, so each one is held against its foot rather than
        -- against a single depth that is only true for six of the nine.
        local posts = findPrefix(m, "PostDock")
        expect(#posts).toBe(#Chaya.DOCK_POSTS)
        for i, p in posts do
            local foot = Chaya.DOCK_POSTS[i][3]
            local _, _, y0 = bounds(p)
            -- a shallow foot is clamped to MIN_POST so the post still buries
            expect(y0 <= foot + 0.001 or y0 <= Chaya.DECK_TOP - Chaya.MIN_POST + 0.001).toBe(true)
        end
        local deep = 0
        for i, f in Chaya.DOCK_POSTS do
            if f[3] < 103 then
                deep += 1
            end
        end
        expect(deep >= 5).toBe(true) -- most of it really is standing in the river
    end)

    test("you step UP from the dock into the chaya, and the step is there", function()
        local deck = find(m, "DockBoard_1")
        local floor = find(m, "ChayaBoard_1")
        local step = find(m, "Step_1")
        expect(step ~= nil).toBe(true)
        local _, _, _, deckTop = bounds(deck)
        local _, _, _, floorTop = bounds(floor)
        local _, _, _, stepTop = bounds(step)
        expect(floorTop > deckTop).toBe(true)
        expect(stepTop > deckTop and stepTop < floorTop).toBe(true)
        -- No riser taller than a comfortable step, in studs-as-feet.
        expect(floorTop - stepTop <= 1.1).toBe(true)
        expect(stepTop - deckTop <= 1.1).toBe(true)
    end)

    test("dock and chaya share their edge — butted, not overlapping and not gapped", function()
        local dockS = find(m, "DockFrameSouth")
        local chayaN = find(m, "ChayaFrameNorth")
        local _, _, _, _, _, dz1 = bounds(dockS)
        local _, _, _, _, cz0, _ = bounds(chayaN)
        expect(math.abs(cz0 - dz1) < 0.001).toBe(true)
    end)
end)

describe("Chaya — the engineering holds up", function()
    -- Owner, 2026-08-17: "your chaya looks great but the engineering is suspect." It was.
    -- Boards ran the full width of both decks with nothing under them, the girders were
    -- laid PARALLEL to the boards (so they carried nothing), the roof had no ridge member,
    -- and the rolled blind hung off nothing at all. These pin the frame that fixed it.

    for _, deck in { "Dock", "Chaya" } do
        test(`{deck} boards are carried by joists, not spanning on faith`, function()
            local joists = findPrefix(m, deck .. "Joist")
            expect(#joists >= 4).toBe(true)
            local xs = {}
            for _, j in joists do
                -- a joist runs ACROSS the boards: long in z, narrow in x
                local jx0, jx1, _, _, jz0, jz1 = bounds(j)
                expect(jz1 - jz0 > jx1 - jx0).toBe(true)
                table.insert(xs, (jx0 + jx1) / 2)
            end
            table.sort(xs)
            for i = 2, #xs do
                -- no board spans further than this between supports
                expect(xs[i] - xs[i - 1] <= 3.0).toBe(true)
            end
            -- and the outermost joists reach the frame, so the edge boards are carried too
            local fw = find(m, deck .. "FrameWest")
            local fe = find(m, deck .. "FrameEast")
            expect(xs[1] - select(1, bounds(fw)) <= 3.0).toBe(true)
            expect(select(2, bounds(fe)) - xs[#xs] <= 3.0).toBe(true)
        end)

        test(`{deck} joists bear on the girders beneath them`, function()
            local joist = find(m, deck .. "Joist_1")
            local girder = find(m, deck .. "Girder_1")
            expect(joist ~= nil and girder ~= nil).toBe(true)
            local _, _, jy0 = bounds(joist)
            local _, _, _, gy1 = bounds(girder)
            expect(math.abs(jy0 - gy1) < 0.01).toBe(true)
        end)
    end

    test("the dock's girders stand on the tops of its posts", function()
        -- The chaya's posts run THROUGH to the eave, so its girders cross them; the dock's
        -- stop under the deck and must actually carry it.
        local girder = find(m, "DockGirder_1")
        local _, _, gy0 = bounds(girder)
        local carried = 0
        for _, p in findPrefix(m, "PostDock") do
            local _, _, _, py1 = bounds(p)
            if math.abs(py1 - gy0) < 0.01 then
                carried += 1
            end
        end
        expect(carried >= 4).toBe(true)
    end)

    test("the roof has a ridge member, and something holds it up", function()
        local purlin = find(m, "RidgePurlin")
        expect(purlin ~= nil).toBe(true)
        local px0, px1, py0 = bounds(purlin)
        expect(px1 - px0 >= 10).toBe(true) -- it runs the length of the building
        local kings = findPrefix(m, "KingPost")
        expect(#kings >= 2).toBe(true)
        for _, k in kings do
            local _, _, ky0, ky1 = bounds(k)
            expect(math.abs(ky1 - py0) < 0.02).toBe(true) -- head under the purlin
            local seated = false
            for _, tie in findPrefix(m, "TieBeam") do
                local tx0, tx1, _, ty1, tz0, tz1 = bounds(tie)
                local kx0, kx1, _, _, kz0, kz1 = bounds(k)
                if
                    math.abs(ky0 - ty1) < 0.02
                    and kx0 >= tx0 - 0.01
                    and kx1 <= tx1 + 0.01
                    and kz0 >= tz0 - 0.01
                    and kz1 <= tz1 + 0.01
                then
                    seated = true
                end
            end
            expect(seated).toBe(true) -- foot on a tie beam, not in the air
        end
    end)

    test("the tie beams reach from plate to plate", function()
        local ties = findPrefix(m, "TieBeam")
        expect(#ties >= 2).toBe(true)
        for _, tie in ties do
            local _, _, _, _, z0, z1 = bounds(tie)
            expect(z1 - z0 >= 9).toBe(true)
        end
    end)

    test("the sudare runs the full bay and hangs from a beam", function()
        -- It used to float in mid-air by the west end, reaching neither post: 5.4 of blind
        -- in a 9.3 bay, with nothing above it. The owner spotted it from across the room.
        local blind = find(m, "Sudare")
        local hangs = find(m, "SudareBeam")
        expect(blind ~= nil and hangs ~= nil).toBe(true)
        local _, _, _, by1, bz0, bz1 = bounds(blind)
        local _, _, hy0, _, hz0, hz1 = bounds(hangs)
        expect(bz1 - bz0 >= 9).toBe(true) -- post to post
        expect(hz1 - hz0 >= 9).toBe(true)
        expect(hy0 - by1 <= 0.4 and hy0 - by1 >= -0.01).toBe(true) -- slung right under it
    end)

    test("the rear shelf lands on the rear posts", function()
        local shelf = find(m, "CaddyShelf")
        local x0, x1 = bounds(shelf)
        expect(x0 <= -51.5 and x1 >= -41.3).toBe(true)
    end)
end)

describe("Chaya — rougher, and open to the air", function()
    test("it has no walls at all", function()
        -- The owner's second note: this vendor is rougher than the machiya row, so it is a
        -- pavilion. Posts, a roof and a counter -- nothing to close it in.
        for _, p in allParts(m) do
            local n = (p.name :: string):lower()
            expect(n:find("wall") == nil).toBe(true)
            expect(n:find("shoji") == nil).toBe(true)
            expect(n:find("door") == nil).toBe(true)
        end
    end)

    test("the roof is thatch on exposed rafters, not the row's kawara", function()
        local thatch = findPrefix(m, "Thatch")
        expect(#thatch == 2).toBe(true)
        for _, t in thatch do
            -- Grass is the BaseMaterial the variant is registered against (a part only wears a
            -- variant when its Material matches), and the honest fallback where the variant
            -- does not load: a thatched roof reading as grass is the right kind of wrong.
            expect(t.properties.Material).toBe("Grass")
            expect(t.properties.MaterialVariant).toBe("Thatch")
        end
        expect(find(m, "RidgeBundle").properties.MaterialVariant).toBe("Thatch")
        expect(#findPrefix(m, "Rafter") >= 6).toBe(true)
        expect(find(m, "RidgeBundle") ~= nil).toBe(true)
    end)

    test("the roof is not upside down", function()
        -- A pitched slab's local +Z end drops as the X-rotation goes positive, which has
        -- inverted a roof in this repo before. Walk each plane's own ends and check the
        -- ridge end is the high one.
        for _, t in findPrefix(m, "Thatch") do
            local cf = t.properties.CFrame
            local half = t.properties.Size[3] / 2
            -- world offset of the local +Z end: column 3 of the rotation, times the half-length
            local endHiY = cf[2] + cf[9] * half
            local endLoY = cf[2] - cf[9] * half
            local endHiZ = cf[3] + cf[12] * half
            local endLoZ = cf[3] - cf[12] * half
            -- whichever end is nearer the ridge line must be the higher one
            local ridgeZ = Chaya.RIDGE_Z
            if math.abs(endHiZ - ridgeZ) < math.abs(endLoZ - ridgeZ) then
                expect(endHiY > endLoY).toBe(true)
            else
                expect(endLoY > endHiY).toBe(true)
            end
        end
    end)

    test("the eave reaches out over the dock, so the counter is sheltered", function()
        local chayaN = find(m, "ChayaFrameNorth")
        local _, _, _, _, cz0 = bounds(chayaN)
        expect(Chaya.ROOF_Z0 < cz0 - 1.5).toBe(true)
    end)

    test("the chōchin is red, and as red as the glyph will allow", function()
        -- Owner's ruling, 2026-08-17, overriding the row's no-true-red rule. What it cannot
        -- override is the legibility floor: the paper sits behind an untinted plate carrying
        -- the World Throw, so a barrel darker than 0.55 relative luminance swallows the glyph
        -- at night. This pins the tint on the right side of that line, since the Chochin
        -- guard only walks MachiyaShops and would never see this one.
        local Chochin = require("../tools/builders/Chochin")
        local rgb = Chaya.LANTERN_PAPER
        expect(rgb[1] > rgb[2] and rgb[2] > rgb[3]).toBe(true) -- it is a red, not a cream
        local lum = Chochin.luminance({ rgb[1] / 255, rgb[2] / 255, rgb[3] / 255 })
        expect(lum >= Chochin.LEGIBILITY_FLOOR).toBe(true)
    end)

    test("and it hangs off a rafter tail, not off thin air", function()
        local hook = find(m, "Hook")
        expect(hook ~= nil).toBe(true)
        local hx, _, _, hy1, hz0, hz1 = bounds(hook)
        local hz = (hz0 + hz1) / 2
        local near = false
        for _, r in findPrefix(m, "RafterNorth") do
            local cf = r.properties.CFrame
            local half = r.properties.Size[3] / 2
            -- the tail is the plane's LOW end: walk both ends and take the lower
            local ay, az = cf[2] + cf[9] * half, cf[3] + cf[12] * half
            local by, bz = cf[2] - cf[9] * half, cf[3] - cf[12] * half
            local ty, tz = ay, az
            if by < ay then
                ty, tz = by, bz
            end
            if math.abs(hx - cf[1]) < 0.5 and math.abs(hz - tz) < 0.5 and math.abs(hy1 - ty) < 0.5 then
                near = true
            end
        end
        expect(near).toBe(true)
    end)

    test("a half-noren hangs at the front, and one chōchin", function()
        expect(#findPrefix(m, "Noren") == 3).toBe(true)
        for _, n in findPrefix(m, "Noren") do
            expect(n.properties.MaterialVariant).toBe("NorenCloth")
        end
        expect(find(m, "ChochinChaya") ~= nil).toBe(true)
    end)
end)

describe("Chaya — it stays on the ground it was surveyed against", function()
    test("nothing strays outside the site", function()
        -- The pair was surveyed at x -52..-41, z -3..17. A part outside that has been
        -- placed by arithmetic rather than by the survey.
        for _, p in allParts(m) do
            local x0, x1, _, _, z0, z1 = bounds(p)
            expect(x0 > -56 and x1 < -36).toBe(true)
            expect(z0 > -6 and z1 < 21).toBe(true)
        end
    end)

    test("every post foot is buried, never floating", function()
        -- Each post's baked foot is a terrain probe. A post that stops above the deck it
        -- carries is standing on nothing -- and the two structures sit at different levels,
        -- so each is checked against its own.
        for _, p in findPrefix(m, "PostDock") do
            local _, _, y0 = bounds(p)
            expect(y0 < Chaya.DECK_TOP).toBe(true)
        end
        for _, p in findPrefix(m, "PostChaya") do
            local _, _, y0 = bounds(p)
            expect(y0 < Chaya.FLOOR).toBe(true)
        end
    end)
end)
