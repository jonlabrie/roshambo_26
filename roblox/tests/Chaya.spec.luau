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
    local ex, ey, ez = s[1] / 2, s[2] / 2, s[3] / 2
    -- A STOOD-UP CYLINDER MEASURES DIFFERENTLY. Its long axis is local X, and CYL_VERTICAL
    -- aims that at world Y -- so Size.X is the post's HEIGHT and Size.Y/Z are its diameter.
    -- Reading the size straight off would give every post a third-of-a-stud head and a
    -- ten-stud girth, which is the shape of a fallen log.
    if p.properties.Shape == "Cylinder" and cf[5] == -1 then
        ex, ey, ez = s[2] / 2, s[1] / 2, s[3] / 2
    end
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
            expect(t.properties.Material).toBe("Grass")
        end
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
